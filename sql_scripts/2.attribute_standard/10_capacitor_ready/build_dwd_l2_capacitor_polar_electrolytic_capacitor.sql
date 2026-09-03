/* prod: dwd.dwd_l2_capacitor_polar_electrolytic_capacitor */
DELETE FROM dwd.dwd_l2_capacitor_polar_electrolytic_capacitor WHERE data_source IN ('digikey', 'icpdf', 'ecloud');

/* ============================================================
 * 装配 SQL：dwd_component_attr_std (EAV) → dwd_l2_capacitor_polar_electrolytic_capacitor
 *
 * 透视规则：l2 → 物理列；L3 暂无 entries，ext_attributes=空 JSON。
 * 品牌标准化 + manufacturer EAV-only。
 * ============================================================ */

INSERT INTO dwd.dwd_l2_capacitor_polar_electrolytic_capacitor
(
    id, mpn, brand, brandid,
    l1_code, l2_code, l3_code,
    manufacturer, rohs_compliant, lifecycle_status, reach, eccn_code, aec_q_level, lead_free, msl_level,
    package_case, mounting_style, temp_min_c, temp_max_c,
    capacitance_f, rated_voltage_v, capacitance_tolerance_pct,
    esr_max_mohm, leakage_current_max_ua, ripple_current_ma,
    ext_attributes, semantic_tags,
    dq_score, dq_flags,
    data_source, source_id,
    create_at, update_at
)
WITH src_param AS (
    SELECT 'digikey' AS data_source, id, partno, brandshort, brandid
    FROM dwd.dwd_digikey_component_param
    UNION ALL
    SELECT 'icpdf'   AS data_source, id, partno, brandshort, brandid
    FROM dwd.dwd_icpdf_component_param
    UNION ALL
    SELECT 'ecloud'  AS data_source, id, partno, brandshort, brandid
    FROM dwd.dwd_ecloud_component_param
),
ext AS (
    /* L3 专有属性 → ext_attributes JSON：按 l3_code 路由 schema scope_level='l3' 属性。
     * capacitor db_type 仅 VARCHAR / DOUBLE（BOOLEAN 亦以原文落 VARCHAR）。*/
    SELECT
        e.data_source,
        e.id,
        concat('{', array_join(array_agg(concat(
            '"', e.std_attr_code, '":',
            CASE
                WHEN e.db_type = 'VARCHAR'
                    THEN concat('"', replace(COALESCE(e.value_std_varchar, ''), '"', '\\"'), '"')
                ELSE COALESCE(CAST(e.value_std_double AS VARCHAR), 'null')
            END
        )), ','), '}') AS ext_attributes_str
    FROM dwd.dwd_component_attr_std e
    INNER JOIN dwd.dwd_component_class c2
            ON c2.id = e.id AND c2.data_source = e.data_source
    INNER JOIN dim.dim_attr_schema d
            ON d.schema_version = e.attr_schema_version
           AND d.l1_code = 'capacitor'
           AND d.std_attr_code = e.std_attr_code
           AND d.scope_level = 'l3'
           AND d.scope_code = c2.l3_code
    WHERE c2.l2_code = 'polar_electrolytic_capacitor'
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
    MAX(CASE WHEN v.std_attr_code = 'rohs_compliant' THEN v.value_std_varchar END) AS rohs_compliant,
    MAX(CASE WHEN v.std_attr_code = 'lifecycle_status' THEN v.value_std_varchar END) AS lifecycle_status,
    MAX(CASE WHEN v.std_attr_code = 'reach' THEN v.value_std_varchar END) AS reach,
    MAX(CASE WHEN v.std_attr_code = 'eccn_code' THEN v.value_std_varchar END) AS eccn_code,
    MAX(CASE WHEN v.std_attr_code = 'aec_q_level' THEN v.value_std_varchar END) AS aec_q_level,
    MAX(CASE WHEN v.std_attr_code = 'lead_free' THEN v.value_std_varchar END) AS lead_free,
    MAX(CASE WHEN v.std_attr_code = 'msl_level' THEN v.value_std_varchar END) AS msl_level,
    MAX(CASE WHEN v.std_attr_code = 'package_case' THEN v.value_std_varchar END) AS package_case,
    MAX(CASE WHEN v.std_attr_code = 'mounting_style' THEN v.value_std_varchar END) AS mounting_style,
    MAX(CASE WHEN v.std_attr_code = 'temp_min_c' THEN v.value_std_double END) AS temp_min_c,
    MAX(CASE WHEN v.std_attr_code = 'temp_max_c' THEN v.value_std_double END) AS temp_max_c,
    MAX(CASE WHEN v.std_attr_code = 'capacitance_f' THEN v.value_std_double END) AS capacitance_f,
    MAX(CASE WHEN v.std_attr_code = 'rated_voltage_v' THEN v.value_std_double END) AS rated_voltage_v,
    MAX(CASE WHEN v.std_attr_code = 'capacitance_tolerance_pct' THEN v.value_std_double END) AS capacitance_tolerance_pct,
    MAX(CASE WHEN v.std_attr_code = 'esr_max_mohm' THEN v.value_std_double END) AS esr_max_mohm,
    MAX(CASE WHEN v.std_attr_code = 'leakage_current_max_ua' THEN v.value_std_double END) AS leakage_current_max_ua,
    MAX(CASE WHEN v.std_attr_code = 'ripple_current_ma' THEN v.value_std_double END) AS ripple_current_ma,

    parse_json(COALESCE(MAX(x.ext_attributes_str), '{}')) AS ext_attributes,
    NULL AS semantic_tags,
    NULL AS dq_score,
    NULL AS dq_flags,

    c.data_source                              AS data_source,
    c.id AS source_id,

    COALESCE(MAX(old.create_at), CURRENT_TIMESTAMP()) AS create_at,
    CURRENT_TIMESTAMP() AS update_at
FROM dwd.dwd_component_class c
INNER JOIN src_param p ON p.data_source = c.data_source AND p.id = c.id
LEFT JOIN dim.v_std_brand_alias a ON a.brand_key = UPPER(TRIM(p.brandshort))
LEFT JOIN dwd.dwd_component_attr_std v ON v.id = c.id AND v.data_source = c.data_source AND v.l2_code = c.l2_code
LEFT JOIN ext x ON x.id = c.id AND x.data_source = c.data_source
LEFT JOIN dwd.dwd_l2_capacitor_polar_electrolytic_capacitor old ON old.id = c.id AND old.data_source = c.data_source
WHERE c.data_source IN ('digikey', 'icpdf', 'ecloud')
  AND c.l2_code = 'polar_electrolytic_capacitor'
  AND c.l3_code NOT LIKE '%_unclassified'
GROUP BY
    c.id, c.data_source, p.partno, p.brandshort, p.brandid,
    a.brand_id_std, a.canonical_name,
    c.l1_code, c.l2_code, c.l3_code;
