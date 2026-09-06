DELETE FROM dwd.dwd_l2_filter_emi_suppression_filter WHERE data_source IN ('digikey', 'icpdf');

/* ============================================================
 * 装载 SQL：dwd.dwd_component_attr_std (EAV)
 *           → dwd.dwd_l2_filter_emi_suppression_filter
 *
 * 透视规则：
 *   - scope_level='l2', scope_code='emi_suppression_filter'
 *     → 宽表物理列（MAX CASE WHEN）
 *   - scope_level='l3', scope_code=c.l3_code
 *     → ext_attributes JSON
 *
 * 多源：digikey + icpdf（UNION ALL via src_param）
 *
 * 执行：python run_test_wide_emi.py  （或直接以 mysql -D test_dwd 执行本文件）
 * prod 合并替换规则：
 *   s/test_dwd\./dwd./g
 *   s/test_dim\./dim./g
 *   class 表 dwd.dwd_component_class → dwd.dwd_component_class
 * ============================================================ */

INSERT INTO dwd.dwd_l2_filter_emi_suppression_filter
(
    data_source, id, mpn, brand, brandid,
    l1_code, l2_code, l3_code,
    brandshort, l3_id,
    manufacturer, lifecycle_status, eccn_code, htsus_code,
    rohs_compliant, reach, aec_q_level, lead_free,
    msl_level, package_case, mounting_style,
    pkg_length_mm, pkg_width_mm, pkg_height_mm,
    temp_min_c, temp_max_c,
    rated_current_ma,
    ext_attributes, semantic_tags,
    dq_score, dq_flags,
    source_id, create_at, update_at
)

/* ── src_param：多源 digikey + icpdf 联合 ───────── */
WITH src_param AS (
    SELECT 'digikey' AS data_source, id, partno, brandshort, brandid
    FROM dwd.dwd_digikey_component_param
    UNION ALL
    SELECT 'icpdf' AS data_source, id, partno, brandshort, brandid
    FROM dwd.dwd_icpdf_component_param
),

/* ── ext_attributes：把 L3 专有行聚合为 JSON ───────── */
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
                            ELSE -- VARCHAR / ENUM
                                CONCAT('"',
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
           AND d.l1_code = 'filter'
           AND d.std_attr_code = e.std_attr_code
           AND d.scope_level  = 'l3'
           AND d.scope_code   = c.l3_code
    WHERE c.l2_code = 'emi_suppression_filter'
      AND (
           e.value_std_double IS NOT NULL
        OR (e.value_std_varchar IS NOT NULL AND TRIM(e.value_std_varchar) <> '')
      )
      /* 过滤 DK 的占位符脏值（'-' / '--' / 'N/A'），防止进入 ext_attributes */
      AND COALESCE(TRIM(e.value_std_varchar), '') NOT IN ('-', '--', 'N/A', 'n/a', '暂无', 'None')
    GROUP BY e.data_source, e.id
)

/* ── 主 SELECT：透视 L2 公共列 ─────────────────────── */
SELECT
    c.data_source,
    c.id,
    /* mpn：优先 EAV 提取值，退化到 param.partno */
    COALESCE(
        NULLIF(TRIM(MAX(CASE WHEN v.std_attr_code = 'mpn' THEN v.value_std_varchar END)), ''),
        p.partno
    ) AS mpn,
    /* 品牌标准化：字典命中用 canonical_name，否则用 brandshort；NULLIF 过滤空字符串 */
    NULLIF(TRIM(COALESCE(a.canonical_name, p.brandshort)), '')  AS brand,
    COALESCE(a.brand_id_std,   p.brandid)                       AS brandid,
    /* 分类 */
    c.l1_code,
    c.l2_code,
    c.l3_code,
    NULLIF(TRIM(p.brandshort), '')                              AS brandshort,
    c.l3_id,
    /* ── L2 公共属性透视 ── */
    MAX(CASE WHEN v.std_attr_code = 'manufacturer'         THEN v.value_std_varchar END) AS manufacturer,
    MAX(CASE WHEN v.std_attr_code = 'lifecycle_status'     THEN v.value_std_varchar END) AS lifecycle_status,
    MAX(CASE WHEN v.std_attr_code = 'eccn_code'            THEN v.value_std_varchar END) AS eccn_code,
    MAX(CASE WHEN v.std_attr_code = 'htsus_code'          THEN v.value_std_varchar END) AS htsus_code,
    MAX(CASE WHEN v.std_attr_code = 'rohs_compliant'       THEN v.value_std_varchar END) AS rohs_compliant,
    MAX(CASE WHEN v.std_attr_code = 'reach'                THEN v.value_std_varchar END) AS reach,
    MAX(CASE WHEN v.std_attr_code = 'aec_q_level'          THEN v.value_std_varchar END) AS aec_q_level,
    MAX(CASE WHEN v.std_attr_code = 'lead_free'            THEN v.value_std_varchar END) AS lead_free,
    MAX(CASE WHEN v.std_attr_code = 'msl_level'            THEN v.value_std_varchar END) AS msl_level,
    MAX(CASE WHEN v.std_attr_code = 'package_case'         THEN v.value_std_varchar END) AS package_case,
    MAX(CASE WHEN v.std_attr_code = 'mounting_style'       THEN v.value_std_varchar END) AS mounting_style,
    MAX(CASE WHEN v.std_attr_code = 'pkg_length_mm'        THEN v.value_std_double  END) AS pkg_length_mm,
    MAX(CASE WHEN v.std_attr_code = 'pkg_width_mm'         THEN v.value_std_double  END) AS pkg_width_mm,
    MAX(CASE WHEN v.std_attr_code = 'pkg_height_mm'        THEN v.value_std_double  END) AS pkg_height_mm,
    MAX(CASE WHEN v.std_attr_code = 'temp_min_c'           THEN v.value_std_double  END) AS temp_min_c,
    MAX(CASE WHEN v.std_attr_code = 'temp_max_c'           THEN v.value_std_double  END) AS temp_max_c,
    MAX(CASE WHEN v.std_attr_code = 'rated_current_ma'     THEN v.value_std_double  END) AS rated_current_ma,
    /* dcr_mohm → ferrite_bead L3 ext_attributes; impedance_100mhz_ohm → ferrite_bead L3 ext_attributes */
    /* ── L3 专有 → JSON ── */
    PARSE_JSON(MAX(x.ext_attributes_str))  AS ext_attributes,
    NULL AS semantic_tags,
    /* ── 数据质量（预留）── */
    NULL AS dq_score,
    NULL AS dq_flags,
    /* ── 溯源 ── */
    c.id AS source_id,
    CURRENT_TIMESTAMP() AS create_at,
    CURRENT_TIMESTAMP() AS update_at

FROM dwd.dwd_component_class c
JOIN src_param p
        ON p.data_source = c.data_source
       AND p.id = c.id
LEFT JOIN dim.v_std_brand_alias a
        ON a.brand_key = UPPER(TRIM(p.brandshort))
LEFT JOIN dwd.dwd_component_attr_std v
        ON v.id = c.id AND v.data_source = c.data_source
LEFT JOIN ext x
        ON x.id = c.id AND x.data_source = c.data_source

WHERE c.l2_code = 'emi_suppression_filter'
  AND c.data_source IN ('icpdf', 'digikey')
  AND c.l3_code NOT LIKE '%_unclassified'   /* 强制过滤未分类 */

GROUP BY
    c.data_source, c.id,
    c.l1_code, c.l2_code, c.l3_id, c.l3_code,
    p.partno, p.brandshort, p.brandid,
    a.canonical_name, a.brand_id_std;
