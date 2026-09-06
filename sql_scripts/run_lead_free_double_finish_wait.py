#!/usr/bin/env python3
"""等待 4 张 double 表的 ADD COLUMN schema change 完成，然后完成 UPDATE/DROP/RENAME。"""
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
    "dwd_l2_isolator_isolated_analog_amplifier",
    "dwd_l2_isolator_rf_isolator_circulator",
    "dwd_l2_isolator_digital_isolator",
    "dwd_l2_isolator_optocoupler",
]

def pending(t):
    # SHOW ALTER TABLE COLUMN FROM <table>：需先 USE dwd，表名不带库前缀
    c.execute("USE dwd")
    c.execute(f"SHOW ALTER TABLE COLUMN FROM {t}")
    return c.fetchall()

print("等待 schema change 完成...")
for t in tabs:
    for _ in range(60):
        if not pending(t):
            break
        time.sleep(2)
    else:
        print(f"  {t}: 仍有 pending job，超时")
        continue
    print(f"  {t}: schema change 完成，继续")

print("\n执行 UPDATE/DROP/RENAME...")
for t in tabs:
    print(f"\n--- {t} ---")
    try:
        c.execute(
            f"UPDATE dwd.{t} SET lead_free_new = CASE "
            f"WHEN lead_free = 1.0 THEN 1 "
            f"WHEN lead_free = 0.0 THEN 0 "
            f"ELSE NULL END"
        )
        c.execute(f"ALTER TABLE dwd.{t} DROP COLUMN lead_free")
        # DROP 也是 schema change，等一下
        for _ in range(60):
            if not pending(t):
                break
            time.sleep(2)
        c.execute(f"ALTER TABLE dwd.{t} RENAME COLUMN lead_free_new TO lead_free")
        c.execute(f"SELECT lead_free v, COUNT(*) n FROM dwd.{t} GROUP BY lead_free ORDER BY n DESC")
        after = {str(r["v"]): r["n"] for r in c.fetchall()}
        print(f"  after: {after}")
    except Exception as e:
        print(f"  ERR: {e}")

print("\n=== 最终列类型 ===")
for t in tabs:
    c.execute(
        "SELECT data_type FROM information_schema.columns "
        "WHERE table_schema='dwd' AND table_name=%s AND column_name='lead_free'",
        (t,),
    )
    print(f"  {t}: {c.fetchone()['data_type']}")

c.close(); conn.close()
