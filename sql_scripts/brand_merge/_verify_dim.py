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

# 1. 所有 merge_id 是否都已 state=0
cur.execute("""
    SELECT COUNT(*) miss FROM dim.dim_brand_merge_map m
    JOIN dim.dim_std_brand b ON b.brand_id_std=m.merge_id
    WHERE b.state <> 0
""")
print("merge_id 未置 state=0 的条数:", cur.fetchone()["miss"], "(应为 0)")

# 2. keeper 是否仍 state=1
cur.execute("""
    SELECT COUNT(*) miss FROM (SELECT DISTINCT keep_id FROM dim.dim_brand_merge_map) m
    JOIN dim.dim_std_brand b ON b.brand_id_std=m.keep_id
    WHERE b.state <> 1
""")
print("keeper 非 state=1 的条数:", cur.fetchone()["miss"], "(应为 0)")

# 3. Narda keeper + Bel Fuse rename
cur.execute("SELECT brand_id_std,name,state FROM dim.dim_std_brand WHERE brand_id_std IN (1498550091584172034,1443490694885642242,1452878214891163649)")
for r in cur.fetchall():
    print(f"   {r['brand_id_std']}  state={r['state']}  name={r['name']!r}")

# 4. 视图：每个 merge 记录的 name 大写后，现在解析到谁？应=keep_id（或该 brand_key 不存在）
cur.execute("""
    SELECT m.merge_id, m.keep_id, b.name merge_name, a.brand_id_std resolved
    FROM dim.dim_brand_merge_map m
    JOIN dim.dim_std_brand b ON b.brand_id_std=m.merge_id
    LEFT JOIN dim.v_std_brand_alias a ON a.brand_key=UPPER(TRIM(b.name))
""")
bad = []
for r in cur.fetchall():
    if r["resolved"] is not None and r["resolved"] == r["merge_id"]:
        bad.append(r)
print(f"\n视图里仍把 merge 记录 name 解析回 merge_id 的条数: {len(bad)} (应为 0)")
for r in bad[:10]:
    print("   BAD", r)

# 5. 视图总行数（健全性）
cur.execute("SELECT COUNT(*) c, COUNT(DISTINCT brand_key) d FROM dim.v_std_brand_alias")
print("\n视图行数 / distinct brand_key:", cur.fetchone())
conn.close()
