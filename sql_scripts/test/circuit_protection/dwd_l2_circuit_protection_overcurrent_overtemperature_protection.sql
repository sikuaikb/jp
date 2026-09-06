/* ============================================================
 * DWD L2 宽表 / 过流/过温断路保护 (overcurrent_overtemperature_protection)
 *   L2: overcurrent_overtemperature_protection
 *
 * L2 物理列（L2 common, is_l2_common=1）：
 *   package_case, current_rating_a, voltage_rating_v, mounting_type
 *
 * L3 专有字段（ext_attributes JSON）：
 *   circuit_breaker 专属：trip_curve_type, pole_count, actuator_type
 *   thermal_cutoff  专属：rated_function_temp_c
 *
 * prod 合并：s/test_dwd\./dwd./g  s/test_dim\./dim./g
 * ============================================================ */

DROP TABLE IF EXISTS test_dwd.dwd_l2_circuit_protection_overcurrent_overtemperature_protection;

CREATE TABLE test_dwd.dwd_l2_circuit_protection_overcurrent_overtemperature_protection (
    /* ── 主键 / 关联键 ─────────────────────────────── */
    `data_source`          VARCHAR(32)    NOT NULL DEFAULT 'digikey' COMMENT '数据源',
    `id`                   BIGINT         NOT NULL                    COMMENT '物料唯一 ID',
    `mpn`                  VARCHAR(1024)  NULL                        COMMENT 'MPN',
    `brand`                VARCHAR(256)   NULL                        COMMENT '标准化品牌全称',
    `brandid`              BIGINT         NULL                        COMMENT '标准化品牌 ID',
    `l1_code`              VARCHAR(32)    NOT NULL COMMENT 'L1: circuit_protection',
    `l2_code`              VARCHAR(96)    NOT NULL COMMENT 'L2: overcurrent_overtemperature_protection',
    `l3_code`              VARCHAR(96)    NULL     COMMENT 'L3: circuit_breaker / thermal_cutoff',
    `brandshort`           VARCHAR(256)   NULL     COMMENT '原始品牌简称',
    `l3_id`                VARCHAR(6)     NULL     COMMENT 'L3 短 ID',

    /* ── L2 公共合规属性 ───────────────────────────── */
    `manufacturer`         VARCHAR(1024)  NULL COMMENT '制造商',
    `lifecycle_status`     VARCHAR(64)    NULL COMMENT '生命周期状态',
    `rohs_compliant`       TINYINT   NULL COMMENT 'RoHS 合规',
    `lead_free`            TINYINT   NULL COMMENT '无铅工艺',
    `msl_level`            VARCHAR(64)    NULL COMMENT '湿气敏感等级',

    /* ── L2 公共封装/安装属性 ──────────────────────── */
    `package_case`         VARCHAR(256)   NULL COMMENT '封装形式（断路器DK无此字段=D级）',
    `mounting_type`        VARCHAR(128)   NULL COMMENT '安装类型（SMD/Through-Hole/DIN-Rail/Panel-Mount）',

    /* ── L2 公共电气参数 ───────────────────────────── */
    `current_rating_a`     DOUBLE         NULL COMMENT '额定电流 A',
    `voltage_rating_v`     DOUBLE         NULL COMMENT '额定AC电压 V（热熔断体D级已补充）',

    /* ── L3 专有属性（JSON）────────────────────────── */
    `ext_attributes`       JSON           NULL COMMENT 'L3专有：circuit_breaker→trip_curve_type/pole_count/actuator_type; thermal_cutoff→rated_function_temp_c',
    `semantic_tags`        JSON           NULL COMMENT '业务标签（预留）',

    /* ── 数据质量 ───────────────────────────────────── */
    `dq_score`             DOUBLE         NULL COMMENT '数据质量分（预留）',
    `dq_flags`             JSON           NULL COMMENT '数据质量标记（预留）',

    /* ── 溯源 / 元数据 ──────────────────────────────── */
    `source_id`            BIGINT         NULL COMMENT '源端原始 id',
    `create_at`            DATETIME       NULL DEFAULT CURRENT_TIMESTAMP,
    `update_at`            DATETIME       NULL DEFAULT CURRENT_TIMESTAMP

) ENGINE = OLAP
PRIMARY KEY (`data_source`, `id`)
COMMENT 'DWD L2 过流/过温断路保护宽表（circuit_protection_schema_v1.16.01）'
DISTRIBUTED BY HASH(`id`) BUCKETS 16
PROPERTIES (
    "compression"             = "ZSTD",
    "datacache.enable"        = "true",
    "replication_num"         = "1",
    "enable_persistent_index" = "true"
);
