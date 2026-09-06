"""检查 rule 表是否引用 PascalCase l3_code"""
import pymysql, sys, io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
conn = pymysql.connect(host='192.168.19.21', port=9030, user='rock_admin',
                       password='jE4^mK9%sJ2_vP&7_2026_z!', charset='utf8mb4')
cur = conn.cursor()

cur.execute("""SELECT rule_id, l3_id, l3_cn, field_code, match_value, match_values
  FROM test_dim.dim_l3_classify_rule_fpga_cpld ORDER BY rule_id, clause_ord LIMIT 15""")
cols = [d[0] for d in cur.description]
for row in cur.fetchall():
    print(dict(zip(cols, row)))

cur.execute("SELECT DISTINCT l1_code, l3_code FROM test_dwd.dwd_component_class_fpga_cpld")
print('\ndwd baseline l1/l3:', cur.fetchall())

cur.execute("SELECT DISTINCT l1_code FROM test_dim.dim_attr_schema_fpga_cpld")
print('attr schema l1_code:', cur.fetchall())

cur.close(); conn.close()
