#!/usr/bin/env python3
"""switch test 全链路审计（分类 + dim + EAV + L2 + 品牌），不写 prod。"""
from __future__ import annotations

import json
import os
import subprocess
import sys
from datetime import datetime
from pathlib import Path

import pymysql

sys.stdout.reconfigure(encoding="utf-8")

HERE = Path(__file__).resolve().parents[1]
AUDIT = HERE / "audit"
ART = HERE / "artifacts" / "switch"
ENV = HERE.parents[1] / "local.env"
OUT = ART / "full_audit_report.txt"

KEY_L2_ATTRS = (
    "manufacturer", "mpn", "lifecycle_status", "rohs_compliant", "package_case",
    "temp_min_c", "temp_max_c", "rated_voltage_v", "rated_current_a",
    "circuit_type", "mounting_type", "electrical_life_cycles",
)
L2_TABLES = (
    "mechanical_actuated_switch",
    "mechanical_sensing_switch",
    "magnetic_sensing_switch",
)


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


def section(lines: list[str], title: str) -> None:
    lines.append("")
    lines.append("=" * 80)
    lines.append(title)
    lines.append("=" * 80)


def audit_dim_rules(cur, lines: list[str]) -> bool:
    section(lines, "一、test_dim 规则装载")
    ok = True
    cur.execute(
        """
        SELECT data_source, rule_kind, COUNT(*) c, COUNT(DISTINCT rule_id) rules
        FROM test_dim.dim_l3_classify_rule_switch
        GROUP BY data_source, rule_kind ORDER BY 1, 2
        """
    )
    for r in cur.fetchall():
        lines.append(f"  classify_rule  {r['data_source']:<8} {r['rule_kind']:<10} rows={r['c']} rules={r['rules']}")
    cur.execute("SELECT COUNT(*) n FROM test_dim.dim_attr_schema_switch")
    lines.append(f"  attr_schema    rows={cur.fetchone()['n']}")
    cur.execute("SELECT COUNT(*) n FROM test_dim.dim_attr_extract_rule_switch")
    lines.append(f"  extract_rule   rows={cur.fetchone()['n']}")
    cur.execute(
        """
        SELECT data_source, COUNT(*) n FROM test_dim.dim_attr_extract_rule_switch
        GROUP BY data_source
        """
    )
    for r in cur.fetchall():
        lines.append(f"    - {r['data_source']}: {r['n']}")
    cur.execute(
        """
        SELECT COUNT(*) n FROM test_dim.dim_attr_extract_rule_switch
        WHERE extract_rule_id NOT REGEXP '^switch_'
        """
    )
    bad_prefix = cur.fetchone()["n"]
    cur.execute(
        """
        SELECT extract_rule_id, COUNT(*) c FROM test_dim.dim_attr_extract_rule_switch
        GROUP BY extract_rule_id HAVING COUNT(*)>1
        """
    )
    dup = cur.fetchall()
    cur.execute("SELECT COUNT(*) n FROM test_dim.dim_attr_extract_rule_switch")
    rule_total = cur.fetchone()["n"]
    if bad_prefix:
        ok = False
        lines.append(f"  [FAIL] extract_rule_id 非 switch_ 前缀: {bad_prefix} 条")
    else:
        lines.append(f"  [PASS] extract_rule_id 全部匹配 ^switch_ ({rule_total} 条)")
    if dup:
        ok = False
        lines.append(f"  [FAIL] extract_rule_id 重复: {len(dup)} 组")
    else:
        lines.append("  [PASS] extract_rule_id PK 无重复")
    cur.execute("SELECT COUNT(*) n FROM test_dim.dim_std_brand")
    brand_n = cur.fetchone()["n"]
    cur.execute("SELECT COUNT(*) n FROM test_dim.v_std_brand_alias")
    alias_n = cur.fetchone()["n"]
    lines.append(f"  brand dict     dim_std_brand={brand_n}  v_std_brand_alias={alias_n}")
    return ok


def audit_classify(cur, lines: list[str]) -> bool:
    section(lines, "二、ICPDF 分类")
    ok = True
    cur.execute(
        """
        SELECT COUNT(*) n,
               SUM(CASE WHEN l3_code LIKE '%unclassified%' OR l3_code IS NULL THEN 1 ELSE 0 END) uncls
        FROM test_dwd.dwd_component_class_switch WHERE data_source='icpdf'
        """
    )
    r = cur.fetchone()
    lines.append(f"  总量: {r['n']:,}  未分类: {r['uncls']:,}")
    if r["uncls"] > 0:
        ok = False
        lines.append("  [FAIL] 存在未分类 SKU")
    else:
        lines.append("  [PASS] 未分类 = 0")

    cur.execute(
        """
        SELECT l3_code, COUNT(*) n FROM test_dwd.dwd_component_class_switch
        WHERE data_source='icpdf' GROUP BY l3_code ORDER BY n DESC
        """
    )
    lines.append("  L3 分布:")
    for row in cur.fetchall():
        lines.append(f"    {row['l3_code']:<32} {row['n']:>8,}")

    cur.execute(
        """
        SELECT COUNT(DISTINCT p.id) gate_n
        FROM dwd.dwd_icpdf_component_param p
        WHERE p.category2 IN (
            '按钮开关','旋转开关','快动/限位开关','拨动开关','翘板开关',
            '拨码开关','小键盘开关','滑动开关','键锁开关','指轮/按动滚轮开关','磁簧开关'
        ) OR p.category IN (
            '轻触开关、轻推开关','基础型/快动型/限制型','DIP/SIP','滑块开关',
            '按钮开关','拨动开关','旋转开关'
        )
        """
    )
    gate_n = cur.fetchone()["gate_n"]
    class_n = r["n"]
    lines.append(f"  Gate 内 param 总量: {gate_n:,}  已分类: {class_n:,}  覆盖率: {100*class_n/gate_n:.1f}%")
    return ok


def audit_eav(cur, lines: list[str]) -> bool:
    section(lines, "三、ICPDF 属性 EAV")
    ok = True
    cur.execute(
        """
        SELECT COUNT(DISTINCT c.id) class_n, COUNT(DISTINCT e.id) eav_n
        FROM test_dwd.dwd_component_class_switch c
        LEFT JOIN test_dwd.dwd_component_attr_std_switch e
          ON e.id=c.id AND e.data_source=c.data_source
        WHERE c.data_source='icpdf'
        """
    )
    r = cur.fetchone()
    pct = 100.0 * r["eav_n"] / r["class_n"] if r["class_n"] else 0
    lines.append(f"  分类 SKU: {r['class_n']:,}  有 EAV: {r['eav_n']:,}  ({pct:.1f}%)")
    if pct < 95:
        ok = False
        lines.append("  [WARN] EAV 覆盖 < 95%")
    else:
        lines.append("  [PASS] EAV 覆盖 ≥ 95%")

    cur.execute(
        """
        SELECT COUNT(*) rows_cnt, COUNT(DISTINCT id) ids
        FROM test_dwd.dwd_component_attr_std_switch WHERE data_source='icpdf'
        """
    )
    r2 = cur.fetchone()
    lines.append(f"  EAV 行数: {r2['rows_cnt']:,}  平均 {r2['rows_cnt']/r2['ids']:.1f} 行/SKU")

    lines.append("  L2 关键属性命中 (icpdf):")
    cur.execute(
        f"""
        SELECT std_attr_code, COUNT(DISTINCT id) filled
        FROM test_dwd.dwd_component_attr_std_switch
        WHERE data_source='icpdf'
          AND (value_std_double IS NOT NULL
               OR (value_std_varchar IS NOT NULL AND trim(value_std_varchar)<>''))
          AND std_attr_code IN ({','.join(repr(x) for x in KEY_L2_ATTRS)})
        GROUP BY std_attr_code
        """
    )
    filled = {r["std_attr_code"]: r["filled"] for r in cur.fetchall()}
    class_n = r["class_n"]
    for code in KEY_L2_ATTRS:
        n = filled.get(code, 0)
        cov = 100.0 * n / class_n if class_n else 0
        flag = "PASS" if cov >= 30 else ("WARN" if cov >= 5 else "FAIL")
        if cov < 30 and code in ("rohs_compliant", "temp_min_c", "temp_max_c", "mounting_type"):
            ok = False
        lines.append(f"    [{flag:4}] {code:<28} {n:>8,}  ({cov:.1f}%)")
    return ok


def audit_l3_summary(cur, lines: list[str]) -> bool:
    section(lines, "四、L3 属性审计摘要")
    ok = True
    cur.execute(
        """
        SELECT c.l3_code, COUNT(DISTINCT c.id) sku,
               COUNT(DISTINCT e.id) eav_ids
        FROM test_dwd.dwd_component_class_switch c
        LEFT JOIN test_dwd.dwd_component_attr_std_switch e
          ON e.id=c.id AND e.data_source=c.data_source
        WHERE c.data_source='icpdf'
        GROUP BY c.l3_code ORDER BY sku DESC
        """
    )
    lines.append(f"  {'L3':<28} {'SKU':>8} {'EAV%':>7} 判定")
    lines.append("  " + "-" * 60)
    fail_l3 = []
    for row in cur.fetchall():
        pct = 100.0 * row["eav_ids"] / row["sku"] if row["sku"] else 0
        if pct >= 95:
            verdict = "PASS" if pct >= 99 else "WARN"
        elif pct >= 50:
            verdict = "FAIL"
            fail_l3.append(row["l3_code"])
        else:
            verdict = "FAIL"
            fail_l3.append(row["l3_code"])
        lines.append(f"  {row['l3_code']:<28} {row['sku']:>8,} {pct:>6.1f}%  {verdict}")
    if fail_l3:
        ok = False
        lines.append(f"  [FAIL L3] {', '.join(fail_l3)}")
    lines.append("  详情: python audit/audit_attr_by_l3.py --data-source icpdf")
    return ok


def audit_l2_brand(cur, lines: list[str]) -> bool:
    section(lines, "五、L2 宽表 + 品牌")
    ok = True
    for l2 in L2_TABLES:
        tbl = f"test_dwd.dwd_l2_switch_{l2}"
        try:
            cur.execute(f"SELECT COUNT(*) n FROM {tbl} WHERE data_source='icpdf'")
            n = cur.fetchone()["n"]
        except Exception as e:
            lines.append(f"  [SKIP] {l2}: 表不存在 ({e})")
            ok = False
            continue
        cur.execute(
            f"""
            SELECT
                SUM(CASE WHEN brand IS NULL OR TRIM(brand)='' THEN 1 ELSE 0 END) brand_null,
                SUM(CASE WHEN brand IS NOT NULL AND TRIM(brand)<>'' AND brandid IS NULL THEN 1 ELSE 0 END) dict_gap,
                SUM(CASE WHEN manufacturer IS NOT NULL AND TRIM(manufacturer)<>'' THEN 1 ELSE 0 END) mfr,
                SUM(CASE WHEN temp_min_c IS NOT NULL THEN 1 ELSE 0 END) tmin
            FROM {tbl} WHERE data_source='icpdf'
            """
        )
        s = cur.fetchone()
        flag = "PASS" if s["brand_null"] == 0 and s["dict_gap"] == 0 else "FAIL"
        if flag == "FAIL":
            ok = False
        lines.append(
            f"  [{flag}] {l2}: rows={n:,} brand_null={s['brand_null']} "
            f"dict_gap={s['dict_gap']} mfr={s['mfr']:,} tmin={s['tmin']:,}"
        )

    cur.execute(
        """
        SELECT p.brandshort, COUNT(DISTINCT c.id) rows_
        FROM test_dwd.dwd_component_class_switch c
        JOIN dwd.dwd_icpdf_component_param p ON p.id=c.id
        LEFT JOIN test_dim.v_std_brand_alias a ON a.brand_key=UPPER(TRIM(p.brandshort))
        WHERE c.data_source='icpdf'
          AND NULLIF(TRIM(p.brandshort),'') IS NOT NULL
          AND a.brand_id_std IS NULL
        GROUP BY p.brandshort ORDER BY rows_ DESC LIMIT 5
        """
    )
    unmapped = cur.fetchall()
    if unmapped:
        ok = False
        lines.append("  [FAIL] 未映射 brandshort (Top5):")
        for u in unmapped:
            lines.append(f"    {u['rows_']:>6,}  {u['brandshort']}")
    else:
        lines.append("  [PASS] brandshort alias 100% 映射")
    return ok


def main() -> int:
    load_env()
    ART.mkdir(parents=True, exist_ok=True)
    lines: list[str] = [
        f"# switch test 全链路审计",
        f"# 时间: {datetime.now().isoformat(timespec='seconds')}",
        f"# 范围: test_dim / test_dwd only，不涉及 prod merge",
    ]

    conn = connect()
    cur = conn.cursor()
    cur.execute("SET enable_local_shuffle_agg=false")

    results = [
        audit_dim_rules(cur, lines),
        audit_classify(cur, lines),
        audit_eav(cur, lines),
        audit_l3_summary(cur, lines),
        audit_l2_brand(cur, lines),
    ]
    conn.close()

    section(lines, "六、子脚本输出（可选详审）")
    lines.append("  python audit/verify_test_dim_rules.py")
    lines.append("  python audit/audit_classify_quality.py")
    lines.append("  python audit/audit_attr_by_l3.py --data-source icpdf")
    lines.append("  python audit/brand_scan_switch.py")

    section(lines, "总结")
    if all(results):
        lines.append("  总体: PASS（test 阶段可进入 merge 评审准备，本次不执行 merge）")
        code = 0
    else:
        lines.append("  总体: WARN/FAIL — 见上文 [FAIL]/[WARN] 项；多为 L3 专规或源数据缺口")
        code = 1

    text = "\n".join(lines) + "\n"
    OUT.write_text(text, encoding="utf-8")
    print(text)
    print(f"报告已写入: {OUT}")
    return code


if __name__ == "__main__":
    raise SystemExit(main())
