import pymysql, sys, io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
conn = pymysql.connect(host='192.168.19.21', port=9030, user='rock_admin',
                       password='jE4^mK9%sJ2_vP&7_2026_z!', charset='utf8mb4')
cur = conn.cursor()
# 搜索可能含 rule 备份的表
cur.execute("""
SELECT table_schema, table_name FROM information_schema.tables
WHERE table_schema IN ('test_dim','test_dwd','dim')
  AND (table_name LIKE '%fpga%' OR table_name LIKE '%fpgacpld%' OR table_name LIKE '%classify_rule%bak%')
ORDER BY 1,2
""")
for sch, tbl in cur.fetchall():
    try:
        cur.execute(f"SELECT COUNT(*) FROM {sch}.{tbl} WHERE CAST(rule_id AS CHAR) REGEXP 'fpgacpld|fpga_cpld'")
        n = cur.fetchone()[0]
        if n:
            print(f'{sch}.{tbl}: {n}')
    except Exception:
        pass
cur.close(); conn.close()
