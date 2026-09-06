#!/usr/bin/env python3
import os
from pathlib import Path
import pymysql

ENV = Path(__file__).resolve().parents[3] / "local.env"
for line in ENV.read_text(encoding="utf-8").splitlines():
    if line.strip().startswith("export "):
        k, _, v = line.strip()[7:].partition("=")
        os.environ[k] = v.strip().strip("'").strip('"')

conn = pymysql.connect(
    host=os.environ["MYSQL_HOST"], port=9030,
    user=os.environ["MYSQL_USER"], password=os.environ["MYSQL_PASSWORD"],
    charset="utf8mb4", cursorclass=pymysql.cursors.DictCursor,
)
cur = conn.cursor()

for cat in ["奇偶校验发生器和校验器", "多谐振荡器", "通用总线功能"]:
    cur.execute(
        "SELECT LEFT(note_cn, 70) n, COUNT(*) c FROM dwd.dwd_digikey_component_param WHERE category=%s GROUP BY 1 ORDER BY c DESC LIMIT 6",
        (cat,),
    )
    print(f"\n--- {cat} ---")
    for r in cur.fetchall():
        print(f"  {r['c']:4} {r['n']!r}")

conn.close()
