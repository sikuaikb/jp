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

for pat in ["%电平%", "%转换器%", "%总线%", "%开关%IC%", "%计数%", "逻辑%"]:
    cur.execute(
        "SELECT category, COUNT(*) n FROM dwd.dwd_digikey_component_param WHERE category LIKE %s GROUP BY 1 ORDER BY n DESC LIMIT 20",
        (pat,),
    )
    rows = cur.fetchall()
    if rows:
        print(f"\n=== category LIKE {pat!r} ===")
        for r in rows:
            print(f"  {r['n']:>7,}  {r['category']}")

# eval exclusion impact
include = [
    "门和反相器", "门和反相器 - 多功能，可配置", "触发器", "移位寄存器",
    "信号开关，多路复用器，解码器", "比较器", "专用逻辑器件",
    "缓冲器，驱动器，接收器，收发器", "驱动器，接收器，收发器",
    "信号缓冲器、中继器、分离器",
]
ph = ",".join(["%s"] * len(include))
cur.execute(
    f"SELECT COUNT(*) n FROM dwd.dwd_digikey_component_param WHERE category IN ({ph})",
    include,
)
print(f"\ninclude raw: {cur.fetchone()['n']:,}")
cur.execute(
    f"""
    SELECT COUNT(*) n FROM dwd.dwd_digikey_component_param
    WHERE category IN ({ph})
      AND category NOT LIKE '%%评估板%%'
      AND category NOT LIKE '%%开发套件%%'
    """,
    include,
)
print(f"include - eval: {cur.fetchone()['n']:,}")

# note_cn sample for 专用逻辑器件
cur.execute(
    "SELECT LEFT(note_cn,50) n, COUNT(*) c FROM dwd.dwd_digikey_component_param WHERE category='专用逻辑器件' GROUP BY 1 ORDER BY c DESC LIMIT 10"
)
print("\n专用逻辑器件 note_cn:")
for r in cur.fetchall():
    print(f"  {r['c']:4} {r['n']!r}")

conn.close()
