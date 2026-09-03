"""
inductor 属性合并（dim-attr-std-merge skill）

预检：python run_attr_merge.py
prod：  python run_attr_merge.py --allow-prod
"""
from __future__ import annotations

import argparse
import os
import re
import sys
from collections import defaultdict
from datetime import datetime
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")

L1 = "inductor"
L2S = ["power_inductor", "hf_chip_inductor", "emi_filter_inductor"]
MERGE_TAG_DEFAULT = datetime.now().strftime("%Y%m%d%H%M")

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
ENV = ROOT / "local.env"
ATTR_DIR = ROOT / "2.attribute_standard"
READY = ATTR_DIR / "12_inductor_ready"

for line in ENV.read_text(encoding="utf-8").splitlines():
    if line.strip().startswith("export "):
        k, _, v = line[7:].partition("=")
        os.environ[k] = v.strip().strip("'").strip('"')

import pymysql

parser = argparse.ArgumentParser()
parser.add_argument("--allow-prod", action="store_true")
parser.add_argument("--merge-tag", default=MERGE_TAG_DEFAULT)
parser.add_argument("--skip-dim-replace", action="store_true")
parser.add_argument("--skip-brand-sync", action="store_true")
parser.add_argument("--l2-only", action="store_true", help="仅重跑 3 张 L2 build（dim/EAV 已完成时）")
parser.add_argument("--eav-only", action="store_true", help="仅重跑 EAV icpdf+digikey")
args = parser.parse_args()

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
    r = q(sql)
    return r[0] if r else {}


def section(t):
    print(f"\n{'='*66}\n  {t}\n{'='*66}")


def fail(msg):
    print(f"\n❌ STOP: {msg}")
    sys.exit(1)


def sum_l2_brand(tbl: str) -> dict:
    cur.execute(f"""
        SELECT
          SUM(CASE WHEN brand IS NULL OR TRIM(brand)='' THEN 1 ELSE 0 END) AS brand_null,
          SUM(CASE WHEN brandid IS NULL THEN 1 ELSE 0 END) AS brand_no_id,
          COUNT(*) AS total,
          COUNT(DISTINCT brand) AS db, COUNT(DISTINCT brandid) AS di
        FROM {tbl}
    """)
    return cur.fetchone()


def split_stmts(sql: str) -> list[str]:
    parts, buf = [], []
    for line in sql.splitlines():
        no = re.sub(r"^\s*--.*$", "", line)
        buf.append(line)
        if no.rstrip().endswith(";"):
            stmt = "\n".join(buf).strip()
            stmt = re.sub(r"/\*.*?\*/", "", stmt, flags=re.DOTALL).rstrip().rstrip(";").strip()
            if stmt:
                parts.append(stmt)
            buf = []
    return parts


def exec_sql_text(sql_text: str, label: str):
    stmts = split_stmts(sql_text)
    print(f"  {label}: {len(stmts)} stmts")
    for i, stmt in enumerate(stmts, 1):
        cur.execute(stmt)


def run_attr_std_prod_inductor(eav_only=False, l2_only=False):
    """Windows 无 mysql CLI 时用 pymysql 跑 run_attr_std.sh prod 等价逻辑。"""
    if not l2_only:
        for src, build in (
            ("icpdf", "build_dwd_component_attr_std_icpdf.sql"),
            ("digikey", "build_dwd_component_attr_std_digikey.sql"),
        ):
            print(f"  EAV ← {src}")
            exec_sql_text((ATTR_DIR / build).read_text(encoding="utf-8-sig"), build)
    if eav_only:
        return
    for l2 in L2S:
        sfx = f"{L1}_{l2}"
        print(f"  L2 {sfx}")
        exec_sql_text((READY / f"dwd_l2_{sfx}.sql").read_text(encoding="utf-8-sig"), f"ddl {sfx}")
        exec_sql_text((READY / f"build_dwd_l2_{sfx}.sql").read_text(encoding="utf-8-sig"), f"build {sfx}")


def apply_unit_factor_prod():
    p = HERE.parents[1] / "test" / "unit_supplement" / "dim_unit_factor_inductor_supplement.sql"
    if not p.exists():
        print("  (skip unit_factor supplement, file missing)")
        return
    text = p.read_text(encoding="utf-8").replace("test_dim.dim_unit_factor", "dim.dim_unit_factor")
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.DOTALL)
    if "INSERT" not in text.upper():
        return
    cur.execute(text.strip().rstrip(";"))
    print("  unit_factor supplement: kOhms → ohm")


def apply_brand_supplement_prod():
    p = HERE.parents[1] / "test" / "brand_supplement" / "dim_std_brand_supplement_inductor_relay.sql"
    if not p.exists():
        fail("brand supplement SQL 缺失")
    text = p.read_text(encoding="utf-8")
    text = re.sub(r"\s*UNION ALL SELECT brand FROM test_dwd\.dwd_l2_relay[^\n]+", "", text)
    text = text.replace("test_dim.", "dim.")
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.DOTALL)
    stmts = [s.strip() for s in text.split(";") if s.strip() and "INSERT" in s.upper()]
    print(f"  brand supplement (inductor only): {len(stmts)} INSERT")
    for stmt in stmts:
        cur.execute(stmt)


def main():
    print(f"ALLOW_PROD: {args.allow_prod}  MERGE_TAG: {args.merge_tag}")

    section("0. 阶段1 后缀表")
    for tbl in (
        f"test_dim.dim_attr_schema_{L1}",
        f"test_dim.dim_attr_extract_rule_{L1}",
        f"test_dwd.dwd_component_attr_std_{L1}",
    ):
        try:
            n = q1(f"SELECT COUNT(*) AS n FROM {tbl}")["n"]
            print(f"  ✅ {tbl}: {n:,}")
        except Exception as e:
            fail(f"{tbl}: {e}")

    for l2 in L2S:
        tbl = f"test_dwd.dwd_l2_{L1}_{l2}_{L1}"
        try:
            n = q1(f"SELECT COUNT(*) AS n FROM {tbl}")["n"]
            b = sum_l2_brand(tbl)
            print(f"  ⚠️  {tbl}: rows={n:,} brand_null={b['brand_null']} (stage1, prod build 已过滤空 brandshort)")
        except Exception as e:
            fail(f"{tbl}: {e}")

    if not READY.is_dir():
        fail(f"缺少 {READY}")
    for l2 in L2S:
        for kind in ("dwd_l2", "build_dwd_l2"):
            f = READY / f"{kind}_{L1}_{l2}.sql"
            if not f.exists():
                fail(f"缺少入仓脚本 {f}")

    section("Step 1 PK 预检")
    if q1(f"""
        SELECT COUNT(*) AS n FROM (
          SELECT schema_version,l1_code,scope_level,scope_code,std_attr_code,COUNT(*) c FROM (
            SELECT schema_version,l1_code,scope_level,scope_code,std_attr_code
            FROM dim.dim_attr_schema WHERE l1_code<>'{L1}'
            UNION ALL SELECT schema_version,l1_code,scope_level,scope_code,std_attr_code
            FROM test_dim.dim_attr_schema_{L1}
          ) u GROUP BY 1,2,3,4,5 HAVING COUNT(*)>1
        ) x
    """)["n"]:
        fail("schema PK 冲突")
    if q1(f"""
        SELECT COUNT(*) AS n FROM (
          SELECT extract_rule_id,COUNT(*) c FROM (
            SELECT extract_rule_id FROM dim.dim_attr_extract_rule
            WHERE l1_code<>'{L1}' AND extract_rule_id NOT REGEXP '^{L1}_'
            UNION ALL SELECT extract_rule_id FROM test_dim.dim_attr_extract_rule_{L1}
          ) u GROUP BY 1 HAVING COUNT(*)>1
        ) x
    """)["n"]:
        fail("extract_rule PK 冲突")
    print("  ✅ PK 无冲突")

    section("Step 2 质量检查")
    bad = q(f"""
        SELECT extract_rule_id FROM test_dim.dim_attr_extract_rule_{L1}
        WHERE extract_rule_id NOT REGEXP '^{L1}_' LIMIT 5
    """)
    if bad:
        fail(f"extract_rule_id 前缀不合规: {bad}")
    orphan = q1(f"""
        SELECT COUNT(DISTINCT r.std_attr_code) AS n
        FROM test_dim.dim_attr_extract_rule_{L1} r
        LEFT JOIN test_dim.dim_attr_schema_{L1} s
          ON s.schema_version=r.schema_version AND s.l1_code='{L1}' AND s.std_attr_code=r.std_attr_code
        WHERE s.std_attr_code IS NULL
    """)["n"]
    if orphan:
        fail(f"orphan extract_rule: {orphan}")
    print("  ✅ 质量检查通过")

    section("Step 3 prod 替换范围")
    prod_s = q1(f"SELECT COUNT(*) AS n FROM dim.dim_attr_schema WHERE l1_code='{L1}'")["n"]
    prod_r = q1(f"""
        SELECT COUNT(*) AS n FROM dim.dim_attr_extract_rule
        WHERE l1_code='{L1}' OR extract_rule_id REGEXP '^{L1}_'
    """)["n"]
    new_s = q1(f"SELECT COUNT(*) AS n FROM test_dim.dim_attr_schema_{L1}")["n"]
    new_r = q1(f"SELECT COUNT(*) AS n FROM test_dim.dim_attr_extract_rule_{L1}")["n"]
    print(f"  schema: prod {prod_s} → test {new_s}")
    print(f"  rule:   prod {prod_r} → test {new_r}  (prod 旧规则无 inductor_ 前缀)")

    cls = defaultdict(int)
    cur.execute(f"SELECT data_source, COUNT(*) n FROM dwd.dwd_component_class WHERE l1_code='{L1}' GROUP BY 1")
    for r in cur.fetchall():
        cls[r["data_source"]] += int(r["n"])
    print(f"  classify 前置: {dict(cls)}")

    if not args.allow_prod:
        print("\n⚠️  预检完成。确认后: python run_attr_merge.py --allow-prod")
        return

    if args.l2_only or args.eav_only:
        section("Step 7 prod EAV/L2 续跑")
        run_attr_std_prod_inductor(eav_only=args.eav_only, l2_only=args.l2_only)
    else:
        if not args.skip_brand_sync:
            section("Step 4b brand + unit_factor prod")
            apply_brand_supplement_prod()
            apply_unit_factor_prod()
            print("  ✅ brand supplement + unit_factor 已写入 prod dim")

        if not args.skip_dim_replace:
            section(f"Step 5 prod dim 替换 (tag={args.merge_tag})")
            tag = args.merge_tag
            cur.execute(f"CREATE TABLE IF NOT EXISTS dim.bak_dim_attr_schema_{L1}_{tag} LIKE dim.dim_attr_schema")
            cur.execute(f"CREATE TABLE IF NOT EXISTS dim.bak_dim_attr_extract_rule_{L1}_{tag} LIKE dim.dim_attr_extract_rule")
            cur.execute(f"INSERT INTO dim.bak_dim_attr_schema_{L1}_{tag} SELECT * FROM dim.dim_attr_schema WHERE l1_code='{L1}'")
            cur.execute(f"""
                INSERT INTO dim.bak_dim_attr_extract_rule_{L1}_{tag}
                SELECT * FROM dim.dim_attr_extract_rule
                WHERE l1_code='{L1}' OR extract_rule_id REGEXP '^{L1}_'
            """)
            cur.execute(f"DELETE FROM dim.dim_attr_extract_rule WHERE l1_code='{L1}' OR extract_rule_id REGEXP '^{L1}_'")
            cur.execute(f"DELETE FROM dim.dim_attr_schema WHERE l1_code='{L1}'")
            cur.execute(f"INSERT INTO dim.dim_attr_schema SELECT * FROM test_dim.dim_attr_schema_{L1}")
            cur.execute(f"INSERT INTO dim.dim_attr_extract_rule SELECT * FROM test_dim.dim_attr_extract_rule_{L1}")
            got_r = q1(f"SELECT COUNT(*) AS n FROM dim.dim_attr_extract_rule WHERE extract_rule_id REGEXP '^{L1}_'")["n"]
            print(f"  ✅ dim 替换完成 extract_rule={got_r} (期望 {new_r})")
            if got_r != new_r:
                fail("extract_rule 行数不符")

        section("Step 7 prod EAV + L2 重跑")
        run_attr_std_prod_inductor()

    section("Step 8 prod 验收")
    for l2 in L2S:
        tbl = f"dwd.dwd_l2_{L1}_{l2}"
        cur.execute(f"SELECT data_source, COUNT(*) n FROM {tbl} GROUP BY 1")
        d = defaultdict(int)
        for row in cur.fetchall():
            d[row["data_source"]] += int(row["n"])
        b = sum_l2_brand(tbl)
        print(f"  {tbl}: by_ds={dict(d)} brand_null={b['brand_null']} brand_no_id={b['brand_no_id']} db={b['db']} di={b['di']}")
        if b["brand_null"] or b["brand_no_id"]:
            fail(f"{tbl} 品牌门控未通过")
        if b["db"] != b["di"]:
            print(f"    ⚠️  distinct_brand != distinct_brandid ({b['db']} vs {b['di']})")

    print(f"\n✅ inductor attr merge 完成。备份 tag={args.merge_tag}")


if __name__ == "__main__":
    try:
        main()
    finally:
        conn.close()
