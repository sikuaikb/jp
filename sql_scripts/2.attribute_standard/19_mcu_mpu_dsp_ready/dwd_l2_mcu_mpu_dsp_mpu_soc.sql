/* DWD L2 / 微处理器与异构SoC (mpu_soc) — dim_attr_schema mcu_mpu_dsp_schema_v1.5.20 */

DROP TABLE IF EXISTS dwd.dwd_l2_mcu_mpu_dsp_mpu_soc;

CREATE TABLE dwd.dwd_l2_mcu_mpu_dsp_mpu_soc (
    `data_source`               VARCHAR(32)     NOT NULL DEFAULT 'icpdf' COMMENT '数据来源',
    `id`                        BIGINT          NOT NULL COMMENT '组件唯一ID',
    `mpn`                       VARCHAR(1024)   NULL     COMMENT '制造商料号',
    `brand`                     VARCHAR(256)    NULL     COMMENT '标准品牌名',
    `brandid`                   BIGINT          NULL     COMMENT '标准品牌ID',
    `l1_code`                   VARCHAR(32)     NOT NULL COMMENT 'L1：mcu_mpu_dsp',
    `l2_code`                   VARCHAR(32)     NOT NULL COMMENT 'L2：mpu_soc',
    `l3_code`                   VARCHAR(64)     NULL     COMMENT 'L3 形态编码',

    `cpu_arch`                    VARCHAR(128)     NULL     COMMENT 'CPU指令集架构',
    `cpu_word_width_bit`          INT              NULL     COMMENT 'CPU字长/数据位宽',
    `cpu_core_count`              INT              NULL     COMMENT 'CPU核心总数',
    `cpu_max_freq_mhz`            DOUBLE           NULL     COMMENT 'CPU最高主频',
    `supply_voltage_min_v`        DOUBLE           NULL     COMMENT '最低供电电压',
    `supply_voltage_max_v`        DOUBLE           NULL     COMMENT '最高供电电压',
    `ddr_interface_type`          VARCHAR(128)     NULL     COMMENT '外部存储接口类型',
    `process_node_nm`             INT              NULL     COMMENT '制程工艺节点',
    `package_case`                VARCHAR(1024)    NULL     COMMENT '封装形式',
    `pkg_length_mm`               DOUBLE           NULL     COMMENT '封装体长度',
    `pkg_width_mm`                DOUBLE           NULL     COMMENT '封装体宽度',
    `pkg_height_mm`               DOUBLE           NULL     COMMENT '封装体高度',
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
