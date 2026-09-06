#!/usr/bin/env python3
"""应用 logic_ic 品牌增量 SQL，并重建 v_std_brand_alias。"""
from __future__ import annotations

import argparse
import os
import re
import sys
from pathlib import Path

import pymysql

sys.stdout.reconfigure(encoding="utf-8")

HERE = Path(__file__).resolve().parent
SQL_ROOT = HERE.parents[2]
ATTR = SQL_ROOT / "2.attribute_standard"
SUPP = HERE / "apply_brand_supplement_logic_ic.sql"


def load_env() -> None:
    for line in (SQL_ROOT / "local.env").read_text(encoding="utf-8").splitlines():
        if line.strip().startswith("export "):
            k, _, v = line.strip()[7:].partition("=")
            os.environ[k] = v.strip().strip("'").strip('"')


def stmts_from(path: Path, db: str) -> list[str]:
    text = path.read_text(encoding="utf-8-sig").replace("dim.", f"{db}.")
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.DOTALL)
    return [s.strip() for s in text.split(";") if s.strip()]


def apply_db(db: str) -> None:
    conn = pymysql.connect(
        host=os.environ["MYSQL_HOST"],
        port=int(os.environ.get("MYSQL_PORT", "9030")),
        user=os.environ["MYSQL_USER"],
        password=os.environ["MYSQL_PASSWORD"],
        charset="utf8mb4",
        autocommit=True,
    )
    cur = conn.cursor()
    cur.execute("SET query_timeout = 600")
    stmts = stmts_from(SUPP, db)
    for stmt in stmts:
        cur.execute(stmt)
    print(f"applied supplement -> {db} ({len(stmts)} stmts)")
    view_sql = (ATTR / "v_std_brand_alias.sql").read_text(encoding="utf-8-sig").replace("dim.", f"{db}.")
    view_sql = re.sub(r"/\*.*?\*/", "", view_sql, flags=re.DOTALL)
    for stmt in [s.strip() for s in view_sql.split(";") if s.strip()]:
        cur.execute(stmt)
    print(f"rebuilt {db}.v_std_brand_alias")
    conn.close()


def main() -> int:
    load_env()
    ap = argparse.ArgumentParser()
    ap.add_argument("--prod", action="store_true")
    ap.add_argument("--both", action="store_true", help="test_dim + prod（prod 需 ALLOW_PROD=1）")
    args = ap.parse_args()

    if args.both:
        apply_db("test_dim")
        if os.environ.get("ALLOW_PROD") != "1":
            print("prod 跳过：需 ALLOW_PROD=1")
            return 1
        apply_db("dim")
        return 0

    if args.prod and os.environ.get("ALLOW_PROD") != "1":
        print("prod 需 ALLOW_PROD=1")
        return 1
    apply_db("dim" if args.prod else "test_dim")
    return 0


if __name__ == "__main__":
    sys.exit(main())
