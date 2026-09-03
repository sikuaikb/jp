#!/usr/bin/env python3
"""生成并执行 DWD L2 别名列 → 规范名 RENAME COLUMN 迁移（StarRocks 元数据级，幂等）。"""
from __future__ import annotations

import os
from pathlib import Path
import pymysql

ENV = Path(__file__).resolve().parent / "local.env"
for line in ENV.read_text(encoding="utf-8").splitlines():
    if line.strip().startswith("export "):
        k, _, v = line[7:].partition("=")
        os.environ[k] = v.strip().strip("'").strip('"')

ALIASES = {
    "ro_hs_compliant": "rohs_compliant",
    "life_cycle_status": "lifecycle_status",
    "mounting_type": "mounting_style",
    "aec_qualified": "aec_q_level",
}

conn = pymysql.connect(
    host=os.environ["MYSQL_HOST"], port=9030,
    user=os.environ["MYSQL_USER"], password=os.environ["MYSQL_PASSWORD"],
    charset="utf8mb4", cursorclass=pymysql.cursors.DictCursor, autocommit=True,
)
cur = conn.cursor()

cur.execute("""
    SELECT table_name, column_name
    FROM information_schema.columns
    WHERE table_schema = 'dwd' AND table_name LIKE 'dwd_l2_%'
    ORDER BY table_name, column_name
""")
rows = cur.fetchall()

renames = [(r["table_name"], old, ALIASES[old]) for r in rows for old in ALIASES if r["column_name"] == old]

sql_path = Path(__file__).resolve().parent / "migrate_l2_alias_rename.sql"
lines = ["/* DWD L2 别名列 → 规范名 RENAME COLUMN（幂等；自动生成） */"]
done = 0
for t, old, new in renames:
    lines.append(f"ALTER TABLE dwd.{t} RENAME COLUMN {old} TO {new};")
sql_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
print(f"生成 {len(renames)} 条 RENAME → {sql_path.name}")

for t, old, new in renames:
    try:
        cur.execute(f"ALTER TABLE dwd.{t} RENAME COLUMN {old} TO {new}")
        done += 1
        print(f"OK  {t}  {old} -> {new}")
    except Exception as e:
        print(f"ERR {t}  {old} -> {new}  {e}")

print(f"\n完成 {done}/{len(renames)}")
cur.close()
conn.close()
