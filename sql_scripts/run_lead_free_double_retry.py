#!/usr/bin/env python3
"""完成 4 张 double 表 lead_free 统一：重试策略。
ADD COLUMN 已异步加好（lead_free_new tinyint 已存在）。
直接尝试 UPDATE/DROP/RENAME，遇 schema-change-in-progress 则等待重试。"""
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

def try_exec(sql, max_tries=30):
    for i in range(max_tries):
        try:
            c.execute(sql)
            return True
        except pymysql.err.ProgrammingError as e:
            if "schema change operation is in progress" in str(e):
                time.sleep(3)
                continue
            raise
    return False

for t in tabs:
    print(f"\n--- {t} ---")
    try:
        ok = try_exec(
            f"UPDATE dwd.{t} SET lead_free_new = CASE "
            f"WHEN lead_free = 1.0 THEN 1 "
            f"WHEN lead_free = 0.0 THEN 0 "
            f"ELSE NULL END"
        )
        print(f"  UPDATE: {'ok' if ok else 'timeout'}")
        ok = try_exec(f"ALTER TABLE dwd.{t} DROP COLUMN lead_free")
        print(f"  DROP:   {'ok' if ok else 'timeout'}")
        time.sleep(5)
        ok = try_exec(f"ALTER TABLE dwd.{t} RENAME COLUMN lead_free_new TO lead_free")
        print(f"  RENAME: {'ok' if ok else 'timeout'}")
        time.sleep(3)
        c.execute(f"SELECT lead_free v, COUNT(*) n FROM dwd.{t} GROUP BY lead_free ORDER BY n DESC")
        print(f"  after: {dict((str(r['v']), r['n']) for r in c.fetchall())}")
    except Exception as e:
        print(f"  ERR: {e}")

print("\n=== 最终列类型 ===")
for t in tabs:
    c.execute(
        "SELECT data_type FROM information_schema.columns "
        "WHERE table_schema='dwd' AND table_name=%s AND column_name='lead_free'",
        (t,),
    )
    r = c.fetchone()
    print(f"  {t}: {r['data_type'] if r else 'MISSING'}")

c.close(); conn.close()
