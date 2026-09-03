#!/usr/bin/env python3
"""统一 dim.dim_attr_schema 里 lead_free 的 db_type -> BOOLEAN (71 个 VARCHAR 行)。
db_type 非 PK 列, 可直接 UPDATE。"""
import os
from pathlib import Path
import pymysql
ENV = Path(__file__).resolve().parent / "local.env"
for line in ENV.read_text(encoding="utf-8").splitlines():
    if line.strip().startswith("export "):
        k, _, v = line[7:].partition("=")
        os.environ[k] = v.strip().strip("'").strip('"')
conn = pymysql.connect(host=os.environ["MYSQL_HOST"], port=9030,
    user=os.environ["MYSQL_USER"], password=os.environ["MYSQL_PASSWORD"],
    charset="utf8mb4", cursorclass=pymysql.cursors.DictCursor, autocommit=True)
c = conn.cursor()

# 改前
c.execute("SELECT db_type, COUNT(*) n FROM dim.dim_attr_schema WHERE std_attr_code='lead_free' GROUP BY db_type")
print("改前:")
for r in c.fetchall():
    print(f"  {r['db_type']}: {r['n']}")

# UPDATE
c.execute("UPDATE dim.dim_attr_schema SET db_type='BOOLEAN' WHERE std_attr_code='lead_free' AND db_type='VARCHAR'")
print(f"\nUPDATE affected: {c.rowcount}")

# 改后
c.execute("SELECT db_type, COUNT(*) n FROM dim.dim_attr_schema WHERE std_attr_code='lead_free' GROUP BY db_type")
print("\n改后:")
for r in c.fetchall():
    print(f"  {r['db_type']}: {r['n']}")

c.close(); conn.close()
