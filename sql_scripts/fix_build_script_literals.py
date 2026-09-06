#!/usr/bin/env python3
"""build 脚本里 std_attr_code = 'old' 字面量 -> 'new'。
只替换被单引号包裹的旧码字面量 (std_attr_code 匹配条件), 不动列名/别名/注释。
旧码 -> 规范名:
  ro_hs_compliant -> rohs_compliant
  life_cycle_status -> lifecycle_status
  mounting_type -> mounting_style
  aec_qualified -> aec_q_level
"""
from __future__ import annotations
from pathlib import Path

ALIAS = {
    "ro_hs_compliant": "rohs_compliant",
    "life_cycle_status": "lifecycle_status",
    "mounting_type": "mounting_style",
    "aec_qualified": "aec_q_level",
}

BASE = Path(r"e:\Hardware_Data_ETL\sql_scripts")

# 命中的文件 (来自 grep), 含主目录 build 脚本与 test/ 下 build/dwd 脚本
REL_FILES = [
    r"2.attribute_standard\06_transformer_ready\build_dwd_l2_transformer_switching_drive_transformer.sql",
    r"2.attribute_standard\06_transformer_ready\build_dwd_l2_transformer_signal_communication_transformer.sql",
    r"2.attribute_standard\06_transformer_ready\build_dwd_l2_transformer_power_transformer.sql",
    r"2.attribute_standard\06_transformer_ready\build_dwd_l2_transformer_instrument_transformer.sql",
    r"2.attribute_standard\18_system_module_ready\build_dwd_l2_system_module_power_module.sql",
    r"2.attribute_standard\15_switch_ready\build_dwd_l2_switch_mechanical_actuated_switch.sql",
    r"2.attribute_standard\14_relay_ready\build_dwd_l2_relay_solid_state_relay.sql",
    r"2.attribute_standard\14_relay_ready\build_dwd_l2_relay_electromechanical_relay.sql",
    r"2.attribute_standard\04_isolator_ready\build_dwd_l2_isolator_optocoupler.sql",
    r"2.attribute_standard\04_isolator_ready\build_dwd_l2_isolator_digital_isolator.sql",
    r"2.attribute_standard\12_inductor_ready\build_dwd_l2_inductor_power_inductor.sql",
    r"2.attribute_standard\12_inductor_ready\build_dwd_l2_inductor_hf_chip_inductor.sql",
    r"2.attribute_standard\12_inductor_ready\build_dwd_l2_inductor_emi_filter_inductor.sql",
    r"2.attribute_standard\25_fpga_cpld_ready\build_dwd_l2_fpga_cpld_fpga.sql",
    r"2.attribute_standard\25_fpga_cpld_ready\build_dwd_l2_fpga_cpld_cpld.sql",
    r"2.attribute_standard\16_circuit_protection_ready\build_dwd_l2_circuit_protection_overcurrent_overtemperature_protection.sql",
    r"2.attribute_standard\17_acoustic_device_ready\build_dwd_l2_acoustic_device_speaker.sql",
    r"2.attribute_standard\17_acoustic_device_ready\build_dwd_l2_acoustic_device_microphone.sql",
    r"2.attribute_standard\17_acoustic_device_ready\build_dwd_l2_acoustic_device_buzzer_and_piezo_actuator.sql",
    r"2.attribute_standard\02_amplifier_ready\build_dwd_l2_amplifier_rf_if_amplifier.sql",
    r"2.attribute_standard\02_amplifier_ready\build_dwd_l2_amplifier_precision_signal_conditioning_amp.sql",
    r"2.attribute_standard\02_amplifier_ready\build_dwd_l2_amplifier_video_wideband_amp.sql",
    r"2.attribute_standard\02_amplifier_ready\build_dwd_l2_amplifier_transimpedance_transconductance_log_amp.sql",
    r"2.attribute_standard\02_amplifier_ready\build_dwd_l2_amplifier_general_opamp_comparator.sql",
    r"2.attribute_standard\02_amplifier_ready\build_dwd_l2_amplifier_audio_power_amplifier.sql",
    r"test\circuit_protection\prod_export\dwd_l2_circuit_protection_overcurrent_overtemperature_protection.sql",
    r"test\circuit_protection\dwd_l2_circuit_protection_overcurrent_overtemperature_protection.sql",
    r"test\circuit_protection\build_dwd_l2_circuit_protection_overcurrent_overtemperature_protection.sql",
    r"test\switch\dwd_l2_switch_mechanical_actuated_switch.sql",
    r"test\switch\build_dwd_l2_switch_mechanical_actuated_switch.sql",
    r"test\rf_wireless\build_dwd_l2_rf_wireless_rfid_nfc_frontend.sql",
    r"test\rf_wireless\dwd_l2_rf_wireless_rfid_nfc_frontend.sql",
    r"test\rf_wireless\build_dwd_l2_rf_wireless_rf_signal_control_detection.sql",
    r"test\rf_wireless\build_dwd_l2_rf_wireless_rf_transceiver_ic.sql",
    r"test\rf_wireless\dwd_l2_rf_wireless_rf_transceiver_ic.sql",
    r"test\rf_wireless\build_dwd_l2_rf_wireless_rf_passive_network.sql",
    r"test\rf_wireless\dwd_l2_rf_wireless_rf_signal_control_detection.sql",
    r"test\rf_wireless\dwd_l2_rf_wireless_rf_passive_network.sql",
]

total = 0
for rel in REL_FILES:
    p = BASE / rel
    if not p.exists():
        print(f"SKIP (not found): {rel}")
        continue
    txt = p.read_text(encoding="utf-8")
    orig = txt
    n = 0
    for old, new in ALIAS.items():
        # 只替换被单引号包裹的字面量
        needle = f"'{old}'"
        cnt = txt.count(needle)
        if cnt:
            txt = txt.replace(needle, f"'{new}'")
            n += cnt
    if txt != orig:
        p.write_text(txt, encoding="utf-8")
        print(f"  {rel}: replaced {n}")
        total += n
    else:
        print(f"  {rel}: no change")
print(f"\n合计替换: {total}")
