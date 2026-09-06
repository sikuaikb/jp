#!/usr/bin/env python3
"""从 prod dim 回写 inductor seed 到 1.classify/seed + 2.attribute_standard/seed"""
from __future__ import annotations

import csv
import json
import os
import sys
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")

L1 = "inductor"
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
CLASSIFY_SEED = ROOT / "1.classify" / "seed"
ATTR_SEED = ROOT / "2.attribute_standard" / "seed"
ENV = ROOT / "local.env"

TAXONOMY_COLS = [
    "l3_id", "l1_code", "l1_cn", "l2_code", "l2_cn", "l3_code", "l3_cn", "note", "schema_version",
]
RULE_COLS = [
    "rule_id", "clause_group_id", "clause_ord", "schema_version", "data_source", "rule_kind",
    "l3_id", "l3_cn", "phase", "rule_priority", "enabled", "confidence_weight",
    "classify_source_hint", "field_code", "match_value", "match_values", "match_map", "note",
]
SCHEMA_COLS = [
    "schema_version", "l1_code", "scope_level", "scope_code", "std_attr_code",
    "std_attr_cn", "unit_std", "db_type", "precision", "value_domain",
    "min_bound", "max_bound", "is_l2_common", "display_ord",
    "attr_category_cn", "attr_category_en", "note",
]
EXTRACT_COLS = [
    "extract_rule_id", "data_source", "schema_version", "l1_code",
    "apply_scope_level", "apply_scope_code", "std_attr_code", "source_kind",
    "source_expr", "source_value_expr", "source_value_regex", "literal_std_value",
    "priority", "enabled", "value_map", "note",
]

for line in ENV.read_text(encoding="utf-8").splitlines():
    if line.strip().startswith("export "):
        k, _, v = line[7:].partition("=")
        os.environ[k] = v.strip().strip("'\"")

import pymysql

conn = pymysql.connect(
    host=os.environ["MYSQL_HOST"], port=int(os.environ.get("MYSQL_PORT", "9030")),
    user=os.environ["MYSQL_USER"], password=os.environ["MYSQL_PASSWORD"],
    charset="utf8mb4", cursorclass=pymysql.cursors.DictCursor,
)
cur = conn.cursor()


def cell(v):
    if v is None:
        return ""
    if isinstance(v, (dict, list)):
        return json.dumps(v, ensure_ascii=False)
    return str(v)


def fetch(sql, cols):
    cur.execute(sql)
    return [{c: cell(r.get(c)) for c in cols} for r in cur.fetchall()]


def merge_csv(path: Path, cols, pk_cols, new_rows, drop_fn):
    kept = []
    if path.exists():
        with path.open(encoding="utf-8", newline="") as fh:
            for row in csv.DictReader(fh):
                if drop_fn(row):
                    continue
                kept.append({c: row.get(c, "") for c in cols})
    new_map = {tuple(r[c] for c in pk_cols): r for r in new_rows}
    out, seen = [], set()
    for row in kept:
        k = tuple(row[c] for c in pk_cols)
        if k in new_map:
            out.append(new_map[k])
            seen.add(k)
        else:
            out.append(row)
    for k, row in new_map.items():
        if k not in seen:
            out.append(row)
    with path.open("w", encoding="utf-8", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=cols, quoting=csv.QUOTE_MINIMAL)
        w.writeheader()
        w.writerows(out)
    print(f"  {path.name}: dropped={sum(1 for _ in [])} new={len(new_rows)} total={len(out)}")


def is_inductor_rule(row):
    rid = row.get("rule_id", "")
    return rid.startswith("inductor_") or rid.startswith("gate_inductor_")


def is_inductor_extract(row):
    rid = row.get("extract_rule_id", "")
    return row.get("l1_code") == L1 or rid.startswith(f"{L1}_")


taxonomy = fetch(
    f"SELECT {', '.join(TAXONOMY_COLS)} FROM dim.dim_l3_classify WHERE l1_code='{L1}' ORDER BY l3_id",
    TAXONOMY_COLS,
)
rules = fetch(
    f"""
    SELECT {', '.join(RULE_COLS)}
    FROM dim.dim_l3_classify_rule r
    WHERE r.rule_id REGEXP '^(inductor_|gate_inductor_)'
       OR r.l3_id IN (SELECT l3_id FROM dim.dim_l3_classify WHERE l1_code='{L1}')
    ORDER BY r.rule_id, r.clause_group_id, r.clause_ord
    """,
    RULE_COLS,
)
schema = fetch(
    f"SELECT {', '.join(SCHEMA_COLS)} FROM dim.dim_attr_schema WHERE l1_code='{L1}' ORDER BY 1,2,3,4,5",
    SCHEMA_COLS,
)
extract = fetch(
    f"""
    SELECT {', '.join(EXTRACT_COLS)} FROM dim.dim_attr_extract_rule
    WHERE l1_code='{L1}' OR extract_rule_id REGEXP '^{L1}_'
    ORDER BY extract_rule_id
    """,
    EXTRACT_COLS,
)

print(f"prod: taxonomy={len(taxonomy)} classify_rule={len(rules)} schema={len(schema)} extract={len(extract)}")

merge_csv(
    CLASSIFY_SEED / "dim_l3_classify.csv", TAXONOMY_COLS, ["l3_id"],
    taxonomy, lambda r: r.get("l1_code") == L1,
)
merge_csv(
    CLASSIFY_SEED / "dim_l3_classify_rule.csv", RULE_COLS, ["rule_id", "clause_group_id", "clause_ord"],
    rules, is_inductor_rule,
)
merge_csv(
    ATTR_SEED / "dim_attr_schema.csv", SCHEMA_COLS, SCHEMA_COLS[:5],
    schema, lambda r: r.get("l1_code") == L1,
)
merge_csv(
    ATTR_SEED / "dim_attr_extract_rule.csv", EXTRACT_COLS, ["extract_rule_id"],
    extract, is_inductor_extract,
)

conn.close()
print("✅ inductor seed CSV 已从 prod dim 回写")
