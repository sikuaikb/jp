#!/usr/bin/env python3
"""端到端最终校验: dim/EAV 旧码 + lead_free 类型 + EAV lead_free 值。"""
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

OLD = ("ro_hs_compliant", "life_cycle_status", "mounting_type", "aec_qualified")

print("=== 1. dim/EAV 旧码残留 ===")
tables = ["dim.dim_std_component_attr", "dim.dim_attr_schema",
          "dim.dim_attr_extract_rule", "dwd.dwd_component_attr_std"]
total = 0
for t in tables:
    for old in OLD:
        c.execute(f"SELECT COUNT(*) n FROM {t} WHERE std_attr_code=%s", (old,))
        n = c.fetchone()["n"]
        if n:
            print(f"  {t} 残留 {old}: {n}")
            total += n
print(f"  -> {'OK 全清' if total == 0 else 'FAIL'}")

print("\n=== 2. DWD L2 lead_free 列类型 ===")
c.execute("""
    SELECT data_type, COUNT(*) n FROM information_schema.columns
    WHERE table_schema='dwd' AND table_name LIKE 'dwd_l2_%' AND column_name='lead_free'
    GROUP BY data_type
""")
rows = c.fetchall()
for r in rows:
    print(f"  {r['data_type']}: {r['n']} 张")
ti = next((r["n"] for r in rows if r["data_type"] == "tinyint"), 0)
tot = sum(r["n"] for r in rows)
print(f"  -> {'OK 全 tinyint' if ti == tot else 'FAIL'}")

print("\n=== 3. EAV lead_free 值分布 (应仅 1/0/NULL) ===")
c.execute("""
    SELECT value_std_varchar v, COUNT(*) n FROM dwd.dwd_component_attr_std
    WHERE std_attr_code='lead_free' GROUP BY value_std_varchar ORDER BY n DESC
""")
for r in c.fetchall():
    print(f"  {str(r['v']):8s} {r['n']:>10,}")

c.close(); conn.close()
