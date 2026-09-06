#!/usr/bin/env python3
"""CONTRIB Step 2：rule_id 须满足 ^logic_ic_ 或 ^gate_logic_ic_（对齐 amplifier_dk_* 模式）。"""
from __future__ import annotations

import csv
import os
import re
import sys
from pathlib import Path

import pymysql

L1 = "logic_ic"
HERE = Path(__file__).resolve().parents[1]
SQL_ROOT = HERE.parents[1]
CSV_PATH = HERE / "seed" / f"dim_l3_classify_rule_{L1}.csv"
OK = re.compile(rf"^(?:gate_{L1}_|{L1}_)")


def load_env() -> None:
    for line in (SQL_ROOT / "local.env").read_text(encoding="utf-8").splitlines():
        if line.strip().startswith("export "):
            k, _, v = line.strip()[7:].partition("=")
            os.environ[k] = v.strip().strip("'").strip('"')


def check_rows(rows: list[tuple[str, str]]) -> list[tuple[str, int]]:
    bad: dict[str, int] = {}
    for rule_id, _kind in rows:
        if not OK.match(rule_id):
            bad[rule_id] = bad.get(rule_id, 0) + 1
    return sorted(bad.items(), key=lambda x: (-x[1], x[0]))


def main() -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    print(f"=== {L1} rule_id 命名检查 (CONTRIB Step 2) ===\n")

    csv_rows: list[tuple[str, str]] = []
    with CSV_PATH.open(encoding="utf-8", newline="") as f:
        for r in csv.DictReader(f):
            csv_rows.append((r["rule_id"], r.get("rule_kind", "")))
    csv_bad = check_rows(csv_rows)
    print(f"seed CSV ({CSV_PATH.name}):")
    if csv_bad:
        for rid, n in csv_bad:
            print(f"  FAIL  {rid}  ({n} 行)")
    else:
        distinct = len({rid for rid, _ in csv_rows})
        print(f"  PASS  {distinct} distinct rule_id，均匹配 ^({L1}_|gate_{L1}_)")

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
        SELECT rule_id, rule_kind, COUNT(*) AS n
        FROM test_dim.dim_l3_classify_rule_{L1}
        GROUP BY 1, 2
        """
    )
    db_rows = [(r["rule_id"], r["rule_kind"]) for r in cur.fetchall()]
    db_bad = check_rows(db_rows)
    print(f"\ntest_dim.dim_l3_classify_rule_{L1}:")
    if db_bad:
        for rid, n in db_bad:
            print(f"  FAIL  {rid}  ({n} 行)")
    else:
        distinct = len({rid for rid, _ in db_rows})
        print(f"  PASS  {distinct} distinct rule_id")
    conn.close()

    ok = not csv_bad and not db_bad
    print("\n" + ("PASS" if ok else "FAIL"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
