/* 装配：EAV → dwd.dwd_l2_mcu_mpu_dsp_mcu（icpdf + digikey，品牌标准化） */

DELETE FROM dwd.dwd_l2_mcu_mpu_dsp_mcu WHERE 1 = 1;

INSERT INTO dwd.dwd_l2_mcu_mpu_dsp_mcu
(
    data_source, id, mpn, brand, brandid,
    l1_code, l2_code, l3_code,
    cpu_core_arch,
    bus_width_bit,
    max_cpu_freq_mhz,
    flash_size_kb,
    ram_size_kb,
    supply_voltage_min_v,
    supply_voltage_max_v,
    gpio_count,
    adc_resolution_bit,
    adc_channel_count,
    timer_count,
    pwm_channel_count,
    uart_count,
    spi_channel_count,
    i2c_channel_count,
    usb_interface_type,
    can_channel_count,
    ethernet_mac_count,
    has_fpu,
    dma_channel_count,
    deep_sleep_current_ua,
    pin_count,
    package_case,
    temp_min_c,
    temp_max_c,
    rohs_compliant,
    reach,
    lead_free,
    aec_q_level,
    msl_level,
    manufacturer,
    lifecycle_status,
    eccn_code,
    ext_attributes, semantic_tags, dq_score, dq_flags,
    source_id, create_at, update_at
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
        concat(
            '{',
            array_join(
                array_agg(
                    concat(
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
           AND d.l1_code = 'mcu_mpu_dsp'
           AND d.std_attr_code = e.std_attr_code
           AND d.scope_level = 'l3'
           AND d.scope_code = c.l3_code
    WHERE c.l2_code = 'mcu'
      AND (
          e.value_std_double IS NOT NULL
          OR (e.value_std_varchar IS NOT NULL AND trim(e.value_std_varchar) <> '')
      )
    GROUP BY e.data_source, e.id
)
SELECT
    c.data_source,
    c.id,
    COALESCE(
        NULLIF(TRIM(MAX(CASE WHEN v.std_attr_code = 'mpn' THEN v.value_std_varchar END)), ''),
        p.partno
    ) AS mpn,
    COALESCE(a.canonical_name, p.brandshort) AS brand,
    COALESCE(a.brand_id_std, p.brandid)    AS brandid,
    c.l1_code,
    c.l2_code,
    c.l3_code,
    MAX(CASE WHEN v.std_attr_code = 'cpu_core_arch' THEN v.value_std_varchar END) AS cpu_core_arch,
    CAST(MAX(CASE WHEN v.std_attr_code = 'bus_width_bit' THEN v.value_std_double END) AS INT) AS bus_width_bit,
    MAX(CASE WHEN v.std_attr_code = 'max_cpu_freq_mhz' THEN v.value_std_double END) AS max_cpu_freq_mhz,
    CAST(MAX(CASE WHEN v.std_attr_code = 'flash_size_kb' THEN v.value_std_double END) AS INT) AS flash_size_kb,
    CAST(MAX(CASE WHEN v.std_attr_code = 'ram_size_kb' THEN v.value_std_double END) AS INT) AS ram_size_kb,
    MAX(CASE WHEN v.std_attr_code = 'supply_voltage_min_v' THEN v.value_std_double END) AS supply_voltage_min_v,
    MAX(CASE WHEN v.std_attr_code = 'supply_voltage_max_v' THEN v.value_std_double END) AS supply_voltage_max_v,
    CAST(MAX(CASE WHEN v.std_attr_code = 'gpio_count' THEN v.value_std_double END) AS INT) AS gpio_count,
    CAST(MAX(CASE WHEN v.std_attr_code = 'adc_resolution_bit' THEN v.value_std_double END) AS INT) AS adc_resolution_bit,
    CAST(MAX(CASE WHEN v.std_attr_code = 'adc_channel_count' THEN v.value_std_double END) AS INT) AS adc_channel_count,
    CAST(MAX(CASE WHEN v.std_attr_code = 'timer_count' THEN v.value_std_double END) AS INT) AS timer_count,
    CAST(MAX(CASE WHEN v.std_attr_code = 'pwm_channel_count' THEN v.value_std_double END) AS INT) AS pwm_channel_count,
    CAST(MAX(CASE WHEN v.std_attr_code = 'uart_count' THEN v.value_std_double END) AS INT) AS uart_count,
    CAST(MAX(CASE WHEN v.std_attr_code = 'spi_channel_count' THEN v.value_std_double END) AS INT) AS spi_channel_count,
    CAST(MAX(CASE WHEN v.std_attr_code = 'i2c_channel_count' THEN v.value_std_double END) AS INT) AS i2c_channel_count,
    MAX(CASE WHEN v.std_attr_code = 'usb_interface_type' THEN v.value_std_varchar END) AS usb_interface_type,
    CAST(MAX(CASE WHEN v.std_attr_code = 'can_channel_count' THEN v.value_std_double END) AS INT) AS can_channel_count,
    CAST(MAX(CASE WHEN v.std_attr_code = 'ethernet_mac_count' THEN v.value_std_double END) AS INT) AS ethernet_mac_count,
    MAX(CASE WHEN v.std_attr_code = 'has_fpu' THEN v.value_std_varchar END) AS has_fpu,
    CAST(MAX(CASE WHEN v.std_attr_code = 'dma_channel_count' THEN v.value_std_double END) AS INT) AS dma_channel_count,
    MAX(CASE WHEN v.std_attr_code = 'deep_sleep_current_ua' THEN v.value_std_double END) AS deep_sleep_current_ua,
    CAST(MAX(CASE WHEN v.std_attr_code = 'pin_count' THEN v.value_std_double END) AS INT) AS pin_count,
    MAX(CASE WHEN v.std_attr_code = 'package_case' THEN v.value_std_varchar END) AS package_case,
    MAX(CASE WHEN v.std_attr_code = 'temp_min_c' THEN v.value_std_double END) AS temp_min_c,
    MAX(CASE WHEN v.std_attr_code = 'temp_max_c' THEN v.value_std_double END) AS temp_max_c,
    MAX(CASE WHEN v.std_attr_code = 'rohs_compliant' THEN CAST(v.value_std_double AS BOOLEAN) END) AS rohs_compliant,
    MAX(CASE WHEN v.std_attr_code = 'reach' THEN CAST(v.value_std_double AS BOOLEAN) END) AS reach,
    MAX(CASE WHEN v.std_attr_code = 'lead_free' THEN CAST(v.value_std_double AS BOOLEAN) END) AS lead_free,
    MAX(CASE WHEN v.std_attr_code = 'aec_q_level' THEN v.value_std_varchar END) AS aec_q_level,
    MAX(CASE WHEN v.std_attr_code = 'msl_level' THEN v.value_std_varchar END) AS msl_level,
    MAX(CASE WHEN v.std_attr_code = 'manufacturer' THEN v.value_std_varchar END) AS manufacturer,
    MAX(CASE WHEN v.std_attr_code = 'lifecycle_status' THEN v.value_std_varchar END) AS lifecycle_status,
    MAX(CASE WHEN v.std_attr_code = 'eccn_code' THEN v.value_std_varchar END) AS eccn_code,
    parse_json(MAX(x.ext_attributes_str)) AS ext_attributes,
    NULL AS semantic_tags,
    NULL AS dq_score,
    NULL AS dq_flags,
    c.id AS source_id,
    COALESCE(MAX(old.create_at), CURRENT_TIMESTAMP()) AS create_at,
    CURRENT_TIMESTAMP() AS update_at
FROM dwd.dwd_component_class c
JOIN src_param p ON p.data_source = c.data_source AND p.id = c.id
LEFT JOIN dim.v_std_brand_alias a ON a.brand_key = UPPER(TRIM(p.brandshort))
LEFT JOIN dwd.dwd_component_attr_std v
       ON v.id = c.id AND v.data_source = c.data_source AND v.l2_code = c.l2_code
LEFT JOIN ext x ON x.id = c.id AND x.data_source = c.data_source
LEFT JOIN dwd.dwd_l2_mcu_mpu_dsp_mcu old ON old.id = c.id AND old.data_source = c.data_source
WHERE c.l1_code = 'mcu_mpu_dsp'
  AND c.l2_code = 'mcu'
  AND c.l3_code NOT LIKE '%_unclassified'
GROUP BY
    c.id, c.data_source, p.partno, p.brandshort, p.brandid,
    a.brand_id_std, a.canonical_name,
    c.l1_code, c.l2_code, c.l3_code;
