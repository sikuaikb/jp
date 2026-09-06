#!/usr/bin/env python3
"""
dim-attr-std-merge Step 6：test_dwd merge 表 vs 阶段1 后缀表 / prod

用法：
  python run_attr_merge_step6.py --rebuild   # 重建 merge 表并对比
  python run_attr_merge_step6.py             # 仅对比（merge 表已存在）
"""
from __future__ import annotations

import argparse
import os
import re
import sys
from collections import defaultdict
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")

L1 = "inductor"
L2S = ["power_inductor", "hf_chip_inductor", "emi_filter_inductor"]

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
ATTR = ROOT / "2.attribute_standard"
READY = ATTR / "12_inductor_ready"
ENV = ROOT / "local.env"

for line in ENV.read_text(encoding="utf-8").splitlines():
    if line.strip().startswith("export "):
        k, _, v = line[7:].partition("=")
        os.environ[k] = v.strip().strip("'\"")

import pymysql

parser = argparse.ArgumentParser()
parser.add_argument("--rebuild", action="store_true", help="重建 merge EAV + L2 表")
parser.add_argument("--tol-pct", type=float, default=0.005, help="阶段1 EAV 对比容差（默认 0.5%%）")
args = parser.parse_args()

MERGE_EAV = f"test_dwd.dwd_component_attr_std_merge_{L1}"

conn = pymysql.connect(
    host=os.environ["MYSQL_HOST"], port=int(os.environ["MYSQL_PORT"]),
    user=os.environ["MYSQL_USER"], password=os.environ["MYSQL_PASSWORD"],
    charset="utf8mb4", autocommit=True, cursorclass=pymysql.cursors.DictCursor,
)
cur = conn.cursor()

TOL_STAGE1_L2 = 0.15


def section(t: str):
    print(f"\n{'='*66}\n  {t}\n{'='*66}")


def fail(msg: str):
    print(f"\n❌ STOP: {msg}")
    sys.exit(1)


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
    for stmt in stmts:
        cur.execute(stmt)


def count_by_ds(tbl: str) -> dict[str, int]:
    cur.execute(f"SELECT data_source, COUNT(*) n FROM {tbl} GROUP BY data_source")
    d = defaultdict(int)
    for r in cur.fetchall():
        d[r["data_source"]] += int(r["n"])
    return dict(d)


def count_distinct_ids(tbl: str, l1_filter: str | None = None) -> dict[str, int]:
    if l1_filter:
        cur.execute(f"""
            SELECT e.data_source, COUNT(DISTINCT e.id) n
            FROM {tbl} e
            JOIN dwd.dwd_component_class c ON c.id = e.id AND c.data_source = e.data_source
            WHERE c.l1_code = %s
            GROUP BY e.data_source
        """, (l1_filter,))
    else:
        cur.execute(f"SELECT data_source, COUNT(DISTINCT id) n FROM {tbl} GROUP BY data_source")
    return {r["data_source"]: int(r["n"]) for r in cur.fetchall()}


def patch_eav_for_merge(text: str, l1: str) -> str:
    text = text.replace("dwd.dwd_component_attr_std", MERGE_EAV)
    if "dwd_icpdf_component_param" in text:
        text = text.replace(
            "WHERE (p.prajson IS NOT NULL OR p.prajson2 IS NOT NULL)\n),",
            f"WHERE (p.prajson IS NOT NULL OR p.prajson2 IS NOT NULL)\n      AND c.l1_code = '{l1}'\n),",
            1,
        )
    if "dwd_digikey_component_param" in text:
        text = text.replace(
            "WHERE p.prajson IS NOT NULL\n),",
            f"WHERE p.prajson IS NOT NULL\n      AND c.l1_code = '{l1}'\n),",
            1,
        )
    return text


def patch_l2_for_merge(text: str, l2: str) -> str:
    prod_l2 = f"dwd.dwd_l2_{L1}_{l2}"
    merge_l2 = f"test_dwd.dwd_l2_{L1}_{l2}_merge"
    text = text.replace(prod_l2, merge_l2)
    text = text.replace("dwd.dwd_component_attr_std", MERGE_EAV)
    return text


def patch_l2_ddl_for_merge(text: str, l2: str) -> str:
    prod_l2 = f"dwd.dwd_l2_{L1}_{l2}"
    merge_l2 = f"test_dwd.dwd_l2_{L1}_{l2}_merge"
    return text.replace(prod_l2, merge_l2)


def compare_counts(label_a: str, label_b: str, a: dict, b: dict, tol_abs: int = 0, tol_pct: float = 0.0) -> bool:
    ok = True
    for ds in sorted(set(a) | set(b)):
        va, vb = a.get(ds, 0), b.get(ds, 0)
        diff = va - vb
        base = max(vb, 1)
        tol = max(tol_abs, int(base * tol_pct))
        flag = "✅" if abs(diff) <= tol else "❌"
        if abs(diff) > tol:
            ok = False
        print(f"    {flag} {ds}: {label_a}={va:,} {label_b}={vb:,} diff={diff:+,} (tol={tol})")
    return ok


def rebuild_merge():
    section("Step 6a 创建 merge EAV 表")
    cur.execute(f"DROP TABLE IF EXISTS {MERGE_EAV}")
    cur.execute(f"CREATE TABLE {MERGE_EAV} LIKE dwd.dwd_component_attr_std")
    print(f"  ✅ {MERGE_EAV}")

    section("Step 6b 跑正式 EAV → merge（仅 inductor）")
    for src, build in (
        ("icpdf", "build_dwd_component_attr_std_icpdf.sql"),
        ("digikey", "build_dwd_component_attr_std_digikey.sql"),
    ):
        print(f"  ← {src}")
        text = patch_eav_for_merge((ATTR / build).read_text(encoding="utf-8-sig"), L1)
        exec_sql_text(text, build)

    section("Step 6c 跑正式 L2 → merge")
    for l2 in L2S:
        sfx = f"{L1}_{l2}"
        print(f"  L2 {sfx}")
        ddl = patch_l2_ddl_for_merge((READY / f"dwd_l2_{sfx}.sql").read_text(encoding="utf-8-sig"), l2)
        exec_sql_text(ddl, "ddl")
        build = patch_l2_for_merge((READY / f"build_dwd_l2_{sfx}.sql").read_text(encoding="utf-8-sig"), l2)
        exec_sql_text(build, "build")


def main():
    if args.rebuild:
        rebuild_merge()
    else:
        try:
            cur.execute(f"SELECT 1 FROM {MERGE_EAV} LIMIT 1")
        except Exception:
            fail("merge 表不存在，请: python run_attr_merge_step6.py --rebuild")

    section("Step 6d merge EAV 行数")
    merge_eav_rows = count_by_ds(MERGE_EAV)
    merge_eav_ids = count_distinct_ids(MERGE_EAV)
    print(f"  merge EAV 总行: {sum(merge_eav_rows.values()):,}  by_ds={merge_eav_rows}")
    print(f"  merge EAV 去重 id: {merge_eav_ids}")

    stage1_eav = f"test_dwd.dwd_component_attr_std_{L1}"
    try:
        stage1_rows = count_by_ds(stage1_eav)
        stage1_ids = count_distinct_ids(stage1_eav, L1)
        print(f"\n  阶段1 EAV 总行: {sum(stage1_rows.values()):,}  by_ds={stage1_rows}")
        print(f"  阶段1 去重 id: {stage1_ids}")
        print(f"\n  merge vs 阶段1 EAV（容差 {args.tol_pct:.1%}）:")
        eav_ok = compare_counts("merge", "stage1", merge_eav_rows, stage1_rows, tol_abs=5, tol_pct=args.tol_pct)
        if not eav_ok:
            print("    ⚠️  有偏差：prod dim 已替换，以 merge≈prod 为准")
    except Exception as e:
        print(f"  (跳过阶段1 EAV: {e})")

    section("Step 6e merge L2 vs prod L2（主验收）")
    l2_prod_ok = True
    for l2 in L2S:
        prod_tbl = f"dwd.dwd_l2_{L1}_{l2}"
        merge_tbl = f"test_dwd.dwd_l2_{L1}_{l2}_merge"
        print(f"\n  {l2}:")
        try:
            cur.execute(f"SELECT COUNT(*) n FROM {merge_tbl}")
            if cur.fetchone()["n"] == 0:
                fail(f"{merge_tbl} 为空")
        except Exception as e:
            fail(f"{merge_tbl}: {e}")
        prod_ds = count_by_ds(prod_tbl)
        merge_ds = count_by_ds(merge_tbl)
        print(f"    prod:  total={sum(prod_ds.values()):,}  {prod_ds}")
        print(f"    merge: total={sum(merge_ds.values()):,}  {merge_ds}")
        if not compare_counts("merge", "prod", merge_ds, prod_ds, tol_abs=0, tol_pct=0.0):
            l2_prod_ok = False

    section("Step 6f merge L2 vs 阶段1 后缀表（参考）")
    for l2 in L2S:
        merge_tbl = f"test_dwd.dwd_l2_{L1}_{l2}_merge"
        stage1_tbl = f"test_dwd.dwd_l2_{L1}_{l2}_{L1}"
        try:
            m = count_by_ds(merge_tbl)
            s = count_by_ds(stage1_tbl)
            print(f"\n  {l2}: merge={sum(m.values()):,}  stage1={sum(s.values()):,}")
            compare_counts("merge", "stage1", m, s, tol_abs=999999, tol_pct=TOL_STAGE1_L2)
        except Exception as e:
            print(f"  {l2}: ({e})")

    section("Step 6 结论")
    if l2_prod_ok:
        print("  ✅ merge L2 与 prod L2 一致 — Step 6 主验收通过")
    else:
        fail("merge L2 与 prod L2 不一致")

    conn.close()


if __name__ == "__main__":
    main()
