#!/usr/bin/env python3
"""circuit_protection · dim-attr-std-merge 只读预检（不写 prod）。"""
from __future__ import annotations

import os
import re
import sys
from datetime import datetime
from pathlib import Path

import pymysql

sys.stdout.reconfigure(encoding="utf-8")

L1 = "circuit_protection"
SCHEMA_VERSION = "v1.16.01"
RULE_PREFIXES = ("cp_", "circuit_protection_")

HERE = Path(__file__).resolve().parent.parent
ENV = HERE.parents[1] / "local.env"
OUT = HERE / "artifacts" / "circuit_protection" / "attr_merge_precheck.md"
READY = HERE.parents[1] / "2.attribute_standard" / "16_circuit_protection_ready"
RUN_ATTR = HERE.parents[1] / "2.attribute_standard" / "run_attr_std.sh"
SUPP = HERE / "dim_unit_factor_circuit_protection_supplement.sql"

L2S = [
    "overcurrent_overtemperature_protection",
    "passive_surge_diversion",
    "semiconductor_transient_suppression",
    "surge_protection_module",
]

TEST_SCHEMA = f"test_dim.dim_attr_schema_{L1}"
TEST_RULE = f"test_dim.dim_attr_extract_rule_{L1}"
TEST_EAV = f"test_dwd.dwd_component_attr_std_{L1}"


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


def q1(cur, sql: str):
    cur.execute(sql)
    row = cur.fetchone()
    return row or {}


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


def rule_prefix_ok(rule_id: str) -> bool:
    rid = (rule_id or "").strip()
    return any(rid.startswith(p) for p in RULE_PREFIXES)


def check_repo_scripts() -> tuple[list[str], list[str]]:
    blockers: list[str] = []
    warnings: list[str] = []
    if not READY.is_dir():
        blockers.append(f"缺少入仓目录 {READY}")
        return blockers, warnings
    for l2 in L2S:
        for kind in ("dwd_l2", "build_dwd_l2"):
            f = READY / f"{kind}_{L1}_{l2}.sql"
            if not f.exists():
                blockers.append(f"缺少 {f.name}")
    # run_attr_std.sh 映射
    txt = RUN_ATTR.read_text(encoding="utf-8")
    if "16_circuit_protection_ready" not in txt:
        blockers.append("run_attr_std.sh 未映射 16_circuit_protection_ready")
    for l2 in L2S:
        token = f"circuit_protection_{l2}"
        if token not in txt:
            blockers.append(f"run_attr_std.sh l2_files_for_l1 缺 {token}")
    # 静态反模式扫描
    bad_mfr: list[str] = []
    bad_brand128: list[str] = []
    for l2 in L2S:
        build = READY / f"build_dwd_l2_{L1}_{l2}.sql"
        if not build.exists():
            continue
        s = build.read_text(encoding="utf-8")
        if re.search(
            r"(?:COALESCE|NULLIF)\([^;]{0,400}canonical[^;]{0,200}\)\s*AS\s+manufacturer\b",
            s,
            re.I | re.S,
        ):
            bad_mfr.append(build.name)
        ddl = READY / f"dwd_l2_{L1}_{l2}.sql"
        if ddl.exists():
            d = ddl.read_text(encoding="utf-8")
            if re.search(r"`brand`\s+VARCHAR\s*\(\s*128\s*\)", d, re.I):
                bad_brand128.append(ddl.name)
    if bad_mfr:
        blockers.append(f"build SQL manufacturer COALESCE 反模式: {', '.join(bad_mfr)}")
    if bad_brand128:
        blockers.append(f"DDL brand VARCHAR(128): {', '.join(bad_brand128)}")
    # 16_circuit_protection/ 占位目录不应并存
    legacy = READY.parent / "16_circuit_protection"
    if legacy.is_dir():
        warnings.append("仍存在 16_circuit_protection/ 占位目录（应仅保留 _ready）")
    return blockers, warnings


def main() -> int:
    load_env()
    OUT.parent.mkdir(parents=True, exist_ok=True)
    conn = connect()
    cur = conn.cursor()
    cur.execute("SET enable_local_shuffle_agg=false")

    blockers: list[str] = []
    warnings: list[str] = []
    lines: list[str] = [
        f"# circuit_protection · dim-attr-std-merge 预检报告",
        "",
        f"生成时间：{datetime.now():%Y-%m-%d %H:%M} · **只读，未写 prod**",
        f"Skill：`.cursor/skills/dim-attr-std-merge/SKILL.md`",
        "",
    ]

    # ── Step 0 阶段 1 ──
    lines.extend(["## 0. 阶段 1 门控（test 后缀表）", ""])
    stage0_rows: list[dict] = []
    for label, tbl in [
        ("dim_attr_schema", TEST_SCHEMA),
        ("dim_attr_extract_rule", TEST_RULE),
        ("dwd_component_attr_std", TEST_EAV),
    ]:
        try:
            n = q1(cur, f"SELECT COUNT(*) n FROM {tbl}")["n"]
            ok = n > 0
            stage0_rows.append({"表": tbl.split(".")[-1], "行数": f"{n:,}", "通过": "✅" if ok else "❌"})
            if not ok:
                blockers.append(f"{tbl} 为空")
        except pymysql.err.ProgrammingError as e:
            stage0_rows.append({"表": tbl.split(".")[-1], "行数": "—", "通过": "❌"})
            blockers.append(f"{tbl} 不存在: {e}")
    lines.append(md_table(stage0_rows, ["表", "行数", "通过"]))

    # data_source 范围
    rule_ds = qall(
        cur,
        f"SELECT data_source, COUNT(*) n FROM {TEST_RULE} GROUP BY 1 ORDER BY n DESC",
    )
    eav_ds = qall(
        cur,
        f"SELECT data_source, COUNT(*) n FROM {TEST_EAV} GROUP BY 1 ORDER BY n DESC",
    )
    lines.append("**extract_rule data_source**")
    lines.append("")
    lines.append(md_table(rule_ds, ["data_source", "n"]))
    lines.append("**EAV data_source**")
    lines.append("")
    lines.append(md_table(eav_ds, ["data_source", "n"]))

    # L2 品牌门控
    l2_rows: list[dict] = []
    test_l2_total = 0
    for l2 in L2S:
        tbl = f"test_dwd.dwd_l2_{L1}_{l2}"
        try:
            r = q1(
                cur,
                f"""
                SELECT COUNT(*) total,
                       SUM(CASE WHEN brand IS NULL OR trim(brand)='' THEN 1 ELSE 0 END) brand_null,
                       SUM(CASE WHEN brandid IS NULL THEN 1 ELSE 0 END) brandid_null,
                       COUNT(DISTINCT brand) db,
                       COUNT(DISTINCT brandid) di
                FROM {tbl}
                """,
            )
            total = int(r["total"] or 0)
            test_l2_total += total
            ok = r["brand_null"] == 0 and r["brandid_null"] == 0 and r["db"] == r["di"]
            l2_rows.append(
                {
                    "l2": l2,
                    "rows": total,
                    "brand_null": r["brand_null"],
                    "brandid_null": r["brandid_null"],
                    "db=di": f"{r['db']}={r['di']}",
                    "ok": ok,
                }
            )
            if not ok:
                blockers.append(f"{tbl} 品牌门控未通过")
        except (pymysql.err.ProgrammingError, pymysql.err.OperationalError):
            l2_rows.append({"l2": l2, "rows": "—", "brand_null": "—", "brandid_null": "—", "db=di": "—", "ok": False})
            blockers.append(f"{tbl} 不存在")
    lines.append("**L2 品牌门控（test_dwd）**")
    lines.append("")
    lines.append(md_table(l2_rows, ["l2", "rows", "brand_null", "brandid_null", "db=di", "ok"]))

    # classify 前置（icpdf 须先 classify-merge）
    cls_test = qall(
        cur,
        f"""
        SELECT data_source, COUNT(*) n
        FROM test_dwd.dwd_component_class_{L1}
        WHERE l1_code='{L1}'
        GROUP BY 1 ORDER BY n DESC
        """,
    )
    cls_prod = qall(
        cur,
        f"""
        SELECT data_source, COUNT(*) n
        FROM dwd.dwd_component_class
        WHERE l1_code='{L1}'
        GROUP BY 1 ORDER BY n DESC
        """,
    )
    lines.extend(["", "### 0.1 classify 前置", ""])
    lines.append("| 侧 | data_source | n |")
    lines.append("|----|-------------|---|")
    for r in cls_prod:
        lines.append(f"| prod | {r['data_source']} | {r['n']:,} |")
    for r in cls_test:
        lines.append(f"| test | {r['data_source']} | {r['n']:,} |")
    icpdf_prod = next((r["n"] for r in cls_prod if r["data_source"] == "icpdf"), 0)
    icpdf_test = next((r["n"] for r in cls_test if r["data_source"] == "icpdf"), 0)
    if icpdf_test > 0 and icpdf_prod == 0:
        warnings.append(
            f"classify 前置：prod icpdf=0 · test icpdf={icpdf_test:,} → **须先 dim-l3-classify-merge** 再 attr-merge 写 icpdf EAV/L2"
        )

    # ── Step 1 PK ──
    lines.extend(["", "## 1. PK 冲突预检", ""])
    schema_dup = q1(
        cur,
        f"""
        SELECT COUNT(*) n FROM (
          SELECT schema_version, l1_code, scope_level, scope_code, std_attr_code, COUNT(*) c
          FROM (
            SELECT schema_version, l1_code, scope_level, scope_code, std_attr_code
            FROM dim.dim_attr_schema WHERE l1_code <> '{L1}'
            UNION ALL
            SELECT schema_version, l1_code, scope_level, scope_code, std_attr_code
            FROM {TEST_SCHEMA}
          ) u GROUP BY 1,2,3,4,5 HAVING COUNT(*)>1
        ) x
        """,
    )["n"]
    rule_dup = q1(
        cur,
        f"""
        SELECT COUNT(*) n FROM (
          SELECT extract_rule_id, COUNT(*) c FROM (
            SELECT extract_rule_id FROM dim.dim_attr_extract_rule
            WHERE l1_code <> '{L1}'
              AND extract_rule_id NOT REGEXP '^{L1}_'
              AND extract_rule_id NOT REGEXP '^cp_'
            UNION ALL SELECT extract_rule_id FROM {TEST_RULE}
          ) u GROUP BY 1 HAVING COUNT(*)>1
        ) x
        """,
    )["n"]
    lines.append(f"- **attr_schema PK 跨 L1 冲突**：{schema_dup} 组 {'✅' if schema_dup == 0 else '❌ STOP'}")
    lines.append(f"- **extract_rule_id PK 跨 L1 冲突**：{rule_dup} 个 {'✅' if rule_dup == 0 else '❌ STOP'}")
    if schema_dup:
        blockers.append("attr_schema PK 跨 L1 冲突")
    if rule_dup:
        blockers.append("extract_rule_id PK 跨 L1 冲突")

    # ── Step 2 质量 ──
    lines.extend(["", "## 2. 质量检查", ""])
    bad_l1 = q1(
        cur,
        f"SELECT COUNT(*) n FROM {TEST_SCHEMA} WHERE l1_code <> '{L1}'",
    )["n"]
    bad_sv = q1(
        cur,
        f"SELECT COUNT(*) n FROM {TEST_SCHEMA} WHERE schema_version <> '{SCHEMA_VERSION}'",
    )["n"]
    bad_rules = qall(
        cur,
        f"""
        SELECT extract_rule_id, l1_code FROM {TEST_RULE}
        WHERE l1_code <> '{L1}'
           OR (extract_rule_id NOT REGEXP '^{L1}_'
               AND extract_rule_id NOT REGEXP '^cp_')
        LIMIT 10
        """,
    )
    orphan = q1(
        cur,
        f"""
        SELECT COUNT(DISTINCT r.std_attr_code) n
        FROM {TEST_RULE} r
        LEFT JOIN {TEST_SCHEMA} s
          ON s.schema_version = r.schema_version
         AND s.l1_code = '{L1}'
         AND s.std_attr_code = r.std_attr_code
        WHERE s.std_attr_code IS NULL
        """,
    )["n"]
    bad_naming = qall(
        cur,
        f"""
        SELECT scope_level, scope_code, std_attr_code
        FROM {TEST_SCHEMA}
        WHERE std_attr_code NOT REGEXP '^[a-z0-9]+(_[a-z0-9]+)*$'
           OR scope_code NOT REGEXP '^[a-z0-9]+(_[a-z0-9]+)*$'
           OR (scope_level = 'L2' AND scope_code REGEXP '_base$')
        LIMIT 10
        """,
    )
    lines.append(f"- l1_code 非 `{L1}`：**{bad_l1}** {'✅' if bad_l1 == 0 else '❌'}")
    lines.append(f"- schema_version 非 `{SCHEMA_VERSION}`：**{bad_sv}** {'✅' if bad_sv == 0 else '❌'}")
    lines.append(f"- extract_rule 孤儿 std_attr：**{orphan}** {'✅' if orphan == 0 else '❌ STOP'}")
    if bad_l1:
        blockers.append("schema l1_code 不一致")
    if bad_sv:
        warnings.append(f"schema_version 有 {bad_sv} 行非 {SCHEMA_VERSION}")
    if orphan:
        blockers.append("extract_rule 孤儿 std_attr")
    if bad_rules:
        lines.append("")
        lines.append("**extract_rule_id / l1_code 异常（前 10）**")
        lines.append("")
        lines.append(md_table(bad_rules, ["extract_rule_id", "l1_code"]))
        blockers.append("extract_rule_id 前缀不合规")
    else:
        lines.append(f"- extract_rule_id 前缀（`cp_` / `circuit_protection_`）：✅")
    if bad_naming:
        lines.append("")
        lines.append("**scope/std_attr 命名异常**")
        lines.append("")
        lines.append(md_table(bad_naming, ["scope_level", "scope_code", "std_attr_code"]))
        blockers.append("scope/std_attr 命名不合规")
    else:
        lines.append("- scope/std_attr snake_case 命名：✅")

    scope_dist = qall(
        cur,
        f"SELECT scope_level, COUNT(*) n FROM {TEST_SCHEMA} GROUP BY 1 ORDER BY 1",
    )
    lines.append("")
    lines.append("**schema scope 分布**")
    lines.append("")
    lines.append(md_table(scope_dist, ["scope_level", "n"]))

    # ── Step 3 prod 替换范围 ──
    lines.extend(["", "## 3. prod ↔ test 只读 diff", ""])
    prod_s = q1(cur, f"SELECT COUNT(*) n FROM dim.dim_attr_schema WHERE l1_code='{L1}'")["n"]
    prod_r = q1(
        cur,
        f"""
        SELECT COUNT(*) n FROM dim.dim_attr_extract_rule
        WHERE l1_code='{L1}' OR extract_rule_id REGEXP '^(cp_|{L1}_)'
        """,
    )["n"]
    test_s = q1(cur, f"SELECT COUNT(*) n FROM {TEST_SCHEMA}")["n"]
    test_r = q1(cur, f"SELECT COUNT(*) n FROM {TEST_RULE}")["n"]
    lines.append("| 表 | prod 现况 | test 沙盒 | merge 动作 |")
    lines.append("|----|-----------|-----------|------------|")
    lines.append(f"| dim_attr_schema | {prod_s} | {test_s} | DELETE prod L1 → INSERT test |")
    lines.append(f"| dim_attr_extract_rule | {prod_r} | {test_r} | DELETE prod L1/cp_* → INSERT test |")
    lines.append("")

    prod_rule_ds = qall(
        cur,
        f"""
        SELECT data_source, COUNT(*) n FROM dim.dim_attr_extract_rule
        WHERE l1_code='{L1}' OR extract_rule_id REGEXP '^cp_'
        GROUP BY 1 ORDER BY n DESC
        """,
    )
    test_rule_ds = qall(
        cur,
        f"SELECT data_source, COUNT(*) n FROM {TEST_RULE} GROUP BY 1 ORDER BY n DESC",
    )
    lines.append("**prod extract_rule by data_source**")
    lines.append("")
    lines.append(md_table(prod_rule_ds, ["data_source", "n"]))
    lines.append("**test extract_rule by data_source**")
    lines.append("")
    lines.append(md_table(test_rule_ds, ["data_source", "n"]))

    new_rule_ids = qall(
        cur,
        f"""
        SELECT t.extract_rule_id FROM {TEST_RULE} t
        LEFT JOIN dim.dim_attr_extract_rule p ON p.extract_rule_id = t.extract_rule_id
        WHERE p.extract_rule_id IS NULL
        ORDER BY t.extract_rule_id
        LIMIT 20
        """,
    )
    lines.append(f"- test **新增** extract_rule_id：**{q1(cur, f'SELECT COUNT(*) n FROM {TEST_RULE} t LEFT JOIN dim.dim_attr_extract_rule p ON p.extract_rule_id=t.extract_rule_id WHERE p.extract_rule_id IS NULL')['n']}**")
    if new_rule_ids:
        lines.append("")
        lines.append("新增 rule_id 样例（前 20）：")
        for r in new_rule_ids:
            lines.append(f"- `{r['extract_rule_id']}`")

    # prod L2 vs test
    lines.extend(["", "### 3.1 prod L2 宽表现况", ""])
    prod_l2_rows: list[dict] = []
    prod_l2_total = 0
    for l2 in L2S:
        tbl = f"dwd.dwd_l2_{L1}_{l2}"
        try:
            r = q1(
                cur,
                f"""
                SELECT COUNT(*) total,
                       SUM(CASE WHEN brand IS NULL OR trim(brand)='' THEN 1 ELSE 0 END) brand_null
                FROM {tbl}
                """,
            )
            by_ds = qall(cur, f"SELECT data_source, COUNT(*) n FROM {tbl} GROUP BY 1 ORDER BY n DESC")
            ds_str = ", ".join(f"{x['data_source']}={x['n']:,}" for x in by_ds) or "—"
            total = int(r["total"] or 0)
            prod_l2_total += total
            prod_l2_rows.append(
                {
                    "l2": l2,
                    "rows": total,
                    "brand_null": r["brand_null"],
                    "by_ds": ds_str,
                    "prod表": "✅" if total > 0 or l2 == "surge_protection_module" else "—",
                }
            )
        except (pymysql.err.ProgrammingError, pymysql.err.OperationalError):
            prod_l2_rows.append({"l2": l2, "rows": "—", "brand_null": "—", "by_ds": "表不存在", "prod表": "❌ 待建"})
            if l2 != "surge_protection_module":
                warnings.append(f"prod {tbl} 不存在或不可读")
            else:
                warnings.append("prod spd L2 表尚未创建（merge 后 run_attr_std 首次 DDL）")
    lines.append(md_table(prod_l2_rows, ["l2", "rows", "brand_null", "by_ds", "prod表"]))
    lines.append("")
    lines.append(f"- test L2 合计：**{test_l2_total:,}**（icpdf）· prod L2 合计：**{prod_l2_total:,}**（digikey）")
    lines.append(f"- merge 后 prod L2 预期：icpdf **{test_l2_total:,}** + digikey **~153k**（Step 7 回归）")

    prod_eav = qall(
        cur,
        f"""
        SELECT e.data_source, COUNT(*) rows_, COUNT(DISTINCT e.id) ids
        FROM dwd.dwd_component_attr_std e
        INNER JOIN dwd.dwd_component_class c ON c.id=e.id AND c.data_source=e.data_source
        WHERE c.l1_code='{L1}'
        GROUP BY 1 ORDER BY rows_ DESC
        """,
    )
    test_eav_agg = qall(
        cur,
        f"SELECT data_source, COUNT(*) rows_, COUNT(DISTINCT id) ids FROM {TEST_EAV} GROUP BY 1 ORDER BY rows_ DESC",
    )
    lines.extend(["", "### 3.2 EAV", ""])
    lines.append("**prod EAV（circuit_protection 分类 id）**")
    lines.append("")
    lines.append(md_table(prod_eav, ["data_source", "rows_", "ids"]) if prod_eav else "_prod 尚无 icpdf 分类 EAV_\n")
    lines.append("**test EAV**")
    lines.append("")
    lines.append(md_table(test_eav_agg, ["data_source", "rows_", "ids"]))

    # ── Step 4 入仓脚本 ──
    lines.extend(["", "## 4. 入仓脚本 & run_attr_std.sh", ""])
    repo_block, repo_warn = check_repo_scripts()
    blockers.extend(repo_block)
    warnings.extend(repo_warn)
    script_rows = []
    for l2 in L2S:
        ddl = READY / f"dwd_l2_{L1}_{l2}.sql"
        build = READY / f"build_dwd_l2_{L1}_{l2}.sql"
        script_rows.append(
            {
                "l2": l2,
                "DDL": "✅" if ddl.exists() else "❌",
                "build": "✅" if build.exists() else "❌",
                "_unclassified过滤": "✅"
                if build.exists() and "_unclassified" in build.read_text(encoding="utf-8")
                else ("—" if not build.exists() else "❌"),
            }
        )
    lines.append(md_table(script_rows, ["l2", "DDL", "build", "_unclassified过滤"]))
    lines.append("")
    lines.append(f"- `run_attr_std.sh` · `l1_dir` → `16_circuit_protection_ready`：{'✅' if '16_circuit_protection_ready' in RUN_ATTR.read_text(encoding='utf-8') else '❌'}")
    lines.append(f"- `l2_files_for_l1` 4 张 L2：{'✅' if all(f'circuit_protection_{l2}' in RUN_ATTR.read_text(encoding='utf-8') for l2 in L2S) else '❌'}")

    # ── unit_factor ──
    lines.extend(["", "## 5. unit_factor supplement", ""])
    if SUPP.exists():
        pairs = re.findall(r"SELECT '([^']+)',\s*'([^']+)'", SUPP.read_text(encoding="utf-8"))
        missing = []
        for target_unit, unit_raw in pairs:
            if not q1(
                cur,
                f"""
                SELECT COUNT(*) n FROM dim.dim_unit_factor
                WHERE target_unit='{target_unit}' AND unit_raw='{unit_raw}'
                """,
            )["n"]:
                missing.append({"target_unit": target_unit, "unit_raw": unit_raw})
        lines.append(f"- 文件：`dim_unit_factor_circuit_protection_supplement.sql`")
        lines.append(f"- 声明 **{len(pairs)}** 对 · prod 缺失 **{len(missing)}**")
        if missing:
            lines.append("")
            lines.append(md_table(missing, ["target_unit", "unit_raw"]))
            warnings.append(f"merge Step 5 须追加 unit_factor {len(missing)} 行")
        else:
            lines.append("- ✅ prod 已齐全")
    else:
        lines.append("_无 supplement 文件_")
        warnings.append("缺少 dim_unit_factor supplement SQL")

    # ── 结论 ──
    lines.extend(["", "## 6. 预检结论", ""])
    if blockers:
        lines.append("**❌ 存在阻断项，暂不可 attr-merge：**")
        for b in blockers:
            lines.append(f"- {b}")
    else:
        lines.append("**✅ dim-attr-std-merge 预检通过，可进入人工授权后的 merge。**")
    if warnings:
        lines.append("")
        lines.append("**⚠️ 注意事项（非阻断）：**")
        for w in warnings:
            lines.append(f"- {w}")
    lines.append("")
    lines.append("**推荐 merge 顺序：**")
    lines.append("1. `dim-l3-classify-merge`（prod 写入 icpdf 分类 ~70,623 行）")
    lines.append("2. **本 skill** Step 5：backup → DELETE prod L1 dim → INSERT test_dim 后缀表 + unit_factor supplement")
    lines.append("3. Step 6（可选）：test_dwd merge 临时表对比阶段 1 后缀表")
    lines.append("4. Step 7：`ALLOW_PROD=1 SOURCES=\"icpdf digikey\" L1_LIST=\"... circuit_protection\" run_attr_std.sh prod`")
    lines.append("5. Step 10：`run_component_catalog.sh prod` 刷新 catalog")
    lines.append("")

    OUT.write_text("\n".join(lines), encoding="utf-8")
    print(f"wrote {OUT}")
    print("blockers:", blockers or "none")
    print("warnings:", len(warnings))
    conn.close()
    return 1 if blockers else 0


if __name__ == "__main__":
    raise SystemExit(main())
