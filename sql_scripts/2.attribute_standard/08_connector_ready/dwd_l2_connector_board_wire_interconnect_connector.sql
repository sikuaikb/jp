/* dwd.dwd_l2_connector_board_wire_interconnect_connector
 * l1_code=connector · scope_level=l2 · scope_code=board_wire_interconnect_connector */
DROP TABLE IF EXISTS dwd.dwd_l2_connector_board_wire_interconnect_connector;

CREATE TABLE dwd.dwd_l2_connector_board_wire_interconnect_connector (
    `data_source` VARCHAR(32) NOT NULL DEFAULT 'digikey',
    `id` BIGINT NOT NULL,
    `mpn` VARCHAR(1024) NULL,
    `brand` VARCHAR(256) NULL,
    `brandid` BIGINT NULL,
    `l1_code` VARCHAR(32) NOT NULL,
    `l2_code` VARCHAR(64) NOT NULL,
    `l3_code` VARCHAR(64) NULL,
    `manufacturer` VARCHAR(1024) NULL,
    `rohs_compliant` TINYINT NULL,
    `lifecycle_status` VARCHAR(1024) NULL,
    `reach` VARCHAR(1024) NULL,
    `eccn_code` VARCHAR(1024) NULL,
    `htsus_code` VARCHAR(1024) NULL,
    `packaging_options_raw` VARCHAR(1024) NULL,
    `lead_free` TINYINT NULL,
    `msl_level` VARCHAR(1024) NULL,
    `temp_min_c` DOUBLE NULL,
    `temp_max_c` DOUBLE NULL,
    `contact_pitch_mm` DOUBLE NULL,
    `row_count` INT NULL,
    `contact_count` INT NULL,
    `current_rating_a` DOUBLE NULL,
    `voltage_rating_v` DOUBLE NULL,
    `mounting_style` VARCHAR(1024) NULL,
    `contact_plating` VARCHAR(1024) NULL,
    `connector_series` VARCHAR(1024) NULL,
    `base_product_number` VARCHAR(1024) NULL,
    `flammability_rating` VARCHAR(1024) NULL,
    `termination_type` VARCHAR(1024) NULL,
    `ext_attributes` JSON NULL,
    `semantic_tags` JSON NULL,
    `dq_score` DOUBLE NULL,
    `dq_flags` JSON NULL,
    `source_id` BIGINT NULL,
    `create_at` DATETIME NULL DEFAULT CURRENT_TIMESTAMP,
    `update_at` DATETIME NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE = OLAP
PRIMARY KEY (`data_source`, `id`)
COMMENT 'connector / board_wire_interconnect_connector L2 宽表'
DISTRIBUTED BY HASH(`id`) BUCKETS 16
PROPERTIES ("replication_num" = "1", "enable_persistent_index" = "true");
