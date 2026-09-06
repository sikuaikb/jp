#!/usr/bin/env python3
"""沙盒/分支 build SQL 的「规则表源隔离」静态 linter（component-etl-methodology 硬门控）。

把一类掩盖性 bug 变成 fail-fast：单源专用 build 脚本（如
build_dwd_<source>_component_attr_std_<l1>.sql / build_dwd_<source>_component_class_<l1>.sql）
JOIN 规则表（dim_attr_extract_rule* / dim_l3_classify_rule*）时若**漏掉**
`AND <alias>.data_source = '<source>'`，会让其他源的规则越界顶替、把缺规则的属性
「凑」出值，从而在阶段 1 影子产出里掩盖缺口（实际踩坑：digikey 电容 build 7 处 join
全漏源隔离，icpdf 规则越界，digikey 缺的 13 个属性被凑满，直到合并主干源隔离脚本才暴露）。

规则（均为 FAIL）：
    B1 [FAIL] 每个 JOIN 到「规则表」（表名含 extract_rule / classify_rule）的别名，
              必须在脚本中出现 `<alias>.data_source =` 等值谓词；缺失即判定源隔离漏写。
    B2 [FAIL] 给定 --expect-source <src> 时，该等值谓词右值必须是 '<src>'
              （拦截「过滤了但过滤成别的源」）。

零外部依赖：只读 --build-sql 传入的文件本身；连接串/源名等全部经 CLI 传入。

用法：
    python3 validate_build_source_isolation.py \
        --build-sql path/to/build_dwd_digikey_component_attr_std_capacitor.sql \
        --build-sql path/to/build_dwd_digikey_component_class_capacitor.sql \
        --expect-source digikey

    # 不锁具体源，只要求「凡 join 规则表必带 data_source 等值谓词」：
    python3 validate_build_source_isolation.py --build-sql a.sql b.sql

退出码：0 = 全部通过；1 = 有 FAIL；2 = 用法错误。
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

# 「规则表」识别：只匹配**真实 dim 规则表**（带 dim_ 前缀），不误伤 CTE
# （如 classify_rule_hit / rules_gate / gate_rule_components 都不该命中）
RULE_TABLE_HINT = re.compile(r"(dim_attr_extract_rule|dim_l3_classify_rule)", re.IGNORECASE)
# JOIN/FROM <table> [AS] <alias>
JOIN_RE = re.compile(
    r"\b(?:JOIN|FROM)\s+([A-Za-z_][\w.]*)\s+(?:AS\s+)?([A-Za-z_]\w*)",
    re.IGNORECASE,
)
LINE_COMMENT_RE = re.compile(r"--[^\n]*")
BLOCK_COMMENT_RE = re.compile(r"/\*.*?\*/", re.DOTALL)
# 紧跟表名的若不是真别名而是这些关键字 → 该引用「无别名」
NOT_ALIAS = {
    "on", "where", "inner", "left", "right", "full", "outer", "join", "cross",
    "group", "order", "having", "union", "using", "limit", "and", "or", "as",
}


def strip_comments(sql: str) -> str:
    sql = BLOCK_COMMENT_RE.sub(" ", sql)
    sql = LINE_COMMENT_RE.sub(" ", sql)
    return sql


def last_segment(table: str) -> str:
    return table.rsplit(".", 1)[-1]


def lint_file(path: Path, expect_source: str | None) -> list[str]:
    fails: list[str] = []
    raw = path.read_text(encoding="utf-8")
    sql = strip_comments(raw)

    # 收集对规则表的引用：(table, alias|None)；alias=None 表示该引用无别名
    refs: list[tuple[str, str | None]] = []
    seen: set[tuple[str, str | None]] = set()
    for m in JOIN_RE.finditer(sql):
        table, tok = m.group(1), m.group(2)
        if not RULE_TABLE_HINT.search(last_segment(table)):
            continue
        alias: str | None = None if tok.lower() in NOT_ALIAS else tok
        key = (last_segment(table), alias)
        if key in seen:
            continue
        seen.add(key)
        refs.append((table, alias))

    if not refs:
        return fails  # 该文件未引用真实 dim 规则表，无源隔离要求

    # 无别名引用（单表 CTE 内）允许 unqualified `data_source = '<src>'`
    unq_re = re.compile(r"(?<![\w.])data_source\s*=\s*'([^']*)'", re.IGNORECASE)
    unq_literals = {m for m in unq_re.findall(sql)}

    for table, alias in refs:
        if alias is None:
            # 无别名：接受 <表名段>.data_source= 或 unqualified data_source=
            seg = last_segment(table)
            seg_re = re.compile(rf"\b{re.escape(seg)}\.data_source\s*=\s*'([^']*)'", re.IGNORECASE)
            literals = set(seg_re.findall(sql)) | unq_literals
            who = f"{table}（无别名）"
        else:
            eq_re = re.compile(rf"\b{re.escape(alias)}\.data_source\s*=\s*'([^']*)'", re.IGNORECASE)
            literals = set(eq_re.findall(sql))
            who = f"{table}（别名 {alias}）"

        if not literals:
            ref = f"{alias}.data_source" if alias else "data_source"
            fails.append(
                f"B1 {path.name}: 引用规则表 {who} 缺源隔离谓词 "
                f"`{ref} = '<source>'`；其他源规则会越界顶替、掩盖缺规则"
            )
            continue
        if expect_source and expect_source not in literals:
            fails.append(
                f"B2 {path.name}: {who} 的 data_source 过滤为 {sorted(literals)}，"
                f"期望 '{expect_source}'（单源 build 必须只放行本源规则）"
            )
    return fails


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--build-sql", action="append", type=Path, default=[], metavar="FILE",
                    help="待检的 build SQL 文件，可重复")
    ap.add_argument("--expect-source", help="单源 build 期望的 data_source 字面值，如 digikey")
    args = ap.parse_args()

    if not args.build_sql:
        print("ERROR: 至少提供一个 --build-sql", file=sys.stderr)
        sys.exit(2)

    all_fails: list[str] = []
    checked = 0
    for p in args.build_sql:
        if not p.exists():
            print(f"ERROR: 文件不存在: {p}", file=sys.stderr)
            sys.exit(2)
        checked += 1
        all_fails.extend(lint_file(p, args.expect_source))

    for f in all_fails:
        print(f"FAIL  {f}")

    if all_fails:
        print(f"\nbuild SQL 源隔离校验未通过：{len(all_fails)} 个 FAIL（检查 {checked} 个文件）")
        sys.exit(1)
    print(f"build SQL 源隔离校验通过：{checked} 个文件，所有规则表 join 均带 data_source 隔离"
          + (f"（= '{args.expect_source}'）" if args.expect_source else ""))
    sys.exit(0)


if __name__ == "__main__":
    main()
