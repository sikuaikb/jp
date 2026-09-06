#!/usr/bin/env python3
import os, pymysql
from pathlib import Path
for line in Path("sql_scripts/local.env").read_text(encoding="utf-8").splitlines():
    if line.strip().startswith("export "):
        k, _, v = line[7:].partition("=")
        os.environ[k] = v.strip().strip("'\"")
c = pymysql.connect(
    host=os.environ["MYSQL_HOST"], port=int(os.environ["MYSQL_PORT"]),
    user=os.environ["MYSQL_USER"], password=os.environ["MYSQL_PASSWORD"],
    cursorclass=pymysql.cursors.DictCursor,
)
cur = c.cursor()
cur.execute("""
SELECT p.brandshort,
       UPPER(TRIM(p.brandshort)) AS bk,
       COUNT(DISTINCT c.id) n,
       MAX(CASE WHEN a.brand_id_std IS NULL THEN 1 ELSE 0 END) miss
FROM dwd.dwd_component_class c
JOIN dwd.dwd_digikey_component_param p ON p.id=c.id
LEFT JOIN dim.v_std_brand_alias a ON a.brand_key = UPPER(TRIM(p.brandshort))
WHERE c.l1_code='inductor' AND p.brandshort LIKE '%rth%'
GROUP BY 1,2 ORDER BY n DESC LIMIT 10
""")
for r in cur.fetchall():
    cur.execute("SELECT brand_id_std FROM dim.v_std_brand_alias WHERE brand_key=%s", (r["bk"],))
    hit = cur.fetchone()
    print(r, "alias_hit=", hit)
c.close()
