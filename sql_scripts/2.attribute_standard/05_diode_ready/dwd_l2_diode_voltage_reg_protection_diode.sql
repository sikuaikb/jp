/* ============================================================
 * DWD L2 / 稳压与保护二极管 (voltage_reg_protection_diode)
 *
 * 物理列与 dim.dim_attr_schema · scope_code=voltage_reg_protection_diode 对齐；
 * L3：zener_diode / tvs_diode / diac_trigger_diode → ext_attributes JSON。
 *
 * diode_type 列：由 c.l3_code 直接推断（不在 EAV，schema 设计 ENUM）。
 *
 * 品牌标准化：brand / brandid 来自 dim.v_std_brand_alias 命中。
 *
 * 装配 SQL：build_dwd_l2_diode_voltage_reg_protection_diode.sql
 * ============================================================ */

DROP TABLE IF EXISTS dwd.dwd_l2_diode_voltage_reg_protection_diode;

CREATE TABLE dwd.dwd_l2_diode_voltage_reg_protection_diode (
    `data_source`                     VARCHAR(32)     NOT NULL DEFAULT 'icpdf' COMMENT '数据来源：icpdf | digikey | mouser ...',
    `id`                       BIGINT          NOT NULL COMMENT '组件唯一ID',
    `mpn`                      VARCHAR(1024)   NULL     COMMENT '制造商料号',
    `brand`                    VARCHAR(256)    NULL     COMMENT '标准品牌名',
    `brandid`                  BIGINT          NULL     COMMENT '标准品牌 ID',

    `l1_code`                  VARCHAR(32)     NOT NULL COMMENT 'L1：diode',
    `l2_code`                  VARCHAR(32)     NOT NULL COMMENT 'L2：voltage_reg_protection_diode',
    `l3_code`                  VARCHAR(64)     NULL     COMMENT 'L3：zener_diode / tvs_diode / diac_trigger_diode',

    `manufacturer`             VARCHAR(1024)   NULL     COMMENT '制造商（EAV 抽取）',
    `rohs_compliant`           BOOLEAN         NULL,
    `lifecycle_status`         VARCHAR(64)     NULL,
    `reach`                    BOOLEAN         NULL,
    `eccn_code`                VARCHAR(128)    NULL,
    `aec_q_level`              VARCHAR(64)     NULL,
    `lead_free`                BOOLEAN         NULL,
    `msl_level`                VARCHAR(1024)   NULL,
    `package_case`             VARCHAR(1024)   NULL,
    `pkg_length_mm`            DOUBLE          NULL,
    `pkg_width_mm`             DOUBLE          NULL,
    `pkg_height_mm`            DOUBLE          NULL,
    `temp_min_c`               DOUBLE          NULL,
    `temp_max_c`               DOUBLE          NULL,
    `diode_type`               VARCHAR(64)     NULL     COMMENT 'L3 路由 ENUM（Zener_Diode / TVS_Diode / DIAC_Trigger_Diode）',
    `power_dissipation_max_w`  DOUBLE          NULL     COMMENT '最大额定功耗 W',
    `ir_max_ua`                DOUBLE          NULL     COMMENT '最大反向漏电流 uA',
    `breakdown_voltage_v`      DOUBLE          NULL     COMMENT '击穿/稳压电压 V',
    `clamping_voltage_max_v`   DOUBLE          NULL     COMMENT '最大钳位电压 V',
    `peak_pulse_power_w`       DOUBLE          NULL     COMMENT '峰值脉冲功率 W',

    `ext_attributes`           JSON            NULL,
    `semantic_tags`            JSON            NULL,

    `dq_score`                 DOUBLE          NULL,
    `dq_flags`                 JSON            NULL,

    `source_id`                BIGINT          NULL,

    `create_at`                DATETIME        NULL     DEFAULT CURRENT_TIMESTAMP,
    `update_at`                DATETIME        NULL     DEFAULT CURRENT_TIMESTAMP
) ENGINE=OLAP
PRIMARY KEY(`data_source`, `id`)
COMMENT 'DWD L2 稳压与保护二极管宽表'
DISTRIBUTED BY HASH(`id`) BUCKETS 16
PROPERTIES (
    "compression"             = "ZSTD",
    "datacache.enable"        = "true",
    "replication_num"         = "1",
    "enable_persistent_index" = "true"
);
