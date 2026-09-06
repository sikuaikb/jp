/* ============================================================
 * DDL：dwd.dwd_l2_data_converter_dac（DigiKey · 数模转换器 L2 宽表）
 *
 * 依赖：dim.dim_attr_schema（l1_code=data_converter）
 * 执行：run_attr_std.sh prod 或 mysql … < dwd_l2_data_converter_dac.sql
 * ============================================================ */
CREATE TABLE IF NOT EXISTS dwd.dwd_l2_data_converter_dac (
    `data_source`                    VARCHAR(32)     NOT NULL DEFAULT 'digikey' COMMENT '数据来源',
    `id`                             BIGINT          NOT NULL COMMENT '组件唯一ID',
    `mpn`                            VARCHAR(1024)   NULL,
    `brand`                          VARCHAR(256)    NULL     COMMENT '标准品牌名（brandshort 空则 NULL）',
    `brandid`                        BIGINT          NULL     COMMENT '标准品牌 ID',

    `l1_code`                        VARCHAR(32)     NOT NULL,
    `l2_code`                        VARCHAR(32)     NOT NULL COMMENT 'dac',
    `l3_code`                        VARCHAR(64)     NULL,

    `manufacturer`                   VARCHAR(1024)   NULL     COMMENT 'EAV 抽取，与 brand 独立',
    `rohs_compliant`                 BOOLEAN         NULL,
    `lifecycle_status`               VARCHAR(64)     NULL,
    `reach`                          BOOLEAN         NULL,
    `eccn_code`                      VARCHAR(128)    NULL,
    `msl_level`                      VARCHAR(1024)   NULL,

    `resolution_bit`                 INT             NULL,
    `sample_rate_ksps`               DOUBLE          NULL,
    `data_interface`                 VARCHAR(256)    NULL,
    `dac_channel_count`              INT             NULL,
    `settling_time_us`               DOUBLE          NULL,
    `reference_type`                 VARCHAR(128)    NULL,
    `differential_output`            BOOLEAN         NULL,
    `inl_dnl_lsb`                    VARCHAR(256)    NULL,
    `supply_voltage_analog_min_v`    DOUBLE          NULL,
    `supply_voltage_analog_max_v`    DOUBLE          NULL,
    `supply_voltage_digital_min_v`   DOUBLE          NULL,
    `supply_voltage_digital_max_v`   DOUBLE          NULL,
    `temp_min_c`                     DOUBLE          NULL,
    `temp_max_c`                     DOUBLE          NULL,
    `package_case`                   VARCHAR(1024)   NULL,
    `mounting_style`                 VARCHAR(128)    NULL,

    `ext_attributes`                 JSON            NULL,
    `semantic_tags`                  JSON            NULL,
    `dq_score`                       DOUBLE          NULL,
    `dq_flags`                       JSON            NULL,

    `source_id`                      BIGINT          NULL,

    `create_at`                      DATETIME        NULL     DEFAULT CURRENT_TIMESTAMP,
    `update_at`                      DATETIME        NULL     DEFAULT CURRENT_TIMESTAMP
) ENGINE=OLAP
PRIMARY KEY(`data_source`, `id`)
COMMENT 'DWD L2 data_converter · 数模转换器（dac）宽表'
DISTRIBUTED BY HASH(`id`) BUCKETS 16
PROPERTIES (
    "compression"             = "ZSTD",
    "datacache.enable"        = "true",
    "replication_num"         = "1",
    "enable_persistent_index" = "true"
);
