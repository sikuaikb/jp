/* DWD L2 / EMI抑制电感 (emi_filter_inductor) */
DROP TABLE IF EXISTS dwd.dwd_l2_emi_filter_inductor_inductor;
DROP TABLE IF EXISTS dwd.dwd_l2_emi_filter_inductor_base;
DROP TABLE IF EXISTS dwd.dwd_l2_inductor_emi_filter_inductor_base;
DROP TABLE IF EXISTS dwd.dwd_l2_inductor_emi_filter_inductor;
CREATE TABLE dwd.dwd_l2_inductor_emi_filter_inductor (
    `data_source` VARCHAR(32) NOT NULL DEFAULT 'icpdf' COMMENT '数据来源：icpdf | digikey',
    `id` BIGINT NOT NULL COMMENT '组件 ID',
    `mpn` VARCHAR(1024) NULL COMMENT '制造商料号',
    `brand` VARCHAR(256) NULL COMMENT '品牌（标准化，dim.v_std_brand_alias）',
    `brandid` BIGINT NULL COMMENT '品牌 ID',
    `l1_code` VARCHAR(32) NOT NULL,
    `l2_code` VARCHAR(32) NOT NULL COMMENT 'emi_filter_inductor',
    `l3_code` VARCHAR(64) NULL,
    `temp_min_c` DOUBLE NULL,
    `temp_max_c` DOUBLE NULL,
    `rated_current_ma` DOUBLE NULL,
    `dcr_max_mohm` DOUBLE NULL,
    `impedance_nom_ohm` DOUBLE NULL,
    `impedance_test_freq_mhz` DOUBLE NULL,
    `package_case` VARCHAR(256) NULL,
    `mounting_style` VARCHAR(256) NULL,
    `pkg_length_mm` DOUBLE NULL,
    `pkg_width_mm` DOUBLE NULL,
    `pkg_height_mm` DOUBLE NULL,
    `rohs_compliant` BOOLEAN NULL,
    `reach` BOOLEAN NULL,
    `aec_q_level` VARCHAR(256) NULL,
    `lead_free` BOOLEAN NULL,
    `msl_level` VARCHAR(256) NULL,
    `manufacturer` VARCHAR(1024) NULL,
    `lifecycle_status` VARCHAR(256) NULL,
    `eccn_code` VARCHAR(256) NULL,
    `ext_attributes` JSON NULL,
    `semantic_tags` JSON NULL,
    `dq_score` DOUBLE NULL,
    `dq_flags` JSON NULL,
    `source_id` BIGINT NULL,
    `create_at` DATETIME NULL DEFAULT CURRENT_TIMESTAMP,
    `update_at` DATETIME NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=OLAP
PRIMARY KEY(`data_source`, `id`)
COMMENT 'DWD L2 EMI抑制电感 (emi_filter_inductor)宽表'
DISTRIBUTED BY HASH(`id`) BUCKETS 16
PROPERTIES ("replication_num" = "1", "enable_persistent_index" = "true");
