/* DWD L2 / 绝缘栅双极型晶体管 (igbt) */
DROP TABLE IF EXISTS dwd.dwd_l2_igbt_transistor;
DROP TABLE IF EXISTS dwd.dwd_l2_igbt_base;
DROP TABLE IF EXISTS dwd.dwd_l2_igbt;
DROP TABLE IF EXISTS dwd.dwd_l2_transistor_igbt_base;
DROP TABLE IF EXISTS dwd.dwd_l2_transistor_igbt;
CREATE TABLE dwd.dwd_l2_transistor_igbt (
    `data_source` VARCHAR(32) NOT NULL DEFAULT 'icpdf' COMMENT '数据来源：icpdf | digikey | mouser ...',
    `id` BIGINT NOT NULL COMMENT '组件 ID',
    `mpn` VARCHAR(1024) NULL COMMENT '制造商料号',
    `brand` VARCHAR(256) NULL COMMENT '品牌（标准化，dim.v_std_brand_alias）',
    `brandid` BIGINT NULL COMMENT '品牌 ID',
    `l1_code` VARCHAR(32) NOT NULL,
    `l2_code` VARCHAR(32) NOT NULL COMMENT 'igbt',
    `l3_code` VARCHAR(64) NULL,
    `temp_min_c` DOUBLE NULL COMMENT '最低工作温度',
    `temp_max_c` DOUBLE NULL COMMENT '最高工作温度',
    `vces_max_v` DOUBLE NULL COMMENT '集射极击穿电压',
    `ic_cont_max_a` DOUBLE NULL COMMENT '连续集电极电流',
    `vce_sat_typ_v` DOUBLE NULL COMMENT '集射极饱和压降（典型值）',
    `vge_th_typ_v` DOUBLE NULL COMMENT '栅射极阈值电压（典型值）',
    `pd_max_w` DOUBLE NULL COMMENT '最大耗散功率',
    `e_off_mj` DOUBLE NULL COMMENT '关断能量损耗',
    `package_case` VARCHAR(256) NULL COMMENT '封装形式',
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
COMMENT 'DWD L2 绝缘栅双极型晶体管 (igbt)宽表'
DISTRIBUTED BY HASH(`id`) BUCKETS 16
PROPERTIES ("replication_num" = "1", "enable_persistent_index" = "true");
