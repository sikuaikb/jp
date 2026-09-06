#!/usr/bin/env python3
"""完成 4 张 double 表的 lead_free 类型统一：lead_free_new 已异步加好，
现在 UPDATE 填值 → DROP 旧 lead_free → RENAME lead_free_new → lead_free。"""
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
    charset="utf8mb4", cursorclass=pymysql.cursors.DictCursor, autocommit=True)
c = conn.cursor()

tabs = [
    "dwd_l2_isolator_isolated_analog_amplifier",
    "dwd_l2_isolator_rf_isolator_circulator",
    "dwd_l2_isolator_digital_isolator",
    "dwd_l2_isolator_optocoupler",
]

for t in tabs:
    print(f"\n--- {t} ---")
    try:
        c.execute(f"SELECT lead_free v, COUNT(*) n FROM dwd.{t} GROUP BY lead_free ORDER BY n DESC")
        before = {str(r["v"]): r["n"] for r in c.fetchall()}
        print(f"  before: {before}")
        c.execute(
            f"UPDATE dwd.{t} SET lead_free_new = CASE "
            f"WHEN lead_free = 1.0 THEN 1 "
            f"WHEN lead_free = 0.0 THEN 0 "
            f"ELSE NULL END"
        )
        c.execute(f"ALTER TABLE dwd.{t} DROP COLUMN lead_free")
        c.execute(f"ALTER TABLE dwd.{t} RENAME COLUMN lead_free_new TO lead_free")
        c.execute(f"SELECT lead_free v, COUNT(*) n FROM dwd.{t} GROUP BY lead_free ORDER BY n DESC")
        after = {str(r["v"]): r["n"] for r in c.fetchall()}
        print(f"  after:  {after}")
    except Exception as e:
        print(f"  ERR: {e}")

c.close(); conn.close()
