#!/usr/bin/env python3
"""导出 switch test seed → merge 预备目录（不写 prod DB）。"""
from __future__ import annotations

import shutil
import sys
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")

HERE = Path(__file__).resolve().parent
STAGING = HERE / "merge_staging"
SRC = HERE / "seed"
CLASSIFY_FILES = (
    "dim_l3_classify_switch.csv",
    "dim_l3_classify_rule_switch.csv",
)
ATTR_FILES = (
    "dim_attr_schema_switch.csv",
    "dim_attr_extract_rule_switch.csv",
)


def copy_pairs() -> None:
    STAGING.mkdir(exist_ok=True)
    (STAGING / "classify").mkdir(exist_ok=True)
    (STAGING / "attribute").mkdir(exist_ok=True)
    for name in CLASSIFY_FILES:
        shutil.copy2(SRC / name, STAGING / "classify" / name)
    for name in ATTR_FILES:
        shutil.copy2(SRC / name, STAGING / "attribute" / name)
    readme = STAGING / "README.txt"
    readme.write_text(
        "switch merge 预备快照（由 export_merge_staging.py 生成）\n"
        "合 prod 时按 CONTRIB.md Step 5/7 从 test_dim 或本目录 CSV 装载。\n"
        "勿直接 mysql 导入 prod，需 ALLOW_PROD=1 + 人工确认。\n",
        encoding="utf-8",
    )
    print(f"-> {STAGING}")


def main() -> int:
    copy_pairs()
    for sub in ("classify", "attribute"):
        n = len(list((STAGING / sub).glob("*.csv")))
        print(f"  {sub}: {n} csv")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
