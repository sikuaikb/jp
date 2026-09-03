/* dwd.dwd_l2_rf_wireless_rfid_nfc_frontend */
DROP TABLE IF EXISTS dwd.dwd_l2_rf_wireless_rfid_nfc_frontend;

CREATE TABLE dwd.dwd_l2_rf_wireless_rfid_nfc_frontend (
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
    `carrier_freq_mhz` DOUBLE NULL,
    `supported_rf_standards` VARCHAR(1024) NULL,
    `host_interface_type` VARCHAR(1024) NULL,
    `supply_voltage_min_v` DOUBLE NULL,
    `supply_voltage_max_v` DOUBLE NULL,
    `reach` VARCHAR(1024) NULL,
    `temp_min_c` DOUBLE NULL,
    `eccn_code` VARCHAR(1024) NULL,
    `temp_max_c` DOUBLE NULL,
    `aec_q_level` VARCHAR(128) NULL,
    `lifecycle_status` VARCHAR(128) NULL,
    `lead_free` TINYINT NULL,
    `rohs_compliant` TINYINT NULL,
    `msl_level` VARCHAR(128) NULL,
    `package_case` VARCHAR(1024) NULL,
    `freq_min_mhz` DOUBLE NULL,
    `freq_max_mhz` DOUBLE NULL,
    `mounting_style` VARCHAR(128) NULL,
    `ext_attributes` JSON NULL,
    `semantic_tags` JSON NULL,
    `dq_score` DOUBLE NULL,
    `dq_flags` JSON NULL,
    `source_id` BIGINT NULL,
    `create_at` DATETIME NULL DEFAULT CURRENT_TIMESTAMP,
    `update_at` DATETIME NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE = OLAP
PRIMARY KEY (`data_source`, `id`)
COMMENT 'rf_wireless / rfid_nfc_frontend L2 宽表'
DISTRIBUTED BY HASH(`id`) BUCKETS 8
PROPERTIES ("replication_num" = "1", "enable_persistent_index" = "true");
