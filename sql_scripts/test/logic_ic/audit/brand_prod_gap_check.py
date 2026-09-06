#!/usr/bin/env python3
"""对比 logic_ic 试点 brandshort 在 prod/test_dim 品牌字典中的覆盖。"""
from __future__ import annotations

import os
import sys
from pathlib import Path

import pymysql

sys.stdout.reconfigure(encoding="utf-8")

HERE = Path(__file__).resolve().parent
SQL_ROOT = HERE.parents[2]

LOGIC_IC_ALIASES = [
    "QUALITY SEMICONDUCTOR",
    "IDT, INTEGRATED DEVICE TECHNOLOGY INC",
    "ADVANCED MICRO DEVICES",
    "RUNIC TECHNOLOGY",
    "ROCHESTER ELECTRONICS, LLC",
    "FLIP ELECTRONICS",
    "ADSANTEC",
    "TAEJIN",
    "EVVO",
    "PANJIT INTERNATIONAL INC.",
    "MICREL INC.",
]

LOGIC_IC_NEW_IDS = [9000557, 9000558, 9000559, 9000560, 9000561]


def load_env() -> None:
    for line in (SQL_ROOT / "local.env").read_text(encoding="utf-8").splitlines():
        if line.strip().startswith("export "):
            k, _, v = line.strip()[7:].partition("=")
            os.environ[k] = v.strip().strip("'").strip('"')


def main() -> int:
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

    cur.execute(
        """
        SELECT DISTINCT UPPER(TRIM(p.brandshort)) AS brand_key, p.brandshort
        FROM test_dwd.dwd_component_class_logic_ic c
        JOIN dwd.dwd_digikey_component_param p ON p.id = c.id
        WHERE NULLIF(TRIM(COALESCE(p.brandshort, '')), '') IS NOT NULL
        ORDER BY brand_key
        """
    )
    pilot_keys = cur.fetchall()
    print(f"logic_ic 试点 distinct brandshort: {len(pilot_keys)}")

    for db in ("dim", "test_dim"):
        print(f"\n=== {db} ===")
        missing_alias = []
        for row in pilot_keys:
            bk = row["brand_key"]
            cur.execute(
                f"SELECT brand_id_std, canonical_name FROM {db}.v_std_brand_alias WHERE brand_key = %s",
                (bk,),
            )
            hit = cur.fetchone()
            if not hit:
                missing_alias.append(row["brandshort"])
        print(f"  试点 brandshort 未映射: {len(missing_alias)}")
        for b in missing_alias[:10]:
            print(f"    - {b}")

        missing_lc = []
        for alias in LOGIC_IC_ALIASES:
            cur.execute(
                f"SELECT brand_id_std FROM {db}.v_std_brand_alias WHERE brand_key = %s",
                (alias,),
            )
            if not cur.fetchone():
                missing_lc.append(alias)
        print(f"  logic_ic 增补 alias 缺失: {len(missing_lc)}")
        for a in missing_lc:
            print(f"    - {a}")

        missing_ids = []
        for bid in LOGIC_IC_NEW_IDS:
            cur.execute(f"SELECT name FROM {db}.dim_std_brand WHERE brand_id_std = %s", (bid,))
            if not cur.fetchone():
                missing_ids.append(bid)
        print(f"  logic_ic 新增 brand_id 缺失: {missing_ids or '无'}")

    conn.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
