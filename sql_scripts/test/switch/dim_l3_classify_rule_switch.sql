/* test_dim.dim_l3_classify_rule_switch — switch gate+classify 规则（试点 DDL） */
DROP TABLE IF EXISTS dim.dim_l3_classify_rule_switch;

CREATE TABLE dim.dim_l3_classify_rule_switch (
    `rule_id`               VARCHAR(64)    NOT NULL,
    `clause_group_id`       INT            NOT NULL,
    `clause_ord`            INT            NOT NULL,
    `schema_version`        VARCHAR(32)    NOT NULL,
    `data_source`           VARCHAR(32)    NOT NULL,
    `rule_kind`             VARCHAR(16)    NOT NULL,
    `l3_id`                 VARCHAR(6)     NULL,
    `l3_cn`                 VARCHAR(128)   NULL,
    `phase`                 TINYINT        NOT NULL,
    `rule_priority`         INT            NOT NULL,
    `enabled`               TINYINT        NOT NULL,
    `confidence_weight`     DECIMAL(5,4)   NOT NULL,
    `classify_source_hint`  VARCHAR(32)    NULL,
    `field_code`            VARCHAR(32)    NOT NULL,
    `match_value`           VARCHAR(512)   NULL,
    `match_values`          ARRAY<VARCHAR(128)> NULL,
    `match_map`             MAP<VARCHAR(512), VARCHAR(512)> NULL,
    `note`                  VARCHAR(512)   NULL,
    `create_at`             DATETIME       NULL DEFAULT CURRENT_TIMESTAMP,
    `update_at`             DATETIME       NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=OLAP
PRIMARY KEY(`rule_id`, `clause_group_id`, `clause_ord`)
COMMENT 'switch L1 分类规则（试点；ICPDF gate+classify）'
DISTRIBUTED BY HASH(`rule_id`) BUCKETS 1
PROPERTIES ("replication_num" = "1", "enable_persistent_index" = "true");
