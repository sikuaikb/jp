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
SELECT COUNT(*) FROM dwd.dwd_component_class c
JOIN dwd.dwd_digikey_component_param p ON p.id=c.id
WHERE c.data_source='digikey' AND c.l1_code='inductor' AND c.l2_code='power_inductor'
  AND (p.brandshort IS NULL OR TRIM(p.brandshort)='')
""")
print('dk power inductor class with empty brandshort:', cur.fetchone())
cur.execute("""
SELECT COUNT(*) FROM dwd.dwd_component_class c
JOIN dwd.dwd_digikey_component_param p ON p.id=c.id
WHERE c.data_source='digikey' AND c.l1_code='inductor' AND c.l2_code='power_inductor'
""")
print('dk power inductor class total:', cur.fetchone())
c.close()
