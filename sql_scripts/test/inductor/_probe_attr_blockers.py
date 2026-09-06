#!/usr/bin/env python3
from pathlib import Path
import pymysql
from collections import defaultdict

env = {}
for line in Path("sql_scripts/local.env").read_text(encoding="utf-8").splitlines():
    if line.strip().startswith("export "):
        k, v = line[7:].split("=", 1)
        env[k] = v.strip("'")

conn = pymysql.connect(host=env["MYSQL_HOST"], port=int(env["MYSQL_PORT"]),
    user=env["MYSQL_USER"], password=env["MYSQL_PASSWORD"], charset="utf8mb4")
cur = conn.cursor()

def sum_ds(sql):
    cur.execute(sql)
    d = defaultdict(int)
    for ds, n in cur.fetchall():
        d[ds] += int(n)
    return dict(d)

print("classify prod inductor (summed):", sum_ds(
    "SELECT data_source, COUNT(*) FROM dwd.dwd_component_class WHERE l1_code='inductor' GROUP BY 1"))

for l2 in ["power_inductor", "hf_chip_inductor", "emi_filter_inductor"]:
    tbl = f"test_dwd.dwd_l2_inductor_{l2}_inductor"
    cur.execute(f"""
        SELECT data_source,
          SUM(CASE WHEN brand IS NULL OR TRIM(brand)='' THEN 1 ELSE 0 END) bn,
          SUM(CASE WHEN brandid IS NULL THEN 1 ELSE 0 END) bni,
          COUNT(*) total
        FROM {tbl} GROUP BY 1
    """)
    print(f"\n{l2} brand by source:")
    for r in cur.fetchall():
        print(r)

cur.execute("""
SELECT brandshort, COUNT(*) c FROM (
  SELECT p.brandshort
  FROM test_dwd.dwd_l2_inductor_power_inductor_inductor t
  JOIN dwd.dwd_icpdf_component_param p ON p.id=t.id AND t.data_source='icpdf'
  WHERE t.brand IS NULL OR TRIM(t.brand)=''
  LIMIT 5000
) x GROUP BY 1 ORDER BY c DESC LIMIT 10
""")
print("\nnull brand brandshort sample (power icpdf):")
for r in cur.fetchall(): print(r)

cur.execute("""
SELECT COUNT(DISTINCT extract_rule_id) FROM test_dim.dim_attr_extract_rule_inductor
WHERE extract_rule_id NOT IN (
  SELECT extract_rule_id FROM dim.dim_attr_extract_rule WHERE l1_code='inductor' OR extract_rule_id REGEXP '^inductor_'
)
""")
print("\ntest-only extract_rule_id count:", cur.fetchone())

cur.execute("SELECT COUNT(*) FROM dwd.dwd_l2_inductor_power_inductor")
print("prod L2 power row count:", cur.fetchone())

conn.close()
