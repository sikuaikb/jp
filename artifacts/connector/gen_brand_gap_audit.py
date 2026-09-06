#!/usr/bin/env python3
"""得捷连接器宽表品牌门控缺口审计（只读 dim，不 sync 品牌字典）。"""
from __future__ import annotations

import os
import sys
from datetime import date
from pathlib import Path

import pymysql

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from gen_attr_fill_rate_tables import L2_CN, L2_WIDE, conn_kwargs  # noqa: E402

OUT_TSV = HERE / f"connector_brand_gap_audit_{date.today().strftime('%Y%m%d')}.tsv"


def main() -> None:
    conn = pymysql.connect(**conn_kwargs())
    rows: list[tuple] = []
    try:
        with conn.cursor() as cur:
            for l2, tbl in L2_WIDE.items():
                cur.execute(
                    f"""
                    SELECT %s AS l2_code,
                           COALESCE(w.brand, get_json_string(p.prajson,'$."制造商"'), p.brandshort) AS brand_raw,
                           COUNT(*) AS row_cnt
                    FROM test_dwd.{tbl} w
                    JOIN dwd.dwd_digikey_component_param p ON p.id = w.id
                    WHERE w.data_source = 'digikey'
                      AND (w.brandid IS NULL OR w.brand IS NULL OR TRIM(w.brand) = '')
                      AND COALESCE(
                            NULLIF(TRIM(w.brand), ''),
                            NULLIF(TRIM(get_json_string(p.prajson,'$."制造商"')), ''),
                            NULLIF(TRIM(p.brandshort), '')
                          ) IS NOT NULL
                    GROUP BY 1, 2
                    ORDER BY row_cnt DESC
                    LIMIT 500
                    """,
                    (l2,),
                )
                rows.extend(cur.fetchall())
    finally:
        conn.close()

    merged: dict[str, int] = {}
    for l2, brand, cnt in rows:
        key = f"{l2}\t{brand}"
        merged[key] = merged.get(key, 0) + int(cnt)

    lines = ["l2_code\tl2_cn\tbrand_raw\trow_cnt"]
    for key, cnt in sorted(merged.items(), key=lambda x: -x[1])[:200]:
        l2, brand = key.split("\t", 1)
        lines.append(f"{l2}\t{L2_CN.get(l2, l2)}\t{brand}\t{cnt}")
    OUT_TSV.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"wrote {OUT_TSV} ({len(lines) - 1} rows)")


if __name__ == "__main__":
    main()
