import pymysql
conn = pymysql.connect(host='192.168.19.21', port=9030, user='rock_admin',
                       password='jE4^mK9%sJ2_vP&7_2026_z!', charset='utf8mb4')
cur = conn.cursor()
cur.execute("""SELECT table_schema, table_name FROM information_schema.tables
  WHERE (table_name LIKE '%fpga%' OR table_name LIKE '%fpgacpld%' OR table_name LIKE '%bak%rule%')
  AND table_schema IN ('test_dim','test_dwd','dim')
  ORDER BY 1,2""")
print('tables:', cur.fetchall())
cur.execute('SELECT COUNT(*) FROM test_dim.dim_l3_classify_rule_fpga_cpld')
print('rule count:', cur.fetchone()[0])
cur.execute("""SELECT DISTINCT rule_id FROM test_dwd.dwd_component_class_fpga_cpld ORDER BY 1""")
print('rule_ids in baseline:', len(cur.fetchall()))
cur.execute("""SELECT rule_id, COUNT(*) FROM test_dwd.dwd_component_class_fpga_cpld GROUP BY 1 ORDER BY 2 DESC""")
for r in cur.fetchall():
    print(r)
cur.close(); conn.close()
