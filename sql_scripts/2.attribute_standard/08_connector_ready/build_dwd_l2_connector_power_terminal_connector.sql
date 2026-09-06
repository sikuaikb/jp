/* power_terminal_connector：EAV → L2 宽表 */
/* power_terminal_connector / digikey：EAV → L2 宽表 */
DELETE FROM dwd.dwd_l2_connector_power_terminal_connector WHERE data_source = 'digikey';

INSERT INTO dwd.dwd_l2_connector_power_terminal_connector
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
    `temp_max_c`,
    `connector_type`,
    `rated_voltage_v`,
    `rated_current_a`,
    `connector_series`,
    `base_product_number`,
    `row_count`,
    `num_positions`,
    `pitch_mm`,
    `wire_gauge_min_awg`,
    `wire_gauge_max_awg`,
    `termination_type`,
    `mounting_style`,
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
    WHERE c.l2_code = 'power_terminal_connector'
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
    MAX(CASE WHEN v.std_attr_code = 'temp_max_c' THEN v.value_std_double END) AS `temp_max_c`,
    CASE c.l3_code
        WHEN 'power_connector' THEN 'Power_Connector'
        WHEN 'power_entry_module' THEN 'Power_Entry_Module'
        WHEN 'dc_barrel_power_jack' THEN 'DC_Barrel_Power_Jack'
        WHEN 'pluggable_terminal_block' THEN 'Pluggable_Terminal_Block'
        WHEN 'screw_terminal_block' THEN 'Screw_Terminal_Block'
        WHEN 'barrier_terminal_block' THEN 'Barrier_Terminal_Block'
        WHEN 'spring_terminal_block' THEN 'Spring_Terminal_Block'
        ELSE NULL END AS `connector_type`,
    MAX(CASE WHEN v.std_attr_code = 'rated_voltage_v' THEN v.value_std_double END) AS `rated_voltage_v`,
    MAX(CASE WHEN v.std_attr_code = 'rated_current_a' THEN v.value_std_double END) AS `rated_current_a`,
    MAX(CASE WHEN v.std_attr_code = 'connector_series' THEN v.value_std_varchar END) AS `connector_series`,
    MAX(CASE WHEN v.std_attr_code = 'base_product_number' THEN v.value_std_varchar END) AS `base_product_number`,
    MAX(CASE WHEN v.std_attr_code = 'row_count' THEN v.value_std_double END) AS `row_count`,
    MAX(CASE WHEN v.std_attr_code = 'num_positions' THEN v.value_std_double END) AS `num_positions`,
    MAX(CASE WHEN v.std_attr_code = 'pitch_mm' THEN v.value_std_double END) AS `pitch_mm`,
    MAX(CASE WHEN v.std_attr_code = 'wire_gauge_min_awg' THEN v.value_std_double END) AS `wire_gauge_min_awg`,
    MAX(CASE WHEN v.std_attr_code = 'wire_gauge_max_awg' THEN v.value_std_double END) AS `wire_gauge_max_awg`,
    MAX(CASE WHEN v.std_attr_code = 'termination_type' THEN v.value_std_varchar END) AS `termination_type`,
    MAX(CASE WHEN v.std_attr_code = 'mounting_style' THEN v.value_std_varchar END) AS `mounting_style`,
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
WHERE c.l2_code = 'power_terminal_connector'
  AND c.data_source = 'digikey'
  AND c.l3_code NOT LIKE '%_unclassified'
GROUP BY
    c.data_source, c.id,
    c.l1_code, c.l2_code, c.l3_code,
    p.partno, p.brandshort, p.brandid,
    a.canonical_name, a.brand_id_std,
    am.canonical_name, am.brand_id_std;

/* power_terminal_connector / icpdf：EAV → L2 宽表 */
DELETE FROM dwd.dwd_l2_connector_power_terminal_connector WHERE data_source = 'icpdf';

INSERT INTO dwd.dwd_l2_connector_power_terminal_connector
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
    `temp_max_c`,
    `connector_type`,
    `rated_voltage_v`,
    `rated_current_a`,
    `connector_series`,
    `base_product_number`,
    `row_count`,
    `num_positions`,
    `pitch_mm`,
    `wire_gauge_min_awg`,
    `wire_gauge_max_awg`,
    `termination_type`,
    `mounting_style`,
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
    WHERE c.l2_code = 'power_terminal_connector'
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
    MAX(CASE WHEN v.std_attr_code = 'temp_max_c' THEN v.value_std_double END) AS `temp_max_c`,
    CASE c.l3_code
        WHEN 'power_connector' THEN 'Power_Connector'
        WHEN 'power_entry_module' THEN 'Power_Entry_Module'
        WHEN 'dc_barrel_power_jack' THEN 'DC_Barrel_Power_Jack'
        WHEN 'pluggable_terminal_block' THEN 'Pluggable_Terminal_Block'
        WHEN 'screw_terminal_block' THEN 'Screw_Terminal_Block'
        WHEN 'barrier_terminal_block' THEN 'Barrier_Terminal_Block'
        WHEN 'spring_terminal_block' THEN 'Spring_Terminal_Block'
        ELSE NULL END AS `connector_type`,
    MAX(CASE WHEN v.std_attr_code = 'rated_voltage_v' THEN v.value_std_double END) AS `rated_voltage_v`,
    MAX(CASE WHEN v.std_attr_code = 'rated_current_a' THEN v.value_std_double END) AS `rated_current_a`,
    MAX(CASE WHEN v.std_attr_code = 'connector_series' THEN v.value_std_varchar END) AS `connector_series`,
    MAX(CASE WHEN v.std_attr_code = 'base_product_number' THEN v.value_std_varchar END) AS `base_product_number`,
    MAX(CASE WHEN v.std_attr_code = 'row_count' THEN v.value_std_double END) AS `row_count`,
    MAX(CASE WHEN v.std_attr_code = 'num_positions' THEN v.value_std_double END) AS `num_positions`,
    MAX(CASE WHEN v.std_attr_code = 'pitch_mm' THEN v.value_std_double END) AS `pitch_mm`,
    MAX(CASE WHEN v.std_attr_code = 'wire_gauge_min_awg' THEN v.value_std_double END) AS `wire_gauge_min_awg`,
    MAX(CASE WHEN v.std_attr_code = 'wire_gauge_max_awg' THEN v.value_std_double END) AS `wire_gauge_max_awg`,
    MAX(CASE WHEN v.std_attr_code = 'termination_type' THEN v.value_std_varchar END) AS `termination_type`,
    MAX(CASE WHEN v.std_attr_code = 'mounting_style' THEN v.value_std_varchar END) AS `mounting_style`,
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
WHERE c.l2_code = 'power_terminal_connector'
  AND c.data_source = 'icpdf'
  AND c.l3_code NOT LIKE '%_unclassified'
GROUP BY
    c.data_source, c.id,
    c.l1_code, c.l2_code, c.l3_code,
    p.partno, p.brandshort, p.brandid,
    a.canonical_name, a.brand_id_std;
