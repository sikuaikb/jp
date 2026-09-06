#!/usr/bin/env python3
"""Step 5：沙盒 dwd_component_class_<l1> vs prod 引擎 merge 表行数对比（icpdf）。"""
from __future__ import annotations

import os
import sys
from pathlib import Path

import pymysql

sys.stdout.reconfigure(encoding="utf-8")

L1 = "circuit_protection"
DS = "icpdf"
SANDBOX = f"test_dwd.dwd_component_class_{L1}"
MERGE = f"test_dwd.dwd_component_class_merge_{L1}"
TOL = 0.005  # 0.5% per skill Step 7


def conn():
    return pymysql.connect(
        host=os.environ.get("MYSQL_HOST", "192.168.19.21"),
        port=int(os.environ.get("MYSQL_PORT", "9030")),
        user=os.environ.get("MYSQL_USER", "root"),
        password=os.environ.get("MYSQL_PASSWORD", ""),
        charset="utf8mb4",
        cursorclass=pymysql.cursors.DictCursor,
    )


def count_cp(cur, table: str) -> int:
    cur.execute(
        f"""
        SELECT COUNT(*) AS n FROM {table}
        WHERE l1_code = %s AND data_source = %s
        """,
        (L1, DS),
    )
    return int(cur.fetchone()["n"])


def drift_detail(cur) -> list[dict]:
    cur.execute(
        f"""
        WITH sb AS (
            SELECT id FROM {SANDBOX}
            WHERE l1_code = %s AND data_source = %s
        ),
        mg AS (
            SELECT id, l1_code, l2_code, l3_code FROM {MERGE}
            WHERE data_source = %s
        )
        SELECT mg.l1_code, mg.l2_code, mg.l3_code, COUNT(*) AS n
        FROM sb
        LEFT JOIN mg ON mg.id = sb.id AND mg.l1_code = %s
        WHERE mg.id IS NULL OR mg.l1_code <> %s
        GROUP BY 1, 2, 3
        ORDER BY n DESC
        LIMIT 15
        """,
        (L1, DS, DS, L1, L1),
    )
    return list(cur.fetchall())


def main() -> int:
    with conn() as c:
        with c.cursor() as cur:
            sb_n = count_cp(cur, SANDBOX)
            try:
                mg_n = count_cp(cur, MERGE)
            except pymysql.err.ProgrammingError as e:
                print(f"ERROR: merge table missing — run dwd_component_class.sql → {MERGE}\n{e}")
                return 1
            diff = mg_n - sb_n
            pct = (diff / sb_n * 100) if sb_n else 0.0
            print(f"sandbox {SANDBOX}: {sb_n:,}")
            print(f"merge   {MERGE}: {mg_n:,}")
            print(f"delta: {diff:+,} ({pct:+.2f}%)")
            if sb_n and abs(diff) / sb_n > TOL:
                print("\nFAIL: |delta| > 0.5% — Step 5 blocked")
                rows = drift_detail(cur)
                if rows:
                    print("\n沙盒 CP 行 · 全局引擎落点（top）:")
                    for r in rows:
                        print(
                            f"  {r.get('l1_code')}.{r.get('l2_code')}.{r.get('l3_code')}: {r['n']:,}"
                        )
                return 1
            print("PASS: Step 5 row count within tolerance")
            return 0


if __name__ == "__main__":
    raise SystemExit(main())
