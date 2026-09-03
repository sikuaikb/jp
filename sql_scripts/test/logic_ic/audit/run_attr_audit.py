#!/usr/bin/env python3
"""logic_ic 属性阶段 1B 一轮审计编排（prajson×schema 全量 + 抽样 + 规则覆盖）。"""
from __future__ import annotations

import csv
import subprocess
import sys
from collections import Counter
from datetime import date
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")

HERE = Path(__file__).resolve().parent
LOGIC = HERE.parent
SQL_ROOT = LOGIC.parents[1]
ART = SQL_ROOT / "artifacts" / "logic_ic"
DATE = str(date.today())
REPORT = ART / f"qa_audit_report_logic_ic_attr_{DATE}.md"


def run_step(cmd: list[str], title: str) -> int:
    print(f"\n{'='*60}\n>> {title}\n{'='*60}")
    return subprocess.run(cmd, cwd=LOGIC).returncode


def load_coverage() -> list[dict]:
    p = ART / "attr_rule_coverage.tsv"
    if not p.exists():
        return []
    return list(csv.DictReader(p.open(encoding="utf-8-sig")))


def load_attr_audit() -> list[dict]:
    p = ART / f"l3_prajson_schema_attr_{DATE}.tsv"
    if not p.exists():
        return []
    return list(csv.DictReader(p.open(encoding="utf-8-sig")))


def load_sample_tsv() -> list[dict]:
    p = ART / f"l3_prajson_sample_analysis_{DATE}.tsv"
    if not p.exists():
        return []
    return list(csv.DictReader(p.open(encoding="utf-8-sig")))


def main() -> int:
    py = sys.executable
    steps = [
        ([py, str(LOGIC / "gen_attr_seed_logic_ic.py")], "生成 schema CSV"),
        ([py, str(LOGIC / "gen_attr_extract_rule_logic_ic.py")], "生成抽取规则 CSV"),
        ([py, str(HERE / "probe_digikey_keys.py")], "L3×prajson key 频次"),
        ([py, str(HERE / "l3_prajson_sample_analysis.py")], "每 L3 1 条样本映射"),
        ([py, str(HERE / "l3_prajson_schema_full_audit.py")], "全量 prajson×schema 审计"),
    ]
    rc = 0
    for cmd, title in steps:
        rc |= run_step(cmd, title)

    coverage = load_coverage()
    attr_rows = load_attr_audit()
    sample_rows = load_sample_tsv()

    missing_rules = [r for r in coverage if r.get("status") == "MISSING"]
    gap_counter = Counter(r.get("gap_type", "?") for r in attr_rows)
    key_gaps = [r for r in attr_rows if r.get("gap_type") == "KEY_MAPPING_GAP"]
    low_cov = [r for r in attr_rows if r.get("gap_type") in ("LOW_COVERAGE", "DK_NO_FIELD")]

    sample_hit = sum(1 for r in sample_rows if r.get("status") == "HIT")
    sample_total = len(sample_rows) or 1

    good_attrs = [r for r in attr_rows if float(r.get("prajson_hit_pct", 0)) >= 50]
    overall = "PASS" if not missing_rules and len(key_gaps) <= 15 else "WARN"
    if missing_rules:
        overall = "FAIL"

    lines = [
        f"# logic_ic 属性审计报告 · {DATE}",
        "",
        f"**总判定：{overall}**",
        "",
        "## 1. 执行步骤",
        "",
        "| 步骤 | 脚本 |",
        "|------|------|",
        "| schema | `gen_attr_seed_logic_ic.py` |",
        "| 规则 | `gen_attr_extract_rule_logic_ic.py` |",
        "| key 频次 | `audit/probe_digikey_keys.py` |",
        "| 样本映射 | `audit/l3_prajson_sample_analysis.py` |",
        "| 全量审计 | `audit/l3_prajson_schema_full_audit.py` |",
        "",
        "## 2. 规则覆盖",
        "",
        f"- schema 行数（coverage 条目）：**{len(coverage)}**",
        f"- MISSING 规则：**{len(missing_rules)}**",
        "",
        "## 3. 抽样映射（每 L3 1 SKU）",
        "",
        f"- 属性检查行：**{len(sample_rows)}**",
        f"- HIT：**{sample_hit}**（{100*sample_hit/sample_total:.1f}%）",
        "",
        "## 4. 全量 prajson×schema",
        "",
        f"- 属性审计行：**{len(attr_rows)}**",
        f"- prajson 命中≥50% 的属性：**{len(good_attrs)}**",
        "",
        "### 差距类型分布",
        "",
        "| gap_type | 行数 |",
        "|----------|-----:|",
    ]
    for gt, n in gap_counter.most_common():
        lines.append(f"| {gt} | {n} |")

    lines += ["", "### KEY_MAPPING_GAP（需补规则 key）", ""]
    if key_gaps:
        lines.append("| L3 | 属性 | hit% | miss | 候选 key |")
        lines.append("|----|------|-----:|-----:|----------|")
        for r in sorted(key_gaps, key=lambda x: -int(x.get("prajson_miss_key", 0)))[:20]:
            lines.append(
                f"| `{r['l3_code']}` | `{r['std_attr_code']}` | {r['prajson_hit_pct']}% "
                f"| {r['prajson_miss_key']} | {r.get('candidate_keys', '')[:50]} |"
            )
    else:
        lines.append("无。")

    lines += ["", "### LOW_COVERAGE / DK_NO_FIELD（DK 缺字段或稀疏）", ""]
    sparse = sorted(low_cov, key=lambda x: float(x.get("prajson_hit_pct", 0)))[:15]
    if sparse:
        for r in sparse:
            lines.append(
                f"- `{r['l3_code']}/{r['std_attr_code']}` hit={r['prajson_hit_pct']}% "
                f"no_data={r['prajson_no_data']}"
            )
    else:
        lines.append("无突出项。")

    lines += [
        "",
        "## 5. 产出文件",
        "",
        f"- [`l3_prajson_sample_analysis_{DATE}.md`](l3_prajson_sample_analysis_{DATE}.md)",
        f"- [`l3_prajson_schema_full_audit_{DATE}.md`](l3_prajson_schema_full_audit_{DATE}.md)",
        f"- [`l3_prajson_schema_attr_{DATE}.tsv`](l3_prajson_schema_attr_{DATE}.tsv)",
        f"- [`digikey_prajson_keys_by_l3_{DATE}.tsv`](digikey_prajson_keys_by_l3_{DATE}.tsv)",
        f"- [`attr_rule_coverage.tsv`](attr_rule_coverage.tsv)",
        "",
        "## 6. 说明",
        "",
        "- 本轮 **未跑 EAV**（`dwd_component_attr_std_logic_ic` 尚未 build）；gap 仅基于 prajson 规则命中。",
        "- 分类阶段 1A 已完成；属性 EAV/L2 为后续步骤。",
        "",
        "```bash",
        "python audit/run_attr_audit.py",
        "```",
    ]

    ART.mkdir(parents=True, exist_ok=True)
    REPORT.write_text("\n".join(lines) + "\n", encoding="utf-8")

    print(f"\n{'='*60}")
    print(f"总判定: {overall}")
    print(f"报告: {REPORT}")
    return 0 if overall != "FAIL" else 1


if __name__ == "__main__":
    sys.exit(main())
