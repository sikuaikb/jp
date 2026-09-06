#!/usr/bin/env python3
"""每个已命中 L3 各取 1 条真实 prajson，对照 schema/规则做映射分析。"""
from __future__ import annotations

import csv
import json
import os
import re
import sys
from collections import defaultdict
from datetime import date
from pathlib import Path

import pymysql

sys.stdout.reconfigure(encoding="utf-8")

HERE = Path(__file__).resolve().parents[1]
SQL_ROOT = HERE.parents[1]
SCHEMA_CSV = HERE / "seed" / "dim_attr_schema_logic_ic.csv"
RULES_CSV = HERE / "seed" / "dim_attr_extract_rule_logic_ic.csv"
ART = SQL_ROOT / "artifacts" / "logic_ic"
OUT_MD = ART / f"l3_prajson_sample_analysis_{date.today()}.md"
OUT_TSV = ART / f"l3_prajson_sample_analysis_{date.today()}.tsv"
OUT_JSON = ART / f"l3_prajson_samples_{date.today()}.json"

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
    "bits_per_element": ["每个元件"],
    "logic_type": ["逻辑"],
    "input_count": ["输入"],
    "circuit_count": ["电路"],
    "shift_function": ["功能", "移位"],
    "comparator_type": ["类型"],
    "output_function": ["输出功能"],
    "circuit_config": ["电路", "开关"],
    "supply_voltage_type": ["供电电压源"],
    "input_type": ["输入类型"],
    "input_capacitance_pf": ["电容"],
    "switch_type": ["类型"],
}


def load_env() -> None:
    env = SQL_ROOT / "local.env"
    for line in env.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line.startswith("export "):
            k, _, v = line[7:].partition("=")
            os.environ[k] = v.strip().strip("'").strip('"')


def load_schema_l3() -> dict[str, list[dict]]:
    rows = list(csv.DictReader(SCHEMA_CSV.open(encoding="utf-8-sig")))
    m: dict[str, list[dict]] = defaultdict(list)
    for r in rows:
        if r["scope_level"] == "l3":
            m[r["scope_code"]].append(r)
    return dict(m)


def load_rules() -> dict:
    rows = list(csv.DictReader(RULES_CSV.open(encoding="utf-8-sig")))
    by_attr: dict[tuple[str, str], list[dict]] = defaultdict(list)
    global_by_attr: dict[str, list[dict]] = defaultdict(list)
    l2_by_attr: dict[tuple[str, str], list[dict]] = defaultdict(list)
    for r in rows:
        if r["source_kind"] != "prajson2_key_eq":
            continue
        sl = r["apply_scope_level"] or "global"
        sc = r["apply_scope_code"] or "*"
        if sl == "l3":
            by_attr[(sc, r["std_attr_code"])].append(r)
        elif sl == "l2":
            l2_by_attr[(sc, r["std_attr_code"])].append(r)
        else:
            global_by_attr[r["std_attr_code"]].append(r)
    return {"l3": by_attr, "l2": l2_by_attr, "global": global_by_attr}


def rules_for_attr(rules: dict, l3: str, l2: str, attr: str, scope_level: str) -> list[dict]:
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


def analyze_attr(attr, attr_cn, scope_level, rule_list, pj, l2) -> dict:
    param_keys = {k for k in pj if k not in ADMIN_KEYS and str(pj.get(k) or "").strip()}
    hit_key = hit_val = extracted = None
    for rule in sorted(rule_list, key=lambda x: int(x["priority"])):
        key = rule["source_expr"]
        if key not in pj:
            continue
        raw = str(pj[key] or "").strip()
        if not raw:
            continue
        hit_key = key
        hit_val = raw[:120]
        regex = rule.get("source_value_regex") or ""
        extracted = try_regex(raw, regex) if regex else raw
        if extracted:
            break
    if hit_key:
        status = "HIT" if extracted else "KEY_HIT_REGEX_FAIL"
        note = f"key=`{hit_key}` val=`{hit_val}`"
    else:
        hints = HINTS.get(attr, [attr.split("_")[0]])
        candidates = []
        for k in param_keys:
            v = str(pj[k])[:60]
            if any(h in k or h in v for h in hints):
                candidates.append(f"{k}={v}")
        if candidates:
            status = "MISS_KEY"
            note = "候选: " + "; ".join(candidates[:3])
        else:
            status = "NO_DATA"
            note = "prajson 无相关参数 key"
    return {
        "std_attr_code": attr,
        "std_attr_cn": attr_cn,
        "scope_level": scope_level,
        "status": status,
        "rule_keys": "|".join(r["source_expr"] for r in rule_list) or "(无规则)",
        "note": note,
    }


def main() -> None:
    if not SCHEMA_CSV.exists() or not RULES_CSV.exists():
        print("请先运行: python gen_attr_seed_logic_ic.py && python gen_attr_extract_rule_logic_ic.py")
        sys.exit(1)

    load_env()
    schema_l3 = load_schema_l3()
    rules = load_rules()

    conn = pymysql.connect(
        host=os.environ["MYSQL_HOST"],
        port=int(os.environ.get("MYSQL_PORT", "9030")),
        user=os.environ["MYSQL_USER"],
        password=os.environ["MYSQL_PASSWORD"],
        charset="utf8mb4",
        cursorclass=pymysql.cursors.DictCursor,
    )
    cur = conn.cursor()
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

    samples, all_rows, json_samples = [], [], {}
    md_parts = [
        "# logic_ic L3 prajson 真实样本映射分析",
        f"**日期**: {date.today()}",
        "**方法**: 每个已命中 L3 取 1 条 SKU（`prajson` 最长），对照 L3 专规 + L2 公共规则",
        "",
        "---",
        "",
    ]

    l2_focus = [
        "manufacturer", "mpn", "package_case", "temp_min_c", "temp_max_c",
        "supply_voltage_min_v", "supply_voltage_max_v", "propagation_delay_ns",
        "output_current_high_low", "logic_series", "mount_type",
    ]

    for item in l3_list:
        l2, l3, pop = item["l2_code"], item["l3_code"], int(item["n"])
        cur.execute(
            """
            SELECT c.id, p.partno, p.brandshort, p.prajson
            FROM test_dwd.dwd_component_class_logic_ic c
            JOIN dwd.dwd_digikey_component_param p ON p.id = c.id
            WHERE c.data_source = 'digikey' AND c.l3_code = %s AND p.prajson IS NOT NULL
            ORDER BY LENGTH(p.prajson) DESC, c.id
            LIMIT 1
            """,
            (l3,),
        )
        row = cur.fetchone()
        if not row:
            continue
        pj = json.loads(row["prajson"]) if isinstance(row["prajson"], str) else row["prajson"]
        if not isinstance(pj, dict):
            continue

        mpn = pj.get("制造商产品编号") or row["partno"]
        brand = pj.get("制造商") or row["brandshort"]
        tech_keys = {
            k: str(pj[k])[:200]
            for k in sorted(pj)
            if k not in ADMIN_KEYS and str(pj.get(k) or "").strip()
        }
        json_samples[l3] = {"mpn": mpn, "brand": brand, "id": row["id"], "prajson_tech": tech_keys}

        l3_attrs = schema_l3.get(l3, [])
        l2_attrs = [
            r for r in csv.DictReader(SCHEMA_CSV.open(encoding="utf-8-sig"))
            if r["scope_level"] == "l2" and r["scope_code"] == l2
        ]

        analyses = []
        for r in l3_attrs:
            rl = rules_for_attr(rules, l3, l2, r["std_attr_code"], "l3")
            a = analyze_attr(r["std_attr_code"], r["std_attr_cn"], "l3", rl, pj, l2)
            analyses.append(a)
            all_rows.append({**a, "l2_code": l2, "l3_code": l3, "mpn": mpn, "pop": pop})
        for r in l2_attrs:
            if r["std_attr_code"] not in l2_focus:
                continue
            rl = rules_for_attr(rules, l3, l2, r["std_attr_code"], "l2")
            a = analyze_attr(r["std_attr_code"], r["std_attr_cn"], "l2", rl, pj, l2)
            analyses.append(a)
            all_rows.append({**a, "l2_code": l2, "l3_code": l3, "mpn": mpn, "pop": pop})

        hit = sum(1 for a in analyses if a["status"] == "HIT")
        miss = sum(1 for a in analyses if a["status"] == "MISS_KEY")
        nodata = sum(1 for a in analyses if a["status"] == "NO_DATA")
        regex_fail = sum(1 for a in analyses if a["status"] == "KEY_HIT_REGEX_FAIL")

        samples.append({"l3_code": l3, "pop": pop, "mpn": mpn})

        md_parts += [
            f"## {l3}（{pop:,} SKU）",
            "",
            f"| 样本 | {brand} / **{mpn}** |",
            f"| L2 | `{l2}` |",
            f"| 技术参数 key 数 | {len(tech_keys)} |",
            "",
            f"**映射统计**: HIT={hit} MISS_KEY={miss} NO_DATA={nodata} REGEX_FAIL={regex_fail}",
            "",
            "| 层级 | 属性 | 状态 | 规则 key | 说明 |",
            "|---|---|---|---|---|",
        ]
        for a in analyses:
            icon = {"HIT": "✓", "MISS_KEY": "△", "NO_DATA": "○", "KEY_HIT_REGEX_FAIL": "!"}.get(a["status"], "?")
            md_parts.append(
                f"| {a['scope_level']} | `{a['std_attr_code']}` | {icon} {a['status']} "
                f"| {a['rule_keys'][:50]} | {a['note'][:90]} |"
            )
        md_parts += ["", "**样本 prajson 技术参数（节选）**:", "", "```json"]
        md_parts.append(json.dumps(dict(list(tech_keys.items())[:20]), ensure_ascii=False, indent=2))
        md_parts += ["```", "", "---", ""]

    conn.close()
    ART.mkdir(parents=True, exist_ok=True)
    OUT_MD.write_text("\n".join(md_parts), encoding="utf-8")
    OUT_JSON.write_text(json.dumps(json_samples, ensure_ascii=False, indent=2), encoding="utf-8")

    fields = ["l2_code", "l3_code", "pop", "mpn", "scope_level", "std_attr_code",
              "std_attr_cn", "status", "rule_keys", "note"]
    with OUT_TSV.open("w", newline="", encoding="utf-8-sig") as f:
        w = csv.DictWriter(f, fieldnames=fields)
        w.writeheader()
        w.writerows(all_rows)

    total_hit = sum(1 for r in all_rows if r["status"] == "HIT")
    total = len(all_rows)
    print(f"分析 L3 数: {len(samples)}  属性行: {total}  HIT率: {100*total_hit/total:.1f}%")
    for s in samples:
        print(f"  {s['l3_code']:25} pop={s['pop']:6}  {s['mpn']}")
    print(f"\n报告: {OUT_MD}")
    print(f"TSV:  {OUT_TSV}")
    print(f"JSON: {OUT_JSON}")


if __name__ == "__main__":
    main()
