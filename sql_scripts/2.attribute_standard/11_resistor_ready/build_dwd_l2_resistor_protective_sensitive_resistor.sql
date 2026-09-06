/* ============================================================
 * 装配 SQL：dwd_component_attr_std（EAV，多源；data_source=icpdf|digikey|ecloud）→ dwd_l2_resistor_protective_sensitive_resistor
 *
 * 透视规则：dim.dim_attr_schema scope_level=l2 & scope_code=protective_sensitive_resistor → 物理列；
 * scope_level=l3 & scope_code=c.l3_code → ext_attributes JSON。
 *
 * 依赖：build_dwd_component_attr_std_{icpdf,digikey,ecloud}.sql；dim.dim_attr_schema；
 *       dwd.dwd_l2_resistor_protective_sensitive_resistor（DDL 见 dwd_l2_resistor_protective_sensitive_resistor.sql）
 *
 * 执行：mysql … -D dwd < sql_scripts/属性标准化/build_dwd_l2_resistor_protective_sensitive_resistor.sql
 * ============================================================ */

INSERT INTO dwd.dwd_l2_resistor_protective_sensitive_resistor
(
    id, mpn, brand, brandid,
    l1_code, l2_code, l3_code,
    manufacturer, rohs_compliant, lifecycle_status, reach, eccn_code, aec_q_level, lead_free,
    msl_level, package_case, temp_min_c, temp_max_c,
    pkg_length_mm, pkg_width_mm, pkg_height_mm,
    resistance_25c_ohm, resistance_tolerance_pct, power_rating_w, voltage_max_v,
    ext_attributes, semantic_tags,
    dq_score, dq_flags,
    data_source, source_id,
    create_at, update_at
)
WITH src_param AS (
    SELECT 'icpdf'   AS data_source, id, partno, brandshort, brandid
    FROM dwd.dwd_icpdf_component_param
    UNION ALL
    SELECT 'digikey' AS data_source, id, partno, brandshort, brandid
    FROM dwd.dwd_digikey_component_param
    UNION ALL
    SELECT 'ecloud'  AS data_source, id, partno, brandshort, brandid
    FROM dwd.dwd_ecloud_component_param
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
                            WHEN e.db_type = 'BOOLEAN'
                                THEN CASE
                                        WHEN CAST(e.value_std_double AS INT) = 1 THEN 'true'
                                        WHEN CAST(e.value_std_double AS INT) = 0 THEN 'false'
                                        ELSE 'null'
                                     END
                            ELSE COALESCE(CAST(e.value_std_double AS VARCHAR), 'null')
                        END
                    )
                ),
                ','
            ),
            '}'
        ) AS ext_attributes_str
    FROM dwd.dwd_component_attr_std e
    INNER JOIN dwd.dwd_component_class c ON c.id = e.id AND c.data_source = e.data_source
    INNER JOIN dim.dim_attr_schema d
            ON d.schema_version = e.attr_schema_version
           AND d.l1_code = 'resistor'
           AND d.std_attr_code = e.std_attr_code
           AND d.scope_level = 'l3'
           AND d.scope_code = c.l3_code
    WHERE c.l2_code = 'protective_sensitive_resistor'
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
    COALESCE(a.canonical_name, p.brandshort)    AS brand,
    COALESCE(a.brand_id_std,   p.brandid)       AS brandid,
    c.l1_code,
    c.l2_code,
    c.l3_code,

    MAX(CASE WHEN v.std_attr_code = 'manufacturer' THEN v.value_std_varchar END) AS manufacturer,
    MAX(CASE WHEN v.std_attr_code = 'rohs_compliant' THEN CAST(v.value_std_double AS BOOLEAN) END) AS rohs_compliant,
    MAX(CASE WHEN v.std_attr_code = 'lifecycle_status' THEN v.value_std_varchar END) AS lifecycle_status,
    MAX(CASE WHEN v.std_attr_code = 'reach' THEN CAST(v.value_std_double AS BOOLEAN) END) AS reach,
    MAX(CASE WHEN v.std_attr_code = 'eccn_code' THEN v.value_std_varchar END) AS eccn_code,
    MAX(CASE WHEN v.std_attr_code = 'aec_q_level' THEN v.value_std_varchar END) AS aec_q_level,
    MAX(CASE WHEN v.std_attr_code = 'lead_free' THEN CAST(v.value_std_double AS BOOLEAN) END) AS lead_free,
    MAX(CASE WHEN v.std_attr_code = 'msl_level' THEN v.value_std_varchar END) AS msl_level,
    MAX(CASE WHEN v.std_attr_code = 'package_case' THEN v.value_std_varchar END) AS package_case,
    MAX(CASE WHEN v.std_attr_code = 'temp_min_c' THEN v.value_std_double END) AS temp_min_c,
    MAX(CASE WHEN v.std_attr_code = 'temp_max_c' THEN v.value_std_double END) AS temp_max_c,
    MAX(CASE WHEN v.std_attr_code = 'pkg_length_mm' THEN v.value_std_double END) AS pkg_length_mm,
    MAX(CASE WHEN v.std_attr_code = 'pkg_width_mm' THEN v.value_std_double END) AS pkg_width_mm,
    MAX(CASE WHEN v.std_attr_code = 'pkg_height_mm' THEN v.value_std_double END) AS pkg_height_mm,

    MAX(CASE WHEN v.std_attr_code = 'resistance_25c_ohm' THEN v.value_std_double END) AS resistance_25c_ohm,
    MAX(CASE WHEN v.std_attr_code = 'resistance_tolerance_pct' THEN v.value_std_double END) AS resistance_tolerance_pct,
    MAX(CASE WHEN v.std_attr_code = 'power_rating_w' THEN v.value_std_double END) AS power_rating_w,
    MAX(CASE WHEN v.std_attr_code = 'voltage_max_v' THEN v.value_std_double END) AS voltage_max_v,

    parse_json(MAX(x.ext_attributes_str)) AS ext_attributes,
    NULL AS semantic_tags,
    NULL AS dq_score,
    NULL AS dq_flags,

    c.data_source                              AS data_source,
    c.id AS source_id,

    COALESCE(MAX(old.create_at), CURRENT_TIMESTAMP()) AS create_at,
    CURRENT_TIMESTAMP() AS update_at
FROM dwd.dwd_component_class c
JOIN src_param p ON p.data_source = c.data_source AND p.id = c.id
LEFT JOIN dim.v_std_brand_alias a ON a.brand_key = UPPER(TRIM(p.brandshort))
LEFT JOIN dwd.dwd_component_attr_std v ON v.id = c.id AND v.data_source = c.data_source AND v.l2_code = c.l2_code
LEFT JOIN ext x ON x.id = c.id AND x.data_source = c.data_source
LEFT JOIN dwd.dwd_l2_resistor_protective_sensitive_resistor old ON old.id = c.id AND old.data_source = c.data_source
WHERE c.l2_code = 'protective_sensitive_resistor'
GROUP BY
    c.id,
    c.data_source,
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
    SUM(CASE WHEN resistance_25c_ohm IS NOT NULL THEN 1 ELSE 0 END) AS has_r,
    SUM(CASE WHEN resistance_tolerance_pct IS NOT NULL THEN 1 ELSE 0 END) AS has_tol,
    SUM(CASE WHEN power_rating_w IS NOT NULL THEN 1 ELSE 0 END) AS has_p,
    SUM(CASE WHEN voltage_max_v IS NOT NULL THEN 1 ELSE 0 END) AS has_v,
    SUM(CASE WHEN package_case IS NOT NULL AND TRIM(package_case) <> '' THEN 1 ELSE 0 END) AS has_pkg,
    SUM(CASE WHEN manufacturer IS NOT NULL AND TRIM(manufacturer) <> '' THEN 1 ELSE 0 END) AS has_mfr,
    SUM(CASE WHEN ext_attributes IS NOT NULL THEN 1 ELSE 0 END) AS has_ext
FROM dwd.dwd_l2_resistor_protective_sensitive_resistor
GROUP BY l3_code
ORDER BY rows_total DESC;
