#!/usr/bin/env python3
from pathlib import Path
import pymysql
env={}
for line in Path('sql_scripts/local.env').read_text(encoding='utf-8').splitlines():
    if line.strip().startswith('export '):
        k,v=line[7:].split('=',1); env[k]=v.strip(chr(39))
conn=pymysql.connect(host=env['MYSQL_HOST'],port=int(env['MYSQL_PORT']),user=env['MYSQL_USER'],password=env['MYSQL_PASSWORD'],charset='utf8mb4')
cur=conn.cursor()
cur.execute("SELECT MAX(LENGTH(l2_code)) FROM dim.dim_l3_classify")
print('max l2_code dim:', cur.fetchone())
cur.execute("SELECT l2_code, LENGTH(l2_code) l FROM dim.dim_l3_classify WHERE LENGTH(l2_code)>32 ORDER BY l DESC LIMIT 15")
for r in cur.fetchall(): print(r)
conn.close()
