#!/usr/bin/env python3
"""从 16_circuit_protection_ready 生成 test L2 DDL + build（ICPDF 双源）。"""
from __future__ import annotations

import re
import sys
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")

HERE = Path(__file__).resolve().parent
READY = HERE.parents[1] / "2.attribute_standard" / "16_circuit_protection_ready"

L2_NAMES = (
    "overcurrent_overtemperature_protection",
    "passive_surge_diversion",
    "semiconductor_transient_suppression",
)

SRC_PARAM = """\
WITH src_param AS (
    SELECT 'digikey' AS data_source, id, partno, brandshort, brandid
    FROM dwd.dwd_digikey_component_param
    UNION ALL
    SELECT 'icpdf' AS data_source, id, partno, brandshort, brandid
    FROM dwd.dwd_icpdf_component_param
),"""

REPLACEMENTS = (
    ("FROM dwd.dwd_component_attr_std", "FROM test_dwd.dwd_component_attr_std_circuit_protection"),
    ("dwd.dwd_l2_circuit_protection_", "test_dwd.dwd_l2_circuit_protection_"),
    ("dwd.dwd_component_class c", "test_dwd.dwd_component_class_circuit_protection c"),
    ("dwd.dwd_component_attr_std e", "test_dwd.dwd_component_attr_std_circuit_protection e"),
    ("dwd.dwd_component_attr_std v", "test_dwd.dwd_component_attr_std_circuit_protection v"),
    ("dim.dim_attr_schema d", "test_dim.dim_attr_schema_circuit_protection d"),
    ("dim.v_std_brand_alias a", "test_dim.v_std_brand_alias a"),
    ("LEFT JOIN dwd.dwd_l2_circuit_protection_", "LEFT JOIN test_dwd.dwd_l2_circuit_protection_"),
)


def adapt_ddl(text: str) -> str:
    return text.replace("dwd.dwd_l2_circuit_protection_", "test_dwd.dwd_l2_circuit_protection_")


def adapt_build(text: str, l2: str) -> str:
    for old, new in REPLACEMENTS:
        text = text.replace(old, new)

    text = re.sub(
        r"WITH src_param AS \(\s*"
        r"SELECT 'digikey' AS data_source, id, partno, brandshort, brandid\s*"
        r"FROM dwd\.dwd_digikey_component_param\s*"
        r"\),",
        SRC_PARAM,
        text,
        count=1,
        flags=re.DOTALL,
    )

    text = text.replace(
        f"DELETE FROM test_dwd.dwd_l2_circuit_protection_{l2} WHERE data_source = 'digikey';",
        f"DELETE FROM test_dwd.dwd_l2_circuit_protection_{l2} "
        f"WHERE data_source IN ('icpdf', 'digikey');",
    )

    insert_target = f"INSERT INTO test_dwd.dwd_l2_circuit_protection_{l2}"
    if insert_target in text and "WHERE data_source IN ('icpdf', 'digikey')" not in text.split(insert_target)[0][-200:]:
        text = text.replace(
            insert_target,
            f"DELETE FROM test_dwd.dwd_l2_circuit_protection_{l2} "
            f"WHERE data_source IN ('icpdf', 'digikey');\n\n{insert_target}",
            1,
        )

    text = text.replace(
        f"WHERE c.l2_code = '{l2}'\n  AND c.data_source = 'digikey'",
        f"WHERE c.l2_code = '{l2}'\n  AND c.data_source IN ('icpdf', 'digikey')",
    )

    text = text.replace(
        f"WHERE c.l2_code = '{l2}'\n  AND c.l1_code = 'circuit_protection'",
        f"WHERE c.l2_code = '{l2}'\n  AND c.l1_code = 'circuit_protection'\n"
        f"  AND c.data_source IN ('icpdf', 'digikey')\n"
        f"  AND c.l3_code NOT LIKE '%_unclassified'",
    )

    header = f"""/* test/circuit_protection build -> test_dwd.dwd_l2_circuit_protection_{l2}
 * EAV: test_dwd.dwd_component_attr_std_circuit_protection
 * 数据源: icpdf (+ digikey 若 classify 存在)
 */
"""
    text = re.sub(r"/\*.*?\*/\s*", header, text, count=1, flags=re.DOTALL)
    parts = text.rsplit("/* ---------- 校验 ---------- */", 1)
    text = parts[0].rstrip()
    text = re.sub(r"/\* ── 验收 ── \*/[\s\S]*$", "", text).rstrip() + "\n"
    return text


def main() -> None:
    for l2 in L2_NAMES:
        ddl_in = READY / f"dwd_l2_circuit_protection_{l2}.sql"
        build_in = READY / f"build_dwd_l2_circuit_protection_{l2}.sql"
        ddl_out = HERE / f"dwd_l2_circuit_protection_{l2}.sql"
        build_out = HERE / f"build_dwd_l2_circuit_protection_{l2}.sql"
        ddl_out.write_text(adapt_ddl(ddl_in.read_text(encoding="utf-8")), encoding="utf-8")
        build_out.write_text(adapt_build(build_in.read_text(encoding="utf-8"), l2), encoding="utf-8")
        print(f"  {ddl_out.name}")
        print(f"  {build_out.name}")
    print("Done.")


if __name__ == "__main__":
    main()
