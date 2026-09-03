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
for title, q in [
    ("dim name GOWANDA", "SELECT brand_id_std,name,source FROM dim.dim_std_brand WHERE UPPER(name) LIKE '%GOWANDA%'"),
    ("alias GOWANDA", "SELECT brand_key,canonical_name,brand_id_std FROM dim.v_std_brand_alias WHERE brand_key LIKE '%GOWANDA%'"),
    ("jp_brand GOWANDA", "SELECT id,name FROM ods.ods_jp_brand WHERE UPPER(name) LIKE '%GOWANDA%' LIMIT 5"),
    ("manual 900025x sample", "SELECT brand_id_std,name,source FROM dim.dim_std_brand WHERE brand_id_std BETWEEN 9000250 AND 9000350 ORDER BY brand_id_std LIMIT 15"),
    ("manual_extra count", "SELECT COUNT(*) n FROM dim.dim_std_brand WHERE source='manual_extra'"),
    ("9M segment count", "SELECT COUNT(*) n FROM dim.dim_std_brand WHERE brand_id_std >= 9000001"),
    ("DELEVAN alias", "SELECT brand_key,canonical_name FROM dim.v_std_brand_alias WHERE brand_key='DELEVAN'"),
    ("CODACA alias", "SELECT brand_key,canonical_name FROM dim.v_std_brand_alias WHERE brand_key LIKE '%CODACA%'"),
    ("all manual_extra names", "SELECT brand_id_std,name FROM dim.dim_std_brand WHERE source='manual_extra' ORDER BY brand_id_std"),
]:
    print("===", title, "===")
    cur.execute(q)
    for r in cur.fetchall():
        print(r)
c.close()
