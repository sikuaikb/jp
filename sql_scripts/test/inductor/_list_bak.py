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
)
cur = c.cursor()
for pat in ["bak_dim_attr%inductor%", "bak_dim_l3%inductor%"]:
    cur.execute(f"SHOW TABLES FROM dim LIKE '{pat}'")
    print(pat, [r[0] for r in cur.fetchall()])
c.close()
