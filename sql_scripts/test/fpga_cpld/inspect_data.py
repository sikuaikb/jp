"""查看 fpga_cpld test_dim 数据详情"""
import pymysql, sys, io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
conn = pymysql.connect(host='192.168.19.21', port=9030, user='rock_admin',
                       password='jE4^mK9%sJ2_vP&7_2026_z!', charset='utf8mb4')
cur = conn.cursor()
L1 = 'fpga_cpld'

cur.execute(f'SELECT * FROM test_dim.dim_l3_classify_fpga_cpld ORDER BY l3_id')
cols = [d[0] for d in cur.description]
print('=== dim_l3_classify ===')
for row in cur.fetchall():
    print(dict(zip(cols, row)))

cur.execute(f"""SELECT DISTINCT rule_id, rule_kind, data_source, enabled
  FROM test_dim.dim_l3_classify_rule_{L1} ORDER BY rule_id LIMIT 20""")
print('\n=== rule_id samples ===')
for r in cur.fetchall():
    print(r)

cur.execute(f"""SELECT data_source, l3_code, COUNT(*) n
  FROM test_dwd.dwd_component_class_fpga_cpld GROUP BY 1,2 ORDER BY 1,3 DESC""")
print('\n=== L3 baseline ===')
for r in cur.fetchall():
    print(r)

cur.close(); conn.close()
