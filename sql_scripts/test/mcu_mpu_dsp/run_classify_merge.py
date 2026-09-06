"""
mcu_mpu_dsp 分类合并（dim-l3-classify-merge skill）
Step 1-3: 预检
Step 4-7: prod dim 替换 + test_dwd 验证 + prod DWD 重建（需 ALLOW_PROD=1）
"""
import os, sys, re
from pathlib import Path
from datetime import datetime
sys.stdout.reconfigure(encoding="utf-8")

L1 = "mcu_mpu_dsp"
L1_PREFIX = "19"
MERGE_TAG = datetime.now().strftime("%Y%m%d%H%M")

HERE = Path(__file__).resolve().parent
ENV = HERE.parents[1] / "local.env"
for line in ENV.read_text(encoding="utf-8").splitlines():
    if line.strip().startswith("export "):
        k, _, v = line[7:].partition("=")
        os.environ[k] = v.strip().strip("'").strip('"')

import pymysql
conn = pymysql.connect(
    host=os.environ["MYSQL_HOST"], port=int(os.environ.get("MYSQL_PORT", "9030")),
    user=os.environ["MYSQL_USER"], password=os.environ["MYSQL_PASSWORD"],
    charset="utf8mb4", autocommit=True,
    cursorclass=pymysql.cursors.DictCursor,
)
cur = conn.cursor()

def q(sql):
    cur.execute(sql)
    return cur.fetchall()

def q1(sql):
    rows = q(sql)
    return rows[0] if rows else {}

def sum_by_ds(rows, key="n"):
    from collections import defaultdict
    d = defaultdict(int)
    for r in rows:
        d[r["data_source"]] += int(r.get(key) or 0)
    return dict(d)

def split_stmts(sql: str) -> list[str]:
    parts, buf = [], []
    for line in sql.splitlines():
        no_cmt = re.sub(r"^\s*--.*$", "", line)
        buf.append(line)
        if no_cmt.rstrip().endswith(";"):
            stmt = "\n".join(buf).strip()
            stmt = re.sub(r"/\*.*?\*/", "", stmt, flags=re.DOTALL).rstrip().rstrip(";").strip()
            if stmt:
                parts.append(stmt)
            buf = []
    return parts

def exec_sql_file(sql_text: str, label: str):
    stmts = split_stmts(sql_text)
    print(f"  执行 {label}: {len(stmts)} statements")
    for i, stmt in enumerate(stmts, 1):
        preview = re.sub(r"\s+", " ", stmt)[:90]
        print(f"    [{i}/{len(stmts)}] {preview}...")
        cur.execute(stmt)

def section(title):
    print(f"\n{'='*66}\n  {title}\n{'='*66}")

def fail(msg):
    print(f"\n❌ STOP: {msg}")
    sys.exit(1)

# ── 0. 后缀表存在性 ─────────────────────────────────────────────
section("0. 阶段1 后缀表检查")
for tbl in (
    "test_dim.dim_l3_classify_mcu_mpu_dsp",
    "test_dim.dim_l3_classify_rule_mcu_mpu_dsp",
    "test_dwd.dwd_component_class_mcu_mpu_dsp",
):
    try:
        n = q1(f"SELECT COUNT(*) AS n FROM {tbl}")["n"]
        print(f"  ✅ {tbl}: {n:,} rows")
    except Exception as e:
        fail(f"{tbl} 不存在或不可读: {e}")

# ── Step 1 PK 冲突 ────────────────────────────────────────────
section("Step 1 PK 冲突预检")
l3_conflicts = q(f"""
    SELECT l3_id, COUNT(*) AS cnt FROM (
        SELECT l3_id FROM dim.dim_l3_classify WHERE l1_code <> '{L1}'
        UNION ALL SELECT l3_id FROM test_dim.dim_l3_classify_{L1}
    ) u GROUP BY l3_id HAVING COUNT(*) > 1
""")
if l3_conflicts:
    print("  l3_id 冲突:", l3_conflicts[:10])
    fail(f"l3_id 冲突 {len(l3_conflicts)} 个")
print("  ✅ l3_id 冲突: 0")

rule_conflicts = q(f"""
    WITH prod_keep_rule AS (
        SELECT r.rule_id, r.clause_group_id, r.clause_ord
        FROM dim.dim_l3_classify_rule r
        LEFT JOIN dim.dim_l3_classify d
            ON d.l3_id = r.l3_id AND d.schema_version = r.schema_version
        WHERE COALESCE(d.l1_code, '') <> '{L1}'
          AND r.rule_id NOT REGEXP '^{L1}_'
          AND r.rule_id NOT REGEXP '^gate_{L1}_'
    )
    SELECT rule_id, clause_group_id, clause_ord, COUNT(*) AS cnt FROM (
        SELECT rule_id, clause_group_id, clause_ord FROM prod_keep_rule
        UNION ALL
        SELECT rule_id, clause_group_id, clause_ord FROM test_dim.dim_l3_classify_rule_{L1}
    ) u GROUP BY rule_id, clause_group_id, clause_ord HAVING COUNT(*) > 1
""")
if rule_conflicts:
    print("  rule PK 冲突:", rule_conflicts[:10])
    fail(f"rule PK 冲突 {len(rule_conflicts)} 个")
print("  ✅ rule PK 冲突: 0")

# ── Step 2 质量检查 ───────────────────────────────────────────
section("Step 2 质量检查")
for r in q(f"SELECT l1_code, COUNT(*) AS n FROM test_dim.dim_l3_classify_{L1} GROUP BY 1"):
    print(f"  l1_code={r['l1_code']!r}  n={r['n']}")
    if r["l1_code"] != L1:
        fail("taxonomy l1_code 不纯")

bad_l3 = q(f"""
    SELECT l3_id, l2_code, l3_code FROM test_dim.dim_l3_classify_{L1}
    WHERE l3_id NOT REGEXP '^[0-9]{{6}}$'
       OR LEFT(l3_id, 2) <> '{L1_PREFIX}'
       OR l2_code REGEXP '_base$'
       OR l2_code NOT REGEXP '^[a-z0-9]+(_[a-z0-9]+)*$'
       OR l3_code NOT REGEXP '^[a-z0-9]+(_[a-z0-9]+)*$'
    LIMIT 10
""")
if bad_l3:
    print("  bad taxonomy:", bad_l3)
    fail("taxonomy 命名/l3_id 不合规")

bad_rule = q(f"""
    SELECT rule_id, COUNT(*) AS n FROM test_dim.dim_l3_classify_rule_{L1}
    WHERE rule_id NOT REGEXP '^{L1}_' AND rule_id NOT REGEXP '^gate_{L1}_'
    GROUP BY 1 LIMIT 10
""")
if bad_rule:
    print("  bad rule_id:", bad_rule)
    fail("rule_id 前缀不合规")

gates = q(f"""
    SELECT data_source, COUNT(*) AS gate_rows FROM test_dim.dim_l3_classify_rule_{L1}
    WHERE enabled = 1 AND rule_kind = 'gate' GROUP BY 1
""")
print("  gate 规则:", gates)
if len(gates) < 2:
    fail("gate 规则不足（需 icpdf + digikey）")
print("  ✅ 质量检查通过")

# ── Step 3 只读替换范围 ───────────────────────────────────────
section("Step 3 prod 替换范围（只读）")
prod_tax = q1(f"""
    SELECT COUNT(*) AS n FROM dim.dim_l3_classify
    WHERE l1_code IN ('{L1}', 'mcu', 'mpu', 'dsp')
""")["n"]
prod_rule = q1(f"""
    SELECT COUNT(*) AS n FROM dim.dim_l3_classify_rule r
    LEFT JOIN dim.dim_l3_classify d ON d.l3_id=r.l3_id AND d.schema_version=r.schema_version
    WHERE d.l1_code IN ('{L1}', 'mcu', 'mpu', 'dsp')
       OR r.rule_id REGEXP '^{L1}_' OR r.rule_id REGEXP '^gate_{L1}_'
       OR r.rule_id REGEXP '^mcu_' OR r.rule_id REGEXP '^mpu_' OR r.rule_id REGEXP '^dsp_'
""")["n"]
new_tax = q1(f"SELECT COUNT(*) AS n FROM test_dim.dim_l3_classify_{L1}")["n"]
new_rule = q1(f"SELECT COUNT(*) AS n FROM test_dim.dim_l3_classify_rule_{L1}")["n"]
print(f"  prod 旧 taxonomy 将删除: {prod_tax}")
print(f"  prod 旧 rule 将删除:     {prod_rule}")
print(f"  test 新 taxonomy 将写入: {new_tax}")
print(f"  test 新 rule 将写入:     {new_rule}")

baseline_raw = q(f"""
    SELECT data_source, COUNT(*) AS n FROM test_dwd.dwd_component_class_{L1}
    WHERE l1_code='{L1}' GROUP BY 1 ORDER BY 1
""")
baseline = sum_by_ds(baseline_raw)
print("  阶段1基线 dwd_component_class_mcu_mpu_dsp:")
for ds, n in sorted(baseline.items()):
    print(f"    {ds}: {n:,}")

if os.environ.get("ALLOW_PROD") != "1":
    print("\n⚠️  预检完成。设置 ALLOW_PROD=1 后重跑以执行 prod dim 替换 + DWD 重建。")
    conn.close()
    sys.exit(0)

# ── Step 4 prod dim 替换 ──────────────────────────────────────
if os.environ.get("SKIP_DIM_REPLACE") == "1":
    print("\n  (SKIP_DIM_REPLACE=1，跳过 Step 4)")
else:
    section(f"Step 4 prod dim 替换 (tag={MERGE_TAG})")
    bak_c = f"dim.bak_dim_l3_classify_{L1}_{MERGE_TAG}"
    bak_r = f"dim.bak_dim_l3_classify_rule_{L1}_{MERGE_TAG}"
    cur.execute(f"DROP TABLE IF EXISTS {bak_c}")
    cur.execute(f"CREATE TABLE {bak_c} AS SELECT * FROM dim.dim_l3_classify WHERE l1_code IN ('{L1}','mcu','mpu','dsp')")
    cur.execute(f"DROP TABLE IF EXISTS {bak_r}")
    cur.execute(f"""
        CREATE TABLE {bak_r} AS
        SELECT r.* FROM dim.dim_l3_classify_rule r
        LEFT JOIN dim.dim_l3_classify d ON d.l3_id=r.l3_id AND d.schema_version=r.schema_version
        WHERE d.l1_code IN ('{L1}','mcu','mpu','dsp')
           OR r.rule_id REGEXP '^{L1}_' OR r.rule_id REGEXP '^gate_{L1}_'
           OR r.rule_id REGEXP '^mcu_' OR r.rule_id REGEXP '^mpu_' OR r.rule_id REGEXP '^dsp_'
    """)
    print(f"  ✅ 备份 {bak_c}")
    print(f"  ✅ 备份 {bak_r}")
    cur.execute(f"""
        DELETE FROM dim.dim_l3_classify_rule
        WHERE rule_id REGEXP '^{L1}_' OR rule_id REGEXP '^gate_{L1}_'
           OR rule_id REGEXP '^mcu_' OR rule_id REGEXP '^mpu_' OR rule_id REGEXP '^dsp_'
           OR l3_id IN (
                SELECT l3_id FROM dim.dim_l3_classify
                WHERE l1_code IN ('{L1}','mcu','mpu','dsp')
           )
    """)
    cur.execute(f"DELETE FROM dim.dim_l3_classify WHERE l1_code IN ('{L1}','mcu','mpu','dsp')")
    cur.execute(f"INSERT INTO dim.dim_l3_classify SELECT * FROM test_dim.dim_l3_classify_{L1}")
    cur.execute(f"INSERT INTO dim.dim_l3_classify_rule SELECT * FROM test_dim.dim_l3_classify_rule_{L1}")
    print("  ✅ prod dim 替换完成")

# ── Step 5 test_dwd 验证 ──────────────────────────────────────
section("Step 5 test_dwd 验证")
merge_tbl = f"test_dwd.dwd_component_class_merge_{L1}"
cur.execute(f"DROP TABLE IF EXISTS {merge_tbl}")
build_sql = (HERE.parents[1] / "1.classify" / "dwd_component_class.sql").read_text(encoding="utf-8")
build_sql = build_sql.replace("dwd.dwd_component_class", merge_tbl)
exec_sql_file(build_sql, "merge 验证表")

merge_map = sum_by_ds(q(f"""
    SELECT data_source, COUNT(*) AS n FROM {merge_tbl}
    WHERE l1_code='{L1}' GROUP BY 1 ORDER BY 1
"""))
print("  merge 表行数:")
for ds, n in sorted(merge_map.items()):
    print(f"    {ds}: {n:,}")
print("  基线对比:")
for ds in sorted(set(baseline) | set(merge_map)):
    b, m = baseline.get(ds, 0), merge_map.get(ds, 0)
    diff = m - b
    flag = "✅" if abs(diff) <= max(5, b * 0.005) else "❌"
    print(f"    {flag} {ds}: merge={m:,} baseline={b:,} diff={diff:+,}")
    if flag == "❌":
        fail(f"merge 与基线偏差过大: {ds}")

# ── Step 6 prod DWD 重建 ──────────────────────────────────────
section("Step 6 prod DWD 重建")
prod_build = (HERE.parents[1] / "1.classify" / "dwd_component_class.sql").read_text(encoding="utf-8")
exec_sql_file(prod_build, "prod dwd_component_class")

# ── Step 7 验收 ───────────────────────────────────────────────
section("Step 7 prod 验收")
prod_map = sum_by_ds(q(f"""
    SELECT data_source, COUNT(*) AS n FROM dwd.dwd_component_class
    WHERE l1_code='{L1}' GROUP BY 1 ORDER BY 1
"""))
print("  prod dwd mcu_mpu_dsp:")
for ds, n in sorted(prod_map.items()):
    print(f"    {ds}: {n:,}")

all_l1 = q("""
    SELECT data_source, l1_code, COUNT(*) AS n FROM dwd.dwd_component_class
    GROUP BY 1, 2 ORDER BY 1, 2
""")
print(f"\n  prod 全 L1 行数 ({len(all_l1)} 组)")

conn.close()
bak_note = f"dim.bak_dim_l3_classify_{L1}_{MERGE_TAG}" if os.environ.get("SKIP_DIM_REPLACE") != "1" else "(Step4 已跳过)"
print(f"\n✅ 分类合并完成。备份表: {bak_note}")
