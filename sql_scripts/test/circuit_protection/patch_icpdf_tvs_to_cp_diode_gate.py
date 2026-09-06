#!/usr/bin/env python3
"""ICPDF TVS 让渡 CP：从 gate_diode_icpdf_v1 白名单移除 TVS/瞬态抑制字面（学得捷 CP 优先）。"""
from __future__ import annotations

import csv
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
SEED = ROOT / "sql_scripts" / "1.classify" / "seed" / "dim_l3_classify_rule.csv"
DIODE_RULE = "gate_diode_icpdf_v1"
TVS_DROP = {"TVS二极管", "瞬态抑制二极管", "瞬态抑制器"}


def strip_diode_tvs(row: dict) -> bool:
    if row.get("rule_id") != DIODE_RULE:
        return False
    raw = (row.get("match_values") or "").strip()
    if not raw.startswith("["):
        return False
    vals = json.loads(raw)
    if not isinstance(vals, list):
        return False
    new_vals = [v for v in vals if v not in TVS_DROP]
    if new_vals == vals:
        return False
    row["match_values"] = json.dumps(new_vals, ensure_ascii=False)
    note = (row.get("note") or "").strip()
    if "TVS" not in note:
        row["note"] = (note + "；TVS/瞬态抑制归 circuit_protection icpdf gate").strip("；")
    return True


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    ap = __import__("argparse").ArgumentParser()
    ap.add_argument("--write", action="store_true")
    args = ap.parse_args()

    rows = list(csv.DictReader(SEED.open(encoding="utf-8")))
    fieldnames = list(rows[0].keys())
    changed = sum(1 for r in rows if strip_diode_tvs(r))
    print(f"  diode TVS strip: {changed} row(s)")

    if not args.write:
        print("dry-run; use --write")
        return 0

    with SEED.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=fieldnames, extrasaction="ignore")
        w.writeheader()
        w.writerows(rows)
    print(f"wrote {SEED}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
