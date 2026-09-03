/* ============================================================
 * DWD L2 / 保护与敏感电阻器 (protective_sensitive_resistor)
 *
 * L2 物理列与 dim.dim_attr_schema · scope_code=protective_sensitive_resistor 对齐；
 * L3（ntc_thermistor / ptc_thermistor / varistor_mov / fusible_resistor / other_sensitive_resistor）→ ext_attributes JSON。
 *
 * 窄表：dwd.dwd_component_attr_std（build_dwd_component_attr_std_{icpdf,digikey}.sql）
 * 透视：build_dwd_l2_resistor_protective_sensitive_resistor.sql
 * ============================================================ */

DROP TABLE IF EXISTS dwd.dwd_l2_resistor_protective_sensitive_resistor;

CREATE TABLE dwd.dwd_l2_resistor_protective_sensitive_resistor (
    `data_source`                      VARCHAR(32)     NOT NULL DEFAULT 'icpdf' COMMENT '数据来源：icpdf | digikey | mouser ...',
    `id`                        BIGINT          NOT NULL COMMENT '组件唯一ID',
    `mpn`                       VARCHAR(1024)   NULL     COMMENT '制造商料号',
    `brand`                     VARCHAR(256)    NULL     COMMENT '标准品牌名（dim_std_brand.name；未命中字典则回退到 brandshort）',
    `brandid`                   BIGINT          NULL     COMMENT '标准品牌ID（dim_std_brand.brand_id_std；未命中字典则回退到 raw brandid）',

    `l1_code`                   VARCHAR(32)     NOT NULL COMMENT 'L1：resistor',
    `l2_code`                   VARCHAR(32)     NOT NULL COMMENT 'L2：protective_sensitive_resistor',
    `l3_code`                   VARCHAR(64)     NULL     COMMENT 'L3：ntc_thermistor / ptc_thermistor / varistor_mov / fusible_resistor / other_sensitive_resistor',

    `manufacturer`              VARCHAR(1024)   NULL     COMMENT '制造商',
    `rohs_compliant`            BOOLEAN         NULL     COMMENT 'RoHS合规',
    `lifecycle_status`          VARCHAR(64)     NULL     COMMENT '生命周期状态',
    `reach`                     BOOLEAN         NULL     COMMENT 'REACH合规',
    `eccn_code`                 VARCHAR(128)    NULL     COMMENT '出口管制分类号',
    `aec_q_level`               VARCHAR(64)     NULL     COMMENT '汽车级认证等级',
    `lead_free`                 BOOLEAN         NULL     COMMENT '无铅标识',
    `msl_level`                 VARCHAR(1024)   NULL     COMMENT '湿敏等级',
    `package_case`              VARCHAR(1024)   NULL     COMMENT '封装形式',
    `temp_min_c`                DOUBLE          NULL     COMMENT '最低工作温度 ℃',
    `temp_max_c`                DOUBLE          NULL     COMMENT '最高工作温度 ℃',
    `pkg_length_mm`             DOUBLE          NULL     COMMENT '封装体长度 mm',
    `pkg_width_mm`              DOUBLE          NULL     COMMENT '封装体宽度 mm',
    `pkg_height_mm`             DOUBLE          NULL     COMMENT '封装体高度 mm',

    `resistance_25c_ohm`        DOUBLE          NULL     COMMENT '标称阻值（25℃）Ω',
    `resistance_tolerance_pct`  DOUBLE          NULL     COMMENT '阻值公差 %',
    `power_rating_w`            DOUBLE          NULL     COMMENT '额定功率 W',
    `voltage_max_v`             DOUBLE          NULL     COMMENT '最大工作电压 V',

    `ext_attributes`            JSON            NULL     COMMENT 'L3 专有属性',
    `semantic_tags`             JSON            NULL     COMMENT '业务场景标签（预留）',

    `dq_score`                  DOUBLE          NULL     COMMENT '数据质量综合分（预留）',
    `dq_flags`                  JSON            NULL     COMMENT '数据质量标记（预留）',

    `source_id`                 BIGINT          NULL     COMMENT '来源表原始 id',

    `create_at`                 DATETIME        NULL DEFAULT CURRENT_TIMESTAMP COMMENT '入库时间',
    `update_at`                 DATETIME        NULL DEFAULT CURRENT_TIMESTAMP COMMENT '最近一次更新时间'
) ENGINE=OLAP
PRIMARY KEY(`data_source`, `id`)
COMMENT 'DWD L2 保护与敏感电阻器宽表（protective_sensitive_resistor）'
DISTRIBUTED BY HASH(`id`) BUCKETS 16
PROPERTIES (
    "compression"             = "ZSTD",
    "datacache.enable"        = "true",
    "replication_num"         = "1",
    "enable_persistent_index" = "true"
);
