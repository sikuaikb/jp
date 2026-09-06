#!/usr/bin/env python3
"""amplifier 6 个 DDL 文件：别名列名 → 规范名（DDL 无 std_attr_code 字面量，直接换）。"""
from pathlib import Path

BASE = Path(r"e:\Hardware_Data_ETL\sql_scripts\2.attribute_standard\02_amplifier_ready")
MAP = {"ro_hs_compliant": "rohs_compliant", "life_cycle_status": "lifecycle_status"}

for f in sorted(BASE.glob("dwd_l2_amplifier_*.sql")):
    txt = f.read_text(encoding="utf-8")
    orig = txt
    for old, new in MAP.items():
        txt = txt.replace(old, new)
    if txt != orig:
        f.write_text(txt, encoding="utf-8")
        print(f"MOD  {f.name}")
    else:
        print(f"skip {f.name}")
print("done amplifier DDL")
