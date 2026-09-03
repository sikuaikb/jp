#!/usr/bin/env python3
"""对照用户提供的 logic 叶子 vs gate v1。"""
import os
from pathlib import Path
import pymysql

ENV = Path(__file__).resolve().parents[3] / "local.env"
for line in ENV.read_text(encoding="utf-8").splitlines():
    if line.strip().startswith("export "):
        k, _, v = line.strip()[7:].partition("=")
        os.environ[k] = v.strip().strip("'").strip('"')

USER_LEAVES = [
    "缓冲器，驱动器，接收器，收发器",
    "FIFO 存储器",
    "触发器",
    "门和反相器",
    "专用逻辑器件",
    "比较器",
    "奇偶校验发生器和校验器",
    "多谐振荡器",
    "信号开关，多路复用器，解码器",
    "移位寄存器",
    "通用总线功能",
    "门和反相器 - 多功能，可配置",
]

GATE_IN = [
    "门和反相器",
    "门和反相器 - 多功能，可配置",
    "比较器",
    "信号开关，多路复用器，解码器",
    "专用逻辑器件",
    "触发器",
    "移位寄存器",
    "缓冲器，驱动器，接收器，收发器",
]

conn = pymysql.connect(
    host=os.environ["MYSQL_HOST"], port=9030,
    user=os.environ["MYSQL_USER"], password=os.environ["MYSQL_PASSWORD"],
    charset="utf8mb4", cursorclass=pymysql.cursors.DictCursor,
)
cur = conn.cursor()

print("=== 用户列表 · prod SKU 数 + category_info 校验 ===\n")
for cat in USER_LEAVES:
    cur.execute(
        "SELECT COUNT(*) n FROM dwd.dwd_digikey_component_param WHERE category = %s",
        (cat,),
    )
    n = cur.fetchone()["n"]
    in_gate = "✓ gate" if cat in GATE_IN else "— 未收"
    cur.execute(
        """
        SELECT category_info, COUNT(*) c
        FROM dwd.dwd_digikey_component_param WHERE category = %s
        GROUP BY 1 ORDER BY c DESC LIMIT 2
        """,
        (cat,),
    )
    paths = cur.fetchall()
    top_path = ""
    if paths and paths[0]["category_info"]:
        ci = paths[0]["category_info"]
        if isinstance(ci, list):
            top_path = " > ".join(ci)
        else:
            top_path = str(ci)[:80]
    print(f"  {n:>6,}  [{in_gate}]  {cat}")
    if top_path:
        print(f"           path: {top_path}")

print("\n=== 逻辑下其他叶子（用户列表外）===\n")
cur.execute(
    """
    SELECT category, COUNT(*) n
    FROM dwd.dwd_digikey_component_param
    WHERE category_info IS NOT NULL
      AND CAST(category_info AS VARCHAR) LIKE '%逻辑%'
      AND category NOT IN (%s)
    GROUP BY 1 ORDER BY n DESC LIMIT 20
    """
    % ",".join(["%s"] * len(USER_LEAVES)),
    USER_LEAVES,
)
# fallback: simpler query
cur.execute(
    """
    SELECT p.category, COUNT(*) n
    FROM dwd.dwd_digikey_component_param p
    WHERE p.category LIKE '%逻辑%'
       OR p.category IN (
         'CPLD（复杂可编程逻辑器件）','FPGA（现场可编程门阵列）',
         '可编程定时器和振荡器','驱动器，接收器，收发器'
       )
    GROUP BY 1 ORDER BY n DESC LIMIT 25
    """
)
for r in cur.fetchall():
    if r["category"] not in USER_LEAVES:
        print(f"  {r['n']:>7,}  {r['category']}")

conn.close()
