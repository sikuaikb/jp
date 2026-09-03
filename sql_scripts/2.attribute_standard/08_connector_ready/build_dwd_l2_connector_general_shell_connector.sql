/* general_shell_connector：EAV → L2 宽表 */
/* general_shell_connector / digikey：EAV → L2 宽表 */
DELETE FROM dwd.dwd_l2_connector_general_shell_connector WHERE data_source = 'digikey';

INSERT INTO dwd.dwd_l2_connector_general_shell_connector
(
    `data_source`,
    `id`,
    `mpn`,
    `brand`,
    `brandid`,
    `l1_code`,
    `l2_code`,
    `l3_code`,
    `manufacturer`,
    `rohs_compliant`,
    `lifecycle_status`,
    `reach`,
    `eccn_code`,
    `htsus_code`,
    `packaging_options_raw`,
    `lead_free`,
    `msl_level`,
    `temp_min_c`,
    `connector_series`,
    `base_product_number`,
    `flammability_rating`,
    `has_shielding`,
    `contact_plating`,
    `temp_max_c`,
    `body_color`,
    `contact_count`,
    `connector_gender`,
    `orientation`,
    `termination_type`,
    `mounting_style`,
    `current_rating_max_a`,
    `voltage_rating_max_v`,
    `ext_attributes`,
    `semantic_tags`,
    `dq_score`,
    `dq_flags`,
    `source_id`,
    `create_at`,
    `update_at`
)
WITH ext AS (
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
            ON d.schema_version = e.attr_schema_version
           AND d.l1_code = 'connector'
           AND d.std_attr_code = e.std_attr_code
           AND d.scope_level = 'l3'
           AND d.scope_code = c.l3_code
    WHERE c.l2_code = 'general_shell_connector'
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
    NULLIF(TRIM(COALESCE(
        a.canonical_name,
        am.canonical_name,
        p.brandshort,
        MAX(get_json_string(p.prajson, '$."制造商"'))
    )), '') AS brand,
    COALESCE(a.brand_id_std, am.brand_id_std, p.brandid) AS brandid,
    c.l1_code,
    c.l2_code,
    c.l3_code,
    MAX(CASE WHEN v.std_attr_code = 'manufacturer' THEN v.value_std_varchar END) AS `manufacturer`,
    MAX(CASE WHEN v.std_attr_code = 'rohs_compliant' THEN v.value_std_varchar END) AS `rohs_compliant`,
    MAX(CASE WHEN v.std_attr_code = 'lifecycle_status' THEN v.value_std_varchar END) AS `lifecycle_status`,
    MAX(CASE WHEN v.std_attr_code = 'reach' THEN v.value_std_varchar END) AS `reach`,
    MAX(CASE WHEN v.std_attr_code = 'eccn_code' THEN v.value_std_varchar END) AS `eccn_code`,
    MAX(CASE WHEN v.std_attr_code = 'htsus_code' THEN v.value_std_varchar END) AS `htsus_code`,
    MAX(CASE WHEN v.std_attr_code = 'packaging_options_raw' THEN v.value_std_varchar END) AS `packaging_options_raw`,
    MAX(CASE WHEN v.std_attr_code = 'lead_free' THEN v.value_std_varchar END) AS `lead_free`,
    MAX(CASE WHEN v.std_attr_code = 'msl_level' THEN v.value_std_varchar END) AS `msl_level`,
    MAX(CASE WHEN v.std_attr_code = 'temp_min_c' THEN v.value_std_double END) AS `temp_min_c`,
    MAX(CASE WHEN v.std_attr_code = 'connector_series' THEN v.value_std_varchar END) AS `connector_series`,
    MAX(CASE WHEN v.std_attr_code = 'base_product_number' THEN v.value_std_varchar END) AS `base_product_number`,
    MAX(CASE WHEN v.std_attr_code = 'flammability_rating' THEN v.value_std_varchar END) AS `flammability_rating`,
    MAX(CASE WHEN v.std_attr_code = 'has_shielding' THEN v.value_std_varchar END) AS `has_shielding`,
    MAX(CASE WHEN v.std_attr_code = 'contact_plating' THEN v.value_std_varchar END) AS `contact_plating`,
    MAX(CASE WHEN v.std_attr_code = 'temp_max_c' THEN v.value_std_double END) AS `temp_max_c`,
    MAX(CASE WHEN v.std_attr_code = 'body_color' THEN v.value_std_varchar END) AS `body_color`,
    MAX(CASE WHEN v.std_attr_code = 'contact_count' THEN v.value_std_double END) AS `contact_count`,
    MAX(CASE WHEN v.std_attr_code = 'connector_gender' THEN v.value_std_varchar END) AS `connector_gender`,
    MAX(CASE WHEN v.std_attr_code = 'orientation' THEN v.value_std_varchar END) AS `orientation`,
    MAX(CASE WHEN v.std_attr_code = 'termination_type' THEN v.value_std_varchar END) AS `termination_type`,
    MAX(CASE WHEN v.std_attr_code = 'mounting_style' THEN v.value_std_varchar END) AS `mounting_style`,
    MAX(CASE WHEN v.std_attr_code = 'current_rating_max_a' THEN v.value_std_double END) AS `current_rating_max_a`,
    MAX(CASE WHEN v.std_attr_code = 'voltage_rating_max_v' THEN v.value_std_double END) AS `voltage_rating_max_v`,
    PARSE_JSON(MAX(x.ext_attributes_str)) AS ext_attributes,
    NULL AS semantic_tags,
    NULL AS dq_score,
    NULL AS dq_flags,
    c.id AS source_id,
    CURRENT_TIMESTAMP() AS create_at,
    CURRENT_TIMESTAMP() AS update_at
FROM dwd.dwd_component_class c
JOIN dwd.dwd_digikey_component_param p ON p.id = c.id AND c.data_source = 'digikey'
LEFT JOIN dim.v_std_brand_alias a ON a.brand_key = UPPER(TRIM(p.brandshort))
LEFT JOIN dim.v_std_brand_alias am
       ON am.brand_key = UPPER(TRIM(get_json_string(p.prajson, '$."制造商"')))
LEFT JOIN dwd.dwd_component_attr_std v
       ON v.id = c.id AND v.data_source = c.data_source
LEFT JOIN ext x ON x.id = c.id AND x.data_source = c.data_source
WHERE c.l2_code = 'general_shell_connector'
  AND c.data_source = 'digikey'
  AND c.l3_code NOT LIKE '%_unclassified'
GROUP BY
    c.data_source, c.id,
    c.l1_code, c.l2_code, c.l3_code,
    p.partno, p.brandshort, p.brandid,
    a.canonical_name, a.brand_id_std,
    am.canonical_name, am.brand_id_std;

/* general_shell_connector / icpdf：EAV → L2 宽表 */
DELETE FROM dwd.dwd_l2_connector_general_shell_connector WHERE data_source = 'icpdf';

INSERT INTO dwd.dwd_l2_connector_general_shell_connector
(
    `data_source`,
    `id`,
    `mpn`,
    `brand`,
    `brandid`,
    `l1_code`,
    `l2_code`,
    `l3_code`,
    `manufacturer`,
    `rohs_compliant`,
    `lifecycle_status`,
    `reach`,
    `eccn_code`,
    `htsus_code`,
    `packaging_options_raw`,
    `lead_free`,
    `msl_level`,
    `temp_min_c`,
    `connector_series`,
    `base_product_number`,
    `flammability_rating`,
    `has_shielding`,
    `contact_plating`,
    `temp_max_c`,
    `body_color`,
    `contact_count`,
    `connector_gender`,
    `orientation`,
    `termination_type`,
    `mounting_style`,
    `current_rating_max_a`,
    `voltage_rating_max_v`,
    `ext_attributes`,
    `semantic_tags`,
    `dq_score`,
    `dq_flags`,
    `source_id`,
    `create_at`,
    `update_at`
)
WITH ext AS (
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
            ON d.schema_version = e.attr_schema_version
           AND d.l1_code = 'connector'
           AND d.std_attr_code = e.std_attr_code
           AND d.scope_level = 'l3'
           AND d.scope_code = c.l3_code
    WHERE c.l2_code = 'general_shell_connector'
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
    NULLIF(TRIM(COALESCE(a.canonical_name, p.brandshort)), '') AS brand,
    COALESCE(a.brand_id_std, p.brandid) AS brandid,
    c.l1_code,
    c.l2_code,
    c.l3_code,
    MAX(CASE WHEN v.std_attr_code = 'manufacturer' THEN v.value_std_varchar END) AS `manufacturer`,
    MAX(CASE WHEN v.std_attr_code = 'rohs_compliant' THEN v.value_std_varchar END) AS `rohs_compliant`,
    MAX(CASE WHEN v.std_attr_code = 'lifecycle_status' THEN v.value_std_varchar END) AS `lifecycle_status`,
    MAX(CASE WHEN v.std_attr_code = 'reach' THEN v.value_std_varchar END) AS `reach`,
    MAX(CASE WHEN v.std_attr_code = 'eccn_code' THEN v.value_std_varchar END) AS `eccn_code`,
    MAX(CASE WHEN v.std_attr_code = 'htsus_code' THEN v.value_std_varchar END) AS `htsus_code`,
    MAX(CASE WHEN v.std_attr_code = 'packaging_options_raw' THEN v.value_std_varchar END) AS `packaging_options_raw`,
    MAX(CASE WHEN v.std_attr_code = 'lead_free' THEN v.value_std_varchar END) AS `lead_free`,
    MAX(CASE WHEN v.std_attr_code = 'msl_level' THEN v.value_std_varchar END) AS `msl_level`,
    MAX(CASE WHEN v.std_attr_code = 'temp_min_c' THEN v.value_std_double END) AS `temp_min_c`,
    MAX(CASE WHEN v.std_attr_code = 'connector_series' THEN v.value_std_varchar END) AS `connector_series`,
    MAX(CASE WHEN v.std_attr_code = 'base_product_number' THEN v.value_std_varchar END) AS `base_product_number`,
    MAX(CASE WHEN v.std_attr_code = 'flammability_rating' THEN v.value_std_varchar END) AS `flammability_rating`,
    MAX(CASE WHEN v.std_attr_code = 'has_shielding' THEN v.value_std_varchar END) AS `has_shielding`,
    MAX(CASE WHEN v.std_attr_code = 'contact_plating' THEN v.value_std_varchar END) AS `contact_plating`,
    MAX(CASE WHEN v.std_attr_code = 'temp_max_c' THEN v.value_std_double END) AS `temp_max_c`,
    MAX(CASE WHEN v.std_attr_code = 'body_color' THEN v.value_std_varchar END) AS `body_color`,
    MAX(CASE WHEN v.std_attr_code = 'contact_count' THEN v.value_std_double END) AS `contact_count`,
    MAX(CASE WHEN v.std_attr_code = 'connector_gender' THEN v.value_std_varchar END) AS `connector_gender`,
    MAX(CASE WHEN v.std_attr_code = 'orientation' THEN v.value_std_varchar END) AS `orientation`,
    MAX(CASE WHEN v.std_attr_code = 'termination_type' THEN v.value_std_varchar END) AS `termination_type`,
    MAX(CASE WHEN v.std_attr_code = 'mounting_style' THEN v.value_std_varchar END) AS `mounting_style`,
    MAX(CASE WHEN v.std_attr_code = 'current_rating_max_a' THEN v.value_std_double END) AS `current_rating_max_a`,
    MAX(CASE WHEN v.std_attr_code = 'voltage_rating_max_v' THEN v.value_std_double END) AS `voltage_rating_max_v`,
    PARSE_JSON(MAX(x.ext_attributes_str)) AS ext_attributes,
    NULL AS semantic_tags,
    NULL AS dq_score,
    NULL AS dq_flags,
    c.id AS source_id,
    CURRENT_TIMESTAMP() AS create_at,
    CURRENT_TIMESTAMP() AS update_at
FROM dwd.dwd_component_class c
JOIN dwd.dwd_icpdf_component_param p ON p.id = c.id AND c.data_source = 'icpdf'
LEFT JOIN dim.v_std_brand_alias a ON a.brand_key = UPPER(TRIM(p.brandshort))
LEFT JOIN dwd.dwd_component_attr_std v
       ON v.id = c.id AND v.data_source = c.data_source
LEFT JOIN ext x ON x.id = c.id AND x.data_source = c.data_source
WHERE c.l2_code = 'general_shell_connector'
  AND c.data_source = 'icpdf'
  AND c.l3_code NOT LIKE '%_unclassified'
GROUP BY
    c.data_source, c.id,
    c.l1_code, c.l2_code, c.l3_code,
    p.partno, p.brandshort, p.brandid,
    a.canonical_name, a.brand_id_std;
