#!/usr/bin/env python3
"""把所有 DDL 文件里 rohs_compliant 列定义的 VARCHAR(...) 改为 TINYINT。
仅匹配 `rohs_compliant` 列行, 不动其他 VARCHAR 列。"""
from __future__ import annotations
import re
from pathlib import Path

BASE = Path(r"e:\Hardware_Data_ETL\sql_scripts")
changed = []
for p in BASE.rglob("*.sql"):
    try:
        txt = p.read_text(encoding="utf-8")
    except Exception:
        continue
    if "rohs_compliant" not in txt:
        continue
    if not re.search(r"CREATE\s+TABLE", txt, re.IGNORECASE):
        continue
    orig = txt
    new = re.sub(r"(`rohs_compliant`\s+)VARCHAR\(\d+\)", r"\1TINYINT", txt)
    if new != orig:
        p.write_text(new, encoding="utf-8")
        changed.append(str(p.relative_to(BASE)))
print(f"修改 DDL 文件数: {len(changed)}")
for c in changed:
    print(f"  {c}")
