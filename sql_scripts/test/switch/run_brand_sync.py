#!/usr/bin/env python3
"""Windows 友好：sync dim_std_brand → test_dim（不写 prod）。"""
from __future__ import annotations

import os
import sys
from pathlib import Path

import pymysql

HERE = Path(__file__).resolve().parent
INDUCTOR = HERE.parent / "inductor" / "run_brand_sync.py"
ENV = HERE.parents[1] / "local.env"


def load_env() -> None:
    for line in ENV.read_text(encoding="utf-8").splitlines():
        if line.strip().startswith("export "):
            k, _, v = line.strip()[7:].partition("=")
            os.environ[k] = v.strip().strip("'").strip('"')


def already_synced() -> bool:
    load_env()
    conn = pymysql.connect(
        host=os.environ["MYSQL_HOST"],
        port=int(os.environ.get("MYSQL_PORT", "9030")),
        user=os.environ["MYSQL_USER"],
        password=os.environ["MYSQL_PASSWORD"],
        charset="utf8mb4",
    )
    cur = conn.cursor()
    try:
        cur.execute("SELECT COUNT(*) FROM test_dim.dim_std_brand")
        n = cur.fetchone()[0]
    except Exception:
        n = 0
    conn.close()
    return n > 500


def main() -> int:
    if already_synced():
        print("test_dim.dim_std_brand 已存在，跳过 sync")
        return 0
    if not INDUCTOR.exists():
        print(f"缺少 {INDUCTOR}")
        return 1
    import subprocess
    return subprocess.run([sys.executable, str(INDUCTOR)], check=False).returncode


if __name__ == "__main__":
    raise SystemExit(main())
