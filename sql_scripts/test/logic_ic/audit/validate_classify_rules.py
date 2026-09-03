#!/usr/bin/env python3
"""logic_ic 分类规则 DB 快照验收（对齐 sensor/validate_classify_rules.py）。"""
from __future__ import annotations

import os
import sys
from pathlib import Path

import pymysql

HERE = Path(__file__).resolve().parents[1]
SQL_ROOT = HERE.parents[1]
EXPECTED = 19_591


def load_env() -> None:
    for line in (SQL_ROOT / "local.env").read_text(encoding="utf-8").splitlines():
        if line.strip().startswith("export "):
            k, _, v = line.strip()[7:].partition("=")
            os.environ[k] = v.strip().strip("'").strip('"')


def main() -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
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

    cur.execute("SELECT COUNT(DISTINCT id) AS n FROM test_dwd.dwd_component_class_logic_ic")
    total = int(cur.fetchone()["n"])
    print(f"总行数: {total:,} (期望 {EXPECTED:,})")

    cur.execute(
        """
        SELECT rule_id, l3_code, COUNT(DISTINCT id) AS n
        FROM test_dwd.dwd_component_class_logic_ic
        GROUP BY 1, 2
        ORDER BY n DESC
        LIMIT 20
        """
    )
    print("\nrule_id × L3 TOP:")
    for r in cur.fetchall():
        print(f"  {r['n']:>7,}  {r['rule_id']:<35} {r['l3_code']}")

    cur.execute(
        """
        SELECT l3_id, l3_code, COUNT(DISTINCT id) AS n
        FROM test_dwd.dwd_component_class_logic_ic
        GROUP BY 1, 2
        ORDER BY n DESC
        """
    )
    print("\nL3 汇总:")
    zero_l3 = []
    for r in cur.fetchall():
        mark = "" if r["n"] > 0 else " ← 零命中"
        if r["n"] == 0:
            zero_l3.append(r["l3_code"])
        print(f"  {r['n']:>7,}  {r['l3_id']}  {r['l3_code']}{mark}")

    cur.execute(
        """
        SELECT COUNT(*) AS n FROM test_dwd.dwd_component_class_logic_ic
        WHERE l3_code IS NULL OR l3_id IS NULL
        """
    )
    null_l3 = int(cur.fetchone()["n"])
    print(f"\nnull_l3: {null_l3}")

    ok = total == EXPECTED and null_l3 == 0
    if zero_l3:
        print(f"零命中 L3（预期内见 SCOPE_DEFERRED.md）: {', '.join(zero_l3)}")
    print("\n" + ("PASS" if ok else "FAIL"))
    conn.close()
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
