#!/usr/bin/env python3
"""从 prod 引擎 SQL 生成 circuit_protection 试点 build（test_dim/test_dwd · 仅 ICPDF）。"""
from __future__ import annotations

import re
from pathlib import Path

HERE = Path(__file__).resolve().parent
PROD = HERE.parents[1] / "1.classify" / "dwd_component_class.sql"
OUT = HERE / "build_dwd_icpdf_component_class_circuit_protection.sql"

HEADER = """/* circuit_protection 试点：ICPDF → test_dwd.dwd_component_class_circuit_protection
 *
 * 读：dwd.dwd_icpdf_component_param（prod 只读）
 * 维表：test_dim.dim_l3_classify_rule_circuit_protection + dim_l3_classify_circuit_protection
 * 写：test_dwd.dwd_component_class_circuit_protection（data_source='icpdf'）
 *
 * 重新生成：python gen_build_classify_sql.py
 */

DELETE FROM test_dwd.dwd_component_class_circuit_protection WHERE data_source = 'icpdf';

INSERT INTO test_dwd.dwd_component_class_circuit_protection
(
    id, data_source,
    l1_code, l2_code, l3_code, l3_id,
    rule_id, phase, classify_source, matched_priority, matched_value, confidence,
    create_at, update_at
)
"""


def main() -> None:
    src = PROD.read_text(encoding="utf-8")
    m = re.search(r"\bWITH\b", src, re.IGNORECASE)
    if not m:
        raise SystemExit("WITH not found in prod SQL")
    body = src[m.start() :]

    body = re.sub(
        r"(?<!test_)dim\.dim_l3_classify_rule",
        "test_dim.dim_l3_classify_rule_circuit_protection",
        body,
    )
    body = re.sub(
        r"(?<!test_)dim\.dim_l3_classify",
        "test_dim.dim_l3_classify_circuit_protection",
        body,
    )
    body = re.sub(
        r"(?<!test_)dwd\.dwd_component_class",
        "test_dwd.dwd_component_class_circuit_protection",
        body,
    )
    body = re.sub(
        r"FROM dwd\.dwd_icpdf_component_param\s*UNION ALL\s*SELECT[\s\S]*?FROM dwd\.dwd_digikey_component_param",
        "FROM dwd.dwd_icpdf_component_param",
        body,
        count=1,
    )
    body = body.replace(
        "WHERE enabled = 1\n      AND rule_kind = 'gate'",
        "WHERE enabled = 1\n      AND data_source = 'icpdf'\n      AND rule_kind = 'gate'",
    )
    body = body.replace(
        "WHERE r.enabled = 1\n      AND r.rule_kind = 'classify'",
        "WHERE r.enabled = 1\n      AND r.data_source = 'icpdf'\n      AND r.rule_kind = 'classify'",
    )

    OUT.write_text(HEADER + body, encoding="utf-8")
    print(f"wrote {OUT}")


if __name__ == "__main__":
    main()
