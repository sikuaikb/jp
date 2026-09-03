#!/usr/bin/env python3
"""dim-attr-std-merge precheck for inductor."""
from pathlib import Path
import pymysql

L1 = "inductor"
L2S = ["power_inductor", "hf_chip_inductor", "emi_filter_inductor"]

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

def run(title, sql, limit=20):
    print(f"\n=== {title} ===")
    try:
        cur.execute(sql)
        rows = cur.fetchall()
        for r in rows[:limit]:
            print(r)
        if len(rows) > limit:
            print(f"... +{len(rows)-limit}")
        if not rows:
            print("(empty)")
        return rows
    except Exception as e:
        print("ERR:", e)
        return []

run("test_dim attr tables", "SHOW TABLES FROM test_dim LIKE '%inductor%'")
run("test_dwd attr/l2 tables", "SHOW TABLES FROM test_dwd LIKE '%inductor%'")

run("prod schema inductor", f"SELECT COUNT(*) FROM dim.dim_attr_schema WHERE l1_code='{L1}'")
run("test schema inductor", f"SELECT COUNT(*) FROM test_dim.dim_attr_schema_{L1}")
run("prod extract_rule inductor", f"""
SELECT COUNT(*) FROM dim.dim_attr_extract_rule
WHERE l1_code='{L1}' OR extract_rule_id REGEXP '^{L1}_'
""")
run("test extract_rule inductor", f"SELECT COUNT(*) FROM test_dim.dim_attr_extract_rule_{L1}")

run("schema PK conflict count", f"""
SELECT COUNT(*) FROM (
  SELECT schema_version, l1_code, scope_level, scope_code, std_attr_code, COUNT(*) c FROM (
    SELECT schema_version, l1_code, scope_level, scope_code, std_attr_code
    FROM dim.dim_attr_schema WHERE l1_code <> '{L1}'
    UNION ALL
    SELECT schema_version, l1_code, scope_level, scope_code, std_attr_code
    FROM test_dim.dim_attr_schema_{L1}
  ) u GROUP BY 1,2,3,4,5 HAVING COUNT(*)>1
) x
""")

run("extract_rule PK conflict count", f"""
SELECT COUNT(*) FROM (
  SELECT extract_rule_id, COUNT(*) c FROM (
    SELECT extract_rule_id FROM dim.dim_attr_extract_rule
    WHERE l1_code <> '{L1}' AND extract_rule_id NOT REGEXP '^{L1}_'
    UNION ALL SELECT extract_rule_id FROM test_dim.dim_attr_extract_rule_{L1}
  ) u GROUP BY extract_rule_id HAVING COUNT(*)>1
) x
""")

run("bad extract_rule_id prefix", f"""
SELECT extract_rule_id, COUNT(*) FROM test_dim.dim_attr_extract_rule_{L1}
WHERE extract_rule_id NOT REGEXP '^{L1}_' GROUP BY 1 LIMIT 10
""")

run("orphan extract rules", f"""
SELECT COUNT(DISTINCT r.std_attr_code) FROM test_dim.dim_attr_extract_rule_{L1} r
LEFT JOIN test_dim.dim_attr_schema_{L1} s
  ON s.schema_version=r.schema_version AND s.l1_code='{L1}' AND s.std_attr_code=r.std_attr_code
WHERE s.std_attr_code IS NULL
""")

run("classify inductor prod", f"""
SELECT data_source, COUNT(*) FROM dwd.dwd_component_class WHERE l1_code='{L1}' GROUP BY 1
""")

run("test EAV inductor suffix", f"SELECT COUNT(*) FROM test_dwd.dwd_component_attr_std_{L1}")

for l2 in L2S:
    tbl = f"test_dwd.dwd_l2_{L1}_{l2}_{L1}"  # stage1 double suffix
    run(f"L2 suffix {tbl} exists", f"SELECT COUNT(*) FROM {tbl}")
    run(f"L2 brand_null {l2}", f"""
    SELECT SUM(CASE WHEN brand IS NULL OR brand='' THEN 1 ELSE 0 END) brand_null,
           COUNT(*) total,
           COUNT(DISTINCT brand) db, COUNT(DISTINCT brandid) di
    FROM {tbl}
    """)

run("prod L2 tables exist", """
SELECT TABLE_NAME FROM information_schema.tables
WHERE TABLE_SCHEMA='dwd' AND TABLE_NAME LIKE 'dwd_l2_inductor%'
""")

run("unit supplement table", "SHOW TABLES FROM test_dim LIKE '%unit%inductor%'")

conn.close()
