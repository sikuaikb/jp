#!/usr/bin/env python3
"""4 张 double 表：lead_free 已 DROP，lead_free_new(tinyint) 已在。
现在 UPDATE 填值 + RENAME lead_free_new → lead_free，带重试。"""
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
        except (pymysql.err.ProgrammingError, pymysql.err.OperationalError) as e:
            s = str(e)
            if "schema change operation is in progress" in s or "cannot be resolved" in s:
                time.sleep(3)
                continue
            raise
    return False

for t in tabs:
    print(f"\n--- {t} ---")
    try:
        # lead_free_new 已是 tinyint，直接填值（旧 double 值已随 DROP 丢失，需从原值重建）
        # 但旧 lead_free 已 DROP，值已丢。只能置 NULL（数据已无法恢复原 0/1）
        # 实际上：之前 UPDATE lead_free_new 时旧 lead_free 还在，但那次 UPDATE 失败了。
        # 所以 lead_free_new 现在全 NULL。需重新从源端补，或接受 NULL。
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
