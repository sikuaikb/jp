#!/usr/bin/env python3
"""估算 foundation brandshort 修复后可恢复的 inductor 行数"""
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
    SELECT c.id, c.data_source, p.partno, p.brandshort,
           substr(TRIM(split_part(
               COALESCE(
                   NULLIF(TRIM(get_json_string(p.prajson, '$.制造商')), ''),
                   NULLIF(TRIM(get_json_string(p.prajson, '$.Manufacturer')), '')
               ), ' (', 1)), 1, 128) AS brandshort_fix
    FROM dwd.dwd_component_class c
    JOIN dwd.dwd_digikey_component_param p ON p.id = c.id
    WHERE c.l1_code = 'inductor'
      AND NULLIF(TRIM(COALESCE(p.brandshort, '')), '') IS NULL
)
SELECT
    COUNT(*) AS empty_total,
    SUM(CASE WHEN NULLIF(TRIM(brandshort_fix), '') IS NOT NULL THEN 1 ELSE 0 END) AS recoverable_from_prajson,
    SUM(CASE WHEN NULLIF(TRIM(brandshort_fix), '') IS NULL THEN 1 ELSE 0 END) AS still_empty,
    SUM(CASE WHEN a.brand_id_std IS NOT NULL THEN 1 ELSE 0 END) AS recoverable_and_brand_mapped
FROM empty e
LEFT JOIN dim.v_std_brand_alias a ON a.brand_key = UPPER(TRIM(e.brandshort_fix))
""")
print("=== inductor 空 brandshort 修复估算 ===")
print(cur.fetchone())

cur.execute("""
SELECT e.brandshort_fix, COUNT(*) n
FROM (
    SELECT substr(TRIM(split_part(
               COALESCE(
                   NULLIF(TRIM(get_json_string(p.prajson, '$.制造商')), ''),
                   NULLIF(TRIM(get_json_string(p.prajson, '$.Manufacturer')), '')
               ), ' (', 1)), 1, 128) AS brandshort_fix
    FROM dwd.dwd_component_class c
    JOIN dwd.dwd_digikey_component_param p ON p.id = c.id
    WHERE c.l1_code = 'inductor'
      AND NULLIF(TRIM(COALESCE(p.brandshort, '')), '') IS NULL
) e
LEFT JOIN dim.v_std_brand_alias a ON a.brand_key = UPPER(TRIM(e.brandshort_fix))
WHERE NULLIF(TRIM(e.brandshort_fix), '') IS NOT NULL AND a.brand_id_std IS NULL
GROUP BY 1 ORDER BY n DESC LIMIT 10
""")
print("\n=== 可恢复但未映射品牌 Top ===")
for r in cur.fetchall():
    print(r)

conn.close()
