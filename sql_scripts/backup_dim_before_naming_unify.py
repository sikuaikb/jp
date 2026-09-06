#!/usr/bin/env python3
"""备份 dim 三张表（命名统一前快照），便于回滚。"""
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

ts = "20260716_naming_unify"
srcs = ["dim_std_component_attr", "dim_attr_schema", "dim_attr_extract_rule"]
for s in srcs:
    bak = f"bak_{s}_{ts}"
    c.execute(f"DROP TABLE IF EXISTS dim.{bak}")
    c.execute(f"CREATE TABLE dim.{bak} AS SELECT * FROM dim.{s}")
    c.execute(f"SELECT COUNT(*) n FROM dim.{bak}")
    print(f"  dim.{bak}: {c.fetchone()['n']:,} rows")

c.close(); conn.close()
