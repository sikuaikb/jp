#!/usr/bin/env python3
"""抽样 gate 内多 L3 / fallback 边界 SKU。"""
from __future__ import annotations

import os
from pathlib import Path

import pymysql

LOCAL_ENV = Path(__file__).resolve().parents[3] / "local.env"


def load_env() -> None:
    for line in LOCAL_ENV.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line.startswith("export "):
            line = line[7:]
        if "=" in line and not line.startswith("#"):
            k, _, v = line.partition("=")
            os.environ[k.strip()] = v.strip().strip("'").strip('"')


def sample(cur, title: str, sql: str, n: int = 8) -> None:
    print(f"\n=== {title} ===")
    cur.execute(sql + f" LIMIT {n}")
    for r in cur.fetchall():
        print(
            f"  id={r['id']} l3={r['l3_code']} rule={r['rule_id']}\n"
            f"    cat={r['category']}\n"
            f"    note={r['note_cn']}\n"
            f"    partno={r['partno']}"
        )


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

    base = """
        SELECT p.id, p.category, p.note_cn, p.partno, c.l3_code, c.l2_code, c.rule_id
        FROM dwd.dwd_digikey_component_param p
        JOIN test_dwd.dwd_component_class_logic_ic c ON c.id=p.id AND c.data_source='digikey'
    """

    sample(
        cur,
        "专用逻辑器件 · fallback (logic_ic_dk_special_fb_v1)",
        base + " WHERE p.category='专用逻辑器件' AND c.rule_id='logic_ic_dk_special_fb_v1'",
    )
    sample(
        cur,
        "专用逻辑器件 · digital_comparator",
        base + " WHERE p.category='专用逻辑器件' AND c.l3_code='digital_comparator'",
    )
    sample(
        cur,
        "专用逻辑器件 · bus_transceiver",
        base + " WHERE p.category='专用逻辑器件' AND c.l3_code='bus_transceiver'",
    )
    sample(
        cur,
        "信号开关 · bus_switch (L3 在 signal_buffer_driver L2)",
        base + " WHERE p.category='信号开关，多路复用器，解码器' AND c.l3_code='bus_switch'",
    )
    sample(
        cur,
        "信号开关 · mux_fb fallback",
        base + " WHERE p.category='信号开关，多路复用器，解码器' AND c.rule_id='logic_ic_dk_mux_fb_v1'",
    )
    sample(
        cur,
        "缓冲叶 · note 空 (buffer_fb)",
        base
        + " WHERE p.category='缓冲器，驱动器，接收器，收发器' AND c.rule_id='logic_ic_dk_buffer_fb_v1'"
        + " AND (p.note_cn IS NULL OR p.note_cn='')",
        5,
    )

    conn.close()


if __name__ == "__main__":
    main()
