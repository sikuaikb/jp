#!/usr/bin/env python3
"""排查 lead_free 脏数据 '要求库存盘点' 根因:
1. 列出所有 std_attr_code='lead_free' 的抽取规则
2. 找 source_expr/value_map 里可能产出 '要求库存盘点' 的规则
3. 查这些规则对应的源端字段实际值分布
"""
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

print("=== 1. 所有 lead_free 抽取规则 ===")
c.execute("""
    SELECT extract_rule_id, data_source, l1_code, apply_scope_level, apply_scope_code,
           source_kind, source_expr, source_value_expr, source_value_regex,
           literal_std_value, priority, enabled
    FROM dim.dim_attr_extract_rule
    WHERE std_attr_code='lead_free'
    ORDER BY data_source, l1_code, apply_scope_code
""")
rules = c.fetchall()
print(f"共 {len(rules)} 条规则")
for r in rules:
    print(f"\n  id={r['extract_rule_id']}")
    print(f"    ds={r['data_source']} l1={r['l1_code']} scope={r['apply_scope_level']}/{r['apply_scope_code']} src={r['source_kind']}")
    print(f"    source_expr={r['source_expr']}")
    print(f"    value_expr={r['source_value_expr']} regex={r['source_value_regex']} literal={r['literal_std_value']} pri={r['priority']} en={r['enabled']}")

# 备份表里查 '要求库存盘点' 原本出现在哪些 data_source/l1 (从已备份的 dim 不行, EAV 没备份)
# 改查: 哪些规则的 source_expr 可能含 '要求库存盘点' 或库存相关
print("\n=== 2. source_expr/value 含 '库存' 或 '盘点' 的规则 ===")
c.execute("""
    SELECT extract_rule_id, std_attr_code, data_source, l1_code, source_kind, source_expr, source_value_expr
    FROM dim.dim_attr_extract_rule
    WHERE source_expr LIKE '%库存%' OR source_expr LIKE '%盘点%'
       OR source_value_expr LIKE '%库存%' OR source_value_expr LIKE '%盘点%'
""")
for r in c.fetchall():
    print(f"  {r['extract_rule_id']} std_attr={r['std_attr_code']} ds={r['data_source']} l1={r['l1_code']} src={r['source_kind']} expr={r['source_expr']} val={r['source_value_expr']}")

c.close(); conn.close()
