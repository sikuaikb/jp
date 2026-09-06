/* ============================================================
 * 装配 SQL：dwd.dwd_component_attr_std（EAV，多源；data_source=icpdf|digikey）→ dwd.dwd_l2_data_converter_dac
 *
 * 透视规则：
 *   - scope_level=l2 AND scope_code=dac → 物理列
 *   - scope_level=l3 AND scope_code=c.l3_code → ext_attributes JSON
 *
 * 品牌：LEFT JOIN dim.v_std_brand_alias；brandshort 空则 brand/brandid 为 NULL。
 *
 * 依赖：
 *   build_dwd_component_attr_std_{icpdf,digikey}.sql（dwd.dwd_component_attr_std）
 *   dim.dim_attr_schema / dim.dim_attr_extract_rule（l1_code=data_converter）
 *   dwd.dwd_component_class（l1_code=data_converter）
 *   dim.v_std_brand_alias
 *
 * 执行：L1_LIST=data_converter SOURCES="icpdf digikey" bash run_attr_std.sh prod
 * ============================================================ */

DELETE FROM dwd.dwd_l2_data_converter_dac WHERE data_source IN ('icpdf', 'digikey');

INSERT INTO dwd.dwd_l2_data_converter_dac
(
    id, mpn, brand, brandid,
    l1_code, l2_code, l3_code,
    manufacturer, rohs_compliant, lifecycle_status, reach, eccn_code, msl_level,
    resolution_bit, sample_rate_ksps, data_interface, dac_channel_count,
    settling_time_us, reference_type, differential_output, inl_dnl_lsb,
    supply_voltage_analog_min_v, supply_voltage_analog_max_v,
    supply_voltage_digital_min_v, supply_voltage_digital_max_v,
    temp_min_c, temp_max_c, package_case, mounting_style,
    ext_attributes, semantic_tags, dq_score, dq_flags,
    data_source, source_id, create_at, update_at
)
WITH src_param AS (
    SELECT 'icpdf'   AS data_source, id, partno, brandshort, brandid
    FROM dwd.dwd_icpdf_component_param
    UNION ALL
    SELECT 'digikey' AS data_source, id, partno, brandshort, brandid
    FROM dwd.dwd_digikey_component_param
),
ext AS (
    SELECT
        e.data_source,
        e.id,
        concat('{', array_join(array_agg(concat(
            '"', e.std_attr_code, '":',
            CASE
                WHEN e.db_type = 'VARCHAR'
                    THEN concat('"', replace(COALESCE(e.value_std_varchar, ''), '"', '\\"'), '"')
                WHEN e.db_type = 'BOOLEAN'
                    THEN CASE
                        WHEN CAST(e.value_std_double AS INT) = 1 THEN 'true'
                        WHEN CAST(e.value_std_double AS INT) = 0 THEN 'false'
                        ELSE 'null'
                    END
                ELSE COALESCE(CAST(e.value_std_double AS VARCHAR), 'null')
            END
        )), ','), '}') AS ext_attributes_str
    FROM dwd.dwd_component_attr_std e
    INNER JOIN dwd.dwd_component_class c2
            ON c2.id = e.id AND c2.data_source = e.data_source
    INNER JOIN dim.dim_attr_schema d
            ON d.schema_version = e.attr_schema_version
           AND d.l1_code = 'data_converter'
           AND d.std_attr_code = e.std_attr_code
           AND d.scope_level = 'l3'
           AND d.scope_code = c2.l3_code
           AND d.is_l2_common = 0
    WHERE c2.l1_code = 'data_converter'
      AND c2.l2_code = 'dac'
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
    CASE
        WHEN p.brandshort IS NULL OR TRIM(p.brandshort) = '' THEN NULL
        ELSE COALESCE(a.canonical_name, p.brandshort)
    END AS brand,
    CASE
        WHEN p.brandshort IS NULL OR TRIM(p.brandshort) = '' THEN NULL
        ELSE COALESCE(a.brand_id_std, p.brandid)
    END AS brandid,
    c.l1_code,
    c.l2_code,
    c.l3_code,

    MAX(CASE WHEN v.std_attr_code = 'manufacturer' THEN v.value_std_varchar END) AS manufacturer,
    MAX(CASE WHEN v.std_attr_code = 'rohs_compliant' THEN CAST(v.value_std_double AS BOOLEAN) END) AS rohs_compliant,
    MAX(CASE WHEN v.std_attr_code = 'lifecycle_status' THEN v.value_std_varchar END) AS lifecycle_status,
    MAX(CASE WHEN v.std_attr_code = 'reach' THEN CAST(v.value_std_double AS BOOLEAN) END) AS reach,
    MAX(CASE WHEN v.std_attr_code = 'eccn_code' THEN v.value_std_varchar END) AS eccn_code,
    MAX(CASE WHEN v.std_attr_code = 'msl_level' THEN v.value_std_varchar END) AS msl_level,

    MAX(CASE WHEN v.std_attr_code = 'resolution_bit' THEN CAST(v.value_std_double AS INT) END) AS resolution_bit,
    MAX(CASE WHEN v.std_attr_code = 'sample_rate_ksps' THEN v.value_std_double END) AS sample_rate_ksps,
    MAX(CASE WHEN v.std_attr_code = 'data_interface' THEN v.value_std_varchar END) AS data_interface,
    MAX(CASE WHEN v.std_attr_code = 'dac_channel_count' THEN CAST(v.value_std_double AS INT) END) AS dac_channel_count,
    MAX(CASE WHEN v.std_attr_code = 'settling_time_us' THEN v.value_std_double END) AS settling_time_us,
    MAX(CASE WHEN v.std_attr_code = 'reference_type' THEN v.value_std_varchar END) AS reference_type,
    MAX(CASE WHEN v.std_attr_code = 'differential_output' THEN CAST(v.value_std_double AS BOOLEAN) END) AS differential_output,
    MAX(CASE WHEN v.std_attr_code = 'inl_dnl_lsb' THEN v.value_std_varchar END) AS inl_dnl_lsb,
    MAX(CASE WHEN v.std_attr_code = 'supply_voltage_analog_min_v' THEN v.value_std_double END) AS supply_voltage_analog_min_v,
    MAX(CASE WHEN v.std_attr_code = 'supply_voltage_analog_max_v' THEN v.value_std_double END) AS supply_voltage_analog_max_v,
    MAX(CASE WHEN v.std_attr_code = 'supply_voltage_digital_min_v' THEN v.value_std_double END) AS supply_voltage_digital_min_v,
    MAX(CASE WHEN v.std_attr_code = 'supply_voltage_digital_max_v' THEN v.value_std_double END) AS supply_voltage_digital_max_v,
    MAX(CASE WHEN v.std_attr_code = 'temp_min_c' THEN v.value_std_double END) AS temp_min_c,
    MAX(CASE WHEN v.std_attr_code = 'temp_max_c' THEN v.value_std_double END) AS temp_max_c,
    MAX(CASE WHEN v.std_attr_code = 'package_case' THEN v.value_std_varchar END) AS package_case,
    MAX(CASE WHEN v.std_attr_code = 'mounting_style' THEN v.value_std_varchar END) AS mounting_style,

    parse_json(COALESCE(MAX(x.ext_attributes_str), '{}')) AS ext_attributes,
    NULL AS semantic_tags,
    NULL AS dq_score,
    NULL AS dq_flags,

    c.data_source AS data_source,
    c.id AS source_id,

    COALESCE(MAX(old.create_at), CURRENT_TIMESTAMP()) AS create_at,
    CURRENT_TIMESTAMP() AS update_at
FROM dwd.dwd_component_class c
JOIN src_param p ON p.data_source = c.data_source AND p.id = c.id
LEFT JOIN dim.v_std_brand_alias a ON a.brand_key = UPPER(TRIM(p.brandshort))
LEFT JOIN dwd.dwd_component_attr_std v
       ON v.id = c.id AND v.data_source = c.data_source AND v.l2_code = c.l2_code
LEFT JOIN ext x ON x.id = c.id AND x.data_source = c.data_source
LEFT JOIN dwd.dwd_l2_data_converter_dac old ON old.id = c.id AND old.data_source = c.data_source
WHERE c.l1_code = 'data_converter'
  AND c.l2_code = 'dac'
GROUP BY
    c.id, c.data_source, p.partno, p.brandshort, p.brandid,
    a.brand_id_std, a.canonical_name,
    c.l1_code, c.l2_code, c.l3_code;
