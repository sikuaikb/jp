DROP TABLE IF EXISTS dwd.dwd_l2_dsp;
DROP TABLE IF EXISTS dwd.dwd_l2_dsp_dsp;
CREATE TABLE dwd.dwd_l2_dsp_dsp (
    `data_source`               VARCHAR(32)     NOT NULL     COMMENT '数据来源（icpdf）',,
    `id`                        BIGINT          NOT NULL COMMENT '组件唯一ID（对齐 dwd_icpdf_component_param.id）',,
    `mpn`                       VARCHAR(1024)   NULL     COMMENT '制造商料号',
    `brand`                     VARCHAR(256)    NULL     COMMENT '品牌简称',
    `brandid`                   BIGINT          NULL     COMMENT '品牌 ID',
    `l1_code`                   VARCHAR(32)     NOT NULL COMMENT 'L1：dsp',
    `l2_code`                   VARCHAR(64)     NOT NULL COMMENT 'L2：dsp_base',
    `l3_code`                   VARCHAR(64)     NULL     COMMENT 'L3 形态编码（如 general_programmable_dsp / audio_dsp）',
    /* ----- 合规 & 交易参数 ----- */
    `manufacturer`              VARCHAR(1024)   NULL     COMMENT '制造商',
    `rohs_compliant`            TINYINT     NULL     COMMENT 'RoHS合规',
    `lifecycle_status`          VARCHAR(128)    NULL     COMMENT '生命周期状态',
    `reach`                     VARCHAR(64)     NULL     COMMENT 'REACH合规',
    `eccn_code`                 VARCHAR(256)    NULL     COMMENT '出口管制分类号',
    `aec_q_level`               VARCHAR(128)    NULL     COMMENT '汽车级认证等级',
    `lead_free`                 TINYINT     NULL     COMMENT '无铅工艺',
    `msl_level`                 VARCHAR(128)    NULL     COMMENT '湿敏等级',
    /* ----- 封装参数 ----- */
    `package_case`              VARCHAR(256)    NULL     COMMENT '封装形式',
    `temp_min_c`                DOUBLE          NULL     COMMENT '最低工作温度（℃）',
    `temp_max_c`                DOUBLE          NULL     COMMENT '最高工作温度（℃）',
    /* ----- 技术参数（L2 公共）----- */
    `core_clock_max_mhz`        DOUBLE          NULL     COMMENT '最高主频（MHz）',
    `core_data_width_bit`       INT             NULL     COMMENT '核心数据位宽（bit）',
    `onchip_sram_kb`            DOUBLE          NULL     COMMENT '片上SRAM容量（KB）',
    `supply_voltage_min_v`      DOUBLE          NULL     COMMENT '核心供电电压下限（V）',
    `supply_voltage_max_v`      DOUBLE          NULL     COMMENT '核心供电电压上限（V）',
    /* ----- L3 专有 & 质量 ----- */
    `ext_attributes`            JSON            NULL     COMMENT 'L3 专有属性 JSON',
    `semantic_tags`             JSON            NULL     COMMENT '业务场景标签数组（预留）',
    `dq_score`                  DOUBLE          NULL     COMMENT '数据质量综合分（预留）',
    `dq_flags`                  JSON            NULL     COMMENT '数据质量标记（预留）',
    /* ----- 溯源 ----- */
    `source_id`                 BIGINT          NULL     COMMENT '来源表原始 id',
    `create_at`                 DATETIME        NULL DEFAULT CURRENT_TIMESTAMP COMMENT '入库时间（仅新行）',
    `update_at`                 DATETIME        NULL DEFAULT CURRENT_TIMESTAMP COMMENT '最近一次更新时间'
) ENGINE=OLAP
PRIMARY KEY(`data_source`, `id`)
COMMENT '组件唯一ID（对齐 dwd_icpdf_component_param.id）'
DISTRIBUTED BY HASH(`id`) BUCKETS 16
PROPERTIES ("replication_num" = "1", "enable_persistent_index" = "true");
