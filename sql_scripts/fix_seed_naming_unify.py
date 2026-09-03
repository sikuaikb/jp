#!/usr/bin/env python3
"""seed 文件命名统一 (列感知, 用 csv 模块正确处理带引号字段)。
- 通用: 把 std_attr_code 列的旧码值替换为规范名 (不动其他列, 如 extract_rule_id/note 里的字样)
- circuit_protection/dim_attr_schema_circuit_protection.csv: 额外删除 6 个重叠行
  (3 个 scope × ro_hs_compliant/life_cycle_status, 这些 scope 已有规范名行)
旧码 -> 规范名:
  ro_hs_compliant -> rohs_compliant
  life_cycle_status -> lifecycle_status
  mounting_type -> mounting_style
  aec_qualified -> aec_q_level
"""
from __future__ import annotations
import csv
from pathlib import Path

ALIAS = {
    "ro_hs_compliant": "rohs_compliant",
    "life_cycle_status": "lifecycle_status",
    "mounting_type": "mounting_style",
    "aec_qualified": "aec_q_level",
}

BASE = Path(r"e:\HardWare_DK_ETL\sql_scripts")

# (相对路径, 是否做重叠删除)
FILES = [
    ("2.attribute_standard/seed/dim_attr_schema.csv", False),
    ("2.attribute_standard/seed/dim_attr_extract_rule.csv", False),
    ("test/circuit_protection/seed/dim_attr_schema_circuit_protection.csv", True),
    ("test/circuit_protection/seed/dim_attr_extract_rule_circuit_protection.csv", False),
    ("test/switch/seed/dim_attr_schema_switch.csv", False),
    ("test/switch/seed/dim_attr_extract_rule_switch.csv", False),
    ("test/switch/merge_staging/attribute/dim_attr_schema_switch.csv", False),
    ("test/switch/merge_staging/attribute/dim_attr_extract_rule_switch.csv", False),
]

# circuit_protection schema seed 中需删除的重叠行 (scope_code, std_attr_code)
DELETE_KEYS = {
    ("overcurrent_overtemperature_protection", "ro_hs_compliant"),
    ("overcurrent_overtemperature_protection", "life_cycle_status"),
    ("passive_surge_diversion", "ro_hs_compliant"),
    ("passive_surge_diversion", "life_cycle_status"),
    ("semiconductor_transient_suppression", "ro_hs_compliant"),
    ("semiconductor_transient_suppression", "life_cycle_status"),
}


def find_col(header, name):
    for i, h in enumerate(header):
        if h.strip() == name:
            return i
    return -1


total_renamed = 0
total_deleted = 0
for rel, do_delete in FILES:
    p = BASE / rel
    if not p.exists():
        print(f"SKIP (not found): {rel}")
        continue
    with open(p, "r", encoding="utf-8", newline="") as f:
        rows = list(csv.reader(f))
    if not rows:
        print(f"SKIP (empty): {rel}")
        continue
    header = rows[0]
    code_idx = find_col(header, "std_attr_code")
    scope_idx = find_col(header, "scope_code")
    if code_idx < 0:
        print(f"SKIP (no std_attr_code col): {rel}")
        continue

    renamed = 0
    deleted = 0
    out_rows = [header]
    for r in rows[1:]:
        if len(r) <= code_idx:
            out_rows.append(r)
            continue
        code = r[code_idx].strip()
        # 删除重叠行
        if do_delete and code in ("ro_hs_compliant", "life_cycle_status") and scope_idx >= 0:
            scope = r[scope_idx].strip() if len(r) > scope_idx else ""
            if (scope, code) in DELETE_KEYS:
                deleted += 1
                continue
        # 改名
        if code in ALIAS:
            r[code_idx] = ALIAS[code]
            renamed += 1
        out_rows.append(r)

    with open(p, "w", encoding="utf-8", newline="") as f:
        csv.writer(f, quoting=csv.QUOTE_MINIMAL).writerows(out_rows)
    msg = f"renamed={renamed}"
    if do_delete:
        msg += f" deleted={deleted}"
    print(f"  {rel}: {msg}")
    total_renamed += renamed
    total_deleted += deleted if do_delete else 0

print(f"\n合计: renamed={total_renamed} deleted={total_deleted}")
