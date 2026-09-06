/* DWD L2 / 计算模块/SOM (compute_som_module)
 * l1=system_module  l2_code=compute_som_module
 */
DROP TABLE IF EXISTS dwd.dwd_l2_system_module_compute_som_module;

CREATE TABLE dwd.dwd_l2_system_module_compute_som_module (
    `data_source`        VARCHAR(32)   NOT NULL DEFAULT 'digikey' COMMENT '数据来源：icpdf | digikey | mouser ...',
    `id`                 BIGINT        NOT NULL COMMENT '组件 ID',
    `mpn`                VARCHAR(1024) NULL     COMMENT '制造商料号',
    `brand`              VARCHAR(256)  NULL     COMMENT '品牌（标准化，dim.v_std_brand_alias）',
    `brandid`            BIGINT        NULL     COMMENT '品牌 ID',
    `l1_code`            VARCHAR(64)   NOT NULL,
    `l2_code`            VARCHAR(96)   NOT NULL COMMENT 'compute_som_module',
    `l3_code`            VARCHAR(64)   NULL,
    `manufacturer`       VARCHAR(256)  NULL     COMMENT '制造商',
    `rohs_compliant`     BOOLEAN       NULL     COMMENT 'RoHS合规',
    `lifecycle_status`   VARCHAR(64)   NULL     COMMENT '生命周期状态',
    `reach`              BOOLEAN       NULL     COMMENT 'REACH合规',
    `eccn_code`          VARCHAR(64)   NULL     COMMENT '出口管制分类号',
    `aec_q_level`        VARCHAR(32)   NULL     COMMENT '汽车级认证等级',
    `lead_free`          BOOLEAN       NULL     COMMENT '无铅工艺',
    `msl_level`          VARCHAR(16)   NULL     COMMENT '湿敏等级',
    `package_case`       VARCHAR(256)  NULL     COMMENT '封装形式',
    `pkg_length_mm`      DOUBLE        NULL     COMMENT '封装体长度 mm',
    `pkg_width_mm`       DOUBLE        NULL     COMMENT '封装体宽度 mm',
    `pkg_height_mm`      DOUBLE        NULL     COMMENT '封装体高度 mm',
    `temp_min_c`         DOUBLE        NULL     COMMENT '最低工作温度',
    `temp_max_c`         DOUBLE        NULL     COMMENT '最高工作温度',
    `supply_voltage_v`   DOUBLE        NULL     COMMENT '供电电压',
    `sys_ram_mb`         INT           NULL     COMMENT '系统 RAM（MB）',
    `sys_storage_mb`     INT           NULL     COMMENT '系统存储（MB）',
    `io_voltage_v`       DOUBLE        NULL     COMMENT 'I/O 电压',
    `connector_type`     VARCHAR(64)   NULL     COMMENT '接口连接器类型',
    `max_power_w`        DOUBLE        NULL     COMMENT '最大功耗',
    `ext_attributes`     JSON          NULL,
    `semantic_tags`      JSON          NULL,
    `dq_score`           DOUBLE        NULL,
    `dq_flags`           JSON          NULL,
    `source_id`          BIGINT        NULL,
    `create_at`          DATETIME      NULL DEFAULT CURRENT_TIMESTAMP,
    `update_at`          DATETIME      NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=OLAP
PRIMARY KEY(`data_source`, `id`)
COMMENT 'DWD L2 计算模块/SOM 宽表（system_module）'
DISTRIBUTED BY HASH(`id`) BUCKETS 16
PROPERTIES ("replication_num" = "1", "enable_persistent_index" = "true");
