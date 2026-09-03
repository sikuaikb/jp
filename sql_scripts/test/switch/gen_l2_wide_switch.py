#!/usr/bin/env python3
"""从 15_switch_ready 模板生成 test/switch L2 DDL + build（test_* 表 + ICPDF/DK 双源）。"""
from __future__ import annotations

import re
import sys
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")

HERE = Path(__file__).resolve().parent
READY = HERE.parents[1] / "2.attribute_standard" / "15_switch_ready"

L2_NAMES = (
    "mechanical_actuated_switch",
    "mechanical_sensing_switch",
    "magnetic_sensing_switch",
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
    ("dwd.dwd_l2_switch_", "test_dwd.dwd_l2_switch_"),
    ("dwd.dwd_component_class c", "test_dwd.dwd_component_class_switch c"),
    ("dwd.dwd_component_attr_std e", "test_dwd.dwd_component_attr_std_switch e"),
    ("dwd.dwd_component_attr_std v", "test_dwd.dwd_component_attr_std_switch v"),
    ("dim.dim_attr_schema d", "test_dim.dim_attr_schema_switch d"),
    ("dim.v_std_brand_alias a", "test_dim.v_std_brand_alias a"),
    ("LEFT JOIN dwd.dwd_l2_switch_", "LEFT JOIN test_dwd.dwd_l2_switch_"),
)


def adapt_ddl(text: str) -> str:
    text = text.replace("dwd.dwd_l2_switch_", "test_dwd.dwd_l2_switch_")
    text = text.replace(
        "COMMENT 'mechanical_actuated_switch L2 宽表（test 试点 strict 后缀）'",
        "COMMENT 'mechanical_actuated_switch L2 宽表（switch test）'",
    )
    text = text.replace(
        "COMMENT 'mechanical_sensing_switch L2 宽表（test 试点 strict 后缀）'",
        "COMMENT 'mechanical_sensing_switch L2 宽表（switch test）'",
    )
    text = text.replace(
        "COMMENT 'magnetic_sensing_switch L2 宽表（test 试点 strict 后缀）'",
        "COMMENT 'magnetic_sensing_switch L2 宽表（switch test）'",
    )
    return text


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

    insert_target = f"INSERT INTO test_dwd.dwd_l2_switch_{l2}"
    if insert_target in text and "DELETE FROM" not in text:
        text = text.replace(
            insert_target,
            f"DELETE FROM test_dwd.dwd_l2_switch_{l2} "
            f"WHERE data_source IN ('icpdf', 'digikey');\n\n{insert_target}",
            1,
        )

    text = text.replace(
        f"WHERE c.l2_code = '{l2}'\n  AND c.l1_code = 'switch'",
        f"WHERE c.l2_code = '{l2}'\n  AND c.l1_code = 'switch'\n"
        f"  AND c.data_source IN ('icpdf', 'digikey')\n"
        f"  AND c.l3_code NOT LIKE '%_unclassified'",
    )

    header = f"""/* test/switch build -> test_dwd.dwd_l2_switch_{l2}
 * EAV: test_dwd.dwd_component_attr_std_switch
 * brand: test_dim.v_std_brand_alias（run_brand_sync.py test）
 * 数据源: icpdf + digikey
 */
"""
    text = re.sub(r"/\*.*?\*/\s*", header, text, count=1, flags=re.DOTALL)

    # 校验 SQL 单独由 run_test_switch_l2.py 执行时可跳过末尾 SELECT
    parts = text.rsplit("/* ---------- 校验 ---------- */", 1)
    return parts[0].rstrip() + "\n"


def main() -> None:
    for l2 in L2_NAMES:
        ddl_in = READY / f"dwd_l2_switch_{l2}.sql"
        build_in = READY / f"build_dwd_l2_switch_{l2}.sql"
        ddl_out = HERE / f"dwd_l2_switch_{l2}.sql"
        build_out = HERE / f"build_dwd_l2_switch_{l2}.sql"

        ddl_out.write_text(adapt_ddl(ddl_in.read_text(encoding="utf-8")), encoding="utf-8")
        build_out.write_text(
            adapt_build(build_in.read_text(encoding="utf-8"), l2),
            encoding="utf-8",
        )
        print(f"  {ddl_out.name}")
        print(f"  {build_out.name}")
    print("Done.")


if __name__ == "__main__":
    main()
