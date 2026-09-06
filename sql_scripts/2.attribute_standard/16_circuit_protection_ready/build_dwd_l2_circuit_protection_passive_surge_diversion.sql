/* ============================================================
 * EAV → L2 宽表：passive_surge_diversion (passive_surge_diversion)
 *
 * L2 物理列：package_case, temp_min_c, temp_max_c, max_continuous_voltage_v
 * L3 ext (mov 专属)：varistor_voltage_v, junction_capacitance_pf
 * ============================================================ */

DELETE FROM dwd.dwd_l2_circuit_protection_passive_surge_diversion WHERE data_source IN ('icpdf', 'digikey');

INSERT INTO dwd.dwd_l2_circuit_protection_passive_surge_diversion
(
    data_source, id, mpn, brand, brandid,
    l1_code, l2_code, l3_code, brandshort, l3_id,
    manufacturer, lifecycle_status, rohs_compliant, lead_free, msl_level,
    package_case, temp_min_c, temp_max_c, max_continuous_voltage_v,
    ext_attributes, semantic_tags, dq_score, dq_flags,
    source_id, create_at, update_at
)
WITH mfr_agg AS (
    SELECT data_source, id, MAX(value_std_varchar) AS mfr_name
    FROM dwd.dwd_component_attr_std
    WHERE std_attr_code = 'manufacturer'
    GROUP BY data_source, id
),
ext AS (
    SELECT
        e.data_source,
        e.id,
        CONCAT('{',
            ARRAY_JOIN(ARRAY_AGG(
                CONCAT('"', e.std_attr_code, '":',
                    CASE
                        WHEN e.db_type IN ('DOUBLE', 'INT')
                            THEN COALESCE(CAST(e.value_std_double AS VARCHAR), 'null')
                        ELSE CONCAT('"', REPLACE(COALESCE(e.value_std_varchar, ''), '"', '\\"'), '"')
                    END
                )
            ), ','),
        '}') AS ext_attributes_str
    FROM dwd.dwd_component_attr_std e
    INNER JOIN dwd.dwd_component_class c
            ON c.id = e.id AND c.data_source = e.data_source
    INNER JOIN dim.dim_attr_schema d
            ON d.schema_version = e.attr_schema_version
           AND d.l1_code = 'circuit_protection'
           AND d.std_attr_code = e.std_attr_code
           AND d.scope_level = 'l3'
           AND d.scope_code = c.l3_code
    WHERE c.l2_code = 'passive_surge_diversion'
  AND c.l1_code = 'circuit_protection'
  AND COALESCE(c.l3_code, '') NOT LIKE '%_unclassified'
      AND (e.value_std_double IS NOT NULL
        OR (e.value_std_varchar IS NOT NULL AND TRIM(e.value_std_varchar) <> ''))
      AND COALESCE(TRIM(e.value_std_varchar), '') NOT IN ('-', '--', 'N/A', 'n/a', 'None')
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
        a_bs.canonical_name,
        a_mfr.canonical_name,
        NULLIF(TRIM(p.brandshort), ''),
        m.mfr_name
    )), '') AS brand,
    COALESCE(a_bs.brand_id_std, a_mfr.brand_id_std, p.brandid) AS brandid,
    c.l1_code, c.l2_code, c.l3_code,
    NULLIF(TRIM(p.brandshort), '')                                AS brandshort,
    c.l3_id,
    MAX(CASE WHEN v.std_attr_code = 'manufacturer'               THEN v.value_std_varchar END) AS manufacturer,
    MAX(CASE WHEN v.std_attr_code = 'lifecycle_status'           THEN v.value_std_varchar END) AS lifecycle_status,
    MAX(CASE WHEN v.std_attr_code = 'rohs_compliant'             THEN v.value_std_varchar END) AS rohs_compliant,
    MAX(CASE WHEN v.std_attr_code = 'lead_free'                  THEN v.value_std_varchar END) AS lead_free,
    MAX(CASE WHEN v.std_attr_code = 'msl_level'                  THEN v.value_std_varchar END) AS msl_level,
    MAX(CASE WHEN v.std_attr_code = 'package_case'               THEN v.value_std_varchar END) AS package_case,
    MAX(CASE WHEN v.std_attr_code = 'temp_min_c'                 THEN v.value_std_double  END) AS temp_min_c,
    MAX(CASE WHEN v.std_attr_code = 'temp_max_c'                 THEN v.value_std_double  END) AS temp_max_c,
    MAX(CASE WHEN v.std_attr_code = 'max_continuous_voltage_v'   THEN v.value_std_double  END) AS max_continuous_voltage_v,
    PARSE_JSON(MAX(x.ext_attributes_str))                         AS ext_attributes,
    NULL AS semantic_tags, NULL AS dq_score, NULL AS dq_flags,
    c.id AS source_id,
    CURRENT_TIMESTAMP() AS create_at,
    CURRENT_TIMESTAMP() AS update_at
FROM dwd.dwd_component_class c
JOIN (
    SELECT 'icpdf' AS data_source, id, partno, brandshort, brandid FROM dwd.dwd_icpdf_component_param
    UNION ALL
    SELECT 'digikey' AS data_source, id, partno, brandshort, brandid FROM dwd.dwd_digikey_component_param
) p ON p.id = c.id AND p.data_source = c.data_source
LEFT JOIN mfr_agg m
        ON m.id = c.id AND m.data_source = c.data_source
LEFT JOIN dim.v_std_brand_alias a_bs
        ON a_bs.brand_key = UPPER(TRIM(p.brandshort))
LEFT JOIN dim.v_std_brand_alias a_mfr
        ON a_mfr.brand_key = UPPER(TRIM(m.mfr_name))
LEFT JOIN dwd.dwd_component_attr_std v
        ON v.id = c.id AND v.data_source = c.data_source
LEFT JOIN ext x
        ON x.id = c.id AND x.data_source = c.data_source
WHERE c.l2_code = 'passive_surge_diversion'
  AND c.data_source IN ('icpdf', 'digikey')
GROUP BY
    c.data_source, c.id,
    c.l1_code, c.l2_code, c.l3_id, c.l3_code,
    p.partno, p.brandshort, p.brandid,
    a_bs.canonical_name, a_bs.brand_id_std,
    a_mfr.canonical_name, a_mfr.brand_id_std, m.mfr_name;

/* ── 验收 ── */
SELECT
    COUNT(*)                                                                      AS total_rows,
    SUM(CASE WHEN brand IS NULL THEN 1 ELSE 0 END)                               AS brand_null,
    COUNT(DISTINCT brand)                                                         AS distinct_brand,
    SUM(CASE WHEN max_continuous_voltage_v IS NOT NULL THEN 1 ELSE 0 END)        AS has_max_vac,
    SUM(CASE WHEN ext_attributes IS NOT NULL THEN 1 ELSE 0 END)                  AS has_ext
FROM dwd.dwd_l2_circuit_protection_passive_surge_diversion;
