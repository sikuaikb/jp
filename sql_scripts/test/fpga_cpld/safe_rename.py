"""
安全重命名 fpga_cpld test 库命名
策略：纯 SQL INSERT SELECT（先插后删，MAP 列问题安全绕过）
绝不 executemany，绝不整表清空
"""
import pymysql, sys, io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

conn = pymysql.connect(host='192.168.19.21', port=9030, user='rock_admin',
                       password='jE4^mK9%sJ2_vP&7_2026_z!', charset='utf8mb4')
cur = conn.cursor()
L1 = 'fpga_cpld'
OLD_L1 = 'fpgacpld'

def q1(sql):
    cur.execute(sql); r = cur.fetchone(); return r[0] if r else 0

def run(sql, label):
    cur.execute(sql); conn.commit()
    print(f'  {label}: {cur.rowcount} rows')
    return cur.rowcount

print('=' * 65)
print('safe_rename: fpgacpld → fpga_cpld + snake_case')
print('=' * 65)

# ── 1. dim_l3_classify ────────────────────────────────────────
print('\n[1] dim_l3_classify')
before = q1(f"SELECT COUNT(*) FROM test_dim.dim_l3_classify_{L1} WHERE l1_code='{OLD_L1}'")
print(f'  需修正行数: {before}')
if before > 0:
    # INSERT SELECT 覆盖（StarRocks PRIMARY KEY 会 upsert），无需 DELETE
    run(f"""INSERT INTO test_dim.dim_l3_classify_{L1}
    (l3_id, l1_code, l1_cn, l2_code, l2_cn, l3_code, l3_cn, note, schema_version)
    SELECT l3_id, '{L1}', l1_cn, l2_code, l2_cn,
      CASE l3_code
        WHEN 'Macrocell_CPLD' THEN 'macrocell_cpld'
        WHEN 'SRAM_FPGA'      THEN 'sram_fpga'
        WHEN 'SoC_FPGA'       THEN 'soc_fpga'
        WHEN 'Flash_FPGA'     THEN 'flash_fpga'
        WHEN 'Antifuse_FPGA'  THEN 'antifuse_fpga'
        ELSE LOWER(l3_code) END,
      l3_cn, note, schema_version
    FROM test_dim.dim_l3_classify_{L1}
    WHERE l1_code = '{OLD_L1}'""", 'upsert classify')
    # 删旧（此时新行已写入，l3_id 相同的旧行被 upsert 覆盖，但万一 upsert 不完全，手动清理)
    run(f"DELETE FROM test_dim.dim_l3_classify_{L1} WHERE l1_code='{OLD_L1}'", 'delete old classify')
after = q1(f"SELECT COUNT(*) FROM test_dim.dim_l3_classify_{L1} WHERE l1_code='{L1}'")
bad   = q1(f"SELECT COUNT(*) FROM test_dim.dim_l3_classify_{L1} WHERE l1_code<>'{L1}'")
print(f'  验证: l1_code={L1} 的行数={after}, 非{L1}行数={bad}')
assert bad == 0 and after == 5, f'classify patch 异常: after={after}, bad={bad}'
print('  ✅ classify OK')

# ── 2. dim_l3_classify_rule ───────────────────────────────────
print('\n[2] dim_l3_classify_rule')
before_old  = q1(f"SELECT COUNT(*) FROM test_dim.dim_l3_classify_rule_{L1} WHERE rule_id REGEXP '^(gate_)?{OLD_L1}_'")
before_good = q1(f"SELECT COUNT(*) FROM test_dim.dim_l3_classify_rule_{L1} WHERE rule_id REGEXP '^(gate_)?{L1}_'")
print(f'  旧前缀行数: {before_old},  已合规行数: {before_good}')

if before_old > 0:
    # 纯 SQL INSERT SELECT：rule_id 改前缀，MAP/ARRAY 列原样复制
    # 显式列出目标列（排除 create_at/update_at，用 DEFAULT CURRENT_TIMESTAMP 自动填充）
    run(f"""INSERT INTO test_dim.dim_l3_classify_rule_{L1}
    (rule_id, clause_group_id, clause_ord, schema_version, data_source, rule_kind,
     l3_id, l3_cn, phase, rule_priority, enabled, confidence_weight,
     classify_source_hint, field_code, match_value, match_values, match_map, note)
    SELECT
      CASE
        WHEN rule_id LIKE 'gate_{OLD_L1}_%'
          THEN REPLACE(rule_id, 'gate_{OLD_L1}_', 'gate_{L1}_')
        WHEN rule_id LIKE '{OLD_L1}_%'
          THEN REPLACE(rule_id, '{OLD_L1}_', '{L1}_')
        ELSE rule_id
      END AS rule_id,
      clause_group_id, clause_ord, schema_version, data_source, rule_kind,
      l3_id, l3_cn, phase, rule_priority, enabled, confidence_weight,
      classify_source_hint, field_code, match_value, match_values, match_map, note
    FROM test_dim.dim_l3_classify_rule_{L1}
    WHERE rule_id REGEXP '^(gate_)?{OLD_L1}_'""", 'insert new-prefix rules')

    # 验证新行已写入
    new_good = q1(f"SELECT COUNT(*) FROM test_dim.dim_l3_classify_rule_{L1} WHERE rule_id REGEXP '^(gate_)?{L1}_'")
    print(f'  插入后合规行数: {new_good}（期望 ≥ {before_old + before_good}）')
    assert new_good >= before_old + before_good, '新行插入数量不够，终止！'

    # 确认无误后才删旧行
    run(f"""DELETE FROM test_dim.dim_l3_classify_rule_{L1}
    WHERE rule_id REGEXP '^(gate_)?{OLD_L1}_'""", 'delete old-prefix rules')

final_good = q1(f"SELECT COUNT(*) FROM test_dim.dim_l3_classify_rule_{L1} WHERE rule_id REGEXP '^(gate_)?{L1}_'")
final_bad  = q1(f"SELECT COUNT(*) FROM test_dim.dim_l3_classify_rule_{L1} WHERE rule_id NOT REGEXP '^(gate_)?{L1}_'")
print(f'  验证: 合规={final_good}, 不合规={final_bad}')
assert final_bad == 0 and final_good == 30, f'rule patch 异常: good={final_good}, bad={final_bad}'
print('  ✅ rule OK')

# ── 3. dwd_component_class (baseline) ────────────────────────
print('\n[3] dwd_component_class baseline')
before = q1(f"SELECT COUNT(*) FROM test_dwd.dwd_component_class_{L1} WHERE l1_code='{OLD_L1}'")
print(f'  需修正行数: {before}')
if before > 0:
    run(f"""INSERT INTO test_dwd.dwd_component_class_{L1}
    (data_source, id, l1_code, l2_code, l3_code, l3_id, rule_id, phase,
     classify_source, matched_priority, matched_value, confidence)
    SELECT data_source, id, '{L1}', l2_code,
      CASE l3_code
        WHEN 'Macrocell_CPLD' THEN 'macrocell_cpld'
        WHEN 'SRAM_FPGA'      THEN 'sram_fpga'
        WHEN 'SoC_FPGA'       THEN 'soc_fpga'
        WHEN 'Flash_FPGA'     THEN 'flash_fpga'
        WHEN 'Antifuse_FPGA'  THEN 'antifuse_fpga'
        ELSE LOWER(l3_code) END,
      l3_id, rule_id, phase, classify_source, matched_priority, matched_value, confidence
    FROM test_dwd.dwd_component_class_{L1}
    WHERE l1_code = '{OLD_L1}'""", 'upsert dwd baseline')
    run(f"DELETE FROM test_dwd.dwd_component_class_{L1} WHERE l1_code='{OLD_L1}'", 'delete old dwd')

after = q1(f"SELECT COUNT(*) FROM test_dwd.dwd_component_class_{L1} WHERE l1_code='{L1}'")
bad   = q1(f"SELECT COUNT(*) FROM test_dwd.dwd_component_class_{L1} WHERE l1_code<>'{L1}'")
print(f'  验证: l1_code={L1} 行数={after:,}, 非{L1}={bad}')
assert bad == 0, f'dwd 仍有旧 l1_code 行: {bad}'
print(f'  ✅ dwd OK ({after:,} 行)')

print('\n' + '=' * 65)
print('safe_rename 完成，所有命名已对齐 fpga_cpld')
cur.close(); conn.close()
