#!/usr/bin/env python3
"""核查 gate_pass SKU 是否全部分到 L3，及 category↔L2/L3 一致性。"""
from __future__ import annotations

import os
import sys
from pathlib import Path

import pymysql

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "seed"))
from gate_config import (  # noqa: E402
    CATEGORY_INCLUDE,
    CATEGORY_INCLUDE_GROUPS,
    CATEGORY_L3_HINT,
    EXCLUDE_CATEGORY_NOT_LIKE,
)

LOCAL_ENV = Path(__file__).resolve().parents[3] / "local.env"

# category → 期望 L2（gate 分组）
CAT_L2: dict[str, str] = {}
for grp in CATEGORY_INCLUDE_GROUPS:
    for c in grp["categories"]:
        CAT_L2[c] = grp["l2_code"]

# category → 允许 L3（来自 CATEGORY_L3_HINT，去掉 l3_id 前缀）
CAT_ALLOWED_L3: dict[str, set[str]] = {}
for cat, hints in CATEGORY_L3_HINT.items():
    CAT_ALLOWED_L3[cat] = {h.split(" ", 1)[1] for h in hints}


def load_env() -> None:
    for line in LOCAL_ENV.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line.startswith("export "):
            line = line[7:]
        if "=" in line and not line.startswith("#"):
            k, _, v = line.partition("=")
            os.environ[k.strip()] = v.strip().strip("'").strip('"')


def sql_quote(s: str) -> str:
    return s.replace("'", "''")


def gate_where() -> str:
    cats = ", ".join(f"'{sql_quote(c)}'" for c in CATEGORY_INCLUDE)
    exc = " OR ".join(f"p.category LIKE '{sql_quote(p)}'" for p in EXCLUDE_CATEGORY_NOT_LIKE)
    return f"p.category IN ({cats}) AND NOT ({exc})"


def main() -> int:
    load_env()
    gw = gate_where()
    conn = pymysql.connect(
        host=os.environ["MYSQL_HOST"],
        port=int(os.environ.get("MYSQL_PORT", "9030")),
        user=os.environ["MYSQL_USER"],
        password=os.environ["MYSQL_PASSWORD"],
        charset="utf8mb4",
        cursorclass=pymysql.cursors.DictCursor,
    )
    cur = conn.cursor()
    ok = True

    print("=== logic_ic classify 覆盖核查 ===\n")

    # 1. gate_pass 总数
    cur.execute(f"SELECT COUNT(DISTINCT p.id) AS n FROM dwd.dwd_digikey_component_param p WHERE {gw}")
    n_gate = cur.fetchone()["n"]

    cur.execute(
        "SELECT COUNT(DISTINCT id) AS n FROM test_dwd.dwd_component_class_logic_ic WHERE data_source='digikey'"
    )
    n_cls = cur.fetchone()["n"]
    print(f"gate_pass SKU:     {n_gate:>8,}")
    print(f"classified SKU:    {n_cls:>8,}")
    if n_gate != n_cls:
        ok = False
        print("  ✗ 数量不一致")
    else:
        print("  ✓ 数量一致")

    # 2. gate 漏分
    cur.execute(
        f"""
        SELECT COUNT(DISTINCT p.id) AS n
        FROM dwd.dwd_digikey_component_param p
        WHERE {gw}
          AND p.id NOT IN (
              SELECT id FROM test_dwd.dwd_component_class_logic_ic WHERE data_source='digikey'
          )
        """
    )
    orphan = cur.fetchone()["n"]
    print(f"\ngate 漏分:         {orphan:>8,} (期望 0)")
    if orphan:
        ok = False
        cur.execute(
            f"""
            SELECT p.id, p.category, p.note_cn, p.partno
            FROM dwd.dwd_digikey_component_param p
            WHERE {gw}
              AND p.id NOT IN (
                  SELECT id FROM test_dwd.dwd_component_class_logic_ic WHERE data_source='digikey'
              )
            LIMIT 10
            """
        )
        print("  样例:")
        for r in cur.fetchall():
            print(f"    id={r['id']} cat={r['category']} note={r['note_cn']}")

    # 3. 超 gate 分类
    cur.execute(
        f"""
        SELECT COUNT(DISTINCT c.id) AS n
        FROM test_dwd.dwd_component_class_logic_ic c
        WHERE c.data_source='digikey'
          AND c.id NOT IN (
              SELECT p.id FROM dwd.dwd_digikey_component_param p WHERE {gw}
          )
        """
    )
    extra = cur.fetchone()["n"]
    print(f"超 gate 分类:      {extra:>8,} (期望 0)")
    if extra:
        ok = False

    # 4. null L3
    cur.execute(
        """
        SELECT COUNT(*) AS n FROM test_dwd.dwd_component_class_logic_ic
        WHERE l3_code IS NULL OR l3_id IS NULL OR l2_code IS NULL
        """
    )
    null_l3 = cur.fetchone()["n"]
    print(f"null L3/L2:        {null_l3:>8,} (期望 0)")
    if null_l3:
        ok = False

    # 5. category × l3 交叉表
    print("\n--- gate_pass · category × l3_code ---")
    cur.execute(
        f"""
        SELECT p.category, c.l2_code, c.l3_code, c.rule_id, COUNT(DISTINCT p.id) AS n
        FROM dwd.dwd_digikey_component_param p
        INNER JOIN test_dwd.dwd_component_class_logic_ic c
            ON c.id = p.id AND c.data_source = 'digikey'
        WHERE {gw}
        GROUP BY p.category, c.l2_code, c.l3_code, c.rule_id
        ORDER BY p.category, n DESC
        """
    )
    rows = cur.fetchall()
    cur_cat = None
    for r in rows:
        if r["category"] != cur_cat:
            cur_cat = r["category"]
            exp_l2 = CAT_L2.get(cur_cat, "?")
            allowed = CAT_ALLOWED_L3.get(cur_cat, set())
            print(f"\n[{cur_cat}]  期望 L2={exp_l2}  允许 L3={sorted(allowed)}")
        l2_ok = r["l2_code"] == CAT_L2.get(r["category"])
        l3_ok = r["l3_code"] in CAT_ALLOWED_L3.get(r["category"], set()) or not CAT_ALLOWED_L3.get(
            r["category"]
        )
        mark = "✓" if l3_ok else "✗"
        if not l3_ok:
            ok = False
        l2_note = "" if l2_ok else " [L3父L2≠gate分组]"
        print(
            f"  {mark} {r['n']:>6,}  L2={r['l2_code']:<28} L3={r['l3_code']:<22} rule={r['rule_id']}{l2_note}"
        )

    # 6. L3 父 L2 与 gate category 分组 L2 不同（分类树设计，非漏分）
    cur.execute(
        f"""
        SELECT p.category, c.l2_code, COUNT(DISTINCT p.id) AS n
        FROM dwd.dwd_digikey_component_param p
        INNER JOIN test_dwd.dwd_component_class_logic_ic c
            ON c.id = p.id AND c.data_source = 'digikey'
        WHERE {gw}
        GROUP BY p.category, c.l2_code
        """
    )
    l2_cross = []
    for r in cur.fetchall():
        exp = CAT_L2.get(r["category"])
        if r["l2_code"] != exp:
            l2_cross.append((r["category"], exp, r["l2_code"], r["n"]))
    print("\n--- L3 父 L2 与 gate category 分组 L2 不同（预期内）---")
    if l2_cross:
        total_cross = sum(x[3] for x in l2_cross)
        print(f"  共 {total_cross:,} SKU（L3 按功能挂树，非按 DK 叶 gate 分组）")
        for cat, exp, got, n in l2_cross:
            print(f"    {cat}: gate 分组 {exp} → L3 父 L2 {got} ({n:,})")
    else:
        print("  无")

    # 7. L3 超出 hint 允许集
    cur.execute(
        f"""
        SELECT p.category, c.l3_code, COUNT(DISTINCT p.id) AS n
        FROM dwd.dwd_digikey_component_param p
        INNER JOIN test_dwd.dwd_component_class_logic_ic c
            ON c.id = p.id AND c.data_source = 'digikey'
        WHERE {gw}
        GROUP BY p.category, c.l3_code
        """
    )
    l3_bad = []
    for r in cur.fetchall():
        allowed = CAT_ALLOWED_L3.get(r["category"], set())
        if allowed and r["l3_code"] not in allowed:
            l3_bad.append((r["category"], r["l3_code"], r["n"], sorted(allowed)))
    print("\n--- L3 超出 category hint 允许集 ---")
    if l3_bad:
        ok = False
        for cat, l3, n, allowed in l3_bad:
            print(f"  ✗ {cat} → {l3} ({n:,})  允许={allowed}")
    else:
        print("  ✓ 均在 hint 允许 L3 内")

    # 8. 每 category 未覆盖（gate 有、classify 无）
    print("\n--- 按 category 覆盖 ---")
    for cat in CATEGORY_INCLUDE:
        cur.execute(
            f"""
            SELECT COUNT(DISTINCT p.id) AS n_gate,
                   COUNT(DISTINCT c.id) AS n_cls
            FROM dwd.dwd_digikey_component_param p
            LEFT JOIN test_dwd.dwd_component_class_logic_ic c
                ON c.id = p.id AND c.data_source = 'digikey'
            WHERE p.category = %s
              AND p.category NOT LIKE '%%评估板%%'
              AND p.category NOT LIKE '%%开发套件%%'
            """,
            (cat,),
        )
        r = cur.fetchone()
        gap = r["n_gate"] - (r["n_cls"] or 0)
        mark = "✓" if gap == 0 else "✗"
        if gap:
            ok = False
        print(f"  {mark} {r['n_gate']:>7,} gate / {r['n_cls'] or 0:>7,} cls  gap={gap:>4}  {cat}")

    # 9. 1:1 叶子是否单一 L3
    print("\n--- 1:1 叶子 L3 纯度 ---")
    one_to_one = [
        "门和反相器",
        "门和反相器 - 多功能，可配置",
        "比较器",
        "奇偶校验发生器和校验器",
        "触发器",
        "移位寄存器",
    ]
    for cat in one_to_one:
        cur.execute(
            f"""
            SELECT c.l3_code, COUNT(DISTINCT p.id) AS n
            FROM dwd.dwd_digikey_component_param p
            INNER JOIN test_dwd.dwd_component_class_logic_ic c
                ON c.id = p.id AND c.data_source = 'digikey'
            WHERE p.category = %s
              AND p.category NOT LIKE '%%评估板%%'
              AND p.category NOT LIKE '%%开发套件%%'
            GROUP BY c.l3_code
            """,
            (cat,),
        )
        dist = cur.fetchall()
        pure = len(dist) == 1
        mark = "✓" if pure else "✗"
        if not pure:
            ok = False
        parts = ", ".join(f"{d['l3_code']}={d['n']:,}" for d in dist)
        print(f"  {mark} {cat}: {parts}")

    print("\n" + ("✅ PASS" if ok else "❌ FAIL"))
    conn.close()
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
