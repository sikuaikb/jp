#!/usr/bin/env python3
"""查 rohs_compliant 仍非 tinyint 的 L2 表。"""
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
    charset="utf8mb4", cursorclass=pymysql.cursors.DictCursor)
c = conn.cursor()
c.execute("""SELECT table_name, data_type FROM information_schema.columns
    WHERE table_schema='dwd' AND table_name LIKE 'dwd_l2_%' AND column_name='rohs_compliant'
      AND data_type<>'tinyint'""")
rows = c.fetchall()
print(f"非 tinyint 残留: {len(rows)}")
for r in rows:
    print(f"  {r['table_name']:55s} {r['data_type']}")
c.close(); conn.close()
