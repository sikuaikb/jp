#!/usr/bin/env python3
from __future__ import annotations
import os, sys
from pathlib import Path
import pymysql

sys.stdout.reconfigure(encoding="utf-8")
ENV = Path(__file__).resolve().parents[1] / "local.env"
for line in ENV.read_text(encoding="utf-8").splitlines():
    if line.strip().startswith("export "):
        k, _, v = line[7:].partition("=")
        os.environ[k] = v.strip().strip("'").strip('"')
conn = pymysql.connect(host=os.environ["MYSQL_HOST"], port=int(os.environ.get("MYSQL_PORT","9030")),
    user=os.environ["MYSQL_USER"], password=os.environ["MYSQL_PASSWORD"], charset="utf8mb4",
    cursorclass=pymysql.cursors.DictCursor)
cur = conn.cursor()

cur.execute("SELECT keep_id, merge_id FROM dim.dim_brand_merge_map")
pairs = cur.fetchall()
merge_ids = [r["merge_id"] for r in pairs]
merge_list = ",".join(str(x) for x in merge_ids)

# 1. 全库 95 张表零残留终检
cur.execute("""
    SELECT DISTINCT t.table_name FROM information_schema.tables t
    JOIN information_schema.columns c ON c.table_schema=t.table_schema AND c.table_name=t.table_name
    WHERE t.table_schema='dwd' AND t.table_name LIKE 'dwd_l2_%' AND c.column_name='brandid'
""")
tables = [r["table_name"] for r in cur.fetchall()]
residual = 0
for tn in tables:
    cur.execute(f"SELECT COUNT(*) c FROM dwd.{tn} WHERE brandid IN ({merge_list})")
    residual += cur.fetchone()["c"]
print(f"全库 {len(tables)} 张表中残留 merge_id 的行数 = {residual} (应为 0)")

# 2. 抽查：Johanson(capacitor) / Cosel(power_module) 已落到 keeper + brand 文本
cur.execute("""
    SELECT brandid, brand, COUNT(*) c FROM dwd.dwd_l2_capacitor_non_polar_fixed_capacitor
    WHERE brandid IN (1448539709889175554)
    GROUP BY brandid, brand
""")
print("\ncapacitor 表 Johanson keeper(1448539709889175554) 抽查:")
for r in cur.fetchall():
    print(f"   brandid={r['brandid']}  brand={r['brand']!r}  rows={r['c']:,}")
conn.close()
