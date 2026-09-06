#!/usr/bin/env python3
import os
from pathlib import Path
import pymysql

ENV = Path(__file__).resolve().parents[3] / "local.env"
for line in ENV.read_text(encoding="utf-8").splitlines():
    if line.strip().startswith("export "):
        k, _, v = line.strip()[7:].partition("=")
        os.environ[k] = v.strip().strip("'").strip('"')

conn = pymysql.connect(
    host=os.environ["MYSQL_HOST"], port=9030,
    user=os.environ["MYSQL_USER"], password=os.environ["MYSQL_PASSWORD"],
    charset="utf8mb4", cursorclass=pymysql.cursors.DictCursor,
)
cur = conn.cursor()

cats = [
    "缓冲器，驱动器，接收器，收发器",
    "驱动器，接收器，收发器",
    "信号缓冲器、中继器、分离器",
    "信号开关，多路复用器，解码器",
]
ph = ",".join(["%s"] * len(cats))

for kw, label in [
    ("电平转换", "level translator"),
    ("总线开关", "bus switch"),
    ("计数器", "counter"),
    ("分频", "divider"),
    ("加法器", "adder"),
    ("ALU", "alu"),
]:
    cur.execute(
        f"""
        SELECT p.category, COUNT(*) n
        FROM dwd.dwd_digikey_component_param p
        WHERE p.category IN ({ph})
          AND (p.note_cn LIKE %s OR p.category LIKE %s)
        GROUP BY 1 ORDER BY n DESC
        """,
        (*cats, f"%{kw}%", f"%{kw}%"),
    )
    rows = cur.fetchall()
    if rows:
        print(f"\n=== {label} ({kw}) in buffer/mux cats ===")
        for r in rows:
            print(f"  {r['n']:>5}  {r['category']}")

# full param search 电平转换 under IC logic path
cur.execute(
    """
    SELECT category, COUNT(*) n FROM dwd.dwd_digikey_component_param
    WHERE note_cn LIKE '%电平转换%' OR note_cn LIKE '%Level Transl%'
    GROUP BY 1 ORDER BY n DESC LIMIT 15
    """
)
print("\n=== note 电平转换 by category ===")
for r in cur.fetchall():
    print(f"  {r['n']:>6,}  {r['category']}")

cur.execute(
    """
    SELECT category, COUNT(*) n FROM dwd.dwd_digikey_component_param
    WHERE note_cn LIKE '%总线开关%' OR note_cn LIKE '%Bus Switch%'
    GROUP BY 1 ORDER BY n DESC LIMIT 15
    """
)
print("\n=== note 总线开关 by category ===")
for r in cur.fetchall():
    print(f"  {r['n']:>6,}  {r['category']}")

conn.close()
