/* rfid_nfc_frontend：EAV → L2 宽表（icpdf + digikey · prod）*/
DELETE FROM dwd.dwd_l2_rf_wireless_rfid_nfc_frontend WHERE data_source IN ('icpdf', 'digikey');

INSERT INTO dwd.dwd_l2_rf_wireless_rfid_nfc_frontend
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
    `carrier_freq_mhz`,
    `supported_rf_standards`,
    `host_interface_type`,
    `supply_voltage_min_v`,
    `supply_voltage_max_v`,
    `reach`,
    `temp_min_c`,
    `eccn_code`,
    `temp_max_c`,
    `aec_q_level`,
    `lifecycle_status`,
    `lead_free`,
    `rohs_compliant`,
    `msl_level`,
    `package_case`,
    `freq_min_mhz`,
    `freq_max_mhz`,
    `mounting_style`,
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
      AND c.l2_code = 'rfid_nfc_frontend'
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
    MAX(CASE WHEN v.std_attr_code = 'carrier_freq_mhz' THEN v.value_std_double END) AS `carrier_freq_mhz`,
    MAX(CASE WHEN v.std_attr_code = 'supported_rf_standards' THEN v.value_std_varchar END) AS `supported_rf_standards`,
    MAX(CASE WHEN v.std_attr_code = 'host_interface_type' THEN v.value_std_varchar END) AS `host_interface_type`,
    MAX(CASE WHEN v.std_attr_code = 'supply_voltage_min_v' THEN v.value_std_double END) AS `supply_voltage_min_v`,
    MAX(CASE WHEN v.std_attr_code = 'supply_voltage_max_v' THEN v.value_std_double END) AS `supply_voltage_max_v`,
    MAX(CASE WHEN v.std_attr_code = 'reach' THEN v.value_std_varchar END) AS `reach`,
    MAX(CASE WHEN v.std_attr_code = 'temp_min_c' THEN v.value_std_double END) AS `temp_min_c`,
    MAX(CASE WHEN v.std_attr_code = 'eccn_code' THEN v.value_std_varchar END) AS `eccn_code`,
    MAX(CASE WHEN v.std_attr_code = 'temp_max_c' THEN v.value_std_double END) AS `temp_max_c`,
    MAX(CASE WHEN v.std_attr_code = 'aec_q_level' THEN v.value_std_varchar END) AS `aec_q_level`,
    MAX(CASE WHEN v.std_attr_code = 'lifecycle_status' THEN v.value_std_varchar END) AS `lifecycle_status`,
    MAX(CASE WHEN v.std_attr_code = 'lead_free' THEN v.value_std_varchar END) AS `lead_free`,
    MAX(CASE WHEN v.std_attr_code = 'rohs_compliant' THEN v.value_std_varchar END) AS `rohs_compliant`,
    MAX(CASE WHEN v.std_attr_code = 'msl_level' THEN v.value_std_varchar END) AS `msl_level`,
    MAX(CASE WHEN v.std_attr_code = 'package_case' THEN v.value_std_varchar END) AS `package_case`,
    MAX(CASE WHEN v.std_attr_code = 'freq_min_mhz' THEN v.value_std_double END) AS `freq_min_mhz`,
    MAX(CASE WHEN v.std_attr_code = 'freq_max_mhz' THEN v.value_std_double END) AS `freq_max_mhz`,
    MAX(CASE WHEN v.std_attr_code = 'mounting_style' THEN v.value_std_varchar END) AS `mounting_style`,
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
      AND c.l2_code = 'rfid_nfc_frontend'
  AND c.data_source IN ('icpdf', 'digikey')
  AND c.l3_code NOT LIKE '%_unclassified'

GROUP BY
    c.data_source, c.id,
    c.l1_code, c.l2_code, c.l3_id, c.l3_code,
    p.partno, p.brandshort, p.brandid,
    a.canonical_name, a.brand_id_std,
    am.canonical_name, am.brand_id_std;
