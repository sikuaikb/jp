"""
安全修正 fpga_cpld attr schema/rule 命名
- l1_code: fpgacpld → fpga_cpld
- scope_code (l3): PascalCase → snake_case
策略：INSERT SELECT 覆盖，验证通过后 DELETE 旧行
"""
import pymysql, sys, io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

conn = pymysql.connect(host='192.168.19.21', port=9030, user='rock_admin',
                       password='jE4^mK9%sJ2_vP&7_2026_z!', charset='utf8mb4')
cur = conn.cursor()
L1 = 'fpga_cpld'
OLD_L1 = 'fpgacpld'

def q1(sql):
    try:
        cur.execute(sql); r = cur.fetchone(); return r[0] if r else 0
    except Exception as e:
        print(f'  [WARN] {e}'); return 0

def run(sql, label):
    cur.execute(sql); conn.commit()
    print(f'  {label}: {cur.rowcount} rows')
    return cur.rowcount

print('=' * 65)
print('safe_rename_attr: fpgacpld → fpga_cpld + snake_case scope_code')
print('=' * 65)

# ── 1. dim_attr_schema ────────────────────────────────────────
print('\n[1] dim_attr_schema')
before = q1(f"SELECT COUNT(*) FROM test_dim.dim_attr_schema_{L1} WHERE l1_code='{OLD_L1}'")
print(f'  需修正行数: {before}')

# 先查 PK 列（需要确认 schema 表的 PK）
cur.execute(f'DESC test_dim.dim_attr_schema_{L1}')
cols = cur.fetchall()
pk_cols = [c[0] for c in cols if c[3] == 'true']
print(f'  PK 列: {pk_cols}')
all_cols = [c[0] for c in cols]
print(f'  总列数: {len(all_cols)}')

if before > 0:
    # INSERT SELECT: 修正 l1_code 和 l3 级 scope_code
    cols_select = ', '.join([
        f"'{L1}'" if c == 'l1_code' else
        ("""CASE scope_code
          WHEN 'Macrocell_CPLD' THEN 'macrocell_cpld'
          WHEN 'SRAM_FPGA'      THEN 'sram_fpga'
          WHEN 'SoC_FPGA'       THEN 'soc_fpga'
          WHEN 'Flash_FPGA'     THEN 'flash_fpga'
          WHEN 'Antifuse_FPGA'  THEN 'antifuse_fpga'
          ELSE scope_code END""" if c == 'scope_code' else c)
        for c in all_cols
    ])
    run(f"""INSERT INTO test_dim.dim_attr_schema_{L1}
      ({', '.join(all_cols)})
      SELECT {cols_select}
      FROM test_dim.dim_attr_schema_{L1}
      WHERE l1_code='{OLD_L1}'""", 'upsert schema with new l1_code+scope_code')

    # 验证
    good = q1(f"SELECT COUNT(*) FROM test_dim.dim_attr_schema_{L1} WHERE l1_code='{L1}'")
    bad  = q1(f"SELECT COUNT(*) FROM test_dim.dim_attr_schema_{L1} WHERE l1_code='{OLD_L1}'")
    print(f'  验证: l1_code={L1} 行数={good}, 旧行数={bad}')

    if bad > 0:
        run(f"DELETE FROM test_dim.dim_attr_schema_{L1} WHERE l1_code='{OLD_L1}'", 'delete old schema')
    
    # 验证 scope_code
    bad_scope = q1(f"""SELECT COUNT(*) FROM test_dim.dim_attr_schema_{L1}
      WHERE scope_code REGEXP '[A-Z]' AND scope_level='l3'""")
    print(f'  PascalCase scope_code 残留: {bad_scope}')
    assert bad_scope == 0, '还有 PascalCase scope_code！'

after = q1(f"SELECT COUNT(*) FROM test_dim.dim_attr_schema_{L1} WHERE l1_code='{L1}'")
bad   = q1(f"SELECT COUNT(*) FROM test_dim.dim_attr_schema_{L1} WHERE l1_code<>'{L1}'")
print(f'  最终: l1_code={L1} 行={after}, 其他={bad}')
assert bad == 0 and after == 77, f'schema 异常: after={after}, bad={bad}'
print('  ✅ dim_attr_schema OK')

# ── 2. dim_attr_extract_rule ──────────────────────────────────
print('\n[2] dim_attr_extract_rule')
before = q1(f"SELECT COUNT(*) FROM test_dim.dim_attr_extract_rule_{L1} WHERE l1_code='{OLD_L1}'")
print(f'  需修正行数: {before}')

cur.execute(f'DESC test_dim.dim_attr_extract_rule_{L1}')
cols2 = cur.fetchall()
all_cols2 = [c[0] for c in cols2]
print(f'  总列数: {len(all_cols2)}')

if before > 0:
    cols2_select = ', '.join([
        f"'{L1}'" if c == 'l1_code' else c
        for c in all_cols2
    ])
    run(f"""INSERT INTO test_dim.dim_attr_extract_rule_{L1}
      ({', '.join(all_cols2)})
      SELECT {cols2_select}
      FROM test_dim.dim_attr_extract_rule_{L1}
      WHERE l1_code='{OLD_L1}'""", 'upsert rule with new l1_code')

    good2 = q1(f"SELECT COUNT(*) FROM test_dim.dim_attr_extract_rule_{L1} WHERE l1_code='{L1}'")
    bad2  = q1(f"SELECT COUNT(*) FROM test_dim.dim_attr_extract_rule_{L1} WHERE l1_code='{OLD_L1}'")
    print(f'  验证: l1_code={L1} 行数={good2}, 旧行数={bad2}')
    if bad2 > 0:
        run(f"DELETE FROM test_dim.dim_attr_extract_rule_{L1} WHERE l1_code='{OLD_L1}'", 'delete old rule')

after2 = q1(f"SELECT COUNT(*) FROM test_dim.dim_attr_extract_rule_{L1} WHERE l1_code='{L1}'")
bad2   = q1(f"SELECT COUNT(*) FROM test_dim.dim_attr_extract_rule_{L1} WHERE l1_code<>'{L1}'")
print(f'  最终: l1_code={L1} 行={after2}, 其他={bad2}')
assert bad2 == 0 and after2 == 81, f'rule 异常: after={after2}, bad={bad2}'
print('  ✅ dim_attr_extract_rule OK')

print('\n' + '=' * 65)
print('safe_rename_attr 完成')
cur.close(); conn.close()
