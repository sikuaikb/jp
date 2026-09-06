#!/usr/bin/env python3
"""构建全部 logic_ic L2 宽表并跑 phase1 审计。"""
from __future__ import annotations

import os
import re
import subprocess
import sys
from pathlib import Path

import pymysql

sys.stdout.reconfigure(encoding="utf-8")

HERE = Path(__file__).resolve().parent
SQL_ROOT = HERE.parents[1]
AUDIT = HERE / "audit"

L2_LIST = [
    "combinational_logic",
    "sequential_logic",
    "signal_buffer_driver",
]


def load_env() -> None:
    for line in (SQL_ROOT / "local.env").read_text(encoding="utf-8").splitlines():
        if line.strip().startswith("export "):
            k, _, v = line.strip()[7:].partition("=")
            os.environ[k] = v.strip().strip("'").strip('"')


def split_sql(text: str) -> list[str]:
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.DOTALL)
    parts, buf = [], []
    for line in text.splitlines():
        buf.append(line)
        if re.sub(r"^\s*--.*$", "", line).rstrip().endswith(";"):
            s = "\n".join(buf).strip().rstrip(";").strip()
            if s:
                parts.append(s)
            buf = []
    return parts


def main() -> int:
    load_env()
    subprocess.run([sys.executable, str(HERE / "gen_l2_wide_logic_ic.py")], check=True)

    conn = pymysql.connect(
        host=os.environ["MYSQL_HOST"],
        port=int(os.environ.get("MYSQL_PORT", "9030")),
        user=os.environ["MYSQL_USER"],
        password=os.environ["MYSQL_PASSWORD"],
        charset="utf8mb4",
        autocommit=True,
        cursorclass=pymysql.cursors.DictCursor,
    )
    cur = conn.cursor()
    cur.execute("SET query_timeout = 900")

    summary = []
    rc = 0
    for l2 in L2_LIST:
        ddl = HERE / f"dwd_l2_logic_ic_{l2}.sql"
        build = HERE / f"build_dwd_l2_logic_ic_{l2}.sql"
        print(f"\n=== {l2} ===")
        for path in (ddl, build):
            print(f"  -> {path.name}")
            for stmt in split_sql(path.read_text(encoding="utf-8-sig")):
                cur.execute(stmt)
        table = f"test_dwd.dwd_l2_logic_ic_{l2}"
        cur.execute(f"SELECT COUNT(*) n FROM {table}")
        n = int(cur.fetchone()["n"])
        summary.append((l2, n))
        if n == 0:
            print(f"  INFO: {table} 0 行")
            continue
        rc |= subprocess.run(
            [sys.executable, str(AUDIT / "phase1_l2_field_audit.py"), "--l2", l2],
        ).returncode

    conn.close()
    print("\n=== L2 宽表汇总 ===")
    for l2, n in summary:
        print(f"  {l2:28} {n:>8,} 行")
    total = sum(n for _, n in summary)
    print(f"  {'合计':28} {total:>8,} 行")
    return rc


if __name__ == "__main__":
    sys.exit(main())
