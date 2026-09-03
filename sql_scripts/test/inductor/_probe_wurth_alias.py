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
for key in ["WÜRTH ELEKTRONIK", "WURTH ELEKTRONIK", "WEIDMÜLLER"]:
    cur.execute("SELECT brand_key, canonical_name, brand_id_std, alias_kind FROM dim.v_std_brand_alias WHERE brand_key=%s", (key,))
    print(key, "->", cur.fetchall())
cur.execute(
    "SELECT brand_key, canonical_name, brand_id_std FROM dim.v_std_brand_alias "
    "WHERE brand_key IN (SELECT UPPER(TRIM('Würth Elektronik')))"
)
print("subquery:", cur.fetchall())
c.close()
