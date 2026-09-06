/* ============================================================
 * 得捷激光类目 prajson 技术字段回填（ODS → dwd.dwd_digikey_component_param）
 *
 * 背景：「光纤发射器 - 驱动器集成电路」86 件在 dwd 层 prajson 仅含 category 占位，
 *       根因是 ODS 未爬取 specs_json / product_info；非分类规则问题。
 *
 * 语义：得捷单源下技术键落在 prajson（引擎内别名为 prajson2）；物理 prajson2 列恒 NULL。
 *
 * 权限：需要 ods.ods_digikey_component_detail SELECT + dwd.dwd_digikey_component_param INSERT
 * 执行：mysql ... < sql_scripts/foundation/patch_digikey_laser_prajson_from_ods.sql
 *
 * 前置：ODS 侧重爬/补采 laser 类目 product 页后，specs_json 非空再跑本脚本。
 * ============================================================ */

INSERT INTO dwd.dwd_digikey_component_param
(
    id, partno, brandid, brandshort,
    category, category2, category_info, taginfo, note, note_cn,
    prajson, prajson2, image, datasheet_url,
    data_source, source_product_url, create_at, update_at
)
SELECT
    xx_hash3_64(r.mfr_part_no)                                            AS id,
    r.mfr_part_no                                                         AS partno,
    NULL                                                                  AS brandid,
    substr(TRIM(split_part(
        get_json_string(r.product_info, '$.制造商'),
        ' (', 1
    )), 1, 128)                                                           AS brandshort,
    r.category                                                            AS category,
    NULL                                                                  AS category2,
    split(r.category_path, ' > ')                                         AS category_info,
    NULL                                                                  AS taginfo,
    COALESCE(
        get_json_string(r.product_info, '$.描述'),
        get_json_string(r.product_info, '$.Description')
    )                                                                     AS note,
    COALESCE(
        get_json_string(r.product_info, '$.详细描述'),
        get_json_string(r.product_info, '$.Detailed Description')
    )                                                                     AS note_cn,
    parse_json(
      regexp_replace(
        regexp_replace(
          regexp_replace(
            concat('{',
              CASE WHEN r.specs_json IS NOT NULL AND r.specs_json <> '' AND r.specs_json <> '{}'
                   THEN concat(substr(r.specs_json, 2, char_length(r.specs_json) - 2), ',') ELSE '' END,
              CASE WHEN r.compliance_json IS NOT NULL AND r.compliance_json <> '' AND r.compliance_json <> '{}'
                   THEN concat(substr(r.compliance_json, 2, char_length(r.compliance_json) - 2), ',') ELSE '' END,
              CASE WHEN r.product_info IS NOT NULL AND r.product_info <> '' AND r.product_info <> '{}'
                   THEN concat(
                       regexp_replace(
                         substr(r.product_info, 2, char_length(r.product_info) - 2),
                         '"(制造商|规格书)"\\s*:\\s*"[^"]*"\\s*,?\\s*', ''
                       ),
                       ',')
                   ELSE '' END,
              CASE WHEN r.aliases_json IS NOT NULL AND r.aliases_json <> '' AND r.aliases_json <> '{}'
                   THEN concat(substr(r.aliases_json, 2, char_length(r.aliases_json) - 2), ',') ELSE '' END,
              CASE WHEN r.documents_json IS NOT NULL AND r.documents_json <> '' AND r.documents_json <> '{}'
                   THEN concat(
                       regexp_replace(
                         substr(r.documents_json, 2, char_length(r.documents_json) - 2),
                         '"规格书"\\s*:\\s*"[^"]*"\\s*,?\\s*', ''
                       ),
                       ',')
                   ELSE '' END,
              CASE WHEN r.pricing_json IS NOT NULL AND r.pricing_json <> '' AND r.pricing_json <> '{}'
                   THEN concat(substr(r.pricing_json, 2, char_length(r.pricing_json) - 2), ',') ELSE '' END,
              '"category": "',      replace(COALESCE(r.category, ''), '"', '\\"'),      '",',
              '"category_path": "', replace(COALESCE(r.category_path, ''), '"', '\\"'), '"',
            '}'),
            ' \\(https://[^)]+\\)', ''
          ),
          ',\\s*,', ','
        ),
        ',\\s*}', '}'
      )
    )                                                                     AS prajson,
    NULL                                                                  AS prajson2,
    substr(get_json_string(parse_json(r.images_json), '$[0]'), 1, 1024)   AS image,
    substr(COALESCE(
        regexp_extract(get_json_string(r.documents_json, '$.规格书'), '(https?://[^\\s)]+)', 1),
        regexp_extract(get_json_string(r.product_info,   '$.规格书'), '(https?://[^\\s)]+)', 1)
    ), 1, 1024)                                                           AS datasheet_url,
    'digikey'                                                             AS data_source,
    r.product_url                                                         AS source_product_url,
    COALESCE(r.crawled_at, CURRENT_TIMESTAMP())                           AS create_at,
    CURRENT_TIMESTAMP()                                                   AS update_at
FROM ods.ods_digikey_component_detail r
WHERE r.mfr_part_no IS NOT NULL
  AND r.mfr_part_no <> ''
  AND r.category = '光纤发射器 - 驱动器集成电路';

/* ---------- 验收（激光类目应有技术 prajson 键） ---------- */
SELECT 'laser_total' AS what, COUNT(*) AS n
FROM dwd.dwd_digikey_component_param
WHERE category = '光纤发射器 - 驱动器集成电路'
UNION ALL
SELECT 'laser_stub_only', COUNT(*)
FROM dwd.dwd_digikey_component_param
WHERE category = '光纤发射器 - 驱动器集成电路'
  AND LENGTH(CAST(prajson AS VARCHAR)) <= 140
UNION ALL
SELECT 'laser_has_mfr_key', COUNT(*)
FROM dwd.dwd_digikey_component_param
WHERE category = '光纤发射器 - 驱动器集成电路'
  AND get_json_string(prajson, '$.制造商') IS NOT NULL
  AND TRIM(get_json_string(prajson, '$.制造商')) <> ''
UNION ALL
SELECT 'laser_has_desc_key', COUNT(*)
FROM dwd.dwd_digikey_component_param
WHERE category = '光纤发射器 - 驱动器集成电路'
  AND get_json_string(prajson, '$.详细描述') IS NOT NULL
  AND TRIM(get_json_string(prajson, '$.详细描述')) <> '';
