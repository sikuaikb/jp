#!/usr/bin/env python3
"""查 dim.dim_attr_schema 里 lifecycle_status / rohs_compliant / mounting_style / aec_q_level
各 std_attr_code 的 db_type 分布, 找出 db_type 不一致的。"""
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

for code in ["lifecycle_status", "rohs_compliant", "mounting_style", "aec_q_level", "lead_free"]:
    print(f"\n=== {code} db_type 分布 ===")
    c.execute("""
        SELECT db_type, COUNT(*) n, GROUP_CONCAT(DISTINCT l1_code) l1s
        FROM dim.dim_attr_schema
        WHERE std_attr_code=%s
        GROUP BY db_type
    """, (code,))
    for r in c.fetchall():
        print(f"  {r['db_type']:10s} n={r['n']:>4}  l1={r['l1s']}")

c.close(); conn.close()
