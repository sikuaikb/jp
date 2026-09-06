/* Capacitor sandbox DDL -> dwd.dwd_l2_capacitor_supercapacitor */
/* ============================================================
 * DWD L2 / 超级电容 (supercapacitor)
 *
 * L2 物理列与 dim.dim_attr_schema · scope_code=supercapacitor 对齐；
 * L3：edlc / lithium_ion_capacitor。
 *
 * 品牌标准化 + manufacturer EAV-only。
 * ============================================================ */

CREATE TABLE IF NOT EXISTS dwd.dwd_l2_capacitor_supercapacitor (
    `data_source`                     VARCHAR(32)     NOT NULL DEFAULT 'icpdf' COMMENT '数据来源：icpdf | digikey | mouser ...',
    `id`                          BIGINT          NOT NULL COMMENT '组件唯一ID',
    `mpn`                         VARCHAR(1024)   NULL,
    `brand`                       VARCHAR(256)    NULL     COMMENT '标准品牌名',
    `brandid`                     BIGINT          NULL     COMMENT '标准品牌 ID',

    `l1_code`                     VARCHAR(32)     NOT NULL,
    `l2_code`                     VARCHAR(32)     NOT NULL COMMENT 'L2：supercapacitor',
    `l3_code`                     VARCHAR(64)     NULL,

    `manufacturer`                VARCHAR(1024)   NULL     COMMENT 'EAV 抽取',
    `rohs_compliant`              TINYINT     NULL,
    `lifecycle_status`            VARCHAR(64)     NULL,
    `reach`                       VARCHAR(64)     NULL,
    `eccn_code`                   VARCHAR(128)    NULL,
    `aec_q_level`                 VARCHAR(64)     NULL,
    `lead_free`                   TINYINT     NULL,
    `msl_level`                   VARCHAR(1024)   NULL,
    `package_case`                VARCHAR(1024)   NULL,
    `mounting_style`              VARCHAR(128)    NULL     COMMENT '安装工艺：smd / through_hole / chassis / panel / other',
    `temp_min_c`                  DOUBLE          NULL,
    `temp_max_c`                  DOUBLE          NULL,
    `pkg_length_mm`               DOUBLE          NULL,
    `pkg_width_mm`                DOUBLE          NULL,
    `pkg_height_mm`               DOUBLE          NULL,
    `voltage_rated_v`             DOUBLE          NULL     COMMENT '额定电压 V',
    `capacitance_f`               DOUBLE          NULL     COMMENT '电容量 F',
    `esr_max_mohm`                DOUBLE          NULL     COMMENT '最大 ESR mΩ',
    `leakage_current_max_ua`      DOUBLE          NULL     COMMENT '最大漏电流 µA',
    `capacitance_tolerance_pct`   VARCHAR(64)     NULL     COMMENT '容值公差（同事 schema 此处为 VARCHAR）',
    `storage_mechanism`           VARCHAR(64)     NULL     COMMENT '储能机制（EDLC / pseudocap / hybrid 等）',
    `electrode_material_system`   VARCHAR(256)    NULL     COMMENT '电极材料体系',

    `ext_attributes`              JSON            NULL,
    `semantic_tags`               JSON            NULL,
    `dq_score`                    DOUBLE          NULL,
    `dq_flags`                    JSON            NULL,

    `source_id`                   BIGINT          NULL,

    `create_at`                   DATETIME        NULL     DEFAULT CURRENT_TIMESTAMP,
    `update_at`                   DATETIME        NULL     DEFAULT CURRENT_TIMESTAMP
) ENGINE=OLAP
PRIMARY KEY(`data_source`, `id`)
COMMENT 'DWD L2 超级电容宽表'
DISTRIBUTED BY HASH(`id`) BUCKETS 16
PROPERTIES (
    "compression"             = "ZSTD",
    "datacache.enable"        = "true",
    "replication_num" = "3",
    "enable_persistent_index" = "true"
);
