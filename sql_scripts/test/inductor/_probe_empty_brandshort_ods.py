#!/usr/bin/env python3
"""157 行根因：ODS 是 制造商 空还是只有 Manufacturer"""
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
WITH empty AS (
    SELECT p.partno
    FROM dwd.dwd_component_class c
    JOIN dwd.dwd_digikey_component_param p ON p.id = c.id
    WHERE c.l1_code = 'inductor'
      AND NULLIF(TRIM(COALESCE(p.brandshort, '')), '') IS NULL
)
SELECT
    COUNT(*) AS total,
    SUM(CASE WHEN NULLIF(TRIM(COALESCE(get_json_string(o.product_info, '$.制造商'), '')), '') IS NOT NULL THEN 1 ELSE 0 END) AS ods_has_mfr_cn,
    SUM(CASE WHEN NULLIF(TRIM(COALESCE(get_json_string(o.product_info, '$.Manufacturer'), '')), '') IS NOT NULL THEN 1 ELSE 0 END) AS ods_has_mfr_en,
    SUM(CASE WHEN NULLIF(TRIM(COALESCE(get_json_string(o.product_info, '$.制造商'), '')), '') IS NULL
              AND NULLIF(TRIM(COALESCE(get_json_string(o.product_info, '$.Manufacturer'), '')), '') IS NULL THEN 1 ELSE 0 END) AS ods_both_empty
FROM empty e
JOIN ods.ods_digikey_component_detail o ON o.mfr_part_no = e.partno
""")
print("=== ODS product_info 制造商 / Manufacturer ===")
print(cur.fetchone())

cur.execute("""
SELECT e.partno,
       get_json_string(o.product_info, '$.制造商') AS cn,
       get_json_string(o.product_info, '$.Manufacturer') AS en
FROM (
    SELECT p.partno
    FROM dwd.dwd_component_class c
    JOIN dwd.dwd_digikey_component_param p ON p.id = c.id
    WHERE c.l1_code = 'inductor'
      AND NULLIF(TRIM(COALESCE(p.brandshort, '')), '') IS NULL
) e
JOIN ods.ods_digikey_component_detail o ON o.mfr_part_no = e.partno
WHERE NULLIF(TRIM(COALESCE(get_json_string(o.product_info, '$.制造商'), '')), '') IS NULL
  AND NULLIF(TRIM(COALESCE(get_json_string(o.product_info, '$.Manufacturer'), '')), '') IS NULL
LIMIT 10
""")
print("\n=== ODS 两边都空（样本）===")
for r in cur.fetchall():
    print(r)

conn.close()
