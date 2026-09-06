/* Capacitor sandbox DDL -> dwd.dwd_l2_capacitor_variable_capacitor */
/* ============================================================
 * DWD L2 / 可调电容 (variable_capacitor)
 *
 * L2 物理列与 dim.dim_attr_schema · scope_code=variable_capacitor 对齐；
 * L3：adjustable_capacitor。
 *
 * 品牌标准化 + manufacturer EAV-only。
 * ============================================================ */

CREATE TABLE IF NOT EXISTS dwd.dwd_l2_capacitor_variable_capacitor (
    `data_source`                     VARCHAR(32)     NOT NULL DEFAULT 'icpdf' COMMENT '数据来源：icpdf | digikey | mouser ...',
    `id`                  BIGINT          NOT NULL COMMENT '组件唯一ID',
    `mpn`                 VARCHAR(1024)   NULL,
    `brand`               VARCHAR(256)    NULL     COMMENT '标准品牌名',
    `brandid`             BIGINT          NULL     COMMENT '标准品牌 ID',

    `l1_code`             VARCHAR(32)     NOT NULL,
    `l2_code`             VARCHAR(32)     NOT NULL COMMENT 'L2：variable_capacitor',
    `l3_code`             VARCHAR(64)     NULL,

    `manufacturer`        VARCHAR(1024)   NULL     COMMENT 'EAV 抽取',
    `rohs_compliant`      TINYINT     NULL,
    `lifecycle_status`    VARCHAR(64)     NULL,
    `reach`               VARCHAR(64)     NULL,
    `eccn_code`           VARCHAR(128)    NULL,
    `aec_q_level`         VARCHAR(64)     NULL,
    `lead_free`           TINYINT     NULL,
    `msl_level`           VARCHAR(1024)   NULL,
    `package_case`        VARCHAR(1024)   NULL,
    `mounting_style`      VARCHAR(128)    NULL     COMMENT '安装工艺：smd / through_hole / chassis / panel / other',
    `temp_min_c`          DOUBLE          NULL,
    `temp_max_c`          DOUBLE          NULL,
    `pkg_length_mm`       DOUBLE          NULL,
    `pkg_width_mm`        DOUBLE          NULL,
    `pkg_height_mm`       DOUBLE          NULL,
    `capacitance_min_pf`  DOUBLE          NULL     COMMENT '最小电容量 pF',
    `capacitance_max_pf`  DOUBLE          NULL     COMMENT '最大电容量 pF',
    `voltage_rated_v`     DOUBLE          NULL     COMMENT '额定电压 V',
    `q_factor`            DOUBLE          NULL     COMMENT '品质因数 Q',
    `capacitance_ratio`   DOUBLE          NULL     COMMENT '容值比',
    `dielectric_material` VARCHAR(256)    NULL     COMMENT '介电材料',

    `ext_attributes`      JSON            NULL,
    `semantic_tags`       JSON            NULL,
    `dq_score`            DOUBLE          NULL,
    `dq_flags`            JSON            NULL,

    `source_id`           BIGINT          NULL,

    `create_at`           DATETIME        NULL     DEFAULT CURRENT_TIMESTAMP,
    `update_at`           DATETIME        NULL     DEFAULT CURRENT_TIMESTAMP
) ENGINE=OLAP
PRIMARY KEY(`data_source`, `id`)
COMMENT 'DWD L2 可调电容宽表'
DISTRIBUTED BY HASH(`id`) BUCKETS 16
PROPERTIES (
    "compression"             = "ZSTD",
    "datacache.enable"        = "true",
    "replication_num" = "3",
    "enable_persistent_index" = "true"
);
