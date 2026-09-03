#!/usr/bin/env python3
from pathlib import Path
import pymysql

env = {}
for line in Path("sql_scripts/local.env").read_text(encoding="utf-8").splitlines():
    if line.strip().startswith("export "):
        k, v = line[7:].split("=", 1)
        env[k] = v.strip("'")

conn = pymysql.connect(
    host=env["MYSQL_HOST"], port=int(env["MYSQL_PORT"]),
    user=env["MYSQL_USER"], password=env["MYSQL_PASSWORD"], charset="utf8mb4",
)
cur = conn.cursor()

checks = [
    ("dwd DDL", "SHOW CREATE TABLE dwd.dwd_component_class"),
    ("merge DDL", "SHOW CREATE TABLE test_dwd.dwd_component_class_merge_inductor"),
    ("max l2_code classify", "SELECT MAX(LENGTH(l2_code)) FROM dim.dim_l3_classify WHERE l1_code='inductor'"),
    ("long l2_code", "SELECT l2_code, LENGTH(l2_code) l FROM dim.dim_l3_classify WHERE l1_code='inductor' ORDER BY l DESC LIMIT 5"),
    ("max rule_id", "SELECT MAX(LENGTH(rule_id)) FROM dim.dim_l3_classify_rule WHERE rule_id REGEXP '^inductor_|^gate_inductor_'"),
    ("long rule_id", "SELECT rule_id, LENGTH(rule_id) l FROM dim.dim_l3_classify_rule WHERE rule_id REGEXP '^inductor_|^gate_inductor_' ORDER BY l DESC LIMIT 5"),
    ("max schema_version", "SELECT MAX(LENGTH(schema_version)) FROM dim.dim_l3_classify_rule WHERE rule_id REGEXP '^inductor_|^gate_inductor_'"),
    ("prod dim rule count", "SELECT COUNT(*) FROM dim.dim_l3_classify_rule WHERE rule_id REGEXP '^inductor_|^gate_inductor_'"),
]
for title, sql in checks:
    print(f"\n=== {title} ===")
    try:
        cur.execute(sql)
        for r in cur.fetchall():
            print(r if len(str(r)) < 300 else str(r)[:300] + "...")
    except Exception as e:
        print("ERR:", e)
conn.close()
