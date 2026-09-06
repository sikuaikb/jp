#!/usr/bin/env python3
"""Step 5 仿真：用 test_dim CP 规则覆盖 prod dim（仅 classify-merge 预演）。"""
from __future__ import annotations

import os
import sys

import pymysql

L1 = "circuit_protection"


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    conn = pymysql.connect(
        host=os.environ["MYSQL_HOST"],
        port=int(os.environ.get("MYSQL_PORT", "9030")),
        user=os.environ["MYSQL_USER"],
        password=os.environ["MYSQL_PASSWORD"],
        charset="utf8mb4",
        autocommit=True,
    )
    cur = conn.cursor()
    cur.execute(
        f"""
        DELETE FROM dim.dim_l3_classify_rule
        WHERE rule_id REGEXP '^{L1}_'
           OR rule_id REGEXP '^gate_{L1}_'
        """
    )
    print(f"deleted old dim CP rules: {cur.rowcount}")
    cur.execute(
        f"""
        INSERT INTO dim.dim_l3_classify_rule
        SELECT * FROM test_dim.dim_l3_classify_rule_{L1}
        """
    )
    print(f"inserted test_dim CP rules: {cur.rowcount}")
    conn.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
