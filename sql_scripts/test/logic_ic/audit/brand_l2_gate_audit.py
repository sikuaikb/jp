#!/usr/bin/env python3
"""L2 宽表 brand/brandid 门控检查。"""
from __future__ import annotations

import os
import sys
from pathlib import Path

import pymysql

sys.stdout.reconfigure(encoding="utf-8")

HERE = Path(__file__).resolve().parent
SQL_ROOT = HERE.parents[2]
L2S = ["combinational_logic", "sequential_logic", "signal_buffer_driver"]


def load_env() -> None:
    for line in (SQL_ROOT / "local.env").read_text(encoding="utf-8").splitlines():
        if line.strip().startswith("export "):
            k, _, v = line.strip()[7:].partition("=")
            os.environ[k] = v.strip().strip("'").strip('"')


def main() -> int:
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
    ok = True
    for l2 in L2S:
        t = f"test_dwd.dwd_l2_logic_ic_{l2}"
        cur.execute(
            f"""
            SELECT COUNT(*) AS n,
                   SUM(CASE WHEN brand IS NULL OR TRIM(brand) = '' THEN 1 ELSE 0 END) AS brand_null,
                   COUNT(DISTINCT brand) AS dt,
                   COUNT(DISTINCT brandid) AS di
            FROM {t}
            """
        )
        r = cur.fetchone()
        cur.execute(
            f"""
            SELECT brand, brandshort, COUNT(*) AS n
            FROM {t}
            WHERE brandid IS NULL AND brand IS NOT NULL AND TRIM(brand) <> ''
            GROUP BY brand, brandshort ORDER BY n DESC LIMIT 15
            """
        )
        gaps = cur.fetchall()
        print(f"{l2}: rows={r['n']:,} brand_null={r['brand_null']} distinct_brand={r['dt']} brandid={r['di']}")
        if gaps:
            ok = False
            print("  brandid NULL:")
            for g in gaps:
                print(f"    {g['brand']!r} brandshort={g['brandshort']!r} n={g['n']}")
    conn.close()
    print("PASS" if ok else "FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
