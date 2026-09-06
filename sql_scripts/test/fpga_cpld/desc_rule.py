import pymysql, sys, io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
conn = pymysql.connect(host='192.168.19.21', port=9030, user='rock_admin',
                       password='jE4^mK9%sJ2_vP&7_2026_z!', charset='utf8mb4')
cur = conn.cursor()
cur.execute('DESC test_dim.dim_l3_classify_rule_fpga_cpld')
cols = cur.fetchall()
print(f'列数: {len(cols)}')
for c in cols:
    print(c)
conn.close()
