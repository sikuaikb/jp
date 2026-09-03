#!/usr/bin/env python3
"""circuit_protection 阶段 1：test_dim + test_dwd 端到端（ICPDF · 不写 prod）。"""
from __future__ import annotations

import os
import re
import subprocess
import sys
from pathlib import Path

import pymysql

HERE = Path(__file__).resolve().parent
SQL_ROOT = HERE.parents[1]
ENV = SQL_ROOT / "local.env"

GATE_BASELINE = 70_662


def load_env() -> None:
    for line in ENV.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line.startswith("export "):
            k, _, v = line[7:].partition("=")
            os.environ[k] = v.strip().strip("'").strip('"')


def connect():
    return pymysql.connect(
        host=os.environ["MYSQL_HOST"],
        port=int(os.environ.get("MYSQL_PORT", "9030")),
        user=os.environ["MYSQL_USER"],
        password=os.environ["MYSQL_PASSWORD"],
        charset="utf8mb4",
        autocommit=True,
        cursorclass=pymysql.cursors.DictCursor,
    )


def split_sql(text: str) -> list[str]:
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.DOTALL)
    parts: list[str] = []
    buf: list[str] = []
    for line in text.splitlines():
        buf.append(line)
        if re.sub(r"^\s*--.*$", "", line).rstrip().endswith(";"):
            stmt = "\n".join(buf).strip().rstrip(";").strip()
            if stmt:
                parts.append(stmt)
            buf = []
    return parts


def exec_file(cur, path: Path) -> None:
    print(f"==> {path.name}")
    for stmt in split_sql(path.read_text(encoding="utf-8")):
        cur.execute(stmt)


def main() -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    load_env()

    print("=== Step 1: load test_dim ===")
    subprocess.run(
        [sys.executable, str(HERE / "load_seed_circuit_protection.py"), "--db", "test_dim"],
        check=True,
    )

    conn = connect()
    cur = conn.cursor()
    cur.execute("SET query_timeout = 600")
    cur.execute("SET enable_local_shuffle_agg = false")

    print("\n=== Step 2: test_dwd classify build ===")
    exec_file(cur, HERE / "dwd_component_class_circuit_protection.sql")
    exec_file(cur, HERE / "build_dwd_icpdf_component_class_circuit_protection.sql")

    cur.execute(
        "SELECT COUNT(DISTINCT id) AS n FROM test_dwd.dwd_component_class_circuit_protection WHERE data_source='icpdf'"
    )
    n = cur.fetchone()["n"]
    print(f"\n=== 分类行数: {n:,}（gate 基线 {GATE_BASELINE:,}）===")

    cur.execute(
        """
        SELECT l3_code, l2_code, COUNT(DISTINCT id) AS c
        FROM test_dwd.dwd_component_class_circuit_protection
        WHERE data_source = 'icpdf'
        GROUP BY l3_code, l2_code
        ORDER BY c DESC
        """
    )
    print("\nL3 分布:")
    for r in cur.fetchall():
        print(f"  {r['l2_code']:<40} {r['l3_code']:<28} {r['c']:>8,}")

    cur.execute(
        """
        SELECT COUNT(DISTINCT id) AS n FROM dwd.dwd_icpdf_component_param
        WHERE category IN ('TVS二极管','保险丝','热熔断路器/开关/保险丝','电路保护器件','硅浪涌保护器')
           OR category2 IN ('电熔丝','断路器','硅浪涌保护器','电信保护电路')
        """
    )
    gate_n = cur.fetchone()["n"]
    unclassified = gate_n - n
    print(f"\n未分类（gate 内）: {unclassified:,} / {gate_n:,}")

    if n < 50_000:
        print("\n[FAIL] 分类行数过低")
        conn.close()
        return 1
    if unclassified > gate_n * 0.05:
        print(f"\n[WARN] 未分类比例 {unclassified / gate_n:.1%} 偏高")

    print("\n[OK] circuit_protection ICPDF 阶段 1 完成（test_dim / test_dwd）")
    conn.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
