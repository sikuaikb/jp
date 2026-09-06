/* DWD L2 / 微控制器 (mcu) — dim_attr_schema mcu_mpu_dsp_schema_v1.5.20 */

DROP TABLE IF EXISTS dwd.dwd_l2_mcu_mpu_dsp_mcu;

CREATE TABLE dwd.dwd_l2_mcu_mpu_dsp_mcu (
    `data_source`               VARCHAR(32)     NOT NULL DEFAULT 'icpdf' COMMENT '数据来源',
    `id`                        BIGINT          NOT NULL COMMENT '组件唯一ID',
    `mpn`                       VARCHAR(1024)   NULL     COMMENT '制造商料号',
    `brand`                     VARCHAR(256)    NULL     COMMENT '标准品牌名',
    `brandid`                   BIGINT          NULL     COMMENT '标准品牌ID',
    `l1_code`                   VARCHAR(32)     NOT NULL COMMENT 'L1：mcu_mpu_dsp',
    `l2_code`                   VARCHAR(32)     NOT NULL COMMENT 'L2：mcu',
    `l3_code`                   VARCHAR(64)     NULL     COMMENT 'L3 形态编码',

    `cpu_core_arch`               VARCHAR(128)     NULL     COMMENT 'CPU内核架构',
    `bus_width_bit`               INT              NULL     COMMENT '内核/数据总线位宽',
    `max_cpu_freq_mhz`            DOUBLE           NULL     COMMENT 'CPU最高主频',
    `flash_size_kb`               INT              NULL     COMMENT 'Flash程序存储容量',
    `ram_size_kb`                 INT              NULL     COMMENT 'SRAM数据存储容量',
    `supply_voltage_min_v`        DOUBLE           NULL     COMMENT '工作电压下限',
    `supply_voltage_max_v`        DOUBLE           NULL     COMMENT '工作电压上限',
    `gpio_count`                  INT              NULL     COMMENT '通用GPIO数量',
    `adc_resolution_bit`          INT              NULL     COMMENT 'ADC最高分辨率',
    `adc_channel_count`           INT              NULL     COMMENT 'ADC通道数',
    `timer_count`                 INT              NULL     COMMENT '定时器数量',
    `pwm_channel_count`           INT              NULL     COMMENT 'PWM通道数量',
    `uart_count`                  INT              NULL     COMMENT 'UART接口数量',
    `spi_channel_count`           INT              NULL     COMMENT 'SPI接口数量',
    `i2c_channel_count`           INT              NULL     COMMENT 'I2C接口数量',
    `usb_interface_type`          VARCHAR(128)     NULL     COMMENT 'USB接口类型',
    `can_channel_count`           INT              NULL     COMMENT 'CAN接口数量',
    `ethernet_mac_count`          INT              NULL     COMMENT '以太网MAC数量',
    `has_fpu`                     VARCHAR(64)      NULL     COMMENT '是否含硬件浮点单元',
    `dma_channel_count`           INT              NULL     COMMENT 'DMA通道数',
    `deep_sleep_current_ua`       DOUBLE           NULL     COMMENT '深度睡眠电流',
    `pin_count`                   INT              NULL     COMMENT '封装引脚总数',
    `package_case`                VARCHAR(1024)    NULL     COMMENT '封装形式',
    `temp_min_c`                  DOUBLE           NULL     COMMENT '最低工作温度',
    `temp_max_c`                  DOUBLE           NULL     COMMENT '最高工作温度',
    `rohs_compliant`              BOOLEAN          NULL     COMMENT 'RoHS合规',
    `reach`                       BOOLEAN          NULL     COMMENT 'REACH合规',
    `lead_free`                   BOOLEAN          NULL     COMMENT '无铅工艺',
    `aec_q_level`                 VARCHAR(64)      NULL     COMMENT '汽车级认证等级',
    `msl_level`                   VARCHAR(1024)    NULL     COMMENT '湿敏等级',
    `manufacturer`                VARCHAR(1024)    NULL     COMMENT '制造商',
    `lifecycle_status`            VARCHAR(64)      NULL     COMMENT '生命周期状态',
    `eccn_code`                   VARCHAR(128)     NULL     COMMENT '出口管制分类号',
    `ext_attributes`            JSON            NULL     COMMENT 'L3 专有属性',
    `semantic_tags`             JSON            NULL     COMMENT '业务标签',
    `dq_score`                  DOUBLE          NULL     COMMENT '数据质量分',
    `dq_flags`                  JSON            NULL     COMMENT '数据质量标记',
    `source_id`                 BIGINT          NULL     COMMENT '来源表原始 id',
    `create_at`                 DATETIME        NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `update_at`                 DATETIME        NULL DEFAULT CURRENT_TIMESTAMP COMMENT '更新时间'
) ENGINE=OLAP
PRIMARY KEY(`data_source`, `id`)
DISTRIBUTED BY HASH(`id`) BUCKETS 16
PROPERTIES (
    "compression" = "ZSTD",
    "enable_persistent_index" = "true",
    "replication_num" = "1"
);
