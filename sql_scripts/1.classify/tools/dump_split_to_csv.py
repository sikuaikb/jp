"""Dump a colleague's split L1 dim tables and append to seed/*.csv.

Usage:
    python3 dump_split_to_csv.py \
        --classify-table dim.dim_l3_classify_inductor \
        --rule-table     dim.dim_l3_classify_rule_inductor \
        --seed-dir       sql_scripts/1.classify/seed

Reads MYSQL_HOST / MYSQL_PORT / MYSQL_USER / MYSQL_PASSWORD from env.

CSV conventions (mirrors load_seed.py expectations):
  - Empty cell           = SQL NULL
  - ARRAY column         = JSON array literal, e.g. ["a","b"]
  - MAP column           = JSON object literal, e.g. {"k":"v"}
"""
from __future__ import annotations

import argparse
import csv
import json
import os
import sys
from pathlib import Path

import pymysql

CLASSIFY_COLS = ["l3_id", "l1_code", "l1_cn", "l2_code", "l2_cn",
                 "l3_code", "l3_cn", "note", "schema_version"]
RULE_COLS = [
    "rule_id", "clause_group_id", "clause_ord",
    "schema_version", "data_source", "rule_kind",
    "l3_id", "l3_cn",
    "phase", "rule_priority", "enabled", "confidence_weight",
    "classify_source_hint", "field_code",
    "match_value", "match_values", "match_map",
    "note",
]


def cell(v):
    if v is None:
        return ""
    if isinstance(v, (list, tuple)):
        return json.dumps(list(v), ensure_ascii=False)
    if isinstance(v, dict):
        return json.dumps(v, ensure_ascii=False)
    if isinstance(v, str):
        return v
    return str(v)


def append_rows(cur, source_table, columns, seed_path: Path):
    cur.execute(f"SELECT {', '.join(columns)} FROM {source_table} ORDER BY {columns[0]}")
    new_rows = cur.fetchall()
    existing_keys: set[tuple] = set()
    if seed_path.exists():
        with seed_path.open(encoding="utf-8") as fh:
            reader = csv.DictReader(fh)
            for row in reader:
                existing_keys.add(tuple(row[c] for c in columns[: pk_len(columns)]))
    rows_to_append = [r for r in new_rows
                      if tuple(cell(v) for v in r[: pk_len(columns)]) not in existing_keys]

    write_header = not seed_path.exists()
    with seed_path.open("a", newline="", encoding="utf-8") as fh:
        w = csv.writer(fh, quoting=csv.QUOTE_MINIMAL)
        if write_header:
            w.writerow(columns)
        for row in rows_to_append:
            w.writerow([cell(v) for v in row])

    print(f"  {source_table} -> {seed_path}: "
          f"src={len(new_rows)} appended={len(rows_to_append)} "
          f"skipped(dup-PK)={len(new_rows) - len(rows_to_append)}")


def pk_len(columns: list[str]) -> int:
    if columns[0] == "l3_id":
        return 1
    return 3


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--classify-table", required=True)
    parser.add_argument("--rule-table", required=True)
    parser.add_argument("--seed-dir", required=True)
    args = parser.parse_args()

    seed_dir = Path(args.seed_dir).resolve()
    if not seed_dir.exists():
        print(f"ERROR: seed dir not found: {seed_dir}", file=sys.stderr)
        sys.exit(2)

    conn = pymysql.connect(
        host=os.environ["MYSQL_HOST"],
        port=int(os.environ.get("MYSQL_PORT", "9030")),
        user=os.environ["MYSQL_USER"],
        password=os.environ["MYSQL_PASSWORD"],
        charset="utf8mb4",
    )
    with conn.cursor() as cur:
        append_rows(cur, args.classify_table, CLASSIFY_COLS, seed_dir / "dim_l3_classify.csv")
        append_rows(cur, args.rule_table, RULE_COLS, seed_dir / "dim_l3_classify_rule.csv")


if __name__ == "__main__":
    main()
