/* DWD L2 / 晶闸管 (thyristor) */
DROP TABLE IF EXISTS dwd.dwd_l2_thyristor_transistor;
DROP TABLE IF EXISTS dwd.dwd_l2_thyristor_base;
DROP TABLE IF EXISTS dwd.dwd_l2_thyristor;
DROP TABLE IF EXISTS dwd.dwd_l2_transistor_thyristor_base;
DROP TABLE IF EXISTS dwd.dwd_l2_transistor_thyristor;
CREATE TABLE dwd.dwd_l2_transistor_thyristor (
    `data_source` VARCHAR(32) NOT NULL DEFAULT 'icpdf' COMMENT '数据来源：icpdf | digikey | mouser ...',
    `id` BIGINT NOT NULL COMMENT '组件 ID',
    `mpn` VARCHAR(1024) NULL COMMENT '制造商料号',
    `brand` VARCHAR(256) NULL COMMENT '品牌（标准化，dim.v_std_brand_alias）',
    `brandid` BIGINT NULL COMMENT '品牌 ID',
    `l1_code` VARCHAR(32) NOT NULL,
    `l2_code` VARCHAR(32) NOT NULL COMMENT 'thyristor',
    `l3_code` VARCHAR(64) NULL,
    `temp_min_c` DOUBLE NULL COMMENT '最低工作温度',
    `temp_max_c` DOUBLE NULL COMMENT '最高工作温度',
    `vdrm_v` DOUBLE NULL COMMENT '断态重复峰值电压',
    `it_rms_a` DOUBLE NULL COMMENT '通态均方根电流',
    `itsm_a` DOUBLE NULL COMMENT '非重复浪涌峰值电流',
    `igt_ma` DOUBLE NULL COMMENT '门极触发电流',
    `vt_v` DOUBLE NULL COMMENT '通态峰值电压',
    `ih_ma` DOUBLE NULL COMMENT '维持电流',
    `it_av_a` DOUBLE NULL COMMENT '通态平均电流',
    `package_case` VARCHAR(256) NULL COMMENT '封装形式',
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
COMMENT 'DWD L2 晶闸管 (thyristor)宽表'
DISTRIBUTED BY HASH(`id`) BUCKETS 16
PROPERTIES ("replication_num" = "1", "enable_persistent_index" = "true");
