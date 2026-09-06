#!/usr/bin/env python3
"""从 classify_config 生成 classify 规则 INSERT SQL（不含 gate）。"""
from __future__ import annotations

import csv
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from classify_config import CLASSIFY_RULES, DATA_SOURCE, SCHEMA_VERSION  # noqa: E402
from gen_rule_csv import row  # noqa: E402

OUT = Path(__file__).resolve().parent / "dim_l3_classify_rule_logic_ic_classify.sql"
COLS = [
    "rule_id", "clause_group_id", "clause_ord", "schema_version", "data_source",
    "rule_kind", "l3_id", "l3_cn", "phase", "rule_priority", "enabled",
    "confidence_weight", "classify_source_hint", "field_code",
    "match_value", "match_values", "match_map", "note",
]


def lit_str(s: str) -> str:
    return "'" + s.replace("\\", "\\\\").replace("'", "''") + "'"


def cell_sql(name: str, val: str) -> str:
    if val == "":
        return "NULL"
    if name == "match_values":
        parsed = json.loads(val)
        if not parsed:
            return "NULL"
        inner = ",".join(lit_str(str(x)) for x in parsed)
        return f"ARRAY<VARCHAR(128)>[{inner}]"
    if name == "match_map":
        parsed = json.loads(val)
        if not parsed:
            return "NULL"
        pairs = [f"{lit_str(str(k))},{lit_str(str(v))}" for k, v in parsed.items()]
        return "map(" + ",".join(pairs) + ")"
    if name in ("phase", "rule_priority", "enabled"):
        return val
    if name == "confidence_weight":
        return val
    return lit_str(val)


def main() -> None:
    rows: list[dict] = []
    for cr in CLASSIFY_RULES:
        rule_hint = cr.get("classify_source_hint")
        for ord_i, (fc, mv, mvs, mmap) in enumerate(cr["clauses"]):
            hint = rule_hint or "digikey_category"
            if rule_hint is None and fc in ("note_cn_regexp", "parjson_match_map"):
                hint = fc
            rows.append(
                row(
                    rule_id=cr["rule_id"],
                    rule_kind="classify",
                    field_code=fc,
                    clause_ord=ord_i,
                    l3_id=cr["l3_id"],
                    l3_cn=cr["l3_cn"],
                    phase=str(cr["phase"]),
                    rule_priority=str(cr["rule_priority"]),
                    match_value=mv or "",
                    match_values=mvs,
                    match_map=mmap,
                    note=cr.get("note", ""),
                    hint=hint,
                )
            )

    values = []
    for r in rows:
        values.append(
            "(" + ", ".join(cell_sql(c, r[c]) for c in COLS) + ")"
        )

    sql = (
        f"-- logic_ic classify 规则 · {len(CLASSIFY_RULES)} 条 rule_id · schema {SCHEMA_VERSION}\n"
        f"-- 生成: python seed/gen_classify_insert_sql.py\n"
        f"INSERT INTO dim.dim_l3_classify_rule\n"
        f"({', '.join(COLS)})\nVALUES\n"
        + ",\n".join(values)
        + ";\n"
    )
    OUT.write_text(sql, encoding="utf-8")
    print(f"wrote {len(rows)} classify clause rows -> {OUT}")


if __name__ == "__main__":
    main()
