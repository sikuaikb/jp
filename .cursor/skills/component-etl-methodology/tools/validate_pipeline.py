#!/usr/bin/env python3
"""元器件清洗全链路 dim/DDL 机械校验统一入口（component-etl-methodology）。

把三个分层校验器串成一次 fail-fast 调用：
    1) 分类层    validate_classify_dim.py     —— 分类树 + 分类规则 dim
    2) 属性层    validate_attr_dim.py          —— schema + extract_rule + unit_factor dim
    3) 宽表层    validate_l2_widetable.py        —— L2 宽表 DDL 对齐电阻基准

每一层"仅在其必需输入被提供时"才运行；未提供的层自动跳过（INFO 标注）。
任意一层 FAIL 则本工具退出码为 1，适合直接放进沙盒 run_test.sh 的 step 0（set -e）。

用法（按需提供分层入参，给齐即全跑）：
    python3 validate_pipeline.py \
        --expect-l1 capacitor \
        --dim-schema test_dim --dim-l1-suffix capacitor \
        --widetable-ddl     .../dwd_l2_a.sql .../dwd_l2_b.sql \
    # 或历史 CSV 路径（非沙盒常规路径）
        [--widetable-ddl-dir .../2.attribute_standard]  # 批量扫 dwd_l2_*.sql
        [--l2               fixed_resistor]   # 单表时启用宽表 W7/W9 深度对账
"""
from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent


def run(label: str, argv: list[str]) -> tuple[str, int]:
    print(f"\n{'='*68}\n[{label}] $ {' '.join(str(a) for a in argv)}\n{'='*68}")
    proc = subprocess.run([sys.executable, *argv])
    return label, proc.returncode


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--expect-l1")
    ap.add_argument("--l1", help="属性/宽表层的 l1 过滤；缺省时复用 --expect-l1")
    ap.add_argument("--l2")
    # 分类层
    ap.add_argument("--dim-schema", help="连库校验分类/属性 dim（与 --dim-l1-suffix 合用）")
    ap.add_argument("--dim-l1-suffix", help="表后缀，如 capacitor → dim_l3_classify_capacitor")
    ap.add_argument("--classify-csv", type=Path)
    ap.add_argument("--classify-rule-csv", type=Path)
    ap.add_argument("--taxonomy", type=Path)
    # 属性层
    ap.add_argument("--attr-schema-csv", type=Path)
    ap.add_argument("--attr-rule-csv", type=Path)
    ap.add_argument("--unit-csv", type=Path)
    # 宽表层
    ap.add_argument("--widetable-ddl", nargs="+", type=Path)
    ap.add_argument("--widetable-ddl-dir", type=Path, help="批量扫描目录下 dwd_l2_*.sql")
    args = ap.parse_args()

    l1 = args.l1 or args.expect_l1
    results: list[tuple[str, int]] = []
    skipped: list[str] = []

    use_db = bool(args.dim_schema and args.dim_l1_suffix)

    # 1) 分类层
    if use_db or (args.classify_csv and args.classify_rule_csv):
        argv = [str(HERE / "validate_classify_dim.py")]
        if use_db:
            suf = args.dim_l1_suffix
            argv += [
                "--dim-schema", args.dim_schema,
                "--classify-table", f"dim_l3_classify_{suf}",
                "--rule-table", f"dim_l3_classify_rule_{suf}",
            ]
        else:
            argv += [
                "--classify-csv", str(args.classify_csv),
                "--rule-csv", str(args.classify_rule_csv),
            ]
        if args.taxonomy:
            argv += ["--taxonomy", str(args.taxonomy)]
        if args.expect_l1:
            argv += ["--expect-l1", args.expect_l1]
        results.append(run("classify", argv))
    else:
        skipped.append("classify（缺 --dim-schema+--dim-l1-suffix 或 CSV）")

    # 2) 属性层
    if use_db or (args.attr_schema_csv and args.attr_rule_csv and args.unit_csv):
        argv = [str(HERE / "validate_attr_dim.py")]
        if use_db:
            suf = args.dim_l1_suffix
            argv += [
                "--dim-schema", args.dim_schema,
                "--schema-table", f"dim_attr_schema_{suf}",
                "--rule-table", f"dim_attr_extract_rule_{suf}",
                "--unit-table", "dim_unit_factor",
            ]
        else:
            argv += [
                "--schema-csv", str(args.attr_schema_csv),
                "--rule-csv", str(args.attr_rule_csv),
                "--unit-csv", str(args.unit_csv),
            ]
        if l1:
            argv += ["--l1", l1]
        results.append(run("attr", argv))
    else:
        skipped.append("attr（缺 --dim-schema+--dim-l1-suffix 或 CSV）")

    # 3) 宽表层
    widetable_ddls: list[Path] = list(args.widetable_ddl or [])
    if args.widetable_ddl_dir:
        widetable_ddls.extend(sorted(args.widetable_ddl_dir.glob("dwd_l2_*.sql")))
    if widetable_ddls:
        argv = [str(HERE / "validate_l2_widetable.py"), "--ddl", *[str(p) for p in widetable_ddls]]
        # 单表 + 给齐 l1/l2 时启用深度对账（多表时 validate_l2 从 DDL 注释逐文件推断）
        schema_csv = args.attr_schema_csv
        if use_db and l1:
            # 宽表 W7 对账仍需 schema CSV；连库模式跳过深度对账（由 validate_dwd_data 兜底）
            pass
        elif schema_csv and l1 and args.l2 and len(widetable_ddls) == 1:
            argv += ["--schema-csv", str(schema_csv), "--l1", l1, "--l2", args.l2]
        elif schema_csv and len(widetable_ddls) > 1:
            argv += ["--schema-csv", str(schema_csv)]
        results.append(run("widetable", argv))
    else:
        skipped.append("widetable（缺 --widetable-ddl / --widetable-ddl-dir）")

    print(f"\n{'#'*68}\n# 全链路校验汇总\n{'#'*68}")
    for s in skipped:
        print(f"SKIP  {s}")
    any_fail = False
    for label, rc in results:
        status = "PASS" if rc == 0 else "FAIL"
        any_fail = any_fail or rc != 0
        print(f"{status}  {label}")
    if not results:
        print("（未提供任何分层输入；无事可做）")
    sys.exit(1 if any_fail else 0)


if __name__ == "__main__":
    main()
