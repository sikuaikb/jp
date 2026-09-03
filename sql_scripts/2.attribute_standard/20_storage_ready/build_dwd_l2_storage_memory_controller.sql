/* prod multi-source L2: dwd.dwd_l2_storage_memory_controller */
DELETE FROM dwd.dwd_l2_storage_memory_controller WHERE data_source IN ('digikey', 'icpdf', 'ecloud');

INSERT INTO dwd.dwd_l2_storage_memory_controller
(
    `data_source`,
    `id`,
    `mpn`,
    `brand`,
    `brandid`,
    `l1_code`,
    `l2_code`,
    `l3_code`,
    `brandshort`,
    `l3_id`,
    `manufacturer`,
    `rohs_compliant`,
    `lifecycle_status`,
    `reach`,
    `eccn_code`,
    `htsus_code`,
    `aec_q_level`,
    `lead_free`,
    `msl_level`,
    `package_case`,
    `temp_min_c`,
    `temp_max_c`,
    `host_interface_type`,
    `max_data_rate_mbps`,
    `supply_voltage_min_v`,
    `supply_voltage_max_v`,
    `ext_attributes`,
    `semantic_tags`,
    `dq_score`,
    `dq_flags`,
    `source_id`,
    `create_at`,
    `update_at`
)
WITH src_param AS (
    SELECT 'digikey' AS data_source, id, partno, brandshort, brandid, prajson
    FROM dwd.dwd_digikey_component_param
    UNION ALL
    SELECT 'icpdf' AS data_source, id, partno, brandshort, brandid, prajson
    FROM dwd.dwd_icpdf_component_param
    UNION ALL
    SELECT 'ecloud' AS data_source, id, partno, brandshort, brandid, prajson
    FROM dwd.dwd_ecloud_component_param
),
ext AS (
    SELECT
        e.data_source,
        e.id,
        CONCAT(
            '{',
            ARRAY_JOIN(
                ARRAY_AGG(
                    CONCAT(
                        '"', e.std_attr_code, '":',
                        CASE
                            WHEN e.db_type IN ('DOUBLE', 'INT')
                                THEN COALESCE(CAST(e.value_std_double AS VARCHAR), 'null')
                            ELSE CONCAT('"', REPLACE(COALESCE(e.value_std_varchar, ''), '"', '\\"'), '"')
                        END
                    )
                ),
                ','
            ),
            '}'
        ) AS ext_attributes_str
    FROM dwd.dwd_component_attr_std e
    INNER JOIN dwd.dwd_component_class c
            ON c.id = e.id AND c.data_source = e.data_source
    INNER JOIN dim.dim_attr_schema d
            ON d.l1_code = 'storage'
           AND d.std_attr_code = e.std_attr_code
           AND d.scope_level = 'l3'
           AND d.scope_code = c.l3_code
    WHERE c.l1_code = 'storage'
      AND c.l2_code = 'memory_controller'
      AND c.data_source IN ('digikey', 'icpdf', 'ecloud')
      AND (
           e.value_std_double IS NOT NULL
        OR (e.value_std_varchar IS NOT NULL AND TRIM(e.value_std_varchar) <> '')
      )
      AND COALESCE(TRIM(e.value_std_varchar), '') NOT IN ('-', '--', 'N/A', 'n/a', '暂无', 'None')
    GROUP BY e.data_source, e.id
)
SELECT
    c.data_source,
    c.id,
    COALESCE(
        NULLIF(TRIM(MAX(CASE WHEN v.std_attr_code = 'mpn' THEN v.value_std_varchar END)), ''),
        p.partno
    ) AS mpn,
    NULLIF(NULLIF(TRIM(COALESCE(
        a.canonical_name,
        am.canonical_name,
        p.brandshort
    )), ''), '-') AS brand,
    COALESCE(a.brand_id_std, am.brand_id_std, p.brandid) AS brandid,
    c.l1_code,
    c.l2_code,
    c.l3_code,
    NULLIF(TRIM(p.brandshort), '') AS brandshort,
    c.l3_id,
    MAX(CASE WHEN v.std_attr_code = 'manufacturer' THEN v.value_std_varchar END) AS `manufacturer`,
    MAX(CASE WHEN v.std_attr_code = 'rohs_compliant' THEN v.value_std_varchar END) AS `rohs_compliant`,
    MAX(CASE WHEN v.std_attr_code = 'lifecycle_status' THEN v.value_std_varchar END) AS `lifecycle_status`,
    MAX(CASE WHEN v.std_attr_code = 'reach' THEN v.value_std_varchar END) AS `reach`,
    MAX(CASE WHEN v.std_attr_code = 'eccn_code' THEN v.value_std_varchar END) AS `eccn_code`,
    MAX(CASE WHEN v.std_attr_code = 'htsus_code' THEN v.value_std_varchar END) AS `htsus_code`,
    MAX(CASE WHEN v.std_attr_code = 'aec_q_level' THEN v.value_std_varchar END) AS `aec_q_level`,
    MAX(CASE WHEN v.std_attr_code = 'lead_free' THEN v.value_std_varchar END) AS `lead_free`,
    MAX(CASE WHEN v.std_attr_code = 'msl_level' THEN v.value_std_varchar END) AS `msl_level`,
    MAX(CASE WHEN v.std_attr_code = 'package_case' THEN v.value_std_varchar END) AS `package_case`,
    MAX(CASE WHEN v.std_attr_code = 'temp_min_c' THEN v.value_std_double END) AS `temp_min_c`,
    MAX(CASE WHEN v.std_attr_code = 'temp_max_c' THEN v.value_std_double END) AS `temp_max_c`,
    MAX(CASE WHEN v.std_attr_code = 'host_interface_type' THEN v.value_std_varchar END) AS `host_interface_type`,
    MAX(CASE WHEN v.std_attr_code = 'max_data_rate_mbps' THEN v.value_std_double END) AS `max_data_rate_mbps`,
    MAX(CASE WHEN v.std_attr_code = 'supply_voltage_min_v' THEN v.value_std_double END) AS `supply_voltage_min_v`,
    MAX(CASE WHEN v.std_attr_code = 'supply_voltage_max_v' THEN v.value_std_double END) AS `supply_voltage_max_v`,
    PARSE_JSON(COALESCE(MAX(x.ext_attributes_str), '{}')) AS ext_attributes,
    NULL AS semantic_tags,
    NULL AS dq_score,
    NULL AS dq_flags,
    c.id AS source_id,
    COALESCE(MAX(old.create_at), CURRENT_TIMESTAMP()) AS create_at,
    CURRENT_TIMESTAMP() AS update_at
FROM dwd.dwd_component_class c
JOIN src_param p ON p.data_source = c.data_source AND p.id = c.id
LEFT JOIN dim.v_std_brand_alias a ON a.brand_key = UPPER(TRIM(p.brandshort))
LEFT JOIN dim.v_std_brand_alias am
       ON am.brand_key = UPPER(TRIM(get_json_string(p.prajson, '$."制造商"')))
LEFT JOIN dwd.dwd_component_attr_std v
       ON v.id = c.id AND v.data_source = c.data_source
LEFT JOIN ext x ON x.id = c.id AND x.data_source = c.data_source
LEFT JOIN dwd.dwd_l2_storage_memory_controller old ON old.id = c.id AND old.data_source = c.data_source
WHERE c.l1_code = 'storage'
  AND c.l2_code = 'memory_controller'
  AND c.data_source IN ('digikey', 'icpdf', 'ecloud')
  AND c.l3_code NOT LIKE '%_unclassified'
GROUP BY
    c.data_source, c.id,
    c.l1_code, c.l2_code, c.l3_id, c.l3_code,
    p.partno, p.brandshort, p.brandid,
    a.canonical_name, a.brand_id_std,
    am.canonical_name, am.brand_id_std;
