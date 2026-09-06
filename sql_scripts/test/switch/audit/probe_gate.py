#!/usr/bin/env python3
"""验证 ICPDF switch gate 白名单命中量（读 gate_config 真源）。"""
from __future__ import annotations

import os
import sys
from pathlib import Path

import pymysql

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "seed"))
from gate_config import (  # noqa: E402
    CATEGORY2_INCLUDE,
    CATEGORY_INCLUDE,
    GATE_BASELINE,
)

ENV = Path(__file__).resolve().parents[3] / "local.env"


def load_env() -> None:
    for line in ENV.read_text(encoding="utf-8").splitlines():
        if line.strip().startswith("export "):
            k, _, v = line[7:].partition("=")
            os.environ[k] = v.strip().strip("'").strip('"')


def main() -> None:
    load_env()
    conn = pymysql.connect(
        host=os.environ["MYSQL_HOST"],
        port=int(os.environ.get("MYSQL_PORT", "9030")),
        user=os.environ["MYSQL_USER"],
        password=os.environ["MYSQL_PASSWORD"],
        cursorclass=pymysql.cursors.DictCursor,
    )
    cur = conn.cursor()
    cur.execute("SET enable_local_shuffle_agg=false")

    ph = ",".join(["%s"] * len(CATEGORY2_INCLUDE))
    ph2 = ",".join(["%s"] * len(CATEGORY_INCLUDE))

    cur.execute(
        f"SELECT COUNT(*) c FROM dwd.dwd_icpdf_component_param WHERE category2 IN ({ph})",
        CATEGORY2_INCLUDE,
    )
    c2_rows = cur.fetchone()["c"]

    cur.execute(
        f"""
        SELECT COUNT(DISTINCT id) c FROM dwd.dwd_icpdf_component_param
        WHERE category2 IN ({ph}) OR category IN ({ph2})
        """,
        CATEGORY2_INCLUDE + CATEGORY_INCLUDE,
    )
    distinct_ids = cur.fetchone()["c"]

    print("=== switch ICPDF gate probe ===")
    print(f"category2_in leaves: {len(CATEGORY2_INCLUDE)}")
    print(f"category_in supplement: {len(CATEGORY_INCLUDE)}")
    print(f"rows (category2_in): {c2_rows:,}  baseline {GATE_BASELINE['rows_category2_in']:,}")
    print(f"distinct ids (union): {distinct_ids:,}  baseline {GATE_BASELINE['distinct_ids']:,}")

    cur.execute(
        f"""
        SELECT category2, COUNT(*) cnt FROM dwd.dwd_icpdf_component_param
        WHERE category2 IN ({ph})
        GROUP BY category2 ORDER BY cnt DESC
        """,
        CATEGORY2_INCLUDE,
    )
    print("\ncategory2 breakdown:")
    for r in cur.fetchall():
        print(f"  {r['cnt']:>8}  {r['category2']}")

    conn.close()


if __name__ == "__main__":
    main()
