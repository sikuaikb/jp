/* test_dim.dim_attr_extract_rule_circuit_protection — CP 属性抽取规则（试点） */
DROP TABLE IF EXISTS dim.dim_attr_extract_rule_circuit_protection;

CREATE TABLE dim.dim_attr_extract_rule_circuit_protection (
    `extract_rule_id`     VARCHAR(128)  NOT NULL,
    `data_source`         VARCHAR(32)   NOT NULL DEFAULT 'digikey',
    `schema_version`      VARCHAR(64)   NOT NULL,
    `l1_code`             VARCHAR(64)   NOT NULL,
    `apply_scope_level`   VARCHAR(16)   NULL,
    `apply_scope_code`    VARCHAR(96)   NULL,
    `std_attr_code`       VARCHAR(128)  NOT NULL,
    `source_kind`         VARCHAR(32)   NOT NULL,
    `source_expr`         VARCHAR(512)  NOT NULL,
    `source_value_expr`   VARCHAR(1024) NULL,
    `source_value_regex`  VARCHAR(512)  NULL,
    `literal_std_value`   VARCHAR(1024) NULL,
    `priority`            INT           NOT NULL,
    `enabled`             TINYINT       NOT NULL,
    `value_map`           JSON          NULL,
    `note`                VARCHAR(512)  NULL,
    `create_at`           DATETIME      NULL DEFAULT CURRENT_TIMESTAMP,
    `update_at`           DATETIME      NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=OLAP
PRIMARY KEY(`extract_rule_id`)
COMMENT 'circuit_protection 属性抽取规则（试点；前缀 cp_）'
DISTRIBUTED BY HASH(`extract_rule_id`) BUCKETS 4
PROPERTIES ("replication_num" = "1", "enable_persistent_index" = "true");
