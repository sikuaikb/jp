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

for l2 in ["power_inductor", "hf_chip_inductor", "emi_filter_inductor"]:
    tbl = f"test_dwd.dwd_l2_inductor_{l2}_inductor"
    cur.execute(f"""
        SELECT SUM(CASE WHEN brand IS NULL OR TRIM(brand)='' THEN 1 ELSE 0 END),
               SUM(CASE WHEN brandid IS NULL THEN 1 ELSE 0 END),
               COUNT(*),
               COUNT(DISTINCT brand), COUNT(DISTINCT brandid)
        FROM {tbl}
    """)
    print(l2, "totals:", cur.fetchone())

cur.execute("""
SELECT t.data_source, p.brandshort, COUNT(*) c
FROM test_dwd.dwd_l2_inductor_power_inductor_inductor t
JOIN dwd.dwd_digikey_component_param p ON p.id=t.id AND t.data_source='digikey'
WHERE t.brand IS NULL OR TRIM(t.brand)=''
GROUP BY 1,2 ORDER BY c DESC LIMIT 15
""")
print("\ndigikey null brand brandshort (power):")
for r in cur.fetchall(): print(r)

cur.execute("SELECT COUNT(*) FROM dim.dim_attr_extract_rule WHERE l1_code='inductor'")
print("\nprod extract_rule l1_code=inductor:", cur.fetchone())
cur.execute("SELECT COUNT(*) FROM dim.dim_attr_extract_rule WHERE extract_rule_id REGEXP '^inductor_'")
print("prod extract_rule inductor_ prefix:", cur.fetchone())

conn.close()
