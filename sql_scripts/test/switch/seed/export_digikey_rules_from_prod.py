#!/usr/bin/env python3
"""从 prod dim 导出 DigiKey switch 规则到 seed（一次性/增量快照）。"""
from __future__ import annotations

import csv
import json
import os
from pathlib import Path

import pymysql

HERE = Path(__file__).resolve().parent
OUT = HERE / "digikey_classify_rules.csv"
ENV = HERE.parents[2] / "local.env"

HEADER = [
    "rule_id", "clause_group_id", "clause_ord", "schema_version", "data_source",
    "rule_kind", "l3_id", "l3_cn", "phase", "rule_priority", "enabled",
    "confidence_weight", "classify_source_hint", "field_code", "match_value",
    "match_values", "match_map", "note",
]


def load_env() -> None:
    for line in ENV.read_text(encoding="utf-8").splitlines():
        if line.strip().startswith("export "):
            k, _, v = line[7:].partition("=")
            os.environ[k] = v.strip().strip("'").strip('"')


def arr_to_json(val) -> str:
    if val is None:
        return ""
    if isinstance(val, str):
        return val
    return json.dumps(list(val), ensure_ascii=False)


def map_to_json(val) -> str:
    if val is None:
        return ""
    if isinstance(val, str):
        return val
    return json.dumps(dict(val), ensure_ascii=False)


def main() -> None:
    load_env()
    conn = pymysql.connect(
        host=os.environ["MYSQL_HOST"],
        port=int(os.environ.get("MYSQL_PORT", "9030")),
        user=os.environ["MYSQL_USER"],
        password=os.environ["MYSQL_PASSWORD"],
        cursorclass=pymysql.cursors.DictCursor,
    )
    cur = conn.cursor()
    cur.execute(
        """
        SELECT rule_id, clause_group_id, clause_ord, schema_version, data_source,
               rule_kind, l3_id, l3_cn, phase, rule_priority, enabled,
               confidence_weight, classify_source_hint, field_code, match_value,
               match_values, match_map, note
        FROM dim.dim_l3_classify_rule
        WHERE data_source = 'digikey'
          AND (rule_id LIKE 'gate_switch_%' OR rule_id LIKE 'switch_digikey_%')
        ORDER BY rule_id, clause_group_id, clause_ord
        """
    )
    rows = cur.fetchall()
    conn.close()

    with OUT.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=HEADER)
        w.writeheader()
        for r in rows:
            w.writerow(
                {
                    "rule_id": r["rule_id"],
                    "clause_group_id": r["clause_group_id"],
                    "clause_ord": r["clause_ord"],
                    "schema_version": r["schema_version"],
                    "data_source": r["data_source"],
                    "rule_kind": r["rule_kind"],
                    "l3_id": r["l3_id"] or "",
                    "l3_cn": r["l3_cn"] or "",
                    "phase": r["phase"],
                    "rule_priority": r["rule_priority"],
                    "enabled": r["enabled"],
                    "confidence_weight": r["confidence_weight"],
                    "classify_source_hint": r["classify_source_hint"] or "",
                    "field_code": r["field_code"],
                    "match_value": r["match_value"] or "",
                    "match_values": arr_to_json(r["match_values"]),
                    "match_map": map_to_json(r["match_map"]),
                    "note": r["note"] or "",
                }
            )
    print(f"wrote {len(rows)} digikey rows -> {OUT}")


if __name__ == "__main__":
    main()
