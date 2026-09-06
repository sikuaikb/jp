/* prod digikey 单源 → dwd.dwd_l2_interface_communication_ic_level_shifter_signal_conditioning */
/* dwd.dwd_l2_interface_communication_ic_level_shifter_signal_conditioning — interface_communication_ic / level_shifter_signal_conditioning */
DROP TABLE IF EXISTS dwd.dwd_l2_interface_communication_ic_level_shifter_signal_conditioning;

CREATE TABLE dwd.dwd_l2_interface_communication_ic_level_shifter_signal_conditioning (
    `data_source` VARCHAR(32) NOT NULL DEFAULT 'digikey',
    `id` BIGINT NOT NULL,
    `mpn` VARCHAR(1024) NULL,
    `brand` VARCHAR(256) NULL,
    `brandid` BIGINT NULL,
    `l1_code` VARCHAR(64) NOT NULL,
    `l2_code` VARCHAR(96) NOT NULL,
    `l3_code` VARCHAR(96) NULL,
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
    `vcca_min_v` DOUBLE NULL,
    `vcca_max_v` DOUBLE NULL,
    `vccb_min_v` DOUBLE NULL,
    `vccb_max_v` DOUBLE NULL,
    `channel_count` INT NULL,
    `data_rate_max_mbps` DOUBLE NULL,
    `ext_attributes` JSON NULL,
    `semantic_tags` JSON NULL,
    `dq_score` DOUBLE NULL,
    `dq_flags` JSON NULL,
    `source_id` BIGINT NULL,
    `create_at` DATETIME NULL DEFAULT CURRENT_TIMESTAMP,
    `update_at` DATETIME NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=OLAP
PRIMARY KEY (`data_source`, `id`)
COMMENT 'interface_communication_ic / level_shifter_signal_conditioning L2 宽表'
DISTRIBUTED BY HASH(`id`) BUCKETS 16
PROPERTIES ("replication_num" = "1", "enable_persistent_index" = "true");
