/* test/switch build -> test_dwd.dwd_l2_switch_mechanical_actuated_switch
 * EAV: test_dwd.dwd_component_attr_std_switch
 * brand: test_dim.v_std_brand_alias（run_brand_sync.py test）
 * 数据源: icpdf + digikey
 */
DELETE FROM test_dwd.dwd_l2_switch_mechanical_actuated_switch WHERE data_source IN ('icpdf', 'digikey');

INSERT INTO test_dwd.dwd_l2_switch_mechanical_actuated_switch
(
    id,
    mpn,
    brand,
    brandid,
    l1_code,
    l2_code,
    l3_code,
    manufacturer,
    rohs_compliant,
    lifecycle_status,
    reach,
    eccn_code,
    aec_q_level,
    lead_free,
    msl_level,
    package_case,
    temp_min_c,
    temp_max_c,
    rated_voltage_v,
    rated_current_a,
    contact_resistance_mohm,
    circuit_type,
    mounting_type,
    insulation_resistance_mohm,
    electrical_life_cycles,
    ext_attributes,
    semantic_tags,
    dq_score,
    dq_flags,
    data_source,
    source_id,
    create_at,
    update_at
)
WITH src_param AS (
    SELECT 'digikey' AS data_source, id, partno, brandshort, brandid
    FROM dwd.dwd_digikey_component_param
    UNION ALL
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
    FROM test_dwd.dwd_component_attr_std_switch e
    INNER JOIN test_dwd.dwd_component_class_switch c
            ON c.id = e.id AND c.data_source = e.data_source
    INNER JOIN test_dim.dim_attr_schema_switch d
            ON d.schema_version = e.attr_schema_version
           AND d.l1_code = 'switch'
           AND d.std_attr_code = e.std_attr_code
           AND d.scope_level = 'l3'
           AND d.scope_code = c.l3_code
    WHERE c.l2_code = 'mechanical_actuated_switch'
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
    COALESCE(CAST(a.brand_id_std AS VARCHAR), p.brandid) AS brandid,
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
    MAX(CASE WHEN v.std_attr_code = 'rated_voltage_v' THEN v.value_std_double END) AS rated_voltage_v,
    MAX(CASE WHEN v.std_attr_code = 'rated_current_a' THEN v.value_std_double END) AS rated_current_a,
    MAX(CASE WHEN v.std_attr_code = 'contact_resistance_mohm' THEN v.value_std_double END) AS contact_resistance_mohm,
    MAX(CASE WHEN v.std_attr_code = 'circuit_type' THEN v.value_std_varchar END) AS circuit_type,
    MAX(CASE WHEN v.std_attr_code = 'mounting_style' THEN v.value_std_varchar END) AS mounting_type,
    MAX(CASE WHEN v.std_attr_code = 'insulation_resistance_mohm' THEN v.value_std_double END) AS insulation_resistance_mohm,
    MAX(CASE WHEN v.std_attr_code = 'electrical_life_cycles' THEN v.value_std_double END) AS electrical_life_cycles,

    parse_json(MAX(x.ext_attributes_str)) AS ext_attributes,
    NULL AS semantic_tags,
    NULL AS dq_score,
    NULL AS dq_flags,

    c.data_source                              AS data_source,
    c.id AS source_id,

    COALESCE(MAX(old.create_at), CURRENT_TIMESTAMP()) AS create_at,
    CURRENT_TIMESTAMP() AS update_at
FROM test_dwd.dwd_component_class_switch c
JOIN src_param p ON p.data_source = c.data_source AND p.id = c.id
LEFT JOIN test_dim.v_std_brand_alias a ON a.brand_key = UPPER(TRIM(p.brandshort))
LEFT JOIN test_dwd.dwd_component_attr_std_switch v
       ON v.id = c.id AND v.data_source = c.data_source AND v.l2_code = c.l2_code
LEFT JOIN ext x ON x.id = c.id AND x.data_source = c.data_source
LEFT JOIN test_dwd.dwd_l2_switch_mechanical_actuated_switch old ON old.id = c.id AND old.data_source = c.data_source
WHERE c.l2_code = 'mechanical_actuated_switch'
  AND c.l1_code = 'switch'
  AND c.data_source IN ('icpdf', 'digikey')
  AND c.l3_code NOT LIKE '%_unclassified'
GROUP BY
    c.id, c.data_source, p.partno, p.brandshort, p.brandid,
    a.brand_id_std, a.canonical_name,
    c.l1_code, c.l2_code, c.l3_code;
