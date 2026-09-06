/* ============================================================
 * DIM: dim.dim_l3_classify —— L3 分类窄表（DDL 仅）
 *
 * 路径：`sql_scripts/1.classify/dim_l3_classify.sql`
 * 数据来源：历史 seed CSV 或新 L1 合并时的 `test_dim.dim_l3_classify_<l1>` 后缀表
 * 合并：新 L1 只替换该 L1 的分类树；规则引擎 SQL 不随 taxonomy 合并覆盖
 *
 * l3_id 编码参考 sql_scripts/foundation/dim_l3_classify_all.sql：
 *   LLMMNN = L1 两位顺序 + L2 两位顺序 + L3 两位顺序。
 *   L1 前两位原则上稳定；L2/L3 可随 schema 演进在同一 L1 段内调整。
 * ============================================================ */

DROP TABLE IF EXISTS dim.dim_l3_classify_resistor_taxonomy;

DROP TABLE IF EXISTS dim.dim_l3_classify;

CREATE TABLE dim.dim_l3_classify (
    `l3_id`           VARCHAR(6)    NOT NULL COMMENT '六位数字主键',
    `l1_code`         VARCHAR(64)   NOT NULL COMMENT 'L1 英文编码',
    `l1_cn`           VARCHAR(128)  NULL     COMMENT 'L1 中文名称',
    `l2_code`         VARCHAR(96)   NOT NULL COMMENT 'L2 英文编码',
    `l2_cn`           VARCHAR(256)  NULL     COMMENT 'L2 中文名称',
    `l3_code`         VARCHAR(64)   NOT NULL COMMENT 'L3 英文编码',
    `l3_cn`           VARCHAR(256)  NULL     COMMENT 'L3 中文名称',
    `note`            VARCHAR(512)  NULL     COMMENT '备注',
    `schema_version`  VARCHAR(64)   NOT NULL COMMENT '字典版本',
    `create_at`       DATETIME      NULL     DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `update_at`       DATETIME      NULL     DEFAULT CURRENT_TIMESTAMP COMMENT '更新时间'
) ENGINE=OLAP
PRIMARY KEY(`l3_id`)
COMMENT 'L3 分类维表（多 L1 合并；DDL 仅）'
DISTRIBUTED BY HASH(`l3_id`) BUCKETS 1
PROPERTIES ("replication_num" = "1", "enable_persistent_index" = "true");
