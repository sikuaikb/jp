/* rf_frequency_synthesis：EAV → L2 宽表（icpdf + digikey · prod）*/
DELETE FROM dwd.dwd_l2_rf_wireless_rf_frequency_synthesis WHERE data_source IN ('icpdf', 'digikey');

INSERT INTO dwd.dwd_l2_rf_wireless_rf_frequency_synthesis
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
    `rf_source_type`,
    `freq_min_mhz`,
    `freq_max_mhz`,
    `supply_voltage_min_v`,
    `supply_voltage_max_v`,
    `output_power_dbm`,
    `supply_current_typ_ma`,
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
                            WHEN e.db_type IN ('DOUBLE', 'INT', 'BOOLEAN')
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
            ON d.l1_code = 'rf_wireless'
           AND d.std_attr_code = e.std_attr_code
           AND d.scope_level = 'l3'
           AND d.scope_code = c.l3_code
    WHERE c.l1_code = 'rf_wireless'
      AND c.l2_code = 'rf_frequency_synthesis'
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
    COALESCE(
        NULLIF(NULLIF(TRIM(COALESCE(
            a.canonical_name,
            am.canonical_name,
            p.brandshort,
            MAX(get_json_string(p.prajson, '$."制造商"'))
        )), ''), '-'),
        ''
    ) AS brand,
    COALESCE(
        a.brand_id_std,
        am.brand_id_std,
        p.brandid,
        CAST(CRC32(TRIM(COALESCE(
            a.canonical_name,
            am.canonical_name,
            p.brandshort,
            MAX(get_json_string(p.prajson, '$."制造商"')), ''
        ))) AS BIGINT)
    ) AS brandid,
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
    CASE c.l3_code
        WHEN 'pll_synthesizer' THEN 'PLL_Synthesizer'
        WHEN 'vco' THEN 'VCO'
        ELSE NULL
    END AS `rf_source_type`,
    MAX(CASE WHEN v.std_attr_code = 'freq_min_mhz' THEN v.value_std_double END) AS `freq_min_mhz`,
    MAX(CASE WHEN v.std_attr_code = 'freq_max_mhz' THEN v.value_std_double END) AS `freq_max_mhz`,
    MAX(CASE WHEN v.std_attr_code = 'supply_voltage_min_v' THEN v.value_std_double END) AS `supply_voltage_min_v`,
    MAX(CASE WHEN v.std_attr_code = 'supply_voltage_max_v' THEN v.value_std_double END) AS `supply_voltage_max_v`,
    MAX(CASE WHEN v.std_attr_code = 'output_power_dbm' THEN v.value_std_double END) AS `output_power_dbm`,
    MAX(CASE WHEN v.std_attr_code = 'supply_current_typ_ma' THEN v.value_std_double END) AS `supply_current_typ_ma`,
    PARSE_JSON(MAX(x.ext_attributes_str)) AS ext_attributes,
    NULL AS semantic_tags,
    NULL AS dq_score,
    NULL AS dq_flags,
    c.id AS source_id,
    CURRENT_TIMESTAMP() AS create_at,
    CURRENT_TIMESTAMP() AS update_at
FROM dwd.dwd_component_class c
JOIN src_param p ON p.id = c.id AND p.data_source = c.data_source
LEFT JOIN dim.v_std_brand_alias a ON a.brand_key = UPPER(TRIM(p.brandshort))
LEFT JOIN dim.v_std_brand_alias am
       ON am.brand_key = UPPER(TRIM(get_json_string(p.prajson, '$."制造商"')))
LEFT JOIN dwd.dwd_component_attr_std v
       ON v.id = c.id AND v.data_source = c.data_source
LEFT JOIN ext x ON x.id = c.id AND x.data_source = c.data_source
WHERE c.l1_code = 'rf_wireless'
      AND c.l2_code = 'rf_frequency_synthesis'
  AND c.data_source IN ('icpdf', 'digikey')
  AND c.l3_code NOT LIKE '%_unclassified'

GROUP BY
    c.data_source, c.id,
    c.l1_code, c.l2_code, c.l3_id, c.l3_code,
    p.partno, p.brandshort, p.brandid,
    a.canonical_name, a.brand_id_std,
    am.canonical_name, am.brand_id_std;
