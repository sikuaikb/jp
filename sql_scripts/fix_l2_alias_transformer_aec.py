#!/usr/bin/env python3
"""transformer 4 张表的 build + DDL：aec_qualified 列名 → aec_q_level，
保留 CASE WHEN std_attr_code='aec_qualified' 字面量（匹配 EAV）。"""
from pathlib import Path

ROOT = Path(r"e:\Hardware_Data_ETL\sql_scripts\2.attribute_standard\06_transformer_ready")
FRAGS = [
    "transformer_instrument_transformer",
    "transformer_power_transformer",
    "transformer_signal_communication_transformer",
    "transformer_switching_drive_transformer",
]
OLD, NEW = "aec_qualified", "aec_q_level"
KEEPER = "__KEEP_AEC_QUALIFIED__"

n = 0
for frag in FRAGS:
    for prefix in ("build_dwd_l2_", "dwd_l2_"):
        f = ROOT / f"{prefix}{frag}.sql"
        if not f.exists():
            continue
        txt = f.read_text(encoding="utf-8")
        orig = txt
        txt = txt.replace(f"'{OLD}'", KEEPER)
        txt = txt.replace(OLD, NEW)
        txt = txt.replace(KEEPER, f"'{OLD}'")
        if txt != orig:
            f.write_text(txt, encoding="utf-8")
            n += 1
            print(f"MOD  {f.name}")
        else:
            print(f"skip {f.name}")
print(f"\ndone transformer aec_qualified: {n} files")
