#!/usr/bin/env python3
"""圆形连接器 L3 ext_attributes 源-schema gap 探针（§8.3）。

对 circular_connector 分类人群扫描得捷 prajson 键频率，对比
test_dim.dim_attr_extract_rule_connector 中 L3 专属规则，输出 gap TSV。

用法:
  cd sql_scripts/test/connector && source ../../local.env
  python3 ../../../artifacts/connector/gen_probe_circular_connector_ext_gap.py
"""
from __future__ import annotations

import csv
import json
import os
import sys
from collections import Counter, defaultdict
from datetime import date
from pathlib import Path

import pymysql

sys.stdout.reconfigure(encoding="utf-8")

REPO = Path(__file__).resolve().parents[2]
LOCAL_ENV = REPO / "sql_scripts" / "local.env"
OUT = REPO / "artifacts" / "connector" / f"probe_circular_connector_ext_gap_{date.today():%Y%m%d}.tsv"

L3 = "circular_connector"
L3_ATTRS = [
    ("shell_diameter_mm", "壳体外径", "DOUBLE"),
    ("locking_type", "锁紧方式", "VARCHAR"),
    ("keying_code", "键位编码", "VARCHAR"),
    ("contact_arrangement_code", "接触件排列代号", "VARCHAR"),
    ("ip_rating", "防护等级", "VARCHAR"),
]

RULE_KEYS = {
    "shell_diameter_mm": ["外壳直径", "直径", "直径 - 外部"],
    "locking_type": ["锁定", "锁定类型", "紧固类型"],
    "keying_code": ["键位", "极化"],
    "contact_arrangement_code": ["触头排列", "排列", "触头尺寸"],
    "ip_rating": ["侵入防护"],
}

ADMIN = {
    "DigiKey 零件编号", "ECCN", "HTSUS", "category", "category_path",
    "制造商", "制造商产品编号", "制造商标准包装", "描述", "类别", "系列",
    "详细描述", "零件状态", "Part Number Alias", "包装", "安装类型",
    "湿气敏感性等级 (MSL)", "REACH 状态", "环保信息", "特色产品",
    "RoHS 状态", "PCN 产品变更/停产", "报价表", "计价货币", "库存数量",
    "DigiKey Part Number", "原厂标准交货期",
}


def load_env() -> None:
    if not LOCAL_ENV.exists():
        return
    for line in LOCAL_ENV.read_text().splitlines():
        if line.startswith("export "):
            k, _, v = line[7:].partition("=")
            os.environ[k] = v.strip().strip("'\"")


def classify_gap(attr: str, dk_key: str | None, key_cnt: int, sample_n: int, has_rule: bool) -> tuple[str, str, str]:
    """返回 (priority, gap_type, probe_note, rule_action) 简化版前三个+action"""
    if attr == "ip_rating" and key_cnt > 0:
        return "—", "已覆盖", f"侵入防护 {key_cnt}/{sample_n}", "保留"
    if dk_key and key_cnt == 0 and has_rule:
        return "P0", "规则键不存在", f"规则绑 {dk_key!r} 但 100k 样本 0 命中", "改 source_expr 或删规则"
    if dk_key and key_cnt > 0 and not has_rule:
        return "P0", "规则缺失", f"{dk_key!r} {key_cnt}/{sample_n}", f"新增 l3={L3} 绑定"
    if dk_key and key_cnt > 0 and has_rule:
        return "P1", "规则已有", f"{dk_key!r} {key_cnt}/{sample_n}", "保留/验 regex"
    if not dk_key and key_cnt == 0:
        if attr == "keying_code":
            return "P2", "源端真无", "全量 prajson 无键位/极化/Key 类键", "登记豁免或 MPN 正则（后续）"
        if attr == "contact_arrangement_code":
            return "P1", "源端无标准键", "无触头排列/排列；触头尺寸可作弱代理", "已提案触头尺寸规则"
        return "P2", "源端真无", "无对应 prajson 键", "登记豁免或删 schema 字段"
    return "P2", "待人工", "", "复核"


def main() -> None:
    load_env()
    conn = pymysql.connect(
        host=os.environ["MYSQL_HOST"],
        port=int(os.environ.get("MYSQL_PORT", "9030")),
        user=os.environ["MYSQL_USER"],
        password=os.environ["MYSQL_PASSWORD"],
        charset="utf8mb4",
    )
    cur = conn.cursor()

    cur.execute(
        """
        SELECT COUNT(*) FROM test_dwd.dwd_component_class_connector
        WHERE l3_code=%s AND data_source='digikey'
        """,
        (L3,),
    )
    total = cur.fetchone()[0]

    cur.execute(
        """
        SELECT p.prajson FROM dwd.dwd_digikey_component_param p
        JOIN test_dwd.dwd_component_class_connector c ON c.id=p.id AND c.data_source='digikey'
        WHERE c.l3_code=%s LIMIT 100000
        """,
        (L3,),
    )
    all_keys: Counter[str] = Counter()
    target_counts: Counter[str] = Counter()
    samples: dict[str, list[str]] = defaultdict(list)
    sample_n = 0
    for (pj,) in cur.fetchall():
        sample_n += 1
        if not pj:
            continue
        try:
            d = json.loads(pj)
        except json.JSONDecodeError:
            continue
        for k in d:
            all_keys[k] += 1
        for keys in RULE_KEYS.values():
            for k in keys:
                v = d.get(k)
                if v and str(v).strip() not in ("", "-", "--", "N/A", "n/a"):
                    target_counts[k] += 1
                    if len(samples[k]) < 3:
                        samples[k].append(str(v)[:100])
        for extra in ("外壳尺寸 - 插件", "外壳尺寸，MIL"):
            v = d.get(extra)
            if v and str(v).strip() not in ("", "-", "--", "N/A", "n/a"):
                target_counts[extra] += 1
                if len(samples[extra]) < 3:
                    samples[extra].append(str(v)[:100])

    cur.execute(
        """
        SELECT std_attr_code, source_expr, apply_scope_level, apply_scope_code
        FROM test_dim.dim_attr_extract_rule_connector
        WHERE data_source='digikey' AND enabled=1
          AND std_attr_code IN %s
        """,
        (tuple(a[0] for a in L3_ATTRS),),
    )
    db_rules: dict[str, list[tuple]] = defaultdict(list)
    for std, expr, lvl, code in cur.fetchall():
        db_rules[std].append((expr, lvl, code))

    fill: dict[str, int] = {}
    for code, _, _ in L3_ATTRS:
        cur.execute(
            """
            SELECT COUNT(DISTINCT e.id) FROM test_dwd.dwd_component_attr_std_connector e
            JOIN test_dwd.dwd_component_class_connector c ON c.id=e.id AND c.data_source=e.data_source
            WHERE c.l3_code=%s AND e.std_attr_code=%s AND e.data_source='digikey'
              AND (
                (e.value_std_varchar IS NOT NULL AND TRIM(e.value_std_varchar) <> '')
                OR e.value_std_double IS NOT NULL
              )
            """,
            (L3, code),
        )
        fill[code] = cur.fetchone()[0]

    rows: list[dict] = []
    for std, cn, _ in L3_ATTRS:
        rules = db_rules.get(std, [])
        rule_exprs = {r[0] for r in rules}
        l3_rules = [r for r in rules if r[1] == "l3" and r[2] == L3]
        global_rules = [r for r in rules if r[1] is None]

        pct = 100.0 * fill.get(std, 0) / total if total else 0
        header_note = f"EAV填充 {fill.get(std, 0):,}/{total:,} ({pct:.2f}%)"
        rows.append({
            "priority": "—",
            "std_attr_code": std,
            "attr_cn": cn,
            "gap_type": "基线",
            "dk_key_present": "—",
            "n_sample_100k": str(total),
            "probe_note": header_note,
            "rule_action": f"规则数 l3={len(l3_rules)} global={len(global_rules)}",
        })

        emitted_keys: set[str] = set()
        for dk_key in RULE_KEYS.get(std, []):
            cnt = target_counts.get(dk_key, 0)
            has_rule = dk_key in rule_exprs
            pri, gap, note, action = classify_gap(std, dk_key, cnt, sample_n, has_rule)
            if dk_key in emitted_keys:
                continue
            emitted_keys.add(dk_key)
            ex = "; ".join(samples.get(dk_key, [])[:2])
            rows.append({
                "priority": pri,
                "std_attr_code": std,
                "attr_cn": cn,
                "gap_type": gap,
                "dk_key_present": dk_key,
                "n_sample_100k": str(cnt),
                "probe_note": f"{note}" + (f" | ex: {ex}" if ex else ""),
                "rule_action": action,
            })

        # 外壳尺寸 - 插件：高频但非 mm 语义
        plug_cnt = target_counts.get("外壳尺寸 - 插件", 0)
        if std == "shell_diameter_mm" and plug_cnt:
            ex = "; ".join(samples.get("外壳尺寸 - 插件", [])[:2])
            rows.append({
                "priority": "P1",
                "std_attr_code": std,
                "attr_cn": cn,
                "gap_type": "语义不匹配",
                "dk_key_present": "外壳尺寸 - 插件",
                "n_sample_100k": str(all_keys.get("外壳尺寸 - 插件", 0)),
                "probe_note": f"MIL 插入尺寸代号非 mm；勿绑 DOUBLE shell_diameter_mm | ex: {ex}",
                "rule_action": "保留 VARCHAR 新字段提案或仅作参考",
            })

    OUT.parent.mkdir(parents=True, exist_ok=True)
    cols = [
        "priority", "std_attr_code", "attr_cn", "gap_type",
        "dk_key_present", "n_sample_100k", "probe_note", "rule_action",
    ]
    with OUT.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=cols, delimiter="\t", lineterminator="\n")
        w.writeheader()
        w.writerows(rows)

    print(f"circular_connector N={total:,} sample={sample_n:,}")
    print(f"Wrote {OUT}")
    conn.close()


if __name__ == "__main__":
    main()
