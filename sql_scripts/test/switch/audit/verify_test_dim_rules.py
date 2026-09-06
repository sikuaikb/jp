#!/usr/bin/env python3
"""核对 test_dim.dim_l3_classify_rule_switch 是否已装载 ICPDF 规则（只读）。"""
from __future__ import annotations

import os
import sys
from pathlib import Path

import pymysql

HERE = Path(__file__).resolve().parent
ENV = HERE.parents[2] / "local.env"


def load_env() -> None:
    for line in ENV.read_text(encoding="utf-8").splitlines():
        if line.strip().startswith("export "):
            k, _, v = line[7:].partition("=")
            os.environ[k] = v.strip().strip("'").strip('"')


def main() -> int:
    load_env()
    conn = pymysql.connect(
        host=os.environ["MYSQL_HOST"],
        port=int(os.environ.get("MYSQL_PORT", "9030")),
        user=os.environ["MYSQL_USER"],
        password=os.environ["MYSQL_PASSWORD"],
        cursorclass=pymysql.cursors.DictCursor,
    )
    cur = conn.cursor()

    print("注意：本表应同时含 icpdf（新）+ digikey（prod 快照），load 时会 DROP 重建\n")

    cur.execute(
        """
        SELECT data_source, rule_kind, COUNT(*) c, COUNT(DISTINCT rule_id) rules
        FROM test_dim.dim_l3_classify_rule_switch
        GROUP BY data_source, rule_kind
        ORDER BY data_source, rule_kind
        """
    )
    rows = cur.fetchall()
    if not rows:
        print("[EMPTY] 请执行: python sql_scripts/test/switch/load_seed_switch.py")
        conn.close()
        return 1

    for r in rows:
        print(
            f"  {r['data_source']:8} {r['rule_kind']:8}  rows={r['c']}  rules={r['rules']}"
        )

    cur.execute(
        """
        SELECT COUNT(*) c FROM test_dim.dim_l3_classify_rule_switch
        WHERE data_source = 'digikey'
        """
    )
    dk = cur.fetchone()["c"]
    if dk == 0:
        print("\n[WARN] digikey 规则缺失！请: python seed/gen_rule_csv.py && load_seed_switch.py")
        print("  或更新快照: python seed/export_digikey_rules_from_prod.py")

    cur.execute(
        """
        SELECT COUNT(*) c FROM dim.dim_l3_classify_rule
        WHERE data_source = 'icpdf'
          AND (rule_id LIKE 'gate_switch_icpdf%' OR rule_id LIKE 'switch_icpdf%')
        """
    )
    prod_n = cur.fetchone()["c"]
    print(f"\ndim.dim_l3_classify_rule (prod · icpdf switch): {prod_n} 行（merge 前应为 0）")

    cur.execute(
        """
        SELECT COUNT(*) c FROM test_dim.dim_attr_extract_rule_switch
        WHERE data_source = 'icpdf'
        """
    )
    attr_n = cur.fetchone()["c"]
    print(
        f"test_dim.dim_attr_extract_rule_switch (icpdf): {attr_n} 行"
        " ← 属性规则表，不是分类规则"
    )

    conn.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
