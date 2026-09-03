#!/usr/bin/env python3
"""模拟 ICPDF switch classify 决选（gate + classify_config 真源）。"""
from __future__ import annotations

import os
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path

import pymysql

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "seed"))
from classify_config import CLASSIFY_RULES  # noqa: E402
from gate_config import CATEGORY2_INCLUDE, CATEGORY_INCLUDE  # noqa: E402

ENV = Path(__file__).resolve().parents[3] / "local.env"
L3_CODE = {
    "150101": "tactile_switch",
    "150102": "pushbutton_switch",
    "150103": "toggle_switch",
    "150104": "slide_switch",
    "150105": "rotary_switch",
    "150106": "rocker_switch",
    "150107": "dip_switch",
    "150108": "keylock_switch",
    "150109": "mechanical_key_switch",
    "150111": "thumbwheel_switch",
    "150201": "snap_action_switch",
    "150202": "limit_switch",
    "150301": "reed_switch",
}


def load_env() -> None:
    for line in ENV.read_text(encoding="utf-8").splitlines():
        if line.strip().startswith("export "):
            k, _, v = line[7:].partition("=")
            os.environ[k] = v.strip().strip("'").strip('"')


def gate_ok(row: dict) -> bool:
    c2 = row.get("category2")
    cat = row.get("category")
    if c2 in CATEGORY2_INCLUDE:
        return True
    return cat in CATEGORY_INCLUDE


def eval_clause(fc: str, mv: str | None, row: dict) -> bool:
    if fc == "category2_eq":
        return row.get("category2") == mv
    if fc == "category_eq":
        return row.get("category") == mv
    if fc == "note_cn_regexp":
        note = row.get("note_cn") or ""
        return bool(re.search(mv, note, re.IGNORECASE))
    return False


def rule_hits(row: dict) -> list[tuple]:
    hits = []
    for cr in CLASSIFY_RULES:
        if all(eval_clause(fc, mv, row) for fc, mv, _, _ in cr["clauses"]):
            l3 = cr["l3_id"]
            hits.append(
                (
                    cr["phase"],
                    cr["rule_priority"],
                    L3_CODE[l3],
                    l3,
                    cr["rule_id"],
                )
            )
    return hits


def pick_winner(hits: list[tuple]) -> tuple | None:
    if not hits:
        return None
    return sorted(hits, key=lambda x: (-x[0], x[1], x[2]))[0]


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
    cur.execute(
        """
        SELECT id, category, category2, note_cn
        FROM dwd.dwd_icpdf_component_param
        """,
    )
    rows = [r for r in cur.fetchall() if gate_ok(r)]
    conn.close()

    by_l3: Counter = Counter()
    unclassified = 0
    rule_win: Counter = Counter()

    for row in rows:
        hits = rule_hits(row)
        win = pick_winner(hits)
        if not win:
            unclassified += 1
            continue
        by_l3[win[3]] += 1
        rule_win[win[4]] += 1

    print("=== switch ICPDF classify simulation ===")
    print(f"gate_pass: {len(rows):,}")
    print(f"classified: {len(rows) - unclassified:,}")
    print(f"unclassified: {unclassified:,}")
    print("\nL3 distribution:")
    for l3_id, cnt in sorted(by_l3.items(), key=lambda x: -x[1]):
        print(f"  {l3_id} {L3_CODE[l3_id]:30} {cnt:>8,}")

    print("\nTop winning rules:")
    for rid, cnt in rule_win.most_common(12):
        print(f"  {cnt:>8,}  {rid}")


if __name__ == "__main__":
    main()
