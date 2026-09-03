#!/usr/bin/env python3
"""对 16 张残留 varchar 表重跑 ALTER MODIFY rohs_compliant tinyint, 看报错。"""
import os, time
from pathlib import Path
import pymysql
ENV = Path(__file__).resolve().parent / "local.env"
for line in ENV.read_text(encoding="utf-8").splitlines():
    if line.strip().startswith("export "):
        k, _, v = line[7:].partition("=")
        os.environ[k] = v.strip().strip("'").strip('"')
conn = pymysql.connect(host=os.environ["MYSQL_HOST"], port=9030,
    user=os.environ["MYSQL_USER"], password=os.environ["MYSQL_PASSWORD"],
    charset="utf8mb4", cursorclass=pymysql.cursors.DictCursor, autocommit=True)
c = conn.cursor()

tabs = [
    "dwd_l2_optoelectronics_photodetector","dwd_l2_acoustic_device_microphone",
    "dwd_l2_storage_rewritable_rom","dwd_l2_rf_wireless_rfid_nfc_frontend",
    "dwd_l2_connector_backplane_ic_socket_connector","dwd_l2_clock_timing_clock_management_ic",
    "dwd_l2_filter_dielectric_cavity_filter","dwd_l2_rf_wireless_rf_transceiver_ic",
    "dwd_l2_driver_ic_laser_driver","dwd_l2_optoelectronics_light_emitter",
    "dwd_l2_storage_flash_memory","dwd_l2_storage_nv_ram",
    "dwd_l2_rf_wireless_rf_frequency_synthesis","dwd_l2_sensor_pressure_sensor",
    "dwd_l2_connector_standard_interface_socket_connector","dwd_l2_acoustic_device_receiver",
]
for t in tabs:
    try:
        c.execute(f"ALTER TABLE dwd.{t} MODIFY COLUMN rohs_compliant TINYINT NULL COMMENT 'RoHS合规'")
        print(f"  OK {t}")
    except Exception as e:
        print(f"  ERR {t}: {e}")
    time.sleep(1)
c.close(); conn.close()
