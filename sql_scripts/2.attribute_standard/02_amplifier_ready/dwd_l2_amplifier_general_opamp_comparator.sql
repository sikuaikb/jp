/* L2 宽表 DDL · amplifier / general_opamp_comparator · prod
 * l1_code = amplifier · scope_code = general_opamp_comparator
 * 列来源：test_dim.dim_attr_schema_amplifier scope_level=l2
 */


CREATE TABLE IF NOT EXISTS dwd.dwd_l2_amplifier_general_opamp_comparator (
    `data_source`            VARCHAR(32)    NOT NULL DEFAULT 'digikey' COMMENT '数据源',
    `id`                     BIGINT         NOT NULL COMMENT '物料 ID',
    `mpn`                    VARCHAR(1024)  NULL     COMMENT '制造商零件编号',
    `brand`                  VARCHAR(256)   NULL     COMMENT '标准化品牌全称',
    `brandid`                BIGINT         NULL     COMMENT '标准化品牌 ID',
    `l1_code`                VARCHAR(32)    NOT NULL COMMENT 'L1: amplifier',
    `l2_code`                VARCHAR(96)    NOT NULL COMMENT 'L2: general_opamp_comparator',
    `l3_code`                VARCHAR(96)    NULL     COMMENT 'L3 分类编码',
    `manufacturer`                VARCHAR(1024)    NULL COMMENT '制造商',
    `rohs_compliant`             TINYINT      NULL COMMENT 'RoHS合规',
    `lifecycle_status`           VARCHAR(64)      NULL COMMENT '生命周期状态',
    `reach`                       VARCHAR(64)      NULL COMMENT 'REACH合规',
    `eccn_code`                   VARCHAR(64)      NULL COMMENT '出口管制分类编号',
    `aec_q_level`                 VARCHAR(64)      NULL COMMENT '汽车级认证等级',
    `lead_free`                   TINYINT      NULL COMMENT '无铅',
    `msl_level`                   VARCHAR(64)      NULL COMMENT '湿敏等级',
    `package_case`                VARCHAR(1024)    NULL COMMENT '封装形式',
    `temp_min_c`                  DOUBLE           NULL COMMENT '最低工作温度',
    `temp_max_c`                  DOUBLE           NULL COMMENT '最高工作温度',
    `pkg_length_mm`               DOUBLE           NULL COMMENT '封装体长度',
    `pkg_width_mm`                DOUBLE           NULL COMMENT '封装体宽度',
    `pkg_height_mm`               DOUBLE           NULL COMMENT '封装体高度',
    `supply_voltage_min_v`        DOUBLE           NULL COMMENT '最小供电电压',
    `supply_voltage_max_v`        DOUBLE           NULL COMMENT '最大供电电压',
    `channel_count`               INT              NULL COMMENT '通道数',
    `quiescent_current_ua`        DOUBLE           NULL COMMENT '每通道静态电流',
    `input_offset_voltage_uv`     DOUBLE           NULL COMMENT '输入失调电压',
    `ext_attributes`         JSON           NULL     COMMENT 'L3 专有属性 JSON',
    `semantic_tags`          JSON           NULL     COMMENT '业务标签（预留）',
    `dq_score`               DOUBLE         NULL     COMMENT '数据质量分（预留）',
    `dq_flags`               JSON           NULL     COMMENT '数据质量标记（预留）',
    `source_id`              BIGINT         NULL     COMMENT '源端 id',
    `create_at`              DATETIME       NULL DEFAULT CURRENT_TIMESTAMP,
    `update_at`              DATETIME       NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=OLAP
PRIMARY KEY (`data_source`, `id`)
COMMENT 'amplifier L2 宽表 · general_opamp_comparator · prod'
DISTRIBUTED BY HASH(`id`) BUCKETS 4
PROPERTIES ("replication_num" = "1", "enable_persistent_index" = "true");
