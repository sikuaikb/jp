#!/usr/bin/env python3
"""查 dim.dim_attr_schema 里 lead_free 的 VARCHAR 行详情, 确认改 BOOLEAN 安全。
并对比 BOOLEAN 行的 value_domain, 决定 VARCHAR 行的 value_domain 是否要同步改。"""
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

print("=== lead_free BOOLEAN 行的 value_domain 样本 ===")
c.execute("""
    SELECT l1_code, scope_level, scope_code, db_type, value_domain, std_attr_cn
    FROM dim.dim_attr_schema
    WHERE std_attr_code='lead_free' AND db_type='BOOLEAN'
    LIMIT 10
""")
for r in c.fetchall():
    print(f"  l1={r['l1_code']:20s} {r['scope_level']:5s} {str(r['scope_code']):22s} dom={r['value_domain']}")

print("\n=== lead_free VARCHAR 行的 value_domain 分布 ===")
c.execute("""
    SELECT value_domain, COUNT(*) n, GROUP_CONCAT(DISTINCT l1_code) l1s
    FROM dim.dim_attr_schema
    WHERE std_attr_code='lead_free' AND db_type='VARCHAR'
    GROUP BY value_domain
""")
for r in c.fetchall():
    print(f"  dom={str(r['value_domain']):30s} n={r['n']:>3}  l1={r['l1s']}")

c.close(); conn.close()
