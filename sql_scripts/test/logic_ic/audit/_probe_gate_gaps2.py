#!/usr/bin/env python3
import os, sys
from pathlib import Path
import pymysql

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "seed"))
from gate_config import CATEGORY_INCLUDE, CATEGORY_EXPLICIT_OUT

ENV = Path(__file__).resolve().parents[3] / "local.env"
for line in ENV.read_text(encoding="utf-8").splitlines():
    if line.strip().startswith("export "):
        k, _, v = line.strip()[7:].partition("=")
        os.environ[k] = v.strip().strip("'").strip('"')

out_cats = [x["category"] for x in CATEGORY_EXPLICIT_OUT]
ph_inc = ",".join(["%s"] * len(CATEGORY_INCLUDE))
ph_out = ",".join(["%s"] * len(out_cats))

conn = pymysql.connect(
    host=os.environ["MYSQL_HOST"], port=9030,
    user=os.environ["MYSQL_USER"], password=os.environ["MYSQL_PASSWORD"],
    charset="utf8mb4", cursorclass=pymysql.cursors.DictCursor,
)
cur = conn.cursor()

print("=== gate 内 category_info 样本（确认落在逻辑路径）===\n")
for cat in CATEGORY_INCLUDE[:3]:
    cur.execute(
        "SELECT category_info FROM dwd.dwd_digikey_component_param WHERE category=%s LIMIT 1",
        (cat,),
    )
    r = cur.fetchone()
    print(f"  {cat}: {r['category_info']}")

print("\n=== IC>逻辑 路径 · 不在 gate 也不在 explicit_out ===\n")
cur.execute(
    f"""
    SELECT p.category, COUNT(*) n
    FROM dwd.dwd_digikey_component_param p
    WHERE CAST(p.category_info AS VARCHAR) LIKE '%%逻辑%%'
      AND p.category NOT IN ({ph_inc})
      AND p.category NOT IN ({ph_out})
      AND p.category NOT LIKE '%%评估板%%'
      AND p.category NOT LIKE '%%开发套件%%'
    GROUP BY 1 ORDER BY n DESC
    """,
    (*CATEGORY_INCLUDE, *out_cats),
)
gap = cur.fetchall()
tg = sum(r["n"] for r in gap)
for r in gap:
    print(f"  {r['n']:>6,}  {r['category']}")
print(f"合计: {tg:,}")

print("\n=== 同名叶子在 gate 外、路径非逻辑（误扩风险对照）===\n")
for cat in ["驱动器，接收器，收发器", "信号缓冲器、中继器、分离器"]:
    cur.execute(
        """
        SELECT COUNT(*) n FROM dwd.dwd_digikey_component_param
        WHERE category=%s AND CAST(category_info AS VARCHAR) LIKE '%%逻辑%%'
        """,
        (cat,),
    )
    n_logic = cur.fetchone()["n"]
    cur.execute("SELECT COUNT(*) n FROM dwd.dwd_digikey_component_param WHERE category=%s", (cat,))
    n_all = cur.fetchone()["n"]
    print(f"  {cat}: total={n_all:,}  path含逻辑={n_logic:,}")

conn.close()
