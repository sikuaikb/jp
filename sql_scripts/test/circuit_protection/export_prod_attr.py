#!/usr/bin/env python3
"""从 prod 导出 circuit_protection 属性 dim + L2 SHOW CREATE。"""
from __future__ import annotations

import csv
import json
import os
import sys
from pathlib import Path

import pymysql

sys.stdout.reconfigure(encoding="utf-8", errors="replace")

HERE = Path(__file__).resolve().parent
ENV = HERE.parents[1] / "local.env"
SEED = HERE / "seed"
OUT = HERE / "prod_export"
L1 = "circuit_protection"

L2_TABLES = [
    "overcurrent_overtemperature_protection",
    "passive_surge_diversion",
    "semiconductor_transient_suppression",
]


def load_env() -> None:
    for line in ENV.read_text(encoding="utf-8").splitlines():
        s = line.strip()
        if s.startswith("export "):
            s = s[7:]
        if "=" in s and not s.startswith("#"):
            k, v = s.split("=", 1)
            os.environ[k.strip()] = v.strip().strip("'").strip('"')


def connect():
    return pymysql.connect(
        host=os.environ["MYSQL_HOST"],
        port=int(os.environ.get("MYSQL_PORT", "9030")),
        user=os.environ["MYSQL_USER"],
        password=os.environ["MYSQL_PASSWORD"],
        charset="utf8mb4",
        autocommit=True,
        cursorclass=pymysql.cursors.DictCursor,
    )


def arr_to_csv(v):
    if v is None:
        return ""
    if isinstance(v, str):
        return v
    return json.dumps(list(v) if isinstance(v, list) else v, ensure_ascii=False)


def main() -> None:
    load_env()
    OUT.mkdir(exist_ok=True)
    conn = connect()
    cur = conn.cursor()

    cur.execute(
        """
        SELECT schema_version, l1_code, scope_level, scope_code, std_attr_code,
               std_attr_cn, unit_std, db_type, precision, value_domain,
               min_bound, max_bound, is_l2_common, display_ord,
               attr_category_cn, attr_category_en, note
        FROM dim.dim_attr_schema
        WHERE l1_code = %s
        ORDER BY scope_level, scope_code, std_attr_code
        """,
        (L1,),
    )
    schema_rows = cur.fetchall()
    SCHEMA_SHORT = "v1.16.01"
    for r in schema_rows:
        r["schema_version"] = SCHEMA_SHORT
    schema_cols = [
        "schema_version", "l1_code", "scope_level", "scope_code", "std_attr_code",
        "std_attr_cn", "unit_std", "db_type", "precision", "value_domain",
        "min_bound", "max_bound", "is_l2_common", "display_ord",
        "attr_category_cn", "attr_category_en", "note",
    ]
    schema_path = SEED / f"dim_attr_schema_{L1}.csv"
    with schema_path.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=schema_cols)
        w.writeheader()
        for r in schema_rows:
            w.writerow({k: ("" if r[k] is None else r[k]) for k in schema_cols})
    print(f"dim_attr_schema: {len(schema_rows)} 行 → {schema_path}")

    cur.execute(
        """
        SELECT extract_rule_id, data_source, schema_version, l1_code,
               apply_scope_level, apply_scope_code, std_attr_code,
               source_kind, source_expr, source_value_expr, source_value_regex,
               literal_std_value, priority, enabled, value_map, note
        FROM dim.dim_attr_extract_rule
        WHERE l1_code = %s OR extract_rule_id REGEXP %s
        ORDER BY extract_rule_id
        """,
        (L1, f"^{L1}_"),
    )
    rule_rows = cur.fetchall()
    for r in rule_rows:
        r["schema_version"] = SCHEMA_SHORT
    rule_cols = [
        "extract_rule_id", "data_source", "schema_version", "l1_code",
        "apply_scope_level", "apply_scope_code", "std_attr_code",
        "source_kind", "source_expr", "source_value_expr", "source_value_regex",
        "literal_std_value", "priority", "enabled", "value_map", "note",
    ]
    rule_path = SEED / f"dim_attr_extract_rule_{L1}.csv"
    with rule_path.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=rule_cols)
        w.writeheader()
        for r in rule_rows:
            out = {}
            for k in rule_cols:
                v = r[k]
                if k == "value_map" and v is not None:
                    out[k] = arr_to_csv(v) if not isinstance(v, str) else v
                elif v is None:
                    out[k] = ""
                else:
                    out[k] = v
            w.writerow(out)
    print(f"dim_attr_extract_rule: {len(rule_rows)} 行 → {rule_path}")

    for l2 in L2_TABLES:
        tbl = f"dwd_l2_{L1}_{l2}"
        cur.execute(f"SHOW CREATE TABLE dwd.{tbl}")
        row = cur.fetchone()
        ddl = row.get("Create Table") or list(row.values())[-1]
        ddl_path = OUT / f"{tbl}.sql"
        ddl_path.write_text(f"/* prod SHOW CREATE TABLE dwd.{tbl} */\n\n{ddl};\n", encoding="utf-8")
        cur.execute(f"SELECT COUNT(*) n FROM dwd.{tbl}")
        n = cur.fetchone()["n"]
        print(f"  {tbl}: {n:,} 行 → {ddl_path.name}")

    cur.close()
    conn.close()


if __name__ == "__main__":
    main()
