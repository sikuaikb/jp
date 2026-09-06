#!/usr/bin/env python3
"""logic_ic prod 基线探查 + 导出 seed。"""
import csv
import json
import os
import sys
from pathlib import Path

import pymysql

sys.stdout.reconfigure(encoding="utf-8", errors="replace")

HERE = Path(__file__).resolve().parent
ENV = HERE.parents[2] / "sql_scripts" / "local.env"
SEED = HERE / "seed"
OUT = HERE / "prod_export"
L1 = "logic_ic"
L2_LIST = ["combinational_logic", "sequential_logic", "signal_buffer_driver"]


def load_env():
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
        init_command="SET pipeline_dop=1",
        cursorclass=pymysql.cursors.DictCursor,
    )


def arr_to_csv(v):
    if v is None:
        return ""
    if isinstance(v, str):
        return v
    return json.dumps(list(v) if isinstance(v, list) else v, ensure_ascii=False)


def main():
    load_env()
    SEED.mkdir(exist_ok=True)
    OUT.mkdir(exist_ok=True)
    conn = connect()
    cur = conn.cursor()

    cur.execute(
        "SELECT COUNT(*) n FROM dwd.dwd_component_class WHERE l1_code=%s AND data_source='digikey'",
        (L1,),
    )
    print(f"prod classify (digikey): {cur.fetchone()['n']:,}")

    baselines = {}
    total = 0
    for l2 in L2_LIST:
        tbl = f"dwd_l2_{L1}_{l2}"
        cur.execute(f"SELECT COUNT(*) n FROM dwd.{tbl}")
        n = cur.fetchone()["n"]
        baselines[l2] = n
        total += n
        print(f"  {tbl}: {n:,}")
    print(f"  L2 合计: {total:,}")

    cur.execute(
        "SELECT l3_id, l1_code, l1_cn, l2_code, l2_cn, l3_code, l3_cn, note, schema_version "
        "FROM dim.dim_l3_classify WHERE l1_code=%s ORDER BY l3_id",
        (L1,),
    )
    cls_cols = ["l3_id", "l1_code", "l1_cn", "l2_code", "l2_cn", "l3_code", "l3_cn", "note", "schema_version"]
    with (SEED / f"dim_l3_classify_{L1}.csv").open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=cls_cols)
        w.writeheader()
        for r in cur.fetchall():
            w.writerow({k: ("" if r[k] is None else r[k]) for k in cls_cols})

    cur.execute(
        f"""
        SELECT r.rule_id, r.clause_group_id, r.clause_ord, r.schema_version, r.data_source,
               r.rule_kind, r.l3_id, r.l3_cn, r.phase, r.rule_priority, r.enabled,
               r.confidence_weight, r.classify_source_hint, r.field_code, r.match_value,
               r.match_values, r.match_map, r.note
        FROM dim.dim_l3_classify_rule r
        LEFT JOIN dim.dim_l3_classify d ON d.l3_id=r.l3_id AND d.schema_version=r.schema_version
        WHERE d.l1_code=%s OR r.rule_id REGEXP %s OR r.rule_id REGEXP %s
        ORDER BY r.rule_id, r.clause_group_id, r.clause_ord
        """,
        (L1, f"^{L1}_", f"^gate_{L1}_"),
    )
    rule_cols = [
        "rule_id", "clause_group_id", "clause_ord", "schema_version", "data_source",
        "rule_kind", "l3_id", "l3_cn", "phase", "rule_priority", "enabled",
        "confidence_weight", "classify_source_hint", "field_code", "match_value",
        "match_values", "match_map", "note",
    ]
    with (SEED / f"dim_l3_classify_rule_{L1}.csv").open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=rule_cols)
        w.writeheader()
        for r in cur.fetchall():
            out = {}
            for k in rule_cols:
                v = r[k]
                if k in ("match_values", "match_map") and v is not None:
                    out[k] = arr_to_csv(v) if not isinstance(v, str) else v
                elif v is None:
                    out[k] = ""
                else:
                    out[k] = v
            w.writerow(out)

    cur.execute(
        """
        SELECT schema_version, l1_code, scope_level, scope_code, std_attr_code,
               std_attr_cn, unit_std, db_type, precision, value_domain,
               min_bound, max_bound, is_l2_common, display_ord,
               attr_category_cn, attr_category_en, note
        FROM dim.dim_attr_schema WHERE l1_code=%s
        ORDER BY scope_level, scope_code, std_attr_code
        """,
        (L1,),
    )
    schema_cols = [
        "schema_version", "l1_code", "scope_level", "scope_code", "std_attr_code",
        "std_attr_cn", "unit_std", "db_type", "precision", "value_domain",
        "min_bound", "max_bound", "is_l2_common", "display_ord",
        "attr_category_cn", "attr_category_en", "note",
    ]
    with (SEED / f"dim_attr_schema_{L1}.csv").open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=schema_cols)
        w.writeheader()
        for r in cur.fetchall():
            w.writerow({k: ("" if r[k] is None else r[k]) for k in schema_cols})

    cur.execute(
        """
        SELECT extract_rule_id, data_source, schema_version, l1_code,
               apply_scope_level, apply_scope_code, std_attr_code,
               source_kind, source_expr, source_value_expr, source_value_regex,
               literal_std_value, priority, enabled, value_map, note
        FROM dim.dim_attr_extract_rule
        WHERE l1_code=%s OR extract_rule_id REGEXP %s
        ORDER BY extract_rule_id
        """,
        (L1, f"^{L1}_"),
    )
    er_cols = [
        "extract_rule_id", "data_source", "schema_version", "l1_code",
        "apply_scope_level", "apply_scope_code", "std_attr_code",
        "source_kind", "source_expr", "source_value_expr", "source_value_regex",
        "literal_std_value", "priority", "enabled", "value_map", "note",
    ]
    with (SEED / f"dim_attr_extract_rule_{L1}.csv").open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=er_cols)
        w.writeheader()
        for r in cur.fetchall():
            out = {}
            for k in er_cols:
                v = r[k]
                if k == "value_map" and v is not None:
                    out[k] = arr_to_csv(v) if not isinstance(v, str) else v
                elif v is None:
                    out[k] = ""
                else:
                    out[k] = v
            w.writerow(out)

    for l2 in L2_LIST:
        tbl = f"dwd_l2_{L1}_{l2}"
        cur.execute(f"SHOW CREATE TABLE dwd.{tbl}")
        row = cur.fetchone()
        ddl = row.get("Create Table") or list(row.values())[-1]
        (OUT / f"{tbl}.sql").write_text(f"/* prod SHOW CREATE TABLE dwd.{tbl} */\n\n{ddl};\n", encoding="utf-8")

    cur.close()
    conn.close()
    print("导出完成")


if __name__ == "__main__":
    main()
