/* test/circuit_protection build -> test_dwd.dwd_l2_circuit_protection_overcurrent_overtemperature_protection
 * EAV: test_dwd.dwd_component_attr_std_circuit_protection
 * 数据源: icpdf (+ digikey 若 classify 存在)
 */
DELETE FROM test_dwd.dwd_l2_circuit_protection_overcurrent_overtemperature_protection WHERE data_source IN ('icpdf', 'digikey');

INSERT INTO test_dwd.dwd_l2_circuit_protection_overcurrent_overtemperature_protection
(
    data_source, id, mpn, brand, brandid,
    l1_code, l2_code, l3_code, brandshort, l3_id,
    manufacturer, lifecycle_status, rohs_compliant, lead_free, msl_level,
    package_case, mounting_type,
    current_rating_a, voltage_rating_v,
    ext_attributes, semantic_tags, dq_score, dq_flags,
    source_id, create_at, update_at
)
WITH mfr_agg AS (
    SELECT data_source, id, MAX(value_std_varchar) AS mfr_name
    FROM test_dwd.dwd_component_attr_std_circuit_protection
    WHERE std_attr_code = 'manufacturer'
    GROUP BY data_source, id
),
ext AS (
    SELECT
        e.data_source,
        e.id,
        CONCAT('{',
            ARRAY_JOIN(ARRAY_AGG(
                CONCAT('"', e.std_attr_code, '":',
                    CASE
                        WHEN e.db_type IN ('DOUBLE', 'INT')
                            THEN COALESCE(CAST(e.value_std_double AS VARCHAR), 'null')
                        ELSE CONCAT('"', REPLACE(COALESCE(e.value_std_varchar, ''), '"', '\\"'), '"')
                    END
                )
            ), ','),
        '}') AS ext_attributes_str
    FROM test_dwd.dwd_component_attr_std_circuit_protection e
    INNER JOIN test_dwd.dwd_component_class_circuit_protection c
            ON c.id = e.id AND c.data_source = e.data_source
    INNER JOIN test_dim.dim_attr_schema_circuit_protection d
            ON d.schema_version = e.attr_schema_version
           AND d.l1_code = 'circuit_protection'
           AND d.std_attr_code = e.std_attr_code
           AND d.scope_level = 'l3'
           AND d.scope_code = c.l3_code
    WHERE c.l2_code = 'overcurrent_overtemperature_protection'
  AND c.l1_code = 'circuit_protection'
  AND c.data_source IN ('icpdf', 'digikey')
  AND c.l3_code NOT LIKE '%_unclassified'
  AND COALESCE(c.l3_code, '') NOT LIKE '%_unclassified'
      AND (e.value_std_double IS NOT NULL
        OR (e.value_std_varchar IS NOT NULL AND TRIM(e.value_std_varchar) <> ''))
      AND COALESCE(TRIM(e.value_std_varchar), '') NOT IN ('-', '--', 'N/A', 'n/a', 'None')
    GROUP BY e.data_source, e.id
)
SELECT
    c.data_source,
    c.id,
    COALESCE(
        NULLIF(TRIM(MAX(CASE WHEN v.std_attr_code = 'mpn' THEN v.value_std_varchar END)), ''),
        p.partno
    ) AS mpn,
    NULLIF(TRIM(COALESCE(
        a_bs.canonical_name,
        a_mfr.canonical_name,
        NULLIF(TRIM(p.brandshort), ''),
        m.mfr_name
    )), '') AS brand,
    COALESCE(a_bs.brand_id_std, a_mfr.brand_id_std, p.brandid) AS brandid,
    c.l1_code, c.l2_code, c.l3_code,
    NULLIF(TRIM(p.brandshort), '')                         AS brandshort,
    c.l3_id,
    MAX(CASE WHEN v.std_attr_code = 'manufacturer'        THEN v.value_std_varchar END) AS manufacturer,
    MAX(CASE WHEN v.std_attr_code = 'lifecycle_status'    THEN v.value_std_varchar END) AS lifecycle_status,
    MAX(CASE WHEN v.std_attr_code = 'rohs_compliant'      THEN v.value_std_varchar END) AS rohs_compliant,
    MAX(CASE WHEN v.std_attr_code = 'lead_free'           THEN v.value_std_varchar END) AS lead_free,
    MAX(CASE WHEN v.std_attr_code = 'msl_level'           THEN v.value_std_varchar END) AS msl_level,
    MAX(CASE WHEN v.std_attr_code = 'package_case'        THEN v.value_std_varchar END) AS package_case,
    MAX(CASE WHEN v.std_attr_code = 'mounting_style'       THEN v.value_std_varchar END) AS mounting_type,
    MAX(CASE WHEN v.std_attr_code = 'current_rating_a'    THEN v.value_std_double  END) AS current_rating_a,
    MAX(CASE WHEN v.std_attr_code = 'voltage_rating_v'    THEN v.value_std_double  END) AS voltage_rating_v,
    PARSE_JSON(MAX(x.ext_attributes_str))                  AS ext_attributes,
    NULL AS semantic_tags, NULL AS dq_score, NULL AS dq_flags,
    c.id AS source_id,
    CURRENT_TIMESTAMP() AS create_at,
    CURRENT_TIMESTAMP() AS update_at
FROM test_dwd.dwd_component_class_circuit_protection c
JOIN (
    SELECT 'icpdf' AS data_source, id, partno, brandshort, brandid FROM dwd.dwd_icpdf_component_param
    UNION ALL
    SELECT 'digikey' AS data_source, id, partno, brandshort, brandid FROM dwd.dwd_digikey_component_param
) p ON p.id = c.id AND p.data_source = c.data_source
LEFT JOIN mfr_agg m
        ON m.id = c.id AND m.data_source = c.data_source
LEFT JOIN test_dim.v_std_brand_alias a_bs
        ON a_bs.brand_key = UPPER(TRIM(p.brandshort))
LEFT JOIN test_dim.v_std_brand_alias a_mfr
        ON a_mfr.brand_key = UPPER(TRIM(m.mfr_name))
LEFT JOIN test_dwd.dwd_component_attr_std_circuit_protection v
        ON v.id = c.id AND v.data_source = c.data_source
LEFT JOIN ext x
        ON x.id = c.id AND x.data_source = c.data_source
WHERE c.l2_code = 'overcurrent_overtemperature_protection'
  AND c.data_source IN ('icpdf', 'digikey')
GROUP BY
    c.data_source, c.id,
    c.l1_code, c.l2_code, c.l3_id, c.l3_code,
    p.partno, p.brandshort, p.brandid,
    a_bs.canonical_name, a_bs.brand_id_std,
    a_mfr.canonical_name, a_mfr.brand_id_std, m.mfr_name;
