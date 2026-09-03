/* ============================================================
 * DWD L2 宽表 / 声学谐振滤波器 (acoustic_resonator_filter)
 *
 * L2 物理列来源：
 *   dim.dim_attr_schema  WHERE
 *     l1_code='filter' AND scope_level='l2'
 *     AND scope_code='acoustic_resonator_filter'
 *
 * L3 专有属性 → ext_attributes JSON
 *   scope_level='l3', scope_code=l3_code
 *   saw_filter          : saw_topology_type / tcf_ppm_per_c / max_input_power_dbm /
 *                         group_delay_var_ns / passband_ripple_db / iip3_dbm
 *   baw_filter          : baw_resonator_type / q_factor / kt2_eff_pct /
 *                         max_input_power_dbm / tcf_ppm_per_c / iip3_dbm
 *   piezoelectric_*     : substrate_material / tcf_ppm_per_c / relative_bandwidth_pct /
 *                         passband_ripple_db / resonator_count / crystal_cut_mode / spurious_rejection_db
 *
 * prod 合并替换规则：
 *   s/test_dwd\./dwd./g
 *   s/test_dim\./dim./g
 * ============================================================ */

DROP TABLE IF EXISTS dwd.dwd_l2_filter_acoustic_resonator_filter;

CREATE TABLE dwd.dwd_l2_filter_acoustic_resonator_filter (
    /* ── 主键 / 关联键 ─────────────────────────────── */
    `data_source`            VARCHAR(32)    NOT NULL DEFAULT 'digikey'
                             COMMENT '数据源 digikey | mouser | ...',
    `id`                     BIGINT         NOT NULL
                             COMMENT '物料唯一 ID',
    `mpn`                    VARCHAR(1024)  NULL     COMMENT '物料编号（MPN）',
    `brand`                  VARCHAR(256)   NULL     COMMENT '标准化品牌全称',
    `brandid`                BIGINT         NULL     COMMENT '标准化品牌 ID',
    `l1_code`                VARCHAR(32)    NOT NULL COMMENT 'L1: filter',
    `l2_code`                VARCHAR(96)    NOT NULL COMMENT 'L2: acoustic_resonator_filter',
    `l3_code`                VARCHAR(96)    NULL     COMMENT 'L3 动态分类',

    /* ── 试点扩展列 ─────────────────────────────────── */
    `brandshort`             VARCHAR(256)   NULL     COMMENT '原始品牌简称',
    `l3_id`                  INT            NULL     COMMENT 'L3 内部 ID',

    /* ── L2 公共合规/交易属性 ───────────────────────── */
    `manufacturer`           VARCHAR(1024)  NULL     COMMENT '制造商',
    `lifecycle_status`       VARCHAR(64)    NULL     COMMENT '生命周期状态',
    `eccn_code`              VARCHAR(128)   NULL     COMMENT '出口管制分类号',
    `htsus_code`             VARCHAR(64)    NULL     COMMENT '美国协调关税税则号',
    `rohs_compliant`         TINYINT   NULL     COMMENT 'RoHS 合规',
    `reach`                  VARCHAR(256)   NULL     COMMENT 'REACH 合规',
    `aec_q_level`            VARCHAR(128)   NULL     COMMENT '汽车电子认证等级',
    `lead_free`              TINYINT   NULL     COMMENT '无铅认证',
    `msl_level`              VARCHAR(64)    NULL     COMMENT '湿气敏感等级',
    `package_case`           VARCHAR(1024)  NULL     COMMENT '封装型号',
    `mounting_style`         VARCHAR(128)   NULL     COMMENT '安装方式：smd / through_hole / chassis / panel / other',
    `pkg_length_mm`          DOUBLE         NULL     COMMENT '封装长度 mm',
    `pkg_width_mm`           DOUBLE         NULL     COMMENT '封装宽度 mm',
    `pkg_height_mm`          DOUBLE         NULL     COMMENT '封装高度 mm',
    `temp_min_c`             DOUBLE         NULL     COMMENT '最低工作温度 ℃',
    `temp_max_c`             DOUBLE         NULL     COMMENT '最高工作温度 ℃',

    /* ── L2 声学专有技术属性 ────────────────────────── */
    `nominal_frequency_mhz`  DOUBLE         NULL     COMMENT '标称中心频率 MHz',
    `bandwidth_mhz`          DOUBLE         NULL     COMMENT '3dB 带宽 MHz',
    `insertion_loss_db`      DOUBLE         NULL     COMMENT '插入损耗 dB',
    `stopband_rejection_db`  DOUBLE         NULL     COMMENT '带外抑制 dB（DK 未录，其他源补）',
    `return_loss_db`         DOUBLE         NULL     COMMENT '回波损耗 dB（DK 未录，其他源补）',

    /* ── L3 专有属性（JSON）────────────────────────── */
    `ext_attributes`         JSON           NULL
                             COMMENT 'L3 专有标准化属性（saw_filter / baw_filter / piezoelectric_resonator_filter）',
    `semantic_tags`          JSON           NULL     COMMENT '业务标签（预留）',

    /* ── 数据质量（预留）────────────────────────────── */
    `dq_score`               DOUBLE         NULL,
    `dq_flags`               JSON           NULL,

    /* ── 溯源 ──────────────────────────────────────── */
    `source_id`              BIGINT         NULL,

    /* ── 元数据 ─────────────────────────────────────── */
    `create_at`              DATETIME       NULL DEFAULT CURRENT_TIMESTAMP,
    `update_at`              DATETIME       NULL DEFAULT CURRENT_TIMESTAMP

) ENGINE = OLAP
PRIMARY KEY (`data_source`, `id`)
COMMENT 'DWD L2 声学谐振滤波器宽表；列与 dim_attr_schema filter/acoustic_resonator_filter 保持一致'
DISTRIBUTED BY HASH(`id`) BUCKETS 4
PROPERTIES (
    "compression"             = "ZSTD",
    "datacache.enable"        = "true",
    "replication_num"         = "1",
    "enable_persistent_index" = "true"
);
