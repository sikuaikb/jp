/* ============================================================
 * dim.dim_std_brand —— 品牌标准化主表（镜像 ods.ods_jp_brand + manual_extra）
 *
 * 路径：sql_scripts/2.attribute_standard/dim_std_brand.sql
 *
 * 数据流：
 *   1) ods.ods_jp_brand (state=1)        → 本文件全量装载（DROP+CREATE+INSERT）
 *   2) dim_std_brand_manual_extra.sql    → 后续 PR 在该独立文件中追加 INSERT VALUES
 *   3) brand_origin_backfill.sql         → 从 dim.dim_brand_origin JOIN 回写产地列
 *   4) v_std_brand_alias.sql             → 视图展开 name/abbr/related_words，供 L2 build EQ JOIN
 *
 * 维护约定：
 *   - ods.ods_jp_brand 由数据源方维护，本仓库不修改 ods；
 *   - 新增品牌（jp_brand 未覆盖）走 dim_std_brand_manual_extra.sql，brand_id_std 用 9_000_001+ 段；
 *   - 一键装载：bash sync_dim_std_brand.sh test|prod。
 *
 * brand_zh / brand_en 拆分规则：
 *   - name 含 CJK 且含 '-'  → zh = split_part(1), en = split_part(2)
 *   - name 含 CJK 不含 '-'  → zh = name, en = NULL
 *   - name 全英文           → zh = NULL, en = name
 * ============================================================ */

DROP TABLE IF EXISTS dim.dim_std_brand;

CREATE TABLE dim.dim_std_brand (
    `brand_id_std`     BIGINT       NOT NULL COMMENT '品牌主键；jp_brand 来源取 ods.id；manual_extra 用 9_000_001+ 段',
    `name`             VARCHAR(256)     NULL COMMENT '标准品牌名（与 ods.ods_jp_brand.name 同），如 威世-VISHAY',
    `brand_zh`         VARCHAR(128)     NULL COMMENT '中文部分（威世）',
    `brand_en`         VARCHAR(128)     NULL COMMENT '英文部分（VISHAY / Vishay）',
    `abbr`             VARCHAR(64)      NULL COMMENT 'jp_brand.abbr（VIS / YAG …）',
    `related_words`    ARRAY<VARCHAR(256)> NULL COMMENT '同义词数组（含 name / abbr 衍生）',
    `logo`             VARCHAR(256)     NULL,
    `state`            TINYINT          NULL,
    `official_website` VARCHAR(512)     NULL,
    `level`            INT              NULL,
    `type`             TINYINT          NULL,
    `source`           VARCHAR(32)  NOT NULL COMMENT 'jp_brand | manual_extra',
    `country_region`   VARCHAR(8)      NULL COMMENT '品牌起源地ISO码 CN/TW/HK/US/JP/DE...,NULL未定',
    `is_domestic`      TINYINT         NULL COMMENT '是否中国资本/品牌:1是(含台港澳+中资收购)0海外 NULL未定',
    `domestic_type`    VARCHAR(20)     NULL COMMENT '国产替代口径:mainland_native/mainland_acquired/taiwan/hk_mo/overseas',
    `create_at`        DATETIME         NULL DEFAULT CURRENT_TIMESTAMP,
    `update_at`        DATETIME         NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=OLAP
PRIMARY KEY(`brand_id_std`)
COMMENT '品牌标准化主表（镜像 ods.ods_jp_brand + manual_extra + 产地维度）'
DISTRIBUTED BY HASH(`brand_id_std`) BUCKETS 4
PROPERTIES ("replication_num"="1","enable_persistent_index"="true");


INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT
    id                            AS brand_id_std,
    name,
    CASE
        WHEN name REGEXP '[一-龥]' AND name LIKE '%-%'
            THEN NULLIF(TRIM(split_part(name, '-', 1)), '')
        WHEN name REGEXP '[一-龥]'
            THEN NULLIF(TRIM(name), '')
        ELSE NULL
    END                           AS brand_zh,
    CASE
        WHEN name REGEXP '[一-龥]' AND name LIKE '%-%'
            THEN NULLIF(TRIM(split_part(name, '-', 2)), '')
        WHEN name NOT REGEXP '[一-龥]'
            THEN NULLIF(TRIM(name), '')
        ELSE NULL
    END                           AS brand_en,
    abbr,
    related_words,
    logo,
    state,
    official_website,
    level,
    type,
    'jp_brand'                    AS source,
    CURRENT_TIMESTAMP(),
    CURRENT_TIMESTAMP()
FROM ods.ods_jp_brand
WHERE state = 1;
