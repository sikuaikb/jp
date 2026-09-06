#!/usr/bin/env python3
"""logic_ic gate 遗漏探查：category_in 未覆盖但应在逻辑 IC 池内的 SKU。"""
from __future__ import annotations

import os
import sys
from pathlib import Path

import pymysql

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "seed"))
from gate_config import CATEGORY_EXPLICIT_OUT, CATEGORY_INCLUDE  # noqa: E402

ENV = Path(__file__).resolve().parents[3] / "local.env"

USER_LOGIC_LEAVES = [
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

EXCLUDE_EVAL_SQL = "p.category NOT LIKE '%%评估板%%' AND p.category NOT LIKE '%%开发套件%%'"


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

    ph_inc = ",".join(["%s"] * len(CATEGORY_INCLUDE))
    ph_user = ",".join(["%s"] * len(USER_LOGIC_LEAVES))
    ph_out = ",".join(["%s"] * len(CATEGORY_EXPLICIT_OUT))
    out_cats = [x["category"] for x in CATEGORY_EXPLICIT_OUT]

    # 1) 用户 12 叶 vs gate
    print("=== 1. DK「逻辑」12 叶 vs 当前 gate ===\n")
    missing_from_gate: list[tuple[str, int]] = []
    for cat in USER_LOGIC_LEAVES:
        cur.execute(
            f"SELECT COUNT(*) n FROM dwd.dwd_digikey_component_param p WHERE category=%s AND {EXCLUDE_EVAL_SQL}",
            (cat,),
        )
        n = cur.fetchone()["n"]
        mark = "✓" if cat in CATEGORY_INCLUDE else "✗"
        print(f"  {mark}  {n:>6,}  {cat}")
        if cat not in CATEGORY_INCLUDE and n > 0:
            missing_from_gate.append((cat, n))

    cur.execute(
        f"SELECT COUNT(*) n FROM dwd.dwd_digikey_component_param p WHERE category IN ({ph_inc}) AND {EXCLUDE_EVAL_SQL}",
        CATEGORY_INCLUDE,
    )
    gate_n = cur.fetchone()["n"]
    cur.execute(
        f"SELECT COUNT(*) n FROM dwd.dwd_digikey_component_param p WHERE category IN ({ph_user}) AND {EXCLUDE_EVAL_SQL}",
        USER_LOGIC_LEAVES,
    )
    user12_n = cur.fetchone()["n"]
    print(f"\n  gate 已收: {gate_n:,} / 用户12叶合计: {user12_n:,}  差额: {user12_n - gate_n:,}")

    # 2) category_info 路径 IC>逻辑>叶子，但 category 不在 gate
    print("\n=== 2. category_info 含「逻辑」第三段 · 未在 gate 的叶子 ===\n")
    cur.execute(
        f"""
        SELECT p.category, COUNT(*) AS n
        FROM dwd.dwd_digikey_component_param p
        WHERE p.category_info IS NOT NULL
          AND get_json_string(p.category_info, '$[1]') = '逻辑'
          AND p.category NOT IN ({ph_inc})
          AND {EXCLUDE_EVAL_SQL}
        GROUP BY p.category
        ORDER BY n DESC
        """
    )
    path_miss = cur.fetchall()
    if path_miss:
        for r in path_miss:
            deliberate = r["category"] in [x["category"] for x in CATEGORY_EXPLICIT_OUT] or r["category"] in (
                "FIFO 存储器", "多谐振荡器", "奇偶校验发生器和校验器", "通用总线功能"
            )
            tag = "刻意不收" if deliberate or r["category"] not in CATEGORY_INCLUDE else "?"
            print(f"  {r['n']:>6,}  [{tag}]  {r['category']}")
    else:
        print("  (无 — 或 category_info JSON 路径不可用)")

    # fallback: array_contains style
    cur.execute(
        f"""
        SELECT p.category, COUNT(*) AS n
        FROM dwd.dwd_digikey_component_param p
        WHERE CAST(p.category_info AS VARCHAR) LIKE '%逻辑%'
          AND p.category NOT IN ({ph_inc})
          AND {EXCLUDE_EVAL_SQL}
        GROUP BY p.category
        ORDER BY n DESC
        LIMIT 25
        """
    )
    print("\n=== 3. category_info 文本含「逻辑」· 未在 gate TOP ===\n")
    for r in cur.fetchall():
        in_user12 = r["category"] in USER_LOGIC_LEAVES
        in_explicit = r["category"] in out_cats
        if in_user12 and r["category"] not in CATEGORY_INCLUDE:
            tag = "用户12叶·未收"
        elif in_explicit:
            tag = "刻意不收"
        elif "评估" in r["category"] or "开发套件" in r["category"]:
            tag = "评估/套件"
        else:
            tag = "其他"
        print(f"  {r['n']:>6,}  [{tag}]  {r['category']}")

    # 3) 邻近误收风险：gate 内是否有非逻辑路径
    print("\n=== 4. gate 内 category_info 非「逻辑」路径（误收风险）===\n")
    cur.execute(
        f"""
        SELECT get_json_string(p.category_info, '$[1]') AS l2_path, p.category, COUNT(*) n
        FROM dwd.dwd_digikey_component_param p
        WHERE p.category IN ({ph_inc})
          AND p.category_info IS NOT NULL
          AND get_json_string(p.category_info, '$[1]') IS NOT NULL
          AND get_json_string(p.category_info, '$[1]') <> '逻辑'
        GROUP BY 1, 2 ORDER BY n DESC LIMIT 15
        """
    )
    wrong_path = cur.fetchall()
    if wrong_path:
        for r in wrong_path:
            print(f"  {r['n']:>6,}  path={r['l2_path']!r}  {r['category']}")
    else:
        print("  无（gate 内叶子均落在 IC>逻辑 下）")

    # 5) 逻辑 IC 在 gate 外、也不在用户12叶、也不在 explicit_out
    print("\n=== 5. 潜在遗漏：逻辑路径 SKU 既不在 gate 也不在 explicit_out ===\n")
    cur.execute(
        f"""
        SELECT p.category, COUNT(*) n
        FROM dwd.dwd_digikey_component_param p
        WHERE CAST(p.category_info AS VARCHAR) LIKE '%"逻辑"%'
          AND p.category NOT IN ({ph_inc})
          AND p.category NOT IN ({ph_out})
          AND {EXCLUDE_EVAL_SQL}
        GROUP BY 1 ORDER BY n DESC
        """
    )
    gap = cur.fetchall()
    total_gap = 0
    for r in gap:
        total_gap += r["n"]
        print(f"  {r['n']:>6,}  {r['category']}")
    print(f"\n  潜在遗漏合计: {total_gap:,} SKU")

    conn.close()


if __name__ == "__main__":
    main()
