/* prod icpdf + digikey → dwd.dwd_l2_interface_communication_ic_ethernet_interface */
/* digikey block */
/* Build dwd_l2_interface_communication_ic_ethernet_interface from EAV */
DELETE FROM dwd.dwd_l2_interface_communication_ic_ethernet_interface WHERE data_source = 'digikey';

INSERT INTO dwd.dwd_l2_interface_communication_ic_ethernet_interface
(
    `data_source`,
    `id`,
    `mpn`,
    `brand`,
    `brandid`,
    `l1_code`,
    `l2_code`,
    `l3_code`,
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
    `max_speed_mbps`,
    `port_count`,
    `host_interface_type`,
    `supply_voltage_v`,
    `supply_voltage_range_v`,
    `ext_attributes`,
    `semantic_tags`,
    `dq_score`,
    `dq_flags`,
    `source_id`,
    `create_at`,
    `update_at`
)
WITH mfr_agg AS (
    SELECT data_source, id, MAX(value_std_varchar) AS mfr_name
    FROM dwd.dwd_component_attr_std
    WHERE std_attr_code = 'manufacturer'
      AND value_std_varchar IS NOT NULL
      AND TRIM(value_std_varchar) <> ''
    GROUP BY data_source, id
),
ic_brand AS (
    SELECT
        UPPER(TRIM(SPLIT_PART(partno, ',', 1))) AS partno_key,
        MAX(brandshort) AS brandshort,
        MAX(brandid) AS brandid
    FROM dwd.dwd_icpdf_component_param
    WHERE brandshort IS NOT NULL AND TRIM(brandshort) <> ''
    GROUP BY UPPER(TRIM(SPLIT_PART(partno, ',', 1)))
),
ic_brand_base AS (
    SELECT
        UPPER(REGEXP_REPLACE(partno, '[^A-Za-z0-9].*$', '')) AS base_key,
        MAX(brandshort) AS brandshort,
        MAX(brandid) AS brandid
    FROM dwd.dwd_icpdf_component_param
    WHERE brandshort IS NOT NULL AND TRIM(brandshort) <> ''
      AND LENGTH(REGEXP_REPLACE(partno, '[^A-Za-z0-9].*$', '')) >= 5
    GROUP BY UPPER(REGEXP_REPLACE(partno, '[^A-Za-z0-9].*$', ''))
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
                            WHEN e.db_type IN ('DOUBLE', 'INT')
                                THEN COALESCE(CAST(e.value_std_double AS VARCHAR), 'null')
                            ELSE CONCAT('"', REPLACE(COALESCE(e.value_std_varchar, ''), '"', '\\"'), '"')
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
           AND d.l1_code = 'interface_communication_ic'
           AND d.std_attr_code = e.std_attr_code
           AND d.scope_level = 'l3'
           AND d.scope_code = c.l3_code
    WHERE c.l2_code = 'ethernet_interface'
      AND c.data_source = 'digikey'
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
        am.canonical_name,
        af.canonical_name,
        adk.canonical_name,
        aic.canonical_name,
        aicb.canonical_name,
        aim.canonical_name,
        ap.canonical_name,
        NULLIF(TRIM(p.brandshort), ''),
        NULLIF(TRIM(m.mfr_name), ''),
        NULLIF(TRIM(ic.brandshort), ''),
        NULLIF(TRIM(icb.brandshort), ''),
        CASE
        WHEN UPPER(p.partno) REGEXP '^(XR1[678]|XR8|XR68|XR19|ST16)' THEN 'EXAR'
        WHEN UPPER(p.partno) REGEXP '^(SC16|SC28|SCC2|SC26)' THEN 'NXP'
        WHEN UPPER(p.partno) REGEXP '^HD63' THEN 'HITACHI'
        WHEN UPPER(p.partno) REGEXP '^(COM2|COM80)' THEN 'SMSC'
        WHEN UPPER(p.partno) REGEXP '^MAX9' THEN 'MAXIM'
        WHEN UPPER(p.partno) REGEXP '^MAX310' THEN 'MAXIM'
        WHEN UPPER(p.partno) REGEXP '^DS90' THEN 'TI'
        WHEN UPPER(p.partno) REGEXP '^(TL16|SN65)' THEN 'TI'
        WHEN UPPER(p.partno) REGEXP '^(ISL83|ISL76|IS82)' THEN 'INTERSIL'
        WHEN UPPER(p.partno) REGEXP '^PC165' THEN 'NXP'
        WHEN UPPER(p.partno) REGEXP '^(N8251|P8251|8251)' THEN 'Intel'
        WHEN UPPER(p.partno) REGEXP '^(AY-3|AY-5|AY-6)' THEN 'MICROCHIP'
        WHEN UPPER(p.partno) REGEXP '^(CDP18|CDP65|CP185)' THEN 'RENESAS'
        WHEN UPPER(p.partno) REGEXP '^ST78' THEN 'STMICROELECTRONICS'
        WHEN UPPER(p.partno) REGEXP '^HD[13]-6402' THEN 'RENESAS'
        WHEN UPPER(p.partno) REGEXP '^TN825' THEN 'Intel'
        ELSE NULL
    END
    )), '') AS brand,
    COALESCE(
        a.brand_id_std,
        am.brand_id_std,
        af.brand_id_std,
        adk.brand_id_std,
        aic.brand_id_std,
        aicb.brand_id_std,
        aim.brand_id_std,
        ap.brand_id_std,
        ic.brandid,
        icb.brandid
    ) AS brandid,
    c.l1_code,
    c.l2_code,
    c.l3_code,
    MAX(CASE WHEN v.std_attr_code = 'manufacturer' THEN v.value_std_varchar END) AS `manufacturer`,
    MAX(CASE WHEN v.std_attr_code = 'rohs_compliant' THEN v.value_std_varchar END) AS `rohs_compliant`,
    MAX(CASE WHEN v.std_attr_code = 'lifecycle_status' THEN v.value_std_varchar END) AS `lifecycle_status`,
    MAX(CASE WHEN v.std_attr_code = 'reach' THEN v.value_std_varchar END) AS `reach`,
    MAX(CASE WHEN v.std_attr_code = 'eccn_code' THEN v.value_std_varchar END) AS `eccn_code`,
    MAX(CASE WHEN v.std_attr_code = 'aec_q_level' THEN v.value_std_varchar END) AS `aec_q_level`,
    MAX(CASE WHEN v.std_attr_code = 'lead_free' THEN v.value_std_varchar END) AS `lead_free`,
    MAX(CASE WHEN v.std_attr_code = 'msl_level' THEN v.value_std_varchar END) AS `msl_level`,
    MAX(CASE WHEN v.std_attr_code = 'package_case' THEN v.value_std_varchar END) AS `package_case`,
    MAX(CASE WHEN v.std_attr_code = 'temp_min_c' THEN v.value_std_double END) AS `temp_min_c`,
    MAX(CASE WHEN v.std_attr_code = 'temp_max_c' THEN v.value_std_double END) AS `temp_max_c`,
    MAX(CASE WHEN v.std_attr_code = 'pkg_length_mm' THEN v.value_std_double END) AS `pkg_length_mm`,
    MAX(CASE WHEN v.std_attr_code = 'pkg_width_mm' THEN v.value_std_double END) AS `pkg_width_mm`,
    MAX(CASE WHEN v.std_attr_code = 'pkg_height_mm' THEN v.value_std_double END) AS `pkg_height_mm`,
    MAX(CASE WHEN v.std_attr_code = 'max_speed_mbps' THEN v.value_std_double END) AS `max_speed_mbps`,
    MAX(CASE WHEN v.std_attr_code = 'port_count' THEN v.value_std_double END) AS `port_count`,
    MAX(CASE WHEN v.std_attr_code = 'host_interface_type' THEN v.value_std_varchar END) AS `host_interface_type`,
    MAX(CASE WHEN v.std_attr_code = 'supply_voltage_v' THEN v.value_std_double END) AS `supply_voltage_v`,
    MAX(CASE WHEN v.std_attr_code = 'supply_voltage_range_v' THEN v.value_std_varchar END) AS `supply_voltage_range_v`,
    PARSE_JSON(MAX(x.ext_attributes_str)) AS ext_attributes,
    NULL AS semantic_tags,
    NULL AS dq_score,
    NULL AS dq_flags,
    c.id AS source_id,
    CURRENT_TIMESTAMP() AS create_at,
    CURRENT_TIMESTAMP() AS update_at
FROM dwd.dwd_component_class c
JOIN dwd.dwd_digikey_component_param p ON p.id = c.id AND c.data_source = 'digikey'
LEFT JOIN dim.v_std_brand_alias a ON a.brand_key = UPPER(TRIM(p.brandshort))
LEFT JOIN dim.v_std_brand_alias am
       ON am.brand_key = UPPER(TRIM(substr(TRIM(split_part(
        COALESCE(
            NULLIF(TRIM(get_json_string(p.prajson, '$.\"制造商\"')), ''),
            NULLIF(TRIM(get_json_string(p.prajson, '$.\"Manufacturer\"')), '')
        ), ' (', 1)), 1, 128)))
LEFT JOIN dim.v_std_brand_alias af
       ON af.brand_key = UPPER(TRIM(SPLIT_PART(p.brandshort, ' ', 1)))
LEFT JOIN dim.v_std_brand_alias adk
       ON adk.brand_key = CASE UPPER(TRIM(p.brandshort))
        WHEN 'AQUANTIA CORP' THEN 'MARVELL'
        WHEN 'LANTIQ' THEN 'INTEL'
        WHEN 'BRIDGETEK PTE LTD.' THEN 'FTDI'
        WHEN 'GENNUM' THEN 'MICROSEMI'
        ELSE NULL
    END
LEFT JOIN dwd.dwd_component_attr_std v
       ON v.id = c.id AND v.data_source = c.data_source
LEFT JOIN mfr_agg m ON m.id = c.id AND m.data_source = c.data_source
LEFT JOIN dim.v_std_brand_alias aim
       ON aim.brand_key = UPPER(TRIM(m.mfr_name))
LEFT JOIN ic_brand ic
       ON ic.partno_key = UPPER(TRIM(SPLIT_PART(p.partno, ',', 1)))
LEFT JOIN ic_brand_base icb
       ON icb.base_key = UPPER(REGEXP_REPLACE(p.partno, '[^A-Za-z0-9].*$', ''))
LEFT JOIN dim.v_std_brand_alias aic
       ON aic.brand_key = UPPER(TRIM(ic.brandshort))
LEFT JOIN dim.v_std_brand_alias aicb
       ON aicb.brand_key = UPPER(TRIM(icb.brandshort))
LEFT JOIN dim.v_std_brand_alias ap
       ON ap.brand_key = UPPER(TRIM(CASE
        WHEN UPPER(p.partno) REGEXP '^(XR1[678]|XR8|XR68|XR19|ST16)' THEN 'EXAR'
        WHEN UPPER(p.partno) REGEXP '^(SC16|SC28|SCC2|SC26)' THEN 'NXP'
        WHEN UPPER(p.partno) REGEXP '^HD63' THEN 'HITACHI'
        WHEN UPPER(p.partno) REGEXP '^(COM2|COM80)' THEN 'SMSC'
        WHEN UPPER(p.partno) REGEXP '^MAX9' THEN 'MAXIM'
        WHEN UPPER(p.partno) REGEXP '^MAX310' THEN 'MAXIM'
        WHEN UPPER(p.partno) REGEXP '^DS90' THEN 'TI'
        WHEN UPPER(p.partno) REGEXP '^(TL16|SN65)' THEN 'TI'
        WHEN UPPER(p.partno) REGEXP '^(ISL83|ISL76|IS82)' THEN 'INTERSIL'
        WHEN UPPER(p.partno) REGEXP '^PC165' THEN 'NXP'
        WHEN UPPER(p.partno) REGEXP '^(N8251|P8251|8251)' THEN 'Intel'
        WHEN UPPER(p.partno) REGEXP '^(AY-3|AY-5|AY-6)' THEN 'MICROCHIP'
        WHEN UPPER(p.partno) REGEXP '^(CDP18|CDP65|CP185)' THEN 'RENESAS'
        WHEN UPPER(p.partno) REGEXP '^ST78' THEN 'STMICROELECTRONICS'
        WHEN UPPER(p.partno) REGEXP '^HD[13]-6402' THEN 'RENESAS'
        WHEN UPPER(p.partno) REGEXP '^TN825' THEN 'Intel'
        ELSE NULL
    END))
LEFT JOIN ext x ON x.id = c.id AND x.data_source = c.data_source
WHERE c.l2_code = 'ethernet_interface'
  AND c.data_source = 'digikey'
  AND c.l3_code NOT LIKE '%_unclassified'
GROUP BY
    c.data_source, c.id,
    c.l1_code, c.l2_code, c.l3_code,
    p.partno, p.brandshort,
    substr(TRIM(split_part(
        COALESCE(
            NULLIF(TRIM(get_json_string(p.prajson, '$.\"制造商\"')), ''),
            NULLIF(TRIM(get_json_string(p.prajson, '$.\"Manufacturer\"')), '')
        ), ' (', 1)), 1, 128),
    a.canonical_name, a.brand_id_std,
    am.canonical_name, am.brand_id_std,
    af.canonical_name, af.brand_id_std,
    adk.canonical_name, adk.brand_id_std,
    aim.canonical_name, aim.brand_id_std,
    aic.canonical_name, aic.brand_id_std,
    aicb.canonical_name, aicb.brand_id_std,
    ap.canonical_name, ap.brand_id_std,
    m.mfr_name,
    ic.brandshort, ic.brandid,
    icb.brandshort, icb.brandid;


/* icpdf block */
DELETE FROM dwd.dwd_l2_interface_communication_ic_ethernet_interface WHERE data_source = 'icpdf';

INSERT INTO dwd.dwd_l2_interface_communication_ic_ethernet_interface
(
    `data_source`,
    `id`,
    `mpn`,
    `brand`,
    `brandid`,
    `l1_code`,
    `l2_code`,
    `l3_code`,
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
    `max_speed_mbps`,
    `port_count`,
    `host_interface_type`,
    `supply_voltage_v`,
    `supply_voltage_range_v`,
    `ext_attributes`,
    `semantic_tags`,
    `dq_score`,
    `dq_flags`,
    `source_id`,
    `create_at`,
    `update_at`
)
WITH mfr_agg AS (
    SELECT data_source, id, MAX(value_std_varchar) AS mfr_name
    FROM dwd.dwd_component_attr_std
    WHERE std_attr_code = 'manufacturer'
      AND value_std_varchar IS NOT NULL
      AND TRIM(value_std_varchar) <> ''
    GROUP BY data_source, id
),
ic_brand AS (
    SELECT
        UPPER(TRIM(SPLIT_PART(partno, ',', 1))) AS partno_key,
        MAX(brandshort) AS brandshort,
        MAX(brandid) AS brandid
    FROM dwd.dwd_icpdf_component_param
    WHERE brandshort IS NOT NULL AND TRIM(brandshort) <> ''
    GROUP BY UPPER(TRIM(SPLIT_PART(partno, ',', 1)))
),
ic_brand_base AS (
    SELECT
        UPPER(REGEXP_REPLACE(partno, '[^A-Za-z0-9].*$', '')) AS base_key,
        MAX(brandshort) AS brandshort,
        MAX(brandid) AS brandid
    FROM dwd.dwd_icpdf_component_param
    WHERE brandshort IS NOT NULL AND TRIM(brandshort) <> ''
      AND LENGTH(REGEXP_REPLACE(partno, '[^A-Za-z0-9].*$', '')) >= 5
    GROUP BY UPPER(REGEXP_REPLACE(partno, '[^A-Za-z0-9].*$', ''))
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
                            WHEN e.db_type IN ('DOUBLE', 'INT')
                                THEN COALESCE(CAST(e.value_std_double AS VARCHAR), 'null')
                            ELSE CONCAT('"', REPLACE(COALESCE(e.value_std_varchar, ''), '"', '\\"'), '"')
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
           AND d.l1_code = 'interface_communication_ic'
           AND d.std_attr_code = e.std_attr_code
           AND d.scope_level = 'l3'
           AND d.scope_code = c.l3_code
    WHERE c.l1_code = 'interface_communication_ic'
      AND c.l2_code = 'ethernet_interface'
      AND c.data_source = 'icpdf'
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
        am.canonical_name,
        af.canonical_name,
        adk.canonical_name,
        aic.canonical_name,
        aicb.canonical_name,
        aim.canonical_name,
        ap.canonical_name,
        NULLIF(TRIM(p.brandshort), ''),
        NULLIF(TRIM(m.mfr_name), ''),
        NULLIF(TRIM(ic.brandshort), ''),
        NULLIF(TRIM(icb.brandshort), ''),
        CASE
        WHEN UPPER(p.partno) REGEXP '^(XR1[678]|XR8|XR68|XR19|ST16)' THEN 'EXAR'
        WHEN UPPER(p.partno) REGEXP '^(SC16|SC28|SCC2|SC26)' THEN 'NXP'
        WHEN UPPER(p.partno) REGEXP '^HD63' THEN 'HITACHI'
        WHEN UPPER(p.partno) REGEXP '^(COM2|COM80)' THEN 'SMSC'
        WHEN UPPER(p.partno) REGEXP '^MAX9' THEN 'MAXIM'
        WHEN UPPER(p.partno) REGEXP '^MAX310' THEN 'MAXIM'
        WHEN UPPER(p.partno) REGEXP '^DS90' THEN 'TI'
        WHEN UPPER(p.partno) REGEXP '^(TL16|SN65)' THEN 'TI'
        WHEN UPPER(p.partno) REGEXP '^(ISL83|ISL76|IS82)' THEN 'INTERSIL'
        WHEN UPPER(p.partno) REGEXP '^PC165' THEN 'NXP'
        WHEN UPPER(p.partno) REGEXP '^(N8251|P8251|8251)' THEN 'Intel'
        WHEN UPPER(p.partno) REGEXP '^(AY-3|AY-5|AY-6)' THEN 'MICROCHIP'
        WHEN UPPER(p.partno) REGEXP '^(CDP18|CDP65|CP185)' THEN 'RENESAS'
        WHEN UPPER(p.partno) REGEXP '^ST78' THEN 'STMICROELECTRONICS'
        WHEN UPPER(p.partno) REGEXP '^HD[13]-6402' THEN 'RENESAS'
        WHEN UPPER(p.partno) REGEXP '^TN825' THEN 'Intel'
        ELSE NULL
    END
    )), '') AS brand,
    COALESCE(
        a.brand_id_std,
        am.brand_id_std,
        af.brand_id_std,
        adk.brand_id_std,
        aic.brand_id_std,
        aicb.brand_id_std,
        aim.brand_id_std,
        ap.brand_id_std,
        ic.brandid,
        icb.brandid
    ) AS brandid,
    c.l1_code,
    c.l2_code,
    c.l3_code,
    MAX(CASE WHEN v.std_attr_code = 'manufacturer' THEN v.value_std_varchar END) AS `manufacturer`,
    MAX(CASE WHEN v.std_attr_code = 'rohs_compliant' THEN v.value_std_varchar END) AS `rohs_compliant`,
    MAX(CASE WHEN v.std_attr_code = 'lifecycle_status' THEN v.value_std_varchar END) AS `lifecycle_status`,
    MAX(CASE WHEN v.std_attr_code = 'reach' THEN v.value_std_varchar END) AS `reach`,
    MAX(CASE WHEN v.std_attr_code = 'eccn_code' THEN v.value_std_varchar END) AS `eccn_code`,
    MAX(CASE WHEN v.std_attr_code = 'aec_q_level' THEN v.value_std_varchar END) AS `aec_q_level`,
    MAX(CASE WHEN v.std_attr_code = 'lead_free' THEN v.value_std_varchar END) AS `lead_free`,
    MAX(CASE WHEN v.std_attr_code = 'msl_level' THEN v.value_std_varchar END) AS `msl_level`,
    MAX(CASE WHEN v.std_attr_code = 'package_case' THEN v.value_std_varchar END) AS `package_case`,
    MAX(CASE WHEN v.std_attr_code = 'temp_min_c' THEN v.value_std_double END) AS `temp_min_c`,
    MAX(CASE WHEN v.std_attr_code = 'temp_max_c' THEN v.value_std_double END) AS `temp_max_c`,
    MAX(CASE WHEN v.std_attr_code = 'pkg_length_mm' THEN v.value_std_double END) AS `pkg_length_mm`,
    MAX(CASE WHEN v.std_attr_code = 'pkg_width_mm' THEN v.value_std_double END) AS `pkg_width_mm`,
    MAX(CASE WHEN v.std_attr_code = 'pkg_height_mm' THEN v.value_std_double END) AS `pkg_height_mm`,
    MAX(CASE WHEN v.std_attr_code = 'max_speed_mbps' THEN v.value_std_double END) AS `max_speed_mbps`,
    MAX(CASE WHEN v.std_attr_code = 'port_count' THEN v.value_std_double END) AS `port_count`,
    MAX(CASE WHEN v.std_attr_code = 'host_interface_type' THEN v.value_std_varchar END) AS `host_interface_type`,
    MAX(CASE WHEN v.std_attr_code = 'supply_voltage_v' THEN v.value_std_double END) AS `supply_voltage_v`,
    MAX(CASE WHEN v.std_attr_code = 'supply_voltage_range_v' THEN v.value_std_varchar END) AS `supply_voltage_range_v`,
    PARSE_JSON(MAX(x.ext_attributes_str)) AS ext_attributes,
    NULL AS semantic_tags,
    NULL AS dq_score,
    NULL AS dq_flags,
    c.id AS source_id,
    CURRENT_TIMESTAMP() AS create_at,
    CURRENT_TIMESTAMP() AS update_at
FROM dwd.dwd_component_class c
JOIN dwd.dwd_icpdf_component_param p ON p.id = c.id AND c.data_source = 'icpdf'
LEFT JOIN dim.v_std_brand_alias a ON a.brand_key = UPPER(TRIM(p.brandshort))
LEFT JOIN dim.v_std_brand_alias am
       ON am.brand_key = UPPER(TRIM(substr(TRIM(split_part(
        COALESCE(
            NULLIF(TRIM(get_json_string(p.prajson, '$.\"制造商\"')), ''),
            NULLIF(TRIM(get_json_string(p.prajson, '$.\"Manufacturer\"')), '')
        ), ' (', 1)), 1, 128)))
LEFT JOIN dim.v_std_brand_alias af
       ON af.brand_key = UPPER(TRIM(SPLIT_PART(p.brandshort, ' ', 1)))
LEFT JOIN dim.v_std_brand_alias adk
       ON adk.brand_key = CASE UPPER(TRIM(p.brandshort))
        WHEN 'AQUANTIA CORP' THEN 'MARVELL'
        WHEN 'LANTIQ' THEN 'INTEL'
        WHEN 'BRIDGETEK PTE LTD.' THEN 'FTDI'
        WHEN 'GENNUM' THEN 'MICROSEMI'
        ELSE NULL
    END
LEFT JOIN dwd.dwd_component_attr_std v
       ON v.id = c.id AND v.data_source = c.data_source
LEFT JOIN mfr_agg m ON m.id = c.id AND m.data_source = c.data_source
LEFT JOIN dim.v_std_brand_alias aim
       ON aim.brand_key = UPPER(TRIM(m.mfr_name))
LEFT JOIN ic_brand ic
       ON ic.partno_key = UPPER(TRIM(SPLIT_PART(p.partno, ',', 1)))
LEFT JOIN ic_brand_base icb
       ON icb.base_key = UPPER(REGEXP_REPLACE(p.partno, '[^A-Za-z0-9].*$', ''))
LEFT JOIN dim.v_std_brand_alias aic
       ON aic.brand_key = UPPER(TRIM(ic.brandshort))
LEFT JOIN dim.v_std_brand_alias aicb
       ON aicb.brand_key = UPPER(TRIM(icb.brandshort))
LEFT JOIN dim.v_std_brand_alias ap
       ON ap.brand_key = UPPER(TRIM(CASE
        WHEN UPPER(p.partno) REGEXP '^(XR1[678]|XR8|XR68|XR19|ST16)' THEN 'EXAR'
        WHEN UPPER(p.partno) REGEXP '^(SC16|SC28|SCC2|SC26)' THEN 'NXP'
        WHEN UPPER(p.partno) REGEXP '^HD63' THEN 'HITACHI'
        WHEN UPPER(p.partno) REGEXP '^(COM2|COM80)' THEN 'SMSC'
        WHEN UPPER(p.partno) REGEXP '^MAX9' THEN 'MAXIM'
        WHEN UPPER(p.partno) REGEXP '^MAX310' THEN 'MAXIM'
        WHEN UPPER(p.partno) REGEXP '^DS90' THEN 'TI'
        WHEN UPPER(p.partno) REGEXP '^(TL16|SN65)' THEN 'TI'
        WHEN UPPER(p.partno) REGEXP '^(ISL83|ISL76|IS82)' THEN 'INTERSIL'
        WHEN UPPER(p.partno) REGEXP '^PC165' THEN 'NXP'
        WHEN UPPER(p.partno) REGEXP '^(N8251|P8251|8251)' THEN 'Intel'
        WHEN UPPER(p.partno) REGEXP '^(AY-3|AY-5|AY-6)' THEN 'MICROCHIP'
        WHEN UPPER(p.partno) REGEXP '^(CDP18|CDP65|CP185)' THEN 'RENESAS'
        WHEN UPPER(p.partno) REGEXP '^ST78' THEN 'STMICROELECTRONICS'
        WHEN UPPER(p.partno) REGEXP '^HD[13]-6402' THEN 'RENESAS'
        WHEN UPPER(p.partno) REGEXP '^TN825' THEN 'Intel'
        ELSE NULL
    END))
LEFT JOIN ext x ON x.id = c.id AND x.data_source = c.data_source
WHERE c.l1_code = 'interface_communication_ic'
      AND c.l2_code = 'ethernet_interface'
  AND c.data_source = 'icpdf'
  AND c.l3_code NOT LIKE '%_unclassified'
GROUP BY
    c.data_source, c.id,
    c.l1_code, c.l2_code, c.l3_code,
    p.partno, p.brandshort,
    substr(TRIM(split_part(
        COALESCE(
            NULLIF(TRIM(get_json_string(p.prajson, '$.\"制造商\"')), ''),
            NULLIF(TRIM(get_json_string(p.prajson, '$.\"Manufacturer\"')), '')
        ), ' (', 1)), 1, 128),
    a.canonical_name, a.brand_id_std,
    am.canonical_name, am.brand_id_std,
    af.canonical_name, af.brand_id_std,
    adk.canonical_name, adk.brand_id_std,
    aim.canonical_name, aim.brand_id_std,
    aic.canonical_name, aic.brand_id_std,
    aicb.canonical_name, aicb.brand_id_std,
    ap.canonical_name, ap.brand_id_std,
    m.mfr_name,
    ic.brandshort, ic.brandid,
    icb.brandshort, icb.brandid;;

SELECT 'ethernet_interface' AS l2_code, data_source, COUNT(*) AS rows_total
FROM dwd.dwd_l2_interface_communication_ic_ethernet_interface
GROUP BY data_source ORDER BY data_source;
