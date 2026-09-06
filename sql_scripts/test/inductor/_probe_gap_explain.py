#!/usr/bin/env python3
"""拆解 classify vs L2 缺口：品牌未映射 / 空 brandshort / excluded 等"""
from pathlib import Path
import os
import pymysql

L1 = "inductor"
L2S = ["power_inductor", "hf_chip_inductor", "emi_filter_inductor"]

for line in Path("sql_scripts/local.env").read_text(encoding="utf-8").splitlines():
    if line.strip().startswith("export "):
        k, _, v = line[7:].partition("=")
        os.environ[k] = v.strip().strip("'\"")

conn = pymysql.connect(
    host=os.environ["MYSQL_HOST"], port=int(os.environ["MYSQL_PORT"]),
    user=os.environ["MYSQL_USER"], password=os.environ["MYSQL_PASSWORD"],
    charset="utf8mb4", cursorclass=pymysql.cursors.DictCursor,
)
cur = conn.cursor()

# classify 总数（用子查询避免 StarRocks 分片 GROUP BY 假象）
cur.execute(f"""
SELECT data_source, COUNT(DISTINCT id) n
FROM dwd.dwd_component_class
WHERE l1_code='{L1}'
GROUP BY data_source
""")
cls = {r["data_source"]: r["n"] for r in cur.fetchall()}
print("=== prod classify (inductor) ===")
print(cls, "total=", sum(cls.values()))

cur.execute(f"""
SELECT data_source, COUNT(DISTINCT id) n
FROM dwd.dwd_component_class
WHERE l1_code='{L1}' AND l2_code IN ({",".join(repr(x) for x in L2S)})
GROUP BY data_source
""")
cls_l2 = {r["data_source"]: r["n"] for r in cur.fetchall()}
print("classify in 3 L2 codes:", cls_l2, "total=", sum(cls_l2.values()))

# L2 实际行数
l2_tot = {}
for l2 in L2S:
    cur.execute(f"SELECT data_source, COUNT(DISTINCT id) n FROM dwd.dwd_l2_{L1}_{l2} GROUP BY data_source")
    for r in cur.fetchall():
        l2_tot[r["data_source"]] = l2_tot.get(r["data_source"], 0) + r["n"]
print("\n=== prod L2 合计 ===")
print(l2_tot, "total=", sum(l2_tot.values()))
print("gap vs classify:", {ds: cls.get(ds, 0) - l2_tot.get(ds, 0) for ds in set(cls) | set(l2_tot)})

# 对 classify 行做品牌门控分解（3 张 L2 合并口径）
sql = f"""
WITH src_param AS (
    SELECT 'icpdf' AS data_source, id, brandshort FROM dwd.dwd_icpdf_component_param
    UNION ALL
    SELECT 'digikey', id, brandshort FROM dwd.dwd_digikey_component_param
),
base AS (
    SELECT c.data_source, c.id, c.l2_code, c.l3_code, p.brandshort,
           a.brand_id_std, a.canonical_name
    FROM dwd.dwd_component_class c
    JOIN src_param p ON p.data_source = c.data_source AND p.id = c.id
    LEFT JOIN dim.v_std_brand_alias a ON a.brand_key = UPPER(TRIM(p.brandshort))
    WHERE c.l1_code = '{L1}'
      AND c.l2_code IN ({",".join(repr(x) for x in L2S)})
)
SELECT data_source,
    COUNT(DISTINCT id) AS classify_in_l2,
    COUNT(DISTINCT CASE WHEN l3_code LIKE 'excluded%' THEN id END) AS excluded_l3,
    COUNT(DISTINCT CASE WHEN NULLIF(TRIM(COALESCE(brandshort,'')),'') IS NULL THEN id END) AS empty_brandshort,
    COUNT(DISTINCT CASE WHEN NULLIF(TRIM(COALESCE(brandshort,'')),'') IS NOT NULL
                         AND brand_id_std IS NULL THEN id END) AS unmapped_brand,
    COUNT(DISTINCT CASE WHEN NULLIF(TRIM(COALESCE(brandshort,'')),'') IS NOT NULL
                         AND l3_code NOT LIKE 'excluded%'
                         AND brand_id_std IS NOT NULL THEN id END) AS would_pass_l2_gate
FROM base
GROUP BY data_source
"""
cur.execute(sql)
print("\n=== classify 行品牌门控分解（3 L2 范围内）===")
for r in cur.fetchall():
    print(r)

# 未映射品牌 Top（digikey 为主）
cur.execute(f"""
WITH src_param AS (
    SELECT 'icpdf' AS data_source, id, brandshort FROM dwd.dwd_icpdf_component_param
    UNION ALL
    SELECT 'digikey', id, brandshort FROM dwd.dwd_digikey_component_param
)
SELECT p.brandshort, c.data_source, COUNT(DISTINCT c.id) n
FROM dwd.dwd_component_class c
JOIN src_param p ON p.data_source = c.data_source AND p.id = c.id
LEFT JOIN dim.v_std_brand_alias a ON a.brand_key = UPPER(TRIM(p.brandshort))
WHERE c.l1_code = '{L1}'
  AND c.l2_code IN ({",".join(repr(x) for x in L2S)})
  AND c.l3_code NOT LIKE 'excluded%'
  AND NULLIF(TRIM(COALESCE(p.brandshort,'')),'') IS NOT NULL
  AND a.brand_id_std IS NULL
GROUP BY 1, 2
ORDER BY n DESC
LIMIT 15
""")
print("\n=== 未映射品牌 Top 15 ===")
for r in cur.fetchall():
    print(r)

# 对比 icpdf 10,572 口径
print("\n=== 10,572 口径（与 L2 无关）===")
print("阶段1 test_dwd.dwd_component_class_inductor icpdf: 28,520")
print("prod classify icpdf (主干引擎): 17,948")
print("差值: 28,520 - 17,948 = 10,572")
cur.execute("""
SELECT COUNT(DISTINCT id) FROM test_dwd.dwd_component_class_inductor
WHERE l1_code='inductor' AND data_source='icpdf'
""")
test_icpdf = cur.fetchone()
key = list(test_icpdf.keys())[0]
print(f"当前 test 后缀表 icpdf 仍存: {test_icpdf[key]}")

conn.close()
