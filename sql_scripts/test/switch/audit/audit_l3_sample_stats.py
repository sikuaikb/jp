#!/usr/bin/env python3
"""按 L3 对已分类 ICPDF SKU 做抽样统计（源数据 + EAV + 宽表）。

用法:
  python audit/audit_l3_sample_stats.py
  python audit/audit_l3_sample_stats.py --sample-size 5 --out artifacts/switch/l3_sample_stats.txt
"""
from __future__ import annotations

import argparse
import csv
import os
import random
import sys
from pathlib import Path

import pymysql

sys.stdout.reconfigure(encoding="utf-8")

HERE = Path(__file__).resolve().parents[1]
ENV = HERE.parents[1] / "local.env"
L3_CSV = HERE / "seed" / "dim_l3_classify_switch.csv"
DEFAULT_OUT = HERE / "artifacts" / "switch" / "l3_sample_stats.txt"

KEY_L2 = (
    "mpn", "manufacturer", "rohs_compliant", "temp_min_c", "temp_max_c",
    "rated_voltage_v", "circuit_type", "mounting_type",
)


def load_env() -> None:
    for line in ENV.read_text(encoding="utf-8").splitlines():
        if line.strip().startswith("export "):
            k, _, v = line.strip()[7:].partition("=")
            os.environ[k] = v.strip().strip("'").strip('"')


def load_l3_names() -> dict[str, str]:
    out: dict[str, str] = {}
    with L3_CSV.open(encoding="utf-8") as f:
        for r in csv.DictReader(f):
            out[r["l3_code"]] = r.get("l3_cn") or r["l3_code"]
    return out


def pct(n: int, d: int) -> float:
    return 100.0 * n / d if d else 0.0


def bar(cov: float, width: int = 20) -> str:
    filled = int(round(cov / 100 * width))
    return "█" * filled + "░" * (width - filled)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--data-source", default="icpdf")
    ap.add_argument("--sample-size", type=int, default=5, help="每 L3 随机抽样 SKU 数")
    ap.add_argument("--seed", type=int, default=42)
    ap.add_argument("--out", type=Path, default=DEFAULT_OUT)
    args = ap.parse_args()
    load_env()
    args.out.parent.mkdir(parents=True, exist_ok=True)
    l3_cn = load_l3_names()
    rng = random.Random(args.seed)

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

    lines: list[str] = [
        f"# switch L3 抽样统计 · data_source={args.data_source}",
        f"# sample_size={args.sample_size}  seed={args.seed}",
        "",
    ]

    # L3 列表
    cur.execute(
        """
        SELECT c.l3_code, c.l2_code, COUNT(*) sku
        FROM test_dwd.dwd_component_class_switch c
        WHERE c.data_source = %s
        GROUP BY c.l3_code, c.l2_code
        ORDER BY sku DESC
        """,
        (args.data_source,),
    )
    l3_rows = cur.fetchall()

    # 汇总表
    lines.append("=" * 100)
    lines.append("一、L3 汇总（源数据 + EAV + 宽表）")
    lines.append("=" * 100)
    hdr = (
        f"{'L3':<24} {'SKU':>7} {'prajson2':>8} {'EAV':>7} {'L2表':>7} "
        f"{'brand':>7} {'mfr':>7} {'c2 Top1%':>8}"
    )
    lines.append(hdr)
    lines.append("-" * len(hdr))

    summary_rows: list[dict] = []

    for l3 in l3_rows:
        code = l3["l3_code"]
        l2 = l3["l2_code"]
        sku = l3["sku"]

        cur.execute(
            """
            SELECT
                COUNT(*) AS sku,
                SUM(CASE WHEN p.prajson2 IS NOT NULL
                         AND trim(cast(p.prajson2 AS CHAR)) NOT IN ('', '{}', 'null')
                    THEN 1 ELSE 0 END) AS has_p2,
                SUM(CASE WHEN p.prajson IS NOT NULL
                         AND trim(cast(p.prajson AS CHAR)) NOT IN ('', '[]', 'null')
                    THEN 1 ELSE 0 END) AS has_p1,
                SUM(CASE WHEN NULLIF(trim(p.brandshort), '') IS NOT NULL THEN 1 ELSE 0 END) AS has_brand,
                SUM(CASE WHEN NULLIF(trim(p.partno), '') IS NOT NULL THEN 1 ELSE 0 END) AS has_partno
            FROM test_dwd.dwd_component_class_switch c
            JOIN dwd.dwd_icpdf_component_param p ON p.id = c.id
            WHERE c.data_source = %s AND c.l3_code = %s
            """,
            (args.data_source, code),
        )
        src = cur.fetchone()

        cur.execute(
            """
            SELECT COUNT(DISTINCT e.id) eav_n
            FROM test_dwd.dwd_component_class_switch c
            LEFT JOIN test_dwd.dwd_component_attr_std_switch e
              ON e.id = c.id AND e.data_source = c.data_source
            WHERE c.data_source = %s AND c.l3_code = %s
            """,
            (args.data_source, code),
        )
        eav_n = cur.fetchone()["eav_n"]

        l2_tbl = f"test_dwd.dwd_l2_switch_{l2}"
        try:
            cur.execute(
                f"SELECT COUNT(*) n FROM {l2_tbl} WHERE data_source=%s AND l3_code=%s",
                (args.data_source, code),
            )
            l2_n = cur.fetchone()["n"]
        except Exception:
            l2_n = 0

        cur.execute(
            """
            SELECT COUNT(DISTINCT c.id) mfr_n
            FROM test_dwd.dwd_component_class_switch c
            JOIN test_dwd.dwd_component_attr_std_switch e
              ON e.id = c.id AND e.data_source = c.data_source
             AND e.std_attr_code = 'manufacturer'
             AND e.value_std_varchar IS NOT NULL AND trim(e.value_std_varchar) <> ''
            WHERE c.data_source = %s AND c.l3_code = %s
            """,
            (args.data_source, code),
        )
        mfr_n = cur.fetchone()["mfr_n"]

        cur.execute(
            """
            SELECT p.category2, COUNT(*) n
            FROM test_dwd.dwd_component_class_switch c
            JOIN dwd.dwd_icpdf_component_param p ON p.id = c.id
            WHERE c.data_source = %s AND c.l3_code = %s
            GROUP BY p.category2 ORDER BY n DESC LIMIT 1
            """,
            (args.data_source, code),
        )
        top_c2 = cur.fetchone()
        c2_top_pct = pct(top_c2["n"], sku) if top_c2 else 0

        row = {
            "l3_code": code,
            "l3_cn": l3_cn.get(code, ""),
            "l2_code": l2,
            "sku": sku,
            "has_p2": src["has_p2"],
            "p2_pct": pct(src["has_p2"], sku),
            "has_p1": src["has_p1"],
            "eav_n": eav_n,
            "eav_pct": pct(eav_n, sku),
            "l2_n": l2_n,
            "has_brand": src["has_brand"],
            "mfr_n": mfr_n,
            "c2_top": top_c2["category2"] if top_c2 else "",
            "c2_top_pct": c2_top_pct,
        }
        summary_rows.append(row)
        lines.append(
            f"{code:<24} {sku:>7,} {row['p2_pct']:>7.1f}% {row['eav_pct']:>6.1f}% "
            f"{pct(l2_n, sku):>6.1f}% {pct(src['has_brand'], sku):>6.1f}% "
            f"{pct(mfr_n, sku):>6.1f}% {c2_top_pct:>7.1f}%"
        )

    lines.append("")
    lines.append("列说明: prajson2%=有 prajson2 占比; EAV%=有 EAV 行; L2表%=宽表命中; "
                 "brand%=有 brandshort; mfr%=有 manufacturer; c2 Top1%=category2 集中度")

    # 逐 L3 详情
    lines.append("")
    lines.append("=" * 100)
    lines.append("二、逐 L3 详情 + 随机抽样")
    lines.append("=" * 100)

    for row in summary_rows:
        code = row["l3_code"]
        cn = row["l3_cn"]
        sku = row["sku"]
        lines.append("")
        lines.append("-" * 100)
        lines.append(f"L3 {code} ({cn})  ∈ {row['l2_code']}  |  SKU={sku:,}")
        lines.append("-" * 100)

        # 数据完整性
        lines.append("  [源数据]")
        lines.append(f"    prajson2  {row['has_p2']:>7,} / {sku:,}  ({row['p2_pct']:.1f}%)  {bar(row['p2_pct'])}")
        lines.append(f"    prajson   {row['has_p1']:>7,} / {sku:,}  ({pct(row['has_p1'], sku):.1f}%)")
        lines.append(f"    brandshort {row['has_brand']:>6,} / {sku:,}  ({pct(row['has_brand'], sku):.1f}%)")
        lines.append(f"    category2 Top1: {row['c2_top']} ({row['c2_top_pct']:.1f}%)")

        # L2 关键属性
        lines.append("  [L2 关键属性 EAV 覆盖]")
        cur.execute(
            f"""
            SELECT e.std_attr_code, COUNT(DISTINCT c.id) n
            FROM test_dwd.dwd_component_class_switch c
            LEFT JOIN test_dwd.dwd_component_attr_std_switch e
              ON e.id = c.id AND e.data_source = c.data_source
             AND e.std_attr_code IN ({','.join(repr(x) for x in KEY_L2)})
             AND (e.value_std_double IS NOT NULL
                  OR (e.value_std_varchar IS NOT NULL AND trim(e.value_std_varchar) <> ''))
            WHERE c.data_source = %s AND c.l3_code = %s
            GROUP BY e.std_attr_code
            """,
            (args.data_source, code),
        )
        filled = {r["std_attr_code"]: r["n"] for r in cur.fetchall()}
        for attr in KEY_L2:
            n = filled.get(attr, 0)
            c = pct(n, sku)
            flag = "✓" if c >= 30 else ("△" if c >= 5 else "✗")
            lines.append(f"    {flag} {attr:<22} {n:>7,}  ({c:5.1f}%)  {bar(c, 15)}")

        # prajson2 Top keys
        cur.execute(
            """
            SELECT k, COUNT(*) cnt FROM (
                SELECT c.id, u.k
                FROM test_dwd.dwd_component_class_switch c
                JOIN dwd.dwd_icpdf_component_param p ON p.id = c.id,
                     UNNEST(CAST(json_keys(p.prajson2) AS ARRAY<VARCHAR(256)>)) AS u(k)
                WHERE c.data_source = %s AND c.l3_code = %s AND p.prajson2 IS NOT NULL
            ) t GROUP BY k ORDER BY cnt DESC LIMIT 12
            """,
            (args.data_source, code),
        )
        top_keys = cur.fetchall()
        if top_keys:
            lines.append("  [prajson2 Top keys]")
            for tk in top_keys:
                lines.append(f"    {tk['cnt']:>7,}  {tk['k']}")

        # 无 prajson2 统计
        no_p2 = sku - row["has_p2"]
        if no_p2 > 0:
            lines.append(f"  [无 prajson2] {no_p2:,} SKU ({pct(no_p2, sku):.1f}%)")
            cur.execute(
                """
                SELECT p.category2, COUNT(*) n
                FROM test_dwd.dwd_component_class_switch c
                JOIN dwd.dwd_icpdf_component_param p ON p.id = c.id
                WHERE c.data_source = %s AND c.l3_code = %s
                  AND (p.prajson2 IS NULL OR trim(cast(p.prajson2 AS CHAR)) IN ('', '{}', 'null'))
                GROUP BY p.category2 ORDER BY n DESC LIMIT 5
                """,
                (args.data_source, code),
            )
            for r in cur.fetchall():
                lines.append(f"      {r['n']:>6,}  category2={r['category2']}")

        # 随机抽样
        cur.execute(
            """
            SELECT c.id, p.partno, p.brandshort, p.category2,
                   CASE WHEN p.prajson2 IS NOT NULL
                        AND trim(cast(p.prajson2 AS CHAR)) NOT IN ('', '{}', 'null')
                   THEN 1 ELSE 0 END AS has_p2
            FROM test_dwd.dwd_component_class_switch c
            JOIN dwd.dwd_icpdf_component_param p ON p.id = c.id
            WHERE c.data_source = %s AND c.l3_code = %s
            """,
            (args.data_source, code),
        )
        all_ids = cur.fetchall()
        sample_n = min(args.sample_size, len(all_ids))
        samples = rng.sample(all_ids, sample_n) if all_ids else []

        lines.append(f"  [随机抽样 n={sample_n}]")
        for s in samples:
            cur.execute(
                """
                SELECT std_attr_code,
                       COALESCE(value_std_varchar, CAST(value_std_double AS CHAR)) AS val
                FROM test_dwd.dwd_component_attr_std_switch
                WHERE data_source = %s AND id = %s
                  AND std_attr_code IN ('mpn','manufacturer','rohs_compliant','temp_min_c',
                                        'temp_max_c','circuit_type','mounting_type','rated_voltage_v')
                  AND (value_std_double IS NOT NULL
                       OR (value_std_varchar IS NOT NULL AND trim(value_std_varchar) <> ''))
                """,
                (args.data_source, s["id"]),
            )
            attrs = {r["std_attr_code"]: r["val"] for r in cur.fetchall()}
            p2_flag = "Y" if s["has_p2"] else "N"
            attr_str = ", ".join(f"{k}={attrs[k]}" for k in KEY_L2 if k in attrs)
            lines.append(
                f"    id={s['id']}  p2={p2_flag}  partno={s['partno'] or '-'}  "
                f"brand={s['brandshort'] or '-'}  c2={s['category2'] or '-'}"
            )
            if attr_str:
                lines.append(f"      EAV: {attr_str}")
            else:
                lines.append("      EAV: (无关键属性)")

        # 无 prajson2 专项抽样（若有）
        if no_p2 > 0:
            no_p2_rows = [r for r in all_ids if not r["has_p2"]]
            sp = rng.sample(no_p2_rows, min(3, len(no_p2_rows)))
            lines.append("  [无 prajson2 抽样]")
            for s in sp:
                lines.append(
                    f"    id={s['id']}  partno={s['partno'] or '-'}  "
                    f"brand={s['brandshort'] or '-'}  c2={s['category2'] or '-'}"
                )

    # 交叉：EAV 缺口 SKU
    lines.append("")
    lines.append("=" * 100)
    lines.append("三、EAV 缺口 SKU 按 L3（无 EAV 或 无 prajson2）")
    lines.append("=" * 100)
    cur.execute(
        """
        SELECT c.l3_code,
               SUM(CASE WHEN e.id IS NULL THEN 1 ELSE 0 END) no_eav,
               SUM(CASE WHEN p.prajson2 IS NULL
                         OR trim(cast(p.prajson2 AS CHAR)) IN ('', '{}', 'null')
                    THEN 1 ELSE 0 END) no_p2
        FROM test_dwd.dwd_component_class_switch c
        JOIN dwd.dwd_icpdf_component_param p ON p.id = c.id
        LEFT JOIN test_dwd.dwd_component_attr_std_switch e
          ON e.id = c.id AND e.data_source = c.data_source
        WHERE c.data_source = %s
        GROUP BY c.l3_code
        HAVING no_eav > 0 OR no_p2 > 0
        ORDER BY no_eav DESC
        """,
        (args.data_source,),
    )
    lines.append(f"  {'L3':<24} {'无EAV':>8} {'无prajson2':>12}")
    lines.append("  " + "-" * 48)
    for r in cur.fetchall():
        lines.append(f"  {r['l3_code']:<24} {r['no_eav']:>8,} {r['no_p2']:>12,}")

    conn.close()
    text = "\n".join(lines) + "\n"
    args.out.write_text(text, encoding="utf-8")
    print(text)
    print(f"报告 -> {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
