#!/usr/bin/env python3
"""生成 dim_l3_classify_rule_circuit_protection.csv（gate + classify）。"""
from __future__ import annotations

import csv
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from classify_config import CLASSIFY_RULES, DATA_SOURCE, SCHEMA_VERSION  # noqa: E402
from gate_config import (  # noqa: E402
    CATEGORY2_INCLUDE,
    CATEGORY2_INCLUDE_GROUPS,
    CATEGORY_INCLUDE,
    GATE_BASELINE,
    SCHEMA_VERSION as GATE_SCHEMA_VERSION,
)

OUT = Path(__file__).resolve().parent / "dim_l3_classify_rule_circuit_protection.csv"
DIGIKEY_SNAPSHOT = Path(__file__).resolve().parent / "digikey_classify_rules.csv"

HEADER = [
    "rule_id", "clause_group_id", "clause_ord", "schema_version", "data_source",
    "rule_kind", "l3_id", "l3_cn", "phase", "rule_priority", "enabled",
    "confidence_weight", "classify_source_hint", "field_code", "match_value",
    "match_values", "match_map", "note",
]


def _hint(field_code: str, rule_hint: str | None) -> str:
    if rule_hint:
        return rule_hint
    if field_code in ("category2_eq", "category2_in"):
        return "icpdf_category2"
    if field_code in ("category_eq", "category_in"):
        return "icpdf_category"
    if field_code == "note_cn_regexp":
        return "note_cn_regexp"
    if field_code == "note_regexp":
        return "note_regexp"
    if field_code == "partno_regexp":
        return "partno_regexp"
    if field_code == "parjson2_match_map":
        return "prajson2"
    return "icpdf_category2"


def _row(**kwargs) -> dict:
    base = {
        "schema_version": SCHEMA_VERSION,
        "data_source": DATA_SOURCE,
        "enabled": "1",
        "confidence_weight": "1.0",
        "l3_id": "",
        "l3_cn": "",
        "phase": "1",
        "rule_priority": "10",
        "match_value": "",
        "match_values": "",
        "match_map": "",
    }
    base.update(kwargs)
    return base


def main() -> None:
    assert SCHEMA_VERSION == GATE_SCHEMA_VERSION
    rows: list[dict] = []

    l2_notes = "; ".join(
        f"{g['l2_code']}({len(g['categories'])})" for g in CATEGORY2_INCLUDE_GROUPS
    )
    rows.append(
        _row(
            rule_id="gate_circuit_protection_icpdf_v1",
            rule_kind="gate",
            field_code="category2_in",
            clause_group_id="0",
            clause_ord="0",
            classify_source_hint="gate_category2",
            match_values=json.dumps(CATEGORY2_INCLUDE, ensure_ascii=False),
            note=(
                f"[gate] icpdf CP category2 白名单 · {len(CATEGORY2_INCLUDE)} 叶 · "
                f"~{GATE_BASELINE['category2_rows']:,} 行；禁止瞬态抑制器宽 gate"
            ),
        )
    )
    rows.append(
        _row(
            rule_id="gate_circuit_protection_icpdf_v1",
            rule_kind="gate",
            field_code="category_in",
            clause_group_id="1",
            clause_ord="0",
            classify_source_hint="gate_category",
            match_values=json.dumps(CATEGORY_INCLUDE, ensure_ascii=False),
            note=(
                f"[gate] icpdf CP category 补充 v1 · {len(CATEGORY_INCLUDE)} 叶 · "
                f"~{GATE_BASELINE['category_rows']:,} 行；TVS/保险丝等（压敏/非线性归 resistor）"
            ),
        )
    )

    for cr in CLASSIFY_RULES:
        rule_hint = cr.get("classify_source_hint")
        for ord_i, (fc, mv, mvs, mmap) in enumerate(cr["clauses"]):
            rows.append(
                _row(
                    rule_id=cr["rule_id"],
                    rule_kind="classify",
                    field_code=fc,
                    clause_group_id="0",
                    clause_ord=str(ord_i),
                    l3_id=cr["l3_id"],
                    l3_cn=cr["l3_cn"],
                    phase=str(cr["phase"]),
                    rule_priority=str(cr["rule_priority"]),
                    match_value=mv or "",
                    match_values=json.dumps(mvs, ensure_ascii=False) if mvs else "",
                    match_map=json.dumps(mmap, ensure_ascii=False) if mmap else "",
                    note=cr.get("note", ""),
                    classify_source_hint=_hint(fc, rule_hint),
                )
            )

    if DIGIKEY_SNAPSHOT.exists():
        with DIGIKEY_SNAPSHOT.open(encoding="utf-8") as f:
            dk_rows = list(csv.DictReader(f))
        rows.extend(dk_rows)
        print(f"  merged {len(dk_rows)} digikey rows from {DIGIKEY_SNAPSHOT.name}")
    else:
        print(f"  WARN: missing {DIGIKEY_SNAPSHOT.name}; run export_digikey_rules_from_prod.py")

    with OUT.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=HEADER)
        w.writeheader()
        w.writerows(rows)

    gate_n = sum(1 for r in rows if r["rule_kind"] == "gate")
    cls_n = sum(1 for r in rows if r["rule_kind"] == "classify")
    icpdf_n = sum(1 for r in rows if r.get("data_source") == "icpdf")
    dk_n = sum(1 for r in rows if r.get("data_source") == "digikey")
    print(
        f"wrote {len(rows)} rows -> {OUT}  "
        f"(gate={gate_n} classify={cls_n}; icpdf={icpdf_n} digikey={dk_n})"
    )


if __name__ == "__main__":
    main()
