#!/usr/bin/env python3
"""把 amplifier 6 个 build 脚本里的别名列名改为规范名，
但保留 CASE WHEN std_attr_code='<alias>' 字面量（匹配 EAV）。
保护-还原法：先把 'alias' 字面量临时替换，再全量替换列名，再还原字面量。"""
from pathlib import Path

BASE = Path(r"e:\Hardware_Data_ETL\sql_scripts\2.attribute_standard\02_amplifier_ready")

MAP = {
    "ro_hs_compliant": "rohs_compliant",
    "life_cycle_status": "lifecycle_status",
}

build_files = sorted(BASE.glob("build_dwd_l2_amplifier_*.sql"))

for f in build_files:
    txt = f.read_text(encoding="utf-8")
    orig = txt
    for old, new in MAP.items():
        keeper = f"__KEEP_{new.upper()}__"
        txt = txt.replace(f"'{old}'", keeper)     # 保护 std_attr_code 字面量
        txt = txt.replace(old, new)                # 替换列名（INSERT list / AS / 反引号）
        txt = txt.replace(keeper, f"'{old}'")      # 还原字面量
    if txt != orig:
        f.write_text(txt, encoding="utf-8")
        print(f"MOD  {f.name}")
    else:
        print(f"skip {f.name}")

print("done amplifier build")
