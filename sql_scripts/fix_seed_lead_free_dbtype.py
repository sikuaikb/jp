#!/usr/bin/env python3
"""把所有 dim_attr_schema*.csv 里 lead_free 行的 db_type 列 VARCHAR -> BOOLEAN。
列感知: 通过 header 定位 std_attr_code 与 db_type 列, 仅改 lead_free 行的 db_type。"""
from __future__ import annotations
import csv
from pathlib import Path

BASE = Path(r"e:\HardWare_DK_ETL\sql_scripts")

files = list(BASE.rglob("dim_attr_schema*.csv"))
total = 0
for p in files:
    with open(p, "r", encoding="utf-8", newline="") as f:
        rows = list(csv.reader(f))
    if not rows:
        continue
    header = rows[0]
    try:
        code_idx = header.index("std_attr_code")
        dbt_idx = header.index("db_type")
    except ValueError:
        continue
    changed = 0
    for r in rows[1:]:
        if len(r) > max(code_idx, dbt_idx) and r[code_idx].strip() == "lead_free" and r[dbt_idx].strip() == "VARCHAR":
            r[dbt_idx] = "BOOLEAN"
            changed += 1
    if changed:
        with open(p, "w", encoding="utf-8", newline="") as f:
            csv.writer(f, quoting=csv.QUOTE_MINIMAL).writerows(rows)
        print(f"  {p.relative_to(BASE)}: {changed} 行 VARCHAR->BOOLEAN")
        total += changed
print(f"\n合计: {total} 行")
