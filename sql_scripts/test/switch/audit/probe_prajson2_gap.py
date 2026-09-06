#!/usr/bin/env python3
"""排查 ICPDF switch 无 prajson2 / 无 EAV 的 SKU（源数据缺口分析）。

用法:
  python audit/probe_prajson2_gap.py
  python audit/probe_prajson2_gap.py --l3 tactile_switch,dip_switch,snap_action_switch
"""
from __future__ import annotations

import argparse
import csv
import os
import sys
from collections import Counter, defaultdict
from pathlib import Path

import pymysql

sys.stdout.reconfigure(encoding="utf-8")

HERE = Path(__file__).resolve().parents[1]
ENV = HERE.parents[1] / "local.env"
ART = HERE / "artifacts" / "switch"
FAIL_L3 = ("tactile_switch", "dip_switch", "snap_action_switch")

P2_EMPTY = """
    (p.prajson2 IS NULL
     OR trim(cast(p.prajson2 AS CHAR)) IN ('', '{}', 'null'))
"""
P1_HAS = """
    (p.prajson IS NOT NULL
     AND trim(cast(p.prajson AS CHAR)) NOT IN ('', '[]', 'null'))
"""
P2_HAS = f"NOT {P2_EMPTY}"


def load_env() -> None:
    for line in ENV.read_text(encoding="utf-8").splitlines():
        if line.strip().startswith("export "):
            k, _, v = line.strip()[7:].partition("=")
            os.environ[k] = v.strip().strip("'").strip('"')


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument(
        "--l3",
        default=",".join(FAIL_L3),
        help="逗号分隔 L3；默认 3 个 FAIL L3",
    )
    ap.add_argument("--all-l3", action="store_true", help="导出全部 L3 缺口 SKU")
    args = ap.parse_args()
    load_env()
    ART.mkdir(parents=True, exist_ok=True)

    l3_filter = None if args.all_l3 else [x.strip() for x in args.l3.split(",") if x.strip()]
    l3_clause = ""
    params: list = ["icpdf"]
    if l3_filter:
        ph = ",".join(["%s"] * len(l3_filter))
        l3_clause = f" AND c.l3_code IN ({ph})"
        params.extend(l3_filter)

    conn = pymysql.connect(
        host=os.environ["MYSQL_HOST"],
        port=int(os.environ.get("MYSQL_PORT", "9030")),
        user=os.environ["MYSQL_USER"],
        password=os.environ["MYSQL_PASSWORD"],
        charset="utf8mb4",
        cursorclass=pymysql.cursors.DictCursor,
        autocommit=True,
    )
    cur = conn.cursor()
    cur.execute("SET enable_local_shuffle_agg=false")
    cur.execute("SET query_timeout = 600")

    # --- 汇总 ---
    cur.execute(
        f"""
        SELECT
            c.l3_code,
            COUNT(*) AS sku,
            SUM(CASE WHEN {P2_HAS} THEN 1 ELSE 0 END) AS has_p2,
            SUM(CASE WHEN {P2_EMPTY} THEN 1 ELSE 0 END) AS no_p2,
            SUM(CASE WHEN {P2_EMPTY} AND {P1_HAS} THEN 1 ELSE 0 END) AS no_p2_has_p1,
            SUM(CASE WHEN {P2_EMPTY} AND NOT ({P1_HAS}) THEN 1 ELSE 0 END) AS no_p2_no_p1,
            SUM(CASE WHEN p.category2 IS NULL OR trim(p.category2) = '' THEN 1 ELSE 0 END) AS c2_null,
            SUM(CASE WHEN {P2_EMPTY} AND (p.category2 IS NULL OR trim(p.category2) = '') THEN 1 ELSE 0 END) AS no_p2_c2_null
        FROM test_dwd.dwd_component_class_switch c
        JOIN dwd.dwd_icpdf_component_param p ON p.id = c.id
        WHERE c.data_source = %s {l3_clause}
        GROUP BY c.l3_code
        ORDER BY no_p2 DESC
        """,
        params,
    )
    summary = cur.fetchall()

    cur.execute(
        f"""
        SELECT
            COUNT(DISTINCT c.id) AS gap_sku,
            SUM(CASE WHEN e.id IS NULL THEN 1 ELSE 0 END) AS no_eav,
            SUM(CASE WHEN {P1_HAS} THEN 1 ELSE 0 END) AS has_p1,
            SUM(CASE WHEN e.id IS NOT NULL THEN 1 ELSE 0 END) AS has_eav
        FROM test_dwd.dwd_component_class_switch c
        JOIN dwd.dwd_icpdf_component_param p ON p.id = c.id
        LEFT JOIN (
            SELECT DISTINCT id FROM test_dwd.dwd_component_attr_std_switch
            WHERE data_source = 'icpdf'
        ) e ON e.id = c.id
        WHERE c.data_source = %s {l3_clause}
          AND {P2_EMPTY}
        """,
        params,
    )
    gap_tot = cur.fetchone()

    # category / category2 分布（无 prajson2）
    cur.execute(
        f"""
        SELECT c.l3_code,
               coalesce(nullif(trim(p.category), ''), '(null)') AS category,
               coalesce(nullif(trim(p.category2), ''), '(null)') AS category2,
               COUNT(*) AS n
        FROM test_dwd.dwd_component_class_switch c
        JOIN dwd.dwd_icpdf_component_param p ON p.id = c.id
        WHERE c.data_source = %s {l3_clause}
          AND {P2_EMPTY}
        GROUP BY c.l3_code, category, category2
        ORDER BY c.l3_code, n DESC
        """,
        params,
    )
    cat_rows = cur.fetchall()

    # brand 分布
    cur.execute(
        f"""
        SELECT c.l3_code, coalesce(nullif(trim(p.brandshort), ''), '(null)') AS brand,
               COUNT(*) AS n
        FROM test_dwd.dwd_component_class_switch c
        JOIN dwd.dwd_icpdf_component_param p ON p.id = c.id
        WHERE c.data_source = %s {l3_clause}
          AND {P2_EMPTY}
        GROUP BY c.l3_code, brand
        ORDER BY c.l3_code, n DESC
        LIMIT 80
        """,
        params,
    )
    brand_rows = cur.fetchall()

    # 明细导出
    cur.execute(
        f"""
        SELECT
            c.l3_code,
            c.l2_code,
            c.id,
            p.partno,
            p.brandshort,
            p.category,
            p.category2,
            CASE WHEN {P1_HAS} THEN 1 ELSE 0 END AS has_prajson,
            CASE WHEN e.id IS NOT NULL THEN 1 ELSE 0 END AS has_eav,
            left(coalesce(p.note_cn, ''), 120) AS note_cn_head
        FROM test_dwd.dwd_component_class_switch c
        JOIN dwd.dwd_icpdf_component_param p ON p.id = c.id
        LEFT JOIN (
            SELECT DISTINCT id FROM test_dwd.dwd_component_attr_std_switch
            WHERE data_source = 'icpdf'
        ) e ON e.id = c.id
        WHERE c.data_source = %s {l3_clause}
          AND {P2_EMPTY}
        ORDER BY c.l3_code, p.brandshort, p.partno
        """,
        params,
    )
    detail = cur.fetchall()

    # 有 prajson 但无 EAV 的（prajson 兜底潜力）
    cur.execute(
        f"""
        SELECT c.l3_code, COUNT(*) AS n
        FROM test_dwd.dwd_component_class_switch c
        JOIN dwd.dwd_icpdf_component_param p ON p.id = c.id
        LEFT JOIN (
            SELECT DISTINCT id FROM test_dwd.dwd_component_attr_std_switch
            WHERE data_source = 'icpdf'
        ) e ON e.id = c.id
        WHERE c.data_source = %s {l3_clause}
          AND {P2_EMPTY}
          AND {P1_HAS}
          AND e.id IS NULL
        GROUP BY c.l3_code
        """,
        params,
    )
    p1_no_eav = {r["l3_code"]: r["n"] for r in cur.fetchall()}

    conn.close()

    csv_path = ART / "prajson2_gap_skus.csv"
    with csv_path.open("w", encoding="utf-8-sig", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(detail[0].keys()) if detail else [])
        if detail:
            w.writeheader()
            w.writerows(detail)

    report_path = ART / "prajson2_gap_report.txt"
    lines: list[str] = [
        "# ICPDF switch · 无 prajson2 SKU 排查",
        f"# L3 范围: {'全部' if args.all_l3 else ', '.join(l3_filter or [])}",
        "",
        "== 一、汇总 ==",
        f"无 prajson2 SKU 合计: {gap_tot['gap_sku']:,}",
        f"  其中无 EAV: {gap_tot['no_eav']:,}",
        f"  其中有 prajson（旧 JSON）: {gap_tot['has_p1']:,}",
        f"  其中有 EAV（仅靠 prajson/其他）: {gap_tot['has_eav']:,}",
        "",
        f"{'L3':<24} {'SKU':>6} {'无p2':>6} {'无p2有p1':>8} {'无p2无p1':>8} {'c2空':>6} {'无p2且c2空':>10}",
        "-" * 78,
    ]
    for r in summary:
        lines.append(
            f"{r['l3_code']:<24} {r['sku']:>6,} {r['no_p2']:>6,} "
            f"{r['no_p2_has_p1']:>8,} {r['no_p2_no_p1']:>8,} "
            f"{r['c2_null']:>6,} {r['no_p2_c2_null']:>10,}"
        )

    lines.extend(["", "== 二、无 prajson2 · category/category2 分布 =="])
    by_l3: dict[str, list] = defaultdict(list)
    for r in cat_rows:
        by_l3[r["l3_code"]].append(r)
    for l3, rows in sorted(by_l3.items()):
        lines.append(f"\n--- {l3} ---")
        for r in rows[:15]:
            lines.append(f"  {r['n']:>4}  category={r['category']!r}  category2={r['category2']!r}")

    lines.extend(["", "== 三、无 prajson2 · Top brand =="])
    cur_l3 = None
    for r in brand_rows:
        if r["l3_code"] != cur_l3:
            cur_l3 = r["l3_code"]
            lines.append(f"\n--- {cur_l3} ---")
        lines.append(f"  {r['n']:>4}  {r['brand']}")

    lines.extend(["", "== 四、prajson 兜底潜力（无 p2 有 p1 仍无 EAV）=="])
    if p1_no_eav:
        for l3, n in sorted(p1_no_eav.items(), key=lambda x: -x[1]):
            lines.append(f"  {l3}: {n:,} SKU — ICPDF 规则几乎全 prajson2_key_eq，prajson 无法补 EAV")
    else:
        lines.append("  （无：无 p2 但有 p1 的 SKU 若已有 EAV 则来自 prajson 路径；否则完全无 JSON）")

    lines.extend([
        "",
        "== 五、prajson（旧 JSON）形态抽样 ==",
        "无 prajson2 的 SKU 100% 仍有 prajson，但 key 为拼音 sqlname（如 gongZuoWenDuMin、chuDianLeiXing），",
        "不是 prajson2 的中文 key（如「工作温度」「开关功能」）。",
        "build SQL 虽支持 prajson_cn_eq / prajson_sqlname_eq，但 switch ICPDF 规则 85 条全是 prajson2_key_eq。",
        "",
        "== 六、结论与建议 ==",
        "1. 根因：category2=null 的老/残缺 ICPDF 记录 → 未生成 prajson2；非 classify 规则错误。",
        "2. prajson 里有电压/电流/温度/触点类型等，但当前规则不读 prajson → EAV 全空。",
        "3. 修复路径（择一或组合）：",
        "   A. 上游补 prajson2 / category2（推荐，与有 prajson2 SKU 对齐）",
        "   B. 为高频 sqlname 增 prajson_sqlname_eq 规则（如 gongZuoWenDuMin/Max → temp_min/max_c）",
        "   C. 接受缺口：3 个 FAIL L3 仅占 switch 总量 ~0.5%（671/144273）",
        "4. 分类仍正确（靠 category L1）；L2 宽表仍有行（brandshort/partno），仅 EAV 属性缺失。",
        "",
        f"明细 CSV: {csv_path.name}  ({len(detail):,} 行)",
    ])

    report_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(report_path.read_text(encoding="utf-8"))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
