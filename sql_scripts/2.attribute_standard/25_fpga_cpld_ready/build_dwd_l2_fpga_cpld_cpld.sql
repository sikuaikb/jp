/* ============================================================
 * 装配 SQL：dwd_component_attr_std（EAV，多源）→ dwd.dwd_l2_fpga_cpld_cpld
 *
 * 品牌标准化：LEFT JOIN dim.v_std_brand_alias；brand=COALESCE(canonical_name, brandshort)；brandid=a.brand_id_std（不兜底源 id）；manufacturer 保持 EAV-only。
 * ============================================================ */

INSERT INTO dwd.dwd_l2_fpga_cpld_cpld
(
    data_source, id, mpn, brand, brandid,
    l1_code, l2_code, l3_code,
    manufacturer, rohs_compliant, lifecycle_status, reach, eccn_code, aec_q_level, lead_free, msl_level,
    package_case, pkg_length_mm, pkg_width_mm, pkg_height_mm, mounting_style,
    temp_min_c, temp_max_c,
    macrocell_count, io_count, vcc_core_min_v, vcc_core_max_v, fmax_mhz, nvm_type, programming_interface,
    ext_attributes, semantic_tags, dq_score, dq_flags,
    source_id, create_at, update_at
)
WITH src_param AS (
    SELECT 'icpdf'   AS data_source, id, partno, brandshort FROM dwd.dwd_icpdf_component_param
    UNION ALL
    SELECT 'digikey' AS data_source, id, partno, brandshort FROM dwd.dwd_digikey_component_param
),
ext AS (
    SELECT e.data_source, e.id,
           concat('{', array_join(array_agg(concat('"', e.std_attr_code, '":',
               CASE WHEN e.db_type IN ('VARCHAR') THEN concat('"', replace(COALESCE(e.value_std_varchar,''), '"', '\\"'), '"')
                    WHEN e.db_type = 'BOOLEAN' THEN CASE WHEN CAST(e.value_std_double AS INT)=1 THEN 'true' WHEN CAST(e.value_std_double AS INT)=0 THEN 'false' ELSE 'null' END
                    ELSE COALESCE(CAST(e.value_std_double AS VARCHAR), 'null') END)), ','), '}') AS ext_attributes_str
    FROM dwd.dwd_component_attr_std e
    INNER JOIN dwd.dwd_component_class c ON c.id = e.id AND c.data_source = e.data_source
    INNER JOIN dim.dim_attr_schema d
            ON d.schema_version = e.attr_schema_version AND d.l1_code = 'fpga_cpld'
           AND d.std_attr_code = e.std_attr_code AND d.scope_level = 'l3' AND d.scope_code = c.l3_code
    WHERE c.l2_code = 'cpld'
      AND (e.value_std_double IS NOT NULL OR (e.value_std_varchar IS NOT NULL AND trim(e.value_std_varchar) <> ''))
    GROUP BY e.data_source, e.id
)
SELECT
    c.data_source,
    c.id,
    COALESCE(NULLIF(TRIM(MAX(CASE WHEN v.std_attr_code = 'mpn' THEN v.value_std_varchar END)), ''), p.partno) AS mpn,
    COALESCE(a.canonical_name, p.brandshort) AS brand,
    a.brand_id_std AS brandid,
    c.l1_code, c.l2_code, c.l3_code,
    MAX(CASE WHEN v.std_attr_code = 'manufacturer'          THEN v.value_std_varchar                            END) AS manufacturer,
    MAX(CASE WHEN v.std_attr_code = 'rohs_compliant'        THEN CAST(v.value_std_double AS BOOLEAN)            END) AS rohs_compliant,
    MAX(CASE WHEN v.std_attr_code = 'lifecycle_status'      THEN v.value_std_varchar                            END) AS lifecycle_status,
    MAX(CASE WHEN v.std_attr_code = 'reach'                 THEN CAST(v.value_std_double AS BOOLEAN)            END) AS reach,
    MAX(CASE WHEN v.std_attr_code = 'eccn_code'             THEN v.value_std_varchar                            END) AS eccn_code,
    MAX(CASE WHEN v.std_attr_code = 'aec_q_level'           THEN v.value_std_varchar                            END) AS aec_q_level,
    MAX(CASE WHEN v.std_attr_code = 'lead_free'             THEN CAST(v.value_std_double AS BOOLEAN)            END) AS lead_free,
    MAX(CASE WHEN v.std_attr_code = 'msl_level'             THEN v.value_std_varchar                            END) AS msl_level,
    MAX(CASE WHEN v.std_attr_code = 'package_case'          THEN v.value_std_varchar                            END) AS package_case,
    MAX(CASE WHEN v.std_attr_code = 'pkg_length_mm'         THEN v.value_std_double                             END) AS pkg_length_mm,
    MAX(CASE WHEN v.std_attr_code = 'pkg_width_mm'          THEN v.value_std_double                             END) AS pkg_width_mm,
    MAX(CASE WHEN v.std_attr_code = 'pkg_height_mm'         THEN v.value_std_double                             END) AS pkg_height_mm,
    MAX(CASE WHEN v.std_attr_code = 'mounting_style'         THEN v.value_std_varchar                            END) AS mounting_style,
    MAX(CASE WHEN v.std_attr_code = 'temp_min_c'            THEN v.value_std_double                             END) AS temp_min_c,
    MAX(CASE WHEN v.std_attr_code = 'temp_max_c'            THEN v.value_std_double                             END) AS temp_max_c,
    CAST(MAX(CASE WHEN v.std_attr_code = 'macrocell_count'       THEN v.value_std_double END) AS INT)               AS macrocell_count,
    CAST(MAX(CASE WHEN v.std_attr_code = 'io_count'              THEN v.value_std_double END) AS INT)               AS io_count,
    MAX(CASE WHEN v.std_attr_code = 'vcc_core_min_v'        THEN v.value_std_double                             END) AS vcc_core_min_v,
    MAX(CASE WHEN v.std_attr_code = 'vcc_core_max_v'        THEN v.value_std_double                             END) AS vcc_core_max_v,
    MAX(CASE WHEN v.std_attr_code = 'fmax_mhz'              THEN v.value_std_double                             END) AS fmax_mhz,
    MAX(CASE WHEN v.std_attr_code = 'nvm_type'              THEN v.value_std_varchar                            END) AS nvm_type,
    MAX(CASE WHEN v.std_attr_code = 'programming_interface' THEN v.value_std_varchar                            END) AS programming_interface,
    parse_json(MAX(x.ext_attributes_str)) AS ext_attributes,
    NULL AS semantic_tags, NULL AS dq_score, NULL AS dq_flags,
    c.id AS source_id,
    COALESCE(MAX(old.create_at), CURRENT_TIMESTAMP()) AS create_at,
    CURRENT_TIMESTAMP() AS update_at
FROM dwd.dwd_component_class c
JOIN src_param p ON p.data_source = c.data_source AND p.id = c.id
LEFT JOIN dim.v_std_brand_alias a ON a.brand_key = UPPER(TRIM(p.brandshort))
LEFT JOIN dwd.dwd_component_attr_std v ON v.id = c.id AND v.data_source = c.data_source AND v.l2_code = c.l2_code
LEFT JOIN ext x ON x.id = c.id AND x.data_source = c.data_source
LEFT JOIN dwd.dwd_l2_fpga_cpld_cpld old ON old.id = c.id AND old.data_source = c.data_source
WHERE c.l2_code = 'cpld'
  AND c.l3_code NOT LIKE '%_unclassified'
GROUP BY c.data_source, c.id, p.partno, p.brandshort, a.brand_id_std, a.canonical_name,
         c.l1_code, c.l2_code, c.l3_code;
