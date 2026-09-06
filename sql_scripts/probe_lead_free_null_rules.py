#!/usr/bin/env python3
"""反查: EAV 里 lead_free 行(已归一)的 extract_rule_id 分布,
定位 '要求库存盘点' 当初由哪条规则产出。
思路: '要求库存盘点' 已被置 NULL, 但被置 NULL 的行 = 原脏值行。
这些行现在 value_std_varchar IS NULL 且 value_std_double IS NULL,
且 extract_rule_id 指向某 lead_free 规则。统计这些 NULL 行的 extract_rule_id。
但注意: 原 '不适用' 也被置 NULL, 需区分。改用更精确: 查 backup EAV? 无。
换思路: 直接查源端 prajson, 看哪个字段含 '要求库存盘点'。"""
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

# 1. EAV 里 lead_free 且 value 全 NULL 的行, 按 extract_rule_id + data_source 统计
print("=== lead_free 全 NULL 行 (原脏值+不适用) 按 extract_rule_id ===")
c.execute("""
    SELECT extract_rule_id, data_source, COUNT(*) n
    FROM dwd.dwd_component_attr_std
    WHERE std_attr_code='lead_free'
      AND value_std_varchar IS NULL AND value_std_double IS NULL
    GROUP BY extract_rule_id, data_source
    ORDER BY n DESC
""")
rows = c.fetchall()
for r in rows:
    print(f"  {str(r['extract_rule_id']):40s} ds={r['data_source']:8s} n={r['n']:>8,}")
print(f"  共 {len(rows)} 个不同 extract_rule_id")

# 2. 查源端 prajson 哪个字段含 '要求库存盘点'
#    icpdf 源表通常在 dwd/ods, 先找含 prajson 的源表
print("\n=== 找 icpdf 源端表 ===")
c.execute("""
    SELECT table_schema, table_name FROM information_schema.columns
    WHERE column_name LIKE '%prajson%' AND table_schema IN ('dwd','ods','raw')
    LIMIT 20
""")
for r in c.fetchall():
    print(f"  {r['table_schema']}.{r['table_name']}")

c.close(); conn.close()
