#!/usr/bin/env python3
"""ICPDF switch 分类质量审计（test_dwd.dwd_component_class_switch）。"""
from __future__ import annotations

import os
import sys
from pathlib import Path

import pymysql

sys.stdout.reconfigure(encoding="utf-8")

HERE = Path(__file__).resolve().parents[1]
ENV = HERE.parents[1] / "local.env"

GATE_C2 = [
    "按钮开关", "旋转开关", "快动/限位开关", "拨动开关", "翘板开关",
    "拨码开关", "小键盘开关", "滑动开关", "键锁开关", "指轮/按动滚轮开关", "磁簧开关",
]
GATE_C = [
    "轻触开关、轻推开关", "基础型/快动型/限制型", "DIP/SIP", "滑块开关",
    "按钮开关", "拨动开关", "旋转开关",
]
DEFERRED_L3 = {
    "150302": "hall_effect_switch",
    "150203": "interlock_safety_switch",
    "150110": "navigation_joystick_switch",
}
EXPECTED_L3 = {
    "150101", "150102", "150103", "150104", "150105", "150106", "150107",
    "150108", "150109", "150111", "150201", "150202", "150301",
}


def load_env() -> None:
    for line in ENV.read_text(encoding="utf-8").splitlines():
        if line.strip().startswith("export "):
            k, _, v = line[7:].partition("=")
            os.environ[k] = v.strip().strip("'").strip('"')


def gate_sql(alias: str = "p") -> str:
    c2 = ",".join(f"'{x}'" for x in GATE_C2)
    c = ",".join(f"'{x}'" for x in GATE_C)
    return f"({alias}.category2 IN ({c2}) OR {alias}.category IN ({c}))"


def main() -> int:
    load_env()
    conn = pymysql.connect(
        host=os.environ["MYSQL_HOST"],
        port=int(os.environ.get("MYSQL_PORT", "9030")),
        user=os.environ["MYSQL_USER"],
        password=os.environ["MYSQL_PASSWORD"],
        cursorclass=pymysql.cursors.DictCursor,
    )
    cur = conn.cursor()
    cur.execute("SET enable_local_shuffle_agg = false")

    issues: list[str] = []

    print("=== switch ICPDF 分类审计 ===\n")

    # 1. 重复 PK
    cur.execute(
        """
        SELECT COUNT(*) dup FROM (
            SELECT id FROM test_dwd.dwd_component_class_switch
            WHERE data_source='icpdf' GROUP BY id HAVING COUNT(*) > 1
        ) t
        """
    )
    dup = cur.fetchone()["dup"]
    print(f"1. 重复分类行 (id): {dup}")
    if dup:
        issues.append(f"PK 重复 {dup} 个 id")

    # 2. gate vs classified
    cur.execute(
        f"""
        SELECT COUNT(DISTINCT p.id) n FROM dwd.dwd_icpdf_component_param p
        WHERE {gate_sql('p')}
        """
    )
    gate_n = cur.fetchone()["n"]
    cur.execute(
        """
        SELECT COUNT(DISTINCT id) n FROM test_dwd.dwd_component_class_switch
        WHERE data_source='icpdf'
        """
    )
    cls_n = cur.fetchone()["n"]
    uncls = gate_n - cls_n
    print(f"2. gate={gate_n:,}  classified={cls_n:,}  未分类={uncls:,}")
    if uncls:
        issues.append(f"gate 内未分类 {uncls:,} 行")

    # 3. L3 分布
    print("\n3. L3 分布")
    cur.execute(
        """
        SELECT l3_id, l3_code, l2_code, COUNT(DISTINCT id) n
        FROM test_dwd.dwd_component_class_switch
        WHERE data_source='icpdf'
        GROUP BY l3_id, l3_code, l2_code
        ORDER BY n DESC
        """
    )
    seen_l3: set[str] = set()
    for r in cur.fetchall():
        seen_l3.add(r["l3_id"])
        flag = " [DEFERRED=0]" if r["l3_id"] in DEFERRED_L3 else ""
        print(f"  {r['n']:>8,}  {r['l3_id']} {r['l3_code']:<28}{flag}")
    missing_tax = EXPECTED_L3 - seen_l3
    zero_deferred = [lid for lid in DEFERRED_L3 if lid not in seen_l3]
    if zero_deferred:
        print(f"  deferred L3 无产出（预期）: {', '.join(zero_deferred)}")
    if missing_tax - set(DEFERRED_L3):
        issues.append(f"应有 L3 无产出: {missing_tax - set(DEFERRED_L3)}")

    # 4. rule_id Top
    print("\n4. rule_id 分布（Top 15）")
    cur.execute(
        """
        SELECT rule_id, l3_code, phase, COUNT(DISTINCT id) n
        FROM test_dwd.dwd_component_class_switch
        WHERE data_source='icpdf'
        GROUP BY rule_id, l3_code, phase
        ORDER BY n DESC LIMIT 15
        """
    )
    for r in cur.fetchall():
        fb = " [FB]" if "_fb_" in r["rule_id"] else ""
        print(f"  {r['n']:>8,}  ph={r['phase']}  {r['rule_id']}{fb} -> {r['l3_code']}")

    # 5. fallback 承载
    print("\n5. fallback 规则")
    cur.execute(
        """
        SELECT rule_id, l3_code, COUNT(DISTINCT id) n
        FROM test_dwd.dwd_component_class_switch
        WHERE data_source='icpdf' AND rule_id LIKE '%_fb_%'
        GROUP BY rule_id, l3_code
        """
    )
    fb_total = 0
    for r in cur.fetchall():
        fb_total += r["n"]
        pct = r["n"] / cls_n * 100 if cls_n else 0
        print(f"  {r['n']:>8,} ({pct:4.1f}%)  {r['rule_id']} -> {r['l3_code']}")
    if fb_total / cls_n > 0.25 if cls_n else False:
        issues.append(f"fallback 占比过高 {fb_total/cls_n:.1%}")

    # 6. category2 vs L3（主叶）
    print("\n6. category2 → L3 交叉（非 1:1 叶）")
    cur.execute(
        f"""
        SELECT p.category2, c.l3_code, COUNT(DISTINCT c.id) n
        FROM test_dwd.dwd_component_class_switch c
        JOIN dwd.dwd_icpdf_component_param p ON p.id = c.id
        WHERE c.data_source='icpdf'
          AND p.category2 IN ('快动/限位开关','小键盘开关','DIP/SIP')
        GROUP BY p.category2, c.l3_code
        ORDER BY p.category2, n DESC
        """
    )
    for r in cur.fetchall():
        print(f"  c2={r['category2']:<16} -> {r['l3_code']:<28} {r['n']:>8,}")

    # 7. 边界类目（gate 内可疑）
    print("\n7. 边界类目（gate 内低量 c2/category）")
    cur.execute(
        f"""
        SELECT p.category2, p.category, c.l3_code, c.rule_id, COUNT(DISTINCT c.id) n
        FROM test_dwd.dwd_component_class_switch c
        JOIN dwd.dwd_icpdf_component_param p ON p.id = c.id
        WHERE c.data_source='icpdf'
          AND (p.category2 IN ('特殊开关','其他开关','光学位置编码器')
               OR p.category LIKE '%紧急停止%')
        GROUP BY p.category2, p.category, c.l3_code, c.rule_id
        ORDER BY n DESC
        """
    )
    boundary = cur.fetchall()
    for r in boundary:
        print(
            f"  {r['n']:>4}  c2={r['category2']!r} cat={r['category']!r} "
            f"-> {r['l3_code']} ({r['rule_id']})"
        )
        if r["category2"] == "光学位置编码器" and r["l3_code"] == "rotary_switch":
            issues.append("光学位置编码器 5 行误归 rotary（已知边界）")

    # 8. snap/limit note 专规 vs fallback
    print("\n8. 快动/限位 snap/limit 规则结构")
    cur.execute(
        """
        SELECT rule_id, l3_code, COUNT(DISTINCT id) n
        FROM test_dwd.dwd_component_class_switch
        WHERE data_source='icpdf'
          AND rule_id LIKE 'switch_icpdf_%note%' OR rule_id LIKE 'switch_icpdf_%fb%'
        GROUP BY rule_id, l3_code ORDER BY n DESC
        """
    )
    for r in cur.fetchall():
        print(f"  {r['n']:>8,}  {r['rule_id']} -> {r['l3_code']}")

    # 9. gate 内未分类样本
    if uncls:
        print("\n9. 未分类样本")
        cur.execute(
            f"""
            SELECT p.id, p.category, p.category2, p.note_cn
            FROM dwd.dwd_icpdf_component_param p
            LEFT JOIN test_dwd.dwd_component_class_switch c
              ON c.id = p.id AND c.data_source = 'icpdf'
            WHERE {gate_sql('p')} AND c.id IS NULL
            LIMIT 10
            """
        )
        for r in cur.fetchall():
            print(f"  id={r['id']} c2={r['category2']!r} cat={r['category']!r}")

    # 10. confidence 分布
    print("\n10. confidence 分布")
    cur.execute(
        """
        SELECT phase, ROUND(AVG(confidence), 3) avg_c,
               MIN(confidence) min_c, MAX(confidence) max_c, COUNT(*) n
        FROM test_dwd.dwd_component_class_switch
        WHERE data_source='icpdf'
        GROUP BY phase ORDER BY phase
        """
    )
    for r in cur.fetchall():
        print(f"  phase={r['phase']}  n={r['n']:,}  avg={r['avg_c']}  range=[{r['min_c']},{r['max_c']}]")

    # 11. 单 L3 吞噬检查
    cur.execute(
        """
        SELECT MAX(cnt) mx FROM (
            SELECT COUNT(DISTINCT id) cnt FROM test_dwd.dwd_component_class_switch
            WHERE data_source='icpdf' GROUP BY l3_id
        ) t
        """
    )
    mx = cur.fetchone()["mx"]
    if mx and cls_n and mx / cls_n > 0.5:
        issues.append(f"单一 L3 占比 {mx/cls_n:.1%}（limit 可能偏多）")

    print("\n=== 审计结论 ===")
    if not issues:
        print("  未发现阻断性缺陷；deferred L3 / 边界类目见 CLASSIFY_DESIGN.md。")
    else:
        print("  待关注项：")
        for i, msg in enumerate(issues, 1):
            print(f"  {i}. {msg}")

    conn.close()
    return 1 if (dup or uncls) else 0


if __name__ == "__main__":
    raise SystemExit(main())
