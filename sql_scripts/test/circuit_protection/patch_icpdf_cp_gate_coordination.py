#!/usr/bin/env python3
"""ICPDF circuit_protection merge 协调：rival L1 gate 让渡 + diode TVS 白名单移除。

Step 5 沙盒（单 L1）vs prod 全局引擎对齐：
  1. 从 gate_diode 移除 TVS category 字面（G1）
  2. diode/transistor/resistor gate exclude，防止 category2 侧路进 rival L1
  3. CP classify phase2→3 见 classify_config.py（全局决选 priority）

用法（仓库根）：
  python sql_scripts/test/circuit_protection/patch_icpdf_cp_gate_coordination.py
  python sql_scripts/test/circuit_protection/patch_icpdf_cp_gate_coordination.py --write
"""
from __future__ import annotations

import argparse
import csv
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
SEED = ROOT / "sql_scripts" / "1.classify" / "seed" / "dim_l3_classify_rule.csv"
APPLY_SQL = ROOT / "sql_scripts" / "test" / "circuit_protection" / "dim_l3_classify_rule_icpdf_cp_coordination_apply.sql"

DIODE_RULE = "gate_diode_icpdf_v1"
TVS_CEDE: set[str] = {"TVS二极管", "瞬态抑制二极管", "瞬态抑制器"}

# CP gate_config.py · CATEGORY_INCLUDE / CATEGORY2_INCLUDE
CP_CATEGORY = [
    "TVS二极管",
    "保险丝",
    "热熔断路器/开关/保险丝",
    "电路保护器件",
    "硅浪涌保护器",
]
CP_CATEGORY2 = ["电熔丝", "断路器", "硅浪涌保护器", "电信保护电路"]

# 新增 gate exclude 行（rival L1 · icpdf）
NEW_EXCLUDES: list[dict] = [
    {
        "rule_id": "gate_diode_icpdf_exclude_cp_tvs_v1",
        "clause_group_id": "0",
        "clause_ord": "0",
        "schema_version": "v1.5.09",
        "data_source": "icpdf",
        "rule_kind": "gate",
        "l3_id": "",
        "l3_cn": "",
        "phase": "1",
        "rule_priority": "1",
        "enabled": "1",
        "confidence_weight": "1",
        "classify_source_hint": "gate_exclude_category",
        "field_code": "gate_exclude_category_like",
        "match_value": "",
        "match_values": json.dumps(list(TVS_CEDE), ensure_ascii=False),
        "match_map": "",
        "note": "CP 协调：category=TVS/瞬态抑制 不进 diode（即使 category2 命中整流二极管）",
    },
    {
        "rule_id": "gate_transistor_icpdf_exclude_cp_v1",
        "clause_group_id": "0",
        "clause_ord": "0",
        "schema_version": "v1.5.09",
        "data_source": "icpdf",
        "rule_kind": "gate",
        "l3_id": "",
        "l3_cn": "",
        "phase": "1",
        "rule_priority": "1",
        "enabled": "1",
        "confidence_weight": "1",
        "classify_source_hint": "gate_exclude_category",
        "field_code": "gate_exclude_category_like",
        "match_value": "",
        "match_values": json.dumps(["电路保护器件", "硅浪涌保护器"], ensure_ascii=False),
        "match_map": "",
        "note": "CP 协调：电路保护/硅浪涌 category 不进 transistor",
    },
    {
        "rule_id": "gate_transistor_icpdf_exclude_cp_v1",
        "clause_group_id": "1",
        "clause_ord": "0",
        "schema_version": "v1.5.09",
        "data_source": "icpdf",
        "rule_kind": "gate",
        "l3_id": "",
        "l3_cn": "",
        "phase": "1",
        "rule_priority": "1",
        "enabled": "1",
        "confidence_weight": "1",
        "classify_source_hint": "gate_exclude_category2",
        "field_code": "gate_exclude_category2_in",
        "match_value": "",
        "match_values": json.dumps(["电信保护电路", "硅浪涌保护器"], ensure_ascii=False),
        "match_map": "",
        "note": "CP 协调：电信保护/硅浪涌 c2 不进 transistor",
    },
    {
        "rule_id": "gate_resistor_icpdf_exclude_cp_v1",
        "clause_group_id": "0",
        "clause_ord": "0",
        "schema_version": "v1.5.09",
        "data_source": "icpdf",
        "rule_kind": "gate",
        "l3_id": "",
        "l3_cn": "",
        "phase": "1",
        "rule_priority": "1",
        "enabled": "1",
        "confidence_weight": "1",
        "classify_source_hint": "gate_exclude_category",
        "field_code": "gate_exclude_category_like",
        "match_value": "",
        "match_values": json.dumps(CP_CATEGORY, ensure_ascii=False),
        "match_map": "",
        "note": "CP 协调：CP category 白名单不进 resistor",
    },
    {
        "rule_id": "gate_resistor_icpdf_exclude_cp_v1",
        "clause_group_id": "1",
        "clause_ord": "0",
        "schema_version": "v1.5.09",
        "data_source": "icpdf",
        "rule_kind": "gate",
        "l3_id": "",
        "l3_cn": "",
        "phase": "1",
        "rule_priority": "1",
        "enabled": "1",
        "confidence_weight": "1",
        "classify_source_hint": "gate_exclude_category2",
        "field_code": "gate_exclude_category2_in",
        "match_value": "",
        "match_values": json.dumps(CP_CATEGORY2, ensure_ascii=False),
        "match_map": "",
        "note": "CP 协调：CP category2 白名单不进 resistor",
    },
]

EXCLUDE_RULE_IDS = {r["rule_id"] for r in NEW_EXCLUDES}


def patch_diode_cede(row: dict) -> bool:
    if row.get("rule_id") != DIODE_RULE:
        return False
    raw = (row.get("match_values") or "").strip()
    if not raw.startswith("["):
        return False
    vals = json.loads(raw)
    if not isinstance(vals, list):
        return False
    new_vals = [v for v in vals if v not in TVS_CEDE]
    if len(new_vals) == len(vals):
        return False
    row["match_values"] = json.dumps(new_vals, ensure_ascii=False)
    note = (row.get("note") or "").strip()
    suffix = "；TVS/瞬态抑制类已让渡 circuit_protection icpdf gate"
    if suffix not in note:
        row["note"] = (note + suffix) if note else suffix.lstrip("；")
    return True


def array_sql(json_text: str) -> str:
    vals = json.loads(json_text)
    inner = ",".join("'" + str(v).replace("'", "''") + "'" for v in vals)
    return f"ARRAY<VARCHAR(128)>[{inner}]"


def emit_apply_sql(rows: list[dict]) -> None:
    lines = [
        "/* merge 协调：ICPDF circuit_protection · rival gate 让渡",
        " * 在 classify-merge 后执行于 prod dim（与 CP 规则一并生效）",
        " * 生成：patch_icpdf_cp_gate_coordination.py --write",
        " */",
        "",
    ]
    for row in rows:
        if row.get("rule_id") != DIODE_RULE:
            continue
        cg, co = row["clause_group_id"], row["clause_ord"]
        note = row.get("note", "").replace("'", "''")
        lines.append(
            f"UPDATE dim.dim_l3_classify_rule\n"
            f"SET match_values = {array_sql(row['match_values'])},\n"
            f"    note = '{note}'\n"
            f"WHERE rule_id = '{DIODE_RULE}' AND clause_group_id = {cg} AND clause_ord = {co};\n"
        )

    lines.append("-- rival gate exclude 行（幂等：先删后插）")
    for rid in sorted(EXCLUDE_RULE_IDS):
        lines.append(
            f"DELETE FROM dim.dim_l3_classify_rule WHERE rule_id = '{rid}';\n"
        )
    for row in rows:
        if row.get("rule_id") not in EXCLUDE_RULE_IDS:
            continue
        cols = [
            "rule_id", "clause_group_id", "clause_ord", "schema_version", "data_source",
            "rule_kind", "l3_id", "l3_cn", "phase", "rule_priority", "enabled",
            "confidence_weight", "classify_source_hint", "field_code", "match_value",
            "match_values", "match_map", "note",
        ]
        vals = []
        for c in cols:
            v = row.get(c, "")
            if c == "match_values" and v:
                vals.append(array_sql(v))
            elif c in ("l3_id", "l3_cn", "match_value", "match_map") and not v:
                vals.append("NULL")
            elif c == "note":
                vals.append("'" + str(v).replace("'", "''") + "'")
            else:
                vals.append("'" + str(v).replace("'", "''") + "'")
        lines.append(
            f"INSERT INTO dim.dim_l3_classify_rule ({', '.join(cols)})\n"
            f"VALUES ({', '.join(vals)});\n"
        )

    APPLY_SQL.write_text("\n".join(lines), encoding="utf-8")
    print(f"wrote apply SQL -> {APPLY_SQL}")


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser()
    ap.add_argument("--write", action="store_true")
    args = ap.parse_args()

    if not SEED.exists():
        print(f"ERROR: missing {SEED}", file=sys.stderr)
        return 1

    with SEED.open(encoding="utf-8", newline="") as f:
        rows = list(csv.DictReader(f))
    fieldnames = list(rows[0].keys()) if rows else []

    changed = 0
    for row in rows:
        if patch_diode_cede(row):
            changed += 1
            print(f"  patched {DIODE_RULE} clause {row['clause_group_id']}")

    rows = [r for r in rows if r.get("rule_id") not in EXCLUDE_RULE_IDS]
    rows.extend(NEW_EXCLUDES)
    print(f"  ensured {len(NEW_EXCLUDES)} rival gate exclude row(s)")

    if not args.write:
        print("dry-run; re-run with --write")
        return 0

    with SEED.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=fieldnames, extrasaction="ignore")
        w.writeheader()
        w.writerows(rows)
    print(f"wrote seed -> {SEED}")
    emit_apply_sql(rows)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
