#!/usr/bin/env python3
"""生成 dim_l3_classify_rule_switch.csv（gate + classify）。"""
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

OUT = Path(__file__).resolve().parent / "dim_l3_classify_rule_switch.csv"
DIGIKEY_SNAPSHOT = Path(__file__).resolve().parent / "digikey_classify_rules.csv"

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


def _hint(field_code: str, rule_hint: str | None) -> str:
    if rule_hint:
        return rule_hint
    if field_code in ("category2_eq", "category2_in"):
        return "icpdf_category2"
    if field_code in ("category_eq", "category_in"):
        return "icpdf_category"
    if field_code == "note_cn_regexp":
        return "note_cn_regexp"
    if field_code == "parjson2_match_map":
        return "parjson2"
    return "icpdf_category2"


def _row(
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
    hint: str = "gate_category2",
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
    assert SCHEMA_VERSION == GATE_SCHEMA_VERSION
    rows: list[dict] = []

    l2_notes = "; ".join(
        f"{g['l2_code']}({len(g['categories'])})" for g in CATEGORY2_INCLUDE_GROUPS
    )
    rows.append(
        _row(
            rule_id="gate_switch_icpdf_v1",
            rule_kind="gate",
            field_code="category2_in",
            match_values=CATEGORY2_INCLUDE,
            hint="gate_category2",
            note=(
                f"[gate] icpdf switch category2 白名单 v1.5.28 · {len(CATEGORY2_INCLUDE)} 叶 · "
                f"~{GATE_BASELINE['rows_category2_in']:,} 行 · {l2_notes}；"
                "禁止 LIKE '%开关%' 宽匹配（PMIC/模拟mux 误收）"
            ),
        )
    )
    rows.append(
        _row(
            rule_id="gate_switch_icpdf_v1",
            rule_kind="gate",
            field_code="category_in",
            clause_group_id=1,
            match_values=CATEGORY_INCLUDE,
            hint="gate_category",
            note=(
                f"[gate] icpdf switch category 补充 v1 · {len(CATEGORY_INCLUDE)} 字面 · "
                f"覆盖 category 非空且 category2 缺失/未命中 G1 的 ~"
                f"{GATE_BASELINE['rows_category_in_supplement_only']:,} 行；"
                "不含开关配件/模拟开关芯片"
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
                    clause_ord=ord_i,
                    l3_id=cr["l3_id"],
                    l3_cn=cr["l3_cn"],
                    phase=str(cr["phase"]),
                    rule_priority=str(cr["rule_priority"]),
                    match_value=mv or "",
                    match_values=mvs,
                    match_map=mmap,
                    note=cr.get("note", ""),
                    hint=_hint(fc, rule_hint),
                )
            )

    # DigiKey：prod 已验收规则快照（勿被 icpdf-only load 冲掉）
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
