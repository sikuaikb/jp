#!/usr/bin/env python3
"""从 DigiKey 抽取规则派生 ICPDF circuit_protection 规则。"""
from __future__ import annotations

import csv
import re
import sys
from collections import Counter
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")

HERE = Path(__file__).resolve().parent
IN_CSV = HERE / "seed" / "dim_attr_extract_rule_circuit_protection.csv"
OUT_CSV = IN_CSV

SCHEMA_VER = "v1.16.01"
L1 = "circuit_protection"
DS = "icpdf"
PREFIX = "cp_"
PREFIX_DK = f"{PREFIX}dk_"
PREFIX_IC = f"{PREFIX}ic_"
LEGACY_DK_PREFIX = "circuit_protection_"

DK_TO_ICPDF: dict[str, str | None] = {
    "零件状态": "生命周期",
    "RoHS 状态": "是否Rohs认证",
    "制造商": "IHS 制造商",
    "制造商产品编号": "Base Number Matches",
    "湿气敏感性等级 (MSL)": "JESD-609代码",
    "封装/外壳": "封装形式",
    "额定电流（安培）": "额定电流",
    "额定电压 - AC": "额定电压（交流）",
    "安装类型": "安装特点",
    "致动器类型": "执行器类型",
    "极数": "极数",
    "断路器类型": None,  # trip_curve_type → EXTRA 电路保护类型（非 fuse 语义 熔断特性）
    "不同频率时电容": None,
    "最大 AC 电压": None,  # MOV → EXTRA 多 key + 宽松 regex
    "压敏电压（典型）": "电路直流最大电压",
    "额定工作温度": "最高工作温度",
    "电压 - 击穿（最小值）": "最小击穿电压",
    "电压 - 反向断态（典型值）": "最大重复峰值反向电压",
    "不同 Ipp 时电压 - 箝位（最大值）": None,  # TVS→最大钳位电压 · EXTRA
    "电流 - 峰值脉冲 (10/1000µs)": None,  # TVS→最大非重复峰值正向电流 · EXTRA
    "功率 - 峰值脉冲": "最大非重复峰值反向功率耗散",
}

SKIP_DK_STD_ATTRS_ON_EXPR: set[tuple[str, str]] = {
    ("temp_min_c", "工作温度"),
    ("temp_max_c", "工作温度"),
    ("lead_free", "RoHS 状态"),
}

ICPDF_VALUE_MAP_OVERRIDE: dict[str, str] = {
    "lifecycle_status": (
        '{"Active":"Active","NRND":"NRND","Obsolete":"Obsolete","EOL":"EOL",'
        '"Preview":"Preview","Transferred":"NRND","End Of Life":"EOL",'
        '"Contact Manufacturer":"Preview","Not Recommended":"NRND",'
        '"Lifetime Buy":"EOL","Unknown":"","'
        '"停产":"Obsolete","在售":"Active","已停产":"EOL","已过时":"Obsolete","_default":""}'
    ),
    "rohs_compliant": (
        '{"符合":"TRUE","不符合":"FALSE","是":"TRUE","否":"FALSE",'
        '"Y":"TRUE","N":"FALSE","_default":""}'
    ),
    "lead_free": (
        '{"不含铅":"TRUE","含铅":"FALSE","无铅":"TRUE","是":"TRUE","否":"FALSE",'
        '"Y":"TRUE","N":"FALSE","_default":""}'
    ),
    "mounting_type": (
        '{"SMD/SMT":"SMD","SURFACE MOUNT":"SMD","表面贴装型":"SMD","表面贴装":"SMD",'
        '"THROUGH HOLE":"Through-Hole","THROUGH HOLE MOUNT":"Through-Hole",'
        '"通孔":"Through-Hole","PCB 安装":"Panel-Mount","面板安装":"Panel-Mount",'
        '"INLINE/HOLDER":"Panel-Mount","PANEL MOUNT":"Panel-Mount",'
        '"PANEL MOUNT-THREADED":"Panel-Mount","PANEL MOUNT/DIN-RAIL MOUNT":"Panel-Mount",'
        '"SOCKET MOUNT":"Panel-Mount","DIN 轨道":"DIN-Rail","DIN RAIL":"DIN-Rail",'
        '"DIN-RAIL MOUNT":"DIN-Rail","_default":""}'
    ),
    "trip_curve_type": (
        '{"THERMAL MAGNETIC":"热磁","MAGNETIC CIRCUIT BREAKER":"磁性(液力延迟)",'
        '"THERMAL CIRCUIT BREAKER":"Other","EQUIPMENT LEAKAGE CIRCUIT BREAKER":"Other",'
        '"_default":""}'
    ),
}

EXTRA_ICPDF = [
    {
        "extract_rule_id": f"{PREFIX_IC}tmin",
        "apply_scope_level": "",
        "apply_scope_code": "",
        "std_attr_code": "temp_min_c",
        "source_expr": "最低工作温度",
        "source_value_regex": r"(-?\d+(?:\.\d+)?)",
        "priority": 5,
        "note": "ICPDF 最低工作温度",
    },
    {
        "extract_rule_id": f"{PREFIX_IC}tmax",
        "apply_scope_level": "",
        "apply_scope_code": "",
        "std_attr_code": "temp_max_c",
        "source_expr": "最高工作温度",
        "source_value_regex": r"(-?\d+(?:\.\d+)?)",
        "priority": 5,
        "note": "ICPDF 最高工作温度",
    },
    {
        "extract_rule_id": f"{PREFIX_IC}leadfree",
        "apply_scope_level": "",
        "apply_scope_code": "",
        "std_attr_code": "lead_free",
        "source_expr": "是否无铅",
        "source_value_regex": "",
        "priority": 10,
        "note": "ICPDF 是否无铅",
    },
    {
        "extract_rule_id": f"{PREFIX_IC}mov_urac",
        "apply_scope_level": "l2",
        "apply_scope_code": "passive_surge_diversion",
        "std_attr_code": "max_continuous_voltage_v",
        "source_expr": "额定（AC）电压（URac）",
        "source_value_regex": r"(-?\d+(?:\.\d+)?)",
        "priority": 8,
        "note": "MOV 最大持续 AC 电压 · 宽松数值 regex",
    },
    {
        "extract_rule_id": f"{PREFIX_IC}mov_vrms",
        "apply_scope_level": "l2",
        "apply_scope_code": "passive_surge_diversion",
        "std_attr_code": "max_continuous_voltage_v",
        "source_expr": "电路RMS最大电压",
        "source_value_regex": r"(-?\d+(?:\.\d+)?)",
        "priority": 9,
        "note": "MOV RMS 电压 fallback",
    },
    {
        "extract_rule_id": f"{PREFIX_IC}mov_varistor2",
        "apply_scope_level": "l3",
        "apply_scope_code": "mov",
        "std_attr_code": "varistor_voltage_v",
        "source_expr": "额定（AC）电压（URac）",
        "source_value_regex": r"(-?\d+(?:\.\d+)?)",
        "priority": 11,
        "note": "MOV 压敏电压弱 fallback",
    },
    {
        "extract_rule_id": f"{PREFIX_IC}tvs_clamp",
        "apply_scope_level": "l3",
        "apply_scope_code": "tvs_diode",
        "std_attr_code": "clamping_voltage_v",
        "source_expr": "最大钳位电压",
        "source_value_regex": r"(-?\d+(?:\.\d+)?)",
        "priority": 8,
        "note": "TVS 箝位电压 · ICPDF 最大钳位电压",
    },
    {
        "extract_rule_id": f"{PREFIX_IC}tvs_ipp",
        "apply_scope_level": "l3",
        "apply_scope_code": "tvs_diode",
        "std_attr_code": "peak_pulse_current_a",
        "source_expr": "最大非重复峰值正向电流",
        "source_value_regex": r"(-?\d+(?:\.\d+)?)\s*A",
        "priority": 8,
        "note": "TVS 峰值脉冲电流",
    },
    {
        "extract_rule_id": f"{PREFIX_IC}tvs_ipp2",
        "apply_scope_level": "l3",
        "apply_scope_code": "tvs_diode",
        "std_attr_code": "peak_pulse_current_a",
        "source_expr": "最大输出电流",
        "source_value_regex": r"(-?\d+(?:\.\d+)?)\s*A",
        "priority": 12,
        "note": "TVS 峰值电流弱 fallback",
    },
    {
        "extract_rule_id": f"{PREFIX_IC}tvs_cap",
        "apply_scope_level": "l3",
        "apply_scope_code": "tvs_diode",
        "std_attr_code": "junction_capacitance_pf",
        "source_expr": "结电容",
        "source_value_regex": r"(-?\d+(?:\.\d+)?)\s*pF",
        "priority": 15,
        "note": "TVS 结电容（ICPDF 少见）",
    },
    {
        "extract_rule_id": f"{PREFIX_IC}cb_trip_type",
        "apply_scope_level": "l3",
        "apply_scope_code": "circuit_breaker",
        "std_attr_code": "trip_curve_type",
        "source_expr": "电路保护类型",
        "source_value_regex": "",
        "priority": 8,
        "note": "断路器脱扣/保护类型 · ICPDF 电路保护类型（非 fuse 熔断特性）",
    },
]

COLS = [
    "extract_rule_id", "data_source", "schema_version", "l1_code",
    "apply_scope_level", "apply_scope_code",
    "std_attr_code", "source_kind", "source_expr",
    "source_value_expr", "source_value_regex", "literal_std_value",
    "priority", "enabled", "value_map", "note",
]


def normalize_dk_rid(rid: str) -> str:
    if rid.startswith(PREFIX_DK):
        return rid
    if rid.startswith(LEGACY_DK_PREFIX):
        return PREFIX_DK + rid[len(LEGACY_DK_PREFIX):]
    if rid.startswith(PREFIX):
        return rid
    return PREFIX_DK + rid


def ic_rid_from_dk(dk_rid: str) -> str:
    return PREFIX_IC + normalize_dk_rid(dk_rid)[len(PREFIX_DK):]


def unique_rid(base: str, seen: set[str]) -> str:
    rid = base
    n = 0
    while rid in seen:
        n += 1
        rid = f"{base}_b{n}"
    seen.add(rid)
    return rid


def assert_prefix(rows: list[dict]) -> None:
    bad = [r["extract_rule_id"] for r in rows if not re.match(r"^cp_", r["extract_rule_id"])]
    if bad:
        raise SystemExit(f"prefix check failed: {bad[:5]}")
    dup = [rid for rid, c in Counter(r["extract_rule_id"] for r in rows).items() if c > 1]
    if dup:
        raise SystemExit(f"duplicate extract_rule_id: {dup[:5]}")


def main() -> None:
    with IN_CSV.open(encoding="utf-8") as f:
        dk_rows = [r for r in csv.DictReader(f) if r["data_source"] == "digikey"]

    for r in dk_rows:
        r["schema_version"] = SCHEMA_VER
        r["extract_rule_id"] = normalize_dk_rid(r["extract_rule_id"])
        note = r.get("note") or ""
        note = note.replace(LEGACY_DK_PREFIX, PREFIX_DK)
        r["note"] = note

    icpdf_rows: list[dict] = []
    seen_ids: set[str] = set()

    for r in dk_rows:
        if r.get("enabled", "1") == "0":
            continue
        if (r["std_attr_code"], r["source_expr"]) in SKIP_DK_STD_ATTRS_ON_EXPR:
            continue
        ic_key = DK_TO_ICPDF.get(r["source_expr"])
        if ic_key is None:
            continue
        rid = unique_rid(ic_rid_from_dk(r["extract_rule_id"]), seen_ids)
        vm = ICPDF_VALUE_MAP_OVERRIDE.get(r["std_attr_code"], r.get("value_map", ""))
        icpdf_rows.append({
            **{c: "" for c in COLS},
            "extract_rule_id": rid,
            "data_source": DS,
            "schema_version": SCHEMA_VER,
            "l1_code": L1,
            "apply_scope_level": r.get("apply_scope_level") or "",
            "apply_scope_code": r.get("apply_scope_code") or "",
            "std_attr_code": r["std_attr_code"],
            "source_kind": "prajson2_key_eq",
            "source_expr": ic_key,
            "source_value_expr": r.get("source_value_expr") or "",
            "source_value_regex": r.get("source_value_regex") or "",
            "literal_std_value": r.get("literal_std_value") or "",
            "priority": r.get("priority") or "10",
            "enabled": "1",
            "value_map": vm,
            "note": (r.get("note") or "") + " · ICPDF prajson2",
        })

    for extra in EXTRA_ICPDF:
        vm = ICPDF_VALUE_MAP_OVERRIDE.get(extra["std_attr_code"], "")
        rid = unique_rid(extra["extract_rule_id"], seen_ids)
        icpdf_rows.append({
            **{c: "" for c in COLS},
            "extract_rule_id": rid,
            "data_source": DS,
            "schema_version": SCHEMA_VER,
            "l1_code": L1,
            "source_kind": "prajson2_key_eq",
            "enabled": "1",
            "value_map": vm,
            "source_value_expr": "",
            "literal_std_value": "",
            **extra,
        })

    merged = dk_rows + icpdf_rows
    assert_prefix(merged)
    with OUT_CSV.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=COLS, lineterminator="\n")
        w.writeheader()
        w.writerows(merged)

    print(f"DK rules: {len(dk_rows)}")
    print(f"ICPDF rules: {len(icpdf_rows)}")
    print(f"Total -> {OUT_CSV}")


if __name__ == "__main__":
    main()
