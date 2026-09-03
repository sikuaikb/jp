/* ============================================================
 * dim.dim_brand_origin —— 品牌产地维度（独立持久表）
 *
 * 路径：sql_scripts/2.attribute_standard/dim_brand_origin.sql
 *
 * 设计原因：
 *   dim.dim_std_brand 每次 sync 会 DROP+CREATE+INSERT FROM ods，
 *   产地列（country_region/is_domestic/domestic_type）会被冲掉。
 *   本表独立存放产地数据（PK=brand_id_std），sync 后由
 *   brand_origin_backfill.sql JOIN 回写 dim_std_brand 的产地列。
 *
 * 数据来源：
 *   brand_origin_agent 产出的 brand_origin_apply.sql 经解析导入。
 *   后续新增/修正产地：直接 UPSERT 本表（PK 模型自动去重）。
 *
 * 维护约定：
 *   - 新增品牌产地：INSERT INTO dim_brand_origin VALUES (brand_id_std, ...)
 *   - 修正产地：INSERT 覆盖（PK 模型 UPSERT）
 *   - brand_merge 合并时：03_merge_dim.py 自动把 merge_id 改成 keep_id
 * ============================================================ */

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
PROPERTIES ("replication_num"="1", "enable_persistent_index"="true");
