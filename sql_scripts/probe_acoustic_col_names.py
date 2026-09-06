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
tabs = ["dwd_l2_acoustic_device_speaker","dwd_l2_acoustic_device_microphone",
        "dwd_l2_acoustic_device_buzzer_and_piezo_actuator","dwd_l2_acoustic_device_receiver"]
for t in tabs:
    c.execute("""SELECT column_name, data_type FROM information_schema.columns
        WHERE table_schema='dwd' AND table_name=%s AND (column_name LIKE 'lead_free%%' OR column_name LIKE 'rohs_compliant%%')""",(t,))
    print(f"{t}:")
    for r in c.fetchall():
        print(f"  name='{r['column_name']}' type={r['data_type']}")
c.close(); conn.close()
