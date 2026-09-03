#!/usr/bin/env python3
"""阶段 C：gdt / esd_suppressor extract_rule（ICPDF prajson2 + prajson cn）。"""
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

NUM_V = r"(-?\d+(?:\.\d+)?)\s*(?:kV|kVDC|V|VDC)?"
NUM_PF = r"(-?\d+(?:\.\d+)?)\s*(?:pF|pf|PF)?"
NUM_INT = r"(-?\d+(?:\.\d+)?)"
NUM_GOHM = r"(-?\d+(?:\.\d+)?)\s*(?:GΩ|GOhm|gohm|MΩ|MOhm|mohm|Ω|Ohm)?"

STAGE_C = [
    # gdt ×6（ICPDF 电信 metadata 为主，电气 key 在 prajson cn）
    {
        "extract_rule_id": "cp_ic_gdt_dc_spark_kv",
        "data_source": "icpdf", "apply_scope_level": "l3", "apply_scope_code": "gdt",
        "std_attr_code": "dc_sparkover_voltage_v", "source_kind": "prajson_cn_eq",
        "source_expr": "DC-Sparkover", "source_value_regex": NUM_V,
        "priority": 5, "enabled": "1",
        "note": "xlsx stage C · GDT DC 击穿 · prajson cn DC-Sparkover",
    },
    {
        "extract_rule_id": "cp_ic_gdt_dc_spark_v",
        "data_source": "icpdf", "apply_scope_level": "l3", "apply_scope_code": "gdt",
        "std_attr_code": "dc_sparkover_voltage_v", "source_kind": "prajson_cn_eq",
        "source_expr": "击穿电压", "source_value_regex": NUM_V,
        "priority": 8, "enabled": "1",
        "note": "xlsx stage C · GDT DC 击穿 fallback · cn 击穿电压 6%",
    },
    {
        "extract_rule_id": "cp_ic_gdt_impulse_v",
        "data_source": "icpdf", "apply_scope_level": "l3", "apply_scope_code": "gdt",
        "std_attr_code": "impulse_sparkover_voltage_v", "source_kind": "prajson_cn_eq",
        "source_expr": "Impulse-Sparkover", "source_value_regex": NUM_V,
        "priority": 8, "enabled": "0",
        "note": "xlsx stage C · ICPDF 无冲击击穿 key · 占位",
    },
    {
        "extract_rule_id": "cp_ic_gdt_arc_v",
        "data_source": "icpdf", "apply_scope_level": "l3", "apply_scope_code": "gdt",
        "std_attr_code": "arc_voltage_v", "source_kind": "prajson_cn_eq",
        "source_expr": "弧光电压", "source_value_regex": NUM_V,
        "priority": 10, "enabled": "0",
        "note": "xlsx stage C · ICPDF 无弧光维持电压 key · 占位",
    },
    {
        "extract_rule_id": "cp_ic_gdt_follow_i",
        "data_source": "icpdf", "apply_scope_level": "l3", "apply_scope_code": "gdt",
        "std_attr_code": "follow_current_interrupt_a", "source_kind": "prajson_cn_eq",
        "source_expr": "续流遮断", "source_value_regex": r"(-?\d+(?:\.\d+)?)\s*A?",
        "priority": 10, "enabled": "0",
        "note": "xlsx stage C · ICPDF 无续流遮断 key · 占位",
    },
    {
        "extract_rule_id": "cp_ic_gdt_insul_gohm",
        "data_source": "icpdf", "apply_scope_level": "l3", "apply_scope_code": "gdt",
        "std_attr_code": "insulation_resistance_gohm", "source_kind": "prajson_cn_eq",
        "source_expr": "绝缘电阻", "source_value_regex": NUM_GOHM,
        "priority": 8, "enabled": "1",
        "note": "xlsx stage C · GDT 绝缘电阻 · cn 28%",
    },
    {
        "extract_rule_id": "cp_ic_gdt_pole_cn",
        "data_source": "icpdf", "apply_scope_level": "l3", "apply_scope_code": "gdt",
        "std_attr_code": "pole_count", "source_kind": "prajson_cn_eq",
        "source_expr": "引脚数", "source_value_regex": NUM_INT,
        "priority": 9, "enabled": "1",
        "note": "xlsx stage C · GDT 极数弱 proxy · cn 引脚数",
    },
    {
        "extract_rule_id": "cp_ic_gdt_pole_elec",
        "data_source": "icpdf", "apply_scope_level": "l3", "apply_scope_code": "gdt",
        "std_attr_code": "pole_count", "source_kind": "prajson_cn_eq",
        "source_expr": "Number-of-Electrodes", "source_value_regex": r"(\d+)",
        "priority": 7, "enabled": "1",
        "note": "xlsx stage C · GDT 电极数 · cn Number-of-Electrodes",
    },
    # esd ×6
    {
        "extract_rule_id": "cp_ic_esd_clamp_cn",
        "data_source": "icpdf", "apply_scope_level": "l3", "apply_scope_code": "esd_suppressor",
        "std_attr_code": "clamping_voltage_v", "source_kind": "prajson_cn_eq",
        "source_expr": "钳位电压", "source_value_regex": r"(-?\d+(?:\.\d+)?)\s*V?",
        "priority": 8, "enabled": "1",
        "note": "xlsx stage C · ESD 钳位电压 · cn 59%",
    },
    {
        "extract_rule_id": "cp_ic_esd_clamp2",
        "data_source": "icpdf", "apply_scope_level": "l3", "apply_scope_code": "esd_suppressor",
        "std_attr_code": "clamping_voltage_v", "source_kind": "prajson2_key_eq",
        "source_expr": "最大钳位电压", "source_value_regex": r"(-?\d+(?:\.\d+)?)\s*V?",
        "priority": 10, "enabled": "1",
        "note": "xlsx stage C · ESD 钳位 · prajson2 35%",
    },
    {
        "extract_rule_id": "cp_ic_esd_cap_cn",
        "data_source": "icpdf", "apply_scope_level": "l3", "apply_scope_code": "esd_suppressor",
        "std_attr_code": "junction_capacitance_pf", "source_kind": "prajson_cn_eq",
        "source_expr": "电容", "source_value_regex": NUM_PF,
        "priority": 8, "enabled": "1",
        "note": "xlsx stage C · ESD 结电容 · cn 电容 56%",
    },
    {
        "extract_rule_id": "cp_ic_esd_cap2",
        "data_source": "icpdf", "apply_scope_level": "l3", "apply_scope_code": "esd_suppressor",
        "std_attr_code": "junction_capacitance_pf", "source_kind": "prajson2_key_eq",
        "source_expr": "最小二极管电容", "source_value_regex": NUM_PF,
        "priority": 10, "enabled": "1",
        "note": "xlsx stage C · ESD 结电容 · prajson2 1%",
    },
    {
        "extract_rule_id": "cp_ic_esd_cap_in",
        "data_source": "icpdf", "apply_scope_level": "l3", "apply_scope_code": "esd_suppressor",
        "std_attr_code": "junction_capacitance_pf", "source_kind": "prajson_cn_eq",
        "source_expr": "输入电容", "source_value_regex": NUM_PF,
        "priority": 12, "enabled": "1",
        "note": "xlsx stage C · ESD 结电容 fallback · cn 输入电容",
    },
    {
        "extract_rule_id": "cp_ic_esd_ch_cn",
        "data_source": "icpdf", "apply_scope_level": "l3", "apply_scope_code": "esd_suppressor",
        "std_attr_code": "channel_count", "source_kind": "prajson_cn_eq",
        "source_expr": "通道数", "source_value_regex": NUM_INT,
        "priority": 8, "enabled": "1",
        "note": "xlsx stage C · ESD 保护通道数 · cn 21%",
    },
    {
        "extract_rule_id": "cp_ic_esd_ch_circ",
        "data_source": "icpdf", "apply_scope_level": "l3", "apply_scope_code": "esd_suppressor",
        "std_attr_code": "channel_count", "source_kind": "prajson_cn_eq",
        "source_expr": "电路数", "source_value_regex": NUM_INT,
        "priority": 11, "enabled": "1",
        "note": "xlsx stage C · ESD 通道 fallback · cn 电路数 28%",
    },
    {
        "extract_rule_id": "cp_ic_esd_iec_contact",
        "data_source": "icpdf", "apply_scope_level": "l3", "apply_scope_code": "esd_suppressor",
        "std_attr_code": "iec_61000_4_2_contact_kv", "source_kind": "prajson2_key_eq",
        "source_expr": "IEC 61000-4-2 接触放电", "source_value_regex": NUM_V,
        "priority": 8, "enabled": "0",
        "note": "xlsx stage C · ICPDF 无 IEC 接触放电 key · 占位",
    },
    {
        "extract_rule_id": "cp_ic_esd_iec_air",
        "data_source": "icpdf", "apply_scope_level": "l3", "apply_scope_code": "esd_suppressor",
        "std_attr_code": "iec_61000_4_2_air_kv", "source_kind": "prajson2_key_eq",
        "source_expr": "IEC 61000-4-2 空气放电", "source_value_regex": NUM_V,
        "priority": 8, "enabled": "0",
        "note": "xlsx stage C · ICPDF 无 IEC 空气放电 key · 占位",
    },
    {
        "extract_rule_id": "cp_ic_esd_dyn_r",
        "data_source": "icpdf", "apply_scope_level": "l3", "apply_scope_code": "esd_suppressor",
        "std_attr_code": "dynamic_on_resistance_ohm", "source_kind": "prajson_cn_eq",
        "source_expr": "动态电阻", "source_value_regex": r"(-?\d+(?:\.\d+)?)\s*(?:Ω|Ohm|ohm)?",
        "priority": 10, "enabled": "0",
        "note": "xlsx stage C · ICPDF 无动态导通电阻 key · 占位",
    },
]


def main() -> None:
    with RULE_CSV.open(encoding="utf-8") as f:
        rows = list(csv.DictReader(f))
    existing_ids = {r["extract_rule_id"] for r in rows}
    added = 0
    for spec in STAGE_C:
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
    print(f"stage C rules merged -> {RULE_CSV} (+{added} specs)")


if __name__ == "__main__":
    main()
