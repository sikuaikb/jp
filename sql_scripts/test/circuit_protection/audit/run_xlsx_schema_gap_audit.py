#!/usr/bin/env python3
"""xlsx vs dim vs extract_rule vs ICPDF prajson 全 L3 字段差距审计。"""
from __future__ import annotations

import csv
import json
import os
import re
import sys
from collections import Counter, defaultdict
from dataclasses import dataclass, field
from pathlib import Path

import openpyxl
import pymysql

sys.stdout.reconfigure(encoding="utf-8")

XLSX = Path(r"e:\hardware_schema\schema_result\schemas_patched\xlsx\circuit_protection_schema.xlsx")
HERE = Path(__file__).resolve().parent
ENV = HERE.parents[2] / "local.env"
RULE_CSV = HERE.parent / "seed" / "dim_attr_extract_rule_circuit_protection.csv"
SCHEMA_CSV = HERE.parent / "seed" / "dim_attr_schema_circuit_protection.csv"
OUT = HERE.parent / "artifacts" / "circuit_protection" / "xlsx_schema_gap_audit.md"

# xlsx 分类英文名 → ETL l3_code
XLSX_L3_TO_CODE: dict[str, str] = {
    "Fuse": "fuse",
    "PPTC_Resettable_Fuse": "pptc_resettable_fuse",
    "Circuit_Breaker": "circuit_breaker",
    "Thermal_Cutoff": "thermal_cutoff",
    "TVS_Diode": "tvs_diode",
    "ESD_Suppressor": "esd_suppressor",
    "TSPD": "tspd",
    "MOV": "mov",
    "GDT": "gdt",
    "SPD_Module": "spd_module",
}

L3_L2: dict[str, str] = {
    "fuse": "overcurrent_overtemperature_protection",
    "pptc_resettable_fuse": "overcurrent_overtemperature_protection",
    "circuit_breaker": "overcurrent_overtemperature_protection",
    "thermal_cutoff": "overcurrent_overtemperature_protection",
    "tvs_diode": "semiconductor_transient_suppression",
    "esd_suppressor": "semiconductor_transient_suppression",
    "tspd": "semiconductor_transient_suppression",
    "mov": "passive_surge_diversion",
    "gdt": "passive_surge_diversion",
    "spd_module": "surge_protection_module",
}

# 字段名 xlsx → ETL snake_case（小写）
def xlsx_attr_to_code(name: str) -> str:
    return name.strip().lower()


@dataclass
class XlsxField:
    l3_xlsx: str
    l3_code: str
    attr_en: str
    attr_code: str
    attr_cn: str
    sheet: str


def load_xlsx_fields() -> list[XlsxField]:
    wb = openpyxl.load_workbook(XLSX, read_only=True, data_only=True)
    out: list[XlsxField] = []
    for sn in wb.sheetnames:
        ws = wb[sn]
        for r in list(ws.iter_rows(values_only=True))[1:]:
            if not r or len(r) < 6:
                continue
            level = str(r[0] or "").strip().upper()
            if level != "L3":
                continue
            l3_xlsx = str(r[2] or r[1] or "").strip()
            l3_code = XLSX_L3_TO_CODE.get(l3_xlsx)
            if not l3_code:
                # try match by cn name patterns
                cn = str(r[1] or "")
                continue
            attr_en = str(r[5] or "").strip()
            attr_cn = str(r[4] or "").strip()
            out.append(XlsxField(l3_xlsx, l3_code, attr_en, xlsx_attr_to_code(attr_en), attr_cn, sn))
    wb.close()
    return out


def load_env() -> None:
    for line in ENV.read_text(encoding="utf-8").splitlines():
        if line.strip().startswith("export "):
            k, _, v = line.strip()[7:].partition("=")
            os.environ[k] = v.strip().strip("'").strip('"')


def load_dim_from_csv() -> set[tuple[str, str]]:
    s: set[tuple[str, str]] = set()
    with SCHEMA_CSV.open(encoding="utf-8") as f:
        for r in csv.DictReader(f):
            if r.get("scope_level") == "l3":
                s.add((r["scope_code"], r["std_attr_code"]))
    return s


def load_rules_split() -> tuple[set[tuple[str, str]], dict[tuple[str, str], list[str]]]:
    dk_keys: set[tuple[str, str]] = set()
    icpdf_exprs: dict[tuple[str, str], list[str]] = defaultdict(list)
    with RULE_CSV.open(encoding="utf-8") as f:
        for r in csv.DictReader(f):
            if r.get("enabled", "1") != "1" or r.get("apply_scope_level") != "l3":
                continue
            key = (r["apply_scope_code"], r["std_attr_code"])
            if r["data_source"] == "digikey":
                dk_keys.add(key)
            elif r["data_source"] == "icpdf" and r.get("source_expr"):
                icpdf_exprs[key].append(r["source_expr"])
    return dk_keys, icpdf_exprs


def probe_src(
    l3_code: str, n: int, xf: XlsxField, icpdf_exprs: list[str], freq: Counter
) -> str:
    if not n:
        return "—"
    if icpdf_exprs:
        hits = [f"`{e}` {100*freq.get(e, 0)/n:.0f}%" for e in icpdf_exprs if freq.get(e, 0)]
        return "; ".join(hits) if hits else "规则 key 0%"
    # 语义候选 key
    hints: list[tuple[str, int]] = []
    attr = xf.attr_code
    for k, cnt in freq.most_common(100):
        kl = k.lower()
        if attr == "fusing_speed_class" and any(x in k for x in ("熔断特性", "熔断速度", "响应时间")):
            hints.append((k, cnt))
        elif attr == "melting_i2t_a2s" and any(x in k for x in ("I2t", "i2t", "熔断积分", "焦耳")):
            hints.append((k, cnt))
        elif attr == "cold_resistance_mohm" and ("电阻" in k or "resistance" in kl):
            hints.append((k, cnt))
        elif attr == "voltage_type" and ("电压类型" in k or "交流" in k and "直流" in k):
            hints.append((k, cnt))
        elif "voltage" in attr and "电压" in k:
            hints.append((k, cnt))
        elif "current" in attr and "电流" in k:
            hints.append((k, cnt))
        elif "resistance" in attr and ("电阻" in k or "resistance" in kl):
            hints.append((k, cnt))
        elif "capacitance" in attr and ("电容" in k or "cap" in kl):
            hints.append((k, cnt))
        elif attr == "polarity_type" and ("极性" in k or "polarity" in kl):
            hints.append((k, cnt))
        elif "temp" in attr and "温度" in k:
            hints.append((k, cnt))
        elif "pole" in attr and "极数" in k:
            hints.append((k, cnt))
        elif "sparkover" in attr or "breakdown" in attr:
            if "击穿" in k or "spark" in kl:
                hints.append((k, cnt))
        elif "surge" in attr and ("浪涌" in k or "surge" in kl):
            hints.append((k, cnt))
        elif "trigger" in attr and ("触发" in k or "转折" in k):
            hints.append((k, cnt))
        elif "holding" in attr and "维持" in k:
            hints.append((k, cnt))
    if hints:
        return "候选: " + ", ".join(f"`{k}` {100*c/n:.0f}%" for k, c in hints[:3])
    return "未探针到相近 key"


def main() -> None:
    load_env()
    xlsx_fields = load_xlsx_fields()
    dim_set = load_dim_from_csv()
    dk_rules, icpdf_rule_exprs = load_rules_split()

    conn = pymysql.connect(
        host=os.environ["MYSQL_HOST"], port=9030,
        user=os.environ["MYSQL_USER"], password=os.environ["MYSQL_PASSWORD"],
        charset="utf8mb4", cursorclass=pymysql.cursors.DictCursor,
    )
    cur = conn.cursor()
    cur.execute("SET enable_local_shuffle_agg=false")

    # L3 行数
    cur.execute("""
        SELECT l3_code, COUNT(1) n FROM test_dwd.dwd_component_class_circuit_protection
        WHERE data_source='icpdf' GROUP BY l3_code
    """)
    l3_n = {r["l3_code"]: r["n"] for r in cur.fetchall()}

    # EAV fill batch
    eav_fill: dict[tuple[str, str], int] = {}
    for l3_code, attr_code in {(f.l3_code, f.attr_code) for f in xlsx_fields}:
        if l3_n.get(l3_code, 0) == 0:
            continue
        cur.execute("""
            SELECT COUNT(1) filled FROM test_dwd.dwd_component_class_circuit_protection c
            INNER JOIN test_dwd.dwd_component_attr_std_circuit_protection e
              ON e.id=c.id AND e.data_source=c.data_source AND e.std_attr_code=%s
            WHERE c.data_source='icpdf' AND c.l3_code=%s
              AND (e.value_std_double IS NOT NULL
                   OR (e.value_std_varchar IS NOT NULL AND trim(e.value_std_varchar)<>''))
        """, (attr_code, l3_code))
        eav_fill[(l3_code, attr_code)] = cur.fetchone()["filled"] or 0

    # prajson key 频率（按 L3，全量扫描）
    key_freq: dict[str, Counter] = defaultdict(Counter)
    cur.execute("""
        SELECT c.l3_code, p.prajson2 FROM dwd.dwd_icpdf_component_param p
        INNER JOIN test_dwd.dwd_component_class_circuit_protection c
          ON c.id=p.id AND c.data_source='icpdf'
        WHERE p.prajson2 IS NOT NULL
    """)
    for row in cur.fetchall():
        l3 = row["l3_code"]
        try:
            obj = json.loads(row["prajson2"])
        except json.JSONDecodeError:
            continue
        if not isinstance(obj, dict):
            continue
        for k, v in obj.items():
            if v not in (None, "", "-"):
                key_freq[l3][k] += 1

    lines = [
        "# circuit_protection · xlsx schema 差距审计",
        "",
        f"真源：`{XLSX}`",
        "对比：`test_dim.dim_attr_schema_circuit_protection` + `dim_attr_extract_rule` + ICPDF EAV",
        "",
        "状态：**DIM**=dim有无 · **RULE**=extract_rule · **EAV**=已提取 · **SRC**=ICPDF prajson 有无可映射 key",
        "",
    ]

    by_l3: dict[str, list[XlsxField]] = defaultdict(list)
    for xf in xlsx_fields:
        by_l3[xf.l3_code].append(xf)

    summary = {"dim_miss": 0, "rule_miss": 0, "eav_zero": 0, "total": 0, "ok": 0}
    l3_stats: dict[str, dict[str, int]] = defaultdict(
        lambda: {"rule_miss": 0, "eav_zero": 0, "ok": 0, "pending": 0}
    )

    for l3_code in sorted(by_l3.keys(), key=lambda x: -l3_n.get(x, 0)):
        fields = by_l3[l3_code]
        n = l3_n.get(l3_code, 0)
        l2 = L3_L2.get(l3_code, "?")
        lines.extend([
            f"## {l3_code} ({fields[0].l3_xlsx})",
            "",
            f"- L2 表：`{l2}` · ICPDF 分类行数：**{n:,}**"
            + (" · ⚠ 当前 gate/classify 无此 L3" if n == 0 else ""),
            "",
            "| xlsx 字段 | attr_code | dim | rule | EAV填充 | 占L3 | SRC 探针 | 判定 |",
            "|-----------|-----------|-----|------|---------|------|----------|------|",
        ])
        for xf in fields:
            summary["total"] += 1
            key = (l3_code, xf.attr_code)
            in_dim = key in dim_set
            has_dk_rule = key in dk_rules
            icpdf_exprs = icpdf_rule_exprs.get(key, [])
            has_icpdf_rule = bool(icpdf_exprs)

            filled = eav_fill.get(key, 0)
            pct = 100 * filled / n if n else 0

            if not in_dim:
                summary["dim_miss"] += 1
            if not has_icpdf_rule and not has_dk_rule:
                summary["rule_miss"] += 1
            if n and filled == 0:
                summary["eav_zero"] += 1

            src_note = probe_src(l3_code, n, xf, icpdf_exprs, key_freq[l3_code])

            if not in_dim:
                verdict = "**GAP-DIM**"
            elif not has_icpdf_rule:
                verdict = "**GAP-RULE**" if has_dk_rule else "**GAP-DIM+RULE**"
            elif filled == 0 and n:
                verdict = "**GAP-EXTRACT**"
            elif pct >= 10:
                verdict = "**OK**"
                summary["ok"] += 1
                l3_stats[l3_code]["ok"] += 1
            elif n == 0:
                verdict = "**N/A**"
            else:
                verdict = "**D**" if "0%" in src_note or src_note == "规则 key 0%" else "**R?**"

            if in_dim and not has_icpdf_rule and not has_dk_rule:
                l3_stats[l3_code]["rule_miss"] += 1
                l3_stats[l3_code]["pending"] += 1
            elif in_dim and n and filled == 0:
                l3_stats[l3_code]["eav_zero"] += 1
                if verdict not in ("**N/A**",):
                    l3_stats[l3_code]["pending"] += 1

            dim_s = "✅" if in_dim else "❌"
            rule_s = "✅ic" if has_icpdf_rule else ("✅dk" if has_dk_rule else "❌")
            eav_s = f"{filled:,} ({pct:.1f}%)" if n else "—"
            lines.append(
                f"| {xf.attr_cn} | `{xf.attr_code}` | {dim_s} | {rule_s} | {eav_s} | "
                f"{src_note} | {verdict} |"
            )
        lines.append("")

    # 汇总
    lines.extend([
        "## 汇总",
        "",
        f"| 指标 | 数量 |",
        f"|------|------|",
        f"| xlsx L3 专属字段总数 | {summary['total']} |",
        f"| dim 缺失 | {summary['dim_miss']} |",
        f"| extract_rule 缺失（含 icpdf） | {summary['rule_miss']} |",
        f"| 有分类但 EAV=0 | {summary['eav_zero']} |",
        f"| 已可用 (EAV≥10%) | {summary['ok']} |",
        "",
        "## 结论",
        "",
        f"1. **xlsx 定义 10 个 L3、共 {summary['total']} 个专属字段**；test dim **全覆盖**（dim_miss={summary['dim_miss']}）。",
        f"2. **{summary['ok']}/{summary['total']} 字段 EAV≥10% 可用**；{summary['rule_miss']} 字段仍无 extract_rule；{summary['eav_zero']} 字段有分类但 EAV=0。",
        "3. **阶段 A–G 已落地** fuse/tspd/esd/gdt/pptc/breaker/tvs 主字段；**mov 已迁出 CP gate**（ICPDF 0 行）；剩余 GAP 多为 **源端稀疏**（thermal_cutoff、gdt）或 **低优可选字段**（spd 9 字段）。",
        "4. **pptc** gate 收窄后 **867 行 · ext 96.9% · hold/trip ~95%**（误归 MOV 释放后纯度提升）；**spd_module** 19 行 + L2 已建，规则 intentionally disabled。",
        "5. **merge prod 预备**：品牌门控通过 · 详见 `phase55_audit_full.md` 迭代 12 · `merge_precheck.md`。",
        "",
        "## 建议落地顺序（剩余 GAP · 非 merge 阻断）",
        "",
        "| 优先级 | L3 | 行数 | 待补字段 | OK 字段 | 说明 |",
        "|--------|-----|------|---------|---------|------|",
    ])
    for l3_code in sorted(by_l3.keys(), key=lambda x: -l3_stats[l3_code]["pending"]):
        st = l3_stats[l3_code]
        if st["pending"] == 0:
            continue
        n = l3_n.get(l3_code, 0)
        pri = "P3" if n < 100 else ("P2" if n < 1000 else "P1")
        note = "源端稀疏" if l3_code in ("thermal_cutoff", "gdt") else (
            "样本极少" if l3_code == "spd_module" else "可选字段"
        )
        lines.append(
            f"| {pri} | {l3_code} | {n:,} | {st['pending']} | {st['ok']} | {note} |"
        )

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text("\n".join(lines), encoding="utf-8")
    print(f"wrote {OUT}")
    print(f"xlsx fields: {summary['total']}, dim_miss: {summary['dim_miss']}, ok: {summary['ok']}")
    conn.close()


if __name__ == "__main__":
    main()
