#!/usr/bin/env python3
"""从 DigiKey 抽取规则派生 ICPDF 规则，追加到 seed CSV。

- prajson2_key_eq：主路径（prajson2 中文 key）
- prajson_sqlname_eq：兜底（无 prajson2 时读 prajson $.sqlname，priority 30+ 低于 prajson2）

用法:
  python gen_attr_extract_rule_icpdf_switch.py
"""
from __future__ import annotations

import csv
import re
import sys
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")

HERE = Path(__file__).resolve().parent
IN_CSV = HERE / "seed" / "dim_attr_extract_rule_switch.csv"
OUT_CSV = IN_CSV  # merge in-place

SCHEMA_VER = "switch_schema_v1.5.28"
L1 = "switch"
DS = "icpdf"
PREFIX = "switch_"
PREFIX_DK = f"{PREFIX}dk_"
PREFIX_IC = f"{PREFIX}ic_"
PREFIX_SN = f"{PREFIX}sn_"
LEGACY_DK_PREFIXES = ("sw1527_", "sw1528_")

# DigiKey source_expr → ICPDF prajson2 key（None=跳过）
DK_TO_ICPDF: dict[str, str | None] = {
    "零件状态": "生命周期",
    "RoHS 状态": "是否Rohs认证",
    "REACH 状态": "Reach Compliance Code",
    "ECCN": "ECCN代码",
    "制造商": "IHS 制造商",
    "制造商产品编号": "Base Number Matches",
    "湿气敏感性等级 (MSL)": "JESD-609代码",
    "工作温度": "最高工作温度",  # tmax; tmin 另规则
    "电路": "电路配置",
    "电气寿命": "电气寿命",
    "机械寿命": "电气寿命",  # ICPDF 常无独立机械寿命，弱映射
    "额定电流（安培）": "最大触点电流（直流）",
    "额定电压 - AC": "最大触点电压（交流）",
    "额定电压 - DC": "最大触点电压（直流）",
    "额定电压": "最大触点电压（直流）",
    "安装类型": "安装特点",
    "类型": "包装说明",
    "致动器类型": "执行器类型",
    "执行器类型": "执行器类型",
    "操作力": "最大操作力",
    "开关行程": "开关动作",
    "侵入防护": "密封",
    "端接样式": "端接类型",
    "转换角度": "分度角",
    "针位数": "位置数",
    "每层电路": "开关段数量",
    "电压 - 输出（最大值）": "最大触点电压（直流）",
    "电流 - 输出（最大值）": "最大触点电流（直流）",
    "供电电压": "最大触点电压（直流）",
    "供电电流": "最大触点电流（直流）",
    "开关功能": "开关功能",
    "类别": "开关类型",
    "工作位置": "安装特点",
    "超程": "开关动作",
    "差动行程": "开关动作",
    "预行程": "开关动作",
    "释放力": "最大操作力",
    "致动器方向": "安装特点",
    "照明类型，颜色": "包装说明",
    "照明": "包装说明",
    "照明电压（标称值）": "最大触点电压（直流）",
    "面板开口尺寸": "主体长度或直径",
    "颜色 - 致动器/盖帽": "包装说明",
    "致动器标志": "包装说明",
    "致动器长度": "主体长度或直径",
    "衬套螺纹": "端接类型",
    "转位止挡": "开关动作",
    "认证机构": "包装说明",
    "特性": "开关功能",
    "颜色 - 致动器/盖帽": "包装说明",
    "电压 - 供电": "最大触点电压（直流）",
    "每层电路": "开关段数量",
}

# ICPDF 专用 value_map 覆盖（lifecycle / rohs / reach / circuit）
ICPDF_VALUE_MAP_OVERRIDE: dict[str, str] = {
    "lifecycle_status": (
        '{"Active":"Active","NRND":"NRND","Obsolete":"Obsolete","EOL":"EOL",'
        '"Preview":"Preview","停产":"Obsolete","在售":"Active","_default":""}'
    ),
    "rohs_compliant": (
        '{"符合":"TRUE","不符合":"FALSE","是":"TRUE","否":"FALSE",'
        '"Y":"TRUE","N":"FALSE","_default":""}'
    ),
    "reach": (
        '{"compliant":"TRUE","not_compliant":"FALSE","unknown":"",'
        '"是":"TRUE","否":"FALSE","Compliant":"TRUE","_default":""}'
    ),
    "lead_free": (
        '{"不含铅":"TRUE","含铅":"FALSE","无铅":"TRUE",'
        '"是":"TRUE","否":"FALSE","Y":"TRUE","N":"FALSE","_default":""}'
    ),
    "circuit_type": (
        '{"1X1":"SPST","1X2":"SPDT","2X1":"DPST","2X2":"DPDT",'
        '"3X1":"3PST","3X2":"3PDT","4X2":"4PDT",'
        '"SPST":"SPST","SPDT":"SPDT","DPST":"DPST","DPDT":"DPDT",'
        '"3PST":"3PST","3PDT":"3PDT","4PDT":"4PDT","4PST":"4PST","6PST":"6PST",'
        '"_default":""}'
    ),
    "mounting_type": (
        '{"PANEL MOUNT":"Panel_Mount","PANEL MOUNT-THREADED":"Panel_Mount",'
        '"THROUGH HOLE-STRAIGHT":"Through_Hole","THROUGH HOLE-RIGHT ANGLE":"Through_Hole",'
        '"SURFACE MOUNT-STRAIGHT":"SMT","SURFACE MOUNT-RIGHT ANGLE":"SMT",'
        '"Chassis Mount":"Panel_Mount","Panel Mount":"Panel_Mount",'
        '"Through Hole":"Through_Hole","Surface Mount":"SMT","SMD/SMT":"SMT",'
        '"_default":""}'
    ),
    "actuation_style": (
        '{"SLIDE":"Slide","PIANO":"Piano","ROCKER":"Rocker","ROTARY":"Rotary",'
        '"PADDLE":"Slide","FLUSH TYPE":"Slide",'
        '"Piano":"Piano","Rocker":"Rocker","Rotary":"Rotary","Slide":"Slide",'
        '"_default":""}'
    ),
}

# prajson $.sqlname → std_attr（无 prajson2 老记录兜底；priority 30+ 低于 prajson2）
# tuple: sqlname, std_attr_code, apply_scope_level, apply_scope_code, regex, priority, value_map_key
SQLNAME_RULES: list[tuple[str, str, str, str, str, int, str | None]] = [
    ("gongZuoWenDuMin", "temp_min_c", "", "", r"(-?\d+(?:\.\d+)?)", 30, None),
    ("gongZuoWenDuMax", "temp_max_c", "", "", r"(-?\d+(?:\.\d+)?)", 30, None),
    ("chuDianLeiXing", "circuit_type", "l2", "mechanical_actuated_switch", "", 30, "circuit_type"),
    ("chuDianLeiXing", "contact_form", "l2", "mechanical_sensing_switch", "", 30, None),
    ("anZhuangFangShi", "mounting_type", "", "", "", 30, "mounting_type"),
    ("EDingDianYaDCMax", "rated_voltage_v", "", "", r"(-?\d+(?:\.\d+)?)", 30, None),
    ("EDingDianYaDC", "rated_voltage_v", "", "", r"(-?\d+(?:\.\d+)?)", 31, None),
    ("EDingDianYaACMax", "rated_voltage_v", "", "", r"(-?\d+(?:\.\d+)?)", 32, None),
    ("EDingDianYaAC", "rated_voltage_v", "", "", r"(-?\d+(?:\.\d+)?)", 33, None),
    ("EDingDianYa", "rated_voltage_v", "", "", r"(-?\d+(?:\.\d+)?)", 34, None),
    ("EDingDianLiuMax", "rated_current_a", "l2", "mechanical_actuated_switch", r"(-?\d+(?:\.\d+)?)", 30, None),
    ("EDingDianLiu", "rated_current_a", "l2", "mechanical_actuated_switch", r"(-?\d+(?:\.\d+)?)", 31, None),
    ("chuDianEDingDianLiu", "rated_current_a", "l2", "mechanical_actuated_switch", r"(-?\d+(?:\.\d+)?)", 32, None),
    ("EDingDianLiuMax", "rated_current_ma", "l2", "mechanical_sensing_switch", r"(-?\d+(?:\.\d+)?)", 30, None),
    ("EDingDianLiu", "rated_current_ma", "l2", "mechanical_sensing_switch", r"(-?\d+(?:\.\d+)?)", 31, None),
    ("jieChuDianZuMax", "contact_resistance_mohm", "l2", "mechanical_actuated_switch", r"(-?\d+(?:\.\d+)?)", 30, None),
    ("jueYuanDianZu", "insulation_resistance_mohm", "l2", "mechanical_actuated_switch", r"(-?\d+(?:\.\d+)?)", 30, None),
    ("fengZhuang", "package_case", "l2", "mechanical_actuated_switch", "", 30, None),
    ("fengZhuang", "package_case", "l2", "mechanical_sensing_switch", "", 30, None),
    ("jieChuQiLeiXing", "actuator_type", "l3", "snap_action_switch", "", 30, None),
    ("jieChuQiLeiXing", "actuator_head_type", "l3", "limit_switch", "", 30, None),
    ("zhenJiaoShu", "position_count", "l3", "dip_switch", r"(\d+)", 30, None),
    ("dianLuShu", "position_count", "l3", "dip_switch", r"(\d+)", 31, None),
    ("dongZuoLi", "actuation_force_gf", "l3", "tactile_switch", r"(\d+(?:\.\d+)?)", 30, None),
    ("dongZuoLi", "operating_force_min_gf", "l3", "snap_action_switch", r"(\d+(?:\.\d+)?)", 30, None),
    ("dongZuoLi", "tactile_peak_force_gf", "l3", "mechanical_key_switch", r"(\d+(?:\.\d+)?)", 30, None),
]

# prajson 老记录 mounting 原文补充（在 ICPDF_VALUE_MAP_OVERRIDE.mounting_type 之上合并）
SQLNAME_MOUNTING_EXTRA = (
    '"Quick Connect":"Quick_Connect",'
    '"Chassis, Solder Lug":"Through_Hole",'
    '"Chassis Mount":"Panel_Mount",'
    '"Solder Lug":"Through_Hole"'
)

# DK 规则中不适用于 ICPDF prajson2 形态的条目（工作温度 range 拆分到错误 key）
SKIP_DK_STD_ATTRS_ON_EXPR: set[tuple[str, str]] = {
    ("temp_min_c", "工作温度"),
    ("temp_max_c", "工作温度"),
}

# 额外 ICPDF-only 规则（无 DK 对应）
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
        "extract_rule_id": f"{PREFIX_IC}plen",
        "apply_scope_level": "l2",
        "apply_scope_code": "mechanical_actuated_switch",
        "std_attr_code": "pkg_length_mm",
        "source_expr": "主体长度或直径",
        "source_value_regex": r"(\d+(?:\.\d+)?)",
        "priority": 10,
        "note": "ICPDF 封装长度",
    },
    {
        "extract_rule_id": f"{PREFIX_IC}pwid",
        "apply_scope_level": "l2",
        "apply_scope_code": "mechanical_actuated_switch",
        "std_attr_code": "pkg_width_mm",
        "source_expr": "主体宽度",
        "source_value_regex": r"(\d+(?:\.\d+)?)",
        "priority": 10,
        "note": "ICPDF 封装宽度",
    },
    {
        "extract_rule_id": f"{PREFIX_IC}phgt",
        "apply_scope_level": "l2",
        "apply_scope_code": "mechanical_actuated_switch",
        "std_attr_code": "pkg_height_mm",
        "source_expr": "主体高度",
        "source_value_regex": r"(\d+(?:\.\d+)?)",
        "priority": 10,
        "note": "ICPDF 封装高度",
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
        "extract_rule_id": f"{PREFIX_IC}circ_func",
        "apply_scope_level": "l2",
        "apply_scope_code": "mechanical_actuated_switch",
        "std_attr_code": "circuit_type",
        "source_expr": "开关功能",
        "source_value_regex": "",
        "priority": 5,
        "note": "ICPDF 开关功能→circuit_type（SPST/DPDT 等）",
    },
]


def normalize_dk_rid(rid: str) -> str:
    """CONTRIB SOP: extract_rule_id 必须以 switch_ 为 L1 前缀。"""
    if rid.startswith(PREFIX_DK):
        return rid
    for old in LEGACY_DK_PREFIXES:
        if rid.startswith(old):
            return PREFIX_DK + rid[len(old):]
    raise ValueError(f"unexpected digikey extract_rule_id: {rid!r}")


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


def assert_switch_prefix(rows: list[dict]) -> None:
    from collections import Counter

    bad = [r["extract_rule_id"] for r in rows if not re.match(r"^switch_", r["extract_rule_id"])]
    if bad:
        raise SystemExit(f"prefix check failed ({len(bad)}): {bad[:5]}")
    dup = [rid for rid, c in Counter(r["extract_rule_id"] for r in rows).items() if c > 1]
    if dup:
        raise SystemExit(f"duplicate extract_rule_id: {dup[:5]}")


COLS = [
    "extract_rule_id", "data_source", "schema_version", "l1_code",
    "apply_scope_level", "apply_scope_code",
    "std_attr_code", "source_kind", "source_expr",
    "source_value_expr", "source_value_regex", "literal_std_value",
    "priority", "enabled", "value_map", "note",
]


def main() -> None:
    with IN_CSV.open(encoding="utf-8") as f:
        dk_rows = [r for r in csv.DictReader(f) if r["data_source"] == "digikey"]

    for r in dk_rows:
        r["extract_rule_id"] = normalize_dk_rid(r["extract_rule_id"])
        note = r.get("note") or ""
        for old in LEGACY_DK_PREFIXES:
            note = note.replace(old, PREFIX_DK)
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

    sn_seen: set[str] = set()
    for sqln, attr, scope_lvl, scope_code, regex, pri, vm_key in SQLNAME_RULES:
        base = f"{PREFIX_SN}{sqln}_{attr}"
        if scope_lvl and scope_code:
            base += f"_{scope_code[:8]}"
        rid = unique_rid(base, sn_seen)
        vm = ""
        if vm_key == "mounting_type":
            base = ICPDF_VALUE_MAP_OVERRIDE.get("mounting_type", "").rstrip("}")
            vm = base + "," + SQLNAME_MOUNTING_EXTRA + "}"
        elif vm_key:
            vm = ICPDF_VALUE_MAP_OVERRIDE.get(vm_key, "")
        icpdf_rows.append({
            **{c: "" for c in COLS},
            "extract_rule_id": rid,
            "data_source": DS,
            "schema_version": SCHEMA_VER,
            "l1_code": L1,
            "apply_scope_level": scope_lvl,
            "apply_scope_code": scope_code,
            "std_attr_code": attr,
            "source_kind": "prajson_sqlname_eq",
            "source_expr": sqln,
            "source_value_expr": "",
            "source_value_regex": regex,
            "literal_std_value": "",
            "priority": str(pri),
            "enabled": "1",
            "value_map": vm,
            "note": f"prajson sqlname 兜底 · {sqln}",
        })

    merged = dk_rows + icpdf_rows
    assert_switch_prefix(merged)
    with OUT_CSV.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=COLS, lineterminator="\n")
        w.writeheader()
        w.writerows(merged)

    print(f"DK rules: {len(dk_rows)}")
    n_p2 = sum(1 for r in icpdf_rows if r["source_kind"] == "prajson2_key_eq")
    n_sn = sum(1 for r in icpdf_rows if r["source_kind"] == "prajson_sqlname_eq")
    print(f"ICPDF rules: {len(icpdf_rows)} (prajson2={n_p2}, sqlname={n_sn})")
    print(f"[OK] all {len(merged)} extract_rule_id match ^switch_")
    print(f"Total -> {OUT_CSV}")


if __name__ == "__main__":
    main()
