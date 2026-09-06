"""解析 brand_origin_apply.sql，提取产地数据，创建 dim.dim_brand_origin 表并导入。"""
import os, re, sys
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '.cursor', 'skills', 'component-etl-methodology', 'tools'))
from dim_db_loader import connect

APPLY_SQL = r"c:\Users\Administrator\Documents\WXWork\1688855790628591\Cache\File\2026-06\brand_origin_apply.sql"

# 解析 UPDATE 语句，提取 (country_region, is_domestic, domestic_type, [brand_id_std...])
rows = []  # (brand_id_std, country_region, is_domestic, domestic_type)

with open(APPLY_SQL, encoding="utf-8") as f:
    sql_text = f.read()

# 匹配: UPDATE dim_std_brand SET country_region='XX', is_domestic=N, domestic_type='YY' WHERE brand_id_std IN (id1,id2,...)
pattern = re.compile(
    r"UPDATE\s+dim_std_brand\s+SET\s+"
    r"country_region='(\w+)',\s*"
    r"is_domestic=(\d+),\s*"
    r"domestic_type='(\w+)'\s+"
    r"WHERE\s+brand_id_std\s+IN\s*\(([^)]+)\)",
    re.IGNORECASE
)

for m in pattern.finditer(sql_text):
    cr = m.group(1)
    is_dom = int(m.group(2))
    dt = m.group(3)
    ids_str = m.group(4)
    ids = [int(x.strip()) for x in ids_str.split(",") if x.strip()]
    for bid in ids:
        rows.append((bid, cr, is_dom, dt))

print(f"解析到 {len(rows)} 条产地记录")

# 统计
from collections import Counter
cr_cnt = Counter(r[1] for r in rows)
dt_cnt = Counter(r[3] for r in rows)
print(f"country_region 分布: {dict(cr_cnt)}")
print(f"domestic_type 分布: {dict(dt_cnt)}")

# 建表 + 导入
conn = connect()
cur = conn.cursor()

print("\n=== 创建 dim.dim_brand_origin 表 ===")
cur.execute("""
CREATE TABLE IF NOT EXISTS dim.dim_brand_origin (
    `brand_id_std`     BIGINT       NOT NULL COMMENT '品牌主键，关联 dim.dim_std_brand',
    `country_region`   VARCHAR(8)   NULL COMMENT '品牌起源地ISO码 CN/TW/HK/US/JP/DE...,NULL未定',
    `is_domestic`      TINYINT      NULL COMMENT '1=中国资本/品牌(含台港澳+中资收购) 0=海外 NULL未定',
    `domestic_type`    VARCHAR(20)  NULL COMMENT 'mainland_native/mainland_acquired/taiwan/hk_mo/overseas',
    `update_at`        DATETIME     NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=OLAP
PRIMARY KEY(`brand_id_std`)
COMMENT '品牌产地维度（独立持久，sync 后 JOIN 回写 dim_std_brand）'
DISTRIBUTED BY HASH(`brand_id_std`) BUCKETS 4
PROPERTIES ("replication_num"="1", "enable_persistent_index"="true")
""")
conn.commit()
print("  表已创建/已存在")

# 清空后导入（幂等）
print("\n=== 清空旧数据 ===")
cur.execute("TRUNCATE TABLE dim.dim_brand_origin")
conn.commit()
print("  已清空")

# 批量 INSERT
BATCH = 500
total = 0
for i in range(0, len(rows), BATCH):
    batch = rows[i:i+BATCH]
    vals = ",".join(f"({bid},'{cr}',{isd},'{dt}',CURRENT_TIMESTAMP())" for bid, cr, isd, dt in batch)
    sql = f"INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES {vals}"
    cur.execute(sql)
    conn.commit()
    total += len(batch)
    if (i // BATCH) % 5 == 0:
        print(f"  已导入 {total}/{len(rows)}")

print(f"\n导入完成: {total} 条")

# 验证
cur.execute("SELECT COUNT(*) FROM dim.dim_brand_origin")
n = cur.fetchone()[0]
print(f"dim.dim_brand_origin 行数: {n}")

cur.execute("SELECT country_region, is_domestic, domestic_type, COUNT(*) FROM dim.dim_brand_origin GROUP BY country_region, is_domestic, domestic_type ORDER BY COUNT(*) DESC")
print("\n分布验证:")
for r in cur.fetchall():
    print(f"  {r[0]:<4} is_dom={r[1]} type={r[2]:<20} n={r[3]}")
