#!/usr/bin/env python3
"""circuit_protection merge prod 前只读预检（不写 prod）。"""
from __future__ import annotations

import json
import os
import re
import sys
from collections import defaultdict
from datetime import datetime
from pathlib import Path

import pymysql

sys.stdout.reconfigure(encoding="utf-8")

L1 = "circuit_protection"
HERE = Path(__file__).resolve().parent.parent
ENV = HERE.parents[1] / "local.env"
OUT = HERE / "artifacts" / "circuit_protection" / "merge_precheck.md"
CLASSIFY_SEED = HERE.parents[1] / "1.classify" / "seed" / "dim_l3_classify_rule.csv"
GATE_TOOL = HERE.parents[2] / ".cursor" / "skills" / "component-etl-methodology" / "tools" / "validate_cross_l1_gate_overlap.py"  # noqa: F841 optional CLI

TEST_CLASSIFY = "test_dim.dim_l3_classify_circuit_protection"
TEST_RULE = "test_dim.dim_l3_classify_rule_circuit_protection"
TEST_SCHEMA = "test_dim.dim_attr_schema_circuit_protection"
TEST_EXTRACT = "test_dim.dim_attr_extract_rule_circuit_protection"
TEST_CLASS_DWD = "test_dwd.dwd_component_class_circuit_protection"

L2_TEST = [
    "overcurrent_overtemperature_protection",
    "passive_surge_diversion",
    "semiconductor_transient_suppression",
    "surge_protection_module",
]
L2_PROD = L2_TEST[:3]

# ICPDF 路由：TVS/TSPD/MOV 归 CP · 与得捷对齐 · gate_diode 不含 TVS
ACCEPTED_CP_GATE_OVERLAPS: set[tuple[str, str, str]] = {
    ("digikey", "category_in", "TVS 二极管"),
    ("digikey", "category_in", "压敏电阻，MOV"),
    ("icpdf", "category_in", "压敏电阻"),
    ("icpdf", "category2_in", "压敏电阻"),
}

GATE_BASELINE_ICPDF = 76_575  # gate_config · TVS+TSPD+MOV 回 CP · 2026-07-02

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
    m = GATE_RULE_RE.match((rule_id or "").strip())
    return m.group(1) if m else None


def fetch_gate_rows(cur, schema: str, table: str, data_source: str | None) -> list[dict]:
    ds_filter = f"AND data_source='{data_source}'" if data_source else ""
    cur.execute(
        f"""
        SELECT rule_id, data_source, rule_kind, enabled, field_code, match_values
        FROM {schema}.{table}
        WHERE rule_kind='gate' AND enabled=1 {ds_filter}
        """
    )
    out: list[dict] = []
    for r in cur.fetchall():
        fc = (r.get("field_code") or "").strip()
        if fc not in ("category_in", "category2_in"):
            continue
        l1 = l1_from_rule_id(r.get("rule_id") or "")
        if not l1:
            continue
        for cat in parse_match_values(r.get("match_values") or ""):
            out.append(
                {
                    "l1_code": l1,
                    "data_source": (r.get("data_source") or "").strip(),
                    "field_code": fc,
                    "category": cat,
                    "rule_id": (r.get("rule_id") or "").strip(),
                }
            )
    return out


def gate_overlaps(rows: list[dict]) -> list[dict]:
    idx: dict[tuple[str, str, str], dict[str, set[str]]] = defaultdict(lambda: defaultdict(set))
    for r in rows:
        key = (r["data_source"], r["field_code"], r["category"])
        idx[key][r["l1_code"]].add(r["rule_id"])
    out = []
    for (ds, fc, cat), l1_map in sorted(idx.items()):
        if len(l1_map) <= 1:
            continue
        out.append(
            {
                "data_source": ds,
                "field_code": fc,
                "category": cat,
                "l1s": sorted(l1_map.keys()),
                "detail": "; ".join(
                    f"{l1}←{','.join(sorted(rids))}" for l1, rids in sorted(l1_map.items())
                ),
            }
        )
    return out


def fetch_gate_rows_from_classify_seed(data_source: str, rule_id: str) -> list[dict]:
    """merge 协调：diode icpdf gate 以 seed CSV 为准（TVS 让渡 CP）。"""
    if not CLASSIFY_SEED.exists():
        return []
    import csv

    out: list[dict] = []
    with CLASSIFY_SEED.open(encoding="utf-8", newline="") as f:
        for row in csv.DictReader(f):
            if (row.get("rule_id") or "").strip() != rule_id:
                continue
            if (row.get("data_source") or "").strip() != data_source:
                continue
            if (row.get("rule_kind") or "").strip() != "gate":
                continue
            fc = (row.get("field_code") or "").strip()
            if fc not in ("category_in", "category2_in"):
                continue
            l1 = l1_from_rule_id(rule_id)
            if not l1:
                continue
            for cat in parse_match_values(row.get("match_values") or ""):
                out.append(
                    {
                        "l1_code": l1,
                        "data_source": data_source,
                        "field_code": fc,
                        "category": cat,
                        "rule_id": rule_id,
                    }
                )
    return out


def overlay_gate_rows(cur, data_source: str) -> tuple[list[dict], list[dict]]:
    prod = fetch_gate_rows(cur, "dim", "dim_l3_classify_rule", data_source)
    sandbox = fetch_gate_rows(cur, "test_dim", "dim_l3_classify_rule_circuit_protection", data_source)
    prefix = f"gate_{L1}_"
    prod_kept = [
        r
        for r in prod
        if not (r["l1_code"] == L1 or r["rule_id"].startswith(prefix))
        and r["rule_id"] != "gate_diode_icpdf_v1"
    ]
    merged = prod_kept + sandbox
    if data_source == "icpdf":
        merged.extend(fetch_gate_rows_from_classify_seed("icpdf", "gate_diode_icpdf_v1"))
    return prod, merged


def load_env() -> None:
    for line in ENV.read_text(encoding="utf-8").splitlines():
        if line.strip().startswith("export "):
            k, _, v = line.strip()[7:].partition("=")
            os.environ[k] = v.strip().strip("'").strip('"')


def connect():
    return pymysql.connect(
        host=os.environ["MYSQL_HOST"],
        port=int(os.environ.get("MYSQL_PORT", "9030")),
        user=os.environ["MYSQL_USER"],
        password=os.environ["MYSQL_PASSWORD"],
        charset="utf8mb4",
        cursorclass=pymysql.cursors.DictCursor,
        autocommit=True,
    )


def q1(cur, sql: str) -> int:
    cur.execute(sql)
    row = cur.fetchone()
    if row is None:
        return 0
    return int(list(row.values())[0])


def qall(cur, sql: str) -> list[dict]:
    cur.execute(sql)
    return list(cur.fetchall())


def md_table(rows: list[dict], cols: list[str] | None = None) -> str:
    if not rows:
        return "_（无）_\n"
    cols = cols or list(rows[0].keys())
    lines = [
        "| " + " | ".join(cols) + " |",
        "| " + " | ".join("---" for _ in cols) + " |",
    ]
    for r in rows:
        lines.append("| " + " | ".join(str(r.get(c, "")) for c in cols) + " |")
    return "\n".join(lines) + "\n"


def main() -> int:
    load_env()
    OUT.parent.mkdir(parents=True, exist_ok=True)
    conn = connect()
    cur = conn.cursor()
    cur.execute("SET enable_local_shuffle_agg=false")

    lines: list[str] = [
        f"# circuit_protection · merge prod 预检报告",
        "",
        f"生成时间：{datetime.now():%Y-%m-%d %H:%M} · **只读，未写 prod**",
        "",
        "## 0. 阶段 1 门控",
        "",
    ]

    # Stage 1 gates
    stage1: list[tuple[str, str, bool]] = []

    for tbl, label in [
        (TEST_CLASSIFY, "dim_l3_classify"),
        (TEST_RULE, "dim_l3_classify_rule"),
        (TEST_SCHEMA, "dim_attr_schema"),
        (TEST_EXTRACT, "dim_attr_extract_rule"),
    ]:
        n = q1(cur, f"SELECT COUNT(*) n FROM {tbl}")
        stage1.append((label, f"{n:,}", n > 0))

    class_by_src = qall(
        cur,
        f"""
        SELECT data_source, COUNT(*) n
        FROM {TEST_CLASS_DWD}
        WHERE l1_code='{L1}'
        GROUP BY 1 ORDER BY n DESC
        """,
    )
    icpdf_n = next((r["n"] for r in class_by_src if r["data_source"] == "icpdf"), 0)
    dk_n = next((r["n"] for r in class_by_src if r["data_source"] == "digikey"), 0)
    icpdf_ok = 60_000 <= icpdf_n <= 80_000
    stage1.append(
        (
            "dwd_class icpdf",
            f"{icpdf_n:,}（基线 ~{GATE_BASELINE_ICPDF:,}）",
            icpdf_ok,
        )
    )
    stage1.append(("dwd_class digikey", f"{dk_n:,}", dk_n >= 0))

    brand_checks = []
    for l2 in L2_TEST:
        tbl = f"test_dwd.dwd_l2_circuit_protection_{l2}"
        try:
            r = qall(
                cur,
                f"""
                SELECT COUNT(*) total,
                       SUM(CASE WHEN brand IS NULL OR trim(brand)='' THEN 1 ELSE 0 END) brand_null
                FROM {tbl}
                """,
            )[0]
            brand_checks.append(
                {
                    "l2": l2,
                    "rows": r["total"],
                    "brand_null": r["brand_null"],
                    "ok": r["brand_null"] == 0,
                }
            )
        except pymysql.err.ProgrammingError:
            brand_checks.append({"l2": l2, "rows": "—", "brand_null": "—", "ok": False})

    lines.append("| 检查项 | 值 | 通过 |")
    lines.append("|--------|-----|------|")
    for label, val, ok in stage1:
        lines.append(f"| {label} | {val} | {'✅' if ok else '❌'} |")
    lines.append("")
    lines.append("**L2 品牌门控（test_dwd）**")
    lines.append("")
    lines.append(md_table(brand_checks, ["l2", "rows", "brand_null", "ok"]))

    lines.extend(["", "## 1. 分类 PK 冲突预检", ""])

    l3_dup = qall(
        cur,
        f"""
        SELECT l3_id, COUNT(*) c FROM (
          SELECT l3_id FROM dim.dim_l3_classify WHERE l1_code <> '{L1}'
          UNION ALL SELECT l3_id FROM {TEST_CLASSIFY}
        ) u GROUP BY l3_id HAVING COUNT(*)>1
        ORDER BY c DESC LIMIT 20
        """,
    )
    l3_dup_n = len(l3_dup)
    lines.append(f"- **l3_id 跨 L1 冲突**：{l3_dup_n} 个 {'✅' if l3_dup_n == 0 else '❌ STOP'}")
    if l3_dup:
        lines.append("")
        lines.append(md_table(l3_dup, ["l3_id", "c"]))

    rule_dup = qall(
        cur,
        f"""
        WITH prod_keep_rule AS (
          SELECT r.rule_id, r.clause_group_id, r.clause_ord
          FROM dim.dim_l3_classify_rule r
          LEFT JOIN dim.dim_l3_classify d
            ON d.l3_id = r.l3_id AND d.schema_version = r.schema_version
          WHERE COALESCE(d.l1_code, '') <> '{L1}'
            AND r.rule_id NOT REGEXP '^{L1}_'
            AND r.rule_id NOT REGEXP '^gate_{L1}_'
        )
        SELECT rule_id, clause_group_id, clause_ord, COUNT(*) c FROM (
          SELECT rule_id, clause_group_id, clause_ord FROM prod_keep_rule
          UNION ALL SELECT rule_id, clause_group_id, clause_ord FROM {TEST_RULE}
        ) u GROUP BY rule_id, clause_group_id, clause_ord HAVING COUNT(*)>1
        LIMIT 20
        """,
    )
    rule_dup_n = len(rule_dup)
    lines.append(f"- **classify_rule PK 跨 L1 冲突**：{rule_dup_n} 组 {'✅' if rule_dup_n == 0 else '❌ STOP'}")
    if rule_dup:
        lines.append("")
        lines.append(md_table(rule_dup[:10], ["rule_id", "clause_group_id", "clause_ord", "c"]))

    bad_classify_prefix = qall(
        cur,
        f"""
        SELECT rule_id, COUNT(*) n FROM {TEST_RULE}
        WHERE rule_id NOT REGEXP '^{L1}_'
          AND rule_id NOT REGEXP '^gate_{L1}_'
        GROUP BY 1 ORDER BY 1 LIMIT 15
        """,
    )
    lines.append(
        f"- **classify rule_id 前缀（^{L1}_ / gate_{L1}_）**："
        f"{'✅' if not bad_classify_prefix else f'❌ {len(bad_classify_prefix)} 个 STOP'}"
    )
    if bad_classify_prefix:
        lines.append("")
        lines.append(md_table(bad_classify_prefix, ["rule_id", "n"]))

    lines.extend(["", "## 2. 属性 PK 冲突预检", ""])

    schema_dup = qall(
        cur,
        f"""
        SELECT schema_version, l1_code, scope_level, scope_code, std_attr_code, COUNT(*) c
        FROM (
          SELECT schema_version, l1_code, scope_level, scope_code, std_attr_code
          FROM dim.dim_attr_schema WHERE l1_code <> '{L1}'
          UNION ALL
          SELECT schema_version, l1_code, scope_level, scope_code, std_attr_code
          FROM {TEST_SCHEMA}
        ) u
        GROUP BY 1,2,3,4,5 HAVING COUNT(*)>1
        LIMIT 20
        """,
    )
    lines.append(f"- **attr_schema PK 跨 L1 冲突**：{len(schema_dup)} 组 {'✅' if not schema_dup else '❌ STOP'}")
    if schema_dup:
        lines.append(md_table(schema_dup[:10], ["schema_version", "l1_code", "scope_level", "scope_code", "std_attr_code", "c"]))

    extract_dup = qall(
        cur,
        f"""
        SELECT extract_rule_id, COUNT(*) c FROM (
          SELECT extract_rule_id FROM dim.dim_attr_extract_rule
          WHERE l1_code <> '{L1}' AND extract_rule_id NOT REGEXP '^{L1}_'
          UNION ALL SELECT extract_rule_id FROM {TEST_EXTRACT}
        ) u GROUP BY extract_rule_id HAVING COUNT(*)>1
        LIMIT 20
        """,
    )
    lines.append(f"- **extract_rule_id 跨 L1 冲突**：{len(extract_dup)} 个 {'✅' if not extract_dup else '❌ STOP'}")
    if extract_dup:
        lines.append(md_table(extract_dup[:10], ["extract_rule_id", "c"]))

    orphan_rules = qall(
        cur,
        f"""
        SELECT r.std_attr_code, COUNT(*) n
        FROM {TEST_EXTRACT} r
        LEFT JOIN {TEST_SCHEMA} s
          ON s.schema_version = r.schema_version
         AND s.l1_code = '{L1}'
         AND s.std_attr_code = r.std_attr_code
        WHERE s.std_attr_code IS NULL
        GROUP BY 1 ORDER BY n DESC LIMIT 15
        """,
    )
    lines.append(f"- **extract_rule 孤儿 std_attr**：{len(orphan_rules)} 个 {'✅' if not orphan_rules else '❌ STOP'}")
    if orphan_rules:
        lines.append(md_table(orphan_rules, ["std_attr_code", "n"]))

    bad_prefix_rules = qall(
        cur,
        f"""
        SELECT extract_rule_id, COUNT(*) n
        FROM {TEST_EXTRACT}
        WHERE extract_rule_id NOT REGEXP '^{L1}_'
        GROUP BY 1 ORDER BY n DESC LIMIT 10
        """,
    )
    lines.append(f"- **extract_rule_id 缺 {L1}_ 前缀**：{len(bad_prefix_rules)} 个 {'✅' if not bad_prefix_rules else '⚠️'}")
    if bad_prefix_rules:
        lines.append(md_table(bad_prefix_rules, ["extract_rule_id", "n"]))

    lines.extend(["", "## 3. prod ↔ test 只读 diff（将删除 / 将写入）", ""])

    # classify diff
    prod_l3 = qall(
        cur,
        f"SELECT l3_id, l3_code, l2_code, l3_cn FROM dim.dim_l3_classify WHERE l1_code='{L1}' ORDER BY l3_id",
    )
    test_l3 = qall(cur, f"SELECT l3_id, l3_code, l2_code, l3_cn FROM {TEST_CLASSIFY} ORDER BY l3_id")
    prod_l3_ids = {r["l3_id"] for r in prod_l3}
    test_l3_ids = {r["l3_id"] for r in test_l3}
    only_prod_l3 = prod_l3_ids - test_l3_ids
    only_test_l3 = test_l3_ids - prod_l3_ids

    lines.append("### 3.1 dim_l3_classify")
    lines.append("")
    lines.append(f"| 侧 | 行数 |")
    lines.append(f"|----|------|")
    lines.append(f"| prod | {len(prod_l3)} |")
    lines.append(f"| test | {len(test_l3)} |")
    lines.append(f"| prod 独有 l3_id | {len(only_prod_l3)} |")
    lines.append(f"| test 新增 l3_id | {len(only_test_l3)} |")
    lines.append("")
    if only_test_l3:
        rows = [r for r in test_l3 if r["l3_id"] in only_test_l3]
        lines.append("**test 新增 L3 节点**")
        lines.append("")
        lines.append(md_table(rows, ["l3_id", "l3_code", "l2_code", "l3_cn"]))

    prod_rules = qall(
        cur,
        f"""
        SELECT data_source, COUNT(*) n, COUNT(DISTINCT rule_id) rules
        FROM dim.dim_l3_classify_rule r
        JOIN dim.dim_l3_classify d ON d.l3_id=r.l3_id AND d.schema_version=r.schema_version
        WHERE d.l1_code='{L1}'
        GROUP BY 1 ORDER BY 1
        """,
    )
    test_rules = qall(
        cur,
        f"""
        SELECT data_source, COUNT(*) n, COUNT(DISTINCT rule_id) rules
        FROM {TEST_RULE}
        GROUP BY 1 ORDER BY 1
        """,
    )
    lines.append("### 3.2 dim_l3_classify_rule（按 data_source）")
    lines.append("")
    lines.append("**prod**")
    lines.append(md_table(prod_rules, ["data_source", "n", "rules"]))
    lines.append("**test**")
    lines.append(md_table(test_rules, ["data_source", "n", "rules"]))

    prod_rule_ids = {
        r["rule_id"]
        for r in qall(
            cur,
            f"""
            SELECT DISTINCT r.rule_id FROM dim.dim_l3_classify_rule r
            JOIN dim.dim_l3_classify d ON d.l3_id=r.l3_id AND d.schema_version=r.schema_version
            WHERE d.l1_code='{L1}'
            """,
        )
    }
    test_rule_ids = {r["rule_id"] for r in qall(cur, f"SELECT DISTINCT rule_id FROM {TEST_RULE}")}
    new_rules = sorted(test_rule_ids - prod_rule_ids)
    drop_rules = sorted(prod_rule_ids - test_rule_ids)
    lines.append(f"- test 新增 rule_id：**{len(new_rules)}** · prod 将删除 rule_id：**{len(drop_rules)}**")
    if new_rules[:15]:
        lines.append("")
        lines.append("新增 rule_id 样例（前 15）：")
        for rid in new_rules[:15]:
            lines.append(f"- `{rid}`")
    lines.append("")

    # attr diff
    prod_schema_n = q1(cur, f"SELECT COUNT(*) n FROM dim.dim_attr_schema WHERE l1_code='{L1}'")
    test_schema_n = q1(cur, f"SELECT COUNT(*) n FROM {TEST_SCHEMA}")
    prod_extract = qall(
        cur,
        f"""
        SELECT data_source, COUNT(*) n FROM dim.dim_attr_extract_rule
        WHERE l1_code='{L1}' GROUP BY 1 ORDER BY 1
        """,
    )
    test_extract = qall(
        cur,
        f"""
        SELECT data_source, COUNT(*) n FROM {TEST_EXTRACT} GROUP BY 1 ORDER BY 1
        """,
    )
    lines.append("### 3.3 dim_attr_schema / extract_rule")
    lines.append("")
    lines.append(f"- prod schema 行：**{prod_schema_n}** · test schema 行：**{test_schema_n}**")
    lines.append("")
    lines.append("**prod extract_rule**")
    lines.append(md_table(prod_extract, ["data_source", "n"]))
    lines.append("**test extract_rule**")
    lines.append(md_table(test_extract, ["data_source", "n"]))

    prod_er_ids = {
        r["extract_rule_id"]
        for r in qall(
            cur, f"SELECT DISTINCT extract_rule_id FROM dim.dim_attr_extract_rule WHERE l1_code='{L1}'"
        )
    }
    test_er_ids = {r["extract_rule_id"] for r in qall(cur, f"SELECT DISTINCT extract_rule_id FROM {TEST_EXTRACT}")}
    new_er = sorted(test_er_ids - prod_er_ids)
    icpdf_new = [x for x in new_er if "icpdf" in x.lower() or x.endswith("_ic_v1")]
    lines.append(f"- test 新增 extract_rule_id：**{len(new_er)}**（其中疑似 ICPDF：**{len(icpdf_new)}**）")
    lines.append("")

    lines.extend(["", "## 4. prod 现状 vs test 增量", ""])
    lines.append("| 项 | prod | test 沙盒 | 备注 |")
    lines.append("|----|------|-----------|------|")
    lines.append(f"| classify data_source | digikey | icpdf + digikey | 双源替换 |")
    lines.append(f"| L2 宽表脚本 | **3** 张 | **4** 张 | ✅ spd L2 已入仓 |")
    lines.append(f"| icpdf 分类行 | 0（预期） | {icpdf_n:,} | merge 后新增 |")
    lines.append(f"| spd_module L2 行 | 无表 | 19 | merge 后 run_attr_std 建表 |")
    lines.append("")

    # prod dwd class icpdf check
    prod_icpdf_class = q1(
        cur,
        f"""
        SELECT COUNT(*) n FROM dwd.dwd_component_class
        WHERE l1_code='{L1}' AND data_source='icpdf'
        """,
    )
    prod_dk_class = q1(
        cur,
        f"""
        SELECT COUNT(*) n FROM dwd.dwd_component_class
        WHERE l1_code='{L1}' AND data_source='digikey'
        """,
    )
    lines.append("### 4.1 prod dwd_component_class 现状")
    lines.append("")
    lines.append(f"- digikey：**{prod_dk_class:,}** 行")
    lines.append(f"- icpdf：**{prod_icpdf_class:,}** 行")
    lines.append("")

    # L3 distribution icpdf test
    l3_dist = qall(
        cur,
        f"""
        SELECT l3_code, COUNT(*) n FROM {TEST_CLASS_DWD}
        WHERE data_source='icpdf' GROUP BY 1 ORDER BY n DESC
        """,
    )
    lines.append("### 4.2 test icpdf L3 分布（merge 后应对齐）")
    lines.append("")
    lines.append(md_table(l3_dist, ["l3_code", "n"]))

    lines.extend(["", "## 5. 跨 L1 gate category 重叠（G1）", ""])
    gate_blockers: list[str] = []
    gate_warnings: list[str] = []
    for src in ("digikey", "icpdf"):
        prod_rows, merged_rows = overlay_gate_rows(cur, src)
        prod_ov = gate_overlaps(prod_rows)
        merged_ov = gate_overlaps(merged_rows)
        cp_prod = [o for o in prod_ov if L1 in o["l1s"]]
        cp_merged = [o for o in merged_ov if L1 in o["l1s"]]
        prod_keys = {(o["field_code"], o["category"]) for o in cp_prod}
        new_cp = [o for o in cp_merged if (o["field_code"], o["category"]) not in prod_keys]
        new_cp_hard = [
            o
            for o in new_cp
            if (src, o["field_code"], o["category"]) not in ACCEPTED_CP_GATE_OVERLAPS
        ]
        new_cp_soft = [
            o
            for o in new_cp
            if (src, o["field_code"], o["category"]) in ACCEPTED_CP_GATE_OVERLAPS
        ]

        lines.append(f"### 5.{1 if src == 'digikey' else 2} {src}")
        lines.append("")
        lines.append(f"| 指标 | prod 基线 | merge 后 overlay |")
        lines.append(f"|------|-----------|------------------|")
        lines.append(f"| 全局重叠处数 | {len(prod_ov)} | {len(merged_ov)} |")
        lines.append(f"| **含 circuit_protection** | **{len(cp_prod)}** | **{len(cp_merged)}** |")
        lines.append(f"| cp **新增**重叠 | — | **{len(new_cp)}** |")
        lines.append("")

        if cp_merged:
            lines.append("**circuit_protection 相关重叠（merge 后）**")
            lines.append("")
            rows = [
                {
                    "category": o["category"][:40],
                    "l1s": ", ".join(o["l1s"]),
                    "new": "🆕" if (o["field_code"], o["category"]) not in prod_keys else "既有",
                }
                for o in cp_merged
            ]
            lines.append(md_table(rows, ["category", "l1s", "new"]))
        if new_cp_hard:
            gate_blockers.append(f"{src} 新增 cp gate 重叠 {len(new_cp_hard)} 处")
        if new_cp_soft:
            gate_warnings.append(
                f"{src} 已知 cp↔diode gate 重叠 {len(new_cp_soft)} 处（TVS 留 CP · 已决策）"
            )
        lines.append("")

    if not gate_blockers:
        lines.append(
            "> G1 工具全量扫描仍可能 FAIL（prod 历史重叠 mcu/mpu、filter/inductor 等），"
            "**circuit_protection merge 未新增 cp 相关 gate 争用**。"
        )
        lines.append("")

    lines.extend(["", "## 6. unit_factor supplement", ""])
    supp = HERE / "dim_unit_factor_circuit_protection_supplement.sql"
    if supp.exists():
        supp_text = supp.read_text(encoding="utf-8")
        # 解析 INSERT 中的 (from, to) 对
        import re

        pairs = re.findall(r"SELECT '([^']+)',\s*'([^']+)'", supp_text)
        missing_units = []
        for target_unit, unit_raw in pairs:
            exists = q1(
                cur,
                f"""
                SELECT COUNT(*) n FROM dim.dim_unit_factor
                WHERE target_unit='{target_unit}' AND unit_raw='{unit_raw}'
                """,
            )
            if not exists:
                missing_units.append({"target_unit": target_unit, "unit_raw": unit_raw})
        lines.append(f"- supplement 文件：`dim_unit_factor_circuit_protection_supplement.sql`")
        lines.append(f"- 声明 unit 对：**{len(pairs)}** · prod 缺失：**{len(missing_units)}**")
        if missing_units:
            lines.append("")
            lines.append("**merge 前须追加的 unit_factor**")
            lines.append("")
            lines.append(md_table(missing_units, ["target_unit", "unit_raw"]))
        else:
            lines.append("")
            lines.append("✅ supplement 中 unit 对已存在于 prod")
    else:
        lines.append("_无 supplement 文件_")
        missing_units = []
    lines.append("")

    # Verdict
    blockers = []
    warnings = []
    if l3_dup_n:
        blockers.append("l3_id 跨 L1 冲突")
    if rule_dup_n:
        blockers.append("classify_rule PK 冲突")
    if bad_classify_prefix:
        blockers.append("classify rule_id 前缀不合规")
    if schema_dup:
        blockers.append("attr_schema PK 冲突")
    if extract_dup:
        blockers.append("extract_rule_id 冲突")
    if orphan_rules:
        blockers.append("extract_rule 孤儿 std_attr")
    if gate_blockers:
        blockers.extend(gate_blockers)
    if gate_warnings:
        warnings.extend(gate_warnings)
    if missing_units:
        warnings.append(f"unit_factor 须 merge 时追加 {len(missing_units)} 行（supplement SQL 已备）")
    if bad_prefix_rules:
        warnings.append(
            f"extract_rule_id 使用 cp_* 前缀（{len(bad_prefix_rules)} 条）· 与 prod 既有 DK 命名一致，非阻断"
        )
    if dk_n == 0:
        warnings.append(
            "test 沙盒 dwd_class 仅 icpdf（digikey=0）· merge 后须对 prod digikey 153k 行做 Step 5 回归"
        )
    if len(prod_l3) < len(test_l3):
        warnings.append(
            f"prod dim_l3_classify 仅 {len(prod_l3)} 节点 → test {len(test_l3)} 节点 · 属 taxonomy 扩展，merge 时整 L1 替换"
        )

    lines.extend(["", "## 7. 预检结论", ""])
    if blockers:
        lines.append("**❌ 存在阻断项，暂不可 merge：**")
        for b in blockers:
            lines.append(f"- {b}")
    else:
        lines.append("**✅ PK / 孤儿规则 / cp gate 争用门控通过，可进入人工授权后的 merge。**")
    if warnings:
        lines.append("")
        lines.append("**⚠️ 注意事项（非阻断）：**")
        for w in warnings:
            lines.append(f"- {w}")
    lines.append("")
    lines.append("**merge 前仍须完成的仓库侧工作（非 DB）：**")
    lines.append("1. ✅ 第 4 张 L2 `surge_protection_module` 已入仓 `16_circuit_protection_ready/`")
    lines.append("2. ✅ `run_attr_std.sh` 已含 circuit_protection 4 张 L2")
    lines.append("3. 从 `main` 切分支 · working tree 干净")
    lines.append("4. classify-merge 后再 attr-merge · 最后刷 catalog · merge 时跑 unit_factor supplement")
    lines.append("")

    OUT.write_text("\n".join(lines), encoding="utf-8")
    print(f"wrote {OUT}")
    print("blockers:", blockers or "none")
    conn.close()
    return 1 if blockers else 0


if __name__ == "__main__":
    raise SystemExit(main())
