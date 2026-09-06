/* dwd.dwd_l2_sensor_pressure_sensor */
DROP TABLE IF EXISTS dwd.dwd_l2_sensor_pressure_sensor;

CREATE TABLE dwd.dwd_l2_sensor_pressure_sensor (
    `data_source` VARCHAR(32) NOT NULL,
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
    `pressure_range_min_kpa` DOUBLE NULL,
    `pressure_range_max_kpa` DOUBLE NULL,
    `output_signal_type` VARCHAR(128) NULL,
    `supply_voltage_v` DOUBLE NULL,
    `accuracy_pct_fso` DOUBLE NULL,
    `overpressure_max_kpa` DOUBLE NULL,
    `pressure_type` VARCHAR(128) NULL,
    `process_connection` VARCHAR(1024) NULL,
    `terminal_style` VARCHAR(1024) NULL,
    `ext_attributes` JSON NULL,
    `semantic_tags` JSON NULL,
    `dq_score` DOUBLE NULL,
    `dq_flags` JSON NULL,
    `source_id` BIGINT NULL,
    `create_at` DATETIME NULL DEFAULT CURRENT_TIMESTAMP,
    `update_at` DATETIME NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE = OLAP
PRIMARY KEY (`data_source`, `id`)
COMMENT 'sensor / pressure_sensor L2 宽表'
DISTRIBUTED BY HASH(`id`) BUCKETS 16
PROPERTIES ("replication_num" = "1", "enable_persistent_index" = "true");
