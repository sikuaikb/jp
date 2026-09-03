/* clock_management_ic：EAV → L2 宽表（test_dwd） */
DELETE FROM dwd.dwd_l2_clock_timing_clock_management_ic WHERE data_source = 'digikey';

INSERT INTO dwd.dwd_l2_clock_timing_clock_management_ic
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
    `aec_q_level`,
    `lead_free`,
    `msl_level`,
    `package_case`,
    `temp_min_c`,
    `temp_max_c`,
    `pkg_length_mm`,
    `pkg_width_mm`,
    `pkg_height_mm`,
    `supply_voltage_min_v`,
    `supply_voltage_max_v`,
    `output_freq_max_mhz`,
    `output_channel_count`,
    `ref_clk_freq_min_mhz`,
    `ref_clk_freq_max_mhz`,
    `output_signal_standard`,
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
           AND d.l1_code = 'clock_timing'
           AND d.std_attr_code = e.std_attr_code
           AND d.scope_level = 'l3'
           AND d.scope_code = c.l3_code
    WHERE c.l2_code = 'clock_management_ic'
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
        MAX(CASE WHEN v.std_attr_code = 'manufacturer' THEN v.value_std_varchar END),
        p.brandshort,
        MAX(get_json_string(p.prajson, '$.\"制造商\"'))
    )), '') AS brand,
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
    MAX(CASE WHEN v.std_attr_code = 'aec_q_level' THEN v.value_std_varchar END) AS `aec_q_level`,
    MAX(CASE WHEN v.std_attr_code = 'lead_free' THEN v.value_std_varchar END) AS `lead_free`,
    MAX(CASE WHEN v.std_attr_code = 'msl_level' THEN v.value_std_varchar END) AS `msl_level`,
    MAX(CASE WHEN v.std_attr_code = 'package_case' THEN v.value_std_varchar END) AS `package_case`,
    MAX(CASE WHEN v.std_attr_code = 'temp_min_c' THEN v.value_std_double END) AS `temp_min_c`,
    MAX(CASE WHEN v.std_attr_code = 'temp_max_c' THEN v.value_std_double END) AS `temp_max_c`,
    MAX(CASE WHEN v.std_attr_code = 'pkg_length_mm' THEN v.value_std_double END) AS `pkg_length_mm`,
    MAX(CASE WHEN v.std_attr_code = 'pkg_width_mm' THEN v.value_std_double END) AS `pkg_width_mm`,
    MAX(CASE WHEN v.std_attr_code = 'pkg_height_mm' THEN v.value_std_double END) AS `pkg_height_mm`,
    MAX(CASE WHEN v.std_attr_code = 'supply_voltage_min_v' THEN v.value_std_double END) AS `supply_voltage_min_v`,
    MAX(CASE WHEN v.std_attr_code = 'supply_voltage_max_v' THEN v.value_std_double END) AS `supply_voltage_max_v`,
    MAX(CASE WHEN v.std_attr_code = 'output_freq_max_mhz' THEN v.value_std_double END) AS `output_freq_max_mhz`,
    MAX(CASE WHEN v.std_attr_code = 'output_channel_count' THEN v.value_std_double END) AS `output_channel_count`,
    MAX(CASE WHEN v.std_attr_code = 'ref_clk_freq_min_mhz' THEN v.value_std_double END) AS `ref_clk_freq_min_mhz`,
    MAX(CASE WHEN v.std_attr_code = 'ref_clk_freq_max_mhz' THEN v.value_std_double END) AS `ref_clk_freq_max_mhz`,
    MAX(CASE WHEN v.std_attr_code = 'output_signal_standard' THEN v.value_std_varchar END) AS `output_signal_standard`,
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
       ON am.brand_key = UPPER(TRIM(get_json_string(p.prajson, '$.\"制造商\"')))
LEFT JOIN dwd.dwd_component_attr_std v
       ON v.id = c.id AND v.data_source = c.data_source
LEFT JOIN ext x ON x.id = c.id AND x.data_source = c.data_source
WHERE c.l2_code = 'clock_management_ic'
  AND c.data_source = 'digikey'
  AND c.l3_code NOT LIKE '%_unclassified'
  AND (
       NULLIF(TRIM(p.brandshort), '') IS NOT NULL
    OR NULLIF(TRIM(get_json_string(p.prajson, '$.\"制造商\"')), '') IS NOT NULL
    OR a.canonical_name IS NOT NULL
    OR am.canonical_name IS NOT NULL
  )
GROUP BY
    c.data_source, c.id,
    c.l1_code, c.l2_code, c.l3_id, c.l3_code,
    p.partno, p.brandshort, p.brandid,
    a.canonical_name, a.brand_id_std,
    am.canonical_name, am.brand_id_std;

/* clock_management_ic：EAV → L2 宽表· icpdf 源 */
DELETE FROM dwd.dwd_l2_clock_timing_clock_management_ic WHERE data_source = 'icpdf';

INSERT INTO dwd.dwd_l2_clock_timing_clock_management_ic
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
    `aec_q_level`,
    `lead_free`,
    `msl_level`,
    `package_case`,
    `temp_min_c`,
    `temp_max_c`,
    `pkg_length_mm`,
    `pkg_width_mm`,
    `pkg_height_mm`,
    `supply_voltage_min_v`,
    `supply_voltage_max_v`,
    `output_freq_max_mhz`,
    `output_channel_count`,
    `ref_clk_freq_min_mhz`,
    `ref_clk_freq_max_mhz`,
    `output_signal_standard`,
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
           AND d.l1_code = 'clock_timing'
           AND d.std_attr_code = e.std_attr_code
           AND d.scope_level = 'l3'
           AND d.scope_code = c.l3_code
    WHERE c.l2_code = 'clock_management_ic'
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
        MAX(CASE WHEN v.std_attr_code = 'manufacturer' THEN v.value_std_varchar END),
        p.brandshort,
        MAX(get_json_string(p.prajson, '$.\"制造商\"'))
    )), '') AS brand,
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
    MAX(CASE WHEN v.std_attr_code = 'aec_q_level' THEN v.value_std_varchar END) AS `aec_q_level`,
    MAX(CASE WHEN v.std_attr_code = 'lead_free' THEN v.value_std_varchar END) AS `lead_free`,
    MAX(CASE WHEN v.std_attr_code = 'msl_level' THEN v.value_std_varchar END) AS `msl_level`,
    MAX(CASE WHEN v.std_attr_code = 'package_case' THEN v.value_std_varchar END) AS `package_case`,
    MAX(CASE WHEN v.std_attr_code = 'temp_min_c' THEN v.value_std_double END) AS `temp_min_c`,
    MAX(CASE WHEN v.std_attr_code = 'temp_max_c' THEN v.value_std_double END) AS `temp_max_c`,
    MAX(CASE WHEN v.std_attr_code = 'pkg_length_mm' THEN v.value_std_double END) AS `pkg_length_mm`,
    MAX(CASE WHEN v.std_attr_code = 'pkg_width_mm' THEN v.value_std_double END) AS `pkg_width_mm`,
    MAX(CASE WHEN v.std_attr_code = 'pkg_height_mm' THEN v.value_std_double END) AS `pkg_height_mm`,
    MAX(CASE WHEN v.std_attr_code = 'supply_voltage_min_v' THEN v.value_std_double END) AS `supply_voltage_min_v`,
    MAX(CASE WHEN v.std_attr_code = 'supply_voltage_max_v' THEN v.value_std_double END) AS `supply_voltage_max_v`,
    MAX(CASE WHEN v.std_attr_code = 'output_freq_max_mhz' THEN v.value_std_double END) AS `output_freq_max_mhz`,
    MAX(CASE WHEN v.std_attr_code = 'output_channel_count' THEN v.value_std_double END) AS `output_channel_count`,
    MAX(CASE WHEN v.std_attr_code = 'ref_clk_freq_min_mhz' THEN v.value_std_double END) AS `ref_clk_freq_min_mhz`,
    MAX(CASE WHEN v.std_attr_code = 'ref_clk_freq_max_mhz' THEN v.value_std_double END) AS `ref_clk_freq_max_mhz`,
    MAX(CASE WHEN v.std_attr_code = 'output_signal_standard' THEN v.value_std_varchar END) AS `output_signal_standard`,
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
LEFT JOIN dim.v_std_brand_alias am
       ON am.brand_key = UPPER(TRIM(get_json_string(p.prajson, '$.\"制造商\"')))
LEFT JOIN dwd.dwd_component_attr_std v
       ON v.id = c.id AND v.data_source = c.data_source
LEFT JOIN ext x ON x.id = c.id AND x.data_source = c.data_source
WHERE c.l2_code = 'clock_management_ic'
  AND c.data_source = 'icpdf'
  AND c.l3_code NOT LIKE '%_unclassified'
  AND (
       NULLIF(TRIM(p.brandshort), '') IS NOT NULL
    OR NULLIF(TRIM(get_json_string(p.prajson, '$.\"制造商\"')), '') IS NOT NULL
    OR a.canonical_name IS NOT NULL
    OR am.canonical_name IS NOT NULL
  )
GROUP BY
    c.data_source, c.id,
    c.l1_code, c.l2_code, c.l3_id, c.l3_code,
    p.partno, p.brandshort, p.brandid,
    a.canonical_name, a.brand_id_std,
    am.canonical_name, am.brand_id_std;

/* clock_management_ic：EAV → L2 宽表· ecloud 源 */
DELETE FROM dwd.dwd_l2_clock_timing_clock_management_ic WHERE data_source = 'ecloud';

INSERT INTO dwd.dwd_l2_clock_timing_clock_management_ic
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
    `aec_q_level`,
    `lead_free`,
    `msl_level`,
    `package_case`,
    `temp_min_c`,
    `temp_max_c`,
    `pkg_length_mm`,
    `pkg_width_mm`,
    `pkg_height_mm`,
    `supply_voltage_min_v`,
    `supply_voltage_max_v`,
    `output_freq_max_mhz`,
    `output_channel_count`,
    `ref_clk_freq_min_mhz`,
    `ref_clk_freq_max_mhz`,
    `output_signal_standard`,
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
           AND d.l1_code = 'clock_timing'
           AND d.std_attr_code = e.std_attr_code
           AND d.scope_level = 'l3'
           AND d.scope_code = c.l3_code
    WHERE c.l2_code = 'clock_management_ic'
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
        MAX(CASE WHEN v.std_attr_code = 'manufacturer' THEN v.value_std_varchar END),
        p.brandshort,
        MAX(get_json_string(p.prajson, '$.\"制造商\"'))
    )), '') AS brand,
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
    MAX(CASE WHEN v.std_attr_code = 'aec_q_level' THEN v.value_std_varchar END) AS `aec_q_level`,
    MAX(CASE WHEN v.std_attr_code = 'lead_free' THEN v.value_std_varchar END) AS `lead_free`,
    MAX(CASE WHEN v.std_attr_code = 'msl_level' THEN v.value_std_varchar END) AS `msl_level`,
    MAX(CASE WHEN v.std_attr_code = 'package_case' THEN v.value_std_varchar END) AS `package_case`,
    MAX(CASE WHEN v.std_attr_code = 'temp_min_c' THEN v.value_std_double END) AS `temp_min_c`,
    MAX(CASE WHEN v.std_attr_code = 'temp_max_c' THEN v.value_std_double END) AS `temp_max_c`,
    MAX(CASE WHEN v.std_attr_code = 'pkg_length_mm' THEN v.value_std_double END) AS `pkg_length_mm`,
    MAX(CASE WHEN v.std_attr_code = 'pkg_width_mm' THEN v.value_std_double END) AS `pkg_width_mm`,
    MAX(CASE WHEN v.std_attr_code = 'pkg_height_mm' THEN v.value_std_double END) AS `pkg_height_mm`,
    MAX(CASE WHEN v.std_attr_code = 'supply_voltage_min_v' THEN v.value_std_double END) AS `supply_voltage_min_v`,
    MAX(CASE WHEN v.std_attr_code = 'supply_voltage_max_v' THEN v.value_std_double END) AS `supply_voltage_max_v`,
    MAX(CASE WHEN v.std_attr_code = 'output_freq_max_mhz' THEN v.value_std_double END) AS `output_freq_max_mhz`,
    MAX(CASE WHEN v.std_attr_code = 'output_channel_count' THEN v.value_std_double END) AS `output_channel_count`,
    MAX(CASE WHEN v.std_attr_code = 'ref_clk_freq_min_mhz' THEN v.value_std_double END) AS `ref_clk_freq_min_mhz`,
    MAX(CASE WHEN v.std_attr_code = 'ref_clk_freq_max_mhz' THEN v.value_std_double END) AS `ref_clk_freq_max_mhz`,
    MAX(CASE WHEN v.std_attr_code = 'output_signal_standard' THEN v.value_std_varchar END) AS `output_signal_standard`,
    PARSE_JSON(MAX(x.ext_attributes_str)) AS ext_attributes,
    NULL AS semantic_tags,
    NULL AS dq_score,
    NULL AS dq_flags,
    c.id AS source_id,
    CURRENT_TIMESTAMP() AS create_at,
    CURRENT_TIMESTAMP() AS update_at
FROM dwd.dwd_component_class c
JOIN dwd.dwd_ecloud_component_param p ON p.id = c.id AND c.data_source = 'ecloud'
LEFT JOIN dim.v_std_brand_alias a ON a.brand_key = UPPER(TRIM(p.brandshort))
LEFT JOIN dim.v_std_brand_alias am
       ON am.brand_key = UPPER(TRIM(get_json_string(p.prajson, '$.\"制造商\"')))
LEFT JOIN dwd.dwd_component_attr_std v
       ON v.id = c.id AND v.data_source = c.data_source
LEFT JOIN ext x ON x.id = c.id AND x.data_source = c.data_source
WHERE c.l2_code = 'clock_management_ic'
  AND c.data_source = 'ecloud'
  AND c.l3_code NOT LIKE '%_unclassified'
  AND (
       NULLIF(TRIM(p.brandshort), '') IS NOT NULL
    OR NULLIF(TRIM(get_json_string(p.prajson, '$.\"制造商\"')), '') IS NOT NULL
    OR a.canonical_name IS NOT NULL
    OR am.canonical_name IS NOT NULL
  )
GROUP BY
    c.data_source, c.id,
    c.l1_code, c.l2_code, c.l3_id, c.l3_code,
    p.partno, p.brandshort, p.brandid,
    a.canonical_name, a.brand_id_std,
    am.canonical_name, am.brand_id_std;
