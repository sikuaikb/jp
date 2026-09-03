/* ============================================================
 * DWD：L2 SKU 全局分类目录
 *
 * 定位：Agent 查分类 + 路由到对应 L2 宽表。
 *       不含电气参数、不含 datasheet（按需查源表/L2）。
 *
 * 主键：(data_source, id) —— 与所有 dwd_l2_* 宽表一致，源内 SKU 唯一。
 *
 * 查询优化（StarRocks PK 表）：
 *   - PK (data_source, id)     → Agent 按源+id 点查
 *   - bloom_filter_columns     → mpn / brandid / l1~l3_code 等值筛选
 *   - HASH(id) BUCKETS 16      → 与 L2 宽表、component_class 同量级分桶
 *
 * 构建：ALLOW_PROD=1 bash sql_scripts/2.attribute_standard/run_component_catalog.sh prod
 * ============================================================ */

DROP TABLE IF EXISTS dwd.dwd_l2_component_catalog;

CREATE TABLE dwd.dwd_l2_component_catalog (
    /* ----- PK 列必须置首（StarRocks PRIMARY KEY 约束）----- */
    `data_source`  VARCHAR(32)   NOT NULL COMMENT 'icpdf | digikey',
    `id`           BIGINT        NOT NULL COMMENT '源内 SKU id',

    /* ----- 身份 ----- */
    `mpn`          VARCHAR(1024) NULL     COMMENT '制造商料号',
    `brand`        VARCHAR(256)  NULL     COMMENT '标准品牌名',
    `brandid`      BIGINT        NULL     COMMENT '标准品牌 ID',

    /* ----- 分类（code + 中文名）----- */
    `l1_code`      VARCHAR(32)   NOT NULL COMMENT 'L1 编码',
    `l1_cn`        VARCHAR(128)  NULL     COMMENT 'L1 中文名称',
    `l2_code`      VARCHAR(64)   NOT NULL COMMENT 'L2 编码',
    `l2_cn`        VARCHAR(256)  NULL     COMMENT 'L2 中文名称',
    `l3_code`      VARCHAR(64)   NULL     COMMENT 'L3 编码',
    `l3_cn`        VARCHAR(256)  NULL     COMMENT 'L3 中文名称',

    /* ----- 溯源 + 分类质量 ----- */
    `l2_table`     VARCHAR(128)  NOT NULL COMMENT '来源 dwd_l2_* 宽表名',
    `l3_id`        VARCHAR(6)    NULL     COMMENT '分类节点 ID（dwd_component_class）',
    `confidence`   DECIMAL(5,4)  NULL     COMMENT '分类置信度',
    `rule_id`      VARCHAR(64)   NULL     COMMENT '命中分类规则',

    `create_at`    DATETIME      NULL DEFAULT CURRENT_TIMESTAMP,
    `update_at`    DATETIME      NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=OLAP
PRIMARY KEY(`data_source`, `id`)
COMMENT 'L2 SKU 全局分类目录（Agent 分类检索 + L2 路由）'
DISTRIBUTED BY HASH(`id`) BUCKETS 16
PROPERTIES (
    "replication_num"         = "1",
    "enable_persistent_index" = "true",
    "bloom_filter_columns"    = "mpn,brandid,l1_code,l2_code,l3_code"
);
