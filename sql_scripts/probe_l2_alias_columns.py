#!/usr/bin/env python3
"""枚举所有 dwd_l2_* 宽表的别名列，生成 ALTER TABLE RENAME COLUMN 清单。"""
from __future__ import annotations

import os
import sys
from pathlib import Path

import pymysql

sys.stdout.reconfigure(encoding="utf-8", errors="replace")

ENV = Path(__file__).resolve().parent / "local.env"
for line in ENV.read_text(encoding="utf-8").splitlines():
    if line.strip().startswith("export "):
        k, _, v = line[7:].partition("=")
        os.environ[k] = v.strip().strip("'").strip('"')

conn = pymysql.connect(
    host=os.environ["MYSQL_HOST"],
    port=int(os.environ.get("MYSQL_PORT", "9030")),
    user=os.environ["MYSQL_USER"],
    password=os.environ["MYSQL_PASSWORD"],
    charset="utf8mb4",
    cursorclass=pymysql.cursors.DictCursor,
)
cur = conn.cursor()

ALIASES = {
    "ro_hs_compliant": "rohs_compliant",
    "life_cycle_status": "lifecycle_status",
    "mounting_type": "mounting_style",
    "aec_qualified": "aec_q_level",
}

cur.execute("""
    SELECT table_name, column_name, data_type
    FROM information_schema.columns
    WHERE table_schema = 'dwd' AND table_name LIKE 'dwd_l2_%'
    ORDER BY table_name, column_name
""")
rows = cur.fetchall()

renames = []
lead_free_types = {}
for r in rows:
    t, c, dt = r["table_name"], r["column_name"], r["data_type"]
    if c in ALIASES:
        renames.append((t, c, ALIASES[c]))
    if c == "lead_free":
        lead_free_types.setdefault(dt, []).append(t)

print("=" * 70)
print("别名 → 规范名 重命名清单")
print("=" * 70)
by_alias = {}
for t, old, new in renames:
    by_alias.setdefault(old, []).append((t, new))
for old, new in ALIASES.items():
    tabs = [(t, n) for (t, o, n) in renames if o == old]
    print(f"\n{old} → {new}  ({len(tabs)} 张表)")
    for t, n in tabs:
        print(f"  {t}")

print("\n" + "=" * 70)
print("lead_free 列类型分布")
print("=" * 70)
for dt, tabs in lead_free_types.items():
    print(f"\n{dt}: {len(tabs)} 张")
    for t in tabs[:30]:
        print(f"  {t}")
    if len(tabs) > 30:
        print(f"  ... +{len(tabs)-30}")

print("\n" + "=" * 70)
print("ALTER 语句预览（前 20）")
print("=" * 70)
for t, old, new in renames[:20]:
    print(f"ALTER TABLE dwd.{t} RENAME COLUMN {old} TO {new};")
print(f"... 共 {len(renames)} 条 RENAME")

cur.close()
conn.close()
