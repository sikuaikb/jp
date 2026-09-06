#!/usr/bin/env python3
"""从 attr_schema_logic_ic.py 生成 dim_attr_schema_logic_ic.csv。"""
from __future__ import annotations

import csv
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "seed"))
from attr_schema_logic_ic import (  # noqa: E402
    CAT_CN,
    L1_CODE,
    L2_CODES,
    L2_COMMON,
    L3_ATTRS,
    SCHEMA_VERSION,
)

OUT = Path(__file__).resolve().parent / "seed" / "dim_attr_schema_logic_ic.csv"
COLS = [
    "schema_version", "l1_code", "scope_level", "scope_code",
    "std_attr_code", "std_attr_cn", "unit_std", "db_type", "precision",
    "value_domain", "min_bound", "max_bound",
    "is_l2_common", "display_ord", "attr_category_cn", "attr_category_en", "note",
]


def row(**kw) -> dict:
    base = {c: "" for c in COLS}
    base.update(kw)
    return base


def main() -> None:
    rows: list[dict] = []
    for l2 in L2_CODES:
        for a in L2_COMMON:
            cat_en = a["cat"]
            rows.append(
                row(
                    schema_version=SCHEMA_VERSION,
                    l1_code=L1_CODE,
                    scope_level="l2",
                    scope_code=l2,
                    std_attr_code=a["code"],
                    std_attr_cn=a["cn"],
                    db_type=a["db_type"],
                    is_l2_common="1",
                    display_ord=str(a["ord"]),
                    attr_category_cn=CAT_CN[cat_en],
                    attr_category_en=cat_en,
                    note=f"L2 公共 · {l2}",
                )
            )
    for l3, attrs in L3_ATTRS.items():
        for a in attrs:
            rows.append(
                row(
                    schema_version=SCHEMA_VERSION,
                    l1_code=L1_CODE,
                    scope_level="l3",
                    scope_code=l3,
                    std_attr_code=a["code"],
                    std_attr_cn=a["cn"],
                    db_type=a["db_type"],
                    is_l2_common="0",
                    display_ord=str(a["ord"]),
                    attr_category_cn="技术参数",
                    attr_category_en="tech_specs",
                    note=f"L3 专规 · {l3}",
                )
            )

    with OUT.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=COLS)
        w.writeheader()
        w.writerows(rows)
    print(f"wrote {len(rows)} rows -> {OUT}  (l2={len(L2_CODES)*len(L2_COMMON)} l3={sum(len(v) for v in L3_ATTRS.values())})")


if __name__ == "__main__":
    main()
