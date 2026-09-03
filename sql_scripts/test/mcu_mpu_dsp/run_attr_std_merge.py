"""
mcu_mpu_dsp 属性标准化合并（dim-attr-std-merge skill）
预检 + seed 更新 + test 验证 + prod dim 替换 + EAV/L2 重建（需 ALLOW_PROD=1）
"""
import os, re, sys, subprocess
from pathlib import Path
from datetime import datetime
sys.stdout.reconfigure(encoding="utf-8")

L1 = "mcu_mpu_dsp"
OLD_L1 = ("mcu", "mpu", "dsp")
MERGE_TAG = datetime.now().strftime("%Y%m%d%H%M")
L2_SFX = ("mcu_mpu_dsp_mcu", "mcu_mpu_dsp_mpu_soc", "mcu_mpu_dsp_dsp")
ATTR_SUBDIR = "19_mcu_mpu_dsp_ready"

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
ATTR = ROOT / "2.attribute_standard"
ENV = ROOT / "local.env"

for line in ENV.read_text(encoding="utf-8").splitlines():
    if line.strip().startswith("export "):
        k, _, v = line[7:].partition("=")
        os.environ[k] = v.strip().strip("'").strip('"')

import pymysql
conn = pymysql.connect(
    host=os.environ["MYSQL_HOST"], port=int(os.environ.get("MYSQL_PORT", "9030")),
    user=os.environ["MYSQL_USER"], password=os.environ["MYSQL_PASSWORD"],
    charset="utf8mb4", autocommit=True, cursorclass=pymysql.cursors.DictCursor,
)
cur = conn.cursor()

def q(sql):
    cur.execute(sql)
    return cur.fetchall()

def q1(sql):
    rows = q(sql)
    return rows[0] if rows else {}

def sum_by_ds(rows, ds_key="data_source", n_key="n"):
    from collections import defaultdict
    d = defaultdict(int)
    for r in rows:
        d[r[ds_key]] += int(r.get(n_key) or 0)
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

PROD_DWD_READ = (
    "dwd.dwd_icpdf_component_param",
    "dwd.dwd_digikey_component_param",
    "dwd.dwd_component_class",
)

def render(sql: str, dwd_db: str, dim_db: str) -> str:
    if dwd_db == "dwd":
        return sql.replace("dim.", f"{dim_db}.")
    placeholders = {}
    for i, tok in enumerate(PROD_DWD_READ):
        ph = f"__PROD_DWD_{i}__"
        placeholders[ph] = tok
        sql = sql.replace(tok, ph)
    sql = sql.replace("dwd.", f"{dwd_db}.").replace("dim.", f"{dim_db}.")
    sql = sql.replace(f"{dim_db}.v_std_brand_alias", "dim.v_std_brand_alias")
    for ph, tok in placeholders.items():
        sql = sql.replace(ph, tok)
    return sql

def section(title):
    print(f"\n{'='*66}\n  {title}\n{'='*66}")

def fail(msg):
    print(f"\n❌ STOP: {msg}")
    sys.exit(1)

def count_table(tbl, where=""):
    w = f" WHERE {where}" if where else ""
    return int(q1(f"SELECT COUNT(*) AS n FROM {tbl}{w}")["n"])

def brand_gate(tbl):
    r = q1(f"""
        SELECT COUNT(*) total,
               SUM(CASE WHEN brand IS NULL THEN 1 ELSE 0 END) brand_null,
               COUNT(DISTINCT brand) dt, COUNT(DISTINCT brandid) di,
               SUM(CASE WHEN brandid IS NULL AND brand IS NOT NULL THEN 1 ELSE 0 END) null_id_rows,
               COUNT(DISTINCT CASE WHEN brandid IS NULL AND brand IS NOT NULL AND TRIM(brand) <> ''
                    THEN brand END) null_brands
        FROM {tbl}
    """)
    return r

def brand_ok(bg) -> bool:
    if bg["brand_null"]:
        return False
    if bg["dt"] == bg["di"]:
        return True
    # 无 brandid 的品牌计入 dt 但不计入 di
    gap = int(bg["dt"]) - int(bg["di"])
    return gap == int(bg.get("null_brands") or 0)

# ── Step 0 阶段1检查 ──────────────────────────────────────────
section("Step 0 阶段1 后缀表检查")
for tbl in (
    f"test_dim.dim_attr_schema_{L1}",
    f"test_dim.dim_attr_extract_rule_{L1}",
    f"test_dwd.dwd_component_attr_std_{L1}",
):
    db, name = tbl.split(".", 1)
    cur.execute(f"SHOW TABLES FROM {db} LIKE %s", (name,))
    if not cur.fetchone():
        fail(f"缺少 {tbl}")
    print(f"  ✅ {tbl}: {count_table(tbl):,}")

for sfx in L2_SFX:
    tbl = f"test_dwd.dwd_l2_{sfx}"
    cur.execute("SHOW TABLES FROM test_dwd LIKE %s", (f"dwd_l2_{sfx}",))
    if not cur.fetchone():
        fail(f"缺少 {tbl}")
    print(f"  ✅ {tbl}: {count_table(tbl):,}（brand 门控在 Step 4 重跑后验收）")

class_n = sum_by_ds(q(f"SELECT data_source, COUNT(*) n FROM dwd.dwd_component_class WHERE l1_code='{L1}' GROUP BY 1"))
print(f"  prod 分类行数: {class_n}")
if sum(class_n.values()) < 1000:
    fail("prod 分类行数异常，请先完成 dim-l3-classify-merge")

# ── Step 1 PK 冲突 ────────────────────────────────────────────
section("Step 1 PK 冲突预检")
schema_pk = q1(f"""
    SELECT COUNT(*) c FROM (
      SELECT schema_version,l1_code,scope_level,scope_code,std_attr_code,COUNT(*) n FROM (
        SELECT schema_version,l1_code,scope_level,scope_code,std_attr_code FROM dim.dim_attr_schema
        UNION ALL SELECT schema_version,l1_code,scope_level,scope_code,std_attr_code
          FROM test_dim.dim_attr_schema_{L1}
      ) u GROUP BY 1,2,3,4,5 HAVING COUNT(*)>1
    ) x
""")["c"]
rule_pk = q1(f"""
    SELECT COUNT(*) c FROM (
      SELECT extract_rule_id, COUNT(*) n FROM (
        SELECT extract_rule_id FROM dim.dim_attr_extract_rule
        UNION ALL SELECT extract_rule_id FROM test_dim.dim_attr_extract_rule_{L1}
      ) u GROUP BY 1 HAVING COUNT(*)>1
    ) x
""")["c"]
print(f"  {'✅' if schema_pk==0 else '❌'} schema PK冲突: {schema_pk}")
print(f"  {'✅' if rule_pk==0 else '❌'} extract_rule PK冲突: {rule_pk}")
if schema_pk or rule_pk:
    fail("PK 冲突，需回阶段1 加前缀")

# ── Step 2 seed CSV ─────────────────────────────────────────────
section("Step 2 更新 seed CSV")
subprocess.run([sys.executable, str(HERE / "dump_attr_to_seed.py")], check=True)

# ── Step 3 test_dim 装载 ────────────────────────────────────────
section("Step 3 test_dim 装载（data-only）")
subprocess.run(
    [sys.executable, str(ATTR / "load_seed.py"), "--db", "test_dim", "--data-only"],
    check=True, env=os.environ.copy(),
)

baseline = {
    "eav": count_table(f"test_dwd.dwd_component_attr_std_{L1}"),
    "l2": {sfx: count_table(f"test_dwd.dwd_l2_{sfx}") for sfx in L2_SFX},
}
print(f"  阶段1基线 EAV: {baseline['eav']:,}")
for sfx, n in baseline["l2"].items():
    print(f"    L2 {sfx}: {n:,}")

def run_attr_pipeline(dwd_db: str, dim_db: str, label: str):
    for src in ("icpdf", "digikey"):
        build = (ATTR / f"build_dwd_component_attr_std_{src}.sql").read_text(encoding="utf-8")
        exec_sql_file(render(build, dwd_db, dim_db), f"{label} EAV {src}")
    base = ATTR / ATTR_SUBDIR
    for sfx in L2_SFX:
        ddl = (base / f"dwd_l2_{sfx}.sql").read_text(encoding="utf-8")
        exec_sql_file(render(ddl, dwd_db, dim_db), f"{label} DDL {sfx}")
        build = (base / f"build_dwd_l2_{sfx}.sql").read_text(encoding="utf-8")
        exec_sql_file(render(build, dwd_db, dim_db), f"{label} build {sfx}")

# ── Step 4 test_dwd 验证 ────────────────────────────────────────
if os.environ.get("SKIP_TEST_VALIDATION") == "1":
    print("\n  (SKIP_TEST_VALIDATION=1，跳过 Step 4)")
else:
    section("Step 4 test_dwd 全链路验证")
    run_attr_pipeline("test_dwd", "test_dim", "test")

if os.environ.get("SKIP_TEST_VALIDATION") != "1":
    test_eav = count_table(
        "test_dwd.dwd_component_attr_std e JOIN dwd.dwd_component_class c "
        "ON c.data_source=e.data_source AND c.id=e.id",
        f"c.l1_code='{L1}'",
    )
    print(f"  test EAV (mcu_mpu_dsp): {test_eav:,}")
    eav_diff = test_eav - baseline["eav"]
    flag = "✅" if abs(eav_diff) <= max(5000, baseline["eav"] * 0.05) else "❌"
    print(f"  {flag} EAV diff={eav_diff:+,} (baseline {baseline['eav']:,})")
    if flag == "❌":
        fail("test EAV 与基线偏差过大")

    for sfx in L2_SFX:
        tbl = f"test_dwd.dwd_l2_{sfx}"
        n = count_table(tbl)
        b = baseline["l2"][sfx]
        diff = n - b
        flag = "✅" if abs(diff) <= max(50, b * 0.01) else "❌"
        bg = brand_gate(tbl)
        print(f"  {flag} {sfx}: n={n:,} baseline={b:,} diff={diff:+,} brand_null={bg['brand_null']} dt={bg['dt']} di={bg['di']}")
        bok = brand_ok(bg)
        print(f"       brand_gate={'✅' if bok else '❌'} null_brands={bg.get('null_brands', 0)}")
        if flag == "❌" or not bok:
            fail(f"test L2 验收失败: {sfx}")

if os.environ.get("ALLOW_PROD") != "1":
    print("\n⚠️  预检+test 验证完成。设置 ALLOW_PROD=1 后重跑以执行 prod dim 替换 + EAV/L2 重建。")
    conn.close()
    sys.exit(0)

# ── Step 5 prod dim 替换 ──────────────────────────────────────
if os.environ.get("SKIP_DIM_REPLACE") == "1":
    print("\n  (SKIP_DIM_REPLACE=1，跳过 Step 5)")
else:
    section(f"Step 5 prod dim 替换 (tag={MERGE_TAG})")
    bak_s = f"dim.bak_dim_attr_schema_{L1}_{MERGE_TAG}"
    bak_r = f"dim.bak_dim_attr_extract_rule_{L1}_{MERGE_TAG}"
    old_l1 = ",".join(f"'{x}'" for x in OLD_L1)
    cur.execute(f"DROP TABLE IF EXISTS {bak_s}")
    cur.execute(f"CREATE TABLE {bak_s} AS SELECT * FROM dim.dim_attr_schema WHERE l1_code IN ({old_l1},'{L1}')")
    cur.execute(f"DROP TABLE IF EXISTS {bak_r}")
    cur.execute(f"CREATE TABLE {bak_r} AS SELECT * FROM dim.dim_attr_extract_rule WHERE l1_code IN ({old_l1},'{L1}')")
    print(f"  ✅ 备份 {bak_s} / {bak_r}")
    cur.execute(f"DELETE FROM dim.dim_attr_extract_rule WHERE l1_code IN ({old_l1})")
    cur.execute(f"DELETE FROM dim.dim_attr_schema WHERE l1_code IN ({old_l1})")
    cur.execute(f"INSERT INTO dim.dim_attr_schema SELECT * FROM test_dim.dim_attr_schema_{L1}")
    cur.execute(f"INSERT INTO dim.dim_attr_extract_rule SELECT * FROM test_dim.dim_attr_extract_rule_{L1}")
    print("  ✅ prod dim 属性规则已替换")

# ── Step 6 prod EAV + L2 ──────────────────────────────────────
section("Step 6 prod EAV + L2 重建")
run_attr_pipeline("dwd", "dim", "prod")

# ── Step 7 prod 验收 ──────────────────────────────────────────
section("Step 7 prod 验收")
prod_eav = count_table("dwd.dwd_component_attr_std e JOIN dwd.dwd_component_class c "
                       "ON c.data_source=e.data_source AND c.id=e.id",
                       f"c.l1_code='{L1}'")
print(f"  prod EAV (mcu_mpu_dsp): {prod_eav:,}")
for sfx in L2_SFX:
    tbl = f"dwd.dwd_l2_{sfx}"
    n = count_table(tbl)
    bg = brand_gate(tbl)
    by_ds = sum_by_ds(q(f"SELECT data_source, COUNT(*) n FROM {tbl} GROUP BY 1"))
    print(f"  {sfx}: n={n:,} by_ds={by_ds} brand_null={bg['brand_null']} dt={bg['dt']} di={bg['di']}")

conn.close()
print(f"\n✅ 属性标准化合并完成。")
