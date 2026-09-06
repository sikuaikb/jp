#!/usr/bin/env python3
"""L2 宽表 DDL 机械校验器（对齐电阻基准 dwd_l2_resistor_fixed_resistor）。

把"所有 L2 宽表必须与 dwd_l2_resistor_fixed_resistor 保持一致"这条硬门控变成
fail-fast 校验。解析一份 CREATE TABLE DDL，对照基准检查公共列 / 类型 / PK / 命名 /
禁用旧列，并（可选）把 L2 物理列与 dim_attr_schema 对账。

用法：
    python3 validate_l2_widetable.py \
        --ddl <dwd_l2_xxx.sql> [<dwd_l2_yyy.sql> ...] \
        [--ddl-dir sql_scripts/2.attribute_standard]  # 批量扫 dwd_l2_*.sql
        [--schema-csv dim_attr_schema.csv]   # 提供后启用 W7 物理列对账
        [--l1 resistor] [--l2 fixed_resistor]  # 单文件时显式指定；多文件默认从 DDL 注释推断
        [--no-auto-l1-l2]                    # 禁用 W9/W7 的 l1/l2 自动推断

退出码：0 = 全部硬门控通过；1 = 有硬门控失败（WARN 不影响退出码）。

校验项（硬门控 = FAIL，建议项 = WARN）：
    W1  [FAIL] 标准头部 8 列齐全且顺序为
               data_source,id,mpn,brand,brandid,l1_code,l2_code,l3_code
    W2  [FAIL] 标准尾部列齐全且类型正确：
               ext_attributes JSON / semantic_tags JSON / dq_score DOUBLE /
               dq_flags JSON / source_id BIGINT / create_at DATETIME / update_at DATETIME
    W3  [FAIL] 头部列类型对齐基准（data_source VARCHAR NOT NULL · id BIGINT NOT NULL ·
               brandid BIGINT · l1_code/l2_code VARCHAR NOT NULL ...）
    W4  [FAIL] PRIMARY KEY(data_source, id) 且 DISTRIBUTED BY HASH(id)
    W5  [FAIL] 所有列名 lower_snake_case
    W6  [FAIL] 无重复列名；无 ',,' 双逗号语法错误
    W7  [FAIL] （需 --schema-csv）每个 L2 物理列必须是 dim_attr_schema 中
               (l1, scope_level=l2, scope_code=l2) 的 std_attr_code，且 db_type 家族一致
    W8  [FAIL] 不得出现废弃旧列：component_id / l2_type / created_at / updated_at
    W9  [FAIL] 表名必须是 dwd_l2_{l1}_{l2}（l1/l2 来自 CLI 或 DDL 头注释 / l1_code·l2_code 列 COMMENT）
    W10 [WARN] L2 物理列与头部 mpn/brand/brandid 重名（应复用头部，不要重复定义）
    W11 [FAIL] 表名不得以 _base 结尾（L2 名不要带 base，与分类层 l2_code 约束一致）
    W12 [FAIL] legacy 表名 dwd_l2_{x}_{x}（同一片段重复，疑似把 L2 误当 L1，如 dwd_l2_mcu_mcu）
    W13 [FAIL] DDL 声明的 l2_code 含 _base 后缀（与分类层 C7 一致，禁止 mcu_base 等占位名）
"""
from __future__ import annotations

import argparse
import csv
import re
import sys
from pathlib import Path

HEADER = ["data_source", "id", "mpn", "brand", "brandid", "l1_code", "l2_code", "l3_code"]
TAIL_TYPES = {
    "ext_attributes": "JSON",
    "semantic_tags": "JSON",
    "dq_score": "DOUBLE",
    "dq_flags": "JSON",
    "source_id": "BIGINT",
    "create_at": "DATETIME",
    "update_at": "DATETIME",
}
HEADER_TYPES = {
    "data_source": ("VARCHAR", True),
    "id": ("BIGINT", True),
    "mpn": ("VARCHAR", False),
    "brand": ("VARCHAR", False),
    "brandid": ("BIGINT", False),
    "l1_code": ("VARCHAR", True),
    "l2_code": ("VARCHAR", True),
    "l3_code": ("VARCHAR", False),
}
FORBIDDEN = {"component_id", "l2_type", "created_at", "updated_at"}
SNAKE_RE = re.compile(r"^[a-z][a-z0-9_]*$")

COL_RE = re.compile(r"^\s*`(?P<name>\w+)`\s+(?P<type>[A-Za-z]+)(?:\s*\([^)]*\))?(?P<rest>.*)$")
CREATE_RE = re.compile(r"CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?`?(?P<name>[\w.]+)`?\s*\(", re.IGNORECASE)
PK_RE = re.compile(r"PRIMARY\s+KEY\s*\(([^)]*)\)", re.IGNORECASE)
DIST_RE = re.compile(r"DISTRIBUTED\s+BY\s+HASH\s*\(([^)]*)\)", re.IGNORECASE)
HEADER_L1_RE = re.compile(r"l1_code\s*=\s*([\w]+)", re.IGNORECASE)
HEADER_L2_RE = re.compile(r"scope_code\s*=\s*([\w]+)", re.IGNORECASE)
L1_COL_COMMENT_RE = re.compile(
    r"`l1_code`[^'\n]*COMMENT\s+'[^']*L1[：:]\s*([\w]+)", re.IGNORECASE
)
L2_COL_COMMENT_RE = re.compile(
    r"`l2_code`[^'\n]*COMMENT\s+'[^']*L2[：:]\s*([\w]+)", re.IGNORECASE
)
LEGACY_DUP_TABLE_RE = re.compile(r"^dwd_l2_([\w]+)_\1$")

# db_type(schema) -> 可接受的 SQL 列类型家族
TYPE_FAMILY = {
    "VARCHAR": {"VARCHAR", "CHAR", "STRING", "TEXT"},
    "DOUBLE": {"DOUBLE", "FLOAT", "DECIMAL"},
    "BOOLEAN": {"BOOLEAN", "TINYINT"},
    "INT": {"INT", "BIGINT", "TINYINT", "SMALLINT"},
    "BIGINT": {"BIGINT"},
    "DATETIME": {"DATETIME", "DATE", "TIMESTAMP"},
    "JSON": {"JSON"},
    "TINYINT": {"TINYINT", "BOOLEAN", "INT"},
}


def parse_ddl(text: str):
    """返回 (table_name, [(col, type_upper, not_null)], pk_cols, dist_cols, raw_create)。"""
    m = CREATE_RE.search(text)
    if not m:
        return None
    table = m.group("name").split(".")[-1]
    create_block = text[m.end():]
    # 截到 ENGINE / PROPERTIES 之前（含 PRIMARY KEY 行也在其中，单独正则抓）
    end = re.search(r"\)\s*ENGINE", create_block, re.IGNORECASE)
    block = create_block[: end.start()] if end else create_block

    cols: list[tuple[str, str, bool]] = []
    for line in block.splitlines():
        stripped = line.strip()
        if stripped.upper().startswith(("PRIMARY KEY", "INDEX", "KEY ", "UNIQUE")):
            continue
        cm = COL_RE.match(line)
        if cm:
            name = cm.group("name")
            ctype = cm.group("type").upper()
            not_null = bool(re.search(r"\bNOT\s+NULL\b", cm.group("rest"), re.IGNORECASE))
            cols.append((name, ctype, not_null))

    pk = PK_RE.search(text)
    pk_cols = [c.strip().strip("`") for c in pk.group(1).split(",")] if pk else []
    dist = DIST_RE.search(text)
    dist_cols = [c.strip().strip("`") for c in dist.group(1).split(",")] if dist else []
    return table, cols, pk_cols, dist_cols, create_block[: (end.start() if end else len(create_block))]


def infer_l1_l2_from_ddl(text: str) -> tuple[str | None, str | None]:
    """从 DDL 文件头注释或 l1_code/l2_code 列 COMMENT 推断 taxonomy（零外部依赖）。"""
    l1: str | None = None
    l2: str | None = None
    head = text[:2500]
    if re.search(r"scope_level\s*=\s*l2", head, re.IGNORECASE):
        m1 = HEADER_L1_RE.search(head)
        m2 = HEADER_L2_RE.search(head)
        if m1:
            l1 = m1.group(1).lower()
        if m2:
            l2 = m2.group(1).lower()
    if not l1:
        m = L1_COL_COMMENT_RE.search(text)
        if m:
            l1 = m.group(1).lower()
    if not l2:
        m = L2_COL_COMMENT_RE.search(text)
        if m:
            l2 = m.group(1).lower()
    return l1, l2


def load_schema_l2(path: Path, l1: str | None, l2: str | None) -> dict[str, str]:
    """返回 {std_attr_code: db_type_upper}（scope_level=l2）。"""
    out: dict[str, str] = {}
    with path.open(encoding="utf-8") as fh:
        for r in csv.DictReader(fh):
            if (r.get("scope_level") or "").strip() != "l2":
                continue
            if l1 and (r.get("l1_code") or "").strip() != l1:
                continue
            if l2 and (r.get("scope_code") or "").strip() != l2:
                continue
            out[(r.get("std_attr_code") or "").strip()] = (r.get("db_type") or "").strip().upper()
    return out


def validate_one(
    ddl_path: Path,
    schema_csv: Path | None,
    l1: str | None,
    l2: str | None,
    *,
    auto_l1_l2: bool = True,
):
    fails: list[str] = []
    warns: list[str] = []
    text = ddl_path.read_text(encoding="utf-8")

    eff_l1, eff_l2 = l1, l2
    if auto_l1_l2:
        inf_l1, inf_l2 = infer_l1_l2_from_ddl(text)
        eff_l1 = eff_l1 or inf_l1
        eff_l2 = eff_l2 or inf_l2

    schema_l2 = load_schema_l2(schema_csv, eff_l1, eff_l2) if schema_csv else None

    # W6a: 双逗号语法错误
    if re.search(r",\s*,", text):
        fails.append("W6 检测到 ',,' 双逗号语法错误（DDL 无法执行）")

    parsed = parse_ddl(text)
    if not parsed:
        fails.append("解析失败：未找到 CREATE TABLE")
        return fails, warns
    table, cols, pk_cols, dist_cols, _ = parsed
    names = [c[0] for c in cols]
    type_by_name = {c[0]: (c[1], c[2]) for c in cols}

    # W5: snake_case
    for n in names:
        if not SNAKE_RE.match(n):
            fails.append(f"W5 列名非 lower_snake_case: {n!r}")
    # W6b: 重复列名
    dup = {n for n in names if names.count(n) > 1}
    if dup:
        fails.append(f"W6 重复列名: {sorted(dup)}")
    # W8: 废弃列
    bad = FORBIDDEN & set(names)
    if bad:
        fails.append(f"W8 出现废弃旧列: {sorted(bad)}")

    # W1: 头部 8 列顺序
    if names[:8] != HEADER:
        fails.append(f"W1 标准头部不符，应为 {HEADER}，实测前 8 列 {names[:8]}")
    # W3: 头部类型
    for col, (want_type, want_nn) in HEADER_TYPES.items():
        if col not in type_by_name:
            continue
        ctype, nn = type_by_name[col]
        if ctype != want_type:
            fails.append(f"W3 头部列 {col} 类型应为 {want_type}，实测 {ctype}")
        if want_nn and not nn:
            fails.append(f"W3 头部列 {col} 必须 NOT NULL")
    # W2: 尾部类型
    for col, want_type in TAIL_TYPES.items():
        if col not in type_by_name:
            fails.append(f"W2 缺少标准尾部列 {col}（应为 {want_type}）")
        elif type_by_name[col][0] != want_type:
            fails.append(f"W2 尾部列 {col} 类型应为 {want_type}，实测 {type_by_name[col][0]}")
    # W4: PK + 分布键
    if [c.lower() for c in pk_cols] != ["data_source", "id"]:
        fails.append(f"W4 PRIMARY KEY 应为 (data_source, id)，实测 {pk_cols}")
    if [c.lower() for c in dist_cols] != ["id"]:
        fails.append(f"W4 DISTRIBUTED BY HASH 应为 (id)，实测 {dist_cols}")

    # W9: 表名
    if eff_l1 and eff_l2:
        want = f"dwd_l2_{eff_l1}_{eff_l2}"
        if table != want:
            fails.append(
                f"W9 表名应为 {want}（l1={eff_l1}, l2={eff_l2}），实测 {table}"
            )
    else:
        warns.append("W9 缺 l1/l2（CLI 未传且 DDL 注释无法推断），跳过表名校验")

    # W11: 表名不得以 _base 结尾（L2 名是业务编码，不是基类占位）
    if table.endswith("_base"):
        fails.append(f"W11 表名 {table} 以 _base 结尾（L2 名不要带 base，与分类层 l2_code 约束一致）")

    # W12: legacy dwd_l2_{x}_{x}（如 mcu_mcu / dsp_dsp）
    dup = LEGACY_DUP_TABLE_RE.match(table)
    if dup:
        seg = dup.group(1)
        fails.append(
            f"W12 legacy 表名 {table}：片段 {seg!r} 重复，疑似把 L2 误当 L1；"
            f"应为 dwd_l2_<l1>_{seg}（如 mcu_mpu_dsp 单一 L1）"
        )

    # W13: l2_code 声明含 _base（与 C7 对齐）
    if eff_l2 and eff_l2.endswith("_base"):
        fails.append(
            f"W13 DDL 声明 l2_code={eff_l2!r} 含 _base 后缀"
            f"（L2 是业务 taxonomy 节点，禁止 mcu_base/dsp_base 占位名）"
        )

    # L2 物理列 = 全部列 - 头部 - 尾部
    l2_cols = [n for n in names if n not in HEADER and n not in TAIL_TYPES]
    # W10: 与头部 mpn/brand/brandid 重名
    redup = {"mpn", "brand", "brandid"} & set(l2_cols)
    if redup:
        warns.append(f"W10 L2 列与头部重名（应复用头部）: {sorted(redup)}")

    # W7: 物理列对账 dim_attr_schema（需 --l1 + --l2 精确锁定 scope，否则跨 L1 混淆，跳过）
    if schema_l2 is not None and not (eff_l1 and eff_l2):
        warns.append("W7 已提供 --schema-csv 但缺 l1/l2，无法锁定 (l1,scope_code) 精确对账，跳过物理列校验")
    elif schema_l2 is not None:
        for col in l2_cols:
            if col in {"mpn", "brand", "brandid"}:
                continue
            if col not in schema_l2:
                fails.append(
                    f"W7 物理列 {col} 不是 dim_attr_schema 中 "
                    f"(l1={eff_l1}, scope_level=l2, scope_code={eff_l2}) 的 std_attr_code"
                )
                continue
            want_fam = TYPE_FAMILY.get(schema_l2[col], set())
            ctype = type_by_name[col][0]
            if want_fam and ctype not in want_fam:
                fails.append(
                    f"W7 物理列 {col} 类型 {ctype} 与 schema db_type={schema_l2[col]} 家族不符 "
                    f"(可接受 {sorted(want_fam)})"
                )
    return fails, warns


def collect_ddl_paths(ddl_args: list[Path], ddl_dir: Path | None) -> list[Path]:
    paths: list[Path] = list(ddl_args)
    if ddl_dir:
        if not ddl_dir.is_dir():
            print(f"ERROR --ddl-dir 不是目录: {ddl_dir}", file=sys.stderr)
            sys.exit(1)
        paths.extend(sorted(ddl_dir.glob("dwd_l2_*.sql")))
    # 去重保序
    seen: set[Path] = set()
    out: list[Path] = []
    for p in paths:
        rp = p.resolve()
        if rp not in seen:
            seen.add(rp)
            out.append(p)
    return out


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--ddl", nargs="*", type=Path, default=[], help="一个或多个宽表 DDL 文件")
    ap.add_argument(
        "--ddl-dir",
        type=Path,
        help="扫描目录下所有 dwd_l2_*.sql（可与 --ddl 混用；shell glob 亦可展开到 --ddl）",
    )
    ap.add_argument("--schema-csv", type=Path)
    ap.add_argument("--l1", help="单文件校验时可显式指定 l1；多文件时忽略，改从 DDL 推断")
    ap.add_argument("--l2", help="单文件校验时可显式指定 l2；多文件时忽略，改从 DDL 推断")
    ap.add_argument(
        "--no-auto-l1-l2",
        action="store_true",
        help="禁用从 DDL 注释自动推断 l1/l2（W9/W7/W13 需 CLI 显式传参）",
    )
    args = ap.parse_args()

    ddls = collect_ddl_paths(args.ddl, args.ddl_dir)
    if not ddls:
        ap.error("需要至少一个 --ddl 文件或有效的 --ddl-dir")

    per_file_l1_l2 = len(ddls) == 1
    global_l1 = args.l1 if per_file_l1_l2 else None
    global_l2 = args.l2 if per_file_l1_l2 else None

    total_fail = 0
    for ddl in ddls:
        fails, warns = validate_one(
            ddl,
            args.schema_csv,
            global_l1,
            global_l2,
            auto_l1_l2=not args.no_auto_l1_l2,
        )
        print(f"\n=== {ddl} ===")
        for w in warns:
            print(f"WARN  {w}")
        for f in fails:
            print(f"FAIL  {f}")
        if not fails:
            print(f"OK    宽表 DDL 与电阻基准对齐（{len(warns)} 个警告）")
        total_fail += len(fails)

    if total_fail:
        print(f"\n宽表校验未通过：共 {total_fail} 个硬门控失败")
        sys.exit(1)
    sys.exit(0)


if __name__ == "__main__":
    main()
