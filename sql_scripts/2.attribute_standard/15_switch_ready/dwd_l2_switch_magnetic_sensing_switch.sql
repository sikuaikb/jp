/* ============================================================
 * TEST DWD L2 宽表: dwd.dwd_l2_switch_magnetic_sensing_switch
 *
 * Switch L1 试点；scope_code='magnetic_sensing_switch'。strict 后缀模式（结尾多一个 _switch）。
 * 由 build_l2_widetable_sql.py 从 seed/dim_attr_schema_switch.csv 渲染。
 *
 * 注：PRIMARY KEY(data_source, id) 要求这两列出现在表定义的最前面（StarRocks 约束）。
 * ============================================================ */

DROP TABLE IF EXISTS dwd.dwd_l2_switch_magnetic_sensing_switch;

CREATE TABLE dwd.dwd_l2_switch_magnetic_sensing_switch (
    `data_source`       VARCHAR(32)  NOT NULL COMMENT '数据源（PK 第一列）',
    `id`                BIGINT       NOT NULL COMMENT '源 param 表 id（PK 第二列）',
    `mpn`               VARCHAR(256) NULL,
    `brand`             VARCHAR(256) NULL,
    `brandid`           VARCHAR(64)  NULL,
    `l1_code`           VARCHAR(64)  NULL,
    `l2_code`           VARCHAR(64)  NULL,
    `l3_code`           VARCHAR(96)  NULL,
    `manufacturer`      VARCHAR(256)   NULL,
    `rohs_compliant`    BOOLEAN        NULL,
    `lifecycle_status`  VARCHAR(256)   NULL,
    `reach`             BOOLEAN        NULL,
    `eccn_code`         VARCHAR(256)   NULL,
    `aec_q_level`       VARCHAR(256)   NULL,
    `lead_free`         BOOLEAN        NULL,
    `msl_level`         VARCHAR(256)   NULL,
    `package_case`      VARCHAR(256)   NULL,
    `temp_min_c`        DOUBLE         NULL,
    `temp_max_c`        DOUBLE         NULL,
    `pkg_length_mm`     DOUBLE         NULL,
    `pkg_width_mm`      DOUBLE         NULL,
    `pkg_height_mm`     DOUBLE         NULL,
    `switch_type`       VARCHAR(256)   NULL,
    `switching_voltage_max_v` DOUBLE         NULL,
    `switching_current_max_ma` DOUBLE         NULL,
    `max_switching_freq_hz` DOUBLE         NULL,
    `ext_attributes`    JSON         NULL COMMENT 'L3 专属属性 JSON',
    `semantic_tags`     JSON         NULL,
    `dq_score`          DOUBLE       NULL,
    `dq_flags`          JSON         NULL,
    `source_id`         BIGINT       NULL,
    `create_at`         DATETIME     NULL DEFAULT CURRENT_TIMESTAMP,
    `update_at`         DATETIME     NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=OLAP
PRIMARY KEY(`data_source`, `id`)
COMMENT 'magnetic_sensing_switch L2 宽表（test 试点 strict 后缀）'
DISTRIBUTED BY HASH(`id`) BUCKETS 8
PROPERTIES ("replication_num" = "1", "enable_persistent_index" = "true");
