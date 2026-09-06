/* test_dwd.dwd_component_attr_std_circuit_protection — CP EAV 窄表（试点） */
DROP TABLE IF EXISTS test_dwd.dwd_component_attr_std_circuit_protection;

CREATE TABLE test_dwd.dwd_component_attr_std_circuit_protection (
    `data_source`            VARCHAR(32)   NOT NULL COMMENT 'icpdf | digikey',
    `id`                     BIGINT        NOT NULL,
    `std_attr_code`          VARCHAR(128)  NOT NULL,
    `l2_code`                VARCHAR(96)   NULL,
    `l3_id`                  VARCHAR(6)    NULL,
    `l3_code`                VARCHAR(64)   NULL,
    `attr_schema_version`    VARCHAR(32)   NOT NULL,
    `std_attr_cn`            VARCHAR(256)  NULL,
    `db_type`                VARCHAR(24)   NULL,
    `unit_std`               VARCHAR(32)   NULL,
    `value_raw`              VARCHAR(1024) NULL,
    `extract_rule_id`        VARCHAR(128)  NULL,
    `match_priority`         INT           NULL,
    `clean_str`              VARCHAR(1024) NULL,
    `value_std_double`       DOUBLE        NULL,
    `value_std_varchar`      VARCHAR(1024) NULL,
    `dq_flag`                VARCHAR(32)   NULL,
    `create_at`              DATETIME      NULL DEFAULT CURRENT_TIMESTAMP,
    `update_at`              DATETIME      NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=OLAP
PRIMARY KEY(`data_source`, `id`, `std_attr_code`)
COMMENT 'circuit_protection 多源 EAV（试点）'
DISTRIBUTED BY HASH(`id`) BUCKETS 16
PROPERTIES ("replication_num" = "1", "enable_persistent_index" = "true");
