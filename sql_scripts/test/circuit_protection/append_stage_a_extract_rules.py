#!/usr/bin/env python3
"""阶段 A：追加 fuse/tspd/tvs polarity 的 extract_rule（ICPDF + DK 占位）。"""
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

STAGE_A = [
    # fuse ×4
    {
        "extract_rule_id": "cp_dk_fuse_speed", "data_source": "digikey",
        "apply_scope_level": "l3", "apply_scope_code": "fuse",
        "std_attr_code": "fusing_speed_class", "source_kind": "prajson2_key_eq",
        "source_expr": "熔断速度/特性", "source_value_regex": "",
        "priority": 10, "enabled": "0", "value_map": "", "note": "xlsx · DK 待探针",
    },
    {
        "extract_rule_id": "cp_ic_fuse_speed", "data_source": "icpdf",
        "apply_scope_level": "l3", "apply_scope_code": "fuse",
        "std_attr_code": "fusing_speed_class", "source_kind": "prajson2_key_eq",
        "source_expr": "熔断特性", "source_value_regex": "",
        "priority": 8, "enabled": "1",
        "value_map": (
            '{"FAST":"FAST","MEDIUM":"Medium","SLOW":"Slow","TIME DELAY":"Time-Delay",'
            '"VERY FAST":"Very Fast","TIME LAG":"Time-Lag","STANDARD":"Standard",'
            '"INSTANTANEOUS":"Instantaneous","_default":""}'
        ),
        "note": "xlsx stage A · ICPDF 熔断特性",
    },
    {
        "extract_rule_id": "cp_ic_fuse_i2t", "data_source": "icpdf",
        "apply_scope_level": "l3", "apply_scope_code": "fuse",
        "std_attr_code": "melting_i2t_a2s", "source_kind": "prajson2_key_eq",
        "source_expr": "焦耳积分标称", "source_value_regex": r"(-?\d+(?:\.\d+)?)\s*J",
        "priority": 8, "enabled": "1", "value_map": "",
        "note": "xlsx stage A · 熔断积分",
    },
    {
        "extract_rule_id": "cp_ic_fuse_cold_r", "data_source": "icpdf",
        "apply_scope_level": "l3", "apply_scope_code": "fuse",
        "std_attr_code": "cold_resistance_mohm", "source_kind": "prajson2_key_eq",
        "source_expr": "电阻", "source_value_regex": r"(-?\d+(?:\.\d+)?)\s*(?:mΩ|mOhm|mohm|Ω)?",
        "priority": 12, "enabled": "1", "value_map": "",
        "note": "xlsx stage A · 冷态电阻弱 fallback",
    },
    {
        "extract_rule_id": "cp_ic_fuse_vtype_ac", "data_source": "icpdf",
        "apply_scope_level": "l3", "apply_scope_code": "fuse",
        "std_attr_code": "voltage_type", "source_kind": "prajson2_key_eq",
        "source_expr": "额定电压（交流）", "source_value_regex": "",
        "priority": 10, "enabled": "1", "value_map": '{"_default":"AC"}',
        "note": "xlsx stage A · 有 AC 额定→AC",
    },
    {
        "extract_rule_id": "cp_ic_fuse_vtype_dc", "data_source": "icpdf",
        "apply_scope_level": "l3", "apply_scope_code": "fuse",
        "std_attr_code": "voltage_type", "source_kind": "prajson2_key_eq",
        "source_expr": "额定电压（直流）", "source_value_regex": "",
        "priority": 11, "enabled": "1", "value_map": '{"_default":"DC"}',
        "note": "xlsx stage A · 有 DC 额定→DC（低优先级）",
    },
    # tspd ×5
    {
        "extract_rule_id": "cp_ic_tspd_trigger_v", "data_source": "icpdf",
        "apply_scope_level": "l3", "apply_scope_code": "tspd",
        "std_attr_code": "trigger_voltage_v", "source_kind": "prajson2_key_eq",
        "source_expr": "最大转折电压", "source_value_regex": r"(-?\d+(?:\.\d+)?)\s*V?",
        "priority": 8, "enabled": "1", "value_map": "",
        "note": "xlsx stage A · TSPD 触发电压",
    },
    {
        "extract_rule_id": "cp_ic_tspd_hold_i", "data_source": "icpdf",
        "apply_scope_level": "l3", "apply_scope_code": "tspd",
        "std_attr_code": "holding_current_ma", "source_kind": "prajson2_key_eq",
        "source_expr": "最大维持电流", "source_value_regex": r"(-?\d+(?:\.\d+)?)\s*(?:mA|A)?",
        "priority": 8, "enabled": "1", "value_map": "",
        "note": "xlsx stage A · 维持电流",
    },
    {
        "extract_rule_id": "cp_ic_tspd_on_v", "data_source": "icpdf",
        "apply_scope_level": "l3", "apply_scope_code": "tspd",
        "std_attr_code": "on_state_voltage_v", "source_kind": "prajson2_key_eq",
        "source_expr": "最大通态电压", "source_value_regex": r"(-?\d+(?:\.\d+)?)\s*V?",
        "priority": 9, "enabled": "1", "value_map": "",
        "note": "xlsx stage A · 导通压降/通态电压",
    },
    {
        "extract_rule_id": "cp_ic_tspd_surge_i", "data_source": "icpdf",
        "apply_scope_level": "l3", "apply_scope_code": "tspd",
        "std_attr_code": "surge_current_8_20us_a", "source_kind": "prajson2_key_eq",
        "source_expr": "通态非重复峰值电流", "source_value_regex": r"(-?\d+(?:\.\d+)?)\s*A",
        "priority": 8, "enabled": "1", "value_map": "",
        "note": "xlsx stage A · 8/20µs 浪涌通流",
    },
    {
        "extract_rule_id": "cp_ic_tspd_dvdt", "data_source": "icpdf",
        "apply_scope_level": "l3", "apply_scope_code": "tspd",
        "std_attr_code": "dv_dt_withstand_v_us", "source_kind": "prajson2_key_eq",
        "source_expr": "dv/dt", "source_value_regex": r"(-?\d+(?:\.\d+)?)",
        "priority": 15, "enabled": "1", "value_map": "",
        "note": "xlsx stage A · dv/dt（ICPDF 少见，占位）",
    },
    # tvs polarity
    {
        "extract_rule_id": "cp_ic_tvs_polarity", "data_source": "icpdf",
        "apply_scope_level": "l3", "apply_scope_code": "tvs_diode",
        "std_attr_code": "polarity_type", "source_kind": "prajson2_key_eq",
        "source_expr": "极性", "source_value_regex": "",
        "priority": 8, "enabled": "1",
        "value_map": (
            '{"UNIDIRECTIONAL":"Unidirectional","BIDIRECTIONAL":"Bidirectional",'
            '"单向":"Unidirectional","双向":"Bidirectional","_default":""}'
        ),
        "note": "xlsx stage A · TVS 极性",
    },
]


def main() -> None:
    with RULE_CSV.open(encoding="utf-8") as f:
        rows = list(csv.DictReader(f))
    existing_ids = {r["extract_rule_id"] for r in rows}
    added = 0
    for spec in STAGE_A:
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
    rows.sort(key=lambda r: (r["data_source"], r.get("apply_scope_code", ""), r["std_attr_code"], r["extract_rule_id"]))
    with RULE_CSV.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=COLS, lineterminator="\n")
        w.writeheader()
        w.writerows(rows)
    print(f"stage A rules merged -> {RULE_CSV} (+{added} specs)")


if __name__ == "__main__":
    main()
