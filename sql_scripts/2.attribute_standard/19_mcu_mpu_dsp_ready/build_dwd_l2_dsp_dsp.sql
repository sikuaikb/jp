/* ============================================================
 * 装配 SQL：dwd_component_attr_std（EAV）→ dwd.dwd_l2_dsp
 *
 * 品牌标准化：LEFT JOIN dim.v_std_brand_alias ON UPPER(TRIM(brandshort))；
 *             brand_null=0 且 distinct_brand=distinct_brandid 为门控指标。
 *
 * 分类来源：dwd.dwd_component_class（l1_code='dsp'）
 * 依赖：dim.v_std_brand_alias（品牌别名视图）
 * 执行：mysql … -D dwd < build_dwd_l2_dsp.sql
 * ============================================================ */

INSERT INTO dwd.dwd_l2_dsp_dsp
(
    id, mpn, brand, brandid,
    l1_code, l2_code, l3_code,
    manufacturer, rohs_compliant, lifecycle_status, reach, eccn_code,
    aec_q_level, lead_free, msl_level, package_case,
    temp_min_c, temp_max_c,
    core_clock_max_mhz, core_data_width_bit, onchip_sram_kb,
    supply_voltage_min_v, supply_voltage_max_v,
    ext_attributes, semantic_tags,
    dq_score, dq_flags,
    data_source, source_id,
    create_at, update_at
)
WITH src_param AS (
    SELECT 'icpdf' AS data_source, id, partno, brandshort, brandid
    FROM dwd.dwd_icpdf_component_param
),
ext AS (
    SELECT
        e.data_source,
        e.id,
        concat(
            '{',
            array_join(
                array_agg(
                    concat(
                        '"', e.std_attr_code, '":',
                        CASE
                            WHEN e.db_type IN ('VARCHAR')
                                THEN concat('"', replace(COALESCE(e.value_std_varchar, ''), '"', '\\"'), '"')
                            ELSE COALESCE(CAST(e.value_std_double AS VARCHAR), 'null')
                        END
                    )
                ),
                ','
            ),
            '}'
        ) AS ext_attributes_str
    FROM dwd.dwd_component_attr_std e
    INNER JOIN dwd.dwd_component_class c ON c.id = e.id AND c.data_source = e.data_source AND c.l1_code = 'dsp'
    INNER JOIN dim.dim_attr_schema d
            ON d.std_attr_code = e.std_attr_code
           AND d.l1_code = 'dsp'
           AND d.scope_level = 'l3'
           AND d.scope_code = c.l3_code
    WHERE c.l3_code IS NOT NULL
      AND (
          e.value_std_double IS NOT NULL
          OR (e.value_std_varchar IS NOT NULL AND trim(e.value_std_varchar) <> '')
      )
    GROUP BY e.data_source, e.id
)
SELECT
    c.id,
    COALESCE(
        NULLIF(TRIM(MAX(CASE WHEN v.std_attr_code = 'mpn' THEN v.value_std_varchar END)), ''),
        p.partno
    ) AS mpn,
    COALESCE(a.canonical_name, p.brandshort) AS brand,
    COALESCE(a.brand_id_std,   p.brandid)   AS brandid,
    c.l1_code,
    c.l2_code,
    c.l3_code,

    MAX(CASE WHEN v.std_attr_code = 'manufacturer' THEN v.value_std_varchar END)      AS manufacturer,
    MAX(CASE WHEN v.std_attr_code = 'rohs_compliant' THEN v.value_std_varchar END)    AS rohs_compliant,
    MAX(CASE WHEN v.std_attr_code = 'lifecycle_status' THEN v.value_std_varchar END)  AS lifecycle_status,
    NULL                                                                                AS reach,
    MAX(CASE WHEN v.std_attr_code = 'eccn_code' THEN v.value_std_varchar END)         AS eccn_code,
    NULL                                                                                AS aec_q_level,
    MAX(CASE WHEN v.std_attr_code = 'lead_free' THEN v.value_std_varchar END)         AS lead_free,
    NULL                                                                                AS msl_level,
    MAX(CASE WHEN v.std_attr_code = 'package_case' THEN v.value_std_varchar END)      AS package_case,
    MAX(CASE WHEN v.std_attr_code = 'temp_min_c' THEN v.value_std_double END)         AS temp_min_c,
    MAX(CASE WHEN v.std_attr_code = 'temp_max_c' THEN v.value_std_double END)         AS temp_max_c,

    MAX(CASE WHEN v.std_attr_code = 'core_clock_max_mhz' THEN v.value_std_double END) AS core_clock_max_mhz,
    CAST(MAX(CASE WHEN v.std_attr_code = 'core_data_width_bit' THEN v.value_std_double END) AS INT) AS core_data_width_bit,
    MAX(CASE WHEN v.std_attr_code = 'onchip_sram_kb' THEN v.value_std_double END)     AS onchip_sram_kb,
    MAX(CASE WHEN v.std_attr_code = 'supply_voltage_min_v' THEN v.value_std_double END) AS supply_voltage_min_v,
    MAX(CASE WHEN v.std_attr_code = 'supply_voltage_max_v' THEN v.value_std_double END) AS supply_voltage_max_v,

    parse_json(MAX(x.ext_attributes_str)) AS ext_attributes,
    NULL AS semantic_tags,
    NULL AS dq_score,
    NULL AS dq_flags,

    c.data_source,
    c.id    AS source_id,

    COALESCE(MAX(old.create_at), CURRENT_TIMESTAMP()) AS create_at,
    CURRENT_TIMESTAMP()                               AS update_at

FROM dwd.dwd_component_class c
INNER JOIN src_param p ON p.id = c.id AND p.data_source = c.data_source
LEFT JOIN dim.v_std_brand_alias a ON a.brand_key = UPPER(TRIM(p.brandshort))
LEFT JOIN dwd.dwd_component_attr_std v ON v.id = c.id AND v.l2_code = c.l2_code AND v.data_source = c.data_source
LEFT JOIN ext x ON x.id = c.id AND x.data_source = c.data_source
LEFT JOIN dwd.dwd_l2_dsp_dsp old ON old.id = c.id AND old.data_source = c.data_source
WHERE c.l1_code = 'dsp'
  AND c.l2_code IS NOT NULL
  AND c.l3_code NOT LIKE '%_unclassified'
GROUP BY
    c.id, c.data_source,
    p.partno,
    p.brandshort,
    p.brandid,
    a.brand_id_std,
    a.canonical_name,
    c.l1_code,
    c.l2_code,
    c.l3_code;


/* ---------- 校验 ---------- */
SELECT
    l3_code,
    COUNT(*) AS rows_total,
    SUM(CASE WHEN core_clock_max_mhz IS NOT NULL THEN 1 ELSE 0 END)  AS has_freq,
    SUM(CASE WHEN core_data_width_bit IS NOT NULL THEN 1 ELSE 0 END) AS has_dw,
    SUM(CASE WHEN onchip_sram_kb IS NOT NULL THEN 1 ELSE 0 END)      AS has_sram,
    SUM(CASE WHEN package_case IS NOT NULL THEN 1 ELSE 0 END)        AS has_pkg,
    SUM(CASE WHEN rohs_compliant IS NOT NULL THEN 1 ELSE 0 END)      AS has_rohs,
    SUM(CASE WHEN manufacturer IS NOT NULL THEN 1 ELSE 0 END)        AS has_mfr
FROM dwd.dwd_l2_dsp
GROUP BY l3_code
ORDER BY rows_total DESC;
