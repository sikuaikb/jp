/* ============================================================
 * 装配 SQL：dwd_component_attr_std（EAV）→ dwd.dwd_l2_mcu
 *
 * 透视规则：
 *   - scope_level=l2 AND scope_code=mcu_base → 全部落物理列
 *   - scope_level=l3 AND scope_code=c.l3_code → ext_attributes JSON
 *
 * 品牌标准化：LEFT JOIN dim.v_std_brand_alias ON UPPER(TRIM(brandshort))；
 *             brand_null=0 且 distinct_brand=distinct_brandid 为门控指标。
 *
 * 依赖：
 *   seed_mcu_mpu_dsp_dim_attr_schema.sql（已装载 dim.dim_attr_schema）
 *   seed_mcu_mpu_dsp_dim_attr_extract_rule.sql（已装载 dim.dim_attr_extract_rule）
 *   seed_mcu_mpu_dsp_dim_unit_factor.sql（已装载 dim.dim_unit_factor）
 *   build_dwd_component_attr_std_icpdf.sql（已生成 dwd.dwd_component_attr_std）
 *   dim.v_std_brand_alias（品牌别名视图）
 *
 * 分类来源：dwd.dwd_component_class（l1_code='mcu'）
 *
 * 执行：mysql … -D dwd < build_dwd_l2_mcu.sql
 * ============================================================ */

INSERT INTO dwd.dwd_l2_mcu_mcu
(
    id, mpn, brand, brandid,
    l1_code, l2_code, l3_code,
    manufacturer, rohs_compliant, lifecycle_status, reach, eccn_code,
    aec_q_level, lead_free, msl_level, package_case, pin_count,
    temp_min_c, temp_max_c,
    cpu_core_arch, bus_width_bit, max_cpu_freq_mhz,
    flash_size_kb, ram_size_kb,
    supply_voltage_min_v, supply_voltage_max_v,
    gpio_count, adc_resolution_bit, adc_channel_count,
    timer_count, pwm_channel_count, uart_count,
    spi_channel_count, i2c_channel_count, usb_interface_type,
    can_channel_count, ethernet_mac_count,
    has_fpu, dma_channel_count, deep_sleep_current_ua,
    ext_attributes, semantic_tags,
    dq_score, dq_flags,
    data_source, source_id,
    create_at, update_at
)
WITH src_param AS (
    SELECT 'icpdf' AS data_source, id, partno, brandshort, brandid
    FROM dwd.dwd_icpdf_component_param
),
ext AS (
    SELECT
        e.data_source,
        e.id,
        concat(
            '{',
            array_join(
                array_agg(
                    concat(
                        '"', e.std_attr_code, '":',
                        CASE
                            WHEN e.db_type IN ('VARCHAR')
                                THEN concat('"', replace(COALESCE(e.value_std_varchar, ''), '"', '\\"'), '"')
                            ELSE COALESCE(CAST(e.value_std_double AS VARCHAR), 'null')
                        END
                    )
                ),
                ','
            ),
            '}'
        ) AS ext_attributes_str
    FROM dwd.dwd_component_attr_std e
    INNER JOIN dwd.dwd_component_class c ON c.id = e.id AND c.data_source = e.data_source AND c.l1_code = 'mcu'
    INNER JOIN dim.dim_attr_schema d
            ON d.std_attr_code = e.std_attr_code
           AND d.l1_code = 'mcu'
           AND d.scope_level = 'l3'
           AND d.scope_code = c.l3_code
    WHERE c.l3_code IS NOT NULL
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
    COALESCE(a.canonical_name, ab.canonical_name, NULLIF(TRIM(p.brandshort), '')) AS brand,
    COALESCE(a.brand_id_std,   ab.brand_id_std,   p.brandid)                    AS brandid,
    c.l1_code,
    c.l2_code,
    c.l3_code,

    MAX(CASE WHEN v.std_attr_code = 'manufacturer' THEN v.value_std_varchar END)     AS manufacturer,
    MAX(CASE WHEN v.std_attr_code = 'rohs_compliant' THEN v.value_std_varchar END)   AS rohs_compliant,
    MAX(CASE WHEN v.std_attr_code = 'lifecycle_status' THEN v.value_std_varchar END) AS lifecycle_status,
    NULL                                                                               AS reach,
    MAX(CASE WHEN v.std_attr_code = 'eccn_code' THEN v.value_std_varchar END)        AS eccn_code,
    NULL                                                                               AS aec_q_level,
    MAX(CASE WHEN v.std_attr_code = 'lead_free' THEN v.value_std_varchar END)        AS lead_free,
    NULL                                                                               AS msl_level,
    MAX(CASE WHEN v.std_attr_code = 'package_case' THEN v.value_std_varchar END)     AS package_case,
    CAST(MAX(CASE WHEN v.std_attr_code = 'pin_count' THEN v.value_std_double END) AS INT) AS pin_count,
    MAX(CASE WHEN v.std_attr_code = 'temp_min_c' THEN v.value_std_double END)        AS temp_min_c,
    MAX(CASE WHEN v.std_attr_code = 'temp_max_c' THEN v.value_std_double END)        AS temp_max_c,

    MAX(CASE WHEN v.std_attr_code = 'cpu_core_arch' THEN v.value_std_varchar END)    AS cpu_core_arch,
    CAST(MAX(CASE WHEN v.std_attr_code = 'bus_width_bit' THEN v.value_std_double END) AS INT)         AS bus_width_bit,
    MAX(CASE WHEN v.std_attr_code = 'max_cpu_freq_mhz' THEN v.value_std_double END)  AS max_cpu_freq_mhz,
    CAST(MAX(CASE WHEN v.std_attr_code = 'flash_size_kb' THEN v.value_std_double END) AS INT)         AS flash_size_kb,
    CAST(MAX(CASE WHEN v.std_attr_code = 'ram_size_kb' THEN v.value_std_double END) AS INT)           AS ram_size_kb,
    MAX(CASE WHEN v.std_attr_code = 'supply_voltage_min_v' THEN v.value_std_double END) AS supply_voltage_min_v,
    MAX(CASE WHEN v.std_attr_code = 'supply_voltage_max_v' THEN v.value_std_double END) AS supply_voltage_max_v,
    CAST(MAX(CASE WHEN v.std_attr_code = 'gpio_count' THEN v.value_std_double END) AS INT)            AS gpio_count,
    CAST(MAX(CASE WHEN v.std_attr_code = 'adc_resolution_bit' THEN v.value_std_double END) AS INT)    AS adc_resolution_bit,
    CAST(MAX(CASE WHEN v.std_attr_code = 'adc_channel_count' THEN v.value_std_double END) AS INT)     AS adc_channel_count,
    CAST(MAX(CASE WHEN v.std_attr_code = 'timer_count' THEN v.value_std_double END) AS INT)           AS timer_count,
    CAST(MAX(CASE WHEN v.std_attr_code = 'pwm_channel_count' THEN v.value_std_double END) AS INT)     AS pwm_channel_count,
    CAST(MAX(CASE WHEN v.std_attr_code = 'uart_count' THEN v.value_std_double END) AS INT)            AS uart_count,
    CAST(MAX(CASE WHEN v.std_attr_code = 'spi_channel_count' THEN v.value_std_double END) AS INT)     AS spi_channel_count,
    CAST(MAX(CASE WHEN v.std_attr_code = 'i2c_channel_count' THEN v.value_std_double END) AS INT)     AS i2c_channel_count,
    MAX(CASE WHEN v.std_attr_code = 'usb_interface_type' THEN v.value_std_varchar END) AS usb_interface_type,
    CAST(MAX(CASE WHEN v.std_attr_code = 'can_channel_count' THEN v.value_std_double END) AS INT)     AS can_channel_count,
    CAST(MAX(CASE WHEN v.std_attr_code = 'ethernet_mac_count' THEN v.value_std_double END) AS INT)    AS ethernet_mac_count,
    MAX(CASE WHEN v.std_attr_code = 'has_fpu' THEN v.value_std_varchar END)           AS has_fpu,
    CAST(MAX(CASE WHEN v.std_attr_code = 'dma_channel_count' THEN v.value_std_double END) AS INT)     AS dma_channel_count,
    MAX(CASE WHEN v.std_attr_code = 'deep_sleep_current_ua' THEN v.value_std_double END) AS deep_sleep_current_ua,

    parse_json(MAX(x.ext_attributes_str)) AS ext_attributes,
    NULL AS semantic_tags,
    NULL AS dq_score,
    NULL AS dq_flags,

    c.data_source,
    c.id    AS source_id,

    COALESCE(MAX(old.create_at), CURRENT_TIMESTAMP()) AS create_at,
    CURRENT_TIMESTAMP()                               AS update_at

FROM dwd.dwd_component_class c
INNER JOIN src_param p ON p.id = c.id AND p.data_source = c.data_source
-- 主路径：brandshort 直接匹配
LEFT JOIN dim.v_std_brand_alias a ON a.brand_key = UPPER(TRIM(p.brandshort))
-- 兜底路径：brandshort 为空时按 brandid 找同 brandid 的规范名
LEFT JOIN (
    SELECT p2.brandid,
           MIN(a2.canonical_name)  AS canonical_name,
           MIN(a2.brand_id_std)    AS brand_id_std
    FROM src_param p2
    JOIN dim.v_std_brand_alias a2 ON a2.brand_key = UPPER(TRIM(p2.brandshort))
    WHERE TRIM(p2.brandshort) <> ''
    GROUP BY p2.brandid
) ab ON ab.brandid = p.brandid
LEFT JOIN dwd.dwd_component_attr_std v ON v.id = c.id AND v.l2_code = c.l2_code AND v.data_source = c.data_source
LEFT JOIN ext x ON x.id = c.id AND x.data_source = c.data_source
LEFT JOIN dwd.dwd_l2_mcu_mcu old ON old.id = c.id AND old.data_source = c.data_source
WHERE c.l1_code = 'mcu'
  AND c.l2_code IS NOT NULL
  AND c.l3_code NOT LIKE '%_unclassified'
GROUP BY
    c.id, c.data_source,
    p.partno,
    p.brandshort,
    p.brandid,
    a.brand_id_std,
    a.canonical_name,
    ab.brand_id_std,
    ab.canonical_name,
    c.l1_code,
    c.l2_code,
    c.l3_code;


/* ---------- 校验 ---------- */
SELECT
    l3_code,
    COUNT(*) AS rows_total,
    SUM(CASE WHEN max_cpu_freq_mhz IS NOT NULL THEN 1 ELSE 0 END) AS has_freq,
    SUM(CASE WHEN flash_size_kb IS NOT NULL THEN 1 ELSE 0 END)    AS has_flash,
    SUM(CASE WHEN ram_size_kb IS NOT NULL THEN 1 ELSE 0 END)      AS has_ram,
    SUM(CASE WHEN cpu_core_arch IS NOT NULL THEN 1 ELSE 0 END)    AS has_arch,
    SUM(CASE WHEN bus_width_bit IS NOT NULL THEN 1 ELSE 0 END)    AS has_bus_w,
    SUM(CASE WHEN package_case IS NOT NULL THEN 1 ELSE 0 END)     AS has_pkg,
    SUM(CASE WHEN rohs_compliant IS NOT NULL THEN 1 ELSE 0 END)   AS has_rohs,
    SUM(CASE WHEN manufacturer IS NOT NULL THEN 1 ELSE 0 END)     AS has_mfr
FROM dwd.dwd_l2_mcu
GROUP BY l3_code
ORDER BY rows_total DESC;
