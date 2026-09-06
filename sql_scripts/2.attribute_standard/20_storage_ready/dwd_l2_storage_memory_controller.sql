/* prod DDL: dwd.dwd_l2_storage_memory_controller */
CREATE TABLE IF NOT EXISTS dwd.dwd_l2_storage_memory_controller (
    `data_source` VARCHAR(32) NOT NULL,
    `id` BIGINT NOT NULL,
    `mpn` VARCHAR(1024) NULL,
    `brand` VARCHAR(256) NULL,
    `brandid` BIGINT NULL,
    `l1_code` VARCHAR(96) NOT NULL,
    `l2_code` VARCHAR(96) NOT NULL,
    `l3_code` VARCHAR(96) NULL,
    `brandshort` VARCHAR(1024) NULL,
    `l3_id` INT NULL,
    `manufacturer` VARCHAR(1024) NULL,
    `rohs_compliant` TINYINT NULL,
    `lifecycle_status` VARCHAR(128) NULL,
    `reach` VARCHAR(1024) NULL,
    `eccn_code` VARCHAR(1024) NULL,
    `htsus_code` VARCHAR(128) NULL,
    `aec_q_level` VARCHAR(128) NULL,
    `lead_free` TINYINT NULL,
    `msl_level` VARCHAR(128) NULL,
    `package_case` VARCHAR(1024) NULL,
    `temp_min_c` DOUBLE NULL,
    `temp_max_c` DOUBLE NULL,
    `host_interface_type` VARCHAR(128) NULL,
    `max_data_rate_mbps` DOUBLE NULL,
    `supply_voltage_min_v` DOUBLE NULL,
    `supply_voltage_max_v` DOUBLE NULL,
    `ext_attributes` JSON NULL,
    `semantic_tags` JSON NULL,
    `dq_score` DOUBLE NULL,
    `dq_flags` JSON NULL,
    `source_id` BIGINT NULL,
    `create_at` DATETIME NULL DEFAULT CURRENT_TIMESTAMP,
    `update_at` DATETIME NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE = OLAP
PRIMARY KEY (`data_source`, `id`)
COMMENT 'storage / memory_controller L2 wide (multi-source)'
DISTRIBUTED BY HASH(`id`) BUCKETS 16
PROPERTIES ("replication_num" = "1", "enable_persistent_index" = "true");
