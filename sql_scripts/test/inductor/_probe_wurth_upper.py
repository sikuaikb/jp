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
cur.execute("SELECT UPPER('Würth Elektronik') AS u, UPPER('Weidmüller') AS w")
print("UPPER:", cur.fetchone())
cur.execute(
    "SELECT brand_key, canonical_name FROM dim.v_std_brand_alias "
    "WHERE brand_key LIKE '%WURTH%' OR brand_key LIKE '%WEID%' LIMIT 15"
)
print("alias hits:", cur.fetchall())
cur.execute(
    "SELECT related_words FROM dim.dim_std_brand WHERE brand_id_std=1443490691236597766"
)
print("wurth rw:", cur.fetchone())
c.close()
