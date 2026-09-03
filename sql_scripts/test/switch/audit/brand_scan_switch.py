#!/usr/bin/env python3
"""switch 试点：未映射 brandshort 扫描（ICPDF 分类人群）。"""
from __future__ import annotations

import json
import os
import sys
from pathlib import Path

import pymysql

sys.stdout.reconfigure(encoding="utf-8")

HERE = Path(__file__).resolve().parents[1]
OUT = HERE / "artifacts" / "switch" / "brand_unmapped_icpdf.json"


def load_env() -> None:
    for line in (HERE.parents[1] / "local.env").read_text(encoding="utf-8").splitlines():
        if line.strip().startswith("export "):
            k, _, v = line.strip()[7:].partition("=")
            os.environ[k] = v.strip().strip("'").strip('"')


def main() -> int:
    load_env()
    OUT.parent.mkdir(parents=True, exist_ok=True)

    conn = pymysql.connect(
        host=os.environ["MYSQL_HOST"],
        port=int(os.environ.get("MYSQL_PORT", "9030")),
        user=os.environ["MYSQL_USER"],
        password=os.environ["MYSQL_PASSWORD"],
        charset="utf8mb4",
        cursorclass=pymysql.cursors.DictCursor,
    )
    cur = conn.cursor()
    cur.execute("SET enable_local_shuffle_agg=false")

    cur.execute(
        """
        SELECT p.brandshort, COUNT(DISTINCT c.id) AS rows_,
               GROUP_CONCAT(DISTINCT c.l3_code ORDER BY c.l3_code) AS l3s
        FROM test_dwd.dwd_component_class_switch c
        JOIN dwd.dwd_icpdf_component_param p ON p.id = c.id
        LEFT JOIN test_dim.v_std_brand_alias a ON a.brand_key = UPPER(TRIM(p.brandshort))
        WHERE c.data_source = 'icpdf'
          AND NULLIF(TRIM(COALESCE(p.brandshort, '')), '') IS NOT NULL
          AND a.brand_id_std IS NULL
        GROUP BY p.brandshort
        ORDER BY rows_ DESC
        """
    )
    unmapped = cur.fetchall()

    cur.execute(
        """
        SELECT COUNT(DISTINCT c.id) AS n
        FROM test_dwd.dwd_component_class_switch c
        JOIN dwd.dwd_icpdf_component_param p ON p.id = c.id
        WHERE c.data_source = 'icpdf'
          AND NULLIF(TRIM(COALESCE(p.brandshort, '')), '') IS NOT NULL
        """
    )
    total = int(cur.fetchone()["n"])
    unmapped_rows = sum(int(r["rows_"]) for r in unmapped)

    report = {
        "data_source": "icpdf",
        "total_with_brandshort": total,
        "unmapped_brandshort_count": len(unmapped),
        "unmapped_row_count": unmapped_rows,
        "unmapped_pct": round(100.0 * unmapped_rows / total, 2) if total else 0,
        "top_unmapped": unmapped[:30],
    }
    OUT.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")

    print(f"ICPDF switch 有 brandshort: {total:,}")
    print(f"未映射 brandshort: {len(unmapped)} 种, 涉及 {unmapped_rows:,} SKU ({report['unmapped_pct']}%)")
    print(f"报告 -> {OUT}")
    for r in unmapped[:15]:
        print(f"  {r['rows_']:>7,}  {r['brandshort']}")

    conn.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
