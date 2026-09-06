#!/usr/bin/env python3
"""switch test 全链路：分类 → EAV → L2 + 品牌（不写 prod）。"""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent

STEPS = (
    ("run_test_switch.py", "分类"),
    ("run_test_switch_attr.py", "属性 EAV"),
    ("run_test_switch_l2.py", "品牌 + L2 宽表"),
    ("audit/audit_attr_by_l3.py --data-source icpdf", "L3 属性审计"),
    ("export_merge_staging.py", "merge 预备快照"),
)


def main() -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    for script, label in STEPS:
        print(f"\n{'='*60}\n>>> {label}: {script}\n{'='*60}")
        if script.endswith(".py") and " " not in script:
            cmd = [sys.executable, str(HERE / script)]
        elif script.startswith("audit/"):
            cmd = [sys.executable, str(HERE / script.split()[0]), *script.split()[1:]]
        else:
            cmd = [sys.executable, str(HERE / script)]
        r = subprocess.run(cmd, cwd=str(HERE))
        if r.returncode != 0:
            print(f"FAIL: {script} exit={r.returncode}")
            return r.returncode
    print("\n全链路完成（test only）")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
