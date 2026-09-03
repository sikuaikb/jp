#!/usr/bin/env python3
"""跨 L1 gate category 重叠校验器（合并前机械门控）。

主干分类引擎按 (data_source, id) 全局决选；若多个 L1 的 gate 同时纳入同一
DigiKey/icpdf category，合并后会出现跨 L1 争用（阶段 1 孤立沙盒无法发现）。

用法（合并前，prod dim + 待合并沙盒 overlay）：
    python3 validate_cross_l1_gate_overlap.py \\
        --prod-schema dim \\
        --sandbox-schema test_dim \\
        --sandbox-l1 circuit_protection \\
        --data-source icpdf \\
        --new-overlap-only \\
        --classify-seed-csv sql_scripts/1.classify/seed/dim_l3_classify_rule.csv \\
        --coordination-gate-rule-ids gate_diode_icpdf_v1

仅扫 prod（无沙盒 overlay）：
    python3 validate_cross_l1_gate_overlap.py --prod-schema dim --data-source digikey

退出码：0 = 通过；1 = FAIL。
  --new-overlap-only：仅 fail 待合并 L1 **新增** gate 争用（prod 历史重叠放行）。
"""
from __future__ import annotations

import argparse
import csv
import json
import re
import sys
from collections import defaultdict
from pathlib import Path

GATE_RULE_RE = re.compile(r"^gate_(.+?)_(?:digikey|icpdf|ecloud)_", re.I)


def parse_match_values(raw: str) -> list[str]:
    s = (raw or "").strip()
    if not s:
        return []
    if s.startswith("["):
        try:
            v = json.loads(s)
            if isinstance(v, list):
                return [str(x).strip() for x in v if str(x).strip()]
        except json.JSONDecodeError:
            pass
    if "|" in s:
        return [p.strip() for p in s.split("|") if p.strip()]
    return [s]


def l1_from_rule_id(rule_id: str) -> str | None:
    m = GATE_RULE_RE.match(rule_id.strip())
    return m.group(1) if m else None


def fetch_gate_rows(schema: str, table: str, data_source: str | None) -> list[dict]:
    from dim_db_loader import fetch_rows

    cols = [
        "rule_id", "data_source", "rule_kind", "enabled",
        "field_code", "match_values",
    ]
    rows = fetch_rows(schema, table, cols)
    out: list[dict] = []
    for r in rows:
        if (r.get("rule_kind") or "").strip() != "gate":
            continue
        if str(r.get("enabled") or "").strip() not in ("1", "1.0"):
            continue
        fc = (r.get("field_code") or "").strip()
        if fc not in ("category_in", "category2_in"):
            continue
        ds = (r.get("data_source") or "").strip()
        if data_source and ds != data_source:
            continue
        l1 = l1_from_rule_id(r.get("rule_id") or "")
        if not l1:
            continue
        for cat in parse_match_values(r.get("match_values") or ""):
            out.append({
                "l1_code": l1,
                "data_source": ds,
                "field_code": fc,
                "category": cat,
                "rule_id": (r.get("rule_id") or "").strip(),
            })
    return out


def fetch_gate_rows_from_seed(
    seed_csv: Path,
    data_source: str | None,
    rule_ids: set[str],
) -> list[dict]:
    out: list[dict] = []
    if not seed_csv.exists():
        return out
    with seed_csv.open(encoding="utf-8", newline="") as f:
        for row in csv.DictReader(f):
            rid = (row.get("rule_id") or "").strip()
            if rid not in rule_ids:
                continue
            if (row.get("rule_kind") or "").strip() != "gate":
                continue
            ds = (row.get("data_source") or "").strip()
            if data_source and ds != data_source:
                continue
            fc = (row.get("field_code") or "").strip()
            if fc not in ("category_in", "category2_in"):
                continue
            l1 = l1_from_rule_id(rid)
            if not l1:
                continue
            for cat in parse_match_values(row.get("match_values") or ""):
                out.append(
                    {
                        "l1_code": l1,
                        "data_source": ds,
                        "field_code": fc,
                        "category": cat,
                        "rule_id": rid,
                    }
                )
    return out


def build_overlap_index(rows: list[dict]) -> dict[tuple[str, str, str], dict[str, set[str]]]:
    """(data_source, field_code, category) -> l1_code -> rule_ids"""
    idx: dict[tuple[str, str, str], dict[str, set[str]]] = defaultdict(lambda: defaultdict(set))
    for r in rows:
        key = (r["data_source"], r["field_code"], r["category"])
        idx[key][r["l1_code"]].add(r["rule_id"])
    return idx


def overlap_messages(
    idx: dict[tuple[str, str, str], dict[str, set[str]]],
    prefix: str = "G1",
) -> list[str]:
    fails: list[str] = []
    for (ds, fc, cat), l1_map in sorted(idx.items()):
        if len(l1_map) <= 1:
            continue
        detail = "; ".join(f"{l1}←{','.join(sorted(rids))}" for l1, rids in sorted(l1_map.items()))
        fails.append(f"{prefix} [{ds}] {fc} category={cat!r} 被 {len(l1_map)} 个 L1 gate 同时纳入: {detail}")
    return fails


def apply_sandbox_overlay(
    prod_rows: list[dict],
    sandbox_schema: str,
    sandbox_l1: str,
    data_source: str | None,
    prod_rule_table: str,
) -> list[dict]:
    sandbox_table = f"dim_l3_classify_rule_{sandbox_l1}"
    sandbox_rows = fetch_gate_rows(sandbox_schema, sandbox_table, data_source)
    prefix = f"gate_{sandbox_l1}_"
    kept = [
        r
        for r in prod_rows
        if not (r["l1_code"] == sandbox_l1 or r["rule_id"].startswith(prefix))
    ]
    return kept + sandbox_rows


def apply_coordination_overlay(
    rows: list[dict],
    seed_csv: Path | None,
    rule_ids: set[str],
    data_source: str | None,
) -> list[dict]:
    if not seed_csv or not rule_ids:
        return rows
    kept = [r for r in rows if r["rule_id"] not in rule_ids]
    kept.extend(fetch_gate_rows_from_seed(seed_csv, data_source, rule_ids))
    return kept


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--prod-schema", default="dim", help="prod dim schema（默认 dim）")
    ap.add_argument("--prod-rule-table", default="dim_l3_classify_rule")
    ap.add_argument("--sandbox-schema", help="沙盒 test_dim schema；与 --sandbox-l1 合用")
    ap.add_argument("--sandbox-l1", help="待合并 L1，overlay 其 gate 规则（替换 prod 同前缀）")
    ap.add_argument("--data-source", help="仅检查某源，如 digikey")
    ap.add_argument(
        "--new-overlap-only",
        action="store_true",
        help="仅 fail 待合并 L1 相对 prod 基线新增的 gate 争用",
    )
    ap.add_argument(
        "--classify-seed-csv",
        type=Path,
        help="classify seed CSV；配合 --coordination-gate-rule-ids 覆盖 prod gate 行",
    )
    ap.add_argument(
        "--coordination-gate-rule-ids",
        nargs="*",
        default=[],
        help="merge 协调 gate rule_id（如 gate_diode_icpdf_v1 从 seed 覆盖）",
    )
    args = ap.parse_args()

    prod_baseline = fetch_gate_rows(args.prod_schema, args.prod_rule_table, args.data_source)
    merged = list(prod_baseline)

    if args.sandbox_schema and args.sandbox_l1:
        merged = apply_sandbox_overlay(
            prod_baseline,
            args.sandbox_schema,
            args.sandbox_l1,
            args.data_source,
            args.prod_rule_table,
        )
        src = (
            f"{args.prod_schema}.{args.prod_rule_table} + overlay "
            f"{args.sandbox_schema}.dim_l3_classify_rule_{args.sandbox_l1}"
        )
    else:
        src = f"{args.prod_schema}.{args.prod_rule_table}"

    coord_ids = set(args.coordination_gate_rule_ids)
    merged = apply_coordination_overlay(merged, args.classify_seed_csv, coord_ids, args.data_source)

    baseline_idx = build_overlap_index(prod_baseline)
    merged_idx = build_overlap_index(merged)

    if args.new_overlap_only:
        if not args.sandbox_l1:
            print("ERROR: --new-overlap-only 需要 --sandbox-l1", file=sys.stderr)
            return 1
        sandbox = args.sandbox_l1
        fails: list[str] = []
        for key, l1_map in sorted(merged_idx.items()):
            if len(l1_map) <= 1:
                continue
            if sandbox not in l1_map:
                continue
            base_map = baseline_idx.get(key, {})
            if sandbox in base_map:
                continue
            ds, fc, cat = key
            detail = "; ".join(f"{l1}←{','.join(sorted(rids))}" for l1, rids in sorted(l1_map.items()))
            fails.append(
                f"G1-NEW [{ds}] {fc} category={cat!r} 待合并 L1 新增争用: {detail}"
            )
        if fails:
            print(f"跨 L1 gate 新增争用 FAIL（{len(fails)} 处）  src={src}", file=sys.stderr)
            for f in fails:
                print(f"  {f}", file=sys.stderr)
            print(
                "修复方向：从一方 gate 移除该 category，或 merge 协调 patch seed + apply SQL。",
                file=sys.stderr,
            )
            return 1
        print(
            f"跨 L1 gate 新增争用校验通过（0 处）  src={src}  "
            f"prod历史重叠={len(overlap_messages(baseline_idx))}  merge总重叠={len(overlap_messages(merged_idx))}"
        )
        return 0

    fails = overlap_messages(merged_idx)
    if fails:
        print(f"跨 L1 gate 重叠校验 FAIL（{len(fails)} 处）  src={src}", file=sys.stderr)
        for f in fails:
            print(f"  {f}", file=sys.stderr)
        print("修复方向：认商城 path / taxonomy 边界，从一方 gate 移除该 category，或协调 phase/规则优先级。", file=sys.stderr)
        return 1

    print(f"跨 L1 gate 重叠校验通过（0 处重叠）  src={src}  rows={len(merged)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
