#!/usr/bin/env python3
"""分类 dim 机械校验器（component-etl-methodology 硬门控的可执行版）。

把"只能写在 prompt 里"的分类硬规则变成 fail-fast 校验，任何新 L1 沙盒在跑
classify 之前必须先过这个工具。defaults 以 sql_scripts/foundation/dim_l3_classify_all.sql
为权威字典——但**只有 L1 维度（l1_code + l3_id 段归属）权威**；L2/L3 以各品类的
Excel schema 为准，dim_l3_classify_all 的 L2/L3 仅供参考，本工具一律不校验 L2/L3
（因为协作者手上不一定有 Excel，硬门控只锁 L1 与 id 段）。

用法（二选一，优先连库）：
    python3 validate_classify_dim.py \
        --dim-schema test_dim \
        --classify-table dim_l3_classify_capacitor \
        --rule-table dim_l3_classify_rule_capacitor \
        [--expect-l1 capacitor]
    python3 validate_classify_dim.py \
        --classify-csv  <导出或历史 CSV> \
        --rule-csv      <导出或历史 CSV> \
        [--taxonomy     <dim_l3_classify_all.sql>]
        [--expect-l1    mcu_mpu_dsp]

退出码：0 = 全部硬门控通过；1 = 有硬门控失败（WARN 不影响退出码）。

校验项（硬门控 = FAIL，建议项 = WARN）：
    C1 [FAIL] L1 权威校验（**只锁 L1，不锁 L2/L3**）：
              (a) 每行 l1_code 必须是 dim_l3_classify_all 中登记的合法 L1；
              (b) l3_id 前2位段必须归属于该 l1_code（段由 taxonomy 学习，前2位一对一）。
              —— 拦截 l3_id 撞段（如 mcu 用了 storage 的 20 段）与未知 L1；
              L2/L3 以各品类 Excel schema 为准，本项不比对 l2_code/l3_code
    C2 [FAIL] 沙盒分类树必须单一 l1_code（一个沙盒 = 一个 L1）
              —— 拦截把 MCU/MPU/DSP 拆成三个 L1
    C3 [FAIL] 每条 enabled=1 的 classify 规则的 l3_id 必须能在分类树 CSV 中找到
              （enabled=0 的"停用/暂存"规则允许指向尚未登记的节点，但一旦启用必须先过校验）
    C4 [FAIL] 每个 rule_id 必须带 L1 文字前缀（gate_<l1>_* 或 <l1>_*）
    C5 [FAIL] 分类树 l3_id 必须六位数字且 CSV 内唯一（PK 预检）
    C6 [WARN] 路由到 L2=mcu 的 classify 规则若仅凭 category/prajson 文案（无 note_cn_regexp）
              且 enabled=1 —— 提示可能违反"源端文案不得单独判 MCU L3"（需商城核对）
    C7 [FAIL] l2_code 不得以 `_base` 结尾（如 mcu_base/dsp_base）；L2 名是业务编码，
              不是"基类"占位（如需基类语义请用真实 L2 编码，见 anti_patterns）
    C8 [FAIL] 同一 (l1_code, l2_code) 内的 l3_id 必须连续无跳号（数值排序后相邻差=1）；
              剔除 `*_unclassified` 节点。—— L2/L3 的 id 体系要自洽且连续（删节点后要补齐重排，
              不允许 190301+190304 这种跳号）
    C9 [FAIL] l1_code / l2_code / l3_code 必须 lower_snake_case（^[a-z][a-z0-9_]*$）：
              全小写、只含字母数字下划线、首字符为字母。—— 拦截 PascalCase（如 General_MCU）、
              大写、连字符、空格；taxonomy code 与下游 EAV/宽表 lower_snake_case 列名/JSON key
              保持一致（Excel 英文名是 PascalCase，落库时必须转 snake_case）。空值跳过。
    C10 [FAIL] schema_version 必须与品类 Excel schema 版本一致（单一版本、全表统一）：
              (a) 分类树 CSV 同一 l1_code 只能有一个 schema_version（如 Excel
              `mcu_mpu_dsp_schema_v5.20.xlsx` → `v1.5.20`，文件名省略前缀 `1.`）；
              (b) enabled classify 规则的 schema_version 必须与其 l3_id 在分类树中的
              schema_version 一致（引擎 INNER JOIN 依赖此列，版本分裂会导致规则零产出）。
              —— 禁止用 v1.0.00/v1.1.00 等规则迭代号冒充 schema 版本（LL-20260601-01）。
"""
from __future__ import annotations

import argparse
import csv
import re
import sys
from pathlib import Path

TAXO_RE = re.compile(
    r"SELECT\s+'(?P<l3_id>[^']+)'\s+AS\s+l3_id,\s*"
    r"'(?P<l1>[^']*)'\s+AS\s+l1_code,\s*'[^']*'\s+AS\s+l1_cn,\s*"
    r"'(?P<l2>[^']*)'\s+AS\s+l2_code,\s*'[^']*'\s+AS\s+l2_cn,\s*"
    r"'(?P<l3>[^']*)'\s+AS\s+l3_code"
)

L3_ID_RE = re.compile(r"^\d{6}$")
SNAKE_RE = re.compile(r"^[a-z][a-z0-9_]*$")


def find_default_taxonomy(start: Path) -> Path | None:
    rel = Path("sql_scripts/foundation/dim_l3_classify_all.sql")
    for base in [start, *start.parents]:
        cand = base / rel
        if cand.is_file():
            return cand
    return None


def load_taxonomy(path: Path) -> dict[str, tuple[str, str, str]]:
    """l3_id -> (l1_code, l2_code, l3_code)。L2/L3 仅供参考，校验只用 L1 维度。"""
    taxo: dict[str, tuple[str, str, str]] = {}
    for m in TAXO_RE.finditer(path.read_text(encoding="utf-8")):
        taxo[m.group("l3_id")] = (m.group("l1"), m.group("l2"), m.group("l3"))
    return taxo


def build_l1_dicts(taxo: dict[str, tuple[str, str, str]]) -> tuple[set[str], dict[str, str]]:
    """从 taxonomy 抽出 L1 权威字典：
    - valid_l1：合法 L1 集合
    - seg2_to_l1：l3_id 前2位段 -> 唯一 L1（taxonomy 内前2位一对一；若冲突取首个并由 caller 感知）
    """
    valid_l1: set[str] = set()
    seg2_to_l1: dict[str, str] = {}
    for lid, (l1, _l2, _l3) in taxo.items():
        valid_l1.add(l1)
        seg = lid[:2]
        seg2_to_l1.setdefault(seg, l1)
    return valid_l1, seg2_to_l1


def read_csv(path: Path) -> list[dict]:
    with path.open(encoding="utf-8") as fh:
        return list(csv.DictReader(fh))


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--classify-csv", type=Path)
    ap.add_argument("--rule-csv", type=Path)
    ap.add_argument("--dim-schema", help="连库读分类树/规则（与 --classify-table/--rule-table 合用）")
    ap.add_argument("--classify-table")
    ap.add_argument("--rule-table")
    ap.add_argument("--taxonomy", type=Path)
    ap.add_argument("--expect-l1")
    args = ap.parse_args()

    classify_cols = [
        "l3_id", "l1_code", "l1_cn", "l2_code", "l2_cn",
        "l3_code", "l3_cn", "note", "schema_version",
    ]
    rule_cols = [
        "rule_id", "clause_group_id", "clause_ord",
        "schema_version", "data_source", "rule_kind",
        "l3_id", "l3_cn",
        "phase", "rule_priority", "enabled", "confidence_weight",
        "classify_source_hint", "field_code",
        "match_value", "match_values", "match_map",
        "note",
    ]

    if args.dim_schema:
        if not args.classify_table or not args.rule_table:
            print("ERROR: --dim-schema 须同时提供 --classify-table 与 --rule-table", file=sys.stderr)
            sys.exit(2)
        from dim_db_loader import fetch_rows

        classify_rows = fetch_rows(args.dim_schema, args.classify_table, classify_cols)
        rule_rows = fetch_rows(args.dim_schema, args.rule_table, rule_cols)
        src = f"{args.dim_schema}.{args.classify_table}+{args.rule_table}"
    elif args.classify_csv and args.rule_csv:
        classify_rows = read_csv(args.classify_csv)
        rule_rows = read_csv(args.rule_csv)
        src = f"{args.classify_csv}+{args.rule_csv}"
    else:
        print("ERROR: 须提供 --dim-schema+表名，或 --classify-csv/--rule-csv", file=sys.stderr)
        sys.exit(2)

    taxo_path = args.taxonomy or find_default_taxonomy(Path.cwd())
    if not taxo_path or not taxo_path.is_file():
        print("ERROR: 找不到权威 taxonomy（dim_l3_classify_all.sql），请用 --taxonomy 指定", file=sys.stderr)
        sys.exit(2)

    taxo = load_taxonomy(taxo_path)
    if not taxo:
        print(f"ERROR: 未能从 {taxo_path} 解析出任何 taxonomy 行", file=sys.stderr)
        sys.exit(2)

    fails: list[str] = []
    warns: list[str] = []

    # C5: l3_id 六位数字 + CSV 内唯一
    seen: set[str] = set()
    for r in classify_rows:
        lid = (r.get("l3_id") or "").strip()
        if not L3_ID_RE.match(lid):
            fails.append(f"C5 l3_id 非六位数字: {lid!r} (l3_code={r.get('l3_code')})")
        if lid in seen:
            fails.append(f"C5 l3_id 重复(PK冲突): {lid}")
        seen.add(lid)

    # C7: l2_code 不得以 _base 结尾
    for r in classify_rows:
        l2 = (r.get("l2_code") or "").strip()
        if l2.endswith("_base"):
            fails.append(f"C7 l2_code={l2!r} 以 _base 结尾（L2 名不要带 base；l3_id={r.get('l3_id')}）")

    # C2: 单一 l1_code
    l1s = {(r.get("l1_code") or "").strip() for r in classify_rows}
    l1s.discard("")
    if len(l1s) != 1:
        fails.append(f"C2 沙盒分类树应单一 l1_code，实测 {sorted(l1s)}（一个沙盒=一个 L1）")
    sandbox_l1 = next(iter(l1s)) if len(l1s) == 1 else None
    if args.expect_l1 and sandbox_l1 and sandbox_l1 != args.expect_l1:
        fails.append(f"C2 l1_code={sandbox_l1} ≠ --expect-l1={args.expect_l1}")

    # C1: L1 权威校验（只锁 L1 + id 段，不锁 L2/L3；L2/L3 以各品类 Excel schema 为准）
    valid_l1, seg2_to_l1 = build_l1_dicts(taxo)
    for r in classify_rows:
        lid = (r.get("l3_id") or "").strip()
        l1 = (r.get("l1_code") or "").strip()
        if not L3_ID_RE.match(lid):
            continue  # 非法 id 已由 C5 报
        # (a) l1_code 必须是合法 L1
        if l1 not in valid_l1:
            fails.append(
                f"C1 l1_code={l1!r}(l3_id={lid}) 不是 {taxo_path.name} 登记的合法 L1；"
                f"L1 必须以该表为准（合法 L1 共 {len(valid_l1)} 个）"
            )
            continue
        # (b) l3_id 前2位段必须归属于该 L1
        seg = lid[:2]
        owner = seg2_to_l1.get(seg)
        if owner is None:
            fails.append(
                f"C1 l3_id={lid} 的段 {seg}xxxx 未在 {taxo_path.name} 中分配给任何 L1；"
                f"新 L1 的 id 段须先在该表登记（每个 L1 占一个唯一前2位段）"
            )
        elif owner != l1:
            fails.append(
                f"C1 l3_id={lid} 段 {seg}xxxx 在 {taxo_path.name} 中属于 L1={owner}，"
                f"与本行 l1_code={l1} 冲突（id 段撞了别的 L1；按该表 L1={l1} 应另用其专属段）"
            )

    # C8: 同一 (l1_code, l2_code) 内 l3_id 连续无跳号（剔除 *_unclassified）
    groups: dict[tuple[str, str], list[int]] = {}
    for r in classify_rows:
        lid = (r.get("l3_id") or "").strip()
        l3c = (r.get("l3_code") or "").strip()
        l1c = (r.get("l1_code") or "").strip()
        l2c = (r.get("l2_code") or "").strip()
        if not L3_ID_RE.match(lid):
            continue
        if l3c.endswith("_unclassified"):
            continue
        groups.setdefault((l1c, l2c), []).append(int(lid))
    for (l1c, l2c), ids in sorted(groups.items()):
        ids_sorted = sorted(ids)
        full_range = list(range(ids_sorted[0], ids_sorted[-1] + 1))
        if ids_sorted != full_range:
            missing = sorted(set(full_range) - set(ids_sorted))
            fails.append(
                f"C8 L2={l2c}(l1={l1c}) 的 l3_id 不连续：实有 {ids_sorted}，"
                f"缺号 {missing}；同一 L2 内 L3 编号须从起始连续无跳号（删节点后补齐重排）"
            )

    # C9: l1_code / l2_code / l3_code 必须 lower_snake_case（空值跳过，缺值由别的规则管）
    for r in classify_rows:
        lid = (r.get("l3_id") or "").strip()
        for col in ("l1_code", "l2_code", "l3_code"):
            val = (r.get(col) or "").strip()
            if not val:
                continue
            if not SNAKE_RE.match(val):
                fails.append(
                    f"C9 {col}={val!r}(l3_id={lid}) 非 lower_snake_case；"
                    f"期望匹配 ^[a-z][a-z0-9_]*$（全小写+下划线，如 general_mcu）；"
                    f"Excel 英文名是 PascalCase，落库时须转 snake_case，"
                    f"与下游 EAV/宽表列名/JSON key 大小写一致"
                )

    # C10: schema_version 单一且规则与分类树对齐（= Excel schema 版本，非规则迭代号）
    l1_versions: dict[str, set[str]] = {}
    l3_to_sv: dict[str, str] = {}
    for r in classify_rows:
        l1c = (r.get("l1_code") or "").strip()
        sv = (r.get("schema_version") or "").strip()
        lid = (r.get("l3_id") or "").strip()
        if l1c and sv:
            l1_versions.setdefault(l1c, set()).add(sv)
        if lid and sv:
            prev = l3_to_sv.get(lid)
            if prev and prev != sv:
                fails.append(
                    f"C10 l3_id={lid} 在分类树 CSV 中并存多个 schema_version: {prev!r} vs {sv!r}；"
                    f"同一 L3 节点只能绑定一个 Excel schema 版本"
                )
            l3_to_sv[lid] = sv
    for l1c, versions in sorted(l1_versions.items()):
        if len(versions) > 1:
            fails.append(
                f"C10 l1_code={l1c} 的分类树并存多个 schema_version: {sorted(versions)}；"
                f"须与品类 Excel schema 文件名版本一致且全表统一"
                f"（如 mcu_mpu_dsp_schema_v5.20.xlsx → v1.5.20）"
            )
    for r in rule_rows:
        kind = (r.get("rule_kind") or "").strip()
        enabled = (r.get("enabled") or "").strip() == "1"
        if kind != "classify" or not enabled:
            continue
        rid = (r.get("rule_id") or "").strip()
        lid = (r.get("l3_id") or "").strip()
        sv = (r.get("schema_version") or "").strip()
        if not lid or not sv:
            continue
        expected = l3_to_sv.get(lid)
        if expected is None:
            continue  # C3 已报 orphan l3_id
        if sv != expected:
            fails.append(
                f"C10 规则 {rid} schema_version={sv!r} ≠ 分类树 l3_id={lid} 的 {expected!r}；"
                f"引擎 classify JOIN 依赖两表 schema_version 一致，分裂会导致规则零产出"
            )

    # C3 + C4: 规则引用与前缀
    classify_l3ids = {(r.get("l3_id") or "").strip() for r in classify_rows}
    for r in rule_rows:
        rid = (r.get("rule_id") or "").strip()
        kind = (r.get("rule_kind") or "").strip()
        lid = (r.get("l3_id") or "").strip()
        enabled = (r.get("enabled") or "").strip() == "1"
        if kind == "classify" and enabled:
            if lid and lid not in classify_l3ids:
                fails.append(f"C3 (enabled) 规则 {rid} 的 l3_id={lid} 不在分类树 CSV 中")
        if sandbox_l1:
            ok_prefix = rid.startswith(f"{sandbox_l1}_") or rid.startswith(f"gate_{sandbox_l1}_")
            if not ok_prefix:
                fails.append(f"C4 rule_id={rid} 未带 L1 前缀（应为 {sandbox_l1}_* 或 gate_{sandbox_l1}_*）")

    # C6 [WARN]: 路由到 L2=mcu 仅凭文案的启用规则
    l3_to_l2 = {
        (r.get("l3_id") or "").strip(): (r.get("l2_code") or "").strip()
        for r in classify_rows
    }
    rules_by_id: dict[str, list[dict]] = {}
    for r in rule_rows:
        rules_by_id.setdefault((r.get("rule_id") or "").strip(), []).append(r)
    for rid, clauses in rules_by_id.items():
        if not any((c.get("rule_kind") or "").strip() == "classify" for c in clauses):
            continue
        if not any((c.get("enabled") or "").strip() == "1" for c in clauses):
            continue
        target_l2 = {l3_to_l2.get((c.get("l3_id") or "").strip()) for c in clauses}
        if "mcu" not in target_l2:
            continue
        fields = {(c.get("field_code") or "").strip() for c in clauses}
        if "note_cn_regexp" not in fields and fields <= {"category_in", "parjson_match_map", "category_eq", "category2_in"}:
            warns.append(
                f"C6 规则 {rid} 路由到 L2=mcu 但仅凭 category/prajson 文案（无 note_cn_regexp）；"
                f"确认已商城核对，否则可能违反 MCU L3 硬门控"
            )

    # 输出
    for w in warns:
        print(f"WARN  {w}")
    for f in fails:
        print(f"FAIL  {f}")

    if fails:
        print(f"\n分类 dim 校验未通过：{len(fails)} 个硬门控失败，{len(warns)} 个警告  src={src}  taxonomy={taxo_path}")
        sys.exit(1)
    print(f"分类 dim 校验通过：硬门控 OK（{len(warns)} 个警告）  src={src}  taxonomy={taxo_path}")
    sys.exit(0)


if __name__ == "__main__":
    main()
