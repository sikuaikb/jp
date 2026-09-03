"""
inductor 分类合并（dim-l3-classify-merge skill）

默认：Step 0-3 只读预检
  python run_classify_merge.py

补齐 test taxonomy 缺失节点（可选）：
  python run_classify_merge.py --fix-test

执行 prod 合并 Step 4-7（必须显式传 --allow-prod）：
  python run_classify_merge.py --allow-prod
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
L1_PREFIX = "12"

HERE = Path(__file__).resolve().parent
ENV = HERE.parents[1] / "local.env"
for line in ENV.read_text(encoding="utf-8").splitlines():
    if line.strip().startswith("export "):
        k, _, v = line[7:].partition("=")
        os.environ[k] = v.strip().strip("'").strip('"')

import pymysql

parser = argparse.ArgumentParser(description="inductor dim-l3-classify-merge")
parser.add_argument("--allow-prod", action="store_true", help="执行 Step 4-7 写 prod")
parser.add_argument("--fix-test", action="store_true", help="从 prod 补齐 test taxonomy 缺失 excluded 节点")
parser.add_argument("--skip-dim-replace", action="store_true", help="跳过 Step 4，仅跑 Step 5-7")
parser.add_argument("--accept-icpdf-drift", action="store_true",
                    help="icpdf 基线与主干引擎不一致时仍继续（阶段1 曾用旧 build 脚本）")
parser.add_argument("--merge-tag", default=datetime.now().strftime("%Y%m%d%H%M"), help="备份表后缀")
args = parser.parse_args()
MERGE_TAG = args.merge_tag

conn = pymysql.connect(
    host=os.environ["MYSQL_HOST"],
    port=int(os.environ.get("MYSQL_PORT", "9030")),
    user=os.environ["MYSQL_USER"],
    password=os.environ["MYSQL_PASSWORD"],
    charset="utf8mb4",
    autocommit=True,
    cursorclass=pymysql.cursors.DictCursor,
)
cur = conn.cursor()


def q(sql: str):
    cur.execute(sql)
    return cur.fetchall()


def q1(sql: str):
    rows = q(sql)
    return rows[0] if rows else {}


def sum_by_ds(rows, key: str = "n") -> dict[str, int]:
    d: dict[str, int] = defaultdict(int)
    for r in rows:
        d[str(r["data_source"])] += int(r.get(key) or 0)
    return dict(d)


def count_l1_by_ds(table: str, l1: str = L1) -> dict[str, int]:
    """StarRocks 分片下 GROUP BY data_source 可能多行，这里汇总。"""
    return sum_by_ds(
        q(f"""
        SELECT data_source, COUNT(*) AS n FROM {table}
        WHERE l1_code = '{l1}'
        GROUP BY data_source
        ORDER BY data_source
        """)
    )


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


def section(title: str):
    print(f"\n{'=' * 66}\n  {title}\n{'=' * 66}")


def fail(msg: str):
    print(f"\n❌ STOP: {msg}")
    sys.exit(1)


def report_missing_taxonomy() -> list[str]:
    rows = q(f"""
        SELECT p.l3_id FROM dim.dim_l3_classify p
        WHERE p.l1_code = '{L1}'
          AND p.l3_id NOT IN (SELECT l3_id FROM test_dim.dim_l3_classify_{L1})
    """)
    return [r["l3_id"] for r in rows]


def sync_missing_taxonomy() -> int:
    missing = report_missing_taxonomy()
    if not missing:
        return 0
    ids = ",".join(f"'{x}'" for x in missing)
    cur.execute(f"""
        INSERT INTO test_dim.dim_l3_classify_{L1}
        SELECT * FROM dim.dim_l3_classify
        WHERE l1_code = '{L1}' AND l3_id IN ({ids})
    """)
    print(f"  ✅ 补齐 taxonomy: {missing}")
    return len(missing)


def main():
    print(f"ALLOW_PROD (--allow-prod): {args.allow_prod}")
    print(f"MERGE_TAG: {MERGE_TAG}")

    section("0. 阶段1 后缀表检查")
    for tbl in (
        f"test_dim.dim_l3_classify_{L1}",
        f"test_dim.dim_l3_classify_rule_{L1}",
        f"test_dwd.dwd_component_class_{L1}",
    ):
        try:
            n = q1(f"SELECT COUNT(*) AS n FROM {tbl}")["n"]
            print(f"  ✅ {tbl}: {n:,} rows")
        except Exception as e:
            fail(f"{tbl} 不存在或不可读: {e}")

    missing_tax = report_missing_taxonomy()
    if missing_tax:
        print(f"  ⚠️  test taxonomy 缺节点: {missing_tax}")
        if args.fix_test:
            sync_missing_taxonomy()
        else:
            print("  如需补齐请加 --fix-test")

    n_tax = q1(f"SELECT COUNT(*) AS n FROM test_dim.dim_l3_classify_{L1}")["n"]
    print(f"  taxonomy 行数: {n_tax}")

    section("Step 1 PK 冲突预检")
    l3_conflicts = q(f"""
        SELECT l3_id, COUNT(*) AS cnt FROM (
            SELECT l3_id FROM dim.dim_l3_classify WHERE l1_code <> '{L1}'
            UNION ALL SELECT l3_id FROM test_dim.dim_l3_classify_{L1}
        ) u GROUP BY l3_id HAVING COUNT(*) > 1
    """)
    if l3_conflicts:
        fail(f"l3_id 冲突 {len(l3_conflicts)} 个: {l3_conflicts[:5]}")
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
        fail(f"rule PK 冲突 {len(rule_conflicts)} 个: {rule_conflicts[:5]}")
    print("  ✅ rule PK 冲突: 0")

    section("Step 2 质量检查")
    for r in q(f"SELECT l1_code, COUNT(*) AS n FROM test_dim.dim_l3_classify_{L1} GROUP BY 1"):
        if r["l1_code"] != L1:
            fail(f"taxonomy l1_code 不纯: {r}")

    bad_l3 = q(f"""
        SELECT l3_id, l2_code, l3_code FROM test_dim.dim_l3_classify_{L1}
        WHERE l3_id NOT REGEXP '^[0-9]{{6}}$'
           OR LEFT(l3_id, 2) <> '{L1_PREFIX}'
           OR l2_code REGEXP '_base$'
        LIMIT 5
    """)
    if bad_l3:
        fail(f"taxonomy 不合规: {bad_l3}")

    bad_rule = q(f"""
        SELECT rule_id FROM test_dim.dim_l3_classify_rule_{L1}
        WHERE rule_id NOT REGEXP '^{L1}_' AND rule_id NOT REGEXP '^gate_{L1}_'
        LIMIT 5
    """)
    if bad_rule:
        fail(f"rule_id 前缀不合规: {bad_rule}")

    gates = q(f"""
        SELECT data_source, COUNT(*) AS gate_rows FROM test_dim.dim_l3_classify_rule_{L1}
        WHERE enabled = 1 AND rule_kind = 'gate' GROUP BY 1
    """)
    print(f"  gate 规则: {gates}")
    if len(gates) < 2:
        fail("gate 规则不足（需 icpdf + digikey）")
    print("  ✅ 质量检查通过")

    section("Step 3 prod 替换范围（只读）")
    prod_tax = q1(f"SELECT COUNT(*) AS n FROM dim.dim_l3_classify WHERE l1_code = '{L1}'")["n"]
    prod_rule = q1(f"""
        SELECT COUNT(*) AS n FROM dim.dim_l3_classify_rule r
        LEFT JOIN dim.dim_l3_classify d ON d.l3_id = r.l3_id AND d.schema_version = r.schema_version
        WHERE d.l1_code = '{L1}'
           OR r.rule_id REGEXP '^{L1}_' OR r.rule_id REGEXP '^gate_{L1}_'
    """)["n"]
    new_tax = q1(f"SELECT COUNT(*) AS n FROM test_dim.dim_l3_classify_{L1}")["n"]
    new_rule = q1(f"SELECT COUNT(*) AS n FROM test_dim.dim_l3_classify_rule_{L1}")["n"]
    print(f"  prod 旧 taxonomy: {prod_tax}  →  test 新: {new_tax}")
    print(f"  prod 旧 rule:     {prod_rule}  →  test 新: {new_rule}")

    baseline = count_l1_by_ds(f"test_dwd.dwd_component_class_{L1}")
    print("  阶段1 基线:")
    for ds, n in sorted(baseline.items()):
        print(f"    {ds}: {n:,}")

    prod_inductor_before = count_l1_by_ds("dwd.dwd_component_class")
    print("  prod 当前 inductor:")
    for ds, n in sorted(prod_inductor_before.items()):
        print(f"    {ds}: {n:,}")
    if not prod_inductor_before:
        print("    (无 inductor 行)")

    if not args.allow_prod:
        print("\n⚠️  预检完成。确认后执行: python run_classify_merge.py --allow-prod")
        return

    if not args.skip_dim_replace:
        section(f"Step 4 prod dim 替换 (tag={MERGE_TAG})")
        bak_c = f"dim.bak_dim_l3_classify_{L1}_{MERGE_TAG}"
        bak_r = f"dim.bak_dim_l3_classify_rule_{L1}_{MERGE_TAG}"
        cur.execute(f"DROP TABLE IF EXISTS {bak_c}")
        cur.execute(f"CREATE TABLE {bak_c} AS SELECT * FROM dim.dim_l3_classify WHERE l1_code = '{L1}'")
        cur.execute(f"DROP TABLE IF EXISTS {bak_r}")
        cur.execute(f"""
            CREATE TABLE {bak_r} AS
            SELECT r.* FROM dim.dim_l3_classify_rule r
            LEFT JOIN dim.dim_l3_classify d ON d.l3_id = r.l3_id AND d.schema_version = r.schema_version
            WHERE d.l1_code = '{L1}'
               OR r.rule_id REGEXP '^{L1}_' OR r.rule_id REGEXP '^gate_{L1}_'
        """)
        print(f"  ✅ 备份 {bak_c} / {bak_r}")

        cur.execute(f"""
            DELETE FROM dim.dim_l3_classify_rule
            WHERE rule_id REGEXP '^{L1}_' OR rule_id REGEXP '^gate_{L1}_'
               OR l3_id IN (
                    SELECT l3_id FROM dim.dim_l3_classify WHERE l1_code = '{L1}'
               )
        """)
        cur.execute(f"DELETE FROM dim.dim_l3_classify WHERE l1_code = '{L1}'")
        cur.execute(f"INSERT INTO dim.dim_l3_classify SELECT * FROM test_dim.dim_l3_classify_{L1}")
        cur.execute(f"INSERT INTO dim.dim_l3_classify_rule SELECT * FROM test_dim.dim_l3_classify_rule_{L1}")

        after_rule = q1(f"""
            SELECT COUNT(*) AS n FROM dim.dim_l3_classify_rule
            WHERE rule_id REGEXP '^{L1}_' OR rule_id REGEXP '^gate_{L1}_'
        """)["n"]
        print(f"  ✅ prod dim 替换完成 (rule={after_rule}, 期望={new_rule})")
        if after_rule != new_rule:
            fail(f"prod rule 行数不符: {after_rule} != {new_rule}")
    else:
        print("\n  (SKIP dim replace)")

    section("Step 5 test_dwd 验证")
    merge_tbl = f"test_dwd.dwd_component_class_merge_{L1}"
    cur.execute(f"DROP TABLE IF EXISTS {merge_tbl}")
    build_sql = (HERE.parents[1] / "1.classify" / "dwd_component_class.sql").read_text(encoding="utf-8")
    build_sql = build_sql.replace("dwd.dwd_component_class", merge_tbl)
    # 确保 merge 表 l2_code 与 prod 一致（VARCHAR(64)），避免长 l2_code 被过滤
    build_sql = build_sql.replace(
        "`l2_code`           VARCHAR(32)",
        "`l2_code`           VARCHAR(64)",
    )
    exec_sql_file(build_sql, "merge 验证表")

    merge_map = count_l1_by_ds(merge_tbl)
    print("  merge 表:")
    for ds, n in sorted(merge_map.items()):
        print(f"    {ds}: {n:,}")
    for ds in sorted(set(baseline) | set(merge_map)):
        b, m = baseline.get(ds, 0), merge_map.get(ds, 0)
        diff = m - b
        tol = max(5, int(b * 0.005))
        ok = abs(diff) <= tol
        if ds == "icpdf" and not ok and args.accept_icpdf_drift:
            print(f"    ⚠️  {ds}: merge={m:,} baseline={b:,} diff={diff:+,} (已 --accept-icpdf-drift，主干引擎为准)")
            continue
        flag = "✅" if ok else "❌"
        print(f"    {flag} {ds}: merge={m:,} baseline={b:,} diff={diff:+,} (tol={tol})")
        if not ok:
            if ds == "icpdf":
                fail(
                    f"icpdf merge 与阶段1基线偏差 {diff:+,}。"
                    f" 阶段1后缀表可能由旧 build 脚本生成，与主干 dwd_component_class.sql 不一致。"
                    f" 排查后加 --accept-icpdf-drift 继续（以主干引擎为准）。"
                )
            fail(f"merge 与基线偏差过大: {ds}")

    section("Step 6 prod DWD 重建")
    prod_build = (HERE.parents[1] / "1.classify" / "dwd_component_class.sql").read_text(encoding="utf-8")
    exec_sql_file(prod_build, "prod dwd_component_class")

    section("Step 7 prod 验收")
    prod_map = count_l1_by_ds("dwd.dwd_component_class")
    print("  prod inductor:")
    for ds, n in sorted(prod_map.items()):
        print(f"    {ds}: {n:,}")
    for ds in sorted(set(baseline) | set(prod_map)):
        b, p = baseline.get(ds, 0), prod_map.get(ds, 0)
        diff = p - b
        tol = max(5, int(b * 0.005))
        ok = abs(diff) <= tol
        if ds == "icpdf" and not ok and args.accept_icpdf_drift:
            # prod 应与 merge 一致，不必再对比旧 icpdf 基线
            pm = merge_map.get(ds, p)
            if p == pm:
                print(f"    ✅ prod vs merge {ds}: {p:,} (icpdf 以 merge/prod 为准，旧基线 {b:,} 已弃用)")
            else:
                fail(f"prod {ds}={p:,} 与 merge {pm:,} 不一致")
            continue
        flag = "✅" if ok else "❌"
        print(f"    {flag} prod vs baseline {ds}: prod={p:,} baseline={b:,} diff={diff:+,}")
        if not ok:
            fail(f"prod 与基线偏差过大: {ds}")

    total = q1("SELECT COUNT(*) AS n FROM dwd.dwd_component_class")["n"]
    print(f"\n  prod dwd_component_class 总行数: {total:,}")
    bak_note = f"dim.bak_dim_l3_classify_{L1}_{MERGE_TAG}" if not args.skip_dim_replace else "(skip dim)"
    print(f"\n✅ inductor 分类合并完成。备份: {bak_note}")


if __name__ == "__main__":
    try:
        main()
    finally:
        conn.close()
