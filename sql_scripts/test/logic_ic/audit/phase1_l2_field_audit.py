#!/usr/bin/env python3
"""logic_ic L2 宽表关键字段填充率审计。"""
from __future__ import annotations

import argparse
import csv
import os
import sys
from pathlib import Path

import pymysql

sys.stdout.reconfigure(encoding="utf-8")

HERE = Path(__file__).resolve().parents[1]
SQL_ROOT = HERE.parents[1]
SCHEMA_CSV = HERE / "seed" / "dim_attr_schema_logic_ic.csv"

KEY_L2_ATTRS = [
    "manufacturer", "mpn", "package_case", "temp_min_c", "temp_max_c",
    "supply_voltage_min_v", "supply_voltage_max_v", "logic_series",
]


def load_env() -> None:
    env = SQL_ROOT / "local.env"
    if not env.exists():
        return
    for line in env.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line.startswith("export "):
            k, _, v = line[7:].partition("=")
            os.environ[k] = v.strip().strip("'").strip('"')


def l2_attrs_for(l2_code: str) -> list[str]:
    rows = list(csv.DictReader(SCHEMA_CSV.open(encoding="utf-8-sig")))
    attrs = [r["std_attr_code"] for r in rows if r["scope_level"] == "l2" and r["scope_code"] == l2_code]
    return [a for a in KEY_L2_ATTRS if a in attrs] or attrs[:8]


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--l2", default="combinational_logic")
    ap.add_argument("--table", default="")
    ap.add_argument("--max-null-pct", type=float, default=30.0)
    args = ap.parse_args()
    l2 = args.l2
    table = args.table or f"test_dwd.dwd_l2_logic_ic_{l2}"
    attrs = l2_attrs_for(l2)
    load_env()
    conn = pymysql.connect(
        host=os.environ["MYSQL_HOST"],
        port=int(os.environ.get("MYSQL_PORT", "9030")),
        user=os.environ["MYSQL_USER"],
        password=os.environ["MYSQL_PASSWORD"],
        charset="utf8mb4",
        cursorclass=pymysql.cursors.DictCursor,
    )
    with conn.cursor() as cur:
        cur.execute(f"SELECT COUNT(*) AS n FROM {table}")
        total = int(cur.fetchone()["n"])
        if total == 0:
            print(f"FAIL {table}: 0 行")
            return 1
        print(f"=== {table} ({total:,} 行) ===")
        cur.execute(
            f"""
            SELECT l3_code, COUNT(*) AS n
            FROM {table}
            GROUP BY l3_code ORDER BY n DESC
            """
        )
        for r in cur.fetchall():
            print(f"  L3 {r['l3_code']}: {r['n']:,}")
        fail = 0
        for col in attrs:
            cur.execute(
                f"SELECT SUM(CASE WHEN `{col}` IS NOT NULL AND TRIM(CAST(`{col}` AS VARCHAR)) <> '' "
                f"THEN 1 ELSE 0 END) AS filled FROM {table}"
            )
            filled = int(cur.fetchone()["filled"])
            pct = 100.0 * filled / total
            flag = "OK" if pct >= (100 - args.max_null_pct) else "LOW"
            if flag == "LOW":
                fail += 1
            print(f"  {col:28} {filled:6,} ({pct:5.1f}%) [{flag}]")
        cur.execute(
            f"SELECT SUM(CASE WHEN ext_attributes IS NOT NULL THEN 1 ELSE 0 END) AS n FROM {table}"
        )
        ext = int(cur.fetchone()["n"])
        print(f"  {'ext_attributes':28} {ext:6,} ({100*ext/total:5.1f}%)")
    conn.close()
    print("PASS" if fail == 0 else f"WARN {fail} 列低于 {100-args.max_null_pct:.0f}% 填充")
    return 0


if __name__ == "__main__":
    sys.exit(main())
