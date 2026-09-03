#!/usr/bin/env python3
"""merge 协调：从 diode icpdf gate 让渡 TVS 类 category 给 circuit_protection。

G1 机械门控要求 CP merge 不得新增 gate 争用。ICPDF TVS 归 circuit_protection
（与 DigiKey TVS→CP 一致），须从 gate_diode_icpdf_v1 白名单移除下列字面。

用法（在仓库根目录）：
  python sql_scripts/test/circuit_protection/patch_diode_icpdf_gate_tvs_cede.py
  python sql_scripts/test/circuit_protection/patch_diode_icpdf_gate_tvs_cede.py --write
"""
from __future__ import annotations

import argparse
import csv
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
SEED = ROOT / "sql_scripts" / "1.classify" / "seed" / "dim_l3_classify_rule.csv"
RULE_ID = "gate_diode_icpdf_v1"

# 让渡给 circuit_protection icpdf gate（gate_circuit_protection_icpdf_v1 category_in）
CEDE_TO_CP: set[str] = {
    "TVS二极管",
    "瞬态抑制二极管",
    "瞬态抑制器",
}


def patch_row(row: dict) -> bool:
    if row.get("rule_id") != RULE_ID:
        return False
    raw = (row.get("match_values") or "").strip()
    if not raw.startswith("["):
        return False
    vals = json.loads(raw)
    if not isinstance(vals, list):
        return False
    new_vals = [v for v in vals if v not in CEDE_TO_CP]
    if len(new_vals) == len(vals):
        return False
    row["match_values"] = json.dumps(new_vals, ensure_ascii=False)
    note = (row.get("note") or "").strip()
    suffix = "；TVS/瞬态抑制类已让渡 circuit_protection icpdf gate"
    if suffix not in note:
        row["note"] = (note + suffix) if note else suffix.lstrip("；")
    return True


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser()
    ap.add_argument("--write", action="store_true", help="写回 CSV（默认 dry-run）")
    args = ap.parse_args()

    if not SEED.exists():
        print(f"ERROR: missing {SEED}", file=sys.stderr)
        return 1

    with SEED.open(encoding="utf-8", newline="") as f:
        rows = list(csv.DictReader(f))
    fieldnames = rows[0].keys() if rows else []

    changed = 0
    for row in rows:
        if patch_row(row):
            changed += 1
            print(f"  patched {row['rule_id']} clause {row['clause_group_id']} · removed {CEDE_TO_CP}")

    if changed == 0:
        print("no changes needed")
        return 0

    if args.write:
        with SEED.open("w", encoding="utf-8", newline="") as f:
            w = csv.DictWriter(f, fieldnames=fieldnames)
            w.writeheader()
            w.writerows(rows)
        print(f"wrote {changed} row(s) -> {SEED}")
        emit_apply_sql(rows)
    else:
        print(f"dry-run: would patch {changed} row(s); re-run with --write")


def array_sql(json_text: str) -> str:
    vals = json.loads(json_text)
    inner = ",".join("'" + str(v).replace("'", "''") + "'" for v in vals)
    return f"ARRAY<VARCHAR(128)>[{inner}]"


def emit_apply_sql(rows: list[dict]) -> None:
    out = ROOT / "sql_scripts" / "test" / "circuit_protection" / "dim_l3_classify_rule_diode_icpdf_tvs_cede_apply.sql"
    lines = [
        "/* merge 协调：ICPDF TVS/瞬态抑制 gate 让渡 circuit_protection",
        " * 在 circuit_protection classify-merge 前/后执行于 prod dim",
        " * 生成：patch_diode_icpdf_gate_tvs_cede.py --write",
        " */",
        "",
    ]
    for row in rows:
        if row.get("rule_id") != RULE_ID:
            continue
        cg = row["clause_group_id"]
        co = row["clause_ord"]
        arr = array_sql(row["match_values"])
        note = row.get("note", "").replace("'", "''")
        lines.append(
            f"UPDATE dim.dim_l3_classify_rule\n"
            f"SET match_values = {arr},\n"
            f"    note = '{note}'\n"
            f"WHERE rule_id = '{RULE_ID}' AND clause_group_id = {cg} AND clause_ord = {co};\n"
        )
    out.write_text("\n".join(lines), encoding="utf-8")
    print(f"wrote apply SQL -> {out}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
