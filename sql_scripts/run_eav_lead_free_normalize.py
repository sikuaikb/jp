#!/usr/bin/env python3
"""EAV lead_free 值归一: 把 std_attr_code='lead_free' 行的 value 统一为
  value_std_varchar = '1' / '0' / NULL
  value_std_double = 1 / 0 / NULL
映射:
  TRUE/true/不含铅/是/Lead Free/PB free/符合 ROHS3 规范/符合 RoHS 规范/无铅 -> 1
  FALSE/false/含铅/否/Contains Lead/不符合 RoHS 规范 -> 0
  (空)/不适用/要求库存盘点/Lead free(小写l? 已含) -> NULL
注意: 'Lead free' (3 行, 小写f) 也归 1。
EAV PK=(data_source,id,std_attr_code), 不改 PK, 只改 value 列, 可直接 UPDATE。
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

YES = ("TRUE", "true", "不含铅", "是", "Lead Free", "PB free", "符合 ROHS3 规范", "符合 RoHS 规范", "无铅", "Lead free")
NO = ("FALSE", "false", "含铅", "否", "Contains Lead", "不符合 RoHS 规范")
# NULL 类: 空串, 不适用, 要求库存盘点 -> NULL (不显式处理, ELSE 置 NULL)

def in_list(vals):
    return ",".join("'" + v.replace("'", "''") + "'" for v in vals)

# 先看当前总量
c.execute("SELECT COUNT(*) n FROM dwd.dwd_component_attr_std WHERE std_attr_code='lead_free'")
total = c.fetchone()["n"]
print(f"lead_free 总行: {total:,}")

# 1. YES -> value_std_varchar='1', value_std_double=1.0
print("\n[1] YES 值 -> 1")
t0 = time.time()
c.execute(f"""
    UPDATE dwd.dwd_component_attr_std
    SET value_std_varchar='1', value_std_double=1.0
    WHERE std_attr_code='lead_free' AND value_std_varchar IN ({in_list(YES)})
""")
print(f"  affected={c.rowcount:,} ({time.time()-t0:.1f}s)")

# 2. NO -> value_std_varchar='0', value_std_double=0.0
print("\n[2] NO 值 -> 0")
t0 = time.time()
c.execute(f"""
    UPDATE dwd.dwd_component_attr_std
    SET value_std_varchar='0', value_std_double=0.0
    WHERE std_attr_code='lead_free' AND value_std_varchar IN ({in_list(NO)})
""")
print(f"  affected={c.rowcount:,} ({time.time()-t0:.1f}s)")

# 3. 其余非空非1/0的脏值 (不适用/要求库存盘点/空串) -> NULL
#    注意: 空串 '' 和 NULL 不同。把不在 YES/NO 且不为 '1'/'0' 的 varchar 值置 NULL
print("\n[3] 脏值 (不适用/要求库存盘点/空串等) -> NULL")
t0 = time.time()
c.execute("""
    UPDATE dwd.dwd_component_attr_std
    SET value_std_varchar=NULL, value_std_double=NULL
    WHERE std_attr_code='lead_free'
      AND value_std_varchar NOT IN ('1','0')
      AND value_std_varchar IS NOT NULL
""")
print(f"  affected={c.rowcount:,} ({time.time()-t0:.1f}s)")

# 4. 处理 value_std_double 有值但 varchar 为空的 (double 来源的行)
#    之前 double 表的值是 0.0/1.0, 对应 EAV 行可能 value_std_varchar 为空但 double 有值
print("\n[4] double 来源行 (varchar 空, double=0/1) -> 同步 varchar")
t0 = time.time()
c.execute("""
    UPDATE dwd.dwd_component_attr_std
    SET value_std_varchar='1'
    WHERE std_attr_code='lead_free' AND value_std_double=1.0 AND (value_std_varchar IS NULL OR value_std_varchar='')
""")
print(f"  double=1.0 -> '1': affected={c.rowcount:,}")
c.execute("""
    UPDATE dwd.dwd_component_attr_std
    SET value_std_varchar='0'
    WHERE std_attr_code='lead_free' AND value_std_double=0.0 AND (value_std_varchar IS NULL OR value_std_varchar='')
""")
print(f"  double=0.0 -> '0': affected={c.rowcount:,} ({time.time()-t0:.1f}s)")

# 校验最终分布
print("\n=== 校验: lead_free value_std_varchar 最终分布 ===")
c.execute("""
    SELECT value_std_varchar v, COUNT(*) n
    FROM dwd.dwd_component_attr_std
    WHERE std_attr_code='lead_free'
    GROUP BY value_std_varchar ORDER BY n DESC
""")
for r in c.fetchall():
    print(f"  {str(r['v']):10s} {r['n']:>10,}")

c.close(); conn.close()
