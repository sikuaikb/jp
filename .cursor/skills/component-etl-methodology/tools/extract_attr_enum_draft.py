#!/usr/bin/env python3
"""从「原始 Excel schema」抽取枚举 / 值域草案，供人工裁决（受众：无上下文会话）。

为什么要这个工具（见 lessons_learned LL-20260529-11）：
  枚举受控词表的**唯一权威源**是用户最初提供的 Excel schema 的「值域约束」列，
  不是库里的脏数据、也不是 dim 里的 value_domain（那本来就是从同一列来的）。
  但 Excel「值域约束」是**半结构自由文本且常自相矛盾**（同属性多套词表、分隔符
  `/` 与 `，` 漂移、`/` 在"符合JEDEC/IPC规范"里非枚举义）——所以本工具只产出
  **草案 + 冲突标注**，最终词表必须人工裁决，禁止 auto-parse 直接当真值。

产物去向（硬约束）：
  人工裁决后的词表只落 **test_dim 只读对照临时表 tmp_attr_enum**，
  **禁止同步到 prod dim**（不污染生产 schema）。校验器 validate_dwd_data.py 读该
  临时表时「存在才校验、缺失降级 WARN 跳过」。

输入 Excel 约定（11 列布局，与 pmic_schema.xlsx 一致）：
  分类等级 | 分类名称 | 分类英文名 | 模块分类 | 核心属性中文名称 |
  核心属性英文名称 | 属性描述 | 类型 | 小数点精度 | 基准单位 | 值域约束
  - L2 行：分类英文名 = L2 code（带 _Base 后缀，本工具会去掉并小写）
  - L3 行：分类英文名 = L3 code（小写）

用法：
    python3 extract_attr_enum_draft.py --xlsx tmp/pmic_schema.xlsx --l1 pmic \
        --out sql_scripts/test/pmic_attr_enum_draft.csv

输出 CSV 列：
    l1_code, scope_level, scope_code, std_attr_code, db_type,
    raw_value_domain, kind, parsed_enum_values, conflict, decision
  - kind: enum / bool / range / bound / format / freetext
  - parsed_enum_values: 仅 enum/bool 类给出候选 JSON 数组（仅供参考，需人工核）
  - conflict: yes = 同 std_attr_code across 多处给出**不同**候选词表，必须人工裁决
  - decision: 留空，人工填最终词表（| 分隔）或 reject
"""
from __future__ import annotations

import argparse
import csv
import json
import re
from pathlib import Path

import openpyxl

# 值域约束属于"格式描述/自由文本"而非枚举的判定：命中即不当 enum
FORMAT_HINT = re.compile(r"符合|规范|格式|^如|，如|全局唯一|非空|NOT\s*NULL", re.IGNORECASE)
BOUND_CHARS = "><≥≤"
ENUM_SPLIT = re.compile(r"[/，,、]")
EXPECTED_HEADER = ("分类等级", "分类名称", "分类英文名")


def norm_code(s: str) -> str:
    s = (s or "").strip()
    if s.lower().endswith("_base"):
        s = s[:-5]
    return s.lower()


def classify_domain(db_type: str, dom: str):
    """返回 (kind, parsed_values_list)。"""
    dom = (dom or "").strip()
    if db_type == "BOOLEAN":
        return "bool", ["TRUE", "FALSE"]
    if not dom:
        return "freetext", []
    if FORMAT_HINT.search(dom):
        return "format", []
    if any(c in dom for c in BOUND_CHARS):
        return "bound", []
    if "~" in dom:
        return "range", []
    if ENUM_SPLIT.search(dom):
        vals = [v.strip() for v in ENUM_SPLIT.split(dom) if v.strip()]
        if len(vals) >= 2:
            return "enum", vals
    return "freetext", []


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--xlsx", required=True, type=Path)
    ap.add_argument("--l1", required=True, help="L1 code，如 pmic")
    ap.add_argument("--out", required=True, type=Path)
    args = ap.parse_args()

    wb = openpyxl.load_workbook(args.xlsx, read_only=True, data_only=True)
    rows_out: list[dict] = []
    # 收集每个 std_attr_code 的候选词表集合用于冲突检测（小写值比较，忽略顺序）
    enum_by_attr: dict[str, set[frozenset]] = {}

    for ws in wb.worksheets:
        data = list(ws.iter_rows(values_only=True))
        if not data or data[0][:3] != EXPECTED_HEADER:
            continue
        for r in data[1:]:
            if not r or len(r) < 11 or not r[0]:
                continue
            scope_level = str(r[0]).strip().lower()  # l2 / l3
            scope_code = norm_code(r[2])
            std_attr_code = (r[5] or "").strip().lower()
            db_type = (r[7] or "").strip().upper()
            dom = (r[10] or "").strip()
            if not std_attr_code:
                continue
            kind, vals = classify_domain(db_type, dom)
            if kind in ("enum", "bool") and vals:
                enum_by_attr.setdefault(std_attr_code, set()).add(
                    frozenset(v.lower() for v in vals)
                )
            rows_out.append({
                "l1_code": args.l1,
                "scope_level": scope_level,
                "scope_code": scope_code,
                "std_attr_code": std_attr_code,
                "db_type": db_type,
                "raw_value_domain": dom,
                "kind": kind,
                "parsed_enum_values": json.dumps(vals, ensure_ascii=False) if vals else "",
                "conflict": "",
                "decision": "",
            })

    # 冲突标注：同 std_attr_code 出现 >1 套不同候选词表
    conflict_attrs = {a for a, s in enum_by_attr.items() if len(s) > 1}
    for row in rows_out:
        if row["std_attr_code"] in conflict_attrs and row["kind"] in ("enum", "bool"):
            row["conflict"] = "yes"

    args.out.parent.mkdir(parents=True, exist_ok=True)
    fields = ["l1_code", "scope_level", "scope_code", "std_attr_code", "db_type",
              "raw_value_domain", "kind", "parsed_enum_values", "conflict", "decision"]
    with args.out.open("w", encoding="utf-8", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=fields)
        w.writeheader()
        w.writerows(rows_out)

    from collections import Counter
    kc = Counter(r["kind"] for r in rows_out)
    print(f"抽取完成 → {args.out}")
    print(f"  总行 {len(rows_out)} | kind 分布: {dict(kc)}")
    print(f"  enum/bool 属性数: {len(enum_by_attr)} | 其中冲突需人工裁决: {len(conflict_attrs)}")
    if conflict_attrs:
        print("  ⚠ 冲突属性（同名多套词表，decision 列必须人工填最终词表）:")
        for a in sorted(conflict_attrs):
            variants = [sorted(s) for s in enum_by_attr[a]]
            print(f"     {a}: {variants}")


if __name__ == "__main__":
    main()
