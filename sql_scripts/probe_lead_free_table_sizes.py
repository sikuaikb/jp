#!/usr/bin/env python3
"""列出 lead_free 为 varchar/double 的表及其行数，按行数升序，供分批 ALTER。"""
from __future__ import annotations
import os
from pathlib import Path
import pymysql

ENV = Path(__file__).resolve().parent / "local.env"
for line in ENV.read_text(encoding="utf-8").splitlines():
    if line.strip().startswith("export "):
        k, _, v = line[7:].partition("=")
        os.environ[k] = v.strip().strip("'").strip('"')

conn = pymysql.connect(host=os.environ["MYSQL_HOST"], port=9030,
    user=os.environ["MYSQL_USER"], password=os.environ["MYSQL_PASSWORD"],
    charset="utf8mb4", cursorclass=pymysql.cursors.DictCursor)
c = conn.cursor()

c.execute("""
    SELECT table_name, data_type
    FROM information_schema.columns
    WHERE table_schema='dwd' AND table_name LIKE 'dwd_l2_%' AND column_name='lead_free'
""")
rows = c.fetchall()

def cnt(t):
    c.execute(f"SELECT COUNT(*) n FROM dwd.{t}")
    return c.fetchone()["n"]

res = []
for r in rows:
    res.append((r["data_type"], r["table_name"], cnt(r["table_name"])))
res.sort(key=lambda x: (x[0], x[2]))

out = Path(__file__).resolve().parent / "artifacts" / "lead_free_table_sizes.tsv"
lines = ["type\ttable\trows"]
for dt, t, n in res:
    lines.append(f"{dt}\t{t}\t{n}")
out.parent.mkdir(parents=True, exist_ok=True)
out.write_text("\n".join(lines), encoding="utf-8")

from collections import Counter
print("=== 按类型统计 ===")
for dt, n in Counter(x[0] for x in res).items():
    print(f"  {dt}: {n} 张")
print("\n=== 行数升序（前 15 小表）===")
for dt, t, n in res[:15]:
    print(f"  {dt:8s} {t:55s} {n:>10,}")
print("\n=== 行数降序（前 10 大表）===")
for dt, t, n in sorted(res, key=lambda x: -x[2])[:10]:
    print(f"  {dt:8s} {t:55s} {n:>10,}")
print(f"\nwritten -> {out}")
c.close(); conn.close()
