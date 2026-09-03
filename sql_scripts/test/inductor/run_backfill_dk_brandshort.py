#!/usr/bin/env python3
"""prod 回填 digikey brandshort（需 ALLOW_PROD=1）"""
from __future__ import annotations

import os
import sys
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")

ROOT = Path(__file__).resolve().parents[2]
ENV = ROOT / "local.env"
SQL = ROOT / "foundation" / "backfill_digikey_brandshort.sql"

for line in ENV.read_text(encoding="utf-8").splitlines():
    if line.strip().startswith("export "):
        k, _, v = line[7:].partition("=")
        os.environ[k] = v.strip().strip("'\"")

if os.environ.get("ALLOW_PROD") != "1":
    print("需要 ALLOW_PROD=1"); sys.exit(1)

import pymysql

conn = pymysql.connect(
    host=os.environ["MYSQL_HOST"], port=int(os.environ["MYSQL_PORT"]),
    user=os.environ["MYSQL_USER"], password=os.environ["MYSQL_PASSWORD"],
    charset="utf8mb4", autocommit=True, cursorclass=pymysql.cursors.DictCursor,
)
cur = conn.cursor()

cur.execute("""
SELECT COUNT(*) n FROM dwd.dwd_digikey_component_param
WHERE (brandshort IS NULL OR TRIM(brandshort) = '')
  AND (NULLIF(TRIM(get_json_string(prajson, '$.制造商')), '') IS NOT NULL
    OR NULLIF(TRIM(get_json_string(prajson, '$.Manufacturer')), '') IS NOT NULL)
""")
before = cur.fetchone()["n"]
print(f"待回填行数（全库）: {before:,}")

text = SQL.read_text(encoding="utf-8")
stmt = "\n".join(l for l in text.splitlines() if l.strip() and not l.strip().startswith("/*") and not l.strip().startswith("*"))
cur.execute(stmt.strip().rstrip(";"))
print("UPDATE 已提交")

cur.execute("""
SELECT COUNT(*) n FROM dwd.dwd_component_class c
JOIN dwd.dwd_digikey_component_param p ON p.id = c.id
WHERE c.l1_code = 'inductor'
  AND NULLIF(TRIM(COALESCE(p.brandshort, '')), '') IS NULL
""")
print(f"inductor 仍空 brandshort: {cur.fetchone()['n']}")

conn.close()
