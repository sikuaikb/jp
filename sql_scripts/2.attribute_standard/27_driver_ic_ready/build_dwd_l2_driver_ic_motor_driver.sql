/* prod icpdf|digikey 多源 → dwd.dwd_l2_driver_ic_motor_driver */
/* Build dwd_l2_driver_ic_motor_driver from EAV */
DELETE FROM dwd.dwd_l2_driver_ic_motor_driver WHERE data_source IN ('digikey', 'icpdf');

INSERT INTO dwd.dwd_l2_driver_ic_motor_driver
(`id`, `mpn`, `brand`, `brandid`, `l1_code`, `l2_code`, `l3_code`, `manufacturer`, `lifecycle_status`, `eccn_code`, `rohs_compliant`, `reach`, `aec_q_level`, `lead_free`, `msl_level`, `package_case`, `pkg_length_mm`, `pkg_width_mm`, `pkg_height_mm`, `temp_min_c`, `temp_max_c`, `supply_voltage_min_v`, `supply_voltage_max_v`, `output_current_continuous_a`, `peak_output_current_a`, `number_of_half_bridges`, `control_interface_type`, `mounting_style`, `ext_attributes`, `semantic_tags`, `dq_score`, `dq_flags`, `data_source`, `source_id`, `create_at`, `update_at`)
WITH src_param AS (
    SELECT 'icpdf'   AS data_source, id, partno, brandshort, brandid
    FROM dwd.dwd_icpdf_component_param
    UNION ALL
    SELECT 'digikey' AS data_source, id, partno, brandshort, brandid
    FROM dwd.dwd_digikey_component_param
),
ext AS (
    SELECT e.data_source, e.id,
           concat('{', array_join(array_agg(concat(
               '"', e.std_attr_code, '":',
               CASE WHEN e.db_type IN ('DOUBLE','INT')
                    THEN COALESCE(CAST(e.value_std_double AS VARCHAR), 'null')
                    ELSE concat('"', replace(COALESCE(e.value_std_varchar, ''), '"', '\\"'), '"')
               END
           )), ','), '}') AS ext_attributes_str
    FROM dwd.dwd_component_attr_std e
    INNER JOIN dwd.dwd_component_class c2 ON c2.id = e.id AND c2.data_source = e.data_source
    INNER JOIN dim.dim_attr_schema d
            ON d.schema_version = e.attr_schema_version AND d.l1_code = 'driver_ic'
           AND d.std_attr_code = e.std_attr_code AND d.scope_level = 'l3' AND d.scope_code = c2.l3_code
    WHERE c2.l2_code = 'motor_driver'
      AND (e.value_std_double IS NOT NULL OR (e.value_std_varchar IS NOT NULL AND trim(e.value_std_varchar) <> ''))
    GROUP BY e.data_source, e.id
)
SELECT
    c.id,
    COALESCE(NULLIF(TRIM(MAX(CASE WHEN v.std_attr_code = 'mpn' THEN v.value_std_varchar END)), ''), p.partno) AS mpn,
    COALESCE(a.canonical_name, p.brandshort) AS brand,
    COALESCE(a.brand_id_std, p.brandid) AS brandid,
    c.l1_code, c.l2_code, c.l3_code,
    MAX(CASE WHEN v.std_attr_code = 'manufacturer' THEN v.value_std_varchar END) AS manufacturer,
    MAX(CASE WHEN v.std_attr_code = 'lifecycle_status' THEN v.value_std_varchar END) AS lifecycle_status,
    MAX(CASE WHEN v.std_attr_code = 'eccn_code' THEN v.value_std_varchar END) AS eccn_code,
    MAX(CASE WHEN v.std_attr_code = 'rohs_compliant' THEN v.value_std_varchar END) AS rohs_compliant,
    MAX(CASE WHEN v.std_attr_code = 'reach' THEN v.value_std_varchar END) AS reach,
    MAX(CASE WHEN v.std_attr_code = 'aec_q_level' THEN v.value_std_varchar END) AS aec_q_level,
    MAX(CASE WHEN v.std_attr_code = 'lead_free' THEN v.value_std_varchar END) AS lead_free,
    MAX(CASE WHEN v.std_attr_code = 'msl_level' THEN v.value_std_varchar END) AS msl_level,
    MAX(CASE WHEN v.std_attr_code = 'package_case' THEN v.value_std_varchar END) AS package_case,
    MAX(CASE WHEN v.std_attr_code = 'pkg_length_mm' THEN v.value_std_double END) AS pkg_length_mm,
    MAX(CASE WHEN v.std_attr_code = 'pkg_width_mm' THEN v.value_std_double END) AS pkg_width_mm,
    MAX(CASE WHEN v.std_attr_code = 'pkg_height_mm' THEN v.value_std_double END) AS pkg_height_mm,
    MAX(CASE WHEN v.std_attr_code = 'temp_min_c' THEN v.value_std_double END) AS temp_min_c,
    MAX(CASE WHEN v.std_attr_code = 'temp_max_c' THEN v.value_std_double END) AS temp_max_c,
    MAX(CASE WHEN v.std_attr_code = 'supply_voltage_min_v' THEN v.value_std_double END) AS supply_voltage_min_v,
    MAX(CASE WHEN v.std_attr_code = 'supply_voltage_max_v' THEN v.value_std_double END) AS supply_voltage_max_v,
    MAX(CASE WHEN v.std_attr_code = 'output_current_continuous_a' THEN v.value_std_double END) AS output_current_continuous_a,
    MAX(CASE WHEN v.std_attr_code = 'peak_output_current_a' THEN v.value_std_double END) AS peak_output_current_a,
    MAX(CASE WHEN v.std_attr_code = 'number_of_half_bridges' THEN v.value_std_double END) AS number_of_half_bridges,
    MAX(CASE WHEN v.std_attr_code = 'control_interface_type' THEN v.value_std_varchar END) AS control_interface_type,
    MAX(CASE WHEN v.std_attr_code = 'mounting_style' THEN v.value_std_varchar END) AS mounting_style,
    parse_json(COALESCE(MAX(x.ext_attributes_str), '{}')) AS ext_attributes,
    NULL AS semantic_tags, NULL AS dq_score, NULL AS dq_flags,
    c.data_source AS data_source, c.id AS source_id,
    COALESCE(MAX(old.create_at), CURRENT_TIMESTAMP()) AS create_at,
    CURRENT_TIMESTAMP() AS update_at
FROM dwd.dwd_component_class c
INNER JOIN src_param p ON p.data_source = c.data_source AND p.id = c.id
LEFT JOIN dim.v_std_brand_alias a ON a.brand_key = UPPER(TRIM(p.brandshort))
LEFT JOIN dwd.dwd_component_attr_std v ON v.id = c.id AND v.data_source = c.data_source AND v.l2_code = c.l2_code
LEFT JOIN ext x ON x.id = c.id AND x.data_source = c.data_source
LEFT JOIN dwd.dwd_l2_driver_ic_motor_driver old ON old.id = c.id AND old.data_source = c.data_source
WHERE c.l2_code = 'motor_driver' AND c.l1_code = 'driver_ic' AND c.l3_code NOT LIKE '%_unclassified'
GROUP BY c.id, c.data_source, p.partno, p.brandshort, p.brandid, a.brand_id_std, a.canonical_name, c.l1_code, c.l2_code, c.l3_code;
