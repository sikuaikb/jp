/* prod multi-source L2: dwd.dwd_l2_storage_flash_memory */
DELETE FROM dwd.dwd_l2_storage_flash_memory WHERE data_source IN ('digikey', 'icpdf', 'ecloud');

INSERT INTO dwd.dwd_l2_storage_flash_memory
(
    `data_source`,
    `id`,
    `mpn`,
    `brand`,
    `brandid`,
    `l1_code`,
    `l2_code`,
    `l3_code`,
    `flash_type`,
    `capacity_mb`,
    `vcc_min_v`,
    `vcc_max_v`,
    `interface_type`,
    `temp_min_c`,
    `temp_max_c`,
    `rohs_compliant`,
    `reach`,
    `aec_q_level`,
    `lead_free`,
    `msl_level`,
    `lifecycle_status`,
    `eccn_code`,
    `manufacturer`,
    `package_case`,
    `pkg_length_mm`,
    `pkg_width_mm`,
    `pkg_height_mm`,
    `max_clock_freq_mhz`,
    `page_program_time_us`,
    `endurance_cycles`,
    `data_retention_years`,
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
      AND c.l2_code = 'flash_memory'
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
    MAX(CASE WHEN v.std_attr_code = 'flash_type' THEN v.value_std_varchar END) AS `flash_type`,
    MAX(CASE WHEN v.std_attr_code = 'capacity_mb' THEN v.value_std_double END) AS `capacity_mb`,
    MAX(CASE WHEN v.std_attr_code = 'vcc_min_v' THEN v.value_std_double END) AS `vcc_min_v`,
    MAX(CASE WHEN v.std_attr_code = 'vcc_max_v' THEN v.value_std_double END) AS `vcc_max_v`,
    MAX(CASE WHEN v.std_attr_code = 'interface_type' THEN v.value_std_varchar END) AS `interface_type`,
    MAX(CASE WHEN v.std_attr_code = 'temp_min_c' THEN v.value_std_double END) AS `temp_min_c`,
    MAX(CASE WHEN v.std_attr_code = 'temp_max_c' THEN v.value_std_double END) AS `temp_max_c`,
    MAX(CASE WHEN v.std_attr_code = 'rohs_compliant' THEN v.value_std_varchar END) AS `rohs_compliant`,
    MAX(CASE WHEN v.std_attr_code = 'reach' THEN v.value_std_varchar END) AS `reach`,
    MAX(CASE WHEN v.std_attr_code = 'aec_q_level' THEN v.value_std_varchar END) AS `aec_q_level`,
    MAX(CASE WHEN v.std_attr_code = 'lead_free' THEN v.value_std_varchar END) AS `lead_free`,
    MAX(CASE WHEN v.std_attr_code = 'msl_level' THEN v.value_std_varchar END) AS `msl_level`,
    MAX(CASE WHEN v.std_attr_code = 'lifecycle_status' THEN v.value_std_varchar END) AS `lifecycle_status`,
    MAX(CASE WHEN v.std_attr_code = 'eccn_code' THEN v.value_std_varchar END) AS `eccn_code`,
    MAX(CASE WHEN v.std_attr_code = 'manufacturer' THEN v.value_std_varchar END) AS `manufacturer`,
    MAX(CASE WHEN v.std_attr_code = 'package_case' THEN v.value_std_varchar END) AS `package_case`,
    MAX(CASE WHEN v.std_attr_code = 'pkg_length_mm' THEN v.value_std_double END) AS `pkg_length_mm`,
    MAX(CASE WHEN v.std_attr_code = 'pkg_width_mm' THEN v.value_std_double END) AS `pkg_width_mm`,
    MAX(CASE WHEN v.std_attr_code = 'pkg_height_mm' THEN v.value_std_double END) AS `pkg_height_mm`,
    MAX(CASE WHEN v.std_attr_code = 'max_clock_freq_mhz' THEN v.value_std_double END) AS `max_clock_freq_mhz`,
    MAX(CASE WHEN v.std_attr_code = 'page_program_time_us' THEN v.value_std_double END) AS `page_program_time_us`,
    MAX(CASE WHEN v.std_attr_code = 'endurance_cycles' THEN v.value_std_double END) AS `endurance_cycles`,
    MAX(CASE WHEN v.std_attr_code = 'data_retention_years' THEN v.value_std_double END) AS `data_retention_years`,
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
LEFT JOIN dwd.dwd_l2_storage_flash_memory old ON old.id = c.id AND old.data_source = c.data_source
WHERE c.l1_code = 'storage'
  AND c.l2_code = 'flash_memory'
  AND c.data_source IN ('digikey', 'icpdf', 'ecloud')
  AND c.l3_code NOT LIKE '%_unclassified'
GROUP BY
    c.data_source, c.id,
    c.l1_code, c.l2_code, c.l3_id, c.l3_code,
    p.partno, p.brandshort, p.brandid,
    a.canonical_name, a.brand_id_std,
    am.canonical_name, am.brand_id_std;
