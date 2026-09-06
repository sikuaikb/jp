/* dwd.dwd_l2_optoelectronics_light_emitter */
DROP TABLE IF EXISTS dwd.dwd_l2_optoelectronics_light_emitter;

CREATE TABLE dwd.dwd_l2_optoelectronics_light_emitter (
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
    `lifecycle_status` VARCHAR(1024) NULL,
    `reach` VARCHAR(1024) NULL,
    `eccn_code` VARCHAR(1024) NULL,
    `aec_q_level` VARCHAR(1024) NULL,
    `lead_free` TINYINT NULL,
    `msl_level` VARCHAR(1024) NULL,
    `package_case` VARCHAR(1024) NULL,
    `pkg_length_mm` DOUBLE NULL,
    `pkg_width_mm` DOUBLE NULL,
    `pkg_height_mm` DOUBLE NULL,
    `temp_min_c` DOUBLE NULL,
    `temp_max_c` DOUBLE NULL,
    `peak_wavelength_nm` DOUBLE NULL,
    `forward_voltage_v` DOUBLE NULL,
    `forward_current_ma` DOUBLE NULL,
    `optical_power_mw` DOUBLE NULL,
    `emission_color` VARCHAR(1024) NULL,
    `ext_attributes` JSON NULL,
    `semantic_tags` JSON NULL,
    `dq_score` DOUBLE NULL,
    `dq_flags` JSON NULL,
    `source_id` BIGINT NULL,
    `create_at` DATETIME NULL DEFAULT CURRENT_TIMESTAMP,
    `update_at` DATETIME NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE = OLAP
PRIMARY KEY (`data_source`, `id`)
COMMENT 'optoelectronics / light_emitter L2 宽表'
DISTRIBUTED BY HASH(`id`) BUCKETS 16
PROPERTIES ("replication_num" = "1", "enable_persistent_index" = "true");
