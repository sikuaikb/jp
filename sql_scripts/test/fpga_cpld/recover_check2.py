import pymysql, sys, io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
conn = pymysql.connect(host='192.168.19.21', port=9030, user='rock_admin',
                       password='jE4^mK9%sJ2_vP&7_2026_z!', charset='utf8mb4')
cur = conn.cursor()

for sql in [
    "SELECT COUNT(*) FROM dim.dim_l3_classify_rule WHERE rule_id REGEXP 'fpgacpld|fpga_cpld'",
    "SELECT COUNT(*) FROM test_dim.dim_l3_classify_rule WHERE rule_id REGEXP 'fpgacpld|fpga_cpld'",
    "SELECT COUNT(*) FROM test_dim.dim_l3_classify_rule_fpga_cpld",
    "SELECT COUNT(*) FROM test_dwd.bak_rule_fpga_cpld_rename",
]:
    cur.execute(sql)
    print(sql.split('FROM')[1].strip(), '->', cur.fetchone()[0])

cur.execute("SHOW CREATE TABLE test_dim.dim_l3_classify_rule_fpga_cpld")
print('\n', cur.fetchone()[1][:800])

cur.close(); conn.close()
