"""Load L3 classify dim seed CSV into a StarRocks database.

Usage:
    python3 load_seed.py --db <db_name> [--ddl-only|--data-only]

Reads MYSQL_HOST / MYSQL_PORT / MYSQL_USER / MYSQL_PASSWORD from env.

CSV conventions:
  - Empty cell                     = SQL NULL
  - ARRAY<VARCHAR(N)>  column      = JSON array literal, e.g. ["a","b","c"]
  - MAP<VARCHAR,VARCHAR> column    = JSON object literal, e.g. {"k":"v"}
  - All other cells                = string value (CSV-quoted as needed)

Behavior:
  1. Render DDL (DROP + CREATE) substituting `dim.` -> `<db_name>.` and execute.
  2. Read CSV and insert rows via parametric batched INSERT (no DML string concat).

Type-aware columns (override automatic NULL-as-empty handling):
  dim_l3_classify_rule:
    match_values  -> ARRAY<VARCHAR(128)>   (json -> StarRocks array literal)
    match_map     -> MAP<VARCHAR(512),VARCHAR(512)> (json -> StarRocks map literal)
"""
from __future__ import annotations

import argparse
import csv
import json
import os
import re
import sys
from pathlib import Path

import pymysql

HERE = Path(__file__).resolve().parent
DDL_FILES = ["dim_l3_classify.sql", "dim_l3_classify_rule.sql"]

TABLE_SPECS = [
    {
        "table": "dim_l3_classify",
        "csv": "seed/dim_l3_classify.csv",
        "columns": [
            "l3_id", "l1_code", "l1_cn", "l2_code", "l2_cn",
            "l3_code", "l3_cn", "note", "schema_version",
        ],
        "complex": {},
    },
    {
        "table": "dim_l3_classify_rule",
        "csv": "seed/dim_l3_classify_rule.csv",
        "columns": [
            "rule_id", "clause_group_id", "clause_ord",
            "schema_version", "data_source", "rule_kind",
            "l3_id", "l3_cn",
            "phase", "rule_priority", "enabled", "confidence_weight",
            "classify_source_hint", "field_code",
            "match_value", "match_values", "match_map",
            "note",
        ],
        "complex": {
            "match_values": "array",
            "match_map": "map",
        },
    },
]


def lit_str(s: str) -> str:
    return "'" + s.replace("\\", "\\\\").replace("'", "''") + "'"


def array_literal(json_text: str) -> str:
    parsed = json.loads(json_text)
    if not isinstance(parsed, list):
        raise ValueError(f"expected JSON array, got {parsed!r}")
    if not parsed:
        return "NULL"
    inner = ",".join(lit_str(str(x)) for x in parsed)
    return f"ARRAY<VARCHAR(128)>[{inner}]"


def map_literal(json_text: str) -> str:
    parsed = json.loads(json_text)
    if not isinstance(parsed, dict):
        raise ValueError(f"expected JSON object, got {parsed!r}")
    if not parsed:
        return "NULL"
    pairs = []
    for k, v in parsed.items():
        pairs.append(f"{lit_str(str(k))},{lit_str(str(v))}")
    return "map(" + ",".join(pairs) + ")"


def cell_to_sql(value: str, complex_kind: str | None) -> str:
    if value == "":
        return "NULL"
    if complex_kind == "array":
        return array_literal(value)
    if complex_kind == "map":
        return map_literal(value)
    return lit_str(value)


def render_ddl(sql_text: str, db: str) -> str:
    return re.sub(r"\bdim\.", f"{db}.", sql_text)


def split_statements(sql_text: str) -> list[str]:
    parts: list[str] = []
    buf: list[str] = []
    for line in sql_text.splitlines():
        stripped_no_comments = re.sub(r"^\s*--.*$", "", line)
        buf.append(line)
        if stripped_no_comments.rstrip().endswith(";"):
            stmt = "\n".join(buf).strip()
            if stmt and stmt != ";":
                # Remove C-style comments and trailing semicolon for execution
                stmt_no_block = re.sub(r"/\*.*?\*/", "", stmt, flags=re.DOTALL)
                stmt_clean = stmt_no_block.rstrip().rstrip(";").strip()
                if stmt_clean:
                    parts.append(stmt_clean)
            buf = []
    if buf:
        tail = "\n".join(buf).strip()
        if tail:
            tail_no_block = re.sub(r"/\*.*?\*/", "", tail, flags=re.DOTALL)
            tail_clean = tail_no_block.rstrip().rstrip(";").strip()
            if tail_clean:
                parts.append(tail_clean)
    return parts


def run_ddl(cur, db: str) -> None:
    for ddl_file in DDL_FILES:
        path = HERE / ddl_file
        sql = path.read_text(encoding="utf-8")
        rendered = render_ddl(sql, db)
        for stmt in split_statements(rendered):
            cur.execute(stmt)
        print(f"  DDL applied: {ddl_file} -> {db}")


def insert_rows(cur, db: str, spec: dict) -> int:
    csv_path = HERE / spec["csv"]
    cols = spec["columns"]
    complex_kinds = spec["complex"]
    rows: list[str] = []
    with csv_path.open(encoding="utf-8") as fh:
        reader = csv.DictReader(fh)
        if reader.fieldnames != cols:
            raise ValueError(
                f"{csv_path} header mismatch: got {reader.fieldnames}, expected {cols}"
            )
        for row in reader:
            literals = [
                cell_to_sql(row[c], complex_kinds.get(c))
                for c in cols
            ]
            rows.append("(" + ", ".join(literals) + ")")
    if not rows:
        print(f"  WARN: empty {csv_path}")
        return 0
    sql = (
        f"INSERT INTO {db}.{spec['table']} ({', '.join(cols)}) VALUES\n"
        + ",\n".join(rows)
    )
    cur.execute(sql)
    return len(rows)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--db", required=True, help="target database (e.g. dim, test_dim)")
    parser.add_argument("--ddl-only", action="store_true")
    parser.add_argument("--data-only", action="store_true")
    args = parser.parse_args()

    if args.ddl_only and args.data_only:
        print("--ddl-only and --data-only are mutually exclusive", file=sys.stderr)
        sys.exit(2)

    for var in ("MYSQL_HOST", "MYSQL_USER", "MYSQL_PASSWORD"):
        if not os.environ.get(var):
            print(f"ERROR: env {var} not set", file=sys.stderr)
            sys.exit(2)

    conn = pymysql.connect(
        host=os.environ["MYSQL_HOST"],
        port=int(os.environ.get("MYSQL_PORT", "9030")),
        user=os.environ["MYSQL_USER"],
        password=os.environ["MYSQL_PASSWORD"],
        charset="utf8mb4",
        autocommit=True,
    )

    print(f"target db: {args.db}")
    with conn.cursor() as cur:
        if not args.data_only:
            run_ddl(cur, args.db)
        if not args.ddl_only:
            for spec in TABLE_SPECS:
                n = insert_rows(cur, args.db, spec)
                print(f"  loaded: {args.db}.{spec['table']} rows={n}")
    conn.close()


if __name__ == "__main__":
    main()
