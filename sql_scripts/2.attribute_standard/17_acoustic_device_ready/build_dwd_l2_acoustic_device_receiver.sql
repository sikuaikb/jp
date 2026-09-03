/* ============================================================
 * Build: dwd.dwd_l2_acoustic_device_receiver
 * Source: dwd.dwd_component_class (分类)
 *       + dwd.dwd_component_attr_std (EAV)
 *       + dwd.dwd_digikey_component_param / dwd.dwd_icpdf_component_param (品牌，多源 icpdf + digikey)
 * ============================================================ */

DELETE FROM dwd.dwd_l2_acoustic_device_receiver WHERE data_source IN ('icpdf', 'digikey');

INSERT INTO dwd.dwd_l2_acoustic_device_receiver
WITH src_param AS (
    SELECT 'digikey' AS data_source, id, partno, brandshort, brandid
    FROM dwd.dwd_digikey_component_param
    UNION ALL
    SELECT 'icpdf' AS data_source, id, partno, brandshort, brandid
    FROM dwd.dwd_icpdf_component_param
)
SELECT
    /* ── 标准头部 8 列 ── */
    c.data_source,
    c.id,
    COALESCE(NULLIF(TRIM(MAX(CASE WHEN s.std_attr_code='mpn' THEN s.value_std_varchar END)), ''), p.partno) AS mpn,
    COALESCE(a.canonical_name, p.brandshort)                              AS brand,
    COALESCE(a.brand_id_std,   p.brandid)                                 AS brandid,
    c.l1_code, c.l2_code, c.l3_code,

    /* ── L2 公共属性 ── */
    MAX(CASE WHEN s.std_attr_code='eccn_code' THEN s.value_std_varchar END) AS `eccn_code`,
    MAX(CASE WHEN s.std_attr_code='freq_max_hz' THEN s.value_std_double END) AS `freq_max_hz`,
    MAX(CASE WHEN s.std_attr_code='freq_min_hz' THEN s.value_std_double END) AS `freq_min_hz`,
    MAX(CASE WHEN s.std_attr_code='impedance_ohm' THEN s.value_std_double END) AS `impedance_ohm`,
    MAX(CASE WHEN s.std_attr_code='lead_free' THEN s.value_std_varchar END) AS `lead_free`,
    MAX(CASE WHEN s.std_attr_code='lifecycle_status' THEN s.value_std_varchar END) AS `lifecycle_status`,
    MAX(CASE WHEN s.std_attr_code='manufacturer' THEN s.value_std_varchar END) AS `manufacturer`,
    MAX(CASE WHEN s.std_attr_code='msl_level' THEN s.value_std_varchar END) AS `msl_level`,
    MAX(CASE WHEN s.std_attr_code='package_case' THEN s.value_std_varchar END) AS `package_case`,
    MAX(CASE WHEN s.std_attr_code='pkg_height_mm' THEN s.value_std_double END) AS `pkg_height_mm`,
    MAX(CASE WHEN s.std_attr_code='pkg_length_mm' THEN s.value_std_double END) AS `pkg_length_mm`,
    MAX(CASE WHEN s.std_attr_code='pkg_width_mm' THEN s.value_std_double END) AS `pkg_width_mm`,
    MAX(CASE WHEN s.std_attr_code='rated_power_mw' THEN s.value_std_double END) AS `rated_power_mw`,
    MAX(CASE WHEN s.std_attr_code='rated_voltage_v' THEN s.value_std_double END) AS `rated_voltage_v`,
    MAX(CASE WHEN s.std_attr_code='reach' THEN s.value_std_varchar END) AS `reach`,
    MAX(CASE WHEN s.std_attr_code='rohs_compliant' THEN s.value_std_varchar END) AS `rohs_compliant`,
    MAX(CASE WHEN s.std_attr_code='sensitivity_db_spl' THEN s.value_std_double END) AS `sensitivity_db_spl`,
    MAX(CASE WHEN s.std_attr_code='temp_max_c' THEN s.value_std_double END) AS `temp_max_c`,
    MAX(CASE WHEN s.std_attr_code='temp_min_c' THEN s.value_std_double END) AS `temp_min_c`,
    MAX(CASE WHEN s.std_attr_code='thd_percent' THEN s.value_std_double END) AS `thd_percent`,

    /* ── ext_attributes（L3 专有） ── */
    json_object(
        'coil_dcr_ohm', MAX(CASE WHEN s.std_attr_code='coil_dcr_ohm' THEN COALESCE(s.value_std_varchar, CAST(s.value_std_double AS VARCHAR)) END),
        'diaphragm_diameter_mm', MAX(CASE WHEN s.std_attr_code='diaphragm_diameter_mm' THEN COALESCE(s.value_std_varchar, CAST(s.value_std_double AS VARCHAR)) END),
        'max_spl_db', MAX(CASE WHEN s.std_attr_code='max_spl_db' THEN COALESCE(s.value_std_varchar, CAST(s.value_std_double AS VARCHAR)) END),
        'qts', MAX(CASE WHEN s.std_attr_code='qts' THEN COALESCE(s.value_std_varchar, CAST(s.value_std_double AS VARCHAR)) END),
        'resonant_freq_hz', MAX(CASE WHEN s.std_attr_code='resonant_freq_hz' THEN COALESCE(s.value_std_varchar, CAST(s.value_std_double AS VARCHAR)) END),
        'armature_resonant_freq_hz', MAX(CASE WHEN s.std_attr_code='armature_resonant_freq_hz' THEN COALESCE(s.value_std_varchar, CAST(s.value_std_double AS VARCHAR)) END),
        'max_input_voltage_mv', MAX(CASE WHEN s.std_attr_code='max_input_voltage_mv' THEN COALESCE(s.value_std_varchar, CAST(s.value_std_double AS VARCHAR)) END),
        'sensitivity_tolerance_db', MAX(CASE WHEN s.std_attr_code='sensitivity_tolerance_db' THEN COALESCE(s.value_std_varchar, CAST(s.value_std_double AS VARCHAR)) END),
        'sound_port_type', MAX(CASE WHEN s.std_attr_code='sound_port_type' THEN COALESCE(s.value_std_varchar, CAST(s.value_std_double AS VARCHAR)) END)
    ) AS ext_attributes,

    /* ── 标准尾部 ── */
    CAST(NULL AS JSON)   AS semantic_tags,
    CAST(NULL AS DOUBLE) AS dq_score,
    CAST(NULL AS JSON)   AS dq_flags,
    c.id                 AS source_id,
    NOW()                AS create_at,
    NOW()                AS update_at

FROM dwd.dwd_component_class c
JOIN src_param p
     ON p.data_source = c.data_source AND p.id = c.id
LEFT JOIN dwd.dwd_component_attr_std s
     ON s.id = c.id AND s.data_source = c.data_source
LEFT JOIN dim.v_std_brand_alias a
     ON a.brand_key = p.brandshort
WHERE c.l1_code = 'acoustic_device'
  AND c.l2_code = 'receiver'
  AND c.data_source IN ('icpdf', 'digikey')
  AND c.l3_code NOT LIKE '%_unclassified'
GROUP BY c.data_source, c.id, c.l1_code, c.l2_code, c.l3_code,
         a.canonical_name, a.brand_id_std, p.partno, p.brandshort, p.brandid;
