"""合并前修正 test 命名（纯 SQL，避免 MAP 类型 pymysql 序列化问题）"""
import pymysql, sys, io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

L1 = 'fpga_cpld'
conn = pymysql.connect(host='192.168.19.21', port=9030, user='rock_admin',
                       password='jE4^mK9%sJ2_vP&7_2026_z!', charset='utf8mb4')
cur = conn.cursor()

def run(sql, label=''):
    try:
        cur.execute(sql)
        conn.commit()
        print(f'  ✅ {label}: {cur.rowcount} rows affected')
        return True
    except Exception as e:
        print(f'  ❌ {label}: {e}')
        return False

print('=' * 60)
print('patch test naming (SQL)')

# classify 已在上一轮 patch 完成，此处幂等
run(f"""INSERT INTO test_dim.dim_l3_classify_{L1}
  (l3_id,l1_code,l1_cn,l2_code,l2_cn,l3_code,l3_cn,note,schema_version)
SELECT l3_id,'{L1}',l1_cn,l2_code,l2_cn,
  CASE l3_code
    WHEN 'Macrocell_CPLD' THEN 'macrocell_cpld'
    WHEN 'SRAM_FPGA' THEN 'sram_fpga'
    WHEN 'SoC_FPGA' THEN 'soc_fpga'
    WHEN 'Flash_FPGA' THEN 'flash_fpga'
    WHEN 'Antifuse_FPGA' THEN 'antifuse_fpga'
    ELSE l3_code END,
  l3_cn,note,schema_version
FROM test_dim.dim_l3_classify_{L1}
WHERE l1_code='fpgacpld'""", 'classify insert new')

run(f"DELETE FROM test_dim.dim_l3_classify_{L1} WHERE l1_code='fpgacpld'", 'classify delete old')

# rules: 备份 → 删旧 → 插新
run(f'DROP TABLE IF EXISTS test_dwd.bak_rule_{L1}_rename', 'drop bak')
run(f"""CREATE TABLE test_dwd.bak_rule_{L1}_rename AS
  SELECT * FROM test_dim.dim_l3_classify_rule_{L1}
  WHERE rule_id REGEXP '^(gate_)?fpgacpld_'""", 'bak rules')

run(f"""DELETE FROM test_dim.dim_l3_classify_rule_{L1}
  WHERE rule_id REGEXP '^(gate_)?fpgacpld_'""", 'delete old rules')

run(f"""INSERT INTO test_dim.dim_l3_classify_rule_{L1}
SELECT
  CASE
    WHEN rule_id LIKE 'gate_fpgacpld_%' THEN REPLACE(rule_id,'gate_fpgacpld_','gate_fpga_cpld_')
    WHEN rule_id LIKE 'fpgacpld_%' THEN REPLACE(rule_id,'fpgacpld_','fpga_cpld_')
    ELSE rule_id
  END AS rule_id,
  clause_group_id, clause_ord, schema_version, data_source, rule_kind,
  l3_id, l3_cn, phase, rule_priority, enabled, confidence_weight,
  classify_source_hint, field_code, match_value, match_values, match_map, note
FROM test_dwd.bak_rule_{L1}_rename""", 'insert new rules')

# dwd baseline
run(f"""INSERT INTO test_dwd.dwd_component_class_{L1}
  (data_source,id,l1_code,l2_code,l3_code,l3_id,rule_id,phase,classify_source,
   matched_priority,matched_value,confidence)
SELECT data_source,id,'{L1}',l2_code,
  CASE l3_code
    WHEN 'Macrocell_CPLD' THEN 'macrocell_cpld'
    WHEN 'SRAM_FPGA' THEN 'sram_fpga'
    WHEN 'SoC_FPGA' THEN 'soc_fpga'
    WHEN 'Flash_FPGA' THEN 'flash_fpga'
    WHEN 'Antifuse_FPGA' THEN 'antifuse_fpga'
    ELSE l3_code END,
  l3_id,rule_id,phase,classify_source,matched_priority,matched_value,confidence
FROM test_dwd.dwd_component_class_{L1}
WHERE l1_code='fpgacpld'""", 'dwd insert new')

run(f"DELETE FROM test_dwd.dwd_component_class_{L1} WHERE l1_code='fpgacpld'", 'dwd delete old')

# verify
cur.execute(f"SELECT l1_code, l3_code FROM test_dim.dim_l3_classify_{L1} ORDER BY l3_id")
print('\nclassify:', cur.fetchall())
cur.execute(f"""SELECT COUNT(*) FROM test_dim.dim_l3_classify_rule_{L1}
  WHERE rule_id NOT REGEXP '^{L1}_' AND rule_id NOT REGEXP '^gate_{L1}_'""")
print('rule prefix bad:', cur.fetchone()[0])
cur.execute(f"SELECT data_source, l3_code, COUNT(*) FROM test_dwd.dwd_component_class_{L1} GROUP BY 1,2 ORDER BY 1,3 DESC")
print('baseline:')
for r in cur.fetchall():
    print(f'  {r}')

cur.close()
conn.close()
print('\n✅ done')
