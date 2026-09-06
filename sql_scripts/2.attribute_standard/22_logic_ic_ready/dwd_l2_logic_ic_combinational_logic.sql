/* ============================================================
 * DWD L2 / combinational_logic
 * l1_code=logic_ic · 逆向合仓自 prod SHOW CREATE TABLE
 * ============================================================ */

DROP TABLE IF EXISTS dwd.dwd_l2_logic_ic_combinational_logic;

CREATE TABLE IF NOT EXISTS dwd.dwd_l2_logic_ic_combinational_logic (
    `data_source`   VARCHAR(32)    NOT NULL COMMENT '数据来源：icpdf | digikey',
    `id`            BIGINT         NOT NULL COMMENT '组件唯一ID',
    `mpn`           VARCHAR(1024)  NULL     COMMENT '制造商料号',
    `brand`         VARCHAR(256)   NULL     COMMENT '标准品牌名',
    `brandid`       BIGINT         NULL     COMMENT '标准品牌ID',
    `l1_code`       VARCHAR(32)    NOT NULL COMMENT 'L1：logic_ic',
    `l2_code`       VARCHAR(96)    NOT NULL COMMENT 'L2：combinational_logic',
    `l3_code`       VARCHAR(96)    NULL     COMMENT 'L3 形态编码',
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
    `mount_type` VARCHAR(128) NULL,
    `temp_min_c` DOUBLE NULL,
    `temp_max_c` DOUBLE NULL,
    `supply_voltage_min_v` DOUBLE NULL,
    `supply_voltage_max_v` DOUBLE NULL,
    `propagation_delay_ns` DOUBLE NULL,
    `output_current_high_low` VARCHAR(128) NULL,
    `logic_series` VARCHAR(128) NULL,
    `ext_attributes` JSON           NULL COMMENT 'L3 专有属性 KV 包',
    `semantic_tags`  JSON           NULL COMMENT '业务标签',
    `dq_score`       DOUBLE         NULL COMMENT '数据质量综合分（预留）',
    `dq_flags`       JSON           NULL COMMENT '数据质量标记（预留）',
    `source_id`      BIGINT         NULL COMMENT '来源表原始 id',
    `create_at`      DATETIME       NULL DEFAULT CURRENT_TIMESTAMP,
    `update_at`      DATETIME       NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=OLAP
PRIMARY KEY(`data_source`, `id`)
COMMENT 'DWD L2 combinational_logic 宽表（logic_ic）'
DISTRIBUTED BY HASH(`id`) BUCKETS 16
PROPERTIES (
    "compression"             = "ZSTD",
    "datacache.enable"        = "true",
    "replication_num"         = "1",
    "enable_persistent_index" = "true"
);
