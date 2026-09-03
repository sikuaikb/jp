"""Verify a target dim db contains exactly what seed/*.csv would load.

Usage:
    python3 verify_seed_vs_db.py --db test_dim

Compares sha256(<canonicalized csv from db>) vs sha256(<seed csv from repo>).
Exits 0 on match, 1 on mismatch.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import os
import sys
from pathlib import Path

import pymysql

HERE = Path(__file__).resolve().parent.parent
SEED_DIR = HERE / "seed"

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


def hash_csv(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def dump_table_to_tmp(cur, db, table, columns, out_path):
    cur.execute(f"SELECT {', '.join(columns)} FROM {db}.{table} ORDER BY {columns[0]}")
    rows = cur.fetchall()
    with open(out_path, "w", newline="", encoding="utf-8") as fh:
        w = csv.writer(fh, quoting=csv.QUOTE_MINIMAL)
        w.writerow(columns)
        for row in rows:
            w.writerow([cell(v) for v in row])
    return len(rows)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--db", required=True)
    args = parser.parse_args()

    conn = pymysql.connect(
        host=os.environ["MYSQL_HOST"],
        port=int(os.environ.get("MYSQL_PORT", "9030")),
        user=os.environ["MYSQL_USER"],
        password=os.environ["MYSQL_PASSWORD"],
        charset="utf8mb4",
    )

    targets = [
        ("dim_l3_classify", CLASSIFY_COLS),
        ("dim_l3_classify_rule", RULE_COLS),
    ]
    all_ok = True
    with conn.cursor() as cur:
        for table, cols in targets:
            seed_path = SEED_DIR / f"{table}.csv"
            dump_path = Path(f"/tmp/{args.db}_{table}.csv")
            n = dump_table_to_tmp(cur, args.db, table, cols, dump_path)
            seed_hash = hash_csv(seed_path)
            db_hash = hash_csv(dump_path)
            ok = seed_hash == db_hash
            tag = "OK " if ok else "MISMATCH"
            print(f"{tag}  {args.db}.{table} rows={n}  seed_sha={seed_hash[:12]}  db_sha={db_hash[:12]}")
            if not ok:
                all_ok = False
                print(f"      diff <(head {seed_path}) <(head {dump_path})")

    sys.exit(0 if all_ok else 1)


if __name__ == "__main__":
    main()
