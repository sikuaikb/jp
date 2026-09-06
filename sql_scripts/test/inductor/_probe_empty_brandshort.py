#!/usr/bin/env python3
"""157 行：追 ODS product_info.制造商 与 prajson 里是否有制造商"""
import os, pymysql
from pathlib import Path

for line in Path("sql_scripts/local.env").read_text(encoding="utf-8").splitlines():
    if line.strip().startswith("export "):
        k, _, v = line[7:].partition("=")
        os.environ[k] = v.strip().strip("'\"")

conn = pymysql.connect(
    host=os.environ["MYSQL_HOST"], port=int(os.environ["MYSQL_PORT"]),
    user=os.environ["MYSQL_USER"], password=os.environ["MYSQL_PASSWORD"],
    charset="utf8mb4", cursorclass=pymysql.cursors.DictCursor,
)
cur = conn.cursor()

cur.execute("""
SELECT p.partno,
       p.brandshort,
       get_json_string(p.prajson, '$.制造商') AS mfr_prajson,
       get_json_string(p.prajson, '$.Manufacturer') AS mfr_en
FROM dwd.dwd_component_class c
JOIN dwd.dwd_digikey_component_param p ON p.id = c.id
WHERE c.l1_code = 'inductor'
  AND NULLIF(TRIM(COALESCE(p.brandshort, '')), '') IS NULL
LIMIT 12
""")
print("=== DWD: brandshort vs prajson 制造商 ===")
rows = cur.fetchall()
for r in rows:
    print(r)

if rows:
    partnos = [r["partno"] for r in rows[:5]]
    ph = ",".join(["%s"] * len(partnos))
    cur.execute(
        f"""
        SELECT mfr_part_no,
               get_json_string(product_info, '$.制造商') AS mfr_cn,
               get_json_string(product_info, '$.Manufacturer') AS mfr_en,
               category
        FROM ods.ods_digikey_component_detail
        WHERE mfr_part_no IN ({ph})
        """,
        partnos,
    )
    print("\n=== ODS 原始 product_info.制造商（样本 5）===")
    for r in cur.fetchall():
        print(r)

cur.execute("""
SELECT
    SUM(CASE WHEN get_json_string(p.prajson, '$.制造商') IS NOT NULL
              AND TRIM(get_json_string(p.prajson, '$.制造商')) <> '' THEN 1 ELSE 0 END) AS prajson_has_mfr,
    SUM(CASE WHEN get_json_string(p.prajson, '$.Manufacturer') IS NOT NULL
              AND TRIM(get_json_string(p.prajson, '$.Manufacturer')) <> '' THEN 1 ELSE 0 END) AS prajson_has_mfr_en,
    COUNT(*) AS total
FROM dwd.dwd_component_class c
JOIN dwd.dwd_digikey_component_param p ON p.id = c.id
WHERE c.l1_code = 'inductor'
  AND NULLIF(TRIM(COALESCE(p.brandshort, '')), '') IS NULL
""")
print("\n=== 157 行 prajson 制造商字段统计 ===")
print(cur.fetchone())

conn.close()
