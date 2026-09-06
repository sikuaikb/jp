#!/usr/bin/env python3
"""探查 dim 表的别名列名分布。"""
from __future__ import annotations

import os
from pathlib import Path
import pymysql

ENV = Path(__file__).resolve().parent / "local.env"
for line in ENV.read_text(encoding="utf-8").splitlines():
    if line.strip().startswith("export "):
        k, _, v = line[7:].partition("=")
        os.environ[k] = v.strip().strip("'").strip('"')

conn = pymysql.connect(
    host=os.environ["MYSQL_HOST"], port=9030,
    user=os.environ["MYSQL_USER"], password=os.environ["MYSQL_PASSWORD"],
    charset="utf8mb4", cursorclass=pymysql.cursors.DictCursor,
)
c = conn.cursor()

codes = [
    "ro_hs_compliant", "life_cycle_status", "mounting_type", "aec_qualified",
    "rohs_compliant", "lifecycle_status", "mounting_style", "aec_q_level",
    "lead_free",
]

print("=== dim.dim_attr_schema: std_attr_code 命中 ===")
for code in codes:
    c.execute("SELECT COUNT(*) n FROM dim.dim_attr_schema WHERE std_attr_code=%s", (code,))
    print(f"  {code:22s} {c.fetchone()['n']}")

print("\n=== dim.dim_std_component_attr 是否存在 + 列 ===")
try:
    c.execute("DESCRIBE dim.dim_std_component_attr")
    for r in c.fetchall():
        print("  col:", r["Field"])
except Exception as e:
    print("  ERR", e)

print("\n=== dim_std_component_attr: std_attr_code 分布 ===")
try:
    c.execute(
        "SELECT std_attr_code, COUNT(*) n FROM dim.dim_std_component_attr "
        "WHERE std_attr_code IN (%s) GROUP BY std_attr_code ORDER BY n DESC"
        % ",".join("'" + x + "'" for x in codes)
    )
    for r in c.fetchall():
        print(" ", r)
except Exception as e:
    print("  ERR", e)

c.close()
conn.close()
