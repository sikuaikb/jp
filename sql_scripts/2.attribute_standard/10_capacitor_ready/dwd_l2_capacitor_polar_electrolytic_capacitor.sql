/* Capacitor sandbox DDL -> dwd.dwd_l2_capacitor_polar_electrolytic_capacitor */
/* ============================================================
 * DWD L2 / 极性/电解电容器 (polar_electrolytic_capacitor)
 *
 * L2 物理列与 dim.dim_attr_schema · scope_code=polar_electrolytic_capacitor 对齐；
 * L3：aluminum_electrolytic_capacitor / solid_electrolytic_capacitor。
 *
 * 品牌标准化 + manufacturer EAV-only。
 * ============================================================ */

CREATE TABLE IF NOT EXISTS dwd.dwd_l2_capacitor_polar_electrolytic_capacitor (
    `data_source`                     VARCHAR(32)     NOT NULL DEFAULT 'icpdf' COMMENT '数据来源：icpdf | digikey | mouser ...',
    `id`                          BIGINT          NOT NULL COMMENT '组件唯一ID',
    `mpn`                         VARCHAR(1024)   NULL,
    `brand`                       VARCHAR(256)    NULL     COMMENT '标准品牌名',
    `brandid`                     BIGINT          NULL     COMMENT '标准品牌 ID',

    `l1_code`                     VARCHAR(32)     NOT NULL,
    `l2_code`                     VARCHAR(32)     NOT NULL COMMENT 'L2：polar_electrolytic_capacitor',
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
    `capacitance_f`               DOUBLE          NULL     COMMENT '电容量 F',
    `rated_voltage_v`             DOUBLE          NULL     COMMENT '额定电压 V',
    `capacitance_tolerance_pct`   DOUBLE          NULL     COMMENT '容值公差 %',
    `esr_max_mohm`                DOUBLE          NULL     COMMENT '最大等效串联电阻 mΩ',
    `leakage_current_max_ua`      DOUBLE          NULL     COMMENT '最大漏电流 µA',
    `ripple_current_ma`           DOUBLE          NULL     COMMENT '纹波电流 mA',

    `ext_attributes`              JSON            NULL,
    `semantic_tags`               JSON            NULL,
    `dq_score`                    DOUBLE          NULL,
    `dq_flags`                    JSON            NULL,

    `source_id`                   BIGINT          NULL,

    `create_at`                   DATETIME        NULL     DEFAULT CURRENT_TIMESTAMP,
    `update_at`                   DATETIME        NULL     DEFAULT CURRENT_TIMESTAMP
) ENGINE=OLAP
PRIMARY KEY(`data_source`, `id`)
COMMENT 'DWD L2 极性/电解电容器宽表'
DISTRIBUTED BY HASH(`id`) BUCKETS 16
PROPERTIES (
    "compression"             = "ZSTD",
    "datacache.enable"        = "true",
    "replication_num" = "3",
    "enable_persistent_index" = "true"
);
