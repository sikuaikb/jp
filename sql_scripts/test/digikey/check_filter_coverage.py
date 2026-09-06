# -*- coding: utf-8 -*-
"""Compare filter SKU counts: CSV export vs DB vs category_info L1 roll-up."""
import csv
import os
import re

import pymysql

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ENV = os.path.join(ROOT, "local.env")
for line in open(ENV, encoding="utf-8"):
    if line.strip().startswith("export "):
        k, _, v = line[7:].partition("=")
        os.environ[k] = v.strip().strip("'").strip('"')

conn = pymysql.connect(
    host=os.environ["MYSQL_HOST"],
    port=int(os.environ.get("MYSQL_PORT", "9030")),
    user=os.environ["MYSQL_USER"],
    password=os.environ["MYSQL_PASSWORD"],
    connect_timeout=30,
)
cur = conn.cursor()
cur.execute("SET query_timeout = 600")

print("=== 1) category.csv：叶子名含「滤波」求和 ===")
leaf_sum = 0
leaf_rows = []
with open(
    os.path.join(
        os.path.dirname(ROOT),
        "exports",
        "digikey",
        "category.csv",
    ),
    encoding="utf-8",
) as f:
    r = csv.DictReader(f)
    for row in r:
        if "滤波" in row["category"]:
            n = int(row["n"])
            leaf_sum += n
            leaf_rows.append((row["category"], n))
for cat, n in sorted(leaf_rows, key=lambda x: -x[1]):
    print(f"  {cat}: {n:,}")
print(f"  合计: {leaf_sum:,}")

print("\n=== 2) category_info.csv：L1=滤波器 路径求和 ===")
l1_sum = 0
paths = []
repo = os.path.dirname(ROOT)
with open(os.path.join(repo, "exports", "digikey", "category_info.csv"), encoding="utf-8") as f:
    r = csv.DictReader(f)
    for row in r:
        if row["category_path"].startswith("滤波器"):
            n = int(row["n"])
            l1_sum += n
            paths.append((row["category_path"], n))
print(f"  L1 路径条数: {len(paths)}")
for p, n in sorted(paths, key=lambda x: -x[1])[:25]:
    print(f"  {p}: {n:,}")
if len(paths) > 25:
    print(f"  ... 另有 {len(paths) - 25} 条")
print(f"  合计: {l1_sum:,}")

print("\n=== 3) DB：dwd param 按 category 含「滤波」 ===")
cur.execute(
    """
    SELECT COUNT(*) FROM dwd.dwd_digikey_component_param
    WHERE category LIKE '%滤波%'
    """
)
print(f"  LIKE '%滤波%': {cur.fetchone()[0]:,}")

print("\n=== 4) DB：category_info[1]='滤波器'（L1 路径）===")
# StarRocks array index - try element_at or [1]
for sql, label in [
    (
        """
        SELECT COUNT(*) FROM dwd.dwd_digikey_component_param
        WHERE category_info IS NOT NULL
          AND element_at(category_info, 1) = '滤波器'
        """,
        "element_at(category_info,1)='滤波器'",
    ),
    (
        """
        SELECT COUNT(*) FROM dwd.dwd_digikey_component_param
        WHERE category_info IS NOT NULL
          AND array_length(category_info) >= 1
          AND CAST(category_info AS VARCHAR) LIKE '["滤波器"%'
        """,
        "CAST LIKE '[\"滤波器\"%'",
    ),
]:
    try:
        cur.execute(sql)
        print(f"  {label}: {cur.fetchone()[0]:,}")
    except Exception as e:
        print(f"  {label}: ERROR {e}")

print("\n=== 5) DB：叶子在 category_info 路径集合内但叶子名不含「滤波」===")
# paths under 滤波器 L1 from csv
l1_leaves = {p.split(" > ")[-1] for p, _ in paths}
placeholders = ",".join(["%s"] * len(l1_leaves))
cur.execute(
    f"""
    SELECT COUNT(*) FROM dwd.dwd_digikey_component_param
    WHERE category IN ({placeholders})
    """,
    list(l1_leaves),
)
print(f"  category IN (滤波器 L1 下 {len(l1_leaves)} 个叶子): {cur.fetchone()[0]:,}")

no_filter_kw = []
for leaf in sorted(l1_leaves):
    if "滤波" not in leaf:
        no_filter_kw.append(leaf)
if no_filter_kw:
    print(f"  其中叶子名不含「滤波」: {len(no_filter_kw)} 个，例如: {no_filter_kw[:8]}")

print("\n=== 6) ODS vs DWD 总量 ===")
cur.execute("SELECT COUNT(*) FROM ods.ods_digikey_component_detail")
ods = cur.fetchone()[0]
cur.execute("SELECT COUNT(*) FROM dwd.dwd_digikey_component_param")
dwd = cur.fetchone()[0]
print(f"  ODS: {ods:,}  DWD param: {dwd:,}  差: {ods - dwd:,}")

conn.close()
