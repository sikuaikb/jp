"""
fpga_cpld attr merge  Steps 6-8
Steps 0-3 预检在 attr_precheck.py 已通过。
ALLOW_PROD=1 才写 prod。
"""
import os, sys, io, pymysql
from pathlib import Path
from datetime import datetime

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

ALLOW_PROD = os.environ.get('ALLOW_PROD', '0') == '1'
L1 = 'fpga_cpld'
L2S = ['cpld', 'fpga']
MERGE_TAG = datetime.now().strftime('%Y%m%d%H%M')
READY_DIR = Path('sql_scripts/2.attribute_standard/25_fpga_cpld_ready')

conn = pymysql.connect(host='192.168.19.21', port=9030, user='rock_admin',
                       password='jE4^mK9%sJ2_vP&7_2026_z!', charset='utf8mb4')
cur = conn.cursor()

def q1(sql):
    try:
        cur.execute(sql); r = cur.fetchone(); return r[0] if r else 0
    except Exception as e:
        print(f'  [WARN] {e}'); return 0

def q(sql):
    cur.execute(sql); return cur.fetchall()

def run(sql, label):
    cur.execute(sql); conn.commit()
    print(f'  {label}: {cur.rowcount} rows')
    return cur.rowcount

def exec_sql_file(path, target_db_replace=None):
    """读取 SQL 文件并执行，支持替换目标库"""
    sql = Path(path).read_text(encoding='utf-8-sig')
    if target_db_replace:
        for orig, repl in target_db_replace.items():
            sql = sql.replace(orig, repl)
    stmts = [s.strip() for s in sql.split(';') if s.strip()]
    ok = 0
    for stmt in stmts:
        try:
            cur.execute(stmt + ';'); conn.commit(); ok += 1
        except Exception as e:
            print(f'  [WARN] {str(e)[:120]}')
    return ok, len(stmts)

print('=' * 65)
print(f'fpga_cpld attr merge  ALLOW_PROD={ALLOW_PROD}')
print(f'merge_tag={MERGE_TAG}')
print('=' * 65)

# ── Step 6: prod dim 替换 ──────────────────────────────────────
print('\n[Step 6] prod dim 替换')
old_schema = q1(f"SELECT COUNT(*) FROM dim.dim_attr_schema WHERE l1_code='{L1}'")
old_rule   = q1(f"SELECT COUNT(*) FROM dim.dim_attr_extract_rule WHERE l1_code='{L1}' OR extract_rule_id REGEXP '^{L1}_'")
print(f'  prod 旧: schema={old_schema}, rule={old_rule}')

if not ALLOW_PROD:
    print('  ⚠️  ALLOW_PROD 未设置，跳过 prod 写入')
else:
    # 6a. 备份
    run(f"""CREATE TABLE IF NOT EXISTS test_dwd.bak_attr_schema_{L1}_{MERGE_TAG}
      AS SELECT * FROM dim.dim_attr_schema WHERE l1_code='{L1}'""",
        f'backup schema → test_dwd.bak_attr_schema_{L1}_{MERGE_TAG}')
    run(f"""CREATE TABLE IF NOT EXISTS test_dwd.bak_attr_rule_{L1}_{MERGE_TAG}
      AS SELECT * FROM dim.dim_attr_extract_rule
      WHERE l1_code='{L1}' OR extract_rule_id REGEXP '^{L1}_'""",
        f'backup rule → test_dwd.bak_attr_rule_{L1}_{MERGE_TAG}')

    # 6b. 删旧
    run(f"""DELETE FROM dim.dim_attr_extract_rule
      WHERE l1_code='{L1}' OR extract_rule_id REGEXP '^{L1}_'""", 'delete old rule')
    run(f"DELETE FROM dim.dim_attr_schema WHERE l1_code='{L1}'", 'delete old schema')

    # 6c. 写入
    run(f"INSERT INTO dim.dim_attr_schema SELECT * FROM test_dim.dim_attr_schema_{L1}", 'insert schema')
    run(f"INSERT INTO dim.dim_attr_extract_rule SELECT * FROM test_dim.dim_attr_extract_rule_{L1}", 'insert rule')

    new_schema = q1(f"SELECT COUNT(*) FROM dim.dim_attr_schema WHERE l1_code='{L1}'")
    new_rule   = q1(f"SELECT COUNT(*) FROM dim.dim_attr_extract_rule WHERE l1_code='{L1}' OR extract_rule_id REGEXP '^{L1}_'")
    print(f'  prod 新: schema={new_schema}, rule={new_rule}')
    assert new_schema == 77, f'schema 行数异常: {new_schema}'
    assert new_rule == 81,   f'rule 行数异常: {new_rule}'
    print('  ✅ Step 6 OK')

# ── Step 7: test_dwd merge 验证 ───────────────────────────────
print('\n[Step 7] test_dwd merge 验证')

# 7a. EAV merge
print('  [7a] EAV merge 表')
for src in ['icpdf', 'digikey']:
    build_file = f'sql_scripts/2.attribute_standard/build_dwd_component_attr_std_{src}.sql'
    if not Path(build_file).exists():
        print(f'  ⚠️ 找不到 {build_file}')
        continue
    merge_tbl = f'test_dwd.dwd_component_attr_std_merge_{L1}'
    q1(f'DROP TABLE IF EXISTS {merge_tbl}')
    run(f'CREATE TABLE {merge_tbl} LIKE dwd.dwd_component_attr_std', f'CREATE {merge_tbl}')
    ok, total = exec_sql_file(build_file, {
        'dwd.dwd_component_attr_std': merge_tbl,
        "l1_code != '_unclassified'": f"l1_code = '{L1}'"
    })
    n_merge = q1(f"SELECT COUNT(*) FROM {merge_tbl}")
    print(f'  [{src}] EAV merge: {n_merge:,} rows (SQL: {ok}/{total})')

# 汇总 EAV merge vs baseline
print('\n  [EAV 汇总对比]')
rows_merge  = q(f"SELECT data_source, COUNT(DISTINCT id) ids, COUNT(*) rows_ FROM test_dwd.dwd_component_attr_std_merge_{L1} GROUP BY 1")
rows_base   = q(f"SELECT data_source, COUNT(DISTINCT id) ids, COUNT(*) rows_ FROM test_dwd.dwd_component_attr_std_{L1} GROUP BY 1")
print('  merge:', rows_merge)
print('  base: ', rows_base)

# 7b. L2 merge
print('\n  [7b] L2 merge 表')
for l2 in L2S:
    merge_tbl = f'test_dwd.dwd_l2_{L1}_{l2}_merge'
    q1(f'DROP TABLE IF EXISTS {merge_tbl}')
    run(f'CREATE TABLE {merge_tbl} LIKE dwd.dwd_l2_{L1}_{l2}', f'CREATE {merge_tbl}')
    build_file = READY_DIR / f'build_dwd_l2_{L1}_{l2}.sql'
    ok, total = exec_sql_file(build_file, {
        f'dwd.dwd_l2_{L1}_{l2}': merge_tbl
    })
    n_merge = q1(f"SELECT COUNT(*) FROM {merge_tbl}")
    print(f'  [{l2}] L2 merge: {n_merge:,} rows (SQL: {ok}/{total})')

print('\n[Step 7 结果汇总]')
for l2 in L2S:
    n = q1(f"SELECT COUNT(*) FROM test_dwd.dwd_l2_{L1}_{l2}_merge")
    print(f'  dwd_l2_{L1}_{l2}_merge: {n:,}')

print('=' * 65)
print('attr merge 脚本结束')
cur.close(); conn.close()
