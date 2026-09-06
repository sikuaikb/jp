#!/usr/bin/env python3
"""全局校验：所有 dwd_l2_* 表的 lead_free 列类型分布。"""
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
c.execute("""
    SELECT data_type, COUNT(*) n
    FROM information_schema.columns
    WHERE table_schema='dwd' AND table_name LIKE 'dwd_l2_%' AND column_name='lead_free'
    GROUP BY data_type
""")
rows = c.fetchall()
print("=== lead_free 列类型分布 ===")
for r in rows:
    print(f"  {r['data_type']:10s} {r['n']} 张")
total = sum(r["n"] for r in rows)
tinyint_n = next((r["n"] for r in rows if r["data_type"] == "tinyint"), 0)
print(f"\n  tinyint: {tinyint_n}/{total}")
if tinyint_n == total:
    print("  ✓ 全部统一为 tinyint")
else:
    print("  ✗ 仍有非 tinyint 列")
    c.execute("""
        SELECT table_name, data_type FROM information_schema.columns
        WHERE table_schema='dwd' AND table_name LIKE 'dwd_l2_%' AND column_name='lead_free'
          AND data_type <> 'tinyint'
    """)
    for r in c.fetchall():
        print(f"    {r['table_name']:55s} {r['data_type']}")
c.close(); conn.close()
