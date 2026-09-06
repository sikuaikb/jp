/* test_dim.dim_l3_classify_switch — switch L3 taxonomy（试点 DDL） */
DROP TABLE IF EXISTS dim.dim_l3_classify_switch;

CREATE TABLE dim.dim_l3_classify_switch (
    `l3_id`           VARCHAR(6)    NOT NULL COMMENT '六位数字主键',
    `l1_code`         VARCHAR(64)   NOT NULL COMMENT 'L1 英文编码',
    `l1_cn`           VARCHAR(128)  NULL     COMMENT 'L1 中文名称',
    `l2_code`         VARCHAR(96)   NOT NULL COMMENT 'L2 英文编码',
    `l2_cn`           VARCHAR(256)  NULL     COMMENT 'L2 中文名称',
    `l3_code`         VARCHAR(64)   NOT NULL COMMENT 'L3 英文编码',
    `l3_cn`           VARCHAR(256)  NULL     COMMENT 'L3 中文名称',
    `note`            VARCHAR(512)  NULL     COMMENT '备注',
    `schema_version`  VARCHAR(32)   NOT NULL COMMENT '字典版本',
    `create_at`       DATETIME      NULL     DEFAULT CURRENT_TIMESTAMP,
    `update_at`       DATETIME      NULL     DEFAULT CURRENT_TIMESTAMP
) ENGINE=OLAP
PRIMARY KEY(`l3_id`)
COMMENT 'switch L1 L3 分类维表（试点；schema v1.5.28）'
DISTRIBUTED BY HASH(`l3_id`) BUCKETS 1
PROPERTIES ("replication_num" = "1", "enable_persistent_index" = "true");
