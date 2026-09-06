#!/usr/bin/env python3
"""探查 dwd_l2_* 表 lead_free 列的实际值分布，按列类型分组。
只读，判断 varchar/double 能否安全 ALTER 到 BOOLEAN(tinyint)。"""
from __future__ import annotations

import os
from pathlib import Path
import pymysql

ENV = Path(__file__).resolve().parent / "local.env"
for line in ENV.read_text(encoding="utf-8").splitlines():
    if line.strip().startswith("export "):
        k, _, v = line[7:].partition("=")
        os.environ[k] = v.strip().strip("'").strip('"')

conn = pymysql.connect(
    host=os.environ["MYSQL_HOST"], port=9030,
    user=os.environ["MYSQL_USER"], password=os.environ["MYSQL_PASSWORD"],
    charset="utf8mb4", cursorclass=pymysql.cursors.DictCursor,
)
cur = conn.cursor()

# 1. 列出每张表的 lead_free 类型
cur.execute("""
    SELECT table_name, data_type
    FROM information_schema.columns
    WHERE table_schema='dwd' AND table_name LIKE 'dwd_l2_%' AND column_name='lead_free'
    ORDER BY data_type, table_name
""")
typed = {}
for r in cur.fetchall():
    typed.setdefault(r["data_type"], []).append(r["table_name"])

print("=== lead_free 列类型分布 ===")
for dt, tabs in typed.items():
    print(f"  {dt}: {len(tabs)} 张")

# 2. 每种类型取若干代表表，看 lead_free 的 distinct 值
def vals_for(table):
    cur.execute(f"SELECT lead_free AS v, COUNT(*) AS n FROM dwd.{table} GROUP BY lead_free ORDER BY n DESC LIMIT 15")
    return cur.fetchall()

print("\n=== varchar 表 lead_free 值分布（取 6 张代表）===")
for t in typed.get("varchar", [])[:6]:
    print(f"\n-- {t}")
    for r in vals_for(t):
        print(f"   {str(r['v'])!r:30s} {r['n']:>8,}")

print("\n=== tinyint 表 lead_free 值分布（取 4 张代表）===")
for t in typed.get("tinyint", [])[:4]:
    print(f"\n-- {t}")
    for r in vals_for(t):
        print(f"   {str(r['v'])!r:30s} {r['n']:>8,}")

print("\n=== double 表 lead_free 值分布（isolator 系，全部 4 张）===")
for t in typed.get("double", []):
    print(f"\n-- {t}")
    for r in vals_for(t):
        print(f"   {str(r['v'])!r:30s} {r['n']:>8,}")

# 3. 全局 distinct 值汇总（跨所有 varchar 表，看是否统一枚举）
print("\n=== 全部 varchar 表 lead_free distinct 值全局汇总 ===")
union = []
for t in typed.get("varchar", []):
    cur.execute(f"SELECT DISTINCT lead_free FROM dwd.{t} WHERE lead_free IS NOT NULL")
    for r in cur.fetchall():
        union.append(r["lead_free"])
from collections import Counter
out = Path(__file__).resolve().parent / "artifacts" / "lead_free_value_dist.tsv"
lines = ["value\ttables_with_value"]
for v, n in Counter(union).most_common(40):
    lines.append(f"{v}\t{n}")
    print(f"   {str(v)!r:30s} 出现于 {n} 张表")
out.parent.mkdir(parents=True, exist_ok=True)
out.write_text("\n".join(lines), encoding="utf-8")
print(f"\nwritten -> {out}")

cur.close()
conn.close()

