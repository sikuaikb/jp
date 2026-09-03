/* ============================================================
 * DWD L2 / speaker
 * l1_code=acoustic_device · scope_level=l2 · scope_code=speaker
 * L3 专有属性 → ext_attributes JSON
 * ============================================================ */

DROP TABLE IF EXISTS dwd.dwd_l2_acoustic_device_speaker;

CREATE TABLE dwd.dwd_l2_acoustic_device_speaker (
    `data_source`   VARCHAR(32)    NOT NULL COMMENT '数据来源：icpdf | digikey | mouser ...',
    `id`            BIGINT         NOT NULL COMMENT '组件唯一ID',
    `mpn`           VARCHAR(1024)  NULL     COMMENT '制造商料号',
    `brand`         VARCHAR(256)   NULL     COMMENT '标准品牌名',
    `brandid`       BIGINT         NULL     COMMENT '标准品牌ID',
    `l1_code`       VARCHAR(32)    NOT NULL COMMENT 'L1：acoustic_device',
    `l2_code`       VARCHAR(32)    NOT NULL COMMENT 'L2：speaker',
    `l3_code`       VARCHAR(64)    NULL     COMMENT 'L3 形态编码',

    /* ----- L2 公共属性（dim_attr_schema scope_level=l2） ----- */
    `eccn_code` VARCHAR(512)     NULL COMMENT '出口管制分类号',
    `freq_max_hz` DOUBLE           NULL COMMENT '频率上限（Hz）',
    `freq_min_hz` DOUBLE           NULL COMMENT '频率下限（Hz）',
    `lead_free` TINYINT     NULL COMMENT '无铅工艺',
    `lifecycle_status` VARCHAR(64)      NULL COMMENT '生命周期状态',
    `mounting_style` VARCHAR(64)      NULL COMMENT '安装方式',
    `manufacturer` VARCHAR(512)     NULL COMMENT '制造商',
    `msl_level` VARCHAR(64)      NULL COMMENT '湿敏等级',
    `nominal_impedance_ohm` DOUBLE           NULL COMMENT '标称阻抗（Ω）',
    `package_case` VARCHAR(512)     NULL COMMENT '封装形式/安装方式',
    `rated_power_w` DOUBLE           NULL COMMENT '额定功率（W）',
    `reach` VARCHAR(512)     NULL COMMENT 'REACH合规',
    `rohs_compliant` TINYINT     NULL COMMENT 'RoHS合规',
    `sensitivity_db_spl` DOUBLE           NULL COMMENT '灵敏度（dB SPL）',
    `speaker_type` VARCHAR(64)      NULL COMMENT '扬声器类型',
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
COMMENT 'DWD L2 speaker 宽表（acoustic_device）'
DISTRIBUTED BY HASH(`id`) BUCKETS 16
PROPERTIES (
    "compression"             = "ZSTD",
    "datacache.enable"        = "true",
    "replication_num"         = "1",
    "enable_persistent_index" = "true"
);
