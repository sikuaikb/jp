#!/usr/bin/env python3
"""Windows 友好：sync_dim_std_brand prod（ods + manual_extra → dim_std_brand → view）"""
from __future__ import annotations

import argparse
import os
import re
import sys
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")

ROOT = Path(__file__).resolve().parents[2]
ATTR = ROOT / "2.attribute_standard"
ENV = ROOT / "local.env"

for line in ENV.read_text(encoding="utf-8").splitlines():
    if line.strip().startswith("export "):
        k, _, v = line[7:].partition("=")
        os.environ[k] = v.strip().strip("'\"")

parser = argparse.ArgumentParser()
parser.add_argument("--prod", action="store_true")
args = parser.parse_args()

if args.prod and os.environ.get("ALLOW_PROD") != "1":
    print("需要 ALLOW_PROD=1")
    sys.exit(1)

db = "dim" if args.prod else "test_dim"

import pymysql

conn = pymysql.connect(
    host=os.environ["MYSQL_HOST"], port=int(os.environ["MYSQL_PORT"]),
    user=os.environ["MYSQL_USER"], password=os.environ["MYSQL_PASSWORD"],
    charset="utf8mb4", autocommit=True,
)
cur = conn.cursor()

def run_file(name: str):
    text = (ATTR / name).read_text(encoding="utf-8")
    text = text.replace("dim.", f"{db}.")
    # strip block comments
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.DOTALL)
    stmts = [s.strip() for s in text.split(";") if s.strip()]
    print(f"==> {name} -> {db} ({len(stmts)} stmts)")
    for i, stmt in enumerate(stmts, 1):
        try:
            cur.execute(stmt)
        except Exception as e:
            print(f"  FAIL stmt {i}/{len(stmts)}: {e}")
            print(stmt[:500])
            raise

for f in ("dim_std_brand.sql", "dim_std_brand_manual_extra.sql", "v_std_brand_alias.sql"):
    run_file(f)

cur.execute(f"SELECT COUNT(*) FROM {db}.dim_std_brand")
print("dim_std_brand rows:", cur.fetchone()[0])
cur.execute(
    f"SELECT COUNT(*) FROM {db}.v_std_brand_alias "
    f"WHERE brand_key IN ('GOWANDA ELECTRONICS','CODACA','FRONTIER')"
)
print("spot check alias hits:", cur.fetchall())
conn.close()
print("Done.")
