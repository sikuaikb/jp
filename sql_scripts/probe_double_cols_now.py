#!/usr/bin/env python3
import os
from pathlib import Path
import pymysql
ENV = Path(__file__).resolve().parent / "local.env"
for line in ENV.read_text(encoding="utf-8").splitlines():
    if line.strip().startswith("export "):
        k, _, v = line[7:].partition("=")
        os.environ[k] = v.strip().strip("'").strip('"')
conn = pymysql.connect(host=os.environ["MYSQL_HOST"], port=9030,
    user=os.environ["MYSQL_USER"], password=os.environ["MYSQL_PASSWORD"],
    charset="utf8mb4", cursorclass=pymysql.cursors.DictCursor)
c = conn.cursor()
tabs = [
    "dwd_l2_isolator_isolated_analog_amplifier",
    "dwd_l2_isolator_rf_isolator_circulator",
    "dwd_l2_isolator_digital_isolator",
    "dwd_l2_isolator_optocoupler",
]
for t in tabs:
    c.execute(
        "SELECT column_name, data_type FROM information_schema.columns "
        "WHERE table_schema='dwd' AND table_name=%s AND column_name LIKE 'lead_free%%'",
        (t,),
    )
    rows = c.fetchall()
    print(f"{t}: {[(r['column_name'], r['data_type']) for r in rows]}")
c.close(); conn.close()
