#!/usr/bin/env python3
"""rohs_compliant 端到端校验: EAV 值 + L2 列类型 + schema db_type。"""
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

print("=== 1. EAV rohs_compliant value_std_varchar 分布 ===")
c.execute("""SELECT value_std_varchar v, COUNT(*) n FROM dwd.dwd_component_attr_std
    WHERE std_attr_code='rohs_compliant' GROUP BY value_std_varchar ORDER BY n DESC""")
for r in c.fetchall():
    print(f"  {str(r['v']):8s} {r['n']:>10,}")

print("\n=== 2. DWD L2 rohs_compliant 列类型 ===")
c.execute("""SELECT data_type, COUNT(*) n FROM information_schema.columns
    WHERE table_schema='dwd' AND table_name LIKE 'dwd_l2_%' AND column_name='rohs_compliant'
    GROUP BY data_type""")
rows = c.fetchall()
for r in rows:
    print(f"  {r['data_type']}: {r['n']} 张")
ti = next((r["n"] for r in rows if r["data_type"]=="tinyint"), 0)
tot = sum(r["n"] for r in rows)
print(f"  -> {'OK 全 tinyint' if ti==tot else 'FAIL'}")

print("\n=== 3. dim_attr_schema rohs_compliant db_type ===")
c.execute("""SELECT db_type, COUNT(*) n FROM dim.dim_attr_schema
    WHERE std_attr_code='rohs_compliant' GROUP BY db_type""")
for r in c.fetchall():
    print(f"  {r['db_type']}: {r['n']}")

c.close(); conn.close()
