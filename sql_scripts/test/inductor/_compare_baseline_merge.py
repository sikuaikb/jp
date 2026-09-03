#!/usr/bin/env python3
"""Compare stage1 baseline vs merge table for inductor icpdf."""
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

def run(title, sql):
    print(f"\n=== {title} ===")
    cur.execute(sql)
    for r in cur.fetchall()[:20]:
        print(r)

run("baseline icpdf top l3", """
SELECT l3_code, COUNT(*) c FROM test_dwd.dwd_component_class_inductor
WHERE data_source='icpdf' AND l1_code='inductor'
GROUP BY 1 ORDER BY c DESC LIMIT 15
""")
run("merge icpdf top l3", """
SELECT l3_code, COUNT(*) c FROM test_dwd.dwd_component_class_merge_inductor
WHERE data_source='icpdf' AND l1_code='inductor'
GROUP BY 1 ORDER BY c DESC LIMIT 15
""")
run("only in baseline count", """
SELECT COUNT(*) FROM test_dwd.dwd_component_class_inductor b
WHERE b.data_source='icpdf' AND b.l1_code='inductor'
AND NOT EXISTS (
  SELECT 1 FROM test_dwd.dwd_component_class_merge_inductor m
  WHERE m.data_source=b.data_source AND m.id=b.id
    AND m.l1_code='inductor'
)
""")
run("only in merge count", """
SELECT COUNT(*) FROM test_dwd.dwd_component_class_merge_inductor m
WHERE m.data_source='icpdf' AND m.l1_code='inductor'
AND NOT EXISTS (
  SELECT 1 FROM test_dwd.dwd_component_class_inductor b
  WHERE b.data_source=m.data_source AND b.id=m.id
    AND b.l1_code='inductor'
)
""")
run("same id different l3 sample", """
SELECT b.id, b.l3_code b_l3, m.l3_code m_l3
FROM test_dwd.dwd_component_class_inductor b
JOIN test_dwd.dwd_component_class_merge_inductor m
  ON b.data_source=m.data_source AND b.id=m.id
WHERE b.l1_code='inductor' AND m.l1_code='inductor'
  AND b.data_source='icpdf' AND b.l3_code <> m.l3_code
LIMIT 10
""")
conn.close()
