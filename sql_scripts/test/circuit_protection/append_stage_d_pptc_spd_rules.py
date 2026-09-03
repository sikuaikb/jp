#!/usr/bin/env python3
"""阶段 D：pptc extract_rule + spd 占位（classify 见 classify_config）。"""
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

NUM_A = r"(-?\d+(?:\.\d+)?)\s*(?:A|a|mA|mA)?"
NUM_OHM = r"(-?\d+(?:\.\d+)?)\s*(?:Ω|Ohm|ohm|mΩ|mOhm)?"
NUM_S = r"(-?\d+(?:\.\d+)?)\s*(?:s|sec|秒)?"

STAGE_D = [
    # pptc ×5（prajson cn · ICPDF gate 内 ~2.8k 行）
    {
        "extract_rule_id": "cp_ic_pptc_hold_i",
        "data_source": "icpdf", "apply_scope_level": "l3", "apply_scope_code": "pptc_resettable_fuse",
        "std_attr_code": "hold_current_a", "source_kind": "prajson_cn_eq",
        "source_expr": "保持电流", "source_value_regex": NUM_A,
        "priority": 8, "enabled": "1",
        "note": "xlsx stage D · PPTC 保持电流 · cn",
    },
    {
        "extract_rule_id": "cp_ic_pptc_hold_i_max",
        "data_source": "icpdf", "apply_scope_level": "l3", "apply_scope_code": "pptc_resettable_fuse",
        "std_attr_code": "hold_current_a", "source_kind": "prajson_cn_eq",
        "source_expr": "保持电流(Max)", "source_value_regex": NUM_A,
        "priority": 10, "enabled": "1",
        "note": "xlsx stage D · PPTC 保持电流 fallback",
    },
    {
        "extract_rule_id": "cp_ic_pptc_trip_i",
        "data_source": "icpdf", "apply_scope_level": "l3", "apply_scope_code": "pptc_resettable_fuse",
        "std_attr_code": "trip_current_a", "source_kind": "prajson_cn_eq",
        "source_expr": "跳闸电流", "source_value_regex": NUM_A,
        "priority": 8, "enabled": "1",
        "note": "xlsx stage D · PPTC 触发电流 · cn 跳闸电流",
    },
    {
        "extract_rule_id": "cp_ic_pptc_r_init",
        "data_source": "icpdf", "apply_scope_level": "l3", "apply_scope_code": "pptc_resettable_fuse",
        "std_attr_code": "resistance_max_initial_ohm", "source_kind": "prajson_cn_eq",
        "source_expr": "电阻", "source_value_regex": NUM_OHM,
        "priority": 9, "enabled": "1",
        "note": "xlsx stage D · PPTC 初始电阻 · cn 电阻",
    },
    {
        "extract_rule_id": "cp_ic_pptc_r_dc",
        "data_source": "icpdf", "apply_scope_level": "l3", "apply_scope_code": "pptc_resettable_fuse",
        "std_attr_code": "resistance_max_initial_ohm", "source_kind": "prajson_cn_eq",
        "source_expr": "电阻(DC）", "source_value_regex": NUM_OHM,
        "priority": 10, "enabled": "1",
        "note": "xlsx stage D · PPTC 初始电阻 fallback",
    },
    {
        "extract_rule_id": "cp_ic_pptc_r_trip",
        "data_source": "icpdf", "apply_scope_level": "l3", "apply_scope_code": "pptc_resettable_fuse",
        "std_attr_code": "resistance_max_tripped_ohm", "source_kind": "prajson_cn_eq",
        "source_expr": "跳闸后电阻", "source_value_regex": NUM_OHM,
        "priority": 12, "enabled": "0",
        "note": "xlsx stage D · ICPDF 少见 key · 占位",
    },
    {
        "extract_rule_id": "cp_ic_pptc_reset_t",
        "data_source": "icpdf", "apply_scope_level": "l3", "apply_scope_code": "pptc_resettable_fuse",
        "std_attr_code": "reset_time_s", "source_kind": "prajson_cn_eq",
        "source_expr": "复位时间", "source_value_regex": NUM_S,
        "priority": 12, "enabled": "0",
        "note": "xlsx stage D · ICPDF 无复位时间 key · 占位",
    },
    # spd ×9 占位（L2 宽表未建 · 源端 ~19 行）
    {
        "extract_rule_id": "cp_ic_spd_class",
        "data_source": "icpdf", "apply_scope_level": "l3", "apply_scope_code": "spd_module",
        "std_attr_code": "spd_class", "source_kind": "prajson_cn_eq",
        "source_expr": "SPD分类", "source_value_regex": "",
        "priority": 12, "enabled": "0",
        "note": "xlsx stage D · spd L2 未建 · 占位",
    },
]


def main() -> None:
    with RULE_CSV.open(encoding="utf-8") as f:
        rows = list(csv.DictReader(f))
    existing_ids = {r["extract_rule_id"] for r in rows}
    added = 0
    for spec in STAGE_D:
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
        key=lambda r: (r["data_source"], r.get("apply_scope_code", ""), r["std_attr_code"], r["extract_rule_id"])
    )
    with RULE_CSV.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=COLS, lineterminator="\n")
        w.writeheader()
        w.writerows(rows)
    print(f"stage D rules merged -> {RULE_CSV} (+{added} specs)")


if __name__ == "__main__":
    main()
