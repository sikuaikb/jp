DROP TABLE IF EXISTS dwd.dwd_l2_mcu;
DROP TABLE IF EXISTS dwd.dwd_l2_mcu_mcu;
CREATE TABLE dwd.dwd_l2_mcu_mcu (
    `data_source`               VARCHAR(32)     NOT NULL     COMMENT '数据来源（icpdf）',,
    `id`                        BIGINT          NOT NULL COMMENT '组件唯一ID（对齐 dwd_icpdf_component_param.id）',,
    `mpn`                       VARCHAR(1024)   NULL     COMMENT '制造商料号',
    `brand`                     VARCHAR(256)    NULL     COMMENT '品牌简称（来自 dwd_icpdf_component_param.brandshort）',
    `brandid`                   BIGINT          NULL     COMMENT '品牌 ID（来自 dwd_icpdf_component_param.brandid）',
    `l1_code`                   VARCHAR(32)     NOT NULL COMMENT 'L1：mcu',
    `l2_code`                   VARCHAR(64)     NOT NULL COMMENT 'L2：mcu_base',
    `l3_code`                   VARCHAR(64)     NULL     COMMENT 'L3 形态编码（如 general_mcu / motor_control_mcu 等）',
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
    `pin_count`                 INT             NULL     COMMENT '封装引脚总数',
    `temp_min_c`                DOUBLE          NULL     COMMENT '最低工作温度（℃）',
    `temp_max_c`                DOUBLE          NULL     COMMENT '最高工作温度（℃）',
    /* ----- 技术参数（L2 公共）----- */
    `cpu_core_arch`             VARCHAR(128)    NULL     COMMENT 'CPU内核架构（如 ARM Cortex-M0, 8051）',
    `bus_width_bit`             INT             NULL     COMMENT '内核/数据总线位宽（bit）',
    `max_cpu_freq_mhz`          DOUBLE          NULL     COMMENT 'CPU最高主频（MHz）',
    `flash_size_kb`             INT             NULL     COMMENT 'Flash程序存储容量（KB）',
    `ram_size_kb`               INT             NULL     COMMENT 'SRAM数据存储容量（KB）',
    `supply_voltage_min_v`      DOUBLE          NULL     COMMENT '工作电压下限（V）',
    `supply_voltage_max_v`      DOUBLE          NULL     COMMENT '工作电压上限（V）',
    `gpio_count`                INT             NULL     COMMENT '通用GPIO数量',
    `adc_resolution_bit`        INT             NULL     COMMENT 'ADC最高分辨率（bit）',
    `adc_channel_count`         INT             NULL     COMMENT 'ADC通道数',
    `timer_count`               INT             NULL     COMMENT '定时器数量',
    `pwm_channel_count`         INT             NULL     COMMENT 'PWM通道数量',
    `uart_count`                INT             NULL     COMMENT 'UART接口数量',
    `spi_channel_count`         INT             NULL     COMMENT 'SPI接口数量',
    `i2c_channel_count`         INT             NULL     COMMENT 'I2C接口数量',
    `usb_interface_type`        VARCHAR(128)    NULL     COMMENT 'USB接口类型',
    `can_channel_count`         INT             NULL     COMMENT 'CAN接口数量',
    `ethernet_mac_count`        INT             NULL     COMMENT '以太网MAC数量',
    `has_fpu`                   VARCHAR(16)     NULL     COMMENT '是否含硬件浮点单元（yes/no）',
    `dma_channel_count`         INT             NULL     COMMENT 'DMA通道数',
    `deep_sleep_current_ua`     DOUBLE          NULL     COMMENT '深度睡眠电流（µA）',
    /* ----- L3 专有 & 质量 ----- */
    `ext_attributes`            JSON            NULL     COMMENT 'L3 专有属性 JSON（scope_level=l3 & scope_code=l3_code）',
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
