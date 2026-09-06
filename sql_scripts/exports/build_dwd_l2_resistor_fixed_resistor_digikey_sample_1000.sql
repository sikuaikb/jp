/* ============================================================
 * DigiKey 固定电阻抽样 1000 条 → dwd.dwd_l2_resistor_fixed_resistor_digikey_sample_1000
 *
 * 来源：dwd.dwd_l2_resistor_fixed_resistor（data_source='digikey'）
 * 关联：dwd.dwd_digikey_component_param.datasheet_url（必须非空）
 *
 * 抽样策略：
 *   1. 公共门槛：brand / datasheet_url 非空；核心电阻参数齐全
 *      （resistance_ohm、tolerance_pct、power_rating_w、package_case、manufacturer、mpn）
 *   2. L3 分形态完整度（DigiKey 数据按 L3 落列不同，不能统一用 ext_attributes 衡量）：
 *      - general_fixed_resistor：L2 列尽量满（l2_score >= 18），且 resistive_element_technology 非空
 *        （该 L3 的 ext_attributes 在源数据中恒为空，属正常）
 *      - resistor_array_network：ext_attributes 必须非空，且 l2_score >= 17
 *   3. fill_score = l2_score + has_ext（最大 27）；层内按 fill_score 优先
 *   4. l3_code 各取 500 条；brand 层内轮询，避免单一品牌过度集中
 *
 * 执行：bash sql_scripts/exports/build_dwd_l2_resistor_fixed_resistor_digikey_sample_1000.sh
 * ============================================================ */

DROP TABLE IF EXISTS dwd.dwd_l2_resistor_fixed_resistor_digikey_sample_1000;

CREATE TABLE dwd.dwd_l2_resistor_fixed_resistor_digikey_sample_1000 (
    `data_source`                      VARCHAR(32)     NOT NULL COMMENT '固定 digikey',
    `id`                               BIGINT          NOT NULL COMMENT '组件唯一ID',
    `mpn`                              VARCHAR(1024)   NULL     COMMENT '制造商料号',
    `brand`                            VARCHAR(256)    NULL     COMMENT '标准品牌名',
    `brandid`                          BIGINT          NULL     COMMENT '标准品牌ID',
    `l1_code`                          VARCHAR(32)     NOT NULL COMMENT 'L1：resistor',
    `l2_code`                          VARCHAR(32)     NOT NULL COMMENT 'L2：fixed_resistor',
    `l3_code`                          VARCHAR(64)     NULL     COMMENT 'L3 形态编码',
    `manufacturer`                     VARCHAR(1024)   NULL,
    `rohs_compliant`                   BOOLEAN         NULL,
    `lifecycle_status`                 VARCHAR(64)     NULL,
    `reach`                            BOOLEAN         NULL,
    `eccn_code`                        VARCHAR(128)    NULL,
    `aec_q_level`                      VARCHAR(64)     NULL,
    `lead_free`                        BOOLEAN         NULL,
    `msl_level`                        VARCHAR(1024)   NULL,
    `package_case`                     VARCHAR(1024)   NULL,
    `temp_min_c`                       DOUBLE          NULL,
    `temp_max_c`                       DOUBLE          NULL,
    `pkg_length_mm`                    DOUBLE          NULL,
    `pkg_width_mm`                     DOUBLE          NULL,
    `pkg_height_mm`                    DOUBLE          NULL,
    `resistor_type`                    VARCHAR(128)    NULL,
    `resistive_element_technology`     VARCHAR(256)    NULL,
    `body_material`                    VARCHAR(128)    NULL,
    `form_factor`                      VARCHAR(128)    NULL,
    `mounting_style`                   VARCHAR(128)    NULL,
    `flameproof`                       BOOLEAN         NULL,
    `resistance_ohm`                   DOUBLE          NULL,
    `tolerance_pct`                    DOUBLE          NULL,
    `power_rating_w`                   DOUBLE          NULL,
    `tcr_ppm_per_c`                    DOUBLE          NULL,
    `max_working_voltage_v`            DOUBLE          NULL,
    `ext_attributes`                   JSON            NULL,
    `semantic_tags`                    JSON            NULL,
    `dq_score`                         DOUBLE          NULL,
    `dq_flags`                         JSON            NULL,
    `source_id`                        BIGINT          NULL,
    `datasheet_url`                    VARCHAR(1024)   NOT NULL COMMENT '规格书 PDF URL',
    `fill_score`                       INT             NOT NULL COMMENT '属性完整度 = l2_score + has_ext（最大 27）',
    `l2_score`                         INT             NOT NULL COMMENT 'L2 物理列非空计数（最大 26）',
    `sample_rank`                      INT             NOT NULL COMMENT '层内轮询排序（越小越优先被抽中）',
    `create_at`                        DATETIME        NULL DEFAULT CURRENT_TIMESTAMP,
    `update_at`                        DATETIME        NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=OLAP
PRIMARY KEY(`data_source`, `id`)
COMMENT 'DigiKey 固定电阻抽样 1000 条（属性完整 + datasheet_url 非空 + l3/brand 离散）'
DISTRIBUTED BY HASH(`id`) BUCKETS 8
PROPERTIES (
    "compression"             = "ZSTD",
    "replication_num"         = "1",
    "enable_persistent_index" = "true"
);

INSERT INTO dwd.dwd_l2_resistor_fixed_resistor_digikey_sample_1000
(
    data_source, id, mpn, brand, brandid,
    l1_code, l2_code, l3_code,
    manufacturer, rohs_compliant, lifecycle_status, reach, eccn_code, aec_q_level, lead_free,
    msl_level, package_case, temp_min_c, temp_max_c,
    pkg_length_mm, pkg_width_mm, pkg_height_mm,
    resistor_type, resistive_element_technology, body_material, form_factor, mounting_style, flameproof,
    resistance_ohm, tolerance_pct, power_rating_w, tcr_ppm_per_c, max_working_voltage_v,
    ext_attributes, semantic_tags, dq_score, dq_flags, source_id,
    datasheet_url, fill_score, l2_score, sample_rank,
    create_at, update_at
)
WITH base AS (
    SELECT
        r.*,
        p.datasheet_url,
        (
            (CASE WHEN r.mpn IS NOT NULL AND TRIM(r.mpn) <> '' THEN 1 ELSE 0 END)
          + (CASE WHEN r.manufacturer IS NOT NULL AND TRIM(r.manufacturer) <> '' THEN 1 ELSE 0 END)
          + (CASE WHEN r.rohs_compliant IS NOT NULL THEN 1 ELSE 0 END)
          + (CASE WHEN r.lifecycle_status IS NOT NULL AND TRIM(r.lifecycle_status) <> '' THEN 1 ELSE 0 END)
          + (CASE WHEN r.reach IS NOT NULL THEN 1 ELSE 0 END)
          + (CASE WHEN r.eccn_code IS NOT NULL AND TRIM(r.eccn_code) <> '' THEN 1 ELSE 0 END)
          + (CASE WHEN r.aec_q_level IS NOT NULL AND TRIM(r.aec_q_level) <> '' THEN 1 ELSE 0 END)
          + (CASE WHEN r.lead_free IS NOT NULL THEN 1 ELSE 0 END)
          + (CASE WHEN r.msl_level IS NOT NULL AND TRIM(r.msl_level) <> '' THEN 1 ELSE 0 END)
          + (CASE WHEN r.package_case IS NOT NULL AND TRIM(r.package_case) <> '' THEN 1 ELSE 0 END)
          + (CASE WHEN r.temp_min_c IS NOT NULL THEN 1 ELSE 0 END)
          + (CASE WHEN r.temp_max_c IS NOT NULL THEN 1 ELSE 0 END)
          + (CASE WHEN r.pkg_length_mm IS NOT NULL THEN 1 ELSE 0 END)
          + (CASE WHEN r.pkg_width_mm IS NOT NULL THEN 1 ELSE 0 END)
          + (CASE WHEN r.pkg_height_mm IS NOT NULL THEN 1 ELSE 0 END)
          + (CASE WHEN r.resistor_type IS NOT NULL AND TRIM(r.resistor_type) <> '' THEN 1 ELSE 0 END)
          + (CASE WHEN r.resistive_element_technology IS NOT NULL AND TRIM(r.resistive_element_technology) <> '' THEN 1 ELSE 0 END)
          + (CASE WHEN r.body_material IS NOT NULL AND TRIM(r.body_material) <> '' THEN 1 ELSE 0 END)
          + (CASE WHEN r.form_factor IS NOT NULL AND TRIM(r.form_factor) <> '' THEN 1 ELSE 0 END)
          + (CASE WHEN r.mounting_style IS NOT NULL AND TRIM(r.mounting_style) <> '' THEN 1 ELSE 0 END)
          + (CASE WHEN r.flameproof IS NOT NULL THEN 1 ELSE 0 END)
          + (CASE WHEN r.resistance_ohm IS NOT NULL THEN 1 ELSE 0 END)
          + (CASE WHEN r.tolerance_pct IS NOT NULL THEN 1 ELSE 0 END)
          + (CASE WHEN r.power_rating_w IS NOT NULL THEN 1 ELSE 0 END)
          + (CASE WHEN r.tcr_ppm_per_c IS NOT NULL THEN 1 ELSE 0 END)
          + (CASE WHEN r.max_working_voltage_v IS NOT NULL THEN 1 ELSE 0 END)
        ) AS l2_score,
        (CASE WHEN r.ext_attributes IS NOT NULL THEN 1 ELSE 0 END) AS has_ext
    FROM dwd.dwd_l2_resistor_fixed_resistor r
    INNER JOIN dwd.dwd_digikey_component_param p
            ON p.id = r.id
    WHERE r.data_source = 'digikey'
      AND r.brand IS NOT NULL
      AND TRIM(r.brand) <> ''
      AND p.datasheet_url IS NOT NULL
      AND TRIM(p.datasheet_url) <> ''
      AND r.resistance_ohm IS NOT NULL
      AND r.tolerance_pct IS NOT NULL
      AND r.power_rating_w IS NOT NULL
      AND r.package_case IS NOT NULL
      AND TRIM(r.package_case) <> ''
      AND r.manufacturer IS NOT NULL
      AND TRIM(r.manufacturer) <> ''
      AND r.mpn IS NOT NULL
      AND TRIM(r.mpn) <> ''
),
scored AS (
    SELECT
        b.*,
        b.l2_score + b.has_ext AS fill_score
    FROM base b
),
filtered AS (
    SELECT *
    FROM scored
    WHERE (
            l3_code = 'general_fixed_resistor'
        AND resistive_element_technology IS NOT NULL
        AND TRIM(resistive_element_technology) <> ''
        AND l2_score >= 18
    ) OR (
            l3_code = 'resistor_array_network'
        AND has_ext = 1
        AND l2_score >= 17
    )
),
ranked AS (
    SELECT
        b.*,
        ROW_NUMBER() OVER (
            PARTITION BY b.l3_code, b.brand
            ORDER BY b.fill_score DESC, b.id
        ) AS rn_in_brand
    FROM filtered b
),
round_pick AS (
    SELECT
        r.*,
        ROW_NUMBER() OVER (
            PARTITION BY r.l3_code
            ORDER BY r.rn_in_brand, r.brand, r.id
        ) AS sample_rank
    FROM ranked r
    WHERE r.rn_in_brand <= 50
),
phase1 AS (
    SELECT
        data_source, id, mpn, brand, brandid,
        l1_code, l2_code, l3_code,
        manufacturer, rohs_compliant, lifecycle_status, reach, eccn_code, aec_q_level, lead_free,
        msl_level, package_case, temp_min_c, temp_max_c,
        pkg_length_mm, pkg_width_mm, pkg_height_mm,
        resistor_type, resistive_element_technology, body_material, form_factor, mounting_style, flameproof,
        resistance_ohm, tolerance_pct, power_rating_w, tcr_ppm_per_c, max_working_voltage_v,
        ext_attributes, semantic_tags, dq_score, dq_flags, source_id,
        datasheet_url, fill_score, l2_score, sample_rank
    FROM round_pick
    WHERE sample_rank <= 500
),
l3_quota AS (
    SELECT l3_code, COUNT(*) AS picked_cnt
    FROM phase1
    GROUP BY l3_code
),
backfill AS (
    SELECT
        f.data_source, f.id, f.mpn, f.brand, f.brandid,
        f.l1_code, f.l2_code, f.l3_code,
        f.manufacturer, f.rohs_compliant, f.lifecycle_status, f.reach, f.eccn_code, f.aec_q_level, f.lead_free,
        f.msl_level, f.package_case, f.temp_min_c, f.temp_max_c,
        f.pkg_length_mm, f.pkg_width_mm, f.pkg_height_mm,
        f.resistor_type, f.resistive_element_technology, f.body_material, f.form_factor, f.mounting_style, f.flameproof,
        f.resistance_ohm, f.tolerance_pct, f.power_rating_w, f.tcr_ppm_per_c, f.max_working_voltage_v,
        f.ext_attributes, f.semantic_tags, f.dq_score, f.dq_flags, f.source_id,
        f.datasheet_url, f.fill_score, f.l2_score,
        10000 + ROW_NUMBER() OVER (
            PARTITION BY f.l3_code
            ORDER BY f.fill_score DESC, f.id
        ) AS sample_rank
    FROM filtered f
    INNER JOIN l3_quota q ON q.l3_code = f.l3_code
    LEFT JOIN phase1 p ON p.id = f.id
    WHERE q.picked_cnt < 500
      AND p.id IS NULL
),
phase2 AS (
    SELECT
        b.data_source, b.id, b.mpn, b.brand, b.brandid,
        b.l1_code, b.l2_code, b.l3_code,
        b.manufacturer, b.rohs_compliant, b.lifecycle_status, b.reach, b.eccn_code, b.aec_q_level, b.lead_free,
        b.msl_level, b.package_case, b.temp_min_c, b.temp_max_c,
        b.pkg_length_mm, b.pkg_width_mm, b.pkg_height_mm,
        b.resistor_type, b.resistive_element_technology, b.body_material, b.form_factor, b.mounting_style, b.flameproof,
        b.resistance_ohm, b.tolerance_pct, b.power_rating_w, b.tcr_ppm_per_c, b.max_working_voltage_v,
        b.ext_attributes, b.semantic_tags, b.dq_score, b.dq_flags, b.source_id,
        b.datasheet_url, b.fill_score, b.l2_score, b.sample_rank
    FROM backfill b
    INNER JOIN l3_quota q ON q.l3_code = b.l3_code
    WHERE b.sample_rank <= 10000 + (500 - q.picked_cnt)
),
picked AS (
    SELECT * FROM phase1
    UNION ALL
    SELECT * FROM phase2
)
SELECT
    data_source, id, mpn, brand, brandid,
    l1_code, l2_code, l3_code,
    manufacturer, rohs_compliant, lifecycle_status, reach, eccn_code, aec_q_level, lead_free,
    msl_level, package_case, temp_min_c, temp_max_c,
    pkg_length_mm, pkg_width_mm, pkg_height_mm,
    resistor_type, resistive_element_technology, body_material, form_factor, mounting_style, flameproof,
    resistance_ohm, tolerance_pct, power_rating_w, tcr_ppm_per_c, max_working_voltage_v,
    ext_attributes, semantic_tags, dq_score, dq_flags, source_id,
    datasheet_url, fill_score, l2_score, sample_rank,
    CURRENT_TIMESTAMP() AS create_at,
    CURRENT_TIMESTAMP() AS update_at
FROM picked;

/* ---------- 校验 ---------- */
SELECT 'total' AS metric, COUNT(*) AS val
FROM dwd.dwd_l2_resistor_fixed_resistor_digikey_sample_1000
UNION ALL
SELECT 'null_datasheet', COUNT(*)
FROM dwd.dwd_l2_resistor_fixed_resistor_digikey_sample_1000
WHERE datasheet_url IS NULL OR TRIM(datasheet_url) = ''
UNION ALL
SELECT 'min_fill_score', MIN(fill_score)
FROM dwd.dwd_l2_resistor_fixed_resistor_digikey_sample_1000
UNION ALL
SELECT 'avg_fill_score', CAST(AVG(fill_score) AS BIGINT)
FROM dwd.dwd_l2_resistor_fixed_resistor_digikey_sample_1000
UNION ALL
SELECT 'min_l2_score', MIN(l2_score)
FROM dwd.dwd_l2_resistor_fixed_resistor_digikey_sample_1000
UNION ALL
SELECT 'avg_l2_score', CAST(AVG(l2_score) AS BIGINT)
FROM dwd.dwd_l2_resistor_fixed_resistor_digikey_sample_1000;

SELECT l3_code,
    COUNT(*) AS cnt,
    SUM(CASE WHEN ext_attributes IS NULL THEN 1 ELSE 0 END) AS ext_null,
    SUM(CASE WHEN resistive_element_technology IS NULL OR TRIM(resistive_element_technology) = '' THEN 1 ELSE 0 END) AS tech_null,
    SUM(CASE WHEN tolerance_pct IS NULL THEN 1 ELSE 0 END) AS tol_null,
    SUM(CASE WHEN power_rating_w IS NULL THEN 1 ELSE 0 END) AS pwr_null,
    SUM(CASE WHEN tcr_ppm_per_c IS NULL THEN 1 ELSE 0 END) AS tcr_null,
    MIN(l2_score) AS min_l2,
    CAST(AVG(l2_score) AS INT) AS avg_l2
FROM dwd.dwd_l2_resistor_fixed_resistor_digikey_sample_1000
GROUP BY l3_code
ORDER BY l3_code;

SELECT l3_code, COUNT(*) AS cnt
FROM dwd.dwd_l2_resistor_fixed_resistor_digikey_sample_1000
GROUP BY l3_code
ORDER BY l3_code;

SELECT brand, COUNT(*) AS cnt
FROM dwd.dwd_l2_resistor_fixed_resistor_digikey_sample_1000
GROUP BY brand
ORDER BY cnt DESC, brand
LIMIT 20;

SELECT
    l3_code,
    COUNT(DISTINCT brand) AS brand_cnt,
    MAX(cnt) AS max_per_brand,
    MIN(cnt) AS min_per_brand,
    CAST(AVG(cnt) AS DECIMAL(10, 2)) AS avg_per_brand
FROM (
    SELECT l3_code, brand, COUNT(*) AS cnt
    FROM dwd.dwd_l2_resistor_fixed_resistor_digikey_sample_1000
    GROUP BY l3_code, brand
) t
GROUP BY l3_code;
