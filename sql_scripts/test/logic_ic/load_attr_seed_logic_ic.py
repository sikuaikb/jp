#!/usr/bin/env python3
"""装载 logic_ic 试点 attr dim：test_dim.dim_attr_schema_logic_ic。"""
from __future__ import annotations

import argparse
import csv
import os
import re
import subprocess
import sys
from pathlib import Path

import pymysql

HERE = Path(__file__).resolve().parent
DDL_FILES = ["dim_attr_schema_logic_ic.sql", "dim_attr_extract_rule_logic_ic.sql"]

TABLE_SPECS = [
    {
        "table": "dim_attr_schema_logic_ic",
        "csv": "seed/dim_attr_schema_logic_ic.csv",
        "columns": [
            "schema_version", "l1_code", "scope_level", "scope_code", "std_attr_code",
            "std_attr_cn", "unit_std", "db_type", "precision", "value_domain",
            "min_bound", "max_bound", "is_l2_common", "display_ord",
            "attr_category_cn", "attr_category_en", "note",
        ],
        "numeric": {"precision", "min_bound", "max_bound", "is_l2_common", "display_ord"},
        "quoted": {"precision"},
        "not_null": {
            "schema_version", "l1_code", "scope_level", "scope_code", "std_attr_code",
            "db_type", "is_l2_common",
        },
    },
    {
        "table": "dim_attr_extract_rule_logic_ic",
        "csv": "seed/dim_attr_extract_rule_logic_ic.csv",
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
]


def lit_str(s: str) -> str:
    return "'" + s.replace("\\", "\\\\").replace("'", "''") + "'"


def cell_to_sql(value: str, column: str, numeric: set[str], not_null: set[str], json_cols: set[str] | None = None) -> str:
    if column == "unit_std" and value.strip() == "-":
        value = ""
    if value == "":
        if column in not_null and column not in numeric:
            return "''"
        return "NULL"
    if column in numeric:
        return value
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
            stmt_no_block = re.sub(r"/\*.*?\*/", "", stmt, flags=re.DOTALL)
            stmt_clean = stmt_no_block.rstrip().rstrip(";").strip()
            if stmt_clean:
                parts.append(stmt_clean)
            buf = []
    return parts


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--db", default="test_dim")
    args = ap.parse_args()

    subprocess.run([sys.executable, str(HERE / "gen_attr_seed_logic_ic.py")], check=True)
    subprocess.run([sys.executable, str(HERE / "gen_attr_extract_rule_logic_ic.py")], check=True)

    env = HERE.parents[1] / "local.env"
    if env.exists():
        for line in env.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if line.startswith("export "):
                k, _, v = line[7:].partition("=")
                os.environ[k] = v.strip().strip("'").strip('"')
    conn = pymysql.connect(
        host=os.environ["MYSQL_HOST"],
        port=int(os.environ.get("MYSQL_PORT", "9030")),
        user=os.environ["MYSQL_USER"],
        password=os.environ["MYSQL_PASSWORD"],
        charset="utf8mb4",
        autocommit=True,
    )
    with conn.cursor() as cur:
        for ddl_file in DDL_FILES:
            rendered = render_ddl((HERE / ddl_file).read_text(encoding="utf-8-sig"), args.db)
            for stmt in split_statements(rendered):
                cur.execute(stmt)
            print(f"  DDL: {ddl_file} -> {args.db}")
        for spec in TABLE_SPECS:
            csv_path = HERE / spec["csv"]
            cols = spec["columns"]
            numeric = spec["numeric"]
            quoted = spec["quoted"]
            not_null = spec["not_null"]
            json_cols = spec.get("json", set())
            rows: list[str] = []
            with csv_path.open(encoding="utf-8-sig") as fh:
                for row in csv.DictReader(fh):
                    literals = [cell_to_sql(row[c], c, numeric, not_null, json_cols) for c in cols]
                    rows.append("(" + ", ".join(literals) + ")")
            col_clause = ", ".join(f"`{c}`" if c in quoted else c for c in cols)
            batch = 200
            total = 0
            for i in range(0, len(rows), batch):
                chunk = rows[i : i + batch]
                sql = f"INSERT INTO {args.db}.{spec['table']} ({col_clause}) VALUES\n" + ",\n".join(chunk)
                cur.execute(sql)
                total += len(chunk)
            print(f"  loaded {args.db}.{spec['table']}: {total} rows")
    conn.close()


if __name__ == "__main__":
    main()
