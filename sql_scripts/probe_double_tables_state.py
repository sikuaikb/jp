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
print("=== 4 张 double 表当前列状态 ===")
for t in tabs:
    c.execute(
        "SELECT column_name, data_type FROM information_schema.columns "
        "WHERE table_schema='dwd' AND table_name=%s AND column_name LIKE 'lead_free%%'",
        (t,),
    )
    print(f"\n{t}:")
    for r in c.fetchall():
        print(f"  {r['column_name']:20s} {r['data_type']}")

print("\n=== pending schema change jobs ===")
for t in tabs:
    try:
        c.execute(f"SHOW ALTER TABLE COLUMN FROM dwd.{t}")
        rows = c.fetchall()
        print(f"{t}: {len(rows)} pending jobs")
        for r in rows:
            print(f"  {dict(r)}")
    except Exception as e:
        print(f"{t}: SHOW ALTER ERR {e}")

c.close(); conn.close()
