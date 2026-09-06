/* test_dwd.dwd_component_class_switch — switch 试点分类结果（仅 ICPDF） */
DROP TABLE IF EXISTS test_dwd.dwd_component_class_switch;

CREATE TABLE test_dwd.dwd_component_class_switch (
    `data_source`       VARCHAR(32)   NOT NULL DEFAULT 'icpdf',
    `id`                BIGINT        NOT NULL,
    `l1_code`           VARCHAR(32)   NULL,
    `l2_code`           VARCHAR(64)   NULL,
    `l3_code`           VARCHAR(64)   NULL,
    `l3_id`             VARCHAR(6)    NULL,
    `rule_id`           VARCHAR(64)   NULL,
    `phase`             TINYINT       NULL,
    `classify_source`   VARCHAR(64)   NULL,
    `matched_priority`  INT           NULL,
    `matched_value`     VARCHAR(512)  NULL,
    `confidence`        DECIMAL(5,4)  NULL,
    `create_at`         DATETIME      NULL DEFAULT CURRENT_TIMESTAMP,
    `update_at`         DATETIME      NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=OLAP
PRIMARY KEY(`data_source`, `id`)
COMMENT 'switch L1 分类结果（试点；仅 ICPDF）'
DISTRIBUTED BY HASH(`id`) BUCKETS 16
PROPERTIES ("replication_num" = "1", "enable_persistent_index" = "true");
