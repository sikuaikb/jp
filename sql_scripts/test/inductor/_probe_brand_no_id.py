#!/usr/bin/env python3
from pathlib import Path
import pymysql
env={}
for line in Path('sql_scripts/local.env').read_text(encoding='utf-8').splitlines():
    if line.strip().startswith('export '):
        k,v=line[7:].split('=',1); env[k]=v.strip(chr(39))
c=pymysql.connect(host=env['MYSQL_HOST'],port=int(env['MYSQL_PORT']),user=env['MYSQL_USER'],password=env['MYSQL_PASSWORD'],charset='utf8mb4')
cur=c.cursor()
cur.execute("""
SELECT brand, data_source, COUNT(*) c FROM dwd.dwd_l2_inductor_power_inductor
WHERE brandid IS NULL AND brand IS NOT NULL AND TRIM(brand)!=''
GROUP BY 1,2 ORDER BY c DESC LIMIT 15
""")
print('power brand_no_id samples:')
for r in cur.fetchall(): print(r)
cur.execute("SELECT COUNT(*) FROM dim.dim_attr_extract_rule WHERE extract_rule_id REGEXP '^inductor_'")
print('prod extract rules:', cur.fetchone())
c.close()
