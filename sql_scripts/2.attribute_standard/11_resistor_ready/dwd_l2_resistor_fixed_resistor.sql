/* ============================================================
 * DWD L2 / 固定电阻器 (fixed_resistor)
 *
 * 物理列与 dim.dim_attr_schema 对齐：
 *   schema_version=resistor_schema_v1.5.09 · l1_code=resistor ·
 *   scope_level=l2 · scope_code=fixed_resistor（全部 std_attr_code，
 *   列名、语义与维表一致；不按 is_l2_common 拆列）。
 *
 * L3 专有属性 → ext_attributes JSON（dim_attr_schema scope_level=l3 &
 * scope_code = 行级 l3_code）。
 *
 * id 后紧跟 **mpn**（料号；同源 param.partno，可与抽取合并）；brand/brandid 沿用参数表。窄表来源：**dwd_component_attr_std**（l2_code=fixed_resistor）。
 *
 * 运维：全量重建会 DROP 再 CREATE（列变更须如此）；装配见 build_dwd_l2_resistor_fixed_resistor.sql
 * ============================================================ */

DROP TABLE IF EXISTS dwd.dwd_l2_resistor_fixed_resistor;

CREATE TABLE dwd.dwd_l2_resistor_fixed_resistor (
    `data_source`                      VARCHAR(32)     NOT NULL DEFAULT 'icpdf' COMMENT '数据来源：icpdf | digikey | mouser ...',
    `id`                               BIGINT          NOT NULL COMMENT '组件唯一ID',
    `mpn`                              VARCHAR(1024)   NULL     COMMENT '制造商料号（同源 dwd_icpdf_component_param.partno；可与属性抽取合并）',
    `brand`                            VARCHAR(256)    NULL     COMMENT '标准品牌名（dim_std_brand.name；未命中字典则回退到 dwd_icpdf_component_param.brandshort）',
    `brandid`                          BIGINT          NULL     COMMENT '标准品牌ID（dim_std_brand.brand_id_std；未命中字典则回退到 dwd_icpdf_component_param.brandid）',

    `l1_code`                          VARCHAR(32)     NOT NULL COMMENT 'L1：resistor',
    `l2_code`                          VARCHAR(32)     NOT NULL COMMENT 'L2：fixed_resistor',
    `l3_code`                          VARCHAR(64)     NULL     COMMENT 'L3 形态编码',

    /* ----- dim_attr_schema：l2 / fixed_resistor（display_ord；mpn 列物理上前移至 id 后）----- */
    `manufacturer`                     VARCHAR(1024)   NULL     COMMENT '制造商',
    `rohs_compliant`                   BOOLEAN         NULL     COMMENT 'RoHS合规',
    `lifecycle_status`                 VARCHAR(64)     NULL     COMMENT '生命周期状态',
    `reach`                            BOOLEAN         NULL     COMMENT 'REACH合规',
    `eccn_code`                        VARCHAR(128)    NULL     COMMENT '出口管制分类号',
    `aec_q_level`                      VARCHAR(64)     NULL     COMMENT '汽车级认证等级',
    `lead_free`                        BOOLEAN         NULL     COMMENT '无铅工艺',
    `msl_level`                        VARCHAR(1024)   NULL     COMMENT '湿敏等级',
    `package_case`                     VARCHAR(1024)   NULL     COMMENT '封装型号',
    `temp_min_c`                       DOUBLE          NULL     COMMENT '最低工作温度（基准单位 deg_c）',
    `temp_max_c`                       DOUBLE          NULL     COMMENT '最高工作温度（基准单位 deg_c）',
    `pkg_length_mm`                    DOUBLE          NULL     COMMENT '封装体长度 mm',
    `pkg_width_mm`                     DOUBLE          NULL     COMMENT '封装体宽度 mm',
    `pkg_height_mm`                    DOUBLE          NULL     COMMENT '封装体高度 mm',
    `resistor_type`                    VARCHAR(128)    NULL     COMMENT '固定电阻功能类型',
    `resistive_element_technology`     VARCHAR(256)    NULL     COMMENT '电阻体工艺/材质',
    `body_material`                    VARCHAR(128)    NULL     COMMENT '本体/外壳材料',
    `form_factor`                      VARCHAR(128)    NULL     COMMENT '外形结构',
    `mounting_style`                   VARCHAR(128)    NULL     COMMENT '安装方式',
    `flameproof`                       BOOLEAN         NULL     COMMENT '阻燃/防火特性',
    `resistance_ohm`                   DOUBLE          NULL     COMMENT '标称阻值 ohm',
    `tolerance_pct`                    DOUBLE          NULL     COMMENT '阻值容差 %',
    `power_rating_w`                   DOUBLE          NULL     COMMENT '额定功率 w',
    `tcr_ppm_per_c`                    DOUBLE          NULL     COMMENT '温度系数 ppm_per_c',
    `max_working_voltage_v`            DOUBLE          NULL     COMMENT '最高工作电压 v',

    `ext_attributes`                   JSON            NULL     COMMENT 'L3 专有属性（dim scope_level=l3 & scope_code=l3_code）',
    `semantic_tags`                    JSON            NULL     COMMENT '业务场景标签数组',

    `dq_score`                         DOUBLE          NULL     COMMENT '数据质量综合分（预留）',
    `dq_flags`                         JSON            NULL     COMMENT '数据质量标记（预留）',

    `source_id`                        BIGINT          NULL     COMMENT '来源表原始 id',

    `create_at`                        DATETIME        NULL DEFAULT CURRENT_TIMESTAMP COMMENT '入库时间（仅新行）',
    `update_at`                        DATETIME        NULL DEFAULT CURRENT_TIMESTAMP COMMENT '最近一次更新时间'
) ENGINE=OLAP
PRIMARY KEY(`data_source`, `id`)
COMMENT 'DWD L2 固定电阻器宽表（L2 列与 dim_attr_schema fixed_resistor 一致）'
DISTRIBUTED BY HASH(`id`) BUCKETS 16
PROPERTIES (
    "compression"             = "ZSTD",
    "datacache.enable"        = "true",
    "replication_num"         = "1",
    "enable_persistent_index" = "true"
);
