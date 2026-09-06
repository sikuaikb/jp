/* test_dim.dim_attr_schema_switch — switch L1 属性字典（试点） */
DROP TABLE IF EXISTS dim.dim_attr_schema_switch;

CREATE TABLE dim.dim_attr_schema_switch (
    `schema_version`   VARCHAR(32)   NOT NULL COMMENT 'switch_schema_v1.4.30',
    `l1_code`          VARCHAR(64)   NOT NULL COMMENT 'switch',
    `scope_level`      VARCHAR(16)   NOT NULL COMMENT 'l2 | l3',
    `scope_code`       VARCHAR(96)   NOT NULL COMMENT 'l2_code 或 l3_code',
    `std_attr_code`    VARCHAR(128)  NOT NULL COMMENT '标准属性编码（snake_case）',
    `std_attr_cn`      VARCHAR(256)  NULL,
    `unit_std`         VARCHAR(64)   NULL,
    `db_type`          VARCHAR(24)   NOT NULL COMMENT 'DOUBLE | INT | VARCHAR | ENUM',
    `precision`        INT           NULL,
    `value_domain`     VARCHAR(2048) NULL,
    `min_bound`        DOUBLE        NULL,
    `max_bound`        DOUBLE        NULL,
    `is_l2_common`     TINYINT       NOT NULL,
    `display_ord`      INT           NULL,
    `attr_category_cn` VARCHAR(256)  NULL,
    `attr_category_en` VARCHAR(256)  NULL,
    `note`             VARCHAR(2048) NULL,
    `create_at`        DATETIME      NULL DEFAULT CURRENT_TIMESTAMP,
    `update_at`        DATETIME      NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=OLAP
PRIMARY KEY(`schema_version`, `l1_code`, `scope_level`, `scope_code`, `std_attr_code`)
COMMENT 'switch 属性字典（试点；来自 传感器_schema.xlsx）'
DISTRIBUTED BY HASH(`std_attr_code`) BUCKETS 4
PROPERTIES ("replication_num" = "1", "enable_persistent_index" = "true");
