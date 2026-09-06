#!/usr/bin/env python3
"""把含 mounting_type 列的 L2 build + DDL 脚本里列名改为 mounting_style，
保留 CASE WHEN std_attr_code='mounting_type' 字面量（匹配 EAV）。
基于实测的 15 张表，定位其 build/DDL 文件。"""
from pathlib import Path

ROOT = Path(r"e:\Hardware_Data_ETL\sql_scripts\2.attribute_standard")

# 15 张表对应的 L1 目录与文件名片段
TARGETS = [
    ("17_acoustic_device_ready", "acoustic_device_buzzer_and_piezo_actuator"),
    ("17_acoustic_device_ready", "acoustic_device_microphone"),
    ("17_acoustic_device_ready", "acoustic_device_speaker"),
    ("16_circuit_protection_ready", "circuit_protection_overcurrent_overtemperature_protection"),
    ("25_fpga_cpld_ready", "fpga_cpld_cpld"),
    ("25_fpga_cpld_ready", "fpga_cpld_fpga"),
    ("12_inductor_ready", "inductor_emi_filter_inductor"),
    ("12_inductor_ready", "inductor_hf_chip_inductor"),
    ("12_inductor_ready", "inductor_power_inductor"),
    ("04_isolator_ready", "isolator_digital_isolator"),
    ("04_isolator_ready", "isolator_optocoupler"),
    ("14_relay_ready", "relay_electromechanical_relay"),
    ("14_relay_ready", "relay_solid_state_relay"),
    ("15_switch_ready", "switch_mechanical_actuated_switch"),
    ("18_system_module_ready", "system_module_power_module"),
]

OLD, NEW = "mounting_type", "mounting_style"
KEEPER = "__KEEP_MOUNTING_TYPE__"

mod_files = []
for dirn, frag in TARGETS:
    d = ROOT / dirn
    for prefix in ("build_dwd_l2_", "dwd_l2_"):
        f = d / f"{prefix}{frag}.sql"
        if not f.exists():
            continue
        txt = f.read_text(encoding="utf-8")
        orig = txt
        txt = txt.replace(f"'{OLD}'", KEEPER)   # 保护 std_attr_code 字面量
        txt = txt.replace(OLD, NEW)             # 替换列名
        txt = txt.replace(KEEPER, f"'{OLD}'")    # 还原字面量
        if txt != orig:
            f.write_text(txt, encoding="utf-8")
            mod_files.append(f.name)
            print(f"MOD  {f.relative_to(ROOT)}")
        else:
            print(f"skip {f.relative_to(ROOT)}")

print(f"\ndone mounting_type: {len(mod_files)} files")
