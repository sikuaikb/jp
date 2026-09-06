#!/usr/bin/env python3
"""prod 只读探测 logic_ic gate v1 基线。"""
from __future__ import annotations

import os
import sys
from pathlib import Path

import pymysql

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "seed"))
from gate_config import (  # noqa: E402
    CATEGORY_EXPLICIT_OUT,
    CATEGORY_INCLUDE,
    CATEGORY_INCLUDE_GROUPS,
    EXCLUDE_CATEGORY_NOT_LIKE,
)

LOCAL_ENV = Path(__file__).resolve().parents[3] / "local.env"


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


def build_include_sql() -> str:
    cats = ", ".join(f"'{sql_quote(c)}'" for c in CATEGORY_INCLUDE)
    return f"p.category IN ({cats})"


def build_exclude_sql() -> str:
    if not EXCLUDE_CATEGORY_NOT_LIKE:
        return "FALSE"
    return " OR ".join(
        f"p.category LIKE '{sql_quote(p)}'" for p in EXCLUDE_CATEGORY_NOT_LIKE
    )


def main() -> None:
    load_env()
    include = build_include_sql()
    exclude = build_exclude_sql()

    conn = pymysql.connect(
        host=os.environ["MYSQL_HOST"],
        port=int(os.environ.get("MYSQL_PORT", "9030")),
        user=os.environ["MYSQL_USER"],
        password=os.environ["MYSQL_PASSWORD"],
        charset="utf8mb4",
        cursorclass=pymysql.cursors.DictCursor,
    )
    cur = conn.cursor()

    print("=== logic_ic gate v1 · DigiKey prod param ===\n")
    print("公式: gate_pass = category_in − category NOT LIKE (评估板/开发套件)\n")

    cur.execute(f"SELECT COUNT(*) AS n FROM dwd.dwd_digikey_component_param p WHERE {include}")
    n_inc = cur.fetchone()["n"]

    cur.execute(
        f"""
        SELECT COUNT(*) AS n FROM dwd.dwd_digikey_component_param p
        WHERE ({include}) AND ({exclude})
        """
    )
    n_exc = cur.fetchone()["n"]
    n_pass = n_inc - n_exc

    print(f"{'gate_include (G1 category_in)':<35} {n_inc:>8,}")
    print(f"{'gate_exclude (X2 NOT LIKE)':<35} {n_exc:>8,}")
    print(f"{'gate_pass':<35} {n_pass:>8,}")

    print("\n--- 按 L2 分组命中 ---")
    for grp in CATEGORY_INCLUDE_GROUPS:
        cats = ", ".join(f"'{sql_quote(c)}'" for c in grp["categories"])
        cur.execute(
            f"""
            SELECT COUNT(*) AS n FROM dwd.dwd_digikey_component_param p
            WHERE p.category IN ({cats})
              AND NOT ({exclude})
            """
        )
        n = cur.fetchone()["n"]
        print(f"  {n:>7,}  {grp['rule_id']:<42} {grp['l2_code']}")

    print("\n--- gate_pass by category ---")
    cur.execute(
        f"""
        SELECT p.category, COUNT(*) AS n
        FROM dwd.dwd_digikey_component_param p
        WHERE ({include}) AND NOT ({exclude})
        GROUP BY p.category ORDER BY n DESC
        """
    )
    for r in cur.fetchall():
        print(f"  {r['n']:>7,}  {r['category']}")

    print("\n--- 白名单外 · 明确不纳入（SKU 数）---")
    for item in CATEGORY_EXPLICIT_OUT:
        cur.execute(
            "SELECT COUNT(*) AS n FROM dwd.dwd_digikey_component_param WHERE category = %s",
            (item["category"],),
        )
        n = cur.fetchone()["n"]
        print(f"  {n:>7,}  {item['category']:<45} # {item['reason']}")

    conn.close()


if __name__ == "__main__":
    main()
