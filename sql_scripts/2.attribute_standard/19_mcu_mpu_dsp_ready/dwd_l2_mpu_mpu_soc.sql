DROP TABLE IF EXISTS dwd.dwd_l2_mpu_mpu_soc;
DROP TABLE IF EXISTS dwd.dwd_l2_mpu_soc;
CREATE TABLE dwd.dwd_l2_mpu_mpu_soc (
    `data_source`               VARCHAR(32)     NOT NULL     COMMENT '数据来源（icpdf）',,
    `id`                        BIGINT          NOT NULL COMMENT '组件唯一ID（对齐 dwd_icpdf_component_param.id）',,
    `mpn`                       VARCHAR(1024)   NULL     COMMENT '制造商料号',
    `brand`                     VARCHAR(256)    NULL     COMMENT '品牌简称',
    `brandid`                   BIGINT          NULL     COMMENT '品牌 ID',
    `l1_code`                   VARCHAR(32)     NOT NULL COMMENT 'L1：mpu',
    `l2_code`                   VARCHAR(64)     NOT NULL COMMENT 'L2：mpu_soc_base',
    `l3_code`                   VARCHAR(64)     NULL     COMMENT 'L3 形态编码（如 application_mpu / ai_edge_computing_soc）',
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
    `pkg_length_mm`             DOUBLE          NULL     COMMENT '封装体长度（mm）',
    `pkg_width_mm`              DOUBLE          NULL     COMMENT '封装体宽度（mm）',
    `pkg_height_mm`             DOUBLE          NULL     COMMENT '封装体高度（mm）',
    `temp_min_c`                DOUBLE          NULL     COMMENT '最低工作温度（℃）',
    `temp_max_c`                DOUBLE          NULL     COMMENT '最高工作温度（℃）',
    /* ----- 技术参数（L2 公共）----- */
    `cpu_arch`                  VARCHAR(128)    NULL     COMMENT 'CPU指令集架构（如 ARM, x86, MIPS）',
    `cpu_word_width_bit`        INT             NULL     COMMENT 'CPU字长/数据位宽（bit）',
    `cpu_core_count`            INT             NULL     COMMENT 'CPU核心总数',
    `cpu_max_freq_mhz`          DOUBLE          NULL     COMMENT 'CPU最高主频（MHz）',
    `supply_voltage_min_v`      DOUBLE          NULL     COMMENT '最低供电电压（V）',
    `supply_voltage_max_v`      DOUBLE          NULL     COMMENT '最高供电电压（V）',
    `ddr_interface_type`        VARCHAR(128)    NULL     COMMENT '外部存储接口类型（如 DDR4, LPDDR4X）',
    `process_node_nm`           INT             NULL     COMMENT '制程工艺节点（nm）',
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
