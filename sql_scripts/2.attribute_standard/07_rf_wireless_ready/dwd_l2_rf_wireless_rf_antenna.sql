/* dwd.dwd_l2_rf_wireless_rf_antenna */
DROP TABLE IF EXISTS dwd.dwd_l2_rf_wireless_rf_antenna;

CREATE TABLE dwd.dwd_l2_rf_wireless_rf_antenna (
    `data_source` VARCHAR(32) NOT NULL DEFAULT 'digikey',
    `id` BIGINT NOT NULL,
    `mpn` VARCHAR(1024) NULL,
    `brand` VARCHAR(256) NULL,
    `brandid` BIGINT NULL,
    `l1_code` VARCHAR(32) NOT NULL,
    `l2_code` VARCHAR(96) NOT NULL,
    `l3_code` VARCHAR(96) NULL,
    `brandshort` VARCHAR(256) NULL,
    `l3_id` INT NULL,
    `manufacturer` VARCHAR(1024) NULL,
    `rohs_compliant` TINYINT NULL,
    `lifecycle_status` VARCHAR(128) NULL,
    `reach` VARCHAR(1024) NULL,
    `eccn_code` VARCHAR(1024) NULL,
    `aec_q_level` VARCHAR(128) NULL,
    `lead_free` TINYINT NULL,
    `msl_level` VARCHAR(128) NULL,
    `package_case` VARCHAR(1024) NULL,
    `temp_min_c` DOUBLE NULL,
    `temp_max_c` DOUBLE NULL,
    `antenna_type` VARCHAR(128) NULL,
    `freq_min_mhz` DOUBLE NULL,
    `freq_max_mhz` DOUBLE NULL,
    `impedance_ohm` DOUBLE NULL,
    `vswr_max` DOUBLE NULL,
    `peak_gain_dbi` DOUBLE NULL,
    `polarization_type` VARCHAR(128) NULL,
    `pkg_length_mm` DOUBLE NULL,
    `pkg_width_mm` DOUBLE NULL,
    `pkg_height_mm` DOUBLE NULL,
    `radiation_pattern_type` VARCHAR(128) NULL,
    `ext_attributes` JSON NULL,
    `semantic_tags` JSON NULL,
    `dq_score` DOUBLE NULL,
    `dq_flags` JSON NULL,
    `source_id` BIGINT NULL,
    `create_at` DATETIME NULL DEFAULT CURRENT_TIMESTAMP,
    `update_at` DATETIME NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE = OLAP
PRIMARY KEY (`data_source`, `id`)
COMMENT 'rf_wireless / rf_antenna L2 宽表'
DISTRIBUTED BY HASH(`id`) BUCKETS 8
PROPERTIES ("replication_num" = "1", "enable_persistent_index" = "true");
