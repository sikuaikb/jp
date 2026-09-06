#!/usr/bin/env python3
"""classify vs L2 行数覆盖（brand 门控后预期有缺口）"""
from pathlib import Path
import os
import pymysql

L1 = "inductor"
L2S = ["power_inductor", "hf_chip_inductor", "emi_filter_inductor"]

for line in Path("sql_scripts/local.env").read_text(encoding="utf-8").splitlines():
    if line.strip().startswith("export "):
        k, _, v = line[7:].partition("=")
        os.environ[k] = v.strip().strip("'\"")

conn = pymysql.connect(
    host=os.environ["MYSQL_HOST"], port=int(os.environ["MYSQL_PORT"]),
    user=os.environ["MYSQL_USER"], password=os.environ["MYSQL_PASSWORD"],
    charset="utf8mb4", cursorclass=pymysql.cursors.DictCursor,
)
cur = conn.cursor()

print("=== classify by l2_code ===")
cur.execute(
    f"SELECT l2_code, data_source, COUNT(*) n FROM dwd.dwd_component_class "
    f"WHERE l1_code='{L1}' GROUP BY 1,2 ORDER BY 1,2"
)
cls = {}
for r in cur.fetchall():
    cls[(r["l2_code"], r["data_source"])] = r["n"]
    print(r)

print("\n=== L2 wide totals ===")
l2_tot = 0
for l2 in L2S:
    cur.execute(f"SELECT data_source, COUNT(*) n FROM dwd.dwd_l2_{L1}_{l2} GROUP BY 1")
    rows = cur.fetchall()
    sub = sum(r["n"] for r in rows)
    l2_tot += sub
    print(l2, {r["data_source"]: r["n"] for r in rows}, "total=", sub)

cls_tot = sum(cls.values())
print(f"\nclassify total={cls_tot}  L2 total={l2_tot}  gap={cls_tot - l2_tot}")

conn.close()
