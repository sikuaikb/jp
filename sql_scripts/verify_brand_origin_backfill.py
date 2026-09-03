"""验证产地回写流程：跑 brand_origin_backfill.sql 前后的产地列填充率对比。"""
import os, sys
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '.cursor', 'skills', 'component-etl-methodology', 'tools'))
from dim_db_loader import connect

conn = connect()
cur = conn.cursor()

print("=== 1. dim.dim_brand_origin 行数 ===")
cur.execute("SELECT COUNT(*) FROM dim.dim_brand_origin")
print(f"  {cur.fetchone()[0]} 条")

print("\n=== 2. 回写前 dim.dim_std_brand 产地列填充率 ===")
cur.execute("""
SELECT
  COUNT(*) AS total,
  SUM(CASE WHEN country_region IS NOT NULL THEN 1 ELSE 0 END) AS has_region,
  SUM(CASE WHEN is_domestic IS NOT NULL THEN 1 ELSE 0 END) AS has_domestic,
  SUM(CASE WHEN domestic_type IS NOT NULL THEN 1 ELSE 0 END) AS has_type
FROM dim.dim_std_brand
""")
row = cur.fetchone()
total, hr, hd, ht = row
print(f"  total={total}  has_region={hr} ({hr/total*100:.1f}%)  has_domestic={hd} ({hd/total*100:.1f}%)  has_type={ht} ({ht/total*100:.1f}%)")

print("\n=== 3. 执行 brand_origin_backfill.sql ===")
backfill = os.path.join(os.path.dirname(__file__), "2.attribute_standard", "brand_origin_backfill.sql")
with open(backfill, encoding="utf-8") as f:
    sql = f.read()
cur.execute(sql)
conn.commit()
print("  backfill 已执行")

print("\n=== 4. 回写后 dim.dim_std_brand 产地列填充率 ===")
cur.execute("""
SELECT
  COUNT(*) AS total,
  SUM(CASE WHEN country_region IS NOT NULL THEN 1 ELSE 0 END) AS has_region,
  SUM(CASE WHEN is_domestic IS NOT NULL THEN 1 ELSE 0 END) AS has_domestic,
  SUM(CASE WHEN domestic_type IS NOT NULL THEN 1 ELSE 0 END) AS has_type
FROM dim.dim_std_brand
""")
row = cur.fetchone()
total, hr, hd, ht = row
print(f"  total={total}  has_region={hr} ({hr/total*100:.1f}%)  has_domestic={hd} ({hd/total*100:.1f}%)  has_type={ht} ({ht/total*100:.1f}%)")

print("\n=== 5. 校验回写一致性：dim_std_brand 产地 vs dim_brand_origin ===")
cur.execute("""
SELECT COUNT(*)
FROM dim.dim_std_brand b
INNER JOIN dim.dim_brand_origin o ON o.brand_id_std = b.brand_id_std
WHERE (b.country_region <=> o.country_region) = 0
   OR (b.is_domestic <=> o.is_domestic) = 0
   OR (b.domestic_type <=> o.domestic_type) = 0
""")
mismatch = cur.fetchone()[0]
print(f"  不一致行数: {mismatch} (应为 0)")

print("\n=== 6. 校验其它列未被破坏（抽查 name/source/state） ===")
cur.execute("""
SELECT
  SUM(CASE WHEN name IS NULL THEN 1 ELSE 0 END) AS null_name,
  SUM(CASE WHEN source IS NULL THEN 1 ELSE 0 END) AS null_source,
  SUM(CASE WHEN state IS NULL THEN 1 ELSE 0 END) AS null_state
FROM dim.dim_std_brand
""")
row = cur.fetchone()
print(f"  null_name={row[0]}  null_source={row[1]}  null_state={row[2]} (都应为 0)")

print("\n验证完成。")
