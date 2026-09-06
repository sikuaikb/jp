/* EAV → L2 宽表：signal_communication_transformer · icpdf + digikey · transformer_schema_v1.6.08 */
DELETE FROM dwd.dwd_l2_transformer_signal_communication_transformer WHERE data_source IN ('icpdf', 'digikey');

INSERT INTO dwd.dwd_l2_transformer_signal_communication_transformer
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
    `lifecycle_status`,
    `rohs_compliant`,
    `lead_free`,
    `reach`,
    `eccn_code`,
    `htsus_code`,
    `msl_level`,
    `mounting_style`,
    `height_max_mm`,
    `pkg_length_mm`,
    `pkg_width_mm`,
    `transformer_type_raw`,
    `turns_ratio`,
    `temp_min_c`,
    `temp_max_c`,
    `inductance_raw`,
    `aec_q_level`,
    `ext_attributes`,
    `semantic_tags`,
    `dq_score`,
    `dq_flags`,
    `source_id`,
    `create_at`,
    `update_at`
)
WITH src_param AS (
    SELECT 'digikey' AS data_source, id, partno, brandshort, brandid
    FROM dwd.dwd_digikey_component_param
    UNION ALL
    SELECT 'icpdf' AS data_source, id, partno, brandshort, brandid
    FROM dwd.dwd_icpdf_component_param
),
mfr_agg AS (
    SELECT data_source, id, MAX(value_std_varchar) AS mfr_name
    FROM dwd.dwd_component_attr_std
    WHERE std_attr_code = 'manufacturer'
    GROUP BY data_source, id
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
                            WHEN e.db_type = 'BOOLEAN'
                                THEN CASE
                                    WHEN CAST(e.value_std_double AS INT) = 1 THEN 'true'
                                    WHEN CAST(e.value_std_double AS INT) = 0 THEN 'false'
                                    ELSE 'null'
                                END
                            WHEN e.db_type IN ('DOUBLE', 'INT')
                                THEN COALESCE(CAST(e.value_std_double AS VARCHAR), 'null')
                            ELSE CONCAT('"',
                                REPLACE(COALESCE(e.value_std_varchar, ''), '"', '\\"'),
                            '"')
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
           AND d.l1_code = 'transformer'
           AND d.std_attr_code = e.std_attr_code
           AND d.scope_level = 'l3'
           AND d.scope_code = c.l3_code
    WHERE c.l2_code = 'signal_communication_transformer'
      AND c.data_source IN ('icpdf', 'digikey')
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
        NULLIF(TRIM(p.brandshort), ''),
        m.mfr_name
    )), '') AS brand,
    COALESCE(a.brand_id_std, p.brandid) AS brandid,
    c.l1_code,
    c.l2_code,
    c.l3_code,
    NULLIF(TRIM(p.brandshort), '') AS brandshort,
    c.l3_id,
    MAX(CASE WHEN v.std_attr_code = 'manufacturer' THEN v.value_std_varchar END) AS `manufacturer`,
    MAX(CASE WHEN v.std_attr_code = 'lifecycle_status' THEN v.value_std_varchar END) AS `lifecycle_status`,
    MAX(CASE WHEN v.std_attr_code = 'rohs_compliant' THEN v.value_std_varchar END) AS `rohs_compliant`,
    MAX(CASE WHEN v.std_attr_code = 'lead_free' THEN v.value_std_varchar END) AS `lead_free`,
    MAX(CASE WHEN v.std_attr_code = 'reach' THEN v.value_std_varchar END) AS `reach`,
    MAX(CASE WHEN v.std_attr_code = 'eccn_code' THEN v.value_std_varchar END) AS `eccn_code`,
    MAX(CASE WHEN v.std_attr_code = 'htsus_code' THEN v.value_std_varchar END) AS `htsus_code`,
    MAX(CASE WHEN v.std_attr_code = 'msl_level' THEN v.value_std_varchar END) AS `msl_level`,
    MAX(CASE WHEN v.std_attr_code = 'mounting_style' THEN v.value_std_varchar END) AS `mounting_style`,
    MAX(CASE WHEN v.std_attr_code = 'height_max_mm' THEN v.value_std_double END) AS `height_max_mm`,
    MAX(CASE WHEN v.std_attr_code = 'pkg_length_mm' THEN v.value_std_double END) AS `pkg_length_mm`,
    MAX(CASE WHEN v.std_attr_code = 'pkg_width_mm' THEN v.value_std_double END) AS `pkg_width_mm`,
    MAX(CASE WHEN v.std_attr_code = 'transformer_type_raw' THEN v.value_std_varchar END) AS `transformer_type_raw`,
    MAX(CASE WHEN v.std_attr_code = 'turns_ratio' THEN v.value_std_varchar END) AS `turns_ratio`,
    MAX(CASE WHEN v.std_attr_code = 'temp_min_c' THEN v.value_std_double END) AS `temp_min_c`,
    MAX(CASE WHEN v.std_attr_code = 'temp_max_c' THEN v.value_std_double END) AS `temp_max_c`,
    MAX(CASE WHEN v.std_attr_code = 'inductance_raw' THEN v.value_std_varchar END) AS `inductance_raw`,
    MAX(CASE WHEN v.std_attr_code = 'aec_q_level' THEN v.value_std_varchar END) AS `aec_q_level`,
    PARSE_JSON(MAX(x.ext_attributes_str)) AS ext_attributes,
    NULL AS semantic_tags,
    NULL AS dq_score,
    NULL AS dq_flags,
    c.id AS source_id,
    CURRENT_TIMESTAMP() AS create_at,
    CURRENT_TIMESTAMP() AS update_at
FROM dwd.dwd_component_class c
JOIN src_param p
        ON p.id = c.id AND p.data_source = c.data_source
LEFT JOIN dim.v_std_brand_alias a
        ON a.brand_key = UPPER(TRIM(p.brandshort))
LEFT JOIN dwd.dwd_component_attr_std v
        ON v.id = c.id AND v.data_source = c.data_source
LEFT JOIN mfr_agg m
        ON m.id = c.id AND m.data_source = c.data_source
LEFT JOIN ext x
        ON x.id = c.id AND x.data_source = c.data_source
WHERE c.l2_code = 'signal_communication_transformer'
  AND c.data_source IN ('icpdf', 'digikey')
  AND c.l3_code NOT LIKE '%_unclassified'
GROUP BY
    c.data_source, c.id,
    c.l1_code, c.l2_code, c.l3_id, c.l3_code,
    p.partno, p.brandshort, p.brandid,
    a.canonical_name, a.brand_id_std, m.mfr_name;

/* ---------- 验收 ---------- */
SELECT
    data_source,
    COUNT(*) AS total_rows,
    SUM(CASE WHEN brand IS NULL THEN 1 ELSE 0 END) AS brand_null
FROM dwd.dwd_l2_transformer_signal_communication_transformer
GROUP BY 1
ORDER BY 1;
