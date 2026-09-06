/* ============================================================
 * DigiKey 全量 ODS 适配层（test 环境）
 *
 * 目标：把 ods.ods_digikey_component_detail 中**所有**数据（全 L1，约 7.7M 行）
 *      重整为下游 1.classify / 2.attribute_standard SQL 可复用的中间表。
 *      下游按 L1 范围分别试点（resistor / capacitor / ... 分管道）。
 *
 * 字段策略：
 *   id              = xx_hash3_64(mfr_part_no)
 *   partno          = mfr_part_no
 *   brandshort      = COALESCE(product_info."制造商", product_info."Manufacturer")（去 URL 后缀；超长截断 128）
 *   brandid         = NULL（DigiKey 无原始品牌 ID）
 *   category        = ods.category（叶子分类）
 *   category_info   = split(category_path, ' > ')（多层路径数组）
 *   note_cn         = product_info."详细描述"
 *   prajson         = 合并 specs+compliance+product_info+aliases+documents+pricing
 *                     + 顶层 category/category_path 到一个 JSON 对象
 *                     —— value 中的 " (https://...)" URL 后缀已清掉
 *   image           = images_json[0]（首张图 URL）
 *   datasheet_url   = documents_json.规格书 → 提取 URL；fallback 到 product_info.规格书
 *
 * 已删除：category2 / prajson2 / taginfo（按需求不保留）
 *
 * value 中文枚举 → 英文标准（在 normalize_digikey_l2_values.sql 中对 L2 表 UPDATE）
 *
 * 表名：dwd.dwd_digikey_component_param（test 环境）
 *       验证通过后可考虑去 test_ 前缀直接合并到 dwd.* 主库。
 *
 * 执行：mysql ... < sql_scripts/test/digikey_resistor/build_dwd_digikey_resistor_param.sql
 * ============================================================ */

DROP TABLE IF EXISTS dwd.dwd_digikey_component_param;

CREATE TABLE dwd.dwd_digikey_component_param (
    `id`                  BIGINT               NOT NULL COMMENT 'xx_hash3_64(mfr_part_no)',
    `partno`              VARCHAR(256)         NOT NULL COMMENT '制造商料号 = ods.mfr_part_no',
    `brandid`             BIGINT               NULL COMMENT 'DigiKey 无原始品牌 ID',
    `brandshort`          VARCHAR(128)         NULL COMMENT 'product_info.制造商（去 URL 后缀）',
    `category`            VARCHAR(256)         NULL COMMENT 'DigiKey 叶子分类',
    `category2`           VARCHAR(256)         NULL COMMENT '保留 NULL：DigiKey 无 IHS 双层分类体系（保留字段以兼容下游 SQL）',
    `category_info`       ARRAY<VARCHAR(256)>  NULL COMMENT 'split(category_path, '' > '') 数组',
    `taginfo`             ARRAY<VARCHAR(256)>  NULL COMMENT '保留 NULL：DigiKey 无独立标签字段（保留字段以兼容下游 SQL）',
    `note`                VARCHAR(2048)        NULL COMMENT 'product_info.描述（简短，多为英文）',
    `note_cn`             VARCHAR(2048)        NULL COMMENT 'product_info.详细描述（中文长文）',
    `prajson`             JSON                 NULL COMMENT '合并 specs+compliance+product_info+aliases+documents+pricing+顶层 category（URL 已清洗）',
    `prajson2`            JSON                 NULL COMMENT '保留 NULL：DigiKey prajson 已装顶层 key 对象（保留字段以兼容下游 SQL）',
    `image`               VARCHAR(1024)        NULL COMMENT 'images_json[0]',
    `datasheet_url`       VARCHAR(1024)        NULL COMMENT '规格书 PDF URL（先 documents_json.规格书；fallback product_info.规格书）',
    `data_source`         VARCHAR(32)          NOT NULL DEFAULT 'digikey',
    `source_product_url`  VARCHAR(1024)        NULL COMMENT 'DigiKey 原始 product_url（溯源）',
    `create_at`           DATETIME             NULL DEFAULT CURRENT_TIMESTAMP,
    `update_at`           DATETIME             NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=OLAP
PRIMARY KEY(`id`, `partno`)
COMMENT 'DigiKey 全量适配层（所有 L1，约 7.7M；所有 JSON 数据合并到 prajson）'
DISTRIBUTED BY HASH(`id`) BUCKETS 32
PROPERTIES (
    "compression"             = "ZSTD",
    "replication_num"         = "1",
    "enable_persistent_index" = "true"
);

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
    /* brand: 取制造商（中/英 key），去 URL 后缀，最多 128 字符 */
    substr(TRIM(split_part(
        COALESCE(
            NULLIF(TRIM(get_json_string(r.product_info, '$.制造商')), ''),
            NULLIF(TRIM(get_json_string(r.product_info, '$.Manufacturer')), '')
        ),
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
    /* prajson: 合并 specs+compliance+product_info+aliases+documents+pricing+顶层 category。
     *
     * 去重策略（specs 优先，product_info/documents 冲突 key 删除）：
     *   - product_info 移除 "制造商"（specs.制造商 优先）和 "规格书"（已抽到 datasheet_url 字段）
     *   - documents_json 移除 "规格书"（已抽到 datasheet_url 字段）
     *
     * 同时：
     *   - value 中的 " (https://...)" URL 后缀统一清掉（防止超长）
     *   - 空 JSON `{}` 不输出（避免拼接出 ',,' 导致 JSON 不合法）
     *   - 末尾 ",}" → "}"（中间段全空时的兜底清理）
     */
    parse_json(
      regexp_replace(
        regexp_replace(
          regexp_replace(
            concat('{',
              CASE WHEN r.specs_json IS NOT NULL AND r.specs_json <> '' AND r.specs_json <> '{}'
                   THEN concat(substr(r.specs_json, 2, char_length(r.specs_json) - 2), ',') ELSE '' END,
              CASE WHEN r.compliance_json IS NOT NULL AND r.compliance_json <> '' AND r.compliance_json <> '{}'
                   THEN concat(substr(r.compliance_json, 2, char_length(r.compliance_json) - 2), ',') ELSE '' END,
              /* product_info：先删冲突 key("制造商"/"规格书"），再合入 */
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
              /* documents_json：删 "规格书"（已抽 datasheet_url），其余合入 */
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
            ' \\(https://[^)]+\\)', ''   /* 清掉 value 中 URL 后缀 */
          ),
          ',\\s*,', ','                  /* 兜底：去掉冲突 key 删除后可能残留的 ,, */
        ),
        ',\\s*}', '}'                    /* 兜底：去掉 ,} */
      )
    )                                                                     AS prajson,
    NULL                                                                  AS prajson2,
    /* image: images_json[0] —— 取首张图 URL */
    substr(get_json_string(parse_json(r.images_json), '$[0]'), 1, 1024)   AS image,
    /* datasheet_url: documents_json.规格书 提取括号内 URL；fallback product_info.规格书 */
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
  AND r.mfr_part_no <> '';


/* ---------- 校验 ---------- */
SELECT 'total' AS what, COUNT(*) AS rows_ FROM dwd.dwd_digikey_component_param
UNION ALL SELECT 'has_brand',         COUNT(*) FROM dwd.dwd_digikey_component_param WHERE brandshort IS NOT NULL AND brandshort <> ''
UNION ALL SELECT 'has_prajson',       COUNT(*) FROM dwd.dwd_digikey_component_param WHERE prajson IS NOT NULL
UNION ALL SELECT 'has_image',         COUNT(*) FROM dwd.dwd_digikey_component_param WHERE image IS NOT NULL
UNION ALL SELECT 'has_datasheet_url', COUNT(*) FROM dwd.dwd_digikey_component_param WHERE datasheet_url IS NOT NULL
UNION ALL SELECT 'has_note',          COUNT(*) FROM dwd.dwd_digikey_component_param WHERE note IS NOT NULL
UNION ALL SELECT 'has_note_cn',       COUNT(*) FROM dwd.dwd_digikey_component_param WHERE note_cn IS NOT NULL
UNION ALL SELECT 'has_category_info', COUNT(*) FROM dwd.dwd_digikey_component_param WHERE category_info IS NOT NULL AND array_length(category_info) > 0;

/* 样例 */
SELECT id, partno, brandshort, category, note, image, datasheet_url
FROM dwd.dwd_digikey_component_param
WHERE partno IN ('TPR8600-EV1R','1-2176349-7')
LIMIT 5;
