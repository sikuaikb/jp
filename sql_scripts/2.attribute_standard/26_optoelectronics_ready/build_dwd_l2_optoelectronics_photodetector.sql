/* photodetector：EAV → L2 宽表（dwd） */
DELETE FROM dwd.dwd_l2_optoelectronics_photodetector WHERE data_source = 'digikey';

INSERT INTO dwd.dwd_l2_optoelectronics_photodetector
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
    `peak_wavelength_nm`,
    `spectral_range_min_nm`,
    `spectral_range_max_nm`,
    `responsivity_a_per_w`,
    `active_area_mm2`,
    `photodetector_type`,
    `nep_w_per_sqrt_hz`,
    `ext_attributes`,
    `semantic_tags`,
    `dq_score`,
    `dq_flags`,
    `source_id`,
    `create_at`,
    `update_at`
)
WITH ext AS (
    SELECT e.data_source, e.id,
        CONCAT('{', ARRAY_JOIN(ARRAY_AGG(CONCAT(
            '"', e.std_attr_code, '":',
            CASE WHEN e.db_type IN ('DOUBLE','INT')
                THEN COALESCE(CAST(e.value_std_double AS VARCHAR), 'null')
                ELSE CONCAT('"', REPLACE(COALESCE(e.value_std_varchar,''), '"', '\\"'), '"') END
        )), ','), '}') AS ext_attributes_str
    FROM dwd.dwd_component_attr_std e
    INNER JOIN dwd.dwd_component_class c ON c.id=e.id AND c.data_source=e.data_source
    INNER JOIN dim.dim_attr_schema d
        ON d.schema_version=e.attr_schema_version AND d.l1_code='optoelectronics'
           AND d.std_attr_code=e.std_attr_code AND d.scope_level='l3' AND d.scope_code=c.l3_code
    WHERE c.l2_code='photodetector'
      AND (e.value_std_double IS NOT NULL OR (e.value_std_varchar IS NOT NULL AND TRIM(e.value_std_varchar)<>''))
      AND COALESCE(TRIM(e.value_std_varchar),'') NOT IN ('-','--','N/A','n/a','暂无','None')
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
        a.canonical_name, a_bs_led.canonical_name, a_bs_word.canonical_name, am.canonical_name, am_led.canonical_name, am_word.canonical_name,
        a_url.canonical_name, a_url12.canonical_name, a_url_nd.canonical_name, a_url_head.canonical_name,
        p.brandshort, MAX(get_json_string(p.prajson, '$."制造商"'))
    )), '') AS brand,
    COALESCE(a.brand_id_std, a_bs_led.brand_id_std, a_bs_word.brand_id_std, am.brand_id_std, am_led.brand_id_std, am_word.brand_id_std,
        a_url.brand_id_std, a_url12.brand_id_std, a_url_nd.brand_id_std, a_url_head.brand_id_std, p.brandid) AS brandid,
    c.l1_code,
    c.l2_code,
    c.l3_code,
    NULLIF(TRIM(p.brandshort), '') AS brandshort,
    c.l3_id,
    NULLIF(TRIM(COALESCE(MAX(CASE WHEN v.std_attr_code = 'manufacturer' THEN v.value_std_varchar END), MAX(get_json_string(p.prajson, '$."制造商"')))), '') AS `manufacturer`,
    NULLIF(TRIM(COALESCE(MAX(CASE WHEN v.std_attr_code = 'rohs_compliant' THEN v.value_std_varchar END), MAX(get_json_string(p.prajson, '$."RoHS 状态"')))), '') AS `rohs_compliant`,
    NULLIF(TRIM(COALESCE(MAX(CASE WHEN v.std_attr_code = 'lifecycle_status' THEN v.value_std_varchar END), MAX(get_json_string(p.prajson, '$."零件状态"')))), '') AS `lifecycle_status`,
    NULLIF(TRIM(COALESCE(MAX(CASE WHEN v.std_attr_code = 'reach' THEN v.value_std_varchar END), MAX(get_json_string(p.prajson, '$."REACH 状态"')))), '') AS `reach`,
    NULLIF(TRIM(COALESCE(MAX(CASE WHEN v.std_attr_code = 'eccn_code' THEN v.value_std_varchar END), MAX(get_json_string(p.prajson, '$."ECCN"')))), '') AS `eccn_code`,
    MAX(CASE WHEN v.std_attr_code = 'aec_q_level' THEN v.value_std_varchar END) AS `aec_q_level`,
    MAX(CASE WHEN v.std_attr_code = 'lead_free' THEN v.value_std_varchar END) AS `lead_free`,
    NULLIF(TRIM(COALESCE(MAX(CASE WHEN v.std_attr_code = 'msl_level' THEN v.value_std_varchar END), MAX(get_json_string(p.prajson, '$."湿气敏感性等级 (MSL)"')))), '') AS `msl_level`,
    NULLIF(TRIM(COALESCE(MAX(CASE WHEN v.std_attr_code = 'package_case' THEN v.value_std_varchar END), MAX(get_json_string(p.prajson, '$."封装/外壳"')))), '') AS `package_case`,
    CAST(NULLIF(TRIM(COALESCE(CAST(MAX(CASE WHEN v.std_attr_code = 'temp_min_c' THEN v.value_std_double END) AS VARCHAR), MAX(regexp_extract(get_json_string(p.prajson, '$."工作温度"'), '(-?\\d+\\.?\\d*)\\s*°?C?\\s*~', 1)))), '') AS DOUBLE) AS `temp_min_c`,
    CAST(NULLIF(TRIM(COALESCE(CAST(MAX(CASE WHEN v.std_attr_code = 'temp_max_c' THEN v.value_std_double END) AS VARCHAR), MAX(regexp_extract(get_json_string(p.prajson, '$."工作温度"'), '~\\s*(-?\\d+\\.?\\d*)\\s*°?C', 1)))), '') AS DOUBLE) AS `temp_max_c`,
    CAST(NULLIF(TRIM(COALESCE(CAST(MAX(CASE WHEN v.std_attr_code = 'pkg_length_mm' THEN v.value_std_double END) AS VARCHAR), MAX(regexp_extract(get_json_string(p.prajson, '$."大小 / 尺寸"'), '([\\d.]+)\\s*mm\\s*长', 1)))), '') AS DOUBLE) AS `pkg_length_mm`,
    CAST(NULLIF(TRIM(COALESCE(CAST(MAX(CASE WHEN v.std_attr_code = 'pkg_width_mm' THEN v.value_std_double END) AS VARCHAR), MAX(regexp_extract(get_json_string(p.prajson, '$."大小 / 尺寸"'), 'x\\s*([\\d.]+)\\s*mm\\s*宽', 1)))), '') AS DOUBLE) AS `pkg_width_mm`,
    CAST(NULLIF(TRIM(COALESCE(CAST(MAX(CASE WHEN v.std_attr_code = 'pkg_height_mm' THEN v.value_std_double END) AS VARCHAR), MAX(regexp_extract(get_json_string(p.prajson, '$."高度 - 安装（最大值）"'), '（([\\d.]+)\\s*mm）', 1)))), '') AS DOUBLE) AS `pkg_height_mm`,
    CAST(NULLIF(TRIM(COALESCE(CAST(MAX(CASE WHEN v.std_attr_code = 'peak_wavelength_nm' THEN v.value_std_double END) AS VARCHAR), MAX(regexp_extract(get_json_string(p.prajson, '$."波长 - 峰值"'), '([\\d.]+)\\s*nm', 1)))), '') AS DOUBLE) AS `peak_wavelength_nm`,
    MAX(CASE WHEN v.std_attr_code = 'spectral_range_min_nm' THEN v.value_std_double END) AS `spectral_range_min_nm`,
    MAX(CASE WHEN v.std_attr_code = 'spectral_range_max_nm' THEN v.value_std_double END) AS `spectral_range_max_nm`,
    MAX(CASE WHEN v.std_attr_code = 'responsivity_a_per_w' THEN v.value_std_double END) AS `responsivity_a_per_w`,
    MAX(CASE WHEN v.std_attr_code = 'active_area_mm2' THEN v.value_std_double END) AS `active_area_mm2`,
    NULLIF(TRIM(COALESCE(MAX(CASE WHEN v.std_attr_code = 'photodetector_type' THEN v.value_std_varchar END), MAX(get_json_string(p.prajson, '$."检测器类型"')))), '') AS `photodetector_type`,
    MAX(CASE WHEN v.std_attr_code = 'nep_w_per_sqrt_hz' THEN v.value_std_double END) AS `nep_w_per_sqrt_hz`,
    PARSE_JSON(MAX(x.ext_attributes_str)) AS ext_attributes,
    NULL AS semantic_tags,
    NULL AS dq_score,
    NULL AS dq_flags,
    c.id AS source_id,
    CURRENT_TIMESTAMP() AS create_at,
    CURRENT_TIMESTAMP() AS update_at
FROM dwd.dwd_component_class c
JOIN dwd.dwd_digikey_component_param p ON p.id=c.id AND c.data_source='digikey'
LEFT JOIN dim.v_std_brand_alias a ON a.brand_key = UPPER(TRIM(p.brandshort))
LEFT JOIN dim.v_std_brand_alias a_bs_led
       ON a_bs_led.brand_key = UPPER(REGEXP_REPLACE(TRIM(p.brandshort), '\\s+LED$', ''))
LEFT JOIN dim.v_std_brand_alias a_bs_word
       ON a_bs_word.brand_key = UPPER(TRIM(SPLIT_PART(TRIM(p.brandshort), ' ', 1)))
LEFT JOIN dim.v_std_brand_alias am ON am.brand_key = UPPER(TRIM(get_json_string(p.prajson, '$."制造商"')))
LEFT JOIN dim.v_std_brand_alias am_led
       ON am_led.brand_key = UPPER(REGEXP_REPLACE(TRIM(get_json_string(p.prajson, '$."制造商"')), '\\s+LED$', ''))
LEFT JOIN dim.v_std_brand_alias am_word
       ON am_word.brand_key = UPPER(TRIM(SPLIT_PART(TRIM(get_json_string(p.prajson, '$."制造商"')), ' ', 1)))
LEFT JOIN dim.v_std_brand_alias a_url
       ON a_url.brand_key = UPPER(REPLACE(regexp_extract(p.source_product_url, '/products/detail/([^/]+)/', 1), '-', ' '))
LEFT JOIN dim.v_std_brand_alias a_url12
       ON a_url12.brand_key = UPPER(REPLACE(
            IF(SPLIT_PART(regexp_extract(p.source_product_url, '/products/detail/([^/]+)/', 1), '-', 2) <> '',
               CONCAT(SPLIT_PART(regexp_extract(p.source_product_url, '/products/detail/([^/]+)/', 1), '-', 1), '-',
                      SPLIT_PART(regexp_extract(p.source_product_url, '/products/detail/([^/]+)/', 1), '-', 2)),
               SPLIT_PART(regexp_extract(p.source_product_url, '/products/detail/([^/]+)/', 1), '-', 1)),
            '-', ' '))
LEFT JOIN dim.v_std_brand_alias a_url_nd
       ON a_url_nd.brand_key = UPPER(REPLACE(regexp_extract(p.source_product_url, '/products/detail/([^/]+)/', 1), '-', ''))
LEFT JOIN dim.v_std_brand_alias a_url_head
       ON a_url_head.brand_key = UPPER(SPLIT_PART(regexp_extract(p.source_product_url, '/products/detail/([^/]+)/', 1), '-', 1))
LEFT JOIN dwd.dwd_component_attr_std v ON v.id=c.id AND v.data_source=c.data_source
LEFT JOIN ext x ON x.id=c.id AND x.data_source=c.data_source
WHERE c.l2_code='photodetector' AND c.data_source='digikey' AND c.l3_code NOT LIKE '%_unclassified'
GROUP BY c.data_source,c.id,c.l1_code,c.l2_code,c.l3_id,c.l3_code,p.partno,p.brandshort,p.brandid,a.canonical_name, a.brand_id_std, a_bs_led.canonical_name, a_bs_led.brand_id_std, a_bs_word.canonical_name, a_bs_word.brand_id_std, am.canonical_name, am.brand_id_std, am_led.canonical_name, am_led.brand_id_std, am_word.canonical_name, am_word.brand_id_std, a_url.canonical_name, a_url.brand_id_std, a_url12.canonical_name, a_url12.brand_id_std, a_url_nd.canonical_name, a_url_nd.brand_id_std, a_url_head.canonical_name, a_url_head.brand_id_std;


/* ecloud：EAV → L2 宽表（dwd） */
DELETE FROM dwd.dwd_l2_optoelectronics_photodetector WHERE data_source = 'ecloud';

INSERT INTO dwd.dwd_l2_optoelectronics_photodetector
(
    `data_source`, `id`, `mpn`, `brand`, `brandid`,
    `l1_code`, `l2_code`, `l3_code`,
    `brandshort`, `l3_id`,
    `manufacturer`, `rohs_compliant`, `lifecycle_status`, `reach`, `eccn_code`,
    `aec_q_level`, `lead_free`, `msl_level`,
    `package_case`, `temp_min_c`, `temp_max_c`,
    `pkg_length_mm`, `pkg_width_mm`, `pkg_height_mm`,
    `peak_wavelength_nm`, `spectral_range_min_nm`, `spectral_range_max_nm`,
    `responsivity_a_per_w`, `active_area_mm2`, `photodetector_type`, `nep_w_per_sqrt_hz`,
    `ext_attributes`, `semantic_tags`, `dq_score`, `dq_flags`,
    `source_id`, `create_at`, `update_at`
)
WITH ext AS (
    SELECT
        e.data_source,
        e.id,
        CONCAT('{', ARRAY_JOIN(ARRAY_AGG(CONCAT(
            '"', e.std_attr_code, '":',
            CASE
                WHEN e.db_type IN ('DOUBLE', 'INT')
                    THEN COALESCE(CAST(e.value_std_double AS VARCHAR), 'null')
                ELSE CONCAT('"', REPLACE(COALESCE(e.value_std_varchar, ''), '"', '\\"'), '"')
            END
        )), ','), '}') AS ext_attributes_str
    FROM dwd.dwd_component_attr_std e
    INNER JOIN dwd.dwd_component_class c2
            ON c2.id = e.id AND c2.data_source = e.data_source
    INNER JOIN dim.dim_attr_schema d
            ON d.schema_version = e.attr_schema_version
           AND d.l1_code = 'optoelectronics'
           AND d.std_attr_code = e.std_attr_code
           AND d.scope_level = 'l3'
           AND d.scope_code = c2.l3_code
    WHERE c2.l2_code = 'photodetector'
      AND c2.data_source = 'ecloud'
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
    NULLIF(TRIM(p.brandshort), '') AS brandshort,
    c.l3_id,
    NULLIF(TRIM(MAX(CASE WHEN v.std_attr_code = 'manufacturer' THEN v.value_std_varchar END)), '') AS manufacturer,
    MAX(CASE WHEN v.std_attr_code = 'rohs_compliant' THEN v.value_std_varchar END) AS rohs_compliant,
    MAX(CASE WHEN v.std_attr_code = 'lifecycle_status' THEN v.value_std_varchar END) AS lifecycle_status,
    MAX(CASE WHEN v.std_attr_code = 'reach' THEN v.value_std_varchar END) AS reach,
    MAX(CASE WHEN v.std_attr_code = 'eccn_code' THEN v.value_std_varchar END) AS eccn_code,
    MAX(CASE WHEN v.std_attr_code = 'aec_q_level' THEN v.value_std_varchar END) AS aec_q_level,
    MAX(CASE WHEN v.std_attr_code = 'lead_free' THEN v.value_std_varchar END) AS lead_free,
    MAX(CASE WHEN v.std_attr_code = 'msl_level' THEN v.value_std_varchar END) AS msl_level,
    MAX(CASE WHEN v.std_attr_code = 'package_case' THEN v.value_std_varchar END) AS package_case,
    MAX(CASE WHEN v.std_attr_code = 'temp_min_c' THEN v.value_std_double END) AS temp_min_c,
    MAX(CASE WHEN v.std_attr_code = 'temp_max_c' THEN v.value_std_double END) AS temp_max_c,
    MAX(CASE WHEN v.std_attr_code = 'pkg_length_mm' THEN v.value_std_double END) AS pkg_length_mm,
    MAX(CASE WHEN v.std_attr_code = 'pkg_width_mm' THEN v.value_std_double END) AS pkg_width_mm,
    MAX(CASE WHEN v.std_attr_code = 'pkg_height_mm' THEN v.value_std_double END) AS pkg_height_mm,
    MAX(CASE WHEN v.std_attr_code = 'peak_wavelength_nm' THEN v.value_std_double END) AS peak_wavelength_nm,
    MAX(CASE WHEN v.std_attr_code = 'spectral_range_min_nm' THEN v.value_std_double END) AS spectral_range_min_nm,
    MAX(CASE WHEN v.std_attr_code = 'spectral_range_max_nm' THEN v.value_std_double END) AS spectral_range_max_nm,
    MAX(CASE WHEN v.std_attr_code = 'responsivity_a_per_w' THEN v.value_std_double END) AS responsivity_a_per_w,
    MAX(CASE WHEN v.std_attr_code = 'active_area_mm2' THEN v.value_std_double END) AS active_area_mm2,
    MAX(CASE WHEN v.std_attr_code = 'photodetector_type' THEN v.value_std_varchar END) AS photodetector_type,
    MAX(CASE WHEN v.std_attr_code = 'nep_w_per_sqrt_hz' THEN v.value_std_double END) AS nep_w_per_sqrt_hz,
    PARSE_JSON(COALESCE(MAX(x.ext_attributes_str), '{}')) AS ext_attributes,
    NULL AS semantic_tags,
    NULL AS dq_score,
    NULL AS dq_flags,
    c.id AS source_id,
    CURRENT_TIMESTAMP() AS create_at,
    CURRENT_TIMESTAMP() AS update_at
FROM dwd.dwd_component_class c
INNER JOIN dwd.dwd_ecloud_component_param p ON p.id = c.id AND c.data_source = 'ecloud'
LEFT JOIN dim.v_std_brand_alias a ON a.brand_key = UPPER(TRIM(p.brandshort))
LEFT JOIN dwd.dwd_component_attr_std v
       ON v.id = c.id AND v.data_source = c.data_source AND v.l2_code = c.l2_code
LEFT JOIN ext x ON x.id = c.id AND x.data_source = c.data_source
WHERE c.l1_code = 'optoelectronics'
  AND c.l2_code = 'photodetector'
  AND c.data_source = 'ecloud'
  AND c.l3_code NOT LIKE '%_unclassified'
GROUP BY
    c.data_source, c.id, c.l1_code, c.l2_code, c.l3_id, c.l3_code,
    p.partno, p.brandshort, p.brandid,
    a.canonical_name, a.brand_id_std;

/* icpdf：EAV → L2 宽表（dwd） */
DELETE FROM dwd.dwd_l2_optoelectronics_photodetector WHERE data_source = 'icpdf';

INSERT INTO dwd.dwd_l2_optoelectronics_photodetector
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
    `peak_wavelength_nm`,
    `spectral_range_min_nm`,
    `spectral_range_max_nm`,
    `responsivity_a_per_w`,
    `active_area_mm2`,
    `photodetector_type`,
    `nep_w_per_sqrt_hz`,
    `ext_attributes`,
    `semantic_tags`,
    `dq_score`,
    `dq_flags`,
    `source_id`,
    `create_at`,
    `update_at`
)
WITH ext AS (
    SELECT e.data_source, e.id,
        CONCAT('{', ARRAY_JOIN(ARRAY_AGG(CONCAT(
            '"', e.std_attr_code, '":',
            CASE WHEN e.db_type IN ('DOUBLE','INT')
                THEN COALESCE(CAST(e.value_std_double AS VARCHAR), 'null')
                ELSE CONCAT('"', REPLACE(COALESCE(e.value_std_varchar,''), '"', '\\"'), '"') END
        )), ','), '}') AS ext_attributes_str
    FROM dwd.dwd_component_attr_std e
    INNER JOIN dwd.dwd_component_class c ON c.id=e.id AND c.data_source=e.data_source
    INNER JOIN test_dim.dim_attr_schema_optoelectronics d
        ON d.schema_version=e.attr_schema_version AND d.l1_code='optoelectronics'
           AND d.std_attr_code=e.std_attr_code AND d.scope_level='l3' AND d.scope_code=c.l3_code
    WHERE c.l2_code='photodetector'
      AND (e.value_std_double IS NOT NULL OR (e.value_std_varchar IS NOT NULL AND TRIM(e.value_std_varchar)<>''))
      AND COALESCE(TRIM(e.value_std_varchar),'') NOT IN ('-','--','N/A','n/a','暂无','None')
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
        a.canonical_name, a_bs_led.canonical_name, a_bs_word.canonical_name, am.canonical_name, am_led.canonical_name, am_word.canonical_name,
        p.brandshort, MAX(get_json_string(p.prajson, '$."IHS 制造商"'))
    )), '') AS brand,
    COALESCE(a.brand_id_std, a_bs_led.brand_id_std, a_bs_word.brand_id_std, am.brand_id_std, am_led.brand_id_std, am_word.brand_id_std, p.brandid) AS brandid,
    c.l1_code,
    c.l2_code,
    c.l3_code,
    NULLIF(TRIM(p.brandshort), '') AS brandshort,
    c.l3_id,
    NULLIF(TRIM(COALESCE(MAX(CASE WHEN v.std_attr_code = 'manufacturer' THEN v.value_std_varchar END), MAX(get_json_string(p.prajson, '$."IHS 制造商"')))), '') AS `manufacturer`,
    NULLIF(TRIM(COALESCE(MAX(CASE WHEN v.std_attr_code = 'rohs_compliant' THEN v.value_std_varchar END), MAX(get_json_string(p.prajson, '$."RoHS 状态"')))), '') AS `rohs_compliant`,
    NULLIF(TRIM(COALESCE(MAX(CASE WHEN v.std_attr_code = 'lifecycle_status' THEN v.value_std_varchar END), MAX(get_json_string(p.prajson, '$."零件状态"')))), '') AS `lifecycle_status`,
    NULLIF(TRIM(COALESCE(MAX(CASE WHEN v.std_attr_code = 'reach' THEN v.value_std_varchar END), MAX(get_json_string(p.prajson, '$."REACH 状态"')))), '') AS `reach`,
    NULLIF(TRIM(COALESCE(MAX(CASE WHEN v.std_attr_code = 'eccn_code' THEN v.value_std_varchar END), MAX(get_json_string(p.prajson, '$."ECCN"')))), '') AS `eccn_code`,
    MAX(CASE WHEN v.std_attr_code = 'aec_q_level' THEN v.value_std_varchar END) AS `aec_q_level`,
    MAX(CASE WHEN v.std_attr_code = 'lead_free' THEN v.value_std_varchar END) AS `lead_free`,
    NULLIF(TRIM(COALESCE(MAX(CASE WHEN v.std_attr_code = 'msl_level' THEN v.value_std_varchar END), MAX(get_json_string(p.prajson, '$."湿气敏感性等级 (MSL)"')))), '') AS `msl_level`,
    NULLIF(TRIM(COALESCE(MAX(CASE WHEN v.std_attr_code = 'package_case' THEN v.value_std_varchar END), MAX(get_json_string(p.prajson, '$."封装/外壳"')))), '') AS `package_case`,
    CAST(NULLIF(TRIM(COALESCE(CAST(MAX(CASE WHEN v.std_attr_code = 'temp_min_c' THEN v.value_std_double END) AS VARCHAR), MAX(regexp_extract(get_json_string(p.prajson, '$."工作温度"'), '(-?\\d+\\.?\\d*)\\s*°?C?\\s*~', 1)))), '') AS DOUBLE) AS `temp_min_c`,
    CAST(NULLIF(TRIM(COALESCE(CAST(MAX(CASE WHEN v.std_attr_code = 'temp_max_c' THEN v.value_std_double END) AS VARCHAR), MAX(regexp_extract(get_json_string(p.prajson, '$."工作温度"'), '~\\s*(-?\\d+\\.?\\d*)\\s*°?C', 1)))), '') AS DOUBLE) AS `temp_max_c`,
    CAST(NULLIF(TRIM(COALESCE(CAST(MAX(CASE WHEN v.std_attr_code = 'pkg_length_mm' THEN v.value_std_double END) AS VARCHAR), MAX(regexp_extract(get_json_string(p.prajson, '$."大小 / 尺寸"'), '([\\d.]+)\\s*mm\\s*长', 1)))), '') AS DOUBLE) AS `pkg_length_mm`,
    CAST(NULLIF(TRIM(COALESCE(CAST(MAX(CASE WHEN v.std_attr_code = 'pkg_width_mm' THEN v.value_std_double END) AS VARCHAR), MAX(regexp_extract(get_json_string(p.prajson, '$."大小 / 尺寸"'), 'x\\s*([\\d.]+)\\s*mm\\s*宽', 1)))), '') AS DOUBLE) AS `pkg_width_mm`,
    CAST(NULLIF(TRIM(COALESCE(CAST(MAX(CASE WHEN v.std_attr_code = 'pkg_height_mm' THEN v.value_std_double END) AS VARCHAR), MAX(regexp_extract(get_json_string(p.prajson, '$."高度 - 安装（最大值）"'), '（([\\d.]+)\\s*mm）', 1)))), '') AS DOUBLE) AS `pkg_height_mm`,
    CAST(NULLIF(TRIM(COALESCE(CAST(MAX(CASE WHEN v.std_attr_code = 'peak_wavelength_nm' THEN v.value_std_double END) AS VARCHAR), MAX(regexp_extract(get_json_string(p.prajson, '$."波长 - 峰值"'), '([\\d.]+)\\s*nm', 1)))), '') AS DOUBLE) AS `peak_wavelength_nm`,
    MAX(CASE WHEN v.std_attr_code = 'spectral_range_min_nm' THEN v.value_std_double END) AS `spectral_range_min_nm`,
    MAX(CASE WHEN v.std_attr_code = 'spectral_range_max_nm' THEN v.value_std_double END) AS `spectral_range_max_nm`,
    MAX(CASE WHEN v.std_attr_code = 'responsivity_a_per_w' THEN v.value_std_double END) AS `responsivity_a_per_w`,
    MAX(CASE WHEN v.std_attr_code = 'active_area_mm2' THEN v.value_std_double END) AS `active_area_mm2`,
    NULLIF(TRIM(COALESCE(MAX(CASE WHEN v.std_attr_code = 'photodetector_type' THEN v.value_std_varchar END), MAX(get_json_string(p.prajson, '$."检测器类型"')))), '') AS `photodetector_type`,
    MAX(CASE WHEN v.std_attr_code = 'nep_w_per_sqrt_hz' THEN v.value_std_double END) AS `nep_w_per_sqrt_hz`,
    PARSE_JSON(MAX(x.ext_attributes_str)) AS ext_attributes,
    NULL AS semantic_tags,
    NULL AS dq_score,
    NULL AS dq_flags,
    c.id AS source_id,
    CURRENT_TIMESTAMP() AS create_at,
    CURRENT_TIMESTAMP() AS update_at
FROM dwd.dwd_component_class c
JOIN dwd.dwd_icpdf_component_param p ON p.id=c.id AND c.data_source='icpdf'
LEFT JOIN dim.v_std_brand_alias a ON a.brand_key = UPPER(TRIM(p.brandshort))
LEFT JOIN dim.v_std_brand_alias a_bs_led
       ON a_bs_led.brand_key = UPPER(REGEXP_REPLACE(TRIM(p.brandshort), '\\s+LED$', ''))
LEFT JOIN dim.v_std_brand_alias a_bs_word
       ON a_bs_word.brand_key = UPPER(TRIM(SPLIT_PART(TRIM(p.brandshort), ' ', 1)))
LEFT JOIN dim.v_std_brand_alias am ON am.brand_key = UPPER(TRIM(get_json_string(p.prajson, '$."IHS 制造商"')))
LEFT JOIN dim.v_std_brand_alias am_led
       ON am_led.brand_key = UPPER(REGEXP_REPLACE(TRIM(get_json_string(p.prajson, '$."IHS 制造商"')), '\\s+LED$', ''))
LEFT JOIN dim.v_std_brand_alias am_word
       ON am_word.brand_key = UPPER(TRIM(SPLIT_PART(TRIM(get_json_string(p.prajson, '$."IHS 制造商"')), ' ', 1)))

LEFT JOIN dwd.dwd_component_attr_std v ON v.id=c.id AND v.data_source=c.data_source
LEFT JOIN ext x ON x.id=c.id AND x.data_source=c.data_source
WHERE c.l2_code='photodetector' AND c.data_source='icpdf' AND c.l3_code NOT LIKE '%_unclassified'
GROUP BY c.data_source,c.id,c.l1_code,c.l2_code,c.l3_id,c.l3_code,p.partno,p.brandshort,p.brandid,a.canonical_name, a.brand_id_std, a_bs_led.canonical_name, a_bs_led.brand_id_std, a_bs_word.canonical_name, a_bs_word.brand_id_std, am.canonical_name, am.brand_id_std, am_led.canonical_name, am_led.brand_id_std, am_word.canonical_name, am_word.brand_id_std
;
