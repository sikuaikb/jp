#!/usr/bin/env python3
"""对比：去掉 ICPDF switch 的 note_cn_regexp 规则后的分类影响。"""
from __future__ import annotations

import os
import re
import sys
from collections import Counter
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

NOTE_RULE_IDS = {
    "switch_icpdf_limit_note_v1",
    "switch_icpdf_snap_note_v1",
    "switch_icpdf_base_limit_note_v1",
    "switch_icpdf_base_snap_note_v1",
}


def load_env() -> None:
    for line in ENV.read_text(encoding="utf-8").splitlines():
        if line.strip().startswith("export "):
            k, _, v = line[7:].partition("=")
            os.environ[k] = v.strip().strip("'").strip('"')


def gate_ok(row: dict) -> bool:
    c2, cat = row.get("category2"), row.get("category")
    return c2 in CATEGORY2_INCLUDE or cat in CATEGORY_INCLUDE


def eval_clause(fc: str, mv: str | None, row: dict) -> bool:
    if fc == "category2_eq":
        return row.get("category2") == mv
    if fc == "category_eq":
        return row.get("category") == mv
    if fc == "note_cn_regexp":
        return bool(re.search(mv, row.get("note_cn") or "", re.IGNORECASE))
    return False


def classify_row(row: dict, rules: list[dict]) -> tuple | None:
    hits = []
    for cr in rules:
        if all(eval_clause(fc, mv, row) for fc, mv, _, _ in cr["clauses"]):
            hits.append(
                (
                    cr["phase"],
                    cr["rule_priority"],
                    L3_CODE[cr["l3_id"]],
                    cr["l3_id"],
                    cr["rule_id"],
                )
            )
    if not hits:
        return None
    return sorted(hits, key=lambda x: (-x[0], x[1], x[2]))[0]


def main() -> None:
    load_env()
    rules_with = CLASSIFY_RULES
    rules_without = [
        r for r in CLASSIFY_RULES if r["rule_id"] not in NOTE_RULE_IDS
    ]

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
        "SELECT id, category, category2, note_cn FROM dwd.dwd_icpdf_component_param"
    )
    rows = [r for r in cur.fetchall() if gate_ok(r)]
    conn.close()

    changed = []
    l3_with: Counter = Counter()
    l3_without: Counter = Counter()
    rule_note_wins = Counter()

    for row in rows:
        w = classify_row(row, rules_with)
        wo = classify_row(row, rules_without)
        if not w or not wo:
            continue
        l3_with[w[3]] += 1
        l3_without[wo[3]] += 1
        if w[4] in NOTE_RULE_IDS:
            rule_note_wins[w[4]] += 1
        if w[3] != wo[3]:
            changed.append(
                {
                    "id": row["id"],
                    "category": row.get("category"),
                    "category2": row.get("category2"),
                    "note": (row.get("note_cn") or "")[:80],
                    "from_l3": w[3],
                    "from_rule": w[4],
                    "to_l3": wo[3],
                    "to_rule": wo[4],
                }
            )

    print("=== note_cn_regexp 影响分析（ICPDF switch · gate 内）===\n")
    print(f"gate 行数: {len(rows):,}")
    print(f"含 note 规则时 classified: {sum(l3_with.values()):,}")
    print(f"去掉 note 规则后 classified: {sum(l3_without.values()):,}")

    print("\n--- note 专规命中（当前规则赢家的行数）---")
    for rid, cnt in rule_note_wins.most_common():
        print(f"  {cnt:>6,}  {rid}")

    print("\n--- L3 分布对比 ---")
    print(f"{'L3':<12} {'with note':>12} {'no note':>12} {'delta':>10}")
    all_l3 = sorted(set(l3_with) | set(l3_without))
    for l3 in all_l3:
        a, b = l3_with[l3], l3_without[l3]
        if a or b:
            print(f"  {l3} {L3_CODE[l3]:<22} {a:>10,} {b:>10,} {b-a:>+10,}")

    print(f"\n--- L3 发生变化: {len(changed):,} 行 ---")
    by_transition: Counter = Counter()
    for c in changed:
        by_transition[(c["from_l3"], c["to_l3"])] += 1
    for (f, t), cnt in by_transition.most_common():
        print(
            f"  {cnt:>6,}  {f} {L3_CODE[f]:20} -> {t} {L3_CODE[t]:20}"
        )

    print("\n--- 变化样本（前 8 条）---")
    for c in changed[:8]:
        print(
            f"  id={c['id']} c2={c['category2']!r} "
            f"{c['from_l3']}->{c['to_l3']} note={c['note']!r}"
        )

    uncls_with = sum(1 for r in rows if not classify_row(r, rules_with))
    uncls_without = sum(1 for r in rows if not classify_row(r, rules_without))
    print(f"\n未分类: with={uncls_with}, without={uncls_without}")


if __name__ == "__main__":
    main()
