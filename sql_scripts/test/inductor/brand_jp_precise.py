#!/usr/bin/env python3
"""精确 jp_brand 查询（inductor 未映射 Top 品牌）"""
import os, pymysql
from pathlib import Path

NAMES = [
    "Gowanda", "CODACA", "Venkel", "Triad", "Amgis", "Renco", "RENCO",
    "FRONTIER", "Frontier", "iNRCORE", "Max Echo", "Cal-Chip", "CAL-CHIP",
    "HALO", "Halo Electronics", "ALLIED", "Allied Components", "RHOMBUS",
    "Knitter", "Ole Wolff", "CAMBION", "ZenithTek", "Superworld", "CALIBER",
    "Talema", "SAGAMI", "Arlitech", "Knowles", "Johanson", "Suntsu", "Newava",
    "aimtec", "Aimtec", "Cincon", "Premo", "ICE Components", "NIC Components",
    "PCA", "MICRO-ELECTRONICS", "Jaro", "Schott", "Aillen", "ITG",
]

for line in Path("sql_scripts/local.env").read_text(encoding="utf-8").splitlines():
    if line.strip().startswith("export "):
        k, _, v = line[7:].partition("=")
        os.environ[k] = v.strip().strip("'\"")
c = pymysql.connect(
    host=os.environ["MYSQL_HOST"], port=int(os.environ["MYSQL_PORT"]),
    user=os.environ["MYSQL_USER"], password=os.environ["MYSQL_PASSWORD"],
    cursorclass=pymysql.cursors.DictCursor,
)
cur = c.cursor()
for n in NAMES:
    cur.execute(
        "SELECT id, name, abbr FROM ods.ods_jp_brand "
        "WHERE state=1 AND (UPPER(name) LIKE %s OR UPPER(abbr) LIKE %s) LIMIT 5",
        (f"%{n.upper()}%", f"%{n.upper()}%"),
    )
    rows = cur.fetchall()
    if rows:
        print(f"\n== {n} ==")
        for r in rows:
            print(r)
c.close()
