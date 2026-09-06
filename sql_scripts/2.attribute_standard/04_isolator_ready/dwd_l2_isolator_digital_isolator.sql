/* DWD L2 / 数字隔离器 (digital_isolator) */
DROP TABLE IF EXISTS dwd.dwd_l2_isolator_digital_isolator;

CREATE TABLE dwd.dwd_l2_isolator_digital_isolator (
    `data_source`              VARCHAR(32)   NOT NULL DEFAULT 'icpdf' COMMENT '数据来源：icpdf | digikey | mouser ...',
    `id`                       BIGINT        NOT NULL COMMENT '组件 ID',
    `mpn`                      VARCHAR(1024) NULL     COMMENT '制造商料号',
    `brand`                    VARCHAR(256)  NULL     COMMENT '品牌（标准化，dim.v_std_brand_alias）',
    `brandid`                  BIGINT        NULL     COMMENT '品牌 ID',
    `l1_code`                  VARCHAR(64)   NOT NULL,
    `l2_code`                  VARCHAR(96)   NOT NULL COMMENT 'digital_isolator',
    `l3_code`                  VARCHAR(64)   NULL,
    `lifecycle_status`         VARCHAR(64)   NULL     COMMENT '生命周期状态',
    `rohs_compliant`           DOUBLE        NULL     COMMENT 'RoHS合规',
    `reach`                    DOUBLE        NULL     COMMENT 'REACH合规',
    `eccn_code`                VARCHAR(64)   NULL     COMMENT '出口管制分类号',
    `lead_free`                DOUBLE        NULL     COMMENT '无铅工艺',
    `msl_level`                VARCHAR(16)   NULL     COMMENT '湿敏等级',
    `package_case`             VARCHAR(256)  NULL     COMMENT '封装形式',
    `mounting_style`            VARCHAR(16)   NULL     COMMENT '安装方式',
    `temp_min_c`               DOUBLE        NULL     COMMENT '最低工作温度',
    `temp_max_c`               DOUBLE        NULL     COMMENT '最高工作温度',
    `vcc_min_v`                DOUBLE        NULL     COMMENT '最低供电电压',
    `vcc_max_v`                DOUBLE        NULL     COMMENT '最高供电电压',
    `ext_attributes`           JSON          NULL,
    `semantic_tags`            JSON          NULL,
    `dq_score`                 DOUBLE        NULL,
    `dq_flags`                 JSON          NULL,
    `source_id`                BIGINT        NULL,
    `create_at`                DATETIME      NULL DEFAULT CURRENT_TIMESTAMP,
    `update_at`                DATETIME      NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=OLAP
PRIMARY KEY(`data_source`, `id`)
COMMENT 'DWD L2 数字隔离器宽表（isolator）'
DISTRIBUTED BY HASH(`id`) BUCKETS 4
PROPERTIES ("replication_num" = "1", "enable_persistent_index" = "true");
