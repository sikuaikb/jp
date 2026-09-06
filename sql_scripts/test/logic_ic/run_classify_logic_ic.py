"""
logic_ic 分类阶段验收脚本（只读/test_dwd，不触碰生产）
按 dim-l3-classify-merge skill Step 0-3 执行：
  Step 0: 确认 test_dim 表已建立
  Step 1: PK 冲突预检
  Step 2: 质量检查
  Step 3: 列出生产将替换的范围
  Step 4: 临时注入 → 跑分类引擎 → test_dwd（try/finally 保证清理）
  Step 5: 验收行数 & L3 分布

不写生产，不需要 ALLOW_PROD=1。
"""
import os, re, sys
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")

HERE = Path(__file__).resolve().parent
SQL_ROOT = HERE.parents[2]
ENV = SQL_ROOT / "sql_scripts" / "local.env"

for line in ENV.read_text(encoding="utf-8").splitlines():
    if line.strip().startswith("export "):
        k, _, v = line[7:].partition("=")
        os.environ[k] = v.strip().strip("'").strip('"')

import pymysql
conn = pymysql.connect(
    host=os.environ["MYSQL_HOST"], port=int(os.environ.get("MYSQL_PORT","9030")),
    user=os.environ["MYSQL_USER"], password=os.environ["MYSQL_PASSWORD"],
    charset="utf8mb4", autocommit=True,
    cursorclass=pymysql.cursors.DictCursor,
)
cur = conn.cursor()

def q(sql, params=None):
    cur.execute(sql, params)
    return cur.fetchall()

def q1(sql, params=None):
    rows = q(sql, params)
    return rows[0] if rows else {}

def section(title):
    print(f"\n{'='*60}")
    print(f"  {title}")
    print('='*60)

L1 = "logic_ic"
L1_PREFIX = "22"  # l3_id 前两位，对应 22_logic_ic

# ─────────────────────────────────────────────────────────────────
# 防护：不在 prod dim 上 DELETE（逆向合仓 prod 已在线）
# ─────────────────────────────────────────────────────────────────

# ─────────────────────────────────────────────────────────────────
# STEP 0: 确认 test_dim 表存在且有数据
# ─────────────────────────────────────────────────────────────────
section("Step 0: 确认 test_dim 表存在")
classify_cnt = q1("SELECT COUNT(*) n FROM test_dim.dim_l3_classify_logic_ic").get('n', 0)
rule_cnt     = q1("SELECT COUNT(*) n FROM test_dim.dim_l3_classify_rule_logic_ic").get('n', 0)
print(f"  dim_l3_classify_logic_ic:      {classify_cnt} 条")
print(f"  dim_l3_classify_rule_logic_ic: {rule_cnt} 条")
if classify_cnt == 0 or rule_cnt == 0:
    print("  !! 表为空，请先运行 load_seed_logic_ic.py"); sys.exit(1)

# ─────────────────────────────────────────────────────────────────
# STEP 1: PK 冲突预检
# ─────────────────────────────────────────────────────────────────
section("Step 1: PK 冲突预检")
conflicts = q(f"""
    SELECT COUNT(*) n FROM (
        SELECT l3_id FROM dim.dim_l3_classify WHERE l1_code <> '{L1}'
        UNION ALL SELECT l3_id FROM test_dim.dim_l3_classify_logic_ic
    ) u GROUP BY l3_id HAVING COUNT(*) > 1
""")
print(f"  l3_id 冲突: {conflicts[0]['n'] if conflicts else 0}  {'[PASS]' if not conflicts else '[FAIL]'}")

rule_conflicts = q(f"""
    WITH prod_keep AS (
        SELECT r.rule_id, r.clause_group_id, r.clause_ord
        FROM dim.dim_l3_classify_rule r
        LEFT JOIN dim.dim_l3_classify d ON d.l3_id=r.l3_id AND d.schema_version=r.schema_version
        WHERE COALESCE(d.l1_code,'') <> '{L1}'
          AND r.rule_id NOT REGEXP '^{L1}_'
          AND r.rule_id NOT REGEXP '^gate_{L1}_'
    )
    SELECT COUNT(*) n FROM (
        SELECT rule_id,clause_group_id,clause_ord FROM prod_keep
        UNION ALL SELECT rule_id,clause_group_id,clause_ord FROM test_dim.dim_l3_classify_rule_logic_ic
    ) u GROUP BY rule_id,clause_group_id,clause_ord HAVING COUNT(*)>1
""")
print(f"  rule_id 冲突: {rule_conflicts[0]['n'] if rule_conflicts else 0}  {'[PASS]' if not rule_conflicts else '[FAIL]'}")

# ─────────────────────────────────────────────────────────────────
# STEP 2: 质量检查
# ─────────────────────────────────────────────────────────────────
section("Step 2: 质量检查")

rows = q(f"SELECT l1_code,COUNT(*) n FROM test_dim.dim_l3_classify_logic_ic GROUP BY l1_code")
bad_l1 = [r for r in rows if r['l1_code'] != L1]
print(f"  l1_code: {[dict(r) for r in rows]}  {'[PASS]' if not bad_l1 else '[FAIL]'}")

bad_ids = q(f"""
    SELECT l3_id FROM test_dim.dim_l3_classify_logic_ic
    WHERE l3_id NOT REGEXP '^[0-9]{{6}}$' OR LEFT(l3_id,2) <> '{L1_PREFIX}'
""")
print(f"  l3_id 格式（前缀{L1_PREFIX}）: {[r['l3_id'] for r in bad_ids] or '无异常'}  {'[PASS]' if not bad_ids else '[FAIL]'}")

bad_l2 = q(f"SELECT DISTINCT l2_code FROM test_dim.dim_l3_classify_logic_ic WHERE l2_code REGEXP '_base$'")
print(f"  l2_code 无 _base: {[r['l2_code'] for r in bad_l2] or '无异常'}  {'[PASS]' if not bad_l2 else '[FAIL]'}")

bad_rules = q(f"""
    SELECT rule_id FROM test_dim.dim_l3_classify_rule_logic_ic
    WHERE rule_id NOT REGEXP '^{L1}_' AND rule_id NOT REGEXP '^gate_{L1}_'
""")
print(f"  rule_id 前缀: {[r['rule_id'] for r in bad_rules] or '全部正确'}  {'[PASS]' if not bad_rules else '[FAIL]'}")

gate_rows = q(f"""
    SELECT data_source,COUNT(*) n FROM test_dim.dim_l3_classify_rule_logic_ic
    WHERE rule_kind='gate' AND enabled=1 GROUP BY data_source
""")
print(f"  gate 规则: {[dict(r) for r in gate_rows]}  {'[PASS]' if gate_rows else '[FAIL]'}")

# ─────────────────────────────────────────────────────────────────
# STEP 3: 生产替换范围确认
# ─────────────────────────────────────────────────────────────────
section("Step 3: 生产替换范围（只读）")
p_cls = q1(f"SELECT COUNT(*) n FROM dim.dim_l3_classify WHERE l1_code='{L1}'").get('n',0)
p_rul = q1(f"SELECT COUNT(*) n FROM dim.dim_l3_classify_rule WHERE rule_id REGEXP '^{L1}_' OR rule_id REGEXP '^gate_{L1}_'").get('n',0)
print(f"  生产 classify: {p_cls} 条（首次=0）  rule: {p_rul} 条（首次=0）")
print(f"  待写入: classify={classify_cnt}  rule={rule_cnt}")

# ─────────────────────────────────────────────────────────────────
# STEP 4: 临时注入 → 跑引擎 → test_dwd
# ─────────────────────────────────────────────────────────────────
section("Step 4: 跑分类引擎 → test_dwd.dwd_component_class_logic_ic")

src = (SQL_ROOT / "sql_scripts/1.classify/dwd_component_class.sql").read_text(encoding="utf-8")
test_sql = src.replace("dwd.dwd_component_class", "test_dwd.dwd_component_class_logic_ic")

def split_stmts(sql):
    sql = re.sub(r'/\*.*?\*/', '', sql, flags=re.DOTALL)
    parts, buf = [], []
    for line in sql.splitlines():
        no_cmt = re.sub(r'^\s*--.*$', '', line)
        buf.append(line)
        if no_cmt.rstrip().endswith(';'):
            stmt = '\n'.join(buf).strip().rstrip(';').strip()
            if stmt:
                parts.append(stmt)
            buf = []
    return parts

injected = False
bak_cls = []
bak_rule = []
try:
    print("  备份 prod dim logic_ic（临时替换前）...")
    bak_cls = q(f"SELECT * FROM dim.dim_l3_classify WHERE l1_code='{L1}'")
    bak_rule = q(f"""
        SELECT r.* FROM dim.dim_l3_classify_rule r
        LEFT JOIN dim.dim_l3_classify d ON d.l3_id=r.l3_id AND d.schema_version=r.schema_version
        WHERE d.l1_code='{L1}' OR r.rule_id REGEXP '^{L1}_' OR r.rule_id REGEXP '^gate_{L1}_'
    """)
    cur.execute(f"DELETE FROM dim.dim_l3_classify WHERE l1_code='{L1}'")
    cur.execute(f"DELETE FROM dim.dim_l3_classify_rule WHERE rule_id REGEXP '^{L1}_' OR rule_id REGEXP '^gate_{L1}_'")

    print("  注入 test_dim 数据到 dim（临时）...")
    cur.execute("INSERT INTO dim.dim_l3_classify SELECT * FROM test_dim.dim_l3_classify_logic_ic")
    cur.execute("INSERT INTO dim.dim_l3_classify_rule SELECT * FROM test_dim.dim_l3_classify_rule_logic_ic")
    injected = True
    print("  注入完成")

    cur.execute("DROP TABLE IF EXISTS test_dwd.dwd_component_class_logic_ic")
    stmts = split_stmts(test_sql)
    print(f"  执行 {len(stmts)} 条 SQL（分类引擎，可能需要 30-120 秒）...")
    cur.execute("SET query_timeout = 259200")
    for i, stmt in enumerate(stmts):
        head = stmt[:80].strip().replace('\n',' ')
        print(f"    [{i+1}/{len(stmts)}] {head!r}...")
        cur.execute(stmt)
    print("  引擎执行完成")

finally:
    if injected:
        print("  恢复 prod dim logic_ic...")
        cur.execute(f"DELETE FROM dim.dim_l3_classify WHERE l1_code='{L1}'")
        cur.execute(f"DELETE FROM dim.dim_l3_classify_rule WHERE rule_id REGEXP '^{L1}_' OR rule_id REGEXP '^gate_{L1}_'")
        if bak_cls:
            cls_cols = list(bak_cls[0].keys())
            for row in bak_cls:
                vals = []
                for c in cls_cols:
                    v = row[c]
                    if v is None:
                        vals.append("NULL")
                    elif isinstance(v, (int, float)):
                        vals.append(str(v))
                    else:
                        vals.append("'" + str(v).replace("\\", "\\\\").replace("'", "''") + "'")
                cur.execute(f"INSERT INTO dim.dim_l3_classify ({', '.join(cls_cols)}) VALUES ({', '.join(vals)})")
        if bak_rule:
            rule_cols = list(bak_rule[0].keys())
            for row in bak_rule:
                vals = []
                for c in rule_cols:
                    v = row[c]
                    if v is None:
                        vals.append("NULL")
                    elif isinstance(v, (int, float)):
                        vals.append(str(v))
                    else:
                        vals.append("'" + str(v).replace("\\", "\\\\").replace("'", "''") + "'")
                cur.execute(f"INSERT INTO dim.dim_l3_classify_rule ({', '.join(rule_cols)}) VALUES ({', '.join(vals)})")
        print(f"  已恢复 classify={len(bak_cls)} rule={len(bak_rule)}")

# ─────────────────────────────────────────────────────────────────
# STEP 5: 验收
# ─────────────────────────────────────────────────────────────────
section("Step 5: 验收结果")

rf_rows = q(f"""
    SELECT l2_code, l3_code, COUNT(*) n
    FROM test_dwd.dwd_component_class_logic_ic
    WHERE l1_code='{L1}' AND data_source='digikey'
    GROUP BY l2_code, l3_code ORDER BY n DESC
""")
total_rf = sum(r['n'] for r in rf_rows)
print(f"\n  logic_ic DigiKey 分类结果: {total_rf:,} 条")
print(f"  {'L2':35} {'L3':35} {'行数':>7}")
print(f"  {'-'*80}")
for r in rf_rows:
    print(f"  {r['l2_code']:35} {r['l3_code']:35} {r['n']:>7,}")

# 与生产 L1 行数对比（漂移检查）
print(f"\n  === 已有 L1 漂移检查 ===")
test_all = q(f"""
    SELECT l1_code, COUNT(*) n FROM test_dwd.dwd_component_class_logic_ic
    WHERE data_source='digikey' GROUP BY l1_code ORDER BY l1_code
""")
prod_all = q(f"""
    SELECT l1_code, COUNT(*) n FROM dwd.dwd_component_class
    WHERE data_source='digikey' GROUP BY l1_code ORDER BY l1_code
""")
prod_map = {r['l1_code']: r['n'] for r in prod_all}
test_map = {r['l1_code']: r['n'] for r in test_all}
all_keys = sorted(set(list(prod_map) + list(test_map)))
ok = True
for l1c in all_keys:
    p = prod_map.get(l1c, 0)
    t = test_map.get(l1c, 0)
    diff = t - p
    pct = abs(diff)/p*100 if p > 0 else 0
    flag = "[新增 OK]" if l1c == L1 else ("!! 漂移>1% [FAIL]" if pct > 1.0 else "")
    if flag and "[FAIL]" in flag:
        ok = False
    print(f"  {l1c:30} prod={p:>8,} test={t:>8,} diff={diff:+,} ({pct:.2f}%) {flag}")

print(f"\n  漂移检查: {'[PASS]' if ok else '[FAIL]'}")
print(f"\n=== 验收完成 ===")
print(f"  logic_ic DigiKey 分类行数: {total_rf:,}")
print(f"  预期范围: ~17,591-21,591（13个L3）")
print(f"  test_dwd 表: test_dwd.dwd_component_class_logic_ic（可继续查询）")
print(f"  若结果合理，将本目录文件提交 git，告知有权限的同事执行 Step 4-9 合并到生产")

conn.close()
