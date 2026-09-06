#!/usr/bin/env python3
"""Root cause: why icpdf inductor baseline 28520 vs merge 17948 (diff 10572)."""
from pathlib import Path
import pymysql

env = {}
for line in Path("sql_scripts/local.env").read_text(encoding="utf-8").splitlines():
    if line.strip().startswith("export "):
        k, v = line[7:].split("=", 1)
        env[k] = v.strip("'")

conn = pymysql.connect(
    host=env["MYSQL_HOST"], port=int(env["MYSQL_PORT"]),
    user=env["MYSQL_USER"], password=env["MYSQL_PASSWORD"], charset="utf8mb4",
)
cur = conn.cursor()

def run(title, sql, limit=15):
    print(f"\n=== {title} ===")
    cur.execute(sql)
    rows = cur.fetchall()
    for r in rows[:limit]:
        print(r)
    if len(rows) > limit:
        print(f"... +{len(rows)-limit} rows")
    return rows

# 只在旧基线、不在 merge 的 icpdf inductor 行
run("only_baseline count", """
SELECT COUNT(*) FROM test_dwd.dwd_component_class_inductor b
WHERE b.data_source='icpdf' AND b.l1_code='inductor'
AND NOT EXISTS (
  SELECT 1 FROM test_dwd.dwd_component_class_merge_inductor m
  WHERE m.data_source=b.data_source AND m.id=b.id AND m.l1_code='inductor'
)
""")

# 这些 id 在 merge 里是否存在（任意 l1）？
run("baseline-only: in merge as other l1?", """
SELECT COALESCE(m.l1_code,'(none)') l1, COUNT(*) c
FROM test_dwd.dwd_component_class_inductor b
LEFT JOIN test_dwd.dwd_component_class_merge_inductor m
  ON m.data_source=b.data_source AND m.id=b.id
WHERE b.data_source='icpdf' AND b.l1_code='inductor'
AND NOT EXISTS (
  SELECT 1 FROM test_dwd.dwd_component_class_merge_inductor m2
  WHERE m2.data_source=b.data_source AND m2.id=b.id AND m2.l1_code='inductor'
)
GROUP BY 1 ORDER BY c DESC
""")

# 只在 merge、不在 baseline
run("only_merge count", """
SELECT COUNT(*) FROM test_dwd.dwd_component_class_merge_inductor m
WHERE m.data_source='icpdf' AND m.l1_code='inductor'
AND NOT EXISTS (
  SELECT 1 FROM test_dwd.dwd_component_class_inductor b
  WHERE b.data_source=b.data_source AND b.id=m.id AND b.l1_code='inductor'
)
""")

# 同 id 两边都是 inductor 但 l3 不同
run("same id different l3 count", """
SELECT COUNT(*) FROM test_dwd.dwd_component_class_inductor b
JOIN test_dwd.dwd_component_class_merge_inductor m
  ON b.data_source=m.data_source AND b.id=m.id
WHERE b.l1_code='inductor' AND m.l1_code='inductor'
  AND b.data_source='icpdf' AND b.l3_code <> m.l3_code
""")

run("l3 remap top", """
SELECT b.l3_code old_l3, m.l3_code new_l3, COUNT(*) c
FROM test_dwd.dwd_component_class_inductor b
JOIN test_dwd.dwd_component_class_merge_inductor m
  ON b.data_source=m.data_source AND b.id=m.id
WHERE b.l1_code='inductor' AND m.l1_code='inductor'
  AND b.data_source='icpdf' AND b.l3_code <> m.l3_code
GROUP BY 1,2 ORDER BY c DESC LIMIT 12
""")

# baseline-only 行的 category 分布（join param）
run("baseline-only category top", """
SELECT p.category, COUNT(*) c
FROM test_dwd.dwd_component_class_inductor b
JOIN dwd.dwd_icpdf_component_param p ON p.id = b.id
WHERE b.data_source='icpdf' AND b.l1_code='inductor'
AND NOT EXISTS (
  SELECT 1 FROM test_dwd.dwd_component_class_merge_inductor m
  WHERE m.data_source=b.data_source AND m.id=b.id AND m.l1_code='inductor'
)
GROUP BY 1 ORDER BY c DESC LIMIT 12
""")

run("baseline-only category2 top", """
SELECT p.category2, COUNT(*) c
FROM test_dwd.dwd_component_class_inductor b
JOIN dwd.dwd_icpdf_component_param p ON p.id = b.id
WHERE b.data_source='icpdf' AND b.l1_code='inductor'
AND NOT EXISTS (
  SELECT 1 FROM test_dwd.dwd_component_class_merge_inductor m
  WHERE m.data_source=b.data_source AND m.id=b.id AND m.l1_code='inductor'
)
GROUP BY 1 ORDER BY c DESC LIMIT 12
""")

# baseline-only 旧 l3 分布
run("baseline-only old l3 top", """
SELECT b.l3_code, COUNT(*) c
FROM test_dwd.dwd_component_class_inductor b
WHERE b.data_source='icpdf' AND b.l1_code='inductor'
AND NOT EXISTS (
  SELECT 1 FROM test_dwd.dwd_component_class_merge_inductor m
  WHERE m.data_source=b.data_source AND m.id=b.id AND m.l1_code='inductor'
)
GROUP BY 1 ORDER BY c DESC LIMIT 12
""")

# 这些 id 在 prod 全表 merge 后是否完全未分类
run("baseline-only: absent from prod class entirely?", """
SELECT
  SUM(CASE WHEN p.id IS NULL THEN 1 ELSE 0 END) not_in_prod_at_all,
  SUM(CASE WHEN p.l1_code IS NOT NULL AND p.l1_code <> 'inductor' THEN 1 ELSE 0 END) prod_other_l1,
  SUM(CASE WHEN p.l1_code = 'inductor' THEN 1 ELSE 0 END) prod_inductor
FROM test_dwd.dwd_component_class_inductor b
LEFT JOIN dwd.dwd_component_class p
  ON p.data_source=b.data_source AND p.id=b.id
WHERE b.data_source='icpdf' AND b.l1_code='inductor'
AND NOT EXISTS (
  SELECT 1 FROM test_dwd.dwd_component_class_merge_inductor m
  WHERE m.data_source=b.data_source AND m.id=b.id AND m.l1_code='inductor'
)
""")

conn.close()
