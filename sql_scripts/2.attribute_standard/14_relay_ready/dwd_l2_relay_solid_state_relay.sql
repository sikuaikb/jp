/* DWD L2 宽表：solid_state_relay → dwd.dwd_l2_relay_solid_state_relay
   注：PRIMARY KEY(data_source, id) 要求这两列在表定义最前面（StarRocks 约束）。 */
DROP TABLE IF EXISTS dwd.dwd_l2_relay_solid_state_relay;
CREATE TABLE dwd.dwd_l2_relay_solid_state_relay (
    `data_source` VARCHAR(32) NOT NULL DEFAULT 'icpdf' COMMENT '数据来源：icpdf | digikey',
    `id` BIGINT NOT NULL COMMENT '组件 ID',
    `mpn` VARCHAR(1024) NULL COMMENT '制造商料号',
    `brand` VARCHAR(256) NULL COMMENT '品牌（标准化，dim.v_std_brand_alias）',
    `brandid` BIGINT NULL COMMENT '品牌 ID',
    `l1_code` VARCHAR(32) NOT NULL,
    `l2_code` VARCHAR(32) NOT NULL COMMENT 'solid_state_relay',
    `l3_code` VARCHAR(64) NULL,
    `temp_min_c` DOUBLE NULL COMMENT '最低工作温度',
    `temp_max_c` DOUBLE NULL COMMENT '最高工作温度',
    `ssr_type` VARCHAR(256) NULL COMMENT 'SSR类型路由',
    `load_voltage_max_v` DOUBLE NULL COMMENT '负载侧最大电压',
    `load_current_max_a` DOUBLE NULL COMMENT '负载侧最大电流',
    `control_voltage_min_v` DOUBLE NULL COMMENT '控制端最小输入电压',
    `control_voltage_max_v` DOUBLE NULL COMMENT '控制端最大输入电压',
    `isolation_voltage_v` DOUBLE NULL COMMENT '输入输出隔离电压',
    `control_current_max_ma` DOUBLE NULL COMMENT '控制端最大输入电流',
    `package_case` VARCHAR(256) NULL COMMENT '封装形式',
    `mounting_style` VARCHAR(256) NULL COMMENT '安装方式',
    `pkg_length_mm` DOUBLE NULL COMMENT '封装体长度',
    `pkg_width_mm` DOUBLE NULL COMMENT '封装体宽度',
    `pkg_height_mm` DOUBLE NULL COMMENT '封装体高度',
    `rohs_compliant` BOOLEAN NULL COMMENT 'RoHS合规',
    `reach` BOOLEAN NULL COMMENT 'REACH合规',
    `aec_q_level` VARCHAR(256) NULL COMMENT '汽车级认证等级',
    `lead_free` BOOLEAN NULL COMMENT '无铅',
    `msl_level` VARCHAR(256) NULL COMMENT '湿敏等级',
    `manufacturer` VARCHAR(1024) NULL COMMENT '制造商',
    `lifecycle_status` VARCHAR(256) NULL COMMENT '生命周期状态',
    `eccn_code` VARCHAR(256) NULL COMMENT '出口管制分类号',
    `ext_attributes` JSON NULL,
    `semantic_tags` JSON NULL,
    `dq_score` DOUBLE NULL,
    `dq_flags` JSON NULL,
    `source_id` BIGINT NULL,
    `create_at` DATETIME NULL DEFAULT CURRENT_TIMESTAMP,
    `update_at` DATETIME NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=OLAP
PRIMARY KEY(`data_source`, `id`)
COMMENT 'DWD L2 固态继电器 (solid_state_relay) 宽表'
DISTRIBUTED BY HASH(`id`) BUCKETS 16
PROPERTIES ("replication_num" = "1", "enable_persistent_index" = "true");
