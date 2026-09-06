/* DWD L2 / 电源模块 (power_module)
 * l1=system_module  l2_code=power_module  多源：icpdf + digikey
 */
DROP TABLE IF EXISTS dwd.dwd_l2_system_module_power_module;

CREATE TABLE dwd.dwd_l2_system_module_power_module (
    `data_source`          VARCHAR(32)   NOT NULL DEFAULT 'digikey' COMMENT '数据来源：icpdf | digikey | mouser ...',
    `id`                   BIGINT        NOT NULL COMMENT '组件 ID',
    `mpn`                  VARCHAR(1024) NULL     COMMENT '制造商料号',
    `brand`                VARCHAR(256)  NULL     COMMENT '品牌（标准化，dim.v_std_brand_alias）',
    `brandid`              BIGINT        NULL     COMMENT '品牌 ID',
    `l1_code`              VARCHAR(64)   NOT NULL,
    `l2_code`              VARCHAR(96)   NOT NULL COMMENT 'power_module',
    `l3_code`              VARCHAR(64)   NULL,
    `manufacturer`         VARCHAR(256)  NULL     COMMENT '制造商',
    `rohs_compliant`       BOOLEAN       NULL     COMMENT 'RoHS合规',
    `lifecycle_status`     VARCHAR(64)   NULL     COMMENT '生命周期状态',
    `reach`                BOOLEAN       NULL     COMMENT 'REACH合规',
    `eccn_code`            VARCHAR(64)   NULL     COMMENT '出口管制分类号',
    `aec_q_level`          VARCHAR(32)   NULL     COMMENT '汽车级认证等级',
    `lead_free`            BOOLEAN       NULL     COMMENT '无铅工艺',
    `msl_level`            VARCHAR(16)   NULL     COMMENT '湿敏等级',
    `package_case`         VARCHAR(256)  NULL     COMMENT '封装形式',
    `pkg_length_mm`        DOUBLE        NULL     COMMENT '封装体长度 mm',
    `pkg_width_mm`         DOUBLE        NULL     COMMENT '封装体宽度 mm',
    `pkg_height_mm`        DOUBLE        NULL     COMMENT '封装体高度 mm',
    `mounting_style`        VARCHAR(256)   NULL     COMMENT '安装方式',
    `temp_min_c`           DOUBLE        NULL     COMMENT '最低工作温度',
    `temp_max_c`           DOUBLE        NULL     COMMENT '最高工作温度',
    `vin_min_v`            DOUBLE        NULL     COMMENT '输入电压下限',
    `vin_max_v`            DOUBLE        NULL     COMMENT '输入电压上限',
    `vout_nom_v`           DOUBLE        NULL     COMMENT '标称输出电压',
    `iout_rated_a`         DOUBLE        NULL     COMMENT '额定输出电流',
    `pout_rated_w`         DOUBLE        NULL     COMMENT '额定输出功率',
    `efficiency_typ_pct`   DOUBLE        NULL     COMMENT '典型效率（%）',
    `vout_accuracy_pct`    DOUBLE        NULL     COMMENT '输出电压精度（%）',
    `ext_attributes`       JSON          NULL,
    `semantic_tags`        JSON          NULL,
    `dq_score`             DOUBLE        NULL,
    `dq_flags`             JSON          NULL,
    `source_id`            BIGINT        NULL,
    `create_at`            DATETIME      NULL DEFAULT CURRENT_TIMESTAMP,
    `update_at`            DATETIME      NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=OLAP
PRIMARY KEY(`data_source`, `id`)
COMMENT 'DWD L2 电源模块宽表（system_module）'
DISTRIBUTED BY HASH(`id`) BUCKETS 16
PROPERTIES ("replication_num" = "1", "enable_persistent_index" = "true");
