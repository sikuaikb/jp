#!/usr/bin/env python3
"""logic_ic 试点人群品牌门控：brandshort → v_std_brand_alias 命中率。"""
from __future__ import annotations

import os
import sys
from pathlib import Path

import pymysql

sys.stdout.reconfigure(encoding="utf-8")

HERE = Path(__file__).resolve().parents[1]
SQL_ROOT = HERE.parents[1]
ART = SQL_ROOT / "artifacts" / "logic_ic"


def load_env() -> None:
    for line in (SQL_ROOT / "local.env").read_text(encoding="utf-8").splitlines():
        if line.strip().startswith("export "):
            k, _, v = line.strip()[7:].partition("=")
            os.environ[k] = v.strip().strip("'").strip('"')


def main() -> int:
    import argparse
    from datetime import date

    ap = argparse.ArgumentParser()
    ap.add_argument("--schema", default="dim", help="dim 或 test_dim")
    args = ap.parse_args()
    alias_view = f"{args.schema}.v_std_brand_alias"

    load_env()
    conn = pymysql.connect(
        host=os.environ["MYSQL_HOST"],
        port=int(os.environ.get("MYSQL_PORT", "9030")),
        user=os.environ["MYSQL_USER"],
        password=os.environ["MYSQL_PASSWORD"],
        charset="utf8mb4",
        cursorclass=pymysql.cursors.DictCursor,
    )
    cur = conn.cursor()

    cur.execute(
        f"""
        SELECT COUNT(DISTINCT c.id) AS total,
               SUM(CASE WHEN NULLIF(TRIM(COALESCE(p.brandshort, '')), '') IS NULL THEN 1 ELSE 0 END) AS empty_brandshort,
               SUM(CASE WHEN NULLIF(TRIM(COALESCE(p.brandshort, '')), '') IS NOT NULL
                         AND a.brand_id_std IS NULL THEN 1 ELSE 0 END) AS unmapped,
               COUNT(DISTINCT CASE WHEN a.brand_id_std IS NULL
                    AND NULLIF(TRIM(COALESCE(p.brandshort, '')), '') IS NOT NULL
                    THEN p.brandshort END) AS unmapped_brands
        FROM test_dwd.dwd_component_class_logic_ic c
        JOIN dwd.dwd_digikey_component_param p ON p.id = c.id
        LEFT JOIN {alias_view} a ON a.brand_key = UPPER(TRIM(p.brandshort))
        """
    )
    r = cur.fetchone()
    total = int(r["total"])
    empty = int(r["empty_brandshort"] or 0)
    unmapped = int(r["unmapped"] or 0)
    with_bs = total - empty
    mapped = with_bs - unmapped
    pct = 100.0 * mapped / with_bs if with_bs else 100.0
    ok = unmapped == 0

    lines = [
        f"# logic_ic 品牌门控 · {date.today()}",
        "",
        f"**判定**: {'PASS' if ok else 'FAIL'}",
        f"**alias 视图**: `{alias_view}`",
        "",
        f"| 指标 | 值 |",
        f"|------|-----:|",
        f"| 试点 SKU | {total:,} |",
        f"| brandshort 空 | {empty:,} |",
        f"| 有 brandshort | {with_bs:,} |",
        f"| 已映射 | {mapped:,} ({pct:.1f}%) |",
        f"| 未映射 SKU | {unmapped:,} |",
        f"| 未映射 brandshort 种数 | {int(r['unmapped_brands'] or 0)} |",
        "",
    ]

    if unmapped:
        cur.execute(
            f"""
            SELECT p.brandshort, COUNT(DISTINCT c.id) AS rows_
            FROM test_dwd.dwd_component_class_logic_ic c
            JOIN dwd.dwd_digikey_component_param p ON p.id = c.id
            LEFT JOIN {alias_view} a ON a.brand_key = UPPER(TRIM(p.brandshort))
            WHERE NULLIF(TRIM(COALESCE(p.brandshort, '')), '') IS NOT NULL
              AND a.brand_id_std IS NULL
            GROUP BY p.brandshort
            ORDER BY rows_ DESC
            """
        )
        lines.append("## 未映射 brandshort\n")
        lines.append("| brandshort | rows |")
        lines.append("|------------|-----:|")
        for row in cur.fetchall():
            lines.append(f"| `{row['brandshort']}` | {row['rows_']:,} |")

    out = ART / f"brand_gate_audit_{date.today()}.md"
    ART.mkdir(parents=True, exist_ok=True)
    out.write_text("\n".join(lines) + "\n", encoding="utf-8")

    print(f"{'PASS' if ok else 'FAIL'} logic_ic brand gate ({alias_view})")
    print(f"  total={total:,} with_brandshort={with_bs:,} mapped={mapped:,} ({pct:.1f}%) unmapped={unmapped:,}")
    print(f"  report -> {out}")
    conn.close()
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
