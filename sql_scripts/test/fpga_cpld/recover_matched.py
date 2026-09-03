import pymysql, sys, io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
conn = pymysql.connect(host='192.168.19.21', port=9030, user='rock_admin',
                       password='jE4^mK9%sJ2_vP&7_2026_z!', charset='utf8mb4')
cur = conn.cursor()
cur.execute("""
SELECT rule_id, l3_id, classify_source, matched_value
FROM test_dwd.dwd_component_class_fpga_cpld
WHERE rule_id LIKE 'fpgacpld_p3%'
GROUP BY rule_id, l3_id, classify_source, matched_value
ORDER BY rule_id LIMIT 40
""")
for r in cur.fetchall():
    print('\n---', r[0], r[1], r[2])
    print(r[3][:500] if r[3] else None)
cur.close(); conn.close()
