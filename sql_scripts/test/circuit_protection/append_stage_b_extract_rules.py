#!/usr/bin/env python3
"""阶段 B：mov/tvs/breaker 共 8 字段 extract_rule（ICPDF prajson2 + prajson cn）。"""
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

STAGE_B = [
    # mov ×4
    {
        "extract_rule_id": "cp_ic_mov_tol_pct",
        "data_source": "icpdf", "apply_scope_level": "l3", "apply_scope_code": "mov",
        "std_attr_code": "varistor_voltage_tolerance_pct", "source_kind": "prajson2_key_eq",
        "source_expr": "容差", "source_value_regex": r"(-?\d+(?:\.\d+)?)\s*%?",
        "priority": 8, "enabled": "1",
        "note": "xlsx stage B · MOV 压敏电压公差 · prajson2 容差 25%",
    },
    {
        "extract_rule_id": "cp_ic_mov_clamp_cn",
        "data_source": "icpdf", "apply_scope_level": "l3", "apply_scope_code": "mov",
        "std_attr_code": "clamping_voltage_max_v", "source_kind": "prajson_cn_eq",
        "source_expr": "钳位电压", "source_value_regex": r"(-?\d+(?:\.\d+)?)\s*V?",
        "priority": 8, "enabled": "1",
        "note": "xlsx stage B · MOV 最大钳位电压 · prajson cn 钳位电压 ~45%",
    },
    {
        "extract_rule_id": "cp_ic_mov_leak_ua",
        "data_source": "icpdf", "apply_scope_level": "l3", "apply_scope_code": "mov",
        "std_attr_code": "leakage_current_max_ua", "source_kind": "prajson2_key_eq",
        "source_expr": "漏电流", "source_value_regex": r"(-?\d+(?:\.\d+)?)\s*(?:µA|uA|μA|A|mA)?",
        "priority": 12, "enabled": "0",
        "note": "xlsx stage B · ICPDF 无 MOV 漏电流 key · 占位",
    },
    {
        "extract_rule_id": "cp_ic_mov_surge_life",
        "data_source": "icpdf", "apply_scope_level": "l3", "apply_scope_code": "mov",
        "std_attr_code": "surge_life_cycles", "source_kind": "prajson2_key_eq",
        "source_expr": "浪涌寿命", "source_value_regex": r"(-?\d+(?:\.\d+)?)",
        "priority": 12, "enabled": "0",
        "note": "xlsx stage B · ICPDF 无 MOV 浪涌寿命 key · 占位",
    },
    # tvs ×2
    {
        "extract_rule_id": "cp_ic_tvs_rev_leak",
        "data_source": "icpdf", "apply_scope_level": "l3", "apply_scope_code": "tvs_diode",
        "std_attr_code": "reverse_leakage_current_ua", "source_kind": "prajson2_key_eq",
        "source_expr": "最大反向电流", "source_value_regex": r"(-?\d+(?:\.\d+)?)\s*(?:µA|uA|μA|mA|A)?",
        "priority": 8, "enabled": "1",
        "note": "xlsx stage B · TVS 反向漏电流 · prajson2 5%",
    },
    {
        "extract_rule_id": "cp_ic_tvs_rev_leak_cn",
        "data_source": "icpdf", "apply_scope_level": "l3", "apply_scope_code": "tvs_diode",
        "std_attr_code": "reverse_leakage_current_ua", "source_kind": "prajson_cn_eq",
        "source_expr": "最大反向漏电流（Ir）", "source_value_regex": r"(-?\d+(?:\.\d+)?)\s*(?:µA|uA|μA|mA|A)?",
        "priority": 10, "enabled": "1",
        "note": "xlsx stage B · TVS 反向漏电流 · prajson cn fallback",
    },
    {
        "extract_rule_id": "cp_ic_tvs_bd_tol",
        "data_source": "icpdf", "apply_scope_level": "l3", "apply_scope_code": "tvs_diode",
        "std_attr_code": "breakdown_voltage_tolerance_pct", "source_kind": "prajson2_key_eq",
        "source_expr": "最大电压容差", "source_value_regex": r"(-?\d+(?:\.\d+)?)\s*%?",
        "priority": 8, "enabled": "1",
        "note": "xlsx stage B · TVS 击穿电压容差 · prajson2 弱 0.2%",
    },
    {
        "extract_rule_id": "cp_ic_tvs_bd_tol_cn",
        "data_source": "icpdf", "apply_scope_level": "l3", "apply_scope_code": "tvs_diode",
        "std_attr_code": "breakdown_voltage_tolerance_pct", "source_kind": "prajson_cn_eq",
        "source_expr": "容差", "source_value_regex": r"(-?\d+(?:\.\d+)?)\s*%?",
        "priority": 12, "enabled": "1",
        "note": "xlsx stage B · TVS 击穿容差 · prajson cn 容差 fallback",
    },
    # breaker ×2
    {
        "extract_rule_id": "cp_ic_cb_iccn",
        "data_source": "icpdf", "apply_scope_level": "l3", "apply_scope_code": "circuit_breaker",
        "std_attr_code": "rated_short_circuit_capacity_ka", "source_kind": "prajson2_key_eq",
        "source_expr": "额定分断能力", "source_value_regex": r"(-?\d+(?:\.\d+)?)\s*(?:A|kA)?",
        "priority": 8, "enabled": "1",
        "note": "xlsx stage B · 断路器 Icn · prajson2 额定分断能力 15% · A→kA",
    },
    {
        "extract_rule_id": "cp_dk_cb_inst_trip",
        "data_source": "digikey", "apply_scope_level": "l3", "apply_scope_code": "circuit_breaker",
        "std_attr_code": "instantaneous_trip_current_min_x", "source_kind": "prajson2_key_eq",
        "source_expr": "断路器类型", "source_value_regex": "",
        "priority": 10, "enabled": "0",
        "value_map": (
            '{"B CURVE":"3","C CURVE":"5","D CURVE":"10","K CURVE":"10","Z CURVE":"2",'
            '"B":"3","C":"5","D":"10","K":"10","Z":"2","_default":""}'
        ),
        "note": "xlsx stage B · DK 断路器曲线→瞬时脱扣倍数 · 待探针 value_map",
    },
    {
        "extract_rule_id": "cp_ic_cb_inst_trip",
        "data_source": "icpdf", "apply_scope_level": "l3", "apply_scope_code": "circuit_breaker",
        "std_attr_code": "instantaneous_trip_current_min_x", "source_kind": "prajson2_key_eq",
        "source_expr": "瞬时脱扣倍数", "source_value_regex": r"(-?\d+(?:\.\d+)?)",
        "priority": 12, "enabled": "0",
        "note": "xlsx stage B · ICPDF 无 B/C/D 曲线倍数 key · 占位",
    },
]


def merge_rules(specs: list[dict]) -> int:
    with RULE_CSV.open(encoding="utf-8") as f:
        rows = list(csv.DictReader(f))
    existing_ids = {r["extract_rule_id"] for r in rows}
    added = 0
    for spec in specs:
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
    return added


def main() -> None:
    n = merge_rules(STAGE_B)
    print(f"stage B rules merged -> {RULE_CSV} (+{n} specs)")


if __name__ == "__main__":
    main()
