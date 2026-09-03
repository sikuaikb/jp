#!/usr/bin/env python3
"""EAV rohs_compliant 值归一 (同 lead_free 流程):
  value_std_varchar -> '1' / '0' / NULL
  value_std_double  -> 1 / 0 / NULL
映射:
  TRUE/true/符合 ROHS3 规范/符合/符合 RoHS 规范/RoHS Compliant/RoHS-conform/Compliant -> 1
  FALSE/false/不符合/不符合 RoHS 规范/Non-Compliant -> 0
  (空)/不适用/要求库存盘点/Exempt -> NULL
"""
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

c.execute("SELECT COUNT(*) n FROM dwd.dwd_component_attr_std WHERE std_attr_code='rohs_compliant'")
print(f"rohs_compliant 总行: {c.fetchone()['n']:,}")

print("\n[1] YES -> 1")
t0 = time.time()
c.execute(f"""UPDATE dwd.dwd_component_attr_std
    SET value_std_varchar='1', value_std_double=1.0
    WHERE std_attr_code='rohs_compliant' AND value_std_varchar IN ({in_list(YES)})""")
print(f"  affected={c.rowcount:,} ({time.time()-t0:.1f}s)")

print("\n[2] NO -> 0")
t0 = time.time()
c.execute(f"""UPDATE dwd.dwd_component_attr_std
    SET value_std_varchar='0', value_std_double=0.0
    WHERE std_attr_code='rohs_compliant' AND value_std_varchar IN ({in_list(NO)})""")
print(f"  affected={c.rowcount:,} ({time.time()-t0:.1f}s)")

print("\n[3] 脏值 (空/不适用/要求库存盘点/Exempt) -> NULL")
t0 = time.time()
c.execute("""UPDATE dwd.dwd_component_attr_std
    SET value_std_varchar=NULL, value_std_double=NULL
    WHERE std_attr_code='rohs_compliant'
      AND value_std_varchar NOT IN ('1','0')
      AND value_std_varchar IS NOT NULL""")
print(f"  affected={c.rowcount:,} ({time.time()-t0:.1f}s)")

print("\n[4] double 来源行同步 varchar")
t0 = time.time()
c.execute("""UPDATE dwd.dwd_component_attr_std SET value_std_varchar='1'
    WHERE std_attr_code='rohs_compliant' AND value_std_double=1.0
      AND (value_std_varchar IS NULL OR value_std_varchar='')""")
print(f"  double=1.0 -> '1': {c.rowcount:,}")
c.execute("""UPDATE dwd.dwd_component_attr_std SET value_std_varchar='0'
    WHERE std_attr_code='rohs_compliant' AND value_std_double=0.0
      AND (value_std_varchar IS NULL OR value_std_varchar='')""")
print(f"  double=0.0 -> '0': {c.rowcount:,} ({time.time()-t0:.1f}s)")

print("\n=== 校验: rohs_compliant value_std_varchar 最终分布 ===")
c.execute("""SELECT value_std_varchar v, COUNT(*) n FROM dwd.dwd_component_attr_std
    WHERE std_attr_code='rohs_compliant' GROUP BY value_std_varchar ORDER BY n DESC""")
for r in c.fetchall():
    print(f"  {str(r['v']):8s} {r['n']:>10,}")

c.close(); conn.close()
