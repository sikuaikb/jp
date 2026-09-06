"""dim-l3-classify-merge Steps 0-3 预检  L1=fpga_cpld"""
import pymysql, sys, io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
conn = pymysql.connect(host='192.168.19.21', port=9030, user='rock_admin',
                       password='jE4^mK9%sJ2_vP&7_2026_z!', charset='utf8mb4')
cur = conn.cursor()
L1 = 'fpga_cpld'
L1_PREFIX = '25'

def q1(sql):
    try:
        cur.execute(sql)
        r = cur.fetchone()
        return r[0] if r else 0
    except Exception as e:
        print(f'  [WARN] q1 error: {e}')
        return 0

def q(sql):
    try:
        cur.execute(sql)
        return cur.fetchall()
    except Exception as e:
        return [('ERR', str(e))]

print('=' * 65)
print(f'dim-l3-classify-merge 预检  L1={L1}')
print('=' * 65)

# list test tables
rows = q("""SELECT table_name FROM information_schema.tables
  WHERE table_schema='test_dim' AND table_name LIKE '%fpga%'
  ORDER BY table_name""")
print('\n[test_dim fpga 相关表]', [r[0] for r in rows])
rows = q("""SELECT table_name FROM information_schema.tables
  WHERE table_schema='test_dwd' AND table_name LIKE '%fpga%'
  ORDER BY table_name""")
print('[test_dwd fpga 相关表]', [r[0] for r in rows])

# Step 0
print('\n[Step 0] Phase 1')
for tbl in [f'dim_l3_classify_{L1}', f'dim_l3_classify_rule_{L1}', f'dwd_component_class_{L1}']:
    db = 'test_dim' if tbl.startswith('dim') else 'test_dwd'
    n = q1(f"SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='{db}' AND table_name='{tbl}'")
    if n == 0:
        print(f'  ❌ {db}.{tbl} 不存在')
    else:
        cnt = q1(f'SELECT COUNT(*) FROM {db}.{tbl}')
        print(f'  {db}.{tbl}: {cnt:,}')

rows = q(f'SELECT l2_code, l3_code, l3_id, schema_version FROM test_dim.dim_l3_classify_{L1} ORDER BY l3_id')
if rows and rows[0][0] != 'ERR':
    print('  L3 taxonomy:')
    for r in rows:
        print(f'    {r[2]} {r[0]}/{r[1]} ({r[3]})')

# Step 1 PK
print('\n[Step 1] PK 冲突')
n = q1(f"""SELECT COUNT(*) FROM (
  SELECT l3_id FROM dim.dim_l3_classify WHERE l1_code <> '{L1}'
  UNION ALL SELECT l3_id FROM test_dim.dim_l3_classify_{L1}
) u GROUP BY l3_id HAVING COUNT(*)>1""")
print(f"  {'✅' if n==0 else '❌'} l3_id 冲突: {n}")

n = q1(f"""SELECT COUNT(*) FROM (
  SELECT rule_id, clause_group_id, clause_ord FROM (
    SELECT r.rule_id, r.clause_group_id, r.clause_ord
    FROM dim.dim_l3_classify_rule r
    LEFT JOIN dim.dim_l3_classify d ON d.l3_id=r.l3_id AND d.schema_version=r.schema_version
    WHERE COALESCE(d.l1_code,'') <> '{L1}'
      AND r.rule_id NOT REGEXP '^{L1}_'
      AND r.rule_id NOT REGEXP '^gate_{L1}_'
    UNION ALL
    SELECT rule_id, clause_group_id, clause_ord FROM test_dim.dim_l3_classify_rule_{L1}
  ) x
) u GROUP BY rule_id, clause_group_id, clause_ord HAVING COUNT(*)>1""")
print(f"  {'✅' if n==0 else '❌'} rule PK 冲突: {n}")

# Step 2 quality
print('\n[Step 2] 质量检查')
rows = q(f"SELECT l1_code, COUNT(*) FROM test_dim.dim_l3_classify_{L1} GROUP BY 1")
ok = len(rows)==1 and rows[0][0]==L1
print(f"  {'✅' if ok else '❌'} l1_code: {rows}")

n = q1(f"""SELECT COUNT(*) FROM test_dim.dim_l3_classify_{L1}
  WHERE l3_id NOT REGEXP '^[0-9]{{6}}$' OR LEFT(l3_id,2) <> '{L1_PREFIX}'""")
print(f"  {'✅' if n==0 else '❌'} l3_id 格式(25xxxx): {n}")

n = q1(f"""SELECT COUNT(*) FROM test_dim.dim_l3_classify_rule_{L1}
  WHERE rule_id NOT REGEXP '^{L1}_' AND rule_id NOT REGEXP '^gate_{L1}_'""")
print(f"  {'✅' if n==0 else '❌'} rule_id 前缀: {n}")

gates = q(f"""SELECT data_source, COUNT(*) FROM test_dim.dim_l3_classify_rule_{L1}
  WHERE enabled=1 AND rule_kind='gate' GROUP BY 1""")
print(f"  gate 规则: {gates}")

# Step 3
print('\n[Step 3] 替换范围')
n_old = q1(f"SELECT COUNT(*) FROM dim.dim_l3_classify WHERE l1_code='{L1}'")
n_old_r = q1(f"""SELECT COUNT(*) FROM dim.dim_l3_classify_rule r
  LEFT JOIN dim.dim_l3_classify d ON d.l3_id=r.l3_id AND d.schema_version=r.schema_version
  WHERE d.l1_code='{L1}' OR r.rule_id REGEXP '^{L1}_' OR r.rule_id REGEXP '^gate_{L1}_'""")
n_new = q1(f'SELECT COUNT(*) FROM test_dim.dim_l3_classify_{L1}')
n_new_r = q1(f'SELECT COUNT(*) FROM test_dim.dim_l3_classify_rule_{L1}')
print(f'  prod 旧: classify={n_old}, rule={n_old_r}')
print(f'  test 新: classify={n_new}, rule={n_new_r}')

# L3 distribution
print('\n[L3 分布 baseline]')
rows = q(f"""SELECT data_source, l3_code, COUNT(*) n
  FROM test_dwd.dwd_component_class_{L1}
  GROUP BY 1,2 ORDER BY 1, n DESC""")
src_total = {}
d = {}
for r in rows:
    src, l3, n = r[0], r[1], int(r[2])
    src_total[src] = src_total.get(src, 0) + n
    d.setdefault(src, {})[l3] = d.setdefault(src, {}).get(l3, 0) + n
for src in sorted(src_total):
    print(f'  [{src}] 共 {src_total[src]:,}')
    for l3, n in sorted(d[src].items(), key=lambda x: -x[1]):
        pct = n / src_total[src] * 100
        flag = ' ⚠️' if pct > 60 else ''
        print(f'    {l3}: {n:,} ({pct:.1f}%){flag}')

print('\n' + '=' * 65)
cur.close()
conn.close()
