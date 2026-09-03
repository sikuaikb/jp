#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""DigiKey 数据摸底（StarRocks）。结果写入 profile_report.txt"""
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ENV = os.path.join(ROOT, "local.env")
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "profile_report.txt")

for line in open(ENV, encoding="utf-8"):
    line = line.strip()
    if line.startswith("export "):
        k, _, v = line[7:].partition("=")
        os.environ[k] = v.strip().strip("'").strip('"')

import pymysql

conn = pymysql.connect(
    host=os.environ["MYSQL_HOST"],
    port=int(os.environ.get("MYSQL_PORT", "9030")),
    user=os.environ["MYSQL_USER"],
    password=os.environ["MYSQL_PASSWORD"],
    connect_timeout=30,
    cursorclass=pymysql.cursors.DictCursor,
)
cur = conn.cursor()
lines = []


def section(title):
    lines.append("")
    lines.append("=" * 60)
    lines.append(title)
    lines.append("=" * 60)


def run(title, sql):
    section(title)
    try:
        cur.execute(sql)
        rows = cur.fetchall()
    except Exception as e:
        lines.append(f"ERROR: {e}")
        return
    if not rows:
        lines.append("(无结果)")
        return
    cols = list(rows[0].keys())
    lines.append(" | ".join(cols))
    lines.append("-" * 80)
    for r in rows[:50]:
        lines.append(" | ".join(str(r.get(c) if r.get(c) is not None else "")[:60] for c in cols))
    if len(rows) > 50:
        lines.append(f"... 共 {len(rows)} 行")


# 表是否存在
run(
    "0) DigiKey 相关表行数",
    """
    SELECT 'dwd.dwd_digikey_component_param' AS tbl, COUNT(*) AS cnt
    FROM dwd.dwd_digikey_component_param
    UNION ALL
    SELECT 'ods.ods_digikey_component_detail', COUNT(*)
    FROM ods.ods_digikey_component_detail
    UNION ALL
    SELECT 'dwd.dwd_component_class (digikey)', COUNT(*)
    FROM dwd.dwd_component_class WHERE data_source = 'digikey'
    """,
)

run(
    "1) param 字段覆盖率",
    """
    SELECT
      COUNT(*) AS total,
      SUM(CASE WHEN brandshort IS NOT NULL AND brandshort <> '' THEN 1 ELSE 0 END) AS has_brand,
      SUM(CASE WHEN category IS NOT NULL AND category <> '' THEN 1 ELSE 0 END) AS has_category,
      SUM(CASE WHEN category_info IS NOT NULL THEN 1 ELSE 0 END) AS has_category_info,
      SUM(CASE WHEN prajson IS NOT NULL THEN 1 ELSE 0 END) AS has_prajson,
      SUM(CASE WHEN note_cn IS NOT NULL AND note_cn <> '' THEN 1 ELSE 0 END) AS has_note_cn,
      SUM(CASE WHEN datasheet_url IS NOT NULL AND datasheet_url <> '' THEN 1 ELSE 0 END) AS has_datasheet,
      SUM(CASE WHEN image IS NOT NULL AND image <> '' THEN 1 ELSE 0 END) AS has_image
    FROM dwd.dwd_digikey_component_param
    """,
)

run(
    "2) category 叶子分类 Top 30",
    """
    SELECT category, COUNT(*) AS cnt
    FROM dwd.dwd_digikey_component_param
    WHERE category IS NOT NULL AND category <> ''
    GROUP BY category
    ORDER BY cnt DESC
    LIMIT 30
    """,
)

run(
    "3) 滤波器 L1（category_path / category 含「滤波」）",
    """
    SELECT category, COUNT(*) AS cnt
    FROM dwd.dwd_digikey_component_param
    WHERE category LIKE '%滤波%'
       OR (category_info IS NOT NULL AND CAST(category_info AS VARCHAR) LIKE '%滤波%')
    GROUP BY category
    ORDER BY cnt DESC
    LIMIT 40
    """,
)

run(
    "4) classify 已接入 L1 分布（digikey）",
    """
    SELECT l1_code, l2_code, COUNT(*) AS cnt
    FROM dwd.dwd_component_class
    WHERE data_source = 'digikey'
    GROUP BY l1_code, l2_code
    ORDER BY cnt DESC
    LIMIT 30
    """,
)

run(
    "5) classify 按 L1 汇总",
    """
    SELECT l1_code, COUNT(*) AS cnt
    FROM dwd.dwd_component_class
    WHERE data_source = 'digikey'
    GROUP BY l1_code
    ORDER BY cnt DESC
    """,
)

run(
    "6) 电阻试点：fixed_resistor L2 宽表（若有）",
    """
    SELECT COUNT(*) AS cnt
    FROM dwd.dwd_l2_resistor_fixed_resistor
    WHERE data_source = 'digikey'
    """,
)

run(
    "7) gate 未分类：param 有数据但不在 class 表（抽样规模）",
    """
    SELECT COUNT(*) AS param_total,
           COUNT(c.id) AS in_class,
           COUNT(*) - COUNT(c.id) AS not_in_class
    FROM dwd.dwd_digikey_component_param p
    LEFT JOIN dwd.dwd_component_class c
      ON c.data_source = 'digikey' AND c.id = p.id
    """,
)

run(
    "8) 滤波器行：在 class 中的 L1 分布",
    """
    SELECT c.l1_code, c.l2_code, c.l3_code, COUNT(*) AS cnt
    FROM dwd.dwd_digikey_component_param p
    JOIN dwd.dwd_component_class c
      ON c.data_source = 'digikey' AND c.id = p.id
    WHERE p.category LIKE '%滤波%'
    GROUP BY 1, 2, 3
    ORDER BY cnt DESC
    LIMIT 25
    """,
)

run(
    "9) 滤波器行：未进 class 的数量",
    """
    SELECT COUNT(*) AS filter_param,
           SUM(CASE WHEN c.id IS NULL THEN 1 ELSE 0 END) AS filter_not_classified
    FROM dwd.dwd_digikey_component_param p
    LEFT JOIN dwd.dwd_component_class c
      ON c.data_source = 'digikey' AND c.id = p.id
    WHERE p.category LIKE '%滤波%'
    """,
)

run(
    "10) 品牌 Top 15",
    """
    SELECT brandshort, COUNT(*) AS cnt
    FROM dwd.dwd_digikey_component_param
    WHERE brandshort IS NOT NULL AND brandshort <> ''
    GROUP BY brandshort
    ORDER BY cnt DESC
    LIMIT 15
    """,
)

conn.close()

text = "\n".join(lines)
with open(OUT, "w", encoding="utf-8") as f:
    f.write(text)
print(text)
print(f"\n已写入: {OUT}")
