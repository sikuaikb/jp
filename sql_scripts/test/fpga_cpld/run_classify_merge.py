"""
fpga_cpld classify merge  Steps 4-7
Steps 0-3 预检在 precheck.py 已通过。
运行环境：设置 ALLOW_PROD=1 才会执行 prod 写入。
"""
import os, sys, io, pymysql
from pathlib import Path
from datetime import datetime

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

ALLOW_PROD = os.environ.get('ALLOW_PROD', '0') == '1'
L1 = 'fpga_cpld'
MERGE_TAG = datetime.now().strftime('%Y%m%d%H%M')

conn = pymysql.connect(host='192.168.19.21', port=9030, user='rock_admin',
                       password='jE4^mK9%sJ2_vP&7_2026_z!', charset='utf8mb4')
cur = conn.cursor()

def q1(sql):
    try:
        cur.execute(sql); r = cur.fetchone(); return r[0] if r else 0
    except Exception as e:
        print(f'  [WARN] q1: {e}'); return 0

def q(sql):
    cur.execute(sql); return cur.fetchall()

def run(sql, label, conn2=None):
    c = (conn2 or conn).cursor()
    c.execute(sql); (conn2 or conn).commit()
    print(f'  {label}: {c.rowcount} rows')
    return c.rowcount

print('=' * 65)
print(f'fpga_cpld classify merge  ALLOW_PROD={ALLOW_PROD}')
print(f'merge_tag={MERGE_TAG}')
print('=' * 65)

# ── Step 4: prod dim 替换 ──────────────────────────────────────
print('\n[Step 4] prod dim 替换')
old_classify = q1(f"SELECT COUNT(*) FROM dim.dim_l3_classify WHERE l1_code='{L1}'")
old_rule     = q1(f"SELECT COUNT(*) FROM dim.dim_l3_classify_rule WHERE rule_id REGEXP '^(gate_)?{L1}_'")
print(f'  prod 旧: classify={old_classify}, rule={old_rule}')

if not ALLOW_PROD:
    print('  ⚠️  ALLOW_PROD 未设置，跳过 prod 写入')
else:
    # 4a. 备份（用 test_dwd 避免 dim 建表权限问题）
    run(f"""CREATE TABLE IF NOT EXISTS test_dwd.bak_classify_{L1}_{MERGE_TAG}
      AS SELECT * FROM dim.dim_l3_classify WHERE l1_code='{L1}'""",
        f'backup classify → test_dwd.bak_classify_{L1}_{MERGE_TAG}')
    run(f"""CREATE TABLE IF NOT EXISTS test_dwd.bak_rule_{L1}_{MERGE_TAG}
      AS SELECT r.* FROM dim.dim_l3_classify_rule r
      LEFT JOIN dim.dim_l3_classify d
        ON d.l3_id=r.l3_id AND d.schema_version=r.schema_version
      WHERE d.l1_code='{L1}' OR r.rule_id REGEXP '^{L1}_' OR r.rule_id REGEXP '^gate_{L1}_'""",
        f'backup rule → test_dwd.bak_rule_{L1}_{MERGE_TAG}')

    # 4b. 删旧（StarRocks 不支持多列 IN，先删 rule 再删 classify）
    run(f"""DELETE FROM dim.dim_l3_classify_rule
      WHERE rule_id REGEXP '^{L1}_' OR rule_id REGEXP '^gate_{L1}_'""",
        'delete old rule by rule_id prefix')
    # 处理通过 l3_id join 关联的旧 rule（理论上上面已覆盖，保险起见再清）
    old_l3_ids = [str(r[0]) for r in q(f"SELECT l3_id FROM dim.dim_l3_classify WHERE l1_code='{L1}'")]
    if old_l3_ids:
        ids_str = ','.join(f"'{x}'" for x in old_l3_ids)
        run(f"DELETE FROM dim.dim_l3_classify_rule WHERE l3_id IN ({ids_str})",
            'delete residual rule by l3_id')
    run(f"DELETE FROM dim.dim_l3_classify WHERE l1_code='{L1}'", 'delete old classify')

    # 4c. 写入新数据
    run(f"INSERT INTO dim.dim_l3_classify SELECT * FROM test_dim.dim_l3_classify_{L1}",
        'insert classify from test_dim')
    # rule 表有 create_at/update_at，显式列出
    run(f"""INSERT INTO dim.dim_l3_classify_rule
      (rule_id, clause_group_id, clause_ord, schema_version, data_source, rule_kind,
       l3_id, l3_cn, phase, rule_priority, enabled, confidence_weight,
       classify_source_hint, field_code, match_value, match_values, match_map, note)
      SELECT rule_id, clause_group_id, clause_ord, schema_version, data_source, rule_kind,
       l3_id, l3_cn, phase, rule_priority, enabled, confidence_weight,
       classify_source_hint, field_code, match_value, match_values, match_map, note
      FROM test_dim.dim_l3_classify_rule_{L1}""",
        'insert rule from test_dim')

    new_classify = q1(f"SELECT COUNT(*) FROM dim.dim_l3_classify WHERE l1_code='{L1}'")
    new_rule     = q1(f"SELECT COUNT(*) FROM dim.dim_l3_classify_rule WHERE rule_id REGEXP '^(gate_)?{L1}_'")
    print(f'  prod 新: classify={new_classify}, rule={new_rule}')
    assert new_classify == 5, f'classify 行数异常: {new_classify}'
    assert new_rule == 30,    f'rule 行数异常: {new_rule}'
    print('  ✅ Step 4 OK')

# ── Step 5: test_dwd 验证 ─────────────────────────────────────
print('\n[Step 5] test_dwd merge 表验证')
engine_sql = Path('sql_scripts/1.classify/dwd_component_class.sql').read_text(encoding='utf-8')
merge_sql = engine_sql.replace('dwd.dwd_component_class', f'test_dwd.dwd_component_class_merge_{L1}')

# 重建 merge 表
q1(f'DROP TABLE IF EXISTS test_dwd.dwd_component_class_merge_{L1}')
# 拆分多语句执行
stmts = [s.strip() for s in merge_sql.split(';') if s.strip()]
for stmt in stmts:
    try:
        cur.execute(stmt + ';'); conn.commit()
    except Exception as e:
        print(f'  [WARN] stmt error: {str(e)[:100]}')

merge_n = q1(f"SELECT COUNT(*) FROM test_dwd.dwd_component_class_merge_{L1} WHERE l1_code='{L1}'")
base_n  = q1(f"SELECT COUNT(*) FROM test_dwd.dwd_component_class_{L1} WHERE l1_code='{L1}'")
print(f'  merge表 {L1}: {merge_n:,}')
print(f'  基线表 {L1}: {base_n:,}')
diff_pct = abs(merge_n - base_n) / max(base_n, 1) * 100
print(f'  偏差: {diff_pct:.2f}%')

# L3 分布对比
print('  [merge L3 分布]')
for r in q(f"""SELECT data_source, l3_code, COUNT(*) n
    FROM test_dwd.dwd_component_class_merge_{L1} WHERE l1_code='{L1}'
    GROUP BY 1,2 ORDER BY 1, n DESC"""):
    print(f'    {r[0]}/{r[1]}: {r[2]:,}')
print('  [baseline L3 分布]')
for r in q(f"""SELECT data_source, l3_code, COUNT(*) n
    FROM test_dwd.dwd_component_class_{L1} WHERE l1_code='{L1}'
    GROUP BY 1,2 ORDER BY 1, n DESC"""):
    print(f'    {r[0]}/{r[1]}: {r[2]:,}')

if diff_pct > 5:
    print(f'  ⚠️ 行数偏差 {diff_pct:.1f}% 超过 5%，请排查规则')
else:
    print('  ✅ Step 5 行数吻合')

# ── Step 6: prod DWD 重跑 ─────────────────────────────────────
print('\n[Step 6] prod DWD 重跑')
if not ALLOW_PROD:
    print('  ⚠️  ALLOW_PROD 未设置，跳过 prod DWD 写入')
else:
    prod_sql = Path('sql_scripts/1.classify/dwd_component_class.sql').read_text(encoding='utf-8')
    stmts = [s.strip() for s in prod_sql.split(';') if s.strip()]
    ok_count = 0
    for stmt in stmts:
        try:
            cur.execute(stmt + ';'); conn.commit(); ok_count += 1
        except Exception as e:
            print(f'  [WARN] prod stmt: {str(e)[:120]}')
    print(f'  执行 {ok_count}/{len(stmts)} 语句')

# ── Step 7: prod DWD 校验 ─────────────────────────────────────
print('\n[Step 7] prod DWD 校验')
rows = q(f"""SELECT data_source, l1_code, COUNT(*) n
  FROM dwd.dwd_component_class
  WHERE l1_code='{L1}'
  GROUP BY 1,2 ORDER BY 1""")
if rows:
    for r in rows:
        print(f'  {r[0]}/{r[1]}: {r[2]:,}')
    print('  ✅ prod DWD 新 L1 已出现')
else:
    if ALLOW_PROD:
        print('  ⚠️ prod DWD 中未见 fpga_cpld，请排查')
    else:
        print('  (ALLOW_PROD 未设置，prod DWD 未执行)')

print('\n' + '=' * 65)
print('合并脚本结束')
cur.close(); conn.close()
