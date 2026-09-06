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
    "dwd_l2_driver_ic_laser_driver",
    "dwd_l2_circuit_protection_surge_protection_module",
    "dwd_l2_interface_communication_ic_digital_isolation_interface",
    "dwd_l2_amplifier_transimpedance_transconductance_log_amp",
    "dwd_l2_storage_nv_ram",
]
for t in tabs:
    c.execute(
        "SELECT data_type FROM information_schema.columns "
        "WHERE table_schema='dwd' AND table_name=%s AND column_name='lead_free'",
        (t,),
    )
    print(f"{t}: {c.fetchone()['data_type']}")
c.close(); conn.close()
