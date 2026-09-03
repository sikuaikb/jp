/* prod digikey 单源 → dwd.dwd_l2_driver_ic_gate_driver */
/* dwd.dwd_l2_driver_ic_gate_driver */
DROP TABLE IF EXISTS dwd.dwd_l2_driver_ic_gate_driver;
CREATE TABLE dwd.dwd_l2_driver_ic_gate_driver (
    `data_source` VARCHAR(32) NOT NULL DEFAULT 'digikey',
    `id` BIGINT NOT NULL,
    `mpn` VARCHAR(1024) NULL,
    `brand` VARCHAR(256) NULL,
    `brandid` BIGINT NULL,
    `l1_code` VARCHAR(32) NOT NULL,
    `l2_code` VARCHAR(32) NOT NULL COMMENT 'gate_driver',
    `l3_code` VARCHAR(64) NULL,
    `manufacturer` VARCHAR(1024) NULL,
    `rohs_compliant` TINYINT NULL,
    `reach` VARCHAR(1024) NULL,
    `lead_free` TINYINT NULL,
    `aec_q_level` VARCHAR(1024) NULL,
    `msl_level` VARCHAR(1024) NULL,
    `lifecycle_status` VARCHAR(1024) NULL,
    `eccn_code` VARCHAR(1024) NULL,
    `package_case` VARCHAR(1024) NULL,
    `pkg_length_mm` DOUBLE NULL,
    `pkg_width_mm` DOUBLE NULL,
    `pkg_height_mm` DOUBLE NULL,
    `temp_min_c` DOUBLE NULL,
    `temp_max_c` DOUBLE NULL,
    `peak_source_current_ma` DOUBLE NULL,
    `peak_sink_current_ma` DOUBLE NULL,
    `vcc_min_v` DOUBLE NULL,
    `vcc_max_v` DOUBLE NULL,
    `input_logic_level` VARCHAR(1024) NULL,
    `propagation_delay_ns` DOUBLE NULL,
    `driver_topology` VARCHAR(1024) NULL,
    `mounting_style` VARCHAR(128) NULL,
    `ext_attributes` JSON NULL,
    `semantic_tags` JSON NULL,
    `dq_score` DOUBLE NULL,
    `dq_flags` JSON NULL,
    `source_id` BIGINT NULL,
    `create_at` DATETIME NULL DEFAULT CURRENT_TIMESTAMP,
    `update_at` DATETIME NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=OLAP PRIMARY KEY(`data_source`, `id`)
COMMENT 'DWD L2 gate_driver（驱动IC沙盒）'
DISTRIBUTED BY HASH(`id`) BUCKETS 16
PROPERTIES ("replication_num" = "1", "enable_persistent_index" = "true");
