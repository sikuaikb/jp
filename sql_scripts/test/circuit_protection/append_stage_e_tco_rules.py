#!/usr/bin/env python3
"""阶段 E：thermal_cutoff 额定动作温度规则修复 + EYP partno 补充。"""
from __future__ import annotations

import csv
import sys
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")

HERE = Path(__file__).resolve().parent
RULE_CSV = HERE / "seed" / "dim_attr_extract_rule_circuit_protection.csv"
SCHEMA_VER = "v1.16.01"
L1 = "circuit_protection"

COLS = [
    "extract_rule_id", "data_source", "schema_version", "l1_code",
    "apply_scope_level", "apply_scope_code",
    "std_attr_code", "source_kind", "source_expr",
    "source_value_expr", "source_value_regex", "literal_std_value",
    "priority", "enabled", "value_map", "note",
]

STAGE_E = [
    {
        "extract_rule_id": "cp_ic_tco_rated_temp",
        "data_source": "icpdf",
        "apply_scope_level": "l3",
        "apply_scope_code": "thermal_cutoff",
        "std_attr_code": "rated_function_temp_c",
        "source_kind": "prajson2_key_eq",
        "source_expr": "额定工作温度",
        "source_value_regex": r"(\d+(?:\.\d+)?)\s*(?:°C|℃|C|°F|℉|F)?",
        "priority": 8,
        "enabled": "1",
        "note": "stage E · 额定工作温度→动作温度（对齐 DK 语义）",
    },
    {
        "extract_rule_id": "cp_ic_tco_rated_action_temp",
        "data_source": "icpdf",
        "apply_scope_level": "l3",
        "apply_scope_code": "thermal_cutoff",
        "std_attr_code": "rated_function_temp_c",
        "source_kind": "prajson2_key_eq",
        "source_expr": "额定动作温度",
        "source_value_regex": r"(\d+(?:\.\d+)?)\s*(?:°C|℃|C|°F|℉|F)?",
        "priority": 9,
        "enabled": "1",
        "note": "stage E · 额定动作温度",
    },
    {
        "extract_rule_id": "cp_ic_tco_action_temp",
        "data_source": "icpdf",
        "apply_scope_level": "l3",
        "apply_scope_code": "thermal_cutoff",
        "std_attr_code": "rated_function_temp_c",
        "source_kind": "prajson2_key_eq",
        "source_expr": "动作温度",
        "source_value_regex": r"(\d+(?:\.\d+)?)\s*(?:°C|℃|C|°F|℉|F)?",
        "priority": 10,
        "enabled": "1",
        "note": "stage E · 动作温度",
    },
    {
        "extract_rule_id": "cp_ic_tco_max_temp_weak",
        "data_source": "icpdf",
        "apply_scope_level": "l3",
        "apply_scope_code": "thermal_cutoff",
        "std_attr_code": "rated_function_temp_c",
        "source_kind": "prajson2_key_eq",
        "source_expr": "最高工作温度",
        "source_value_regex": r"(\d+(?:\.\d+)?)\s*(?:°C|℃|C|°F|℉|F)?",
        "priority": 20,
        "enabled": "1",
        "note": "stage E · 最高工作温度弱 fallback（运行上限≠动作温度，低优先级）",
    },
]


def main() -> None:
    with RULE_CSV.open(encoding="utf-8") as f:
        rows = list(csv.DictReader(f))
    existing_ids = {r["extract_rule_id"] for r in rows}
    added = 0
    for spec in STAGE_E:
        rid = spec["extract_rule_id"]
        if rid in existing_ids:
            rows = [r for r in rows if r["extract_rule_id"] != rid]
        row = {c: "" for c in COLS}
        row.update({k: spec.get(k, "") for k in COLS if k in spec})
        row["schema_version"] = SCHEMA_VER
        row["l1_code"] = L1
        row["enabled"] = spec.get("enabled", "1")
        rows.append(row)
        existing_ids.add(rid)
        added += 1
    rows.sort(
        key=lambda r: (
            r["data_source"],
            r.get("apply_scope_code", ""),
            r["std_attr_code"],
            r["extract_rule_id"],
        )
    )
    with RULE_CSV.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=COLS, lineterminator="\n")
        w.writeheader()
        w.writerows(rows)
    print(f"stage E rules merged -> {RULE_CSV} (+{added} specs)")


if __name__ == "__main__":
    main()
