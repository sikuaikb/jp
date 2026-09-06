#!/usr/bin/env python3
"""lead_free 类型统一到 TINYINT(BOOLEAN)。
- double 表：直接 ALTER MODIFY COLUMN tinyint
- varchar 表：先 UPDATE 用 CASE 归一为 '1'/'0'/NULL，再 ALTER MODIFY COLUMN tinyint
带前后 0/1/null 计数校验。默认跑 PILOT 集，--all 跑全部。"""
from __future__ import annotations
import os, sys
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

YES = ("TRUE", "true", "不含铅", "无铅", "是", "Lead Free", "PB free", "符合 ROHS3 规范", "符合 RoHS 规范")
NO = ("FALSE", "false", "含铅", "否", "Contains Lead", "不符合 RoHS 规范")

def in_list(vals):
    return ",".join("'" + v.replace("'", "''") + "'" for v in vals)

def profile(t):
    c.execute(f"SELECT lead_free v, COUNT(*) n FROM dwd.{t} GROUP BY lead_free ORDER BY n DESC")
    return {str(r["v"]): r["n"] for r in c.fetchall()}

def migrate_varchar(t):
    before = profile(t)
    sql = (
        f"UPDATE dwd.{t} SET lead_free = CASE "
        f"WHEN lead_free IN ({in_list(YES)}) THEN '1' "
        f"WHEN lead_free IN ({in_list(NO)}) THEN '0' "
        f"ELSE NULL END"
    )
    c.execute(sql)
    # ALTER to tinyint
    c.execute(f"ALTER TABLE dwd.{t} MODIFY COLUMN lead_free TINYINT NULL COMMENT '无铅工艺'")
    after = profile(t)
    return before, after

def migrate_double(t):
    before = profile(t)
    # StarRocks 不允许 double→tinyint 直接改，用 add/update/drop/rename
    c.execute(f"ALTER TABLE dwd.{t} ADD COLUMN lead_free_new TINYINT NULL COMMENT '无铅工艺'")
    c.execute(
        f"UPDATE dwd.{t} SET lead_free_new = CASE "
        f"WHEN lead_free = 1.0 THEN 1 "
        f"WHEN lead_free = 0.0 THEN 0 "
        f"ELSE NULL END"
    )
    c.execute(f"ALTER TABLE dwd.{t} DROP COLUMN lead_free")
    c.execute(f"ALTER TABLE dwd.{t} RENAME COLUMN lead_free_new TO lead_free")
    after = profile(t)
    return before, after

# 选表
PILOT_DOUBLE = [
    "dwd_l2_isolator_isolated_analog_amplifier",
    "dwd_l2_isolator_rf_isolator_circulator",
    "dwd_l2_isolator_digital_isolator",
    "dwd_l2_isolator_optocoupler",
]
PILOT_VARCHAR = [
    "dwd_l2_driver_ic_laser_driver",
    "dwd_l2_circuit_protection_surge_protection_module",
    "dwd_l2_interface_communication_ic_digital_isolation_interface",
    "dwd_l2_amplifier_transimpedance_transconductance_log_amp",
    "dwd_l2_storage_nv_ram",
]

targets = []
if "--all" in sys.argv:
    c.execute("""
        SELECT table_name, data_type FROM information_schema.columns
        WHERE table_schema='dwd' AND table_name LIKE 'dwd_l2_%' AND column_name='lead_free'
          AND data_type IN ('varchar','double')
    """)
    targets = [(r["table_name"], r["data_type"]) for r in c.fetchall()]
else:
    targets = [(t, "double") for t in PILOT_DOUBLE] + [(t, "varchar") for t in PILOT_VARCHAR]

print(f"目标 {len(targets)} 张表")
for t, dt in targets:
    print(f"\n--- {t} ({dt}) ---")
    try:
        before, after = migrate_double(t) if dt == "double" else migrate_varchar(t)
        print(f"  before: {before}")
        print(f"  after:  {after}")
    except Exception as e:
        print(f"  ERR: {e}")

c.close(); conn.close()
