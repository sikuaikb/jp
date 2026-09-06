#!/usr/bin/env python3
from pathlib import Path
import pymysql
from collections import defaultdict

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

print("=== dim attr inductor ===")
for q in [
    ("schema", f"SELECT COUNT(*) FROM dim.dim_attr_schema WHERE l1_code='{L1}'"),
    ("rule prefix", f"SELECT COUNT(*) FROM dim.dim_attr_extract_rule WHERE extract_rule_id REGEXP '^{L1}_'"),
]:
    cur.execute(q[1])
    print(q[0], cur.fetchone())

print("\n=== EAV total ===")
cur.execute("SELECT data_source, COUNT(*) FROM dwd.dwd_component_attr_std GROUP BY 1")
for r in cur.fetchall():
    print(r)

print("\n=== EAV inductor rows (via class join sample) ===")
cur.execute(f"""
SELECT e.data_source, COUNT(*) FROM dwd.dwd_component_attr_std e
JOIN dwd.dwd_component_class c ON c.id=e.id AND c.data_source=e.data_source
WHERE c.l1_code='{L1}' GROUP BY 1
""")
for r in cur.fetchall():
    print(r)

print("\n=== prod L2 ===")
for l2 in L2S:
    tbl = f"dwd.dwd_l2_{L1}_{l2}"
    try:
        cur.execute(f"SELECT data_source, COUNT(*) FROM {tbl} GROUP BY 1")
        d = defaultdict(int)
        for ds, n in cur.fetchall():
            d[ds] += int(n)
        cur.execute(f"""
            SELECT SUM(CASE WHEN brand IS NULL OR TRIM(brand)='' THEN 1 ELSE 0 END),
                   SUM(CASE WHEN brandid IS NULL THEN 1 ELSE 0 END), COUNT(*)
            FROM {tbl}
        """)
        b = cur.fetchone()
        print(f"{tbl}: ds={dict(d)} brand_null={b[0]} brand_no_id={b[1]} total={b[2]}")
    except Exception as e:
        print(f"{tbl}: ERR {e}")

conn.close()
