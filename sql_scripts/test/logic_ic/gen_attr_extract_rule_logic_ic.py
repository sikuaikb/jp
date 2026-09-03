#!/usr/bin/env python3
"""从 dim_attr_schema_logic_ic.csv 生成 DigiKey 属性抽取规则。"""
from __future__ import annotations

import argparse
import csv
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
SCHEMA_CSV = HERE / "seed" / "dim_attr_schema_logic_ic.csv"
OUT_CSV = HERE / "seed" / "dim_attr_extract_rule_logic_ic.csv"
COVERAGE_TSV = REPO / "artifacts" / "logic_ic" / "attr_rule_coverage.tsv"

SCHEMA_VER = "logic_ic_schema_v1.4.30"
L1_CODE = "logic_ic"
DK = "prajson2_key_eq"

RULE_COLS = [
    "extract_rule_id", "data_source", "schema_version", "l1_code",
    "apply_scope_level", "apply_scope_code",
    "std_attr_code", "source_kind", "source_expr",
    "source_value_expr", "source_value_regex", "literal_std_value",
    "priority", "enabled", "value_map", "note",
]

LIFECYCLE_MAP = (
    '{"在售":"Active","已过时":"Obsolete","停产":"EOL","已停产":"EOL",'
    '"最后售卖":"EOL","DigiKey 停止提供":"EOL",'
    '"不推荐用于新设计":"NRND","不适用于新设计":"NRND","未发布":"Preview"}'
)
MSL_MAP = (
    '{"不适用":"","未明确供应商":"","1（无限）":"1","2（1 年）":"2",'
    '"2a（4 周）":"2a","3（168 小时）":"3","4（72 小时）":"4",'
    '"5（48 小时）":"5","5a（24 小时）":"5a","6（TOL）":"6"}'
)
LEAD_FREE_MAP = (
    '{"符合 ROHS3 规范":"TRUE","符合 RoHS 规范":"TRUE","不符合 RoHS 规范":"FALSE","不适用":""}'
)
BOOL_MAP = '{"是":"TRUE","否":"FALSE","有":"TRUE","无":"FALSE"}'


@dataclass
class Binding:
    dk_key: str
    priority: int = 5
    regex: str = ""
    value_map: str = ""
    note: str = ""
    scopes: list[tuple[str, str]] = field(default_factory=list)


def B(dk_key: str, priority: int = 5, regex: str = "", value_map: str = "", note: str = "", scopes: list[tuple[str, str]] | None = None) -> Binding:
    return Binding(dk_key, priority, regex, value_map, note, scopes or [])


ATTR_BINDINGS: dict[str, list[Binding]] = {
    "manufacturer": [B("制造商")],
    "mpn": [B("制造商产品编号")],
    "lifecycle_status": [B("零件状态", value_map=LIFECYCLE_MAP)],
    "rohs_compliant": [B("RoHS 状态", priority=8)],
    "lead_free": [B("RoHS 状态", priority=9, value_map=LEAD_FREE_MAP)],
    "reach": [B("REACH 状态", priority=8)],
    "eccn_code": [B("ECCN", priority=8)],
    "msl_level": [B("湿气敏感性等级 (MSL)", priority=8, value_map=MSL_MAP)],
    "package_case": [B("封装/外壳"), B("供应商器件封装", priority=8)],
    "mount_type": [B("安装类型")],
    "logic_series": [B("系列")],
    "temp_min_c": [B("工作温度", regex=r"(-?\d+\.?\d*)\s*°?C?\s*~")],
    "temp_max_c": [B("工作温度", regex=r"~\s*(-?\d+\.?\d*)\s*°?C")],
    "supply_voltage_min_v": [
        B("供电电压", regex=r"([\d.]+)\s*V?\s*~"),
        B("电压 - 供电", priority=8, regex=r"([\d.]+)\s*V?\s*~"),
    ],
    "supply_voltage_max_v": [
        B("供电电压", regex=r"~\s*([\d.]+)\s*V"),
        B("电压 - 供电", priority=8, regex=r"~\s*([\d.]+)\s*V"),
    ],
    "propagation_delay_ns": [
        B("不同 V、最大 CL 时最大传播延迟", regex=r"([\d.]+)\s*ns"),
        B("传播延迟", priority=8, regex=r"([\d.]+)\s*ns"),
        B("传播延迟（最大值）", priority=9, regex=r"([\d.]+)\s*ns"),
    ],
    "output_current_high_low": [
        B("电流 - 输出高、低"),
        B("输出类型", priority=9, scopes=[("l2", "sequential_logic")], note="移位寄存器等 DK 叶常无电流字段"),
    ],
    # L3
    "logic_type": [
        B("逻辑类型"),
        B("逻辑类型", scopes=[("l3", "buffer_driver")]),
    ],
    "input_count": [B("输入数", scopes=[("l3", "basic_logic_gate")])],
    "circuit_count": [B("电路数", scopes=[("l3", "basic_logic_gate")])],
    "output_type_gate": [
        B("输出类型", scopes=[("l3", "basic_logic_gate")]),
        B("特性", priority=8, scopes=[("l3", "basic_logic_gate")], note="开路漏极等门输出特性"),
    ],
    "schmitt_trigger_input": [B("施密特触发器输入", scopes=[("l3", "basic_logic_gate")], value_map=BOOL_MAP)],
    "independent_circuits": [
        B("独立电路", scopes=[("l3", "mux_demux")]),
        B("独立电路", scopes=[("l3", "encoder_decoder")]),
    ],
    "circuit_config": [
        B("电路", scopes=[("l3", "mux_demux")]),
        B("电路", scopes=[("l3", "encoder_decoder")]),
        B("独立电路", priority=8, scopes=[("l3", "encoder_decoder")]),
        B("电路数", priority=9, scopes=[("l3", "encoder_decoder")]),
        B("电路", scopes=[("l3", "bus_switch")]),
    ],
    "supply_voltage_type": [
        B("供电电压源", scopes=[("l3", "mux_demux")]),
        B("供电电压源", scopes=[("l3", "encoder_decoder")]),
        B("供电电压源", scopes=[("l3", "bus_switch")]),
    ],
    "bit_width": [
        B("位数", scopes=[("l3", "digital_comparator")]),
        B("位数", scopes=[("l3", "alu_adder")]),
        B("位数", scopes=[("l3", "register")]),
        B("位数", scopes=[("l3", "counter_divider")]),
        B("位数", scopes=[("l3", "buffer_driver")]),
    ],
    "comparator_type": [B("类型", scopes=[("l3", "digital_comparator")])],
    "output_function": [B("输出功能", scopes=[("l3", "digital_comparator")])],
    "comparator_output": [B("输出", scopes=[("l3", "digital_comparator")])],
    "element_count": [
        B("元件数", scopes=[("l3", "flip_flop_latch")]),
        B("元件数", scopes=[("l3", "shift_register")]),
        B("元件数", scopes=[("l3", "buffer_driver")]),
        B("元件数", scopes=[("l3", "bus_transceiver")]),
    ],
    "bits_per_element": [
        B("每个元件位数", scopes=[("l3", "flip_flop_latch")]),
        B("每个元件位数", scopes=[("l3", "shift_register")]),
        B("每个元件位数", scopes=[("l3", "buffer_driver")]),
        B("位数", priority=8, scopes=[("l3", "buffer_driver")], note="专用逻辑缓冲叶常用位数"),
        B("每个元件位数", scopes=[("l3", "bus_transceiver")]),
    ],
    "output_type_ff": [B("输出类型", scopes=[("l3", "flip_flop_latch")])],
    "input_capacitance_pf": [B("输入电容", scopes=[("l3", "flip_flop_latch")])],
    "shift_function": [B("功能", scopes=[("l3", "shift_register")])],
    "output_type_sr": [B("输出类型", scopes=[("l3", "shift_register")])],
    "input_type": [
        B("输入类型", scopes=[("l3", "buffer_driver")]),
        B("输入类型", scopes=[("l3", "bus_transceiver")]),
    ],
    "output_type_buf": [B("输出类型", scopes=[("l3", "buffer_driver")])],
    "output_type_xcvr": [B("输出类型", scopes=[("l3", "bus_transceiver")])],
    "switch_type": [B("类型", scopes=[("l3", "bus_switch")])],
}


def rule_id(std_attr: str, dk_key: str, scope_level: str, scope_code: str, idx: int) -> str:
    parts = ["logic_ic"]
    if scope_level and scope_code:
        parts.append(scope_code[:12])
    parts.append(std_attr[:24])
    if idx:
        parts.append(str(idx))
    return "_".join(parts)[:120]


def emit_rule(rows, seen_ids, std_attr, b, scope_level, scope_code, idx):
    rid = rule_id(std_attr, b.dk_key, scope_level, scope_code, idx)
    base, n = rid, 1
    while rid in seen_ids:
        rid = f"{base}_{n}"
        n += 1
    seen_ids.add(rid)
    rows.append({
        "extract_rule_id": rid,
        "data_source": "digikey",
        "schema_version": SCHEMA_VER,
        "l1_code": L1_CODE,
        "apply_scope_level": scope_level,
        "apply_scope_code": scope_code,
        "std_attr_code": std_attr,
        "source_kind": DK,
        "source_expr": b.dk_key,
        "source_value_expr": "",
        "source_value_regex": b.regex,
        "literal_std_value": "",
        "priority": b.priority,
        "enabled": 1,
        "value_map": b.value_map,
        "note": b.note,
    })


def gen_rules(schema_rows):
    schema_keys = {(r["scope_level"], r["scope_code"], r["std_attr_code"]) for r in schema_rows}
    std_attrs = {k[2] for k in schema_keys}
    rows, coverage, seen_ids, global_emitted = [], [], set(), set()

    for std_attr in sorted(std_attrs):
        bindings = ATTR_BINDINGS.get(std_attr, [])
        global_bs = [b for b in bindings if not b.scopes]
        scoped_bs = [b for b in bindings if b.scopes]
        if global_bs and std_attr not in global_emitted:
            for idx, b in enumerate(global_bs):
                emit_rule(rows, seen_ids, std_attr, b, "", "", idx)
            global_emitted.add(std_attr)
        for scope_level, scope_code in sorted({(sl, sc) for sl, sc, sa in schema_keys if sa == std_attr}):
            matched = [b for b in scoped_bs if (scope_level, scope_code) in b.scopes]
            rule_count = len(global_bs) + len(matched)
            for idx, b in enumerate(matched):
                emit_rule(rows, seen_ids, std_attr, b, scope_level, scope_code, idx)
            coverage.append({
                "scope_level": scope_level,
                "scope_code": scope_code,
                "std_attr_code": std_attr,
                "rule_count": rule_count,
                "status": "OK" if rule_count else "MISSING",
                "dk_keys": "; ".join(x.dk_key for x in (global_bs + matched)),
            })

    rows.sort(key=lambda r: (r["apply_scope_code"], r["std_attr_code"], r["priority"], r["extract_rule_id"]))
    return rows, coverage


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--schema", type=Path, default=SCHEMA_CSV)
    args = ap.parse_args()
    schema_rows = list(csv.DictReader(args.schema.open(encoding="utf-8-sig")))
    rows, coverage = gen_rules(schema_rows)
    with OUT_CSV.open("w", newline="", encoding="utf-8-sig") as f:
        w = csv.DictWriter(f, fieldnames=RULE_COLS)
        w.writeheader()
        w.writerows(rows)
    COVERAGE_TSV.parent.mkdir(parents=True, exist_ok=True)
    with COVERAGE_TSV.open("w", newline="", encoding="utf-8-sig") as f:
        w = csv.DictWriter(f, fieldnames=["scope_level", "scope_code", "std_attr_code", "rule_count", "status", "dk_keys"])
        w.writeheader()
        w.writerows(coverage)
    ok = sum(1 for c in coverage if c["status"] == "OK")
    missing = [c for c in coverage if c["status"] == "MISSING"]
    print(f"rules: {len(rows)}  coverage OK: {ok}/{len(coverage)}")
    print(f"coverage -> {COVERAGE_TSV}")
    if missing:
        print(f"MISSING {len(missing)}:")
        for m in missing:
            print(f"  {m['scope_level']}/{m['scope_code']}.{m['std_attr_code']}")


if __name__ == "__main__":
    main()
