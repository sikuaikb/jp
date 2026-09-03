"""验证 prod EAV + L2 实际数据"""
import pymysql, sys, io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

conn = pymysql.connect(host='192.168.19.21', port=9030, user='rock_admin',
                       password='jE4^mK9%sJ2_vP&7_2026_z!', charset='utf8mb4')
cur = conn.cursor()
L1 = 'fpga_cpld'

def q(sql):
    cur.execute(sql); return cur.fetchall()

# EAV 表结构（看有没有 l1_code 列）
print('[EAV 表列（前5）]')
cur.execute('DESC dwd.dwd_component_attr_std')
cols = cur.fetchall()
for c in cols[:8]:
    print(f'  {c[0]:30} {c[1]}')

# EAV fpga_cpld 行数（通过 join classify）
print('\n[EAV fpga_cpld 行数（join dwd_component_class）]')
rows = q(f"""SELECT c.data_source, COUNT(DISTINCT e.id) ids, COUNT(*) rows_
  FROM dwd.dwd_component_attr_std e
  JOIN dwd.dwd_component_class c ON c.data_source=e.data_source AND c.id=e.id
  WHERE c.l1_code='{L1}'
  GROUP BY 1""")
for r in rows:
    print(f'  [{r[0]}] distinct_id={r[1]:,}, rows={r[2]:,}')

# L2 验证
print('\n[prod L2 宽表]')
for l2 in ['cpld', 'fpga']:
    rows = q(f"SELECT data_source, COUNT(*) n FROM dwd.dwd_l2_{L1}_{l2} GROUP BY 1 ORDER BY 1")
    for r in rows:
        print(f'  dwd_l2_{L1}_{l2} [{r[0]}]: {r[1]:,}')

# L2 关键字段空值率（cpld）
print('\n[L2 cpld 关键字段空值率]')
rows = q(f"""SELECT
  SUM(CASE WHEN brand IS NULL THEN 1 ELSE 0 END) brand_null,
  COUNT(*) total,
  SUM(CASE WHEN macrocell_count IS NOT NULL THEN 1 ELSE 0 END) has_macrocell,
  SUM(CASE WHEN io_count IS NOT NULL THEN 1 ELSE 0 END) has_io
  FROM dwd.dwd_l2_{L1}_cpld""")
for r in rows:
    total = r[1]
    print(f'  brand_null={r[0]} ({r[0]/total*100:.1f}%), macrocell_fill={r[2]/total*100:.1f}%, io_fill={r[3]/total*100:.1f}%')

conn.close()
