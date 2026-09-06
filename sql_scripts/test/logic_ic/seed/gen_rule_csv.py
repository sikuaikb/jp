#!/usr/bin/env python3
"""生成 dim_l3_classify_rule_logic_ic.csv（gate + classify）。"""
from __future__ import annotations

import csv
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from classify_config import CLASSIFY_RULES, DATA_SOURCE, SCHEMA_VERSION  # noqa: E402
from gate_config import CATEGORY_INCLUDE_GROUPS, EXCLUDE_CATEGORY_NOT_LIKE, L1_CODE  # noqa: E402

OUT = Path(__file__).resolve().parent / "dim_l3_classify_rule_logic_ic.csv"

HEADER = [
    "rule_id",
    "clause_group_id",
    "clause_ord",
    "schema_version",
    "data_source",
    "rule_kind",
    "l3_id",
    "l3_cn",
    "phase",
    "rule_priority",
    "enabled",
    "confidence_weight",
    "classify_source_hint",
    "field_code",
    "match_value",
    "match_values",
    "match_map",
    "note",
]


def row(
    *,
    rule_id: str,
    rule_kind: str,
    field_code: str,
    clause_group_id: int = 0,
    clause_ord: int = 0,
    l3_id: str = "",
    l3_cn: str = "",
    phase: str = "1",
    rule_priority: str = "10",
    match_value: str = "",
    match_values: list | None = None,
    match_map: dict | None = None,
    note: str = "",
    hint: str = "gate_category",
) -> dict:
    return {
        "rule_id": rule_id,
        "clause_group_id": str(clause_group_id),
        "clause_ord": str(clause_ord),
        "schema_version": SCHEMA_VERSION,
        "data_source": DATA_SOURCE,
        "rule_kind": rule_kind,
        "l3_id": l3_id,
        "l3_cn": l3_cn,
        "phase": phase,
        "rule_priority": rule_priority,
        "enabled": "1",
        "confidence_weight": "1.0",
        "classify_source_hint": hint,
        "field_code": field_code,
        "match_value": match_value,
        "match_values": json.dumps(match_values, ensure_ascii=False) if match_values else "",
        "match_map": json.dumps(match_map, ensure_ascii=False) if match_map else "",
        "note": note,
    }


def main() -> None:
    rows: list[dict] = []

    for i, grp in enumerate(CATEGORY_INCLUDE_GROUPS):
        rows.append(
            row(
                rule_id=grp["rule_id"],
                rule_kind="gate",
                field_code="category_in",
                rule_priority=str(10 + i),
                match_values=grp["categories"],
                note=grp.get("note", ""),
            )
        )

    rows.append(
        row(
            rule_id=f"gate_{L1_CODE}_{DATA_SOURCE}_exclude_eval_v1",
            rule_kind="gate",
            field_code="gate_exclude_category_like",
            rule_priority="90",
            match_values=EXCLUDE_CATEGORY_NOT_LIKE,
            note="X2 文档行；build SQL 中 AND category NOT LIKE",
        )
    )

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

    with OUT.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=HEADER)
        w.writeheader()
        w.writerows(rows)

    gate_n = sum(1 for r in rows if r["rule_kind"] == "gate")
    cls_n = sum(1 for r in rows if r["rule_kind"] == "classify")
    print(f"wrote {len(rows)} rows -> {OUT}  (gate={gate_n} classify={cls_n})")


if __name__ == "__main__":
    main()
