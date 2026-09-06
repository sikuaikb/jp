/* ============================================================
 * 装配 SQL：dwd_component_attr_std（EAV，多源）→ dwd.dwd_l2_isolator_rf_isolator_circulator
 *
 * 品牌标准化：LEFT JOIN dim.v_std_brand_alias；brand=COALESCE(canonical_name, brandshort)；brandid=a.brand_id_std（不兜底源 id）；manufacturer 保持 EAV-only。
 * ============================================================ */

INSERT INTO dwd.dwd_l2_isolator_rf_isolator_circulator
(id, mpn, brand, brandid, l1_code, l2_code, l3_code,
 lifecycle_status, rohs_compliant, reach, eccn_code, lead_free,
 msl_level, package_case, temp_min_c, temp_max_c,
 device_function_type,
 ext_attributes, semantic_tags, dq_score, dq_flags,
 data_source, source_id, create_at, update_at)
WITH src_param AS (
    SELECT 'icpdf'   AS data_source, id, partno, brandshort, brandid FROM dwd.dwd_icpdf_component_param
    UNION ALL
    SELECT 'digikey' AS data_source, id, partno, brandshort, brandid FROM dwd.dwd_digikey_component_param
),
ext AS (
    SELECT e.data_source, e.id,
           concat('{', array_join(array_agg(concat('"', e.std_attr_code, '":',
               CASE WHEN e.db_type IN ('VARCHAR') THEN concat('"', replace(COALESCE(e.value_std_varchar,''), '"', '\\"'), '"')
                    WHEN e.db_type = 'BOOLEAN' THEN CASE WHEN CAST(e.value_std_double AS INT)=1 THEN 'true' WHEN CAST(e.value_std_double AS INT)=0 THEN 'false' ELSE 'null' END
                    ELSE COALESCE(CAST(e.value_std_double AS VARCHAR), 'null') END)), ','), '}') AS ext_attributes_str
    FROM dwd.dwd_component_attr_std e
    INNER JOIN dwd.dwd_component_class c ON c.id = e.id AND c.data_source = e.data_source
    INNER JOIN dim.dim_attr_schema d
            ON d.schema_version = e.attr_schema_version AND d.l1_code = 'isolator'
           AND d.std_attr_code = e.std_attr_code AND d.scope_level = 'l3' AND d.scope_code = c.l3_code
    WHERE c.l2_code = 'rf_isolator_circulator'
      AND (e.value_std_double IS NOT NULL OR (e.value_std_varchar IS NOT NULL AND trim(e.value_std_varchar) <> ''))
    GROUP BY e.data_source, e.id
)
SELECT
    c.id,
    COALESCE(NULLIF(TRIM(MAX(CASE WHEN v.std_attr_code = 'mpn' THEN v.value_std_varchar END)), ''), p.partno) AS mpn,
    COALESCE(a.canonical_name, p.brandshort) AS brand,
    a.brand_id_std AS brandid,
    c.l1_code, c.l2_code, c.l3_code,
    MAX(CASE WHEN v.std_attr_code = 'lifecycle_status'      THEN v.value_std_varchar END) AS lifecycle_status,
    MAX(CASE WHEN v.std_attr_code = 'rohs_compliant'        THEN v.value_std_double  END) AS rohs_compliant,
    MAX(CASE WHEN v.std_attr_code = 'reach'                 THEN v.value_std_double  END) AS reach,
    MAX(CASE WHEN v.std_attr_code = 'eccn_code'             THEN v.value_std_varchar END) AS eccn_code,
    MAX(CASE WHEN v.std_attr_code = 'lead_free'             THEN v.value_std_double  END) AS lead_free,
    MAX(CASE WHEN v.std_attr_code = 'msl_level'             THEN v.value_std_varchar END) AS msl_level,
    MAX(CASE WHEN v.std_attr_code = 'package_case'          THEN v.value_std_varchar END) AS package_case,
    MAX(CASE WHEN v.std_attr_code = 'temp_min_c'            THEN v.value_std_double  END) AS temp_min_c,
    MAX(CASE WHEN v.std_attr_code = 'temp_max_c'            THEN v.value_std_double  END) AS temp_max_c,
    MAX(CASE WHEN v.std_attr_code = 'device_function_type'  THEN v.value_std_varchar END) AS device_function_type,
    parse_json(MAX(x.ext_attributes_str)) AS ext_attributes,
    NULL AS semantic_tags, NULL AS dq_score, NULL AS dq_flags,
    c.data_source,
    c.id AS source_id,
    COALESCE(MAX(old.create_at), CURRENT_TIMESTAMP()) AS create_at,
    CURRENT_TIMESTAMP() AS update_at
FROM dwd.dwd_component_class c
JOIN src_param p ON p.data_source = c.data_source AND p.id = c.id
LEFT JOIN dim.v_std_brand_alias a ON a.brand_key = UPPER(TRIM(p.brandshort))
LEFT JOIN dwd.dwd_component_attr_std v
       ON v.id = c.id AND v.data_source = c.data_source AND v.l2_code = c.l2_code
LEFT JOIN ext x ON x.id = c.id AND x.data_source = c.data_source
LEFT JOIN dwd.dwd_l2_isolator_rf_isolator_circulator old ON old.id = c.id AND old.data_source = c.data_source
WHERE c.l2_code = 'rf_isolator_circulator'
GROUP BY c.id, c.data_source, p.partno, p.brandshort, a.brand_id_std, a.canonical_name,
         c.l1_code, c.l2_code, c.l3_code;
