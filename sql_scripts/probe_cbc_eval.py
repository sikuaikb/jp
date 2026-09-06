#!/usr/bin/env python3
"""确认 CBC-EVAL-05B (id=13513774) 当前 EAV lead_free 行状态。"""
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
    SELECT data_source, id, std_attr_code, value_std_varchar, value_std_double, extract_rule_id
    FROM dwd.dwd_component_attr_std
    WHERE id='13513774' AND std_attr_code='lead_free'
""")
rows = c.fetchall()
print(f"id=13513774 lead_free 行: {len(rows)}")
for r in rows:
    print(f"  ds={r['data_source']} varchar={r['value_std_varchar']} double={r['value_std_double']} rule={r['extract_rule_id']}")
c.close(); conn.close()
