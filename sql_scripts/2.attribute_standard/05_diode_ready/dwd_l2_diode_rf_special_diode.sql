/* ============================================================
 * DWD L2 / 射频与特殊二极管 (rf_special_diode)
 *
 * 物理列与 dim.dim_attr_schema · scope_code=rf_special_diode 对齐；
 * L3：pin_diode / varactor_diode / mixer_diode / step_recovery_diode → ext_attributes JSON。
 *
 * 注：RF schema 无 pkg_*_mm / diode_type；多 frequency_max_mhz / junction_capacitance_pf。
 *
 * 品牌标准化：brand / brandid 来自 dim.v_std_brand_alias 命中。
 *
 * 装配 SQL：build_dwd_l2_diode_rf_special_diode.sql
 * ============================================================ */

DROP TABLE IF EXISTS dwd.dwd_l2_diode_rf_special_diode;

CREATE TABLE dwd.dwd_l2_diode_rf_special_diode (
    `data_source`                     VARCHAR(32)     NOT NULL DEFAULT 'icpdf' COMMENT '数据来源：icpdf | digikey | mouser ...',
    `id`                          BIGINT          NOT NULL COMMENT '组件唯一ID',
    `mpn`                         VARCHAR(1024)   NULL     COMMENT '制造商料号',
    `brand`                       VARCHAR(256)    NULL     COMMENT '标准品牌名',
    `brandid`                     BIGINT          NULL     COMMENT '标准品牌 ID',

    `l1_code`                     VARCHAR(32)     NOT NULL COMMENT 'L1：diode',
    `l2_code`                     VARCHAR(32)     NOT NULL COMMENT 'L2：rf_special_diode',
    `l3_code`                     VARCHAR(64)     NULL     COMMENT 'L3 形态编码',

    `manufacturer`                VARCHAR(1024)   NULL     COMMENT '制造商（EAV 抽取）',
    `rohs_compliant`              BOOLEAN         NULL,
    `lifecycle_status`            VARCHAR(64)     NULL,
    `reach`                       BOOLEAN         NULL,
    `eccn_code`                   VARCHAR(128)    NULL,
    `aec_q_level`                 VARCHAR(64)     NULL,
    `lead_free`                   BOOLEAN         NULL,
    `msl_level`                   VARCHAR(1024)   NULL,
    `package_case`                VARCHAR(1024)   NULL,
    `temp_min_c`                  DOUBLE          NULL,
    `temp_max_c`                  DOUBLE          NULL,
    `breakdown_voltage_v`         DOUBLE          NULL     COMMENT '反向击穿电压 V',
    `if_max_ma`                   DOUBLE          NULL     COMMENT '最大正向电流 mA',
    `power_dissipation_max_mw`    DOUBLE          NULL     COMMENT '最大耗散功率 mW',
    `reverse_leakage_current_ua`  DOUBLE          NULL     COMMENT '最大反向漏电流 uA',
    `junction_capacitance_pf`     DOUBLE          NULL     COMMENT '零偏结电容 pF',
    `frequency_max_mhz`           DOUBLE          NULL     COMMENT '最大工作频率 MHz',

    `ext_attributes`              JSON            NULL,
    `semantic_tags`               JSON            NULL,

    `dq_score`                    DOUBLE          NULL,
    `dq_flags`                    JSON            NULL,

    `source_id`                   BIGINT          NULL,

    `create_at`                   DATETIME        NULL     DEFAULT CURRENT_TIMESTAMP,
    `update_at`                   DATETIME        NULL     DEFAULT CURRENT_TIMESTAMP
) ENGINE=OLAP
PRIMARY KEY(`data_source`, `id`)
COMMENT 'DWD L2 射频与特殊二极管宽表'
DISTRIBUTED BY HASH(`id`) BUCKETS 16
PROPERTIES (
    "compression"             = "ZSTD",
    "datacache.enable"        = "true",
    "replication_num"         = "1",
    "enable_persistent_index" = "true"
);
