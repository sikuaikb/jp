#!/usr/bin/env python3
"""logic_ic gate 候选 category 精细探查。"""
from __future__ import annotations

import os
from pathlib import Path

import pymysql

ENV = Path(__file__).resolve().parents[3] / "local.env"

CANDIDATES = [
    "门和反相器",
    "门和反相器 - 多功能，可配置",
    "触发器",
    "移位寄存器",
    "信号开关，多路复用器，解码器",
    "比较器",
    "专用逻辑器件",
    "缓冲器，驱动器，接收器，收发器",
    "驱动器，接收器，收发器",
    "信号缓冲器、中继器、分离器",
    "逻辑 - 电平转换器",
    "电平转换器",
    "电压电平转换器",
    "总线开关",
    "信号开关",
    "计数器",
    "寄存器",
    "锁存器",
    "编码器",
    "解码器",
    "多路复用器",
    "算术逻辑单元",
    "加法器",
    "FIFO 存储器",
    "CPLD（复杂可编程逻辑器件）",
    "FPGA（现场可编程门阵列）",
    "可编程定时器和振荡器",
]

EXCLUDE_PATTERNS = ["%评估板%", "%开发套件%"]


def load_env() -> None:
    for line in ENV.read_text(encoding="utf-8").splitlines():
        if line.strip().startswith("export "):
            k, _, v = line.strip()[7:].partition("=")
            os.environ[k] = v.strip().strip("'").strip('"')


def main() -> None:
    load_env()
    conn = pymysql.connect(
        host=os.environ["MYSQL_HOST"], port=9030,
        user=os.environ["MYSQL_USER"], password=os.environ["MYSQL_PASSWORD"],
        charset="utf8mb4", cursorclass=pymysql.cursors.DictCursor,
    )
    cur = conn.cursor()

    print("=== 候选 category 精确计数（含评估板）===\n")
    for cat in CANDIDATES:
        cur.execute(
            "SELECT COUNT(*) n FROM dwd.dwd_digikey_component_param WHERE category = %s",
            (cat,),
        )
        n = cur.fetchone()["n"]
        if n:
            print(f"  {n:>7,}  {cat}")

    print("\n=== LIKE 补充探查 ===\n")
    likes = ["%电平转换%", "%计数器%", "%寄存器%", "%锁存%", "%编码器%", "%解码器%", "%总线开关%"]
    for pat in likes:
        cur.execute(
            """
            SELECT category, COUNT(*) n FROM dwd.dwd_digikey_component_param
            WHERE category LIKE %s GROUP BY 1 ORDER BY n DESC LIMIT 15
            """,
            (pat,),
        )
        rows = cur.fetchall()
        if rows:
            print(f"  -- {pat} --")
            for r in rows:
                print(f"    {r['n']:>6,}  {r['category']}")

    print("\n=== 门和反相器 · category_info 样本 ===\n")
    cur.execute(
        """
        SELECT category_info, COUNT(*) n
        FROM dwd.dwd_digikey_component_param
        WHERE category = '门和反相器'
        GROUP BY 1 ORDER BY n DESC LIMIT 8
        """
    )
    for r in cur.fetchall():
        ci = r["category_info"]
        path = " > ".join(ci) if ci else ""
        print(f"  {r['n']:>6,}  {path}")

    conn.close()


if __name__ == "__main__":
    main()
