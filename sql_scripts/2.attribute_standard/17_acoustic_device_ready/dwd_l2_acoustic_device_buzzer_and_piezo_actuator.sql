/* ============================================================
 * DWD L2 / buzzer_and_piezo_actuator
 * l1_code=acoustic_device · scope_level=l2 · scope_code=buzzer_and_piezo_actuator
 * L3 专有属性 → ext_attributes JSON
 * ============================================================ */

DROP TABLE IF EXISTS dwd.dwd_l2_acoustic_device_buzzer_and_piezo_actuator;

CREATE TABLE dwd.dwd_l2_acoustic_device_buzzer_and_piezo_actuator (
    `data_source`   VARCHAR(32)    NOT NULL COMMENT '数据来源：icpdf | digikey | mouser ...',
    `id`            BIGINT         NOT NULL COMMENT '组件唯一ID',
    `mpn`           VARCHAR(1024)  NULL     COMMENT '制造商料号',
    `brand`         VARCHAR(256)   NULL     COMMENT '标准品牌名',
    `brandid`       BIGINT         NULL     COMMENT '标准品牌ID',
    `l1_code`       VARCHAR(32)    NOT NULL COMMENT 'L1：acoustic_device',
    `l2_code`       VARCHAR(32)    NOT NULL COMMENT 'L2：buzzer_and_piezo_actuator',
    `l3_code`       VARCHAR(64)    NULL     COMMENT 'L3 形态编码',

    /* ----- L2 公共属性（dim_attr_schema scope_level=l2） ----- */
    `eccn_code` VARCHAR(512)     NULL COMMENT '出口管制分类号',
    `lead_free` TINYINT     NULL COMMENT '无铅工艺',
    `lifecycle_status` VARCHAR(64)      NULL COMMENT '生命周期状态',
    `mounting_style` VARCHAR(64)      NULL COMMENT '安装方式',
    `manufacturer` VARCHAR(512)     NULL COMMENT '制造商',
    `msl_level` VARCHAR(64)      NULL COMMENT '湿敏等级',
    `package_case` VARCHAR(512)     NULL COMMENT '封装形式/安装方式',
    `pkg_height_mm` DOUBLE           NULL COMMENT '封装高度（mm）',
    `pkg_length_mm` DOUBLE           NULL COMMENT '封装长度（mm）',
    `pkg_width_mm` DOUBLE           NULL COMMENT '封装宽度（mm）',
    `rated_freq_hz` DOUBLE           NULL COMMENT '额定工作频率（Hz）',
    `reach` VARCHAR(512)     NULL COMMENT 'REACH合规',
    `rohs_compliant` TINYINT     NULL COMMENT 'RoHS合规',
    `spl_db` DOUBLE           NULL COMMENT '声压级(SPL)（dB）',
    `temp_max_c` DOUBLE           NULL COMMENT '工作温度上限（°C）',
    `temp_min_c` DOUBLE           NULL COMMENT '工作温度下限（°C）',

    /* ----- 标准尾部（顺序固定） ----- */
    `ext_attributes` JSON           NULL COMMENT 'L3 专有属性 KV 包',
    `semantic_tags`  JSON           NULL COMMENT '业务标签',
    `dq_score`       DOUBLE         NULL COMMENT '数据质量综合分（预留）',
    `dq_flags`       JSON           NULL COMMENT '数据质量标记（预留）',
    `source_id`      BIGINT         NULL COMMENT '来源表原始 id',
    `create_at`      DATETIME       NULL DEFAULT CURRENT_TIMESTAMP,
    `update_at`      DATETIME       NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=OLAP
PRIMARY KEY(`data_source`, `id`)
COMMENT 'DWD L2 buzzer_and_piezo_actuator 宽表（acoustic_device）'
DISTRIBUTED BY HASH(`id`) BUCKETS 16
PROPERTIES (
    "compression"             = "ZSTD",
    "datacache.enable"        = "true",
    "replication_num"         = "1",
    "enable_persistent_index" = "true"
);
