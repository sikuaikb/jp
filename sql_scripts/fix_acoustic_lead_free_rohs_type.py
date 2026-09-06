#!/usr/bin/env python3
"""修复 acoustic DDL 文件 lead_free/rohs_compliant 列类型 VARCHAR -> TINYINT。
这些文件列名带尾部空格 (`lead_free    `), 之前正则漏掉。
只改类型, 保留列名尾部空格形式 (最小改动, 与 DB 列名干净不冲突 - DB 已是干净名)。"""
from __future__ import annotations
import re
from pathlib import Path

BASE = Path(r"e:\Hardware_Data_ETL\sql_scripts\2.attribute_standard\17_acoustic_device_ready")
files = [
    "dwd_l2_acoustic_device_speaker.sql",
    "dwd_l2_acoustic_device_microphone.sql",
    "dwd_l2_acoustic_device_buzzer_and_piezo_actuator.sql",
    "dwd_l2_acoustic_device_receiver.sql",
]
# 匹配 `lead_free<空格>` 后的 VARCHAR(...) 或 `rohs_compliant<空格>` 后的 VARCHAR(...)
pat = re.compile(r"(`(?:lead_free|rohs_compliant)\s*`\s+)VARCHAR\(\d+\)")
for fn in files:
    p = BASE / fn
    txt = p.read_text(encoding="utf-8")
    orig = txt
    new = pat.sub(lambda m: m.group(1) + "TINYINT", txt)
    if new != orig:
        p.write_text(new, encoding="utf-8")
        print(f"  fixed {fn}")
    else:
        print(f"  no change {fn}")
