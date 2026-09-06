/* test_dwd.dwd_l2_logic_ic_signal_buffer_driver */
DROP TABLE IF EXISTS test_dwd.dwd_l2_logic_ic_signal_buffer_driver;

CREATE TABLE test_dwd.dwd_l2_logic_ic_signal_buffer_driver (
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
    `lead_free` TINYINT NULL,
    `msl_level` VARCHAR(128) NULL,
    `package_case` VARCHAR(1024) NULL,
    `mount_type` VARCHAR(1024) NULL,
    `temp_min_c` DOUBLE NULL,
    `temp_max_c` DOUBLE NULL,
    `supply_voltage_min_v` DOUBLE NULL,
    `supply_voltage_max_v` DOUBLE NULL,
    `propagation_delay_ns` DOUBLE NULL,
    `output_current_high_low` VARCHAR(1024) NULL,
    `logic_series` VARCHAR(1024) NULL,
    `ext_attributes` JSON NULL,
    `semantic_tags` JSON NULL,
    `dq_score` DOUBLE NULL,
    `dq_flags` JSON NULL,
    `source_id` BIGINT NULL,
    `create_at` DATETIME NULL DEFAULT CURRENT_TIMESTAMP,
    `update_at` DATETIME NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE = OLAP
PRIMARY KEY (`data_source`, `id`)
COMMENT 'logic_ic / signal_buffer_driver L2 宽表'
DISTRIBUTED BY HASH(`id`) BUCKETS 16
PROPERTIES ("replication_num" = "1", "enable_persistent_index" = "true");
