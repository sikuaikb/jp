#!/usr/bin/env python3
"""阶段 F：pptc hold/trip mA 换算 + prajson2 电阻 + partno 补充（探针驱动）。"""
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

NUM_MA = r"(-?\d+(?:\.\d+)?)\s*mA"
NUM_A = r"(-?\d+(?:\.\d+)?)\s*A"
NUM_A_LOOSE = r"(-?\d+(?:\.\d+)?)\s*(?:A|a|mA|mA)?"
NUM_OHM = r"(-?\d+(?:\.\d+)?)\s*(?:Ω|Ohm|ohm|mΩ|mOhm)?"

STAGE_F = [
    # hold · prajson cn（宽松 regex + dim_unit_factor mA→A）
    {
        "extract_rule_id": "cp_ic_pptc_hold_i",
        "data_source": "icpdf", "apply_scope_level": "l3", "apply_scope_code": "pptc_resettable_fuse",
        "std_attr_code": "hold_current_a", "source_kind": "prajson_cn_eq",
        "source_expr": "保持电流", "source_value_regex": "",
        "priority": 8, "enabled": "1",
        "note": "stage F · 保持电流 · 全值解析 mA→A",
    },
    {
        "extract_rule_id": "cp_ic_pptc_hold_i_max",
        "data_source": "icpdf", "apply_scope_level": "l3", "apply_scope_code": "pptc_resettable_fuse",
        "std_attr_code": "hold_current_a", "source_kind": "prajson_cn_eq",
        "source_expr": "保持电流(Max)", "source_value_regex": "",
        "priority": 10, "enabled": "1",
        "note": "stage F · 保持电流(Max)",
    },
    {
        "extract_rule_id": "cp_ic_pptc_hold_i_max_cn2",
        "data_source": "icpdf", "apply_scope_level": "l3", "apply_scope_code": "pptc_resettable_fuse",
        "std_attr_code": "hold_current_a", "source_kind": "prajson_cn_eq",
        "source_expr": "保持电流（Max）", "source_value_regex": "",
        "priority": 11, "enabled": "1",
        "note": "stage F · 全角括号变体",
    },
    # trip · prajson cn
    {
        "extract_rule_id": "cp_ic_pptc_trip_i",
        "data_source": "icpdf", "apply_scope_level": "l3", "apply_scope_code": "pptc_resettable_fuse",
        "std_attr_code": "trip_current_a", "source_kind": "prajson_cn_eq",
        "source_expr": "跳闸电流", "source_value_regex": "",
        "priority": 8, "enabled": "1",
        "note": "stage F · 跳闸电流 · 全值解析 mA→A",
    },
    # resistance · prajson cn（保留）
    {
        "extract_rule_id": "cp_ic_pptc_r_init",
        "data_source": "icpdf", "apply_scope_level": "l3", "apply_scope_code": "pptc_resettable_fuse",
        "std_attr_code": "resistance_max_initial_ohm", "source_kind": "prajson_cn_eq",
        "source_expr": "电阻", "source_value_regex": NUM_OHM,
        "priority": 9, "enabled": "1",
        "note": "stage F · prajson cn 电阻",
    },
    {
        "extract_rule_id": "cp_ic_pptc_r_dc",
        "data_source": "icpdf", "apply_scope_level": "l3", "apply_scope_code": "pptc_resettable_fuse",
        "std_attr_code": "resistance_max_initial_ohm", "source_kind": "prajson_cn_eq",
        "source_expr": "电阻(DC）", "source_value_regex": NUM_OHM,
        "priority": 10, "enabled": "1",
        "note": "stage F · prajson cn 电阻 DC",
    },
    # resistance · prajson2（~7.8k 行 · 探针主增益）
    {
        "extract_rule_id": "cp_ic_pptc_r_pj2",
        "data_source": "icpdf", "apply_scope_level": "l3", "apply_scope_code": "pptc_resettable_fuse",
        "std_attr_code": "resistance_max_initial_ohm", "source_kind": "prajson2_key_eq",
        "source_expr": "电阻", "source_value_regex": NUM_OHM,
        "priority": 11, "enabled": "1",
        "note": "stage F · prajson2 电阻 · ~7830 行",
    },
]


def main() -> None:
    with RULE_CSV.open(encoding="utf-8") as f:
        rows = list(csv.DictReader(f))
    replace_ids = {s["extract_rule_id"] for s in STAGE_F}
    rows = [r for r in rows if r["extract_rule_id"] not in replace_ids]
    for spec in STAGE_F:
        row = {c: "" for c in COLS}
        row.update({k: spec.get(k, "") for k in COLS if k in spec})
        row["schema_version"] = SCHEMA_VER
        row["l1_code"] = L1
        row["enabled"] = spec.get("enabled", "1")
        rows.append(row)
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
    print(f"stage F rules merged -> {RULE_CSV} ({len(STAGE_F)} specs)")


if __name__ == "__main__":
    main()
