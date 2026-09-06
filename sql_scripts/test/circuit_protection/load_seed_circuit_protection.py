#!/usr/bin/env python3
"""装载 circuit_protection 试点 dim → test_dim（不写 prod dim）。"""
from __future__ import annotations

import argparse
import csv
import json
import os
import re
import subprocess
import sys
from pathlib import Path

import pymysql

HERE = Path(__file__).resolve().parent
DDL_FILES = [
    "dim_l3_classify_circuit_protection.sql",
    "dim_l3_classify_rule_circuit_protection.sql",
]

TABLE_SPECS = [
    {
        "table": "dim_l3_classify_circuit_protection",
        "csv": "seed/dim_l3_classify_circuit_protection.csv",
        "columns": [
            "l3_id", "l1_code", "l1_cn", "l2_code", "l2_cn",
            "l3_code", "l3_cn", "note", "schema_version",
        ],
        "complex": {},
    },
    {
        "table": "dim_l3_classify_rule_circuit_protection",
        "csv": "seed/dim_l3_classify_rule_circuit_protection.csv",
        "columns": [
            "rule_id", "clause_group_id", "clause_ord",
            "schema_version", "data_source", "rule_kind",
            "l3_id", "l3_cn",
            "phase", "rule_priority", "enabled", "confidence_weight",
            "classify_source_hint", "field_code",
            "match_value", "match_values", "match_map",
            "note",
        ],
        "complex": {"match_values": "array", "match_map": "map"},
    },
]


def lit_str(s: str) -> str:
    return "'" + s.replace("\\", "\\\\").replace("'", "''") + "'"


def array_literal(json_text: str) -> str:
    parsed = json.loads(json_text)
    if not isinstance(parsed, list) or not parsed:
        return "NULL"
    inner = ",".join(lit_str(str(x)) for x in parsed)
    return f"ARRAY<VARCHAR(128)>[{inner}]"


def map_literal(json_text: str) -> str:
    parsed = json.loads(json_text)
    if not isinstance(parsed, dict) or not parsed:
        return "NULL"
    pairs = [f"{lit_str(str(k))},{lit_str(str(v))}" for k, v in parsed.items()]
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
        stripped = re.sub(r"^\s*--.*$", "", line)
        buf.append(line)
        if stripped.rstrip().endswith(";"):
            stmt = "\n".join(buf).strip()
            stmt = re.sub(r"/\*.*?\*/", "", stmt, flags=re.DOTALL).rstrip().rstrip(";").strip()
            if stmt:
                parts.append(stmt)
            buf = []
    return parts


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--db", default="test_dim", help="目标库（默认 test_dim）")
    args = ap.parse_args()
    if args.db in ("dim", "dwd"):
        raise SystemExit(f"拒绝写入 prod 库 {args.db!r}，请使用 test_dim")

    subprocess.run(
        [sys.executable, str(HERE / "seed" / "export_digikey_rules_from_prod.py")],
        check=True,
    )
    subprocess.run([sys.executable, str(HERE / "seed" / "gen_rule_csv.py")], check=True)
    subprocess.run([sys.executable, str(HERE / "gen_build_classify_sql.py")], check=True)

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
            rendered = render_ddl((HERE / ddl_file).read_text(encoding="utf-8"), args.db)
            for stmt in split_statements(rendered):
                cur.execute(stmt)
            print(f"  DDL: {ddl_file} -> {args.db}")

        for spec in TABLE_SPECS:
            csv_path = HERE / spec["csv"]
            cols = spec["columns"]
            rows: list[str] = []
            with csv_path.open(encoding="utf-8") as fh:
                for row in csv.DictReader(fh):
                    rows.append(
                        "("
                        + ", ".join(
                            cell_to_sql(row[c], spec["complex"].get(c)) for c in cols
                        )
                        + ")"
                    )
            sql = (
                f"INSERT INTO {args.db}.{spec['table']} ({', '.join(cols)}) VALUES\n"
                + ",\n".join(rows)
            )
            cur.execute(sql)
            print(f"  loaded {args.db}.{spec['table']}: {len(rows)} rows")
    conn.close()


if __name__ == "__main__":
    main()
