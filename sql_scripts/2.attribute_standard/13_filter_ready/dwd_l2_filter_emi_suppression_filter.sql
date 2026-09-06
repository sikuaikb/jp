/* ============================================================
 * DWD L2 宽表 / EMI 抑制滤波器 (emi_suppression_filter)
 *
 * L2 物理列来源：
 *   dim.dim_attr_schema  WHERE
 *     l1_code='filter' AND scope_level='l2'
 *     AND scope_code='emi_suppression_filter'
 *
 * L3 专有属性 → ext_attributes JSON
 *   scope_level='l3', scope_code=l3_code
 *
 * 品牌：COALESCE(canonical_name, brandshort)
 *   dim.v_std_brand_alias 权限不足时退化为 brandshort（test 可接受）
 *
 * test 环境：在 test_dwd 库执行 DDL；build 引用 test_dwd / test_dim 表
 * prod 合并时：s/test_dwd\./dwd./g  s/test_dim\./dim./g
 * ============================================================ */

DROP TABLE IF EXISTS dwd.dwd_l2_filter_emi_suppression_filter;

CREATE TABLE dwd.dwd_l2_filter_emi_suppression_filter (
    /* ── 主键 / 关联键 ─────────────────────────────── */
    `data_source`            VARCHAR(32)    NOT NULL DEFAULT 'digikey'
                             COMMENT '数据源 digikey | mouser | ...',
    `id`                     BIGINT         NOT NULL
                             COMMENT '物料唯一 ID',
    `mpn`                    VARCHAR(1024)  NULL
                             COMMENT '物料编号（MPN），同源 dwd_digikey_component_param.partno',
    `brand`                  VARCHAR(256)   NULL
                             COMMENT '标准化品牌全称；缺字典时退化为 brandshort',
    `brandid`                BIGINT         NULL
                             COMMENT '标准化品牌 ID（dim_std_brand.brand_id_std）',
    `l1_code`                VARCHAR(32)    NOT NULL COMMENT 'L1: filter',
    `l2_code`                VARCHAR(96)    NOT NULL COMMENT 'L2: emi_suppression_filter',
    `l3_code`                VARCHAR(96)    NULL     COMMENT 'L3 动态分类',

    /* ── 试点扩展列（非 dim_attr_schema 物理列）────── */
    `brandshort`             VARCHAR(256)   NULL
                             COMMENT '原始品牌简称（dwd_digikey_component_param.brandshort）',
    `l3_id`                  INT            NULL     COMMENT 'L3 内部 ID',

    /* ── L2 公共技术属性（17 字段）──────────────────── */
    `manufacturer`           VARCHAR(1024)  NULL     COMMENT '制造商（仅来自 EAV，不 COALESCE 兜底）',
    `lifecycle_status`       VARCHAR(64)    NULL     COMMENT '生命周期状态',
    `eccn_code`              VARCHAR(128)   NULL     COMMENT '出口管制分类号',
    `htsus_code`             VARCHAR(64)    NULL     COMMENT '美国协调关税税则号 HTSUS',
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
    `rated_current_ma`       DOUBLE         NULL     COMMENT '额定电流 mA（EMI L2 公共）',
    /* dcr_mohm 已移至 ferrite_bead L3 ext_attributes；impedance_100mhz_ohm 已移至 ferrite_bead L3 ext */

    /* ── L3 专有属性（JSON）────────────────────────── */
    `ext_attributes`         JSON           NULL
                             COMMENT 'L3 专有标准化属性；emi_common_mode_filter/emi_power_line_filter/ferrite_bead/feedthrough_capacitor/emi_lc_rc_filter 各自的字段',
    `semantic_tags`          JSON           NULL
                             COMMENT '业务标签数组（预留，对齐电阻基准尾部）',

    /* ── 数据质量 ───────────────────────────────────── */
    `dq_score`               DOUBLE         NULL     COMMENT '数据质量综合分（预留）',
    `dq_flags`               JSON           NULL     COMMENT '数据质量标记（预留）',

    /* ── 溯源 ──────────────────────────────────────── */
    `source_id`              BIGINT         NULL     COMMENT '源端原始 id',

    /* ── 元数据 ─────────────────────────────────────── */
    `create_at`              DATETIME       NULL DEFAULT CURRENT_TIMESTAMP
                             COMMENT '首次写入时间',
    `update_at`              DATETIME       NULL DEFAULT CURRENT_TIMESTAMP
                             COMMENT '最后更新时间'

) ENGINE = OLAP
PRIMARY KEY (`data_source`, `id`)
COMMENT 'DWD L2 EMI 抑制滤波器宽表；列与 dim_attr_schema filter/emi_suppression_filter 保持一致'
DISTRIBUTED BY HASH(`id`) BUCKETS 16
PROPERTIES (
    "compression"             = "ZSTD",
    "datacache.enable"        = "true",
    "replication_num"         = "1",
    "enable_persistent_index" = "true"
);
