/*
 * dwd.dwd_ecloud_component_detail
 *   source : ods.ods_jp_component_detail (+ ods.ods_jp_category, ods.ods_jp_brand)
 *   changes:
 *     1) cat_id 后新增 category_1 / category_2（分别取一级、二级分类 title）
 *     2) 补 brand_id：用 brand_name 关联 ods_jp_brand.name 反查
 *     3) 丢弃 supplier / eccn
 *     4) create_at / update_at 统一为执行时间
 *     5) 丢弃 extended_attributes，拆成 dimensions (JSON) 与 pdf (JSON) 两列
 *     6) 无分区，PRIMARY KEY(id) + HASH(id) 16 buckets
 *   layout reasoning:
 *     当前 ODS 约 2.6M 行，16 bucket ≈ 每桶 16 万行，ZSTD 下单 tablet 约 30-50MB，
 *     满足 StarRocks 主键表单 tablet ≤ 1-2GB 的推荐上限，且留出 5-10x 增长空间。
 *   run:
 *     mysql ... < dwd_ecloud_component_detail.sql
 *     注意：StarRocks 不认"纯行注释"独立语句，本脚本头部与小节标题统一用块注释。
 */

/* 1) 建表（幂等） */
CREATE TABLE IF NOT EXISTS dwd.dwd_ecloud_component_detail (
    `id`            VARCHAR(64)     NOT NULL COMMENT '组件ID',
    `cat_id`        VARCHAR(64)     NULL     COMMENT '分类ID（指向二级分类）',
    `category_1`    VARCHAR(256)    NULL     COMMENT '一级分类 title（关联 ods_jp_category 根节点）',
    `category_2`    VARCHAR(256)    NULL     COMMENT '二级分类 title（cat_id 直接对应节点）',
    `name`          VARCHAR(256)    NULL     COMMENT '名称/型号',
    `picture`       VARCHAR(512)    NULL     COMMENT '图片 URL',
    `brand_name`    VARCHAR(256)    NULL     COMMENT '品牌名称',
    `brand_id`      BIGINT          NULL     COMMENT '品牌ID（关联 ods_jp_brand.name 回填）',
    `dimensions`    JSON            NULL     COMMENT '参数字典（extended_attributes.dimensions）',
    `pdf`           JSON            NULL     COMMENT 'PDF 链接数组（extended_attributes.pdf）',
    `description`   VARCHAR(65533)  NULL     COMMENT '描述文本',
    `encapsulation` VARCHAR(128)    NULL     COMMENT '封装（源端"-"未做转换，保留原值）',
    `data_sheet`    VARCHAR(65533)  NULL     COMMENT '数据手册（JSON 数组字符串）',
    `create_at`     DATETIME        NULL DEFAULT CURRENT_TIMESTAMP COMMENT '本表入库时间',
    `update_at`     DATETIME        NULL DEFAULT CURRENT_TIMESTAMP COMMENT '本表更新时间'
) ENGINE=OLAP
PRIMARY KEY(`id`)
COMMENT 'JP 组件明细 DWD（维度补全 + extended_attributes 拆解）'
DISTRIBUTED BY HASH(`id`) BUCKETS 16
PROPERTIES (
    "compression"             = "ZSTD",
    "datacache.enable"        = "true",
    "replication_num"         = "1",
    "enable_persistent_index" = "true"
);


/* 2) 灌入（主键表可安全重跑 upsert）
 *    连接关系：
 *      c.cat_id -> c2.id (二级分类：title -> category_2)
 *      c2.pid   -> c1.id (一级分类：title -> category_1)
 *      c.brand_name -> b.name (品牌：id -> brand_id)
 */
INSERT INTO dwd.dwd_ecloud_component_detail
(
    id, cat_id, category_1, category_2,
    name, picture, brand_name, brand_id,
    dimensions, pdf,
    description, encapsulation, data_sheet,
    create_at, update_at
)
SELECT
    c.id,
    c.cat_id,
    c1.title                                                            AS category_1,
    c2.title                                                            AS category_2,
    c.name,
    c.picture,
    c.brand_name,
    b.id                                                                AS brand_id,
    parse_json(NULLIF(get_json_string(c.extended_attributes, '$.dimensions'), ''))  AS dimensions,
    parse_json(NULLIF(get_json_string(c.extended_attributes, '$.pdf'),        '')) AS pdf,
    c.description,
    c.encapsulation,
    c.data_sheet,
    CURRENT_TIMESTAMP()                                                 AS create_at,
    CURRENT_TIMESTAMP()                                                 AS update_at
FROM ods.ods_jp_component_detail c
LEFT JOIN ods.ods_jp_category c2 ON CAST(c2.id AS CHAR) = c.cat_id
LEFT JOIN ods.ods_jp_category c1 ON c1.id              = c2.pid
LEFT JOIN ods.ods_jp_brand    b  ON b.name             = c.brand_name;


/* 3) 核对 */
SELECT
    (SELECT COUNT(*) FROM ods.ods_jp_component_detail)          AS src_rows,
    (SELECT COUNT(*) FROM dwd.dwd_ecloud_component_detail)          AS dst_rows,
    (SELECT COUNT(*) FROM dwd.dwd_ecloud_component_detail WHERE category_1 IS NULL) AS null_category_1,
    (SELECT COUNT(*) FROM dwd.dwd_ecloud_component_detail WHERE category_2 IS NULL) AS null_category_2,
    (SELECT COUNT(*) FROM dwd.dwd_ecloud_component_detail WHERE brand_id   IS NULL) AS null_brand_id,
    (SELECT COUNT(*) FROM dwd.dwd_ecloud_component_detail WHERE dimensions IS NOT NULL) AS has_dimensions,
    (SELECT COUNT(*) FROM dwd.dwd_ecloud_component_detail WHERE pdf        IS NOT NULL) AS has_pdf;
