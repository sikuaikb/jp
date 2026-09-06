/* DWD L2 / 场效应晶体管 (fet) */
DROP TABLE IF EXISTS dwd.dwd_l2_fet_transistor;
DROP TABLE IF EXISTS dwd.dwd_l2_fet_base;
DROP TABLE IF EXISTS dwd.dwd_l2_fet;
DROP TABLE IF EXISTS dwd.dwd_l2_transistor_fet_base;
DROP TABLE IF EXISTS dwd.dwd_l2_transistor_fet;
CREATE TABLE dwd.dwd_l2_transistor_fet (
    `data_source` VARCHAR(32) NOT NULL DEFAULT 'icpdf' COMMENT '数据来源：icpdf | digikey | mouser ...',
    `id` BIGINT NOT NULL COMMENT '组件 ID',
    `mpn` VARCHAR(1024) NULL COMMENT '制造商料号',
    `brand` VARCHAR(256) NULL COMMENT '品牌（标准化，dim.v_std_brand_alias）',
    `brandid` BIGINT NULL COMMENT '品牌 ID',
    `l1_code` VARCHAR(32) NOT NULL,
    `l2_code` VARCHAR(32) NOT NULL COMMENT 'fet',
    `l3_code` VARCHAR(64) NULL,
    `temp_min_c` INT NULL COMMENT '最低工作温度',
    `temp_max_c` INT NULL COMMENT '最高工作温度',
    `fet_type` VARCHAR(256) NULL COMMENT 'L3亚分类路由键',
    `vds_max_v` DOUBLE NULL COMMENT '漏源击穿电压',
    `id_max_a` DOUBLE NULL COMMENT '最大连续漏极电流',
    `rds_on_max_mohm` DOUBLE NULL COMMENT '最大导通电阻',
    `vgs_th_max_v` DOUBLE NULL COMMENT '栅极阈值电压上限',
    `pd_max_w` DOUBLE NULL COMMENT '最大耗散功率',
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
COMMENT 'DWD L2 场效应晶体管 (fet)宽表'
DISTRIBUTED BY HASH(`id`) BUCKETS 16
PROPERTIES ("replication_num" = "1", "enable_persistent_index" = "true");
