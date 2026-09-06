#!/usr/bin/env python3
"""DWD L2 rohs_compliant 列类型统一 -> TINYINT。
- varchar 表: 先 UPDATE 归一为 '1'/'0'/NULL (EAV 已归一, 但 L2 表里存的是旧抽取的杂乱值, 需再归一), 再 ALTER MODIFY tinyint
- double 表: add/update/drop/rename (StarRocks 不允许 double->tinyint 直接改)
- tinyint 表: 跳过
带重试 (schema change in progress)。"""
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

YES = ("TRUE", "true", "符合 ROHS3 规范", "符合", "符合 RoHS 规范", "RoHS Compliant", "RoHS-conform", "Compliant")
NO = ("FALSE", "false", "不符合", "不符合 RoHS 规范", "Non-Compliant")

def in_list(vals):
    return ",".join("'" + v.replace("'", "''") + "'" for v in vals)

def try_exec(sql, max_tries=40):
    for _ in range(max_tries):
        try:
            c.execute(sql)
            return True
        except (pymysql.err.ProgrammingError, pymysql.err.OperationalError) as e:
            s = str(e)
            if "schema change operation is in progress" in s or "cannot be resolved" in s or "do not existing column" in s:
                time.sleep(3)
                continue
            raise
    return False

# 取所有 rohs_compliant 非 tinyint 的 L2 表
c.execute("""
    SELECT table_name, data_type FROM information_schema.columns
    WHERE table_schema='dwd' AND table_name LIKE 'dwd_l2_%' AND column_name='rohs_compliant'
      AND data_type <> 'tinyint'
""")
targets = [(r["table_name"], r["data_type"]) for r in c.fetchall()]
print(f"目标 {len(targets)} 张表 (varchar+double)")

ok = 0
for t, dt in targets:
    try:
        if dt == "varchar":
            # 先归一 L2 表里现存的杂乱值
            c.execute(f"UPDATE dwd.{t} SET rohs_compliant='1' WHERE rohs_compliant IN ({in_list(YES)})")
            c.execute(f"UPDATE dwd.{t} SET rohs_compliant='0' WHERE rohs_compliant IN ({in_list(NO)})")
            c.execute(f"UPDATE dwd.{t} SET rohs_compliant=NULL WHERE rohs_compliant IS NOT NULL AND rohs_compliant NOT IN ('1','0')")
            try_exec(f"ALTER TABLE dwd.{t} MODIFY COLUMN rohs_compliant TINYINT NULL COMMENT 'RoHS合规'")
        elif dt == "double":
            try_exec(f"ALTER TABLE dwd.{t} ADD COLUMN rohs_compliant_new TINYINT NULL COMMENT 'RoHS合规'")
            time.sleep(3)
            try_exec(f"UPDATE dwd.{t} SET rohs_compliant_new = CASE WHEN rohs_compliant=1.0 THEN 1 WHEN rohs_compliant=0.0 THEN 0 ELSE NULL END")
            try_exec(f"ALTER TABLE dwd.{t} DROP COLUMN rohs_compliant")
            time.sleep(3)
            try_exec(f"ALTER TABLE dwd.{t} RENAME COLUMN rohs_compliant_new TO rohs_compliant")
        ok += 1
        print(f"  OK {t} ({dt})")
    except Exception as e:
        print(f"  ERR {t} ({dt}): {e}")

print(f"\n完成 {ok}/{len(targets)}")
# 校验
c.execute("""SELECT data_type, COUNT(*) n FROM information_schema.columns
    WHERE table_schema='dwd' AND table_name LIKE 'dwd_l2_%' AND column_name='rohs_compliant'
    GROUP BY data_type""")
print("\n最终类型分布:")
for r in c.fetchall():
    print(f"  {r['data_type']}: {r['n']}")
c.close(); conn.close()
