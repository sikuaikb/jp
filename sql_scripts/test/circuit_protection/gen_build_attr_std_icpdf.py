#!/usr/bin/env python3
"""从 switch build 模板生成 circuit_protection ICPDF EAV build SQL。"""
from __future__ import annotations

import sys
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")

HERE = Path(__file__).resolve().parent
SWITCH_BUILD = HERE.parent / "switch" / "build_dwd_icpdf_component_attr_std_switch.sql"
OUT = HERE / "build_dwd_icpdf_component_attr_std_circuit_protection.sql"

REPLACEMENTS = (
    ("dim_unit_factor_switch", "dim_unit_factor"),
    ("dim_attr_schema_switch", "dim_attr_schema_circuit_protection"),
    ("dim_attr_extract_rule_switch", "dim_attr_extract_rule_circuit_protection"),
    ("dwd_component_class_switch", "dwd_component_class_circuit_protection"),
    ("dwd_component_attr_std_switch", "dwd_component_attr_std_circuit_protection"),
    ("switch", "circuit_protection"),
)


def main() -> None:
    text = SWITCH_BUILD.read_text(encoding="utf-8")
    for old, new in REPLACEMENTS:
        text = text.replace(old, new)
    header = """/* test/circuit_protection build -> test_dwd.dwd_component_attr_std_circuit_protection
 * 由 switch 引擎模板派生；dim 指向 test_dim.dim_attr_*_circuit_protection
 */
"""
    text = header + text.split("*/", 1)[-1].lstrip()
    OUT.write_text(text, encoding="utf-8")
    print(f"wrote {OUT}")


if __name__ == "__main__":
    main()
