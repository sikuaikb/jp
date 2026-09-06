#!/usr/bin/env python3
"""DigiKey 逻辑 IC 相关 category 探查（prod 只读）。"""
from __future__ import annotations

import os
from pathlib import Path

import pymysql

SQL_ROOT = Path(__file__).resolve().parents[3]
ENV = SQL_ROOT / "local.env"

KEYWORDS = [
    "逻辑",
    "门",
    "触发",
    "锁存",
    "寄存",
    "移位",
    "计数",
    "多路",
    "复用",
    "编解码",
    "比较器",
    "缓冲",
    "收发",
    "电平转换",
    "总线开关",
    "FIFO",
    "可编程",
]


def load_env() -> None:
    for line in ENV.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line.startswith("export "):
            k, _, v = line[7:].partition("=")
            os.environ[k] = v.strip().strip("'").strip('"')


def main() -> None:
    load_env()
    conn = pymysql.connect(
        host=os.environ["MYSQL_HOST"],
        port=int(os.environ.get("MYSQL_PORT", "9030")),
        user=os.environ["MYSQL_USER"],
        password=os.environ["MYSQL_PASSWORD"],
        charset="utf8mb4",
        cursorclass=pymysql.cursors.DictCursor,
    )
    cur = conn.cursor()

    print("=== category 含「逻辑/门/触发…」关键词 (TOP 80) ===\n")
    cond = " OR ".join(f"p.category LIKE %s" for _ in KEYWORDS)
    params = [f"%{k}%" for k in KEYWORDS]
    cur.execute(
        f"""
        SELECT p.category, COUNT(*) AS n
        FROM dwd.dwd_digikey_component_param p
        WHERE ({cond})
        GROUP BY p.category
        ORDER BY n DESC
        LIMIT 80
        """,
        params,
    )
    total = 0
    for r in cur.fetchall():
        total += r["n"]
        print(f"  {r['n']:>7,}  {r['category']}")
    print(f"\n  (以上合计约 {total:,} 行)")

    print("\n=== category2 含「逻辑」 (TOP 30) ===\n")
    cur.execute(
        """
        SELECT p.category2, COUNT(*) AS n
        FROM dwd.dwd_digikey_component_param p
        WHERE p.category2 LIKE '%逻辑%'
        GROUP BY p.category2 ORDER BY n DESC LIMIT 30
        """
    )
    for r in cur.fetchall():
        print(f"  {r['n']:>7,}  {r['category2']}")

    print("\n=== 精确叶子：集成电路 > 逻辑 (若存在) ===\n")
    cur.execute(
        """
        SELECT p.category, COUNT(*) AS n
        FROM dwd.dwd_digikey_component_param p
        WHERE p.category LIKE '逻辑%'
           OR p.category LIKE '%逻辑 -%'
        GROUP BY p.category ORDER BY n DESC
        """
    )
    for r in cur.fetchall():
        print(f"  {r['n']:>7,}  {r['category']}")

    conn.close()


if __name__ == "__main__":
    main()
