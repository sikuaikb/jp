#!/usr/bin/env python3
"""属性标准化 dim 机械校验器（component-etl-methodology 硬门控的可执行版）。

把"只能写在 prompt 里"的属性 dim 硬规则变成 fail-fast 校验。三张 dim 字典
（dim_attr_schema / dim_attr_extract_rule / dim_unit_factor）在装载
进 test_dim / dim 之前必须先过这个工具。

用法（二选一，优先连库）：
    python3 validate_attr_dim.py \
        --dim-schema test_dim \
        --schema-table dim_attr_schema_capacitor \
        --rule-table dim_attr_extract_rule_capacitor \
        --unit-table dim_unit_factor \
        [--l1 capacitor]
    python3 validate_attr_dim.py \
        --schema-csv  <dim_attr_schema.csv> \
        --rule-csv    <dim_attr_extract_rule.csv> \
        --unit-csv    <dim_unit_factor.csv> \
        [--l1         resistor]

退出码：0 = 全部硬门控通过；1 = 有硬门控失败（WARN 不影响退出码）。

校验项（硬门控 = FAIL，建议项 = WARN）：
    A1  [FAIL] std_attr_code 必须 lower snake_case（^[a-z][a-z0-9_]*$）
               —— 拦截大写/连字符/空格列名，宽表物理列名直接取自此字段
    A2  [FAIL] dim_attr_schema PK 唯一：
               (schema_version,l1_code,scope_level,scope_code,std_attr_code)
    A3  [FAIL] scope_level 只能是 l2 / l3
    A4  [FAIL] db_type 只能是 VARCHAR/DOUBLE/BOOLEAN/INT/BIGINT/DATETIME/JSON/TINYINT
    A5  [FAIL] 同一 (l1_code, l2_code) 只能有一个 schema_version
               —— 窄表 attr_l2_catalog 取 MAX(schema_version)，多版本并存会歧义
    A6  [FAIL] extract_rule_id 全局唯一（跨 l1_code 也不得重复）
    A7  [FAIL] 抽取规则引用的 (schema_version,l1_code,std_attr_code) 必须在 schema 中存在
               —— 拦截 orphan 规则 / std_attr_code 拼写漂移
    A8  [WARN] schema 中非空 unit_std 建议能在 dim_unit_factor.target_unit 找到换算
               —— 找不到时引擎走裸数值 passthrough，可恢复，故为 WARN 不是 FAIL
    A9  [FAIL] dim_unit_factor PK 唯一 (target_unit,unit_raw)；factor 必须可解析为数值
    A10 [FAIL] 抽取规则 enabled / priority 必须是整数
    A11 [WARN] db_type=DOUBLE 但 unit_std 为空（裸数值，确认无需单位换算）
    A12 [FAIL] scope_level=l2 行的 scope_code（= l2_code）不得以 `_base` 结尾
               —— 与分类层 l2_code 命名约束一致（L2 名不要带 base）
    A13 [WARN] db_type∈{DOUBLE,INT} 但 max_bound 为空（上界缺失）
               —— 引擎 out_of_range 只能靠 min/max 机械拦截；缺上界则异常高值
                  （如 tcr=-3e7、电压=3e5）无法被标记，建议补 max_bound
    A14 [WARN] value_domain 文本暗示有界（含 > < ≥ ≤ ~ 或数字区间）但 min_bound
               与 max_bound 同时为空（dim 内部不一致：界写在人读文本里没落到
               机器列，引擎读 min_bound/max_bound 而非 value_domain，约束形同虚设）
    A15 [FAIL] 多源覆盖对称性：某属性被该 L1 的部分 data_source 覆盖、另一些源 0 规则
               —— 多源架构（一个 L1 多个源）下「某源对某属性/整层 L3 属性 0 规则」是
                  漏建高发区（实际踩坑：digikey 缺 capacitance_f 与全部 L3 属性规则，
                  却因沙盒 build 漏源隔离、被 icpdf 规则越界顶替而在阶段 1 未暴露）。
                  每个非对称属性必须二选一：① 补该源规则；② 用豁免清单显式登记
                  「该源确无此属性」。两者都没有 → FAIL 阻断（不再靠人读 WARN）。
                  豁免方式（机器无法区分「漏建 bug」与「该源真无此属性」，故需人工登记）：
                    --attr-source-waiver L1:SOURCE:STD_ATTR_CODE （可重复）
                    或 env ATTR_SOURCE_WAIVER="L1:SOURCE:CODE L1:SOURCE:CODE ..."
                  已豁免项打印为 WARN A15(waived)，不影响退出码。
    A16 [WARN] schema→rule 反向覆盖：某 std_attr_code 在 dim_attr_schema 有定义、
               但**所有** data_source 都 0 抽取规则（A15 只查源间不对称，此项补「全源皆缺」
               的盲区）。该属性注定恒空（独立列/ext 键拿不到值），须确认是否漏建规则
"""
from __future__ import annotations

import argparse
import csv
import os
import re
import sys
from pathlib import Path

SNAKE_RE = re.compile(r"^[a-z][a-z0-9_]*$")
ALLOWED_DB_TYPE = {"VARCHAR", "DOUBLE", "BOOLEAN", "INT", "BIGINT", "DATETIME", "JSON", "TINYINT"}
ALLOWED_SCOPE = {"l2", "l3"}
NUMERIC_DB_TYPE = {"DOUBLE", "INT", "BIGINT"}
# value_domain 文本里出现这些「界符号 / 数字区间」即视为「人读文本声明了取值范围」
BOUND_HINT_RE = re.compile(r"[><≥≤~]|\d+\s*[~\-至到]\s*\d+")


def read_csv(path: Path) -> list[dict]:
    with path.open(encoding="utf-8") as fh:
        return list(csv.DictReader(fh))


def g(row: dict, key: str) -> str:
    return (row.get(key) or "").strip()


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--schema-csv", type=Path)
    ap.add_argument("--rule-csv", type=Path)
    ap.add_argument("--unit-csv", type=Path)
    ap.add_argument("--dim-schema", help="连库读属性 dim（与 *-table 合用）")
    ap.add_argument("--schema-table")
    ap.add_argument("--rule-table")
    ap.add_argument("--unit-table")
    ap.add_argument("--l1", help="只校验该 l1_code；不传则全表")
    ap.add_argument(
        "--attr-source-waiver",
        action="append",
        default=[],
        metavar="L1:SOURCE:STD_ATTR_CODE",
        help="A15 豁免：显式登记「该源确无此属性」，可重复；也可用 env ATTR_SOURCE_WAIVER",
    )
    args = ap.parse_args()

    # A15 豁免清单：CLI + env（空格/逗号分隔），元素形如 l1:source:std_attr_code
    waiver_raw = list(args.attr_source_waiver)
    waiver_raw += re.split(r"[\s,]+", os.environ.get("ATTR_SOURCE_WAIVER", "").strip())
    a15_waiver: set[tuple[str, str, str]] = set()
    for item in waiver_raw:
        item = item.strip()
        if not item:
            continue
        parts = item.split(":")
        if len(parts) != 3:
            print(
                f"ERROR: --attr-source-waiver 格式应为 L1:SOURCE:STD_ATTR_CODE，收到 {item!r}",
                file=sys.stderr,
            )
            sys.exit(2)
        a15_waiver.add((parts[0].strip(), parts[1].strip(), parts[2].strip()))

    schema_cols = [
        "schema_version", "l1_code", "scope_level", "scope_code", "std_attr_code",
        "std_attr_cn", "unit_std", "db_type", "precision", "value_domain",
        "min_bound", "max_bound", "is_l2_common", "display_ord",
        "attr_category_cn", "attr_category_en", "note",
    ]
    rule_cols = [
        "extract_rule_id", "data_source", "schema_version", "l1_code",
        "apply_scope_level", "apply_scope_code",
        "std_attr_code", "source_kind", "source_expr",
        "source_value_expr", "source_value_regex", "literal_std_value",
        "priority", "enabled", "value_map", "note",
    ]
    unit_cols = ["target_unit", "unit_raw", "factor", "note"]

    if args.dim_schema:
        for tname, label in [
            (args.schema_table, "--schema-table"),
            (args.rule_table, "--rule-table"),
            (args.unit_table, "--unit-table"),
        ]:
            if not tname:
                print(f"ERROR: --dim-schema 须同时提供 {label}", file=sys.stderr)
                sys.exit(2)
        from dim_db_loader import fetch_rows

        schema_rows = fetch_rows(args.dim_schema, args.schema_table, schema_cols)
        rule_rows = fetch_rows(args.dim_schema, args.rule_table, rule_cols)
        unit_rows = fetch_rows(args.dim_schema, args.unit_table, unit_cols)
        src = f"{args.dim_schema}.*"
    elif args.schema_csv and args.rule_csv and args.unit_csv:
        schema_rows = read_csv(args.schema_csv)
        rule_rows = read_csv(args.rule_csv)
        unit_rows = read_csv(args.unit_csv)
        src = str(args.schema_csv)
    else:
        print("ERROR: 须提供 --dim-schema+表名，或三张 --*-csv", file=sys.stderr)
        sys.exit(2)

    if args.l1:
        schema_rows = [r for r in schema_rows if g(r, "l1_code") == args.l1]
        rule_rows = [r for r in rule_rows if g(r, "l1_code") == args.l1]

    fails: list[str] = []
    warns: list[str] = []
    # A13/A14 按 L1 聚合（避免逐属性刷屏）；按 (l1,code) 去重
    a13_miss_max: dict[str, set[str]] = {}   # l1 -> {缺 max_bound 的数值属性}
    a14_domain_only: dict[str, set[str]] = {}  # l1 -> {value_domain 声明了界但 min/max 空的属性}

    # A9: unit_factor PK + factor 数值
    unit_pk: set[tuple[str, str]] = set()
    target_units: set[str] = set()
    for r in unit_rows:
        tu, ur = g(r, "target_unit"), g(r, "unit_raw")
        target_units.add(tu)
        pk = (tu, ur)
        if pk in unit_pk:
            fails.append(f"A9 dim_unit_factor PK 重复 (target_unit,unit_raw)={pk}")
        unit_pk.add(pk)
        fac = g(r, "factor")
        try:
            float(fac)
        except ValueError:
            fails.append(f"A9 factor 非数值: target_unit={tu} unit_raw={ur!r} factor={fac!r}")

    # A1..A5 + A11: schema 校验
    schema_pk: set[tuple] = set()
    schema_attr: set[tuple[str, str, str]] = set()  # (schema_version, l1_code, std_attr_code)
    l2_versions: dict[tuple[str, str], set[str]] = {}  # (l1_code, l2_code/scope_code) -> versions
    for r in schema_rows:
        sv = g(r, "schema_version")
        l1 = g(r, "l1_code")
        lvl = g(r, "scope_level")
        sc = g(r, "scope_code")
        code = g(r, "std_attr_code")
        dbt = g(r, "db_type").upper()
        unit = g(r, "unit_std")

        if not SNAKE_RE.match(code):
            fails.append(f"A1 std_attr_code 非 lower_snake_case: {code!r} (l1={l1} scope={lvl}/{sc})")
        pk = (sv, l1, lvl, sc, code)
        if pk in schema_pk:
            fails.append(
                "A2 dim_attr_schema PK 重复 "
                f"(schema_version,l1_code,scope_level,scope_code,std_attr_code)={pk}"
            )
        schema_pk.add(pk)
        schema_attr.add((sv, l1, code))
        if lvl not in ALLOWED_SCOPE:
            fails.append(
                f"A3 scope_level 非法: {lvl!r}（只能是 {sorted(ALLOWED_SCOPE)}；l1={l1} attr={code}）"
            )
        if dbt not in ALLOWED_DB_TYPE:
            fails.append(
                f"A4 db_type 非法: {dbt!r}（只能是 {sorted(ALLOWED_DB_TYPE)}；l1={l1} attr={code}）"
            )
        if lvl == "l2":
            l2_versions.setdefault((l1, sc), set()).add(sv)
            if sc.endswith("_base"):
                fails.append(f"A12 scope_code(l2)={sc!r} 以 _base 结尾（L2 名不要带 base；l1={l1}）")
        if unit and unit not in target_units:
            warns.append(
                f"A8 unit_std={unit!r} 在 dim_unit_factor.target_unit 中找不到换算 "
                f"(l1={l1} attr={code})；引擎将走裸数值 passthrough"
            )
        if dbt == "DOUBLE" and not unit:
            warns.append(f"A11 DOUBLE 属性无 unit_std（裸数值）: l1={l1} attr={code}")

        # A13/A14: 数值属性的「合理区间」覆盖审计（dim_attr_schema 已有 min_bound/max_bound 列）
        if dbt in NUMERIC_DB_TYPE:
            min_b = g(r, "min_bound")
            max_b = g(r, "max_bound")
            domain = g(r, "value_domain")
            if not max_b:
                a13_miss_max.setdefault(l1, set()).add(code)
            if not min_b and not max_b and domain and BOUND_HINT_RE.search(domain):
                a14_domain_only.setdefault(l1, set()).add(code)

    for (l1, l2), versions in l2_versions.items():
        if len(versions) > 1:
            fails.append(f"A5 (l1={l1}, l2={l2}) 并存多个 schema_version: {sorted(versions)}")

    # A13/A14 聚合输出（每 L1 一条，含计数 + 属性清单，便于定位但不刷屏）
    def _fmt(codes: set[str], cap: int = 12) -> str:
        s = sorted(codes)
        return str(s) if len(s) <= cap else f"{s[:cap]} …(+{len(s) - cap})"

    for l1 in sorted(a13_miss_max):
        codes = a13_miss_max[l1]
        warns.append(
            f"A13 l1={l1} 有 {len(codes)} 个数值属性缺 max_bound（上界）；无上界则异常高值"
            f"（如 tcr=-3e7、电压=3e5）无法被引擎标 out_of_range，建议补 max_bound: {_fmt(codes)}"
        )
    for l1 in sorted(a14_domain_only):
        codes = a14_domain_only[l1]
        warns.append(
            f"A14 l1={l1} 有 {len(codes)} 个数值属性 value_domain 文本声明了取值范围但 min_bound/max_bound 均空；"
            f"引擎读 min_bound/max_bound 不读 value_domain，应把界转写进机器列: {_fmt(codes)}"
        )

    # A6 + A7 + A10: extract_rule 校验；A15: 按 data_source 的覆盖对称性
    rule_pk: set[str] = set()
    src_per_l1: dict[str, set[str]] = {}                  # l1 -> {data_source}
    src_per_attr: dict[tuple[str, str], set[str]] = {}    # (l1, std_attr_code) -> {data_source}
    a15_missing_ds = False
    for r in rule_rows:
        rid = g(r, "extract_rule_id")
        if rid in rule_pk:
            fails.append(f"A6 extract_rule_id 全局重复: {rid}")
        rule_pk.add(rid)

        sv = g(r, "schema_version")
        l1 = g(r, "l1_code")
        code = g(r, "std_attr_code")
        if (sv, l1, code) not in schema_attr:
            fails.append(
                f"A7 抽取规则 {rid} 引用 (schema_version={sv}, l1={l1}, std_attr_code={code}) "
                f"在 dim_attr_schema 中不存在（orphan 规则 / 拼写漂移）"
            )
        for col in ("enabled", "priority"):
            v = g(r, col)
            if v and not re.fullmatch(r"-?\d+", v):
                fails.append(f"A10 {col} 非整数: {rid} {col}={v!r}")

        ds = g(r, "data_source")
        if not ds:
            a15_missing_ds = True
        else:
            src_per_l1.setdefault(l1, set()).add(ds)
            src_per_attr.setdefault((l1, code), set()).add(ds)

    # A15: 多源覆盖对称性审计（仅在该 L1 出现 ≥2 个 data_source 时才有意义）
    if a15_missing_ds:
        warns.append("A15 部分抽取规则缺 data_source，相关行已跳过按源覆盖对称性审计")
    a15_gap: dict[tuple[str, str], set[str]] = {}      # (l1, 缺规则的源) -> 未豁免缺失属性
    a15_waived: dict[tuple[str, str], set[str]] = {}   # (l1, 缺规则的源) -> 已豁免缺失属性
    for (l1, code), srcs in src_per_attr.items():
        full = src_per_l1.get(l1, set())
        if len(full) < 2:
            continue  # 单源 L1 无对称性可言
        for missing in full - srcs:
            if (l1, missing, code) in a15_waiver:
                a15_waived.setdefault((l1, missing), set()).add(code)
            else:
                a15_gap.setdefault((l1, missing), set()).add(code)
    for (l1, missing) in sorted(a15_waived):
        codes = a15_waived[(l1, missing)]
        warns.append(
            f"A15(waived) l1={l1} data_source={missing!r} 已豁免 {len(codes)} 个属性"
            f"（人工登记「该源确无此属性」）: {_fmt(codes)}"
        )
    for (l1, missing) in sorted(a15_gap):
        codes = a15_gap[(l1, missing)]
        fails.append(
            f"A15 l1={l1} data_source={missing!r} 缺 {len(codes)} 个属性的抽取规则"
            f"（同 L1 其他源已覆盖、该源 0 规则，多源覆盖不对称）；每个属性须"
            f"「补该源规则」或加豁免 --attr-source-waiver {l1}:{missing}:<attr>"
            f"（确认该源确无此属性）后方可进入阶段 2 合并: {_fmt(codes)}"
        )

    # A16: schema→rule 反向覆盖——某属性在 schema 有定义但所有源 0 规则（A15 盲区：全源皆缺）
    schema_codes_per_l1: dict[str, set[str]] = {}
    for (sv, l1, code) in schema_attr:
        schema_codes_per_l1.setdefault(l1, set()).add(code)
    ruled_codes_per_l1: dict[str, set[str]] = {}
    for (l1, code) in src_per_attr:
        ruled_codes_per_l1.setdefault(l1, set()).add(code)
    a16_gap: dict[str, set[str]] = {}
    for l1, codes in schema_codes_per_l1.items():
        missing = codes - ruled_codes_per_l1.get(l1, set())
        if missing:
            a16_gap[l1] = missing
    for l1 in sorted(a16_gap):
        codes = a16_gap[l1]
        warns.append(
            f"A16 l1={l1} 有 {len(codes)} 个属性在 dim_attr_schema 有定义但所有 data_source 0 抽取规则"
            f"（注定恒空，独立列/ext 键拿不到值）；确认是否漏建规则: {_fmt(codes)}"
        )

    for w in warns:
        print(f"WARN  {w}")
    for f in fails:
        print(f"FAIL  {f}")

    if fails:
        print(f"\n属性 dim 校验未通过：{len(fails)} 个硬门控失败，{len(warns)} 个警告  src={src}")
        sys.exit(1)
    print(
        f"属性 dim 校验通过：硬门控 OK（{len(warns)} 个警告）  src={src}  "
        f"schema={len(schema_rows)} 行 / rule={len(rule_rows)} 行 / unit={len(unit_rows)} 行"
    )
    sys.exit(0)


if __name__ == "__main__":
    main()
