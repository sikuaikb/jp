"""fpga_cpld attr merge 预检 Steps 0-3"""
import pymysql, sys, io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

conn = pymysql.connect(host='192.168.19.21', port=9030, user='rock_admin',
                       password='jE4^mK9%sJ2_vP&7_2026_z!', charset='utf8mb4')
cur = conn.cursor()
L1 = 'fpga_cpld'

def q1(sql):
    try:
        cur.execute(sql); r = cur.fetchone(); return r[0] if r else 0
    except Exception as e:
        print(f'  [WARN] {e}'); return 0

def q(sql):
    cur.execute(sql); return cur.fetchall()

print('=' * 65)
print(f'attr merge 预检  L1={L1}')
print('=' * 65)

# Step 0: 阶段1已完成验证
print('\n[Step 0] test_dim 表行数')
n_schema  = q1(f'SELECT COUNT(*) FROM test_dim.dim_attr_schema_{L1}')
n_rule    = q1(f'SELECT COUNT(*) FROM test_dim.dim_attr_extract_rule_{L1}')
n_eav     = q1(f'SELECT COUNT(*) FROM test_dwd.dwd_component_attr_std_{L1}')
print(f'  dim_attr_schema:       {n_schema}')
print(f'  dim_attr_extract_rule: {n_rule}')
print(f'  dwd_component_attr_std:{n_eav:,}')
print('  l1_code:', q(f"SELECT DISTINCT l1_code FROM test_dim.dim_attr_schema_{L1}"))
print('  scope_level:', q(f"SELECT scope_level, COUNT(*) FROM test_dim.dim_attr_schema_{L1} GROUP BY 1"))

# L2 tables
print('\n  L2 宽表:')
l2_tables = q(f"""SELECT table_name FROM information_schema.tables
  WHERE table_schema='test_dwd' AND table_name LIKE 'dwd_l2_{L1}%'
  AND table_name NOT LIKE '%_merge%'""")
for t in l2_tables:
    n = q(f"SELECT data_source, COUNT(*) n FROM test_dwd.{t[0]} GROUP BY 1")
    print(f'    {t[0]}: {n}')

# Step 1: PK 冲突
print('\n[Step 1] PK 冲突预检')
schema_pk_conflict = q1(f"""SELECT COUNT(*) FROM (
  SELECT schema_version, l1_code, scope_level, scope_code, std_attr_code, COUNT(*) c FROM (
    SELECT schema_version, l1_code, scope_level, scope_code, std_attr_code
    FROM dim.dim_attr_schema WHERE l1_code <> '{L1}'
    UNION ALL
    SELECT schema_version, l1_code, scope_level, scope_code, std_attr_code
    FROM test_dim.dim_attr_schema_{L1}
  ) u GROUP BY 1,2,3,4,5 HAVING COUNT(*)>1
) x""")
rule_pk_conflict = q1(f"""SELECT COUNT(*) FROM (
  SELECT extract_rule_id, COUNT(*) c FROM (
    SELECT extract_rule_id FROM dim.dim_attr_extract_rule
    WHERE l1_code <> '{L1}' AND extract_rule_id NOT REGEXP '^{L1}_'
    UNION ALL
    SELECT extract_rule_id FROM test_dim.dim_attr_extract_rule_{L1}
  ) u GROUP BY extract_rule_id HAVING COUNT(*)>1
) x""")
flag = '✅' if schema_pk_conflict == 0 else '❌'
print(f'  {flag} schema PK 冲突: {schema_pk_conflict}')
flag = '✅' if rule_pk_conflict == 0 else '❌'
print(f'  {flag} rule PK 冲突:   {rule_pk_conflict}')

# Step 2: 质量检查
print('\n[Step 2] 质量检查')
bad_rule_id = q1(f"""SELECT COUNT(*) FROM test_dim.dim_attr_extract_rule_{L1}
  WHERE extract_rule_id NOT REGEXP '^{L1}_'""")
bad_snake = q1(f"""SELECT COUNT(*) FROM test_dim.dim_attr_schema_{L1}
  WHERE std_attr_code NOT REGEXP '^[a-z0-9]+(_[a-z0-9]+)*$'
     OR scope_code NOT REGEXP '^[a-z0-9]+(_[a-z0-9]+)*$'
     OR (scope_level='L2' AND scope_code REGEXP '_base$')""")
orphan_rule = q1(f"""SELECT COUNT(*) FROM test_dim.dim_attr_extract_rule_{L1} r
  LEFT JOIN test_dim.dim_attr_schema_{L1} s
    ON s.schema_version=r.schema_version AND s.l1_code='{L1}' AND s.std_attr_code=r.std_attr_code
  WHERE s.std_attr_code IS NULL""")
flag = '✅' if bad_rule_id == 0 else '❌'
print(f'  {flag} rule_id 无前缀: {bad_rule_id}')
flag = '✅' if bad_snake == 0 else '❌'
print(f'  {flag} snake_case 异常: {bad_snake}')
flag = '✅' if orphan_rule == 0 else '⚠️'
print(f'  {flag} rule 孤立项(无对应schema): {orphan_rule}')

# Step 3: 生产替换范围
print('\n[Step 3] 生产替换范围')
p_schema = q1(f"SELECT COUNT(*) FROM dim.dim_attr_schema WHERE l1_code='{L1}'")
p_rule   = q1(f"SELECT COUNT(*) FROM dim.dim_attr_extract_rule WHERE l1_code='{L1}' OR extract_rule_id REGEXP '^{L1}_'")
print(f'  prod 旧: schema={p_schema}, rule={p_rule}')
print(f'  test 新: schema={n_schema}, rule={n_rule}')

# unit_factor supplement?
try:
    n_uf = q1(f'SELECT COUNT(*) FROM test_dim.dim_unit_factor_{L1}_supplement')
    print(f'  unit_factor supplement: {n_uf} 条')
except:
    print('  unit_factor supplement: 无')

# EAV 分布
print('\n[EAV 基线分布]')
rows = q(f"SELECT data_source, COUNT(DISTINCT id) ids, COUNT(*) rows_ FROM test_dwd.dwd_component_attr_std_{L1} GROUP BY 1")
for r in rows:
    print(f'  [{r[0]}] distinct_id={r[1]:,}, rows={r[2]:,}')

print('\n' + '=' * 65)
cur.close(); conn.close()
