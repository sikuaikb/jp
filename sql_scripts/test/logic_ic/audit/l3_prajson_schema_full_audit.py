#!/usr/bin/env python3
"""每个 L3 全量 SKU：逐条 prajson 对照 schema 属性规则，汇总映射覆盖率。"""
from __future__ import annotations

import csv
import json
import os
import re
import sys
from collections import Counter, defaultdict
from datetime import date
from pathlib import Path

import pymysql

sys.stdout.reconfigure(encoding="utf-8")

HERE = Path(__file__).resolve().parents[1]
SQL_ROOT = HERE.parents[1]
SCHEMA_CSV = HERE / "seed" / "dim_attr_schema_logic_ic.csv"
RULES_CSV = HERE / "seed" / "dim_attr_extract_rule_logic_ic.csv"
ARTIFACTS = SQL_ROOT / "artifacts" / "logic_ic"
DATE_STR = str(date.today())
OUT_ATTR_TSV = ARTIFACTS / f"l3_prajson_schema_attr_{DATE_STR}.tsv"
OUT_KEY_TSV = ARTIFACTS / f"l3_prajson_schema_keys_{DATE_STR}.tsv"
OUT_MD = ARTIFACTS / f"l3_prajson_schema_full_audit_{DATE_STR}.md"

ADMIN_KEYS = {
    "DigiKey 零件编号", "ECCN", "HTSUS", "category", "category_path",
    "制造商", "制造商产品编号", "制造商标准包装", "描述", "类别", "系列",
    "详细描述", "零件状态", "Part Number Alias", "包装",
    "湿气敏感性等级 (MSL)", "REACH 状态", "环保信息", "特色产品",
    "RoHS 状态", "PCN 产品变更/停产", "报价表", "计价货币", "库存数量",
    "原厂标准交货期", "基本产品编号", "产品培训模块", "PCN 组装/来源",
    "测试条件", "EDA 模型", "EDA/CAD 模型", "Forum Discussions",
    "其他名称", "PCN 封装", "PCN 设计/规格", "PCN 其他", "PCN 零件状态变更",
}

HINTS: dict[str, list[str]] = {
    "propagation_delay_ns": ["传播", "延迟", "tpd"],
    "supply_voltage_min_v": ["供电", "电压"],
    "supply_voltage_max_v": ["供电", "电压"],
    "bit_width": ["位数"],
    "element_count": ["元件"],
    "bits_per_element": ["每个元件", "位数"],
    "logic_type": ["逻辑"],
    "input_count": ["输入"],
    "circuit_count": ["电路"],
    "shift_function": ["功能", "移位"],
    "comparator_type": ["类型"],
    "output_function": ["输出功能"],
    "comparator_output": ["输出"],
    "circuit_config": ["电路", "开关"],
    "supply_voltage_type": ["供电电压源"],
    "input_type": ["输入类型"],
    "input_capacitance_pf": ["电容"],
    "switch_type": ["类型"],
    "output_type_gate": ["输出", "特性"],
    "output_type_ff": ["输出"],
    "output_type_sr": ["输出"],
    "output_type_buf": ["输出"],
    "output_type_xcvr": ["输出"],
    "output_current_high_low": ["电流", "输出"],
    "schmitt_trigger_input": ["施密特"],
    "mount_type": ["安装"],
    "package_case": ["封装"],
    "manufacturer": ["制造"],
    "mpn": ["产品编号"],
}


def load_env() -> None:
    for line in (SQL_ROOT / "local.env").read_text(encoding="utf-8").splitlines():
        if line.strip().startswith("export "):
            k, _, v = line.strip()[7:].partition("=")
            os.environ[k] = v.strip().strip("'").strip('"')


def load_schema() -> tuple[dict[str, list[dict]], dict[str, list[dict]]]:
    rows = list(csv.DictReader(SCHEMA_CSV.open(encoding="utf-8-sig")))
    l3: dict[str, list[dict]] = defaultdict(list)
    l2: dict[str, list[dict]] = defaultdict(list)
    for r in rows:
        if r["scope_level"] == "l3":
            l3[r["scope_code"]].append(r)
        elif r["scope_level"] == "l2":
            l2[r["scope_code"]].append(r)
    return dict(l3), dict(l2)


def load_rules() -> dict:
    rows = list(csv.DictReader(RULES_CSV.open(encoding="utf-8-sig")))
    l3: dict[tuple[str, str], list[dict]] = defaultdict(list)
    l2: dict[tuple[str, str], list[dict]] = defaultdict(list)
    global_: dict[str, list[dict]] = defaultdict(list)
    key_to_attrs: dict[str, set[str]] = defaultdict(set)
    for r in rows:
        if r["source_kind"] != "prajson2_key_eq":
            continue
        sl = r["apply_scope_level"] or "global"
        sc = r["apply_scope_code"] or "*"
        attr = r["std_attr_code"]
        key_to_attrs[r["source_expr"]].add(attr)
        if sl == "l3":
            l3[(sc, attr)].append(r)
        elif sl == "l2":
            l2[(sc, attr)].append(r)
        else:
            global_[attr].append(r)
    return {"l3": l3, "l2": l2, "global": global_, "key_to_attrs": key_to_attrs}


def rules_for(rules: dict, l3: str, l2: str, attr: str, scope_level: str) -> list[dict]:
    out: list[dict] = []
    if scope_level == "l3":
        out.extend(rules["l3"].get((l3, attr), []))
    elif scope_level == "l2":
        out.extend(rules["l2"].get((l2, attr), []))
    out.extend(rules["global"].get(attr, []))
    return out


def try_regex(val: str, pattern: str) -> str | None:
    if not pattern:
        return val if val else None
    try:
        m = re.search(pattern, val)
        return m.group(1) if m and m.lastindex else (m.group(0) if m else None)
    except re.error:
        return None


def eval_attr(pj: dict, rule_list: list[dict], attr: str) -> str:
    if not rule_list:
        return "NO_RULE"
    for rule in sorted(rule_list, key=lambda x: int(x["priority"])):
        key = rule["source_expr"]
        if key not in pj:
            continue
        raw = str(pj[key] or "").strip()
        if not raw:
            continue
        regex = rule.get("source_value_regex") or ""
        if regex:
            return "HIT" if try_regex(raw, regex) else "KEY_HIT_REGEX_FAIL"
        return "HIT"
    param_keys = {k for k, v in pj.items() if k not in ADMIN_KEYS and str(v or "").strip()}
    hints = HINTS.get(attr, [attr.split("_")[0]])
    for k in param_keys:
        v = str(pj[k])
        if any(h in k or h in v for h in hints):
            return "MISS_KEY"
    return "NO_DATA"


def gap_label(hit_pct: float, miss: int, nodata: int) -> str:
    if hit_pct >= 50:
        return "GOOD"
    if miss > nodata:
        return "KEY_MAPPING_GAP"
    if nodata > 0:
        return "DK_NO_FIELD"
    if hit_pct >= 10:
        return "PARTIAL"
    return "LOW_COVERAGE"


def main() -> None:
    load_env()
    schema_l3, schema_l2 = load_schema()
    rules = load_rules()
    key_to_attrs = rules["key_to_attrs"]

    conn = pymysql.connect(
        host=os.environ["MYSQL_HOST"],
        port=int(os.environ.get("MYSQL_PORT", "9030")),
        user=os.environ["MYSQL_USER"],
        password=os.environ["MYSQL_PASSWORD"],
        charset="utf8mb4",
        cursorclass=pymysql.cursors.DictCursor,
    )
    cur = conn.cursor()
    cur.execute("SET query_timeout = 900")

    cur.execute(
        """
        SELECT c.l2_code, c.l3_code, COUNT(DISTINCT c.id) AS n
        FROM test_dwd.dwd_component_class_logic_ic c
        WHERE c.data_source = 'digikey'
        GROUP BY c.l2_code, c.l3_code
        HAVING n > 0
        ORDER BY n DESC
        """
    )
    l3_list = cur.fetchall()

    attr_rows: list[dict] = []
    key_rows: list[dict] = []
    md_parts = [
        f"# logic_ic L3 prajson × schema 全量审计",
        f"**日期**: {DATE_STR}",
        "**方法**: 每个已命中 L3 的全部 SKU 逐条解析 `prajson`，对照 schema + 抽取规则（**无 EAV 对比**）。",
        "",
        "---",
        "",
    ]

    total_skus = 0
    for item in l3_list:
        l2, l3, pop = item["l2_code"], item["l3_code"], int(item["n"])
        cur.execute(
            """
            SELECT c.id, p.partno, p.prajson
            FROM test_dwd.dwd_component_class_logic_ic c
            JOIN dwd.dwd_digikey_component_param p ON p.id = c.id
            WHERE c.data_source = 'digikey' AND c.l3_code = %s AND p.prajson IS NOT NULL
            """,
            (l3,),
        )
        records = cur.fetchall()
        if not records:
            continue
        total_skus += len(records)

        key_freq: Counter[str] = Counter()
        key_sample_val: dict[str, str] = {}
        applicable: list[tuple[str, dict]] = []
        for r in schema_l3.get(l3, []):
            applicable.append(("l3", r))
        for r in schema_l2.get(l2, []):
            applicable.append(("l2", r))

        attr_stats: dict[tuple[str, str], Counter] = defaultdict(Counter)
        attr_miss_sample: dict[tuple[str, str], str] = {}

        for rec in records:
            pj = json.loads(rec["prajson"]) if isinstance(rec["prajson"], str) else rec["prajson"]
            if not isinstance(pj, dict):
                continue
            mpn = pj.get("制造商产品编号") or rec["partno"]

            for k, v in pj.items():
                if k in ADMIN_KEYS or not str(v or "").strip():
                    continue
                key_freq[k] += 1
                if k not in key_sample_val:
                    key_sample_val[k] = str(v)[:80]

            for scope_level, sch in applicable:
                attr = sch["std_attr_code"]
                key = (scope_level, attr)
                rl = rules_for(rules, l3, l2, attr, scope_level)
                status = eval_attr(pj, rl, attr)
                attr_stats[key][status] += 1
                if status in ("MISS_KEY", "KEY_HIT_REGEX_FAIL") and key not in attr_miss_sample:
                    attr_miss_sample[key] = mpn

        n_rec = len(records)
        l3_attr_summary: list[dict] = []

        for scope_level, sch in applicable:
            attr = sch["std_attr_code"]
            key = (scope_level, attr)
            st = attr_stats[key]
            hit = st.get("HIT", 0)
            miss = st.get("MISS_KEY", 0)
            nodata = st.get("NO_DATA", 0)
            regex_fail = st.get("KEY_HIT_REGEX_FAIL", 0)
            no_rule = st.get("NO_RULE", 0)
            hit_pct = 100.0 * hit / n_rec if n_rec else 0
            gap = gap_label(hit_pct, miss, nodata)

            rl = rules_for(rules, l3, l2, attr, scope_level)
            rule_keys = "|".join(dict.fromkeys(r["source_expr"] for r in rl)) or "(无)"

            candidates = []
            if miss > 0:
                hints = HINTS.get(attr, [attr.split("_")[0]])
                for k, cnt in key_freq.most_common():
                    if k in {r["source_expr"] for r in rl}:
                        continue
                    v = key_sample_val.get(k, "")
                    if any(h in k or h in v for h in hints):
                        candidates.append(f"{k}({cnt})")
                    if len(candidates) >= 3:
                        break

            row = {
                "l3_code": l3,
                "l2_code": l2,
                "scope_level": scope_level,
                "std_attr_code": attr,
                "std_attr_cn": sch["std_attr_cn"],
                "sku_count": n_rec,
                "prajson_hit": hit,
                "prajson_miss_key": miss,
                "prajson_no_data": nodata,
                "prajson_regex_fail": regex_fail,
                "prajson_no_rule": no_rule,
                "prajson_hit_pct": f"{hit_pct:.1f}",
                "gap_type": gap,
                "rule_keys": rule_keys,
                "candidate_keys": "; ".join(candidates),
                "sample_mpn_gap": attr_miss_sample.get(key, ""),
            }
            attr_rows.append(row)
            l3_attr_summary.append(row)

        for k, cnt in key_freq.most_common():
            mapped = sorted(key_to_attrs.get(k, set()))
            key_rows.append({
                "l3_code": l3,
                "l2_code": l2,
                "prajson_key": k,
                "sku_count": cnt,
                "sku_pct": f"{100.0 * cnt / n_rec:.1f}",
                "mapped_attrs": "|".join(mapped) if mapped else "(未映射)",
                "sample_value": key_sample_val.get(k, ""),
            })

        gap_attrs = [r for r in l3_attr_summary if r["gap_type"] == "KEY_MAPPING_GAP"]
        md_parts += [
            f"## {l3}（{pop:,} SKU，实查 {n_rec:,} 条有 prajson）",
            "",
            f"| L2 | `{l2}` | schema 属性数 | {len(applicable)} |",
            f"| prajson 技术 key 种类 | {len(key_freq)} | 已映射 key | "
            f"{sum(1 for k in key_freq if key_to_attrs.get(k))} |",
            "",
            "### 属性 prajson 命中率",
            "",
            "| 层级 | 属性 | hit% | gap | 规则 key |",
            "|---|---|---:|---|---|",
        ]
        for r in sorted(l3_attr_summary, key=lambda x: (-float(x["prajson_hit_pct"]), x["std_attr_code"])):
            icon = {"GOOD": "✓", "KEY_MAPPING_GAP": "△", "DK_NO_FIELD": "○", "PARTIAL": "~", "LOW_COVERAGE": "×"}.get(
                r["gap_type"], "?"
            )
            md_parts.append(
                f"| {r['scope_level']} | `{r['std_attr_code']}` | {r['prajson_hit_pct']}% "
                f"| {icon} {r['gap_type']} | {r['rule_keys'][:40]} |"
            )

        unmapped = sorted(
            [kr for kr in key_rows if kr["l3_code"] == l3 and kr["mapped_attrs"] == "(未映射)"],
            key=lambda x: -x["sku_count"],
        )
        if unmapped[:6]:
            md_parts += ["", "### 高频未映射 prajson key", ""]
            for uk in unmapped[:6]:
                md_parts.append(
                    f"- `{uk['prajson_key']}` — {uk['sku_count']} SKU ({uk['sku_pct']}%) "
                    f"例: `{uk['sample_value'][:50]}`"
                )
        if gap_attrs:
            md_parts += ["", "### KEY_MAPPING_GAP", ""]
            for r in sorted(gap_attrs, key=lambda x: -int(x["prajson_miss_key"]))[:8]:
                md_parts.append(
                    f"- `{r['scope_level']}/{r['std_attr_code']}` hit={r['prajson_hit_pct']}% "
                    f"miss={r['prajson_miss_key']} — {r['candidate_keys'] or '(无)'}"
                )
        md_parts += ["", "---", ""]

    conn.close()

    ARTIFACTS.mkdir(parents=True, exist_ok=True)
    if attr_rows:
        with OUT_ATTR_TSV.open("w", newline="", encoding="utf-8-sig") as f:
            w = csv.DictWriter(f, fieldnames=list(attr_rows[0].keys()))
            w.writeheader()
            w.writerows(attr_rows)
    if key_rows:
        with OUT_KEY_TSV.open("w", newline="", encoding="utf-8-sig") as f:
            w = csv.DictWriter(f, fieldnames=list(key_rows[0].keys()))
            w.writeheader()
            w.writerows(key_rows)

    summary = Counter(r["gap_type"] for r in attr_rows)
    summary_lines = [
        f"**L3 数**: {len(l3_list)} | **实查 SKU**: {total_skus:,} | **属性审计行**: {len(attr_rows)}",
        "",
        "### 全局差距类型",
        "",
    ]
    for gt, n in summary.most_common():
        summary_lines.append(f"- {gt}: {n}")
    summary_lines += ["", "---", ""]
    md_parts = md_parts[:4] + summary_lines + md_parts[4:]

    OUT_MD.write_text("\n".join(md_parts), encoding="utf-8")

    print(f"L3 数: {len(l3_list)}")
    print(f"实查 SKU: {total_skus:,}")
    print(f"属性审计行: {len(attr_rows)}")
    print(f"prajson key 行: {len(key_rows)}")
    print("\n差距类型:")
    for gt, n in summary.most_common():
        print(f"  {gt}: {n}")
    key_gap = [r for r in attr_rows if r["gap_type"] == "KEY_MAPPING_GAP"]
    print(f"\nKEY_MAPPING_GAP ({len(key_gap)}):")
    for r in sorted(key_gap, key=lambda x: -int(x["prajson_miss_key"]))[:10]:
        print(
            f"  {r['l3_code']}.{r['std_attr_code']} hit={r['prajson_hit_pct']}% "
            f"miss={r['prajson_miss_key']}/{r['sku_count']}"
        )
    print(f"\n报告: {OUT_MD}")
    print(f"属性TSV: {OUT_ATTR_TSV}")
    print(f"Key TSV: {OUT_KEY_TSV}")


if __name__ == "__main__":
    main()
