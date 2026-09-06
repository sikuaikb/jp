/* Capacitor sandbox DDL -> dwd.dwd_l2_capacitor_non_polar_fixed_capacitor */
/* ============================================================
 * DWD L2 / 无极性固定电容器 (non_polar_fixed_capacitor)
 *
 * 物理列与 dim.dim_attr_schema 对齐：
 *   schema_version=capacitor_schema_v1.5.09 · l1_code=capacitor ·
 *   scope_level=l2 · scope_code=non_polar_fixed_capacitor
 *
 * L3：ceramic_capacitor / film_capacitor / mica_capacitor
 * 注：当前 dim_attr_schema_capacitor 无 L3 entries，ext_attributes 暂为空 JSON（{}）。
 *
 * 品牌标准化（与电阻/二极管一致）：brand/brandid 由 dim.v_std_brand_alias 命中后写回；未命中回退 raw。
 * manufacturer 保持 EAV-only（不与 brand 兜底）。
 * 注：rohs_compliant / reach / lead_free 在 capacitor schema 中 db_type=VARCHAR，存原文枚举。
 * ============================================================ */

CREATE TABLE IF NOT EXISTS dwd.dwd_l2_capacitor_non_polar_fixed_capacitor (
    `data_source`                     VARCHAR(32)     NOT NULL DEFAULT 'icpdf' COMMENT '数据来源：icpdf | digikey | mouser ...',
    `id`                              BIGINT          NOT NULL COMMENT '组件唯一ID',
    `mpn`                             VARCHAR(1024)   NULL     COMMENT '制造商料号',
    `brand`                           VARCHAR(256)    NULL     COMMENT '标准品牌名',
    `brandid`                         BIGINT          NULL     COMMENT '标准品牌 ID',

    `l1_code`                         VARCHAR(32)     NOT NULL COMMENT 'L1：capacitor',
    `l2_code`                         VARCHAR(32)     NOT NULL COMMENT 'L2：non_polar_fixed_capacitor',
    `l3_code`                         VARCHAR(64)     NULL     COMMENT 'L3：ceramic_capacitor / film_capacitor / mica_capacitor',

    `manufacturer`                    VARCHAR(1024)   NULL     COMMENT '制造商（EAV 抽取）',
    `rohs_compliant`                  TINYINT     NULL     COMMENT 'RoHS 合规（VARCHAR 原文枚举）',
    `lifecycle_status`                VARCHAR(64)     NULL,
    `reach`                           VARCHAR(64)     NULL,
    `eccn_code`                       VARCHAR(128)    NULL,
    `aec_q_level`                     VARCHAR(64)     NULL,
    `lead_free`                       TINYINT     NULL,
    `msl_level`                       VARCHAR(1024)   NULL,
    `package_case`                    VARCHAR(1024)   NULL,
    `mounting_style`                  VARCHAR(128)    NULL     COMMENT '安装工艺：smd / through_hole / chassis / panel / other',
    `temp_min_c`                      DOUBLE          NULL,
    `temp_max_c`                      DOUBLE          NULL,
    `capacitance_f`                   DOUBLE          NULL     COMMENT '电容量 F',
    `rated_voltage_v`                 DOUBLE          NULL     COMMENT '额定电压 V',
    `capacitance_tolerance_pct`       DOUBLE          NULL     COMMENT '容值公差 %',
    `dielectric_material`             VARCHAR(256)    NULL     COMMENT '介电材料',
    `dissipation_factor_pct`          DOUBLE          NULL     COMMENT '损耗角正切 %',
    `insulation_resistance_min_gohm`  DOUBLE          NULL     COMMENT '最小绝缘电阻 GΩ',

    `ext_attributes`                  JSON            NULL,
    `semantic_tags`                   JSON            NULL,
    `dq_score`                        DOUBLE          NULL,
    `dq_flags`                        JSON            NULL,

    `source_id`                       BIGINT          NULL,

    `create_at`                       DATETIME        NULL     DEFAULT CURRENT_TIMESTAMP,
    `update_at`                       DATETIME        NULL     DEFAULT CURRENT_TIMESTAMP
) ENGINE=OLAP
PRIMARY KEY(`data_source`, `id`)
COMMENT 'DWD L2 无极性固定电容器宽表'
DISTRIBUTED BY HASH(`id`) BUCKETS 16
PROPERTIES (
    "compression"             = "ZSTD",
    "datacache.enable"        = "true",
    "replication_num" = "3",
    "enable_persistent_index" = "true"
);
