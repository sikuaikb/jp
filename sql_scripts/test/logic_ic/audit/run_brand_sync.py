#!/usr/bin/env python3
"""同步 dim_std_brand + manual_extra + v_std_brand_alias（test_dim 或 prod dim）。"""
from __future__ import annotations

import argparse
import os
import re
import sys
from pathlib import Path

import pymysql

sys.stdout.reconfigure(encoding="utf-8")

HERE = Path(__file__).resolve().parents[1]
SQL_ROOT = HERE.parents[1]
ATTR = SQL_ROOT / "2.attribute_standard"


def load_env() -> None:
    for line in (SQL_ROOT / "local.env").read_text(encoding="utf-8").splitlines():
        if line.strip().startswith("export "):
            k, _, v = line.strip()[7:].partition("=")
            os.environ[k] = v.strip().strip("'").strip('"')



def run_file(cur, db: str, name: str) -> None:
    text = (ATTR / name).read_text(encoding="utf-8-sig").replace("dim.", f"{db}.")
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.DOTALL)
    stmts = [s.strip() for s in text.split(";") if s.strip()]
    print(f"==> {name} -> {db} ({len(stmts)} stmts)")
    for i, stmt in enumerate(stmts, 1):
        try:
            cur.execute(stmt)
        except Exception as e:
            print(f"  FAIL stmt {i}/{len(stmts)}: {e}")
            print(stmt[:400])
            raise


def main() -> int:
    load_env()
    ap = argparse.ArgumentParser()
    ap.add_argument("--prod", action="store_true", help="写入 prod dim（需 ALLOW_PROD=1）")
    args = ap.parse_args()
    if args.prod and os.environ.get("ALLOW_PROD") != "1":
        print("prod 同步需 ALLOW_PROD=1")
        return 1
    db = "dim" if args.prod else "test_dim"
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
    cur.execute("SET query_timeout = 600")
    for f in ("dim_std_brand.sql", "dim_std_brand_manual_extra.sql", "v_std_brand_alias.sql"):
        run_file(cur, db, f)
    cur.execute(f"SELECT COUNT(*) AS n FROM {db}.dim_std_brand")
    print(f"{db}.dim_std_brand rows:", cur.fetchone()["n"])
    conn.close()
    print("Done.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
