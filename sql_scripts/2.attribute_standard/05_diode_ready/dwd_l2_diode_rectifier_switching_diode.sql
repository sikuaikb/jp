/* ============================================================
 * DWD L2 / 整流与开关二极管 (rectifier_switching_diode)
 *
 * 物理列与 dim.dim_attr_schema 对齐：
 *   schema_version=v1.5.09 · l1_code=diode ·
 *   scope_level=l2 · scope_code=rectifier_switching_diode
 *
 * L3 专有属性 → ext_attributes JSON（dim_attr_schema scope_level=l3 & scope_code=l3_code）
 * L3: rectifier_diode / schottky_diode / switching_diode / bridge_rectifier / avalanche_diode
 *
 * 品牌标准化（与电阻一致）：brand / brandid 由 dim.v_std_brand_alias 命中后写回；未命中回退 raw。
 *
 * 装配 SQL：build_dwd_l2_diode_rectifier_switching_diode.sql
 * ============================================================ */

DROP TABLE IF EXISTS dwd.dwd_l2_diode_rectifier_switching_diode;

CREATE TABLE dwd.dwd_l2_diode_rectifier_switching_diode (
    `data_source`                     VARCHAR(32)     NOT NULL DEFAULT 'icpdf' COMMENT '数据来源：icpdf | digikey | mouser ...',
    `id`                BIGINT          NOT NULL COMMENT '组件唯一ID',
    `mpn`               VARCHAR(1024)   NULL     COMMENT '制造商料号',
    `brand`             VARCHAR(256)    NULL     COMMENT '标准品牌名（dim_std_brand.name；未命中字典回退 brandshort）',
    `brandid`           BIGINT          NULL     COMMENT '标准品牌 ID（dim_std_brand.brand_id_std；未命中回退 raw brandid）',

    `l1_code`           VARCHAR(32)     NOT NULL COMMENT 'L1：diode',
    `l2_code`           VARCHAR(32)     NOT NULL COMMENT 'L2：rectifier_switching_diode',
    `l3_code`           VARCHAR(64)     NULL     COMMENT 'L3 形态编码',

    `manufacturer`      VARCHAR(1024)   NULL     COMMENT '制造商（EAV 抽取，未命中 = NULL；不与 brand 兜底）',
    `rohs_compliant`    BOOLEAN         NULL     COMMENT 'RoHS合规',
    `lifecycle_status`  VARCHAR(64)     NULL     COMMENT '生命周期状态',
    `reach`             BOOLEAN         NULL     COMMENT 'REACH合规',
    `eccn_code`         VARCHAR(128)    NULL     COMMENT '出口管制分类号',
    `aec_q_level`       VARCHAR(64)     NULL     COMMENT '汽车级认证等级',
    `lead_free`         BOOLEAN         NULL     COMMENT '无铅工艺',
    `msl_level`         VARCHAR(1024)   NULL     COMMENT '湿敏等级',
    `package_case`      VARCHAR(1024)   NULL     COMMENT '封装形式',
    `pkg_length_mm`     DOUBLE          NULL     COMMENT '封装体长度 mm',
    `pkg_width_mm`      DOUBLE          NULL     COMMENT '封装体宽度 mm',
    `pkg_height_mm`     DOUBLE          NULL     COMMENT '封装体高度 mm',
    `temp_min_c`        DOUBLE          NULL     COMMENT '最低工作温度 ℃',
    `temp_max_c`        DOUBLE          NULL     COMMENT '最高工作温度 ℃',
    `vrrm_v`            DOUBLE          NULL     COMMENT '重复峰值反向电压 V',
    `if_avg_a`          DOUBLE          NULL     COMMENT '平均正向电流 A',
    `vf_max_v`          DOUBLE          NULL     COMMENT '最大正向压降 V',
    `ir_max_ua`         DOUBLE          NULL     COMMENT '最大反向漏电流 uA',
    `ifsm_max_a`        DOUBLE          NULL     COMMENT '最大非重复浪涌电流 A',

    `ext_attributes`    JSON            NULL     COMMENT 'L3 专有属性',
    `semantic_tags`     JSON            NULL     COMMENT '业务场景标签（预留）',

    `dq_score`          DOUBLE          NULL     COMMENT '数据质量综合分（预留）',
    `dq_flags`          JSON            NULL     COMMENT '数据质量标记（预留）',

    `source_id`         BIGINT          NULL     COMMENT '来源表原始 id',

    `create_at`         DATETIME        NULL     DEFAULT CURRENT_TIMESTAMP COMMENT '入库时间',
    `update_at`         DATETIME        NULL     DEFAULT CURRENT_TIMESTAMP COMMENT '最近一次更新时间'
) ENGINE=OLAP
PRIMARY KEY(`data_source`, `id`)
COMMENT 'DWD L2 整流与开关二极管宽表（rectifier_switching_diode）'
DISTRIBUTED BY HASH(`id`) BUCKETS 16
PROPERTIES (
    "compression"             = "ZSTD",
    "datacache.enable"        = "true",
    "replication_num"         = "1",
    "enable_persistent_index" = "true"
);
