"""Load attribute_standard dim seed CSVs into StarRocks.

Usage:
    python3 load_seed.py --db <db_name> [--ddl-only|--data-only]

Reads MYSQL_HOST / MYSQL_PORT / MYSQL_USER / MYSQL_PASSWORD from env.

CSV conventions:
  - 空单元格 = SQL NULL
  - 所有列均为标量（VARCHAR / INT / DOUBLE / TINYINT / DATETIME）

Behavior:
  1. Render DDL (DROP + CREATE) substituting `dim.` -> `<db_name>.` and execute.
  2. Read CSV and insert rows via batched INSERT VALUES.
"""
from __future__ import annotations

import argparse
import csv
import os
import re
import sys
from pathlib import Path

import pymysql

HERE = Path(__file__).resolve().parent
DDL_FILES = [
    "dim_attr_schema.sql",
    "dim_attr_extract_rule.sql",
    "dim_unit_factor.sql",
]

TABLE_SPECS = [
    {
        "table": "dim_attr_schema",
        "csv": "seed/dim_attr_schema.csv",
        "columns": [
            "schema_version", "l1_code", "scope_level", "scope_code", "std_attr_code",
            "std_attr_cn", "unit_std", "db_type", "precision", "value_domain",
            "min_bound", "max_bound", "is_l2_common", "display_ord",
            "attr_category_cn", "attr_category_en", "note",
        ],
        "numeric": {"precision", "min_bound", "max_bound", "is_l2_common", "display_ord"},
        "quoted": {"precision"},  # backtick-escape reserved keyword
        # NOT NULL 列即使 CSV 空也写 ''（不当 NULL）
        "not_null": {
            "schema_version", "l1_code", "scope_level", "scope_code", "std_attr_code",
            "db_type", "is_l2_common",
        },
    },
    {
        "table": "dim_attr_extract_rule",
        "csv": "seed/dim_attr_extract_rule.csv",
        "columns": [
            "extract_rule_id", "data_source", "schema_version", "l1_code",
            "apply_scope_level", "apply_scope_code",
            "std_attr_code", "source_kind", "source_expr",
            "source_value_expr", "source_value_regex", "literal_std_value",
            "priority", "enabled", "value_map", "note",
        ],
        "numeric": {"priority", "enabled"},
        "quoted": set(),
        "not_null": {
            "extract_rule_id", "data_source", "schema_version", "l1_code",
            "std_attr_code", "source_kind", "source_expr",
            "priority", "enabled",
        },
        "json": {"value_map"},
    },
    {
        "table": "dim_unit_factor",
        "csv": "seed/dim_unit_factor.csv",
        "columns": ["target_unit", "unit_raw", "factor", "note"],
        "numeric": {"factor"},
        "quoted": set(),
        "not_null": {"target_unit", "unit_raw", "factor"},
    },
]


def lit_str(s: str) -> str:
    return "'" + s.replace("\\", "\\\\").replace("'", "''") + "'"


def cell_to_sql(value: str, column: str, numeric: set[str], not_null: set[str], json_cols: set[str] = None) -> str:
    # unit_std='-' 视为"无单位"，转 NULL（dim_unit_factor 不会命中 '-'，否则会把单位换算挂掉）
    if column == "unit_std" and value.strip() == "-":
        value = ""
    if value == "":
        # NOT NULL VARCHAR 列：写空字符串字面量；NULL 数值列不支持空字符串，仍写 NULL
        if column in not_null and column not in numeric:
            return "''"
        return "NULL"
    if column in numeric:
        return value
    # JSON 列：用 parse_json() 包裹
    if json_cols and column in json_cols:
        return "parse_json(" + lit_str(value) + ")"
    return lit_str(value)


def render_ddl(sql_text: str, db: str) -> str:
    return re.sub(r"\bdim\.", f"{db}.", sql_text)


def split_statements(sql_text: str) -> list[str]:
    parts: list[str] = []
    buf: list[str] = []
    for line in sql_text.splitlines():
        no_comment = re.sub(r"^\s*--.*$", "", line)
        buf.append(line)
        if no_comment.rstrip().endswith(";"):
            stmt = "\n".join(buf).strip()
            if stmt and stmt != ";":
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
    numeric = spec["numeric"]
    quoted = spec["quoted"]
    not_null = spec.get("not_null", set())
    json_cols = spec.get("json", set())
    rows: list[str] = []
    with csv_path.open(encoding="utf-8") as fh:
        reader = csv.DictReader(fh)
        if reader.fieldnames != cols:
            raise ValueError(
                f"{csv_path} header mismatch: got {reader.fieldnames}, expected {cols}"
            )
        for row in reader:
            literals = [cell_to_sql(row[c], c, numeric, not_null, json_cols) for c in cols]
            rows.append("(" + ", ".join(literals) + ")")
    if not rows:
        print(f"  WARN: empty {csv_path}")
        return 0
    # quote column names that are SQL reserved (e.g. `precision`)
    col_clause = ", ".join(f"`{c}`" if c in quoted else c for c in cols)
    # 分批插入，避免单 SQL 过大
    BATCH = 200
    total = 0
    for i in range(0, len(rows), BATCH):
        chunk = rows[i:i + BATCH]
        sql = (
            f"INSERT INTO {db}.{spec['table']} ({col_clause}) VALUES\n"
            + ",\n".join(chunk)
        )
        cur.execute(sql)
        total += len(chunk)
    return total


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
