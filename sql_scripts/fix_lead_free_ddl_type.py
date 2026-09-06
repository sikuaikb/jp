#!/usr/bin/env python3
"""把所有 DDL 文件里 lead_free 列定义的 VARCHAR(64) 改为 TINYINT。
只匹配 `lead_free` 列行, 不动其他 VARCHAR(64) 列。
形式: `lead_free`  VARCHAR(64)  NULL COMMENT '无铅工艺'  ->  `lead_free`  TINYINT  NULL COMMENT '无铅工艺'
"""
from __future__ import annotations
import re
from pathlib import Path

BASE = Path(r"e:\Hardware_Data_ETL\sql_scripts")

# 找所有含 lead_free 的 .sql DDL 文件 (dwd_l2_*.sql 建表语句)
changed = []
for p in BASE.rglob("*.sql"):
    try:
        txt = p.read_text(encoding="utf-8")
    except Exception:
        continue
    if "lead_free" not in txt:
        continue
    # 只处理含 CREATE TABLE 的 DDL 文件 (避免误改 build 脚本里的别名)
    if not re.search(r"CREATE\s+TABLE", txt, re.IGNORECASE):
        continue
    orig = txt
    # 匹配 `lead_free` 列定义行: 反引号 lead_free 反引号 + 任意空白 + VARCHAR(64) ...
    # 替换该行中的 VARCHAR(64) -> TINYINT (仅 lead_free 行)
    new = re.sub(
        r"(`lead_free`\s+)VARCHAR\(\d+\)",
        r"\1TINYINT",
        txt,
    )
    if new != orig:
        p.write_text(new, encoding="utf-8")
        changed.append(str(p.relative_to(BASE)))

print(f"修改 DDL 文件数: {len(changed)}")
for c in changed:
    print(f"  {c}")
