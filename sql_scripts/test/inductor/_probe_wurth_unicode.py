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
cur.execute("SELECT UPPER(TRIM('Würth Elektronik')) k")
k = cur.fetchone()["k"]
print("repr:", repr(k))
for ch in k:
    print(hex(ord(ch)), ch)
cur.execute("SELECT brand_id_std FROM dim.v_std_brand_alias WHERE brand_key=%s", (k,))
print("hit with ods upper:", cur.fetchone())
c.close()
