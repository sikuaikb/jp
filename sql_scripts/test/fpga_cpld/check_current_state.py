"""只读检查当前 fpga_cpld test_dim/dwd 状态，不修改任何数据"""
import pymysql, sys, io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
conn = pymysql.connect(host='192.168.19.21', port=9030, user='rock_admin',
                       password='jE4^mK9%sJ2_vP&7_2026_z!', charset='utf8mb4')
cur = conn.cursor()

def q(sql):
    cur.execute(sql)
    return cur.fetchall()

print('=' * 65)
print('fpga_cpld 当前状态（只读）')
print('=' * 65)

# classify
rows = q("SELECT l1_code, l2_code, l3_code, l3_id FROM test_dim.dim_l3_classify_fpga_cpld ORDER BY l3_id")
print(f"\nclassify 行数: {len(rows)}")
for r in rows:
    print(f"  {r[3]} {r[0]}/{r[1]}/{r[2]}")

# rule
n_rule = q("SELECT COUNT(*) FROM test_dim.dim_l3_classify_rule_fpga_cpld")[0][0]
print(f"\nrule 行数: {n_rule}")
if n_rule > 0:
    rows = q("""SELECT DISTINCT rule_id, rule_kind, data_source, enabled
      FROM test_dim.dim_l3_classify_rule_fpga_cpld ORDER BY rule_kind, rule_id""")
    for r in rows:
        print(f"  {r[1]:<10} {r[2]:<10} enabled={r[3]}  {r[0]}")

# dwd baseline
rows = q("""SELECT data_source, l3_code, COUNT(*) n
  FROM test_dwd.dwd_component_class_fpga_cpld GROUP BY 1,2 ORDER BY 1,3 DESC""")
totals = {}
for r in rows:
    totals[r[0]] = totals.get(r[0], 0) + r[2]
print(f"\nbaseline dwd 行数:")
for src, n in sorted(totals.items()):
    print(f"  [{src}] 共 {n:,}")
for r in rows:
    pct = r[2] / totals[r[0]] * 100
    print(f"    {r[0]} {r[1]}: {r[2]:,} ({pct:.1f}%)")

# prod classify 旧数据
n_prod = q("SELECT COUNT(*) FROM dim.dim_l3_classify WHERE l1_code='fpga_cpld'")[0][0]
n_prod_r = q("SELECT COUNT(*) FROM dim.dim_l3_classify_rule WHERE rule_id REGEXP '^fpga_cpld_' OR rule_id REGEXP '^gate_fpga_cpld_'")[0][0]
print(f"\nprod dim 旧数据: classify={n_prod}, rule={n_prod_r}")

print('=' * 65)
cur.close()
conn.close()
