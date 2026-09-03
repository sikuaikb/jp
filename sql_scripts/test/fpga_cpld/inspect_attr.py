"""检查 fpga_cpld attr schema/rule 当前状态"""
import pymysql, sys, io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

conn = pymysql.connect(host='192.168.19.21', port=9030, user='rock_admin',
                       password='jE4^mK9%sJ2_vP&7_2026_z!', charset='utf8mb4')
cur = conn.cursor()
L1 = 'fpga_cpld'

def q(sql):
    cur.execute(sql); return cur.fetchall()

print('[scope_code 样本 - 所有不重复值]')
rows = q(f"""SELECT DISTINCT scope_level, scope_code FROM test_dim.dim_attr_schema_{L1}
  ORDER BY scope_level, scope_code""")
for r in rows:
    print(f'  {r[0]:5} | {r[1]}')

print('\n[snake_case 异常行]')
rows = q(f"""SELECT scope_level, scope_code, std_attr_code FROM test_dim.dim_attr_schema_{L1}
  WHERE std_attr_code NOT REGEXP '^[a-z0-9]+(_[a-z0-9]+)*$'
     OR scope_code NOT REGEXP '^[a-z0-9]+(_[a-z0-9]+)*$'
     OR (scope_level='L2' AND scope_code REGEXP '_base$')
  ORDER BY 1,2""")
for r in rows:
    print(f'  {r[0]:5} | scope={r[1]} | attr={r[2]}')

print('\n[l1_code 分布]')
rows = q(f'SELECT l1_code, COUNT(*) n FROM test_dim.dim_attr_schema_{L1} GROUP BY 1')
for r in rows: print(f'  {r}')

print('\n[rule l1_code 分布]')
rows = q(f'SELECT l1_code, COUNT(*) n FROM test_dim.dim_attr_extract_rule_{L1} GROUP BY 1')
for r in rows: print(f'  {r}')

print('\n[rule extract_rule_id 前5条]')
rows = q(f'SELECT extract_rule_id, l1_code, std_attr_code, data_source FROM test_dim.dim_attr_extract_rule_{L1} LIMIT 5')
for r in rows: print(f'  {r}')

print('\n[L2 表内 l3_code 样本]')
for t in [f'dwd_l2_{L1}_cpld_{L1}', f'dwd_l2_{L1}_fpga_{L1}']:
    try:
        r = q(f'SELECT l3_code, COUNT(*) FROM test_dwd.{t} GROUP BY 1')
        print(f'  {t}: {r}')
    except Exception as e:
        print(f'  {t}: 不存在或错误: {e}')

cur.close(); conn.close()
