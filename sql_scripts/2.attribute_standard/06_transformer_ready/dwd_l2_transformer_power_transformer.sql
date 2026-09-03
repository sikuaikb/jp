/* dwd.dwd_l2_transformer_power_transformer · transformer_schema_v1.6.08 */
DROP TABLE IF EXISTS dwd.dwd_l2_transformer_power_transformer;

CREATE TABLE dwd.dwd_l2_transformer_power_transformer (
    `data_source` VARCHAR(32) NOT NULL DEFAULT 'digikey',
    `id` BIGINT NOT NULL,
    `mpn` VARCHAR(1024) NULL,
    `brand` VARCHAR(256) NULL,
    `brandid` BIGINT NULL,
    `l1_code` VARCHAR(32) NOT NULL,
    `l2_code` VARCHAR(96) NOT NULL,
    `l3_code` VARCHAR(96) NULL,
    `brandshort` VARCHAR(256) NULL,
    `l3_id` VARCHAR(6) NULL,
    `manufacturer` VARCHAR(1024) NULL,
    `lifecycle_status` VARCHAR(64) NULL,
    `eccn_code` VARCHAR(1024) NULL,
    `rohs_compliant` TINYINT NULL,
    `reach` VARCHAR(1024) NULL,
    `aec_q_level` VARCHAR(64) NULL,
    `lead_free` TINYINT NULL,
    `htsus_code` VARCHAR(1024) NULL,
    `msl_level` VARCHAR(64) NULL,
    `package_case` VARCHAR(1024) NULL,
    `temp_min_c` DOUBLE NULL,
    `height_max_mm` DOUBLE NULL,
    `temp_max_c` DOUBLE NULL,
    `pkg_length_mm` DOUBLE NULL,
    `rated_power_va` DOUBLE NULL,
    `pkg_width_mm` DOUBLE NULL,
    `primary_voltage_v` DOUBLE NULL,
    `transformer_type_raw` VARCHAR(1024) NULL,
    `secondary_voltage_v` DOUBLE NULL,
    `turns_ratio` VARCHAR(1024) NULL,
    `rated_frequency_hz` DOUBLE NULL,
    `efficiency_pct` DOUBLE NULL,
    `winding_count` INT NULL,
    `insulation_class` VARCHAR(64) NULL,
    `mounting_style` VARCHAR(64) NULL,
    `ext_attributes` JSON NULL,
    `semantic_tags` JSON NULL,
    `dq_score` DOUBLE NULL,
    `dq_flags` JSON NULL,
    `source_id` BIGINT NULL,
    `create_at` DATETIME NULL DEFAULT CURRENT_TIMESTAMP,
    `update_at` DATETIME NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE = OLAP
PRIMARY KEY (`data_source`, `id`)
COMMENT 'DWD L2 power_transformer 宽表（transformer_schema_v1.6.08）'
DISTRIBUTED BY HASH(`id`) BUCKETS 16
PROPERTIES (
    "compression"             = "ZSTD",
    "datacache.enable"        = "true",
    "replication_num"         = "1",
    "enable_persistent_index" = "true"
);
