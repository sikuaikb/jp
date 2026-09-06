#!/usr/bin/env python3
"""circuit_protection test 全链路：分类 → EAV → L2 → Phase 5.5 QA。"""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent

STEPS = (
    ("run_test_circuit_protection.py", "分类"),
    ("run_test_circuit_protection_attr.py", "属性 EAV"),
    ("run_test_circuit_protection_l2.py", "品牌 + L2 宽表"),
    ("audit/run_phase55_audit.py", "Phase 5.5 QA"),
)


def main() -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    for script, label in STEPS:
        print(f"\n{'='*60}\n>>> {label}: {script}\n{'='*60}")
        if script.startswith("audit/"):
            cmd = [sys.executable, str(HERE / script)]
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
