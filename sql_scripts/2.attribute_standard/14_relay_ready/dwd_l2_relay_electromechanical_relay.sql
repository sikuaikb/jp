/* DWD L2 宽表：electromechanical_relay → dwd.dwd_l2_relay_electromechanical_relay
   注：PRIMARY KEY(data_source, id) 要求这两列在表定义最前面（StarRocks 约束）。 */
DROP TABLE IF EXISTS dwd.dwd_l2_relay_electromechanical_relay;
CREATE TABLE dwd.dwd_l2_relay_electromechanical_relay (
    `data_source` VARCHAR(32) NOT NULL DEFAULT 'icpdf' COMMENT '数据来源：icpdf | digikey',
    `id` BIGINT NOT NULL COMMENT '组件 ID',
    `mpn` VARCHAR(1024) NULL COMMENT '制造商料号',
    `brand` VARCHAR(256) NULL COMMENT '品牌（标准化，dim.v_std_brand_alias）',
    `brandid` BIGINT NULL COMMENT '品牌 ID',
    `l1_code` VARCHAR(32) NOT NULL,
    `l2_code` VARCHAR(32) NOT NULL COMMENT 'electromechanical_relay',
    `l3_code` VARCHAR(64) NULL,
    `temp_min_c` DOUBLE NULL COMMENT '最低工作温度',
    `temp_max_c` DOUBLE NULL COMMENT '最高工作温度',
    `coil_voltage_v` DOUBLE NULL COMMENT '线圈额定电压',
    `contact_form` VARCHAR(256) NULL COMMENT '触点形式',
    `contact_rated_current_a` DOUBLE NULL COMMENT '触点额定电流',
    `contact_rated_voltage_v` DOUBLE NULL COMMENT '触点额定电压',
    `coil_power_mw` DOUBLE NULL COMMENT '线圈额定功耗',
    `operate_time_ms` DOUBLE NULL COMMENT '动作时间',
    `relay_type` VARCHAR(256) NULL COMMENT '继电器类型路由',
    `release_time_ms` DOUBLE NULL COMMENT '释放时间',
    `contact_material` VARCHAR(512) NULL COMMENT '触点材料',
    `package_case` VARCHAR(256) NULL COMMENT '封装形式',
    `mounting_style` VARCHAR(256) NULL COMMENT '安装方式',
    `rohs_compliant` BOOLEAN NULL COMMENT 'RoHS合规',
    `reach` BOOLEAN NULL COMMENT 'REACH合规',
    `aec_q_level` VARCHAR(256) NULL COMMENT '汽车级认证等级',
    `lead_free` BOOLEAN NULL COMMENT '无铅',
    `msl_level` VARCHAR(256) NULL COMMENT '湿敏等级',
    `manufacturer` VARCHAR(1024) NULL COMMENT '制造商',
    `lifecycle_status` VARCHAR(256) NULL COMMENT '生命周期状态',
    `eccn_code` VARCHAR(256) NULL COMMENT '出口管制分类编号',
    `ext_attributes` JSON NULL,
    `semantic_tags` JSON NULL,
    `dq_score` DOUBLE NULL,
    `dq_flags` JSON NULL,
    `source_id` BIGINT NULL,
    `create_at` DATETIME NULL DEFAULT CURRENT_TIMESTAMP,
    `update_at` DATETIME NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=OLAP
PRIMARY KEY(`data_source`, `id`)
COMMENT 'DWD L2 电磁继电器 (electromechanical_relay) 宽表'
DISTRIBUTED BY HASH(`id`) BUCKETS 16
PROPERTIES ("replication_num" = "1", "enable_persistent_index" = "true");
