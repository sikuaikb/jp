/* DWD L2 / FPGA (fpga)
 * L3: sram_based_fpga / flash_based_fpga / antifuse_fpga / soc_fpga
 */
DROP TABLE IF EXISTS dwd.dwd_l2_fpga_cpld_fpga;

CREATE TABLE dwd.dwd_l2_fpga_cpld_fpga (
    `data_source`          VARCHAR(32)   NOT NULL DEFAULT 'icpdf' COMMENT '数据来源：icpdf | digikey | mouser ...',
    `id`                   BIGINT        NOT NULL COMMENT '组件 ID',
    `mpn`                  VARCHAR(1024) NULL     COMMENT '制造商料号',
    `brand`                VARCHAR(256)  NULL     COMMENT '品牌（标准化，dim.v_std_brand_alias）',
    `brandid`              BIGINT        NULL     COMMENT '品牌 ID',
    `l1_code`              VARCHAR(64)   NOT NULL,
    `l2_code`              VARCHAR(96)   NOT NULL COMMENT 'fpga',
    `l3_code`              VARCHAR(64)   NULL,
    `manufacturer`         VARCHAR(256)  NULL     COMMENT '制造商',
    `rohs_compliant`       BOOLEAN       NULL     COMMENT 'RoHS合规',
    `lifecycle_status`     VARCHAR(64)   NULL     COMMENT '生命周期状态',
    `reach`                BOOLEAN       NULL     COMMENT 'REACH合规',
    `eccn_code`            VARCHAR(64)   NULL     COMMENT '出口管制分类号',
    `aec_q_level`          VARCHAR(64)   NULL     COMMENT '汽车级认证等级',
    `lead_free`            BOOLEAN       NULL     COMMENT '无铅工艺',
    `msl_level`            VARCHAR(16)   NULL     COMMENT '湿敏等级',
    `package_case`         VARCHAR(128)  NULL     COMMENT '封装形式',
    `pkg_length_mm`        DOUBLE        NULL     COMMENT '封装体长度 mm',
    `pkg_width_mm`         DOUBLE        NULL     COMMENT '封装体宽度 mm',
    `mounting_style`        VARCHAR(16)   NULL     COMMENT '安装方式',
    `temp_min_c`           DOUBLE        NULL     COMMENT '最低工作温度',
    `temp_max_c`           DOUBLE        NULL     COMMENT '最高工作温度',
    `logic_cells_k`        DOUBLE        NULL     COMMENT '逻辑单元数（K）',
    `user_io_count`        INT           NULL     COMMENT '用户 I/O 数',
    `block_ram_kbit`       DOUBLE        NULL     COMMENT '块 RAM 容量（kbit）',
    `dsp_block_count`      INT           NULL     COMMENT 'DSP 块数量',
    `vcc_core_v`           DOUBLE        NULL     COMMENT '内核电压',
    `ext_attributes`       JSON          NULL     COMMENT 'L3 专属属性 JSON（各 L3 专用稀疏列）',
    `semantic_tags`        JSON          NULL,
    `dq_score`             DOUBLE        NULL,
    `dq_flags`             JSON          NULL,
    `source_id`            BIGINT        NULL,
    `create_at`            DATETIME      NULL DEFAULT CURRENT_TIMESTAMP,
    `update_at`            DATETIME      NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=OLAP
PRIMARY KEY(`data_source`, `id`)
COMMENT 'DWD L2 FPGA 宽表（fpga_cpld）'
DISTRIBUTED BY HASH(`id`) BUCKETS 16
PROPERTIES ("replication_num" = "1", "enable_persistent_index" = "true");
