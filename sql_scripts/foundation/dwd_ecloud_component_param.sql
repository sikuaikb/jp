/* ============================================================
 * 元器件云（ecloud）ODS → dwd.dwd_ecloud_component_param 全量适配层
 *
 * 数据源：ods.ods_jp_component_detail（元器件云平台组件明细，约 355 万行）
 *
 * 定位：与 dwd.dwd_icpdf_component_param / dwd.dwd_digikey_component_param /
 *      dwd.dwd_pdf_extract_component_param 平行的第四源 param 适配层。
 *      下游 classify/EAV/L2 用 data_source='ecloud' 隔离。
 *
 * 字段策略：
 *   id              = CAST(ods.id AS BIGINT)
 *                     （源端雪花ID，纯数字，max 1.84e18 < 2^63-1，安全；与 icpdf/pcb 同模式：沿用源端 id）
 *   partno          = ods.name（型号，99.3% 唯一）
 *   brandid         = ods_jp_brand.id（BIGINT，JOIN brand_name 回填；源端 brand_id 是字符串，统一用字典 id）
 *   brandshort      = ods.brand_name（截断 128）
 *   category        = ods_jp_category c1.title（一级分类中文，如"电阻"；共 19 个一级类）
 *   category2       = ods_jp_category c2.title（二级分类中文，如"MOSFET"）
 *   category_info   = ARRAY[c1.title, c2.title]（构造路径数组，兼容下游 category_info_overlap 规则）
 *   taginfo         = NULL（元器件云无独立标签字段，保留兼容下游 SQL）
 *   note            = NULL（无英文备注）
 *   note_cn         = SUBSTRING(ods.description, 1, 2048)
 *   prajson         = parse_json(get_json_string(ods.extended_attributes, '$.dimensions'))
 *                     （平铺中文 KV，如 {"漏源电压Vdss(V)":"60V","FET类型":"N 通道",...}；中英双 key 对照）
 *   prajson2        = NULL（元器件云无 prajson2 形态）
 *   image           = ods.picture
 *   datasheet_url   = get_json_string(ods.data_sheet, '$[0]')（data_sheet 是 JSON 数组字符串，取首元素）
 *   data_source     = 'ecloud'
 *
 * 与 icpdf/digikey 的关键差异（决定下游规则写法）：
 *   - category/category2 是中文分类名（非 prod L1 code），gate 规则需做「中文一级类 → prod L1」映射
 *   - prajson 是平铺中文 KV（key 是中文参数名），attr extract_rule 需做「中文 key → std_attr_code」映射
 *   - id 是源端雪花ID CAST BIGINT（非 hash(partno)），同 partno 跨源 id 不同，靠 data_source 隔离
 *   - 与 icpdf/digikey partno 重叠 27-32%（元器件云是聚合源，dimensions 内甚至混有 "data_source":"digikey"），
 *     下游 L2 宽表会出现同 partno 多 data_source 行——符合多源设计预期
 *
 * 下游：
 *   - classify：data_source='ecloud' 走主干 dwd_component_class.sql 的 param_all UNION，
 *     gate 规则用 category_in 中文白名单映射 prod L1（gate_<l1>_ecloud_v1）
 *   - attr_std：新建 build_dwd_component_attr_std_ecloud.sql，
 *     source_kind='ecloud_dim_kv_eq'（中文 key 精确匹配抽 std_attr_code）
 *
 * 执行：mysql … < sql_scripts/foundation/dwd_ecloud_component_param.sql
 * ============================================================ */

CREATE TABLE IF NOT EXISTS dwd.dwd_ecloud_component_param (
    `id`                  BIGINT               NOT NULL COMMENT '源端雪花ID CAST BIGINT（max 1.84e18 < 2^63-1）',
    `partno`              VARCHAR(256)         NOT NULL COMMENT '型号 = ods.name',
    `brandid`             BIGINT               NULL COMMENT '品牌ID（JOIN ods_jp_brand.id 回填）',
    `brandshort`          VARCHAR(128)         NULL COMMENT '品牌名称 = ods.brand_name（截断 128）',
    `category`            VARCHAR(256)         NULL COMMENT '一级分类中文（如电阻；共 19 个一级类）',
    `category2`           VARCHAR(256)         NULL COMMENT '二级分类中文（如 MOSFET）',
    `category_info`       ARRAY<VARCHAR(256)>  NULL COMMENT '[一级分类, 二级分类] 路径数组',
    `taginfo`             ARRAY<VARCHAR(256)>  NULL COMMENT '保留 NULL（元器件云无独立标签字段）',
    `note`                VARCHAR(2048)        NULL COMMENT '保留 NULL（无英文备注）',
    `note_cn`             VARCHAR(2048)        NULL COMMENT '中文描述 = ods.description（截断 2048）',
    `prajson`             JSON                 NULL COMMENT '平铺中文 KV 参数（extended_attributes.dimensions）',
    `prajson2`            JSON                 NULL COMMENT '保留 NULL（元器件云无 prajson2 形态）',
    `image`               VARCHAR(1024)        NULL COMMENT '图片 URL = ods.picture',
    `datasheet_url`       VARCHAR(1024)        NULL COMMENT '规格书 URL（data_sheet JSON 数组首元素）',
    `data_source`         VARCHAR(32)          NOT NULL DEFAULT 'ecloud',
    `source_product_url`  VARCHAR(1024)        NULL COMMENT '保留 NULL',
    `create_at`           DATETIME             NULL DEFAULT CURRENT_TIMESTAMP,
    `update_at`           DATETIME             NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=OLAP
PRIMARY KEY(`id`)
COMMENT '元器件云（ecloud）全量 param 适配层（约 355 万行；prajson 为平铺中文 KV；id=源端雪花ID CAST BIGINT 唯一）'
DISTRIBUTED BY HASH(`id`) BUCKETS 32
PROPERTIES (
    "compression"             = "ZSTD",
    "replication_num"         = "1",
    "enable_persistent_index" = "true"
);


INSERT INTO dwd.dwd_ecloud_component_param
(
    id, partno, brandid, brandshort,
    category, category2, category_info, taginfo, note, note_cn,
    prajson, prajson2, image, datasheet_url,
    data_source, source_product_url, create_at, update_at
)
SELECT
    CAST(c.id AS BIGINT)                                                  AS id,
    c.name                                                                AS partno,
    b.id                                                                  AS brandid,
    SUBSTR(COALESCE(c.brand_name, ''), 1, 128)                            AS brandshort,
    c1.title                                                               AS category,
    c2.title                                                               AS category2,
    CASE WHEN c1.title IS NOT NULL
         THEN array_remove(split(concat(c1.title, '|', COALESCE(c2.title, '')), '|'), '')
         ELSE NULL
    END                                                                    AS category_info,
    NULL                                                                    AS taginfo,
    CAST(NULL AS VARCHAR(2048))                                            AS note,
    SUBSTRING(COALESCE(c.description, ''), 1, 2048)                        AS note_cn,
    parse_json(NULLIF(get_json_string(c.extended_attributes, '$.dimensions'), ''))  AS prajson,
    CAST(NULL AS JSON)                                                     AS prajson2,
    c.picture                                                              AS image,
    NULLIF(
        COALESCE(
            get_json_string(CAST(NULLIF(TRIM(c.data_sheet), '') AS JSON), '$[0]'),
            get_json_string(CAST(NULLIF(TRIM(c.data_sheet), '') AS JSON), '$[1]')
        ),
        ''
    )                                                                      AS datasheet_url,
    'ecloud'                                                      AS data_source,
    CAST(NULL AS VARCHAR(1024))                                            AS source_product_url,
    CURRENT_TIMESTAMP()                                                    AS create_at,
    CURRENT_TIMESTAMP()                                                    AS update_at
FROM ods.ods_jp_component_detail c
LEFT JOIN ods.ods_jp_category c2 ON CAST(c2.id AS CHAR) = c.cat_id
LEFT JOIN ods.ods_jp_category c1 ON c1.id = c2.pid
LEFT JOIN ods.ods_jp_brand    b  ON b.name = c.brand_name
WHERE c.name IS NOT NULL
  AND TRIM(c.name) <> '';


/* ---------- 校验 ----------
 * 注：本表 32 桶，GROUP BY 在分布式聚合时可能出现「同值分裂多行」的统计噪音
 *    （与 dwd_ecloud_component_detail 16 桶同现象；等值匹配 / array_contains / JOIN 不受影响）。
 *    如需精确分类计数，用 COUNT(DISTINCT category) 或子查询去重后再聚合。
 */
SELECT 'total' AS what, COUNT(*) AS rows_ FROM dwd.dwd_ecloud_component_param
UNION ALL SELECT 'has_brand',        COUNT(*) FROM dwd.dwd_ecloud_component_param WHERE brandshort IS NOT NULL AND brandshort <> ''
UNION ALL SELECT 'has_category',     COUNT(*) FROM dwd.dwd_ecloud_component_param WHERE category IS NOT NULL AND category <> ''
UNION ALL SELECT 'has_category2',    COUNT(*) FROM dwd.dwd_ecloud_component_param WHERE category2 IS NOT NULL AND category2 <> ''
UNION ALL SELECT 'has_prajson',      COUNT(*) FROM dwd.dwd_ecloud_component_param WHERE prajson IS NOT NULL
UNION ALL SELECT 'has_datasheet',    COUNT(*) FROM dwd.dwd_ecloud_component_param WHERE datasheet_url IS NOT NULL AND datasheet_url <> ''
UNION ALL SELECT 'has_image',        COUNT(*) FROM dwd.dwd_ecloud_component_param WHERE image IS NOT NULL AND image <> ''
UNION ALL SELECT 'distinct_partno',  COUNT(DISTINCT partno) FROM dwd.dwd_ecloud_component_param
UNION ALL SELECT 'distinct_category',COUNT(DISTINCT category) FROM dwd.dwd_ecloud_component_param WHERE category IS NOT NULL;

/* 品类分布（19 个一级类；若 GROUP BY 分裂，用 COUNT(DISTINCT category) 看真实类别数） */
SELECT category, COUNT(*) AS cnt
FROM dwd.dwd_ecloud_component_param
WHERE category IS NOT NULL
GROUP BY category
ORDER BY cnt DESC;

/* 与现有源 partno 重叠（聚合源特性；重叠行靠 data_source 隔离，不冲突） */
SELECT 'cc∩icpdf'   AS what, COUNT(*) AS n
FROM dwd.dwd_ecloud_component_param cc
INNER JOIN dwd.dwd_icpdf_component_param   i ON i.partno = cc.partno
UNION ALL SELECT 'cc∩digikey', COUNT(*)
FROM dwd.dwd_ecloud_component_param cc
INNER JOIN dwd.dwd_digikey_component_param  d ON d.partno = cc.partno
UNION ALL SELECT 'cc∩pcb', COUNT(*)
FROM dwd.dwd_ecloud_component_param cc
INNER JOIN dwd.dwd_pdf_extract_component_param p ON p.partno = cc.partno;
