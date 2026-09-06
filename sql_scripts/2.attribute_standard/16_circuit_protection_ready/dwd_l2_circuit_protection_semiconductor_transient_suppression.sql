/* ============================================================
 * DWD L2 宽表 / 半导体瞬态过压抑制 (semiconductor_transient_suppression)
 *   L2: semiconductor_transient_suppression
 *
 * L2 物理列（L2 common, is_l2_common=1）：
 *   package_case, temp_min_c, temp_max_c,
 *   standoff_voltage_v, breakdown_voltage_v, peak_pulse_power_w
 *
 * L3 专有字段（ext_attributes JSON）：
 *   tvs_diode 专属：clamping_voltage_v, peak_pulse_current_a, junction_capacitance_pf
 *
 * prod 合并：s/test_dwd\./dwd./g  s/test_dim\./dim./g
 * ============================================================ */

DROP TABLE IF EXISTS dwd.dwd_l2_circuit_protection_semiconductor_transient_suppression;

CREATE TABLE dwd.dwd_l2_circuit_protection_semiconductor_transient_suppression (
    /* ── 主键 / 关联键 ─────────────────────────────── */
    `data_source`          VARCHAR(32)    NOT NULL DEFAULT 'digikey' COMMENT '数据源',
    `id`                   BIGINT         NOT NULL                    COMMENT '物料唯一 ID',
    `mpn`                  VARCHAR(1024)  NULL                        COMMENT 'MPN',
    `brand`                VARCHAR(256)   NULL                        COMMENT '标准化品牌全称',
    `brandid`              BIGINT         NULL                        COMMENT '标准化品牌 ID',
    `l1_code`              VARCHAR(32)    NOT NULL COMMENT 'L1: circuit_protection',
    `l2_code`              VARCHAR(96)    NOT NULL COMMENT 'L2: semiconductor_transient_suppression',
    `l3_code`              VARCHAR(96)    NULL     COMMENT 'L3: tvs_diode / esd_suppressor / ...',
    `brandshort`           VARCHAR(256)   NULL     COMMENT '原始品牌简称',
    `l3_id`                VARCHAR(6)     NULL     COMMENT 'L3 短 ID',

    /* ── L2 公共合规属性 ───────────────────────────── */
    `manufacturer`         VARCHAR(1024)  NULL COMMENT '制造商',
    `lifecycle_status`     VARCHAR(64)    NULL COMMENT '生命周期状态',
    `rohs_compliant`       TINYINT   NULL COMMENT 'RoHS 合规',
    `lead_free`            TINYINT   NULL COMMENT '无铅工艺',
    `msl_level`            VARCHAR(64)    NULL COMMENT '湿气敏感等级',

    /* ── L2 公共封装/环境属性 ──────────────────────── */
    `package_case`         VARCHAR(256)   NULL COMMENT '封装形式',
    `temp_min_c`           DOUBLE         NULL COMMENT '最低工作温度 ℃',
    `temp_max_c`           DOUBLE         NULL COMMENT '最高工作温度 ℃',

    /* ── L2 公共电气参数 ───────────────────────────── */
    `standoff_voltage_v`   DOUBLE         NULL COMMENT '反向截止电压 V',
    `breakdown_voltage_v`  DOUBLE         NULL COMMENT '击穿电压 V',
    `peak_pulse_power_w`   DOUBLE         NULL COMMENT '峰值脉冲功率 W',

    /* ── L3 专有属性（JSON）────────────────────────── */
    `ext_attributes`       JSON           NULL COMMENT 'L3 专有属性（tvs_diode: clamping_voltage_v, peak_pulse_current_a, junction_capacitance_pf）',
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
COMMENT 'DWD L2 半导体瞬态过压抑制宽表（circuit_protection_schema_v1.16.01）'
DISTRIBUTED BY HASH(`id`) BUCKETS 16
PROPERTIES (
    "compression"             = "ZSTD",
    "datacache.enable"        = "true",
    "replication_num"         = "1",
    "enable_persistent_index" = "true"
);
