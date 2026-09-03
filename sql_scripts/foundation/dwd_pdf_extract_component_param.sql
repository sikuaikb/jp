/* ============================================================
 * PDF 抽取 ODS → dwd.dwd_pdf_extract_component_param 全量适配层
 *
 * 数据源：ods.ods_pdf_extract_component_param
 *
 * 定位：与 dwd.dwd_digikey_component_param 平行的多源 param 适配层。
 *      ODS 表字段已与 DWD param 对齐（id/partno/category/prajson/…），
 *      且 prajson 已是结构化抽取结果（{__extract__, category, records[], specs{}}），
 *      故本脚本采用 **透传** 模式，不做得捷那套 specs_json/product_info JSON 拼装。
 *
 * 与得捷 param 的关键差异：
 *   - data_source = 'pcb_attr_extract_pipe'（非 'digikey'），下游用 data_source 隔离
 *   - prajson 是 PDF 抽取结构化结果，prajson2 恒 NULL
 *   - 额外保留溯源列：version / minio_bucket / minio_file_path（回追原始 PDF）
 *   - category 已是 L1 code（如 mpu/resistor），category_info 已是 [L1,L2,L3] 路径
 *
 * 字段策略（透传，仅做防御性清洗）：
 *   id              = ods.id（= xx_hash3_64(partno)，与得捷 id 规则一致）
 *   partno          = ods.partno
 *   brandshort      = ods.brandshort（截断 128）
 *   category        = ods.category（L1 code）
 *   category_info   = ods.category_info（[L1,L2,L3] 数组）
 *   prajson         = ods.prajson（结构化抽取结果，原样透传）
 *   data_source     = 'pcb_attr_extract_pipe'（覆盖 ODS 默认 'digikey'）
 *
 * 下游：
 *   - classify：data_source='pcb_attr_extract_pipe' 单独 gate / 或用 category_info 短路
 *   - attr_std：从 prajson.specs 抽取（新建 extract rule，不复用得捷 prajson2_key_eq）
 *
 * 执行：mysql … < sql_scripts/foundation/dwd_pdf_extract_component_param.sql
 * ============================================================ */

DROP TABLE IF EXISTS dwd.dwd_pdf_extract_component_param;

CREATE TABLE dwd.dwd_pdf_extract_component_param (
    `id`                  BIGINT               NOT NULL COMMENT 'xx_hash3_64(partno)，与得捷 param id 规则一致',
    `partno`              VARCHAR(256)         NOT NULL COMMENT '制造商料号',
    `brandid`             BIGINT               NULL COMMENT '品牌 ID（当前 NULL，后续可回填）',
    `brandshort`          VARCHAR(128)         NULL COMMENT '品牌简称（来自抽取 specs.manufacturer）',
    `category`            VARCHAR(256)         NULL COMMENT 'L1 code（如 mpu/resistor）',
    `category2`           VARCHAR(256)         NULL COMMENT '保留字段以兼容下游 SQL（当前 NULL）',
    `category_info`       ARRAY<VARCHAR(256)>  NULL COMMENT '[L1,L2,L3] 分类路径数组',
    `taginfo`             ARRAY<VARCHAR(256)>  NULL COMMENT '保留字段以兼容下游 SQL（当前 NULL）',
    `note`                VARCHAR(2048)        NULL COMMENT '英文备注（当前多 NULL）',
    `note_cn`             VARCHAR(2048)        NULL COMMENT '中文备注（当前多 NULL）',
    `prajson`             JSON                 NULL COMMENT 'PDF 抽取结构化结果 {__extract__, category, records[], specs{}}',
    `prajson2`            JSON                 NULL COMMENT '保留字段以兼容下游 SQL（恒 NULL）',
    `image`               VARCHAR(1024)        NULL COMMENT '图片 URL（当前 NULL）',
    `datasheet_url`       VARCHAR(1024)        NULL COMMENT '规格书 URL（当前 NULL，用 minio_file_path 回追 PDF）',
    `data_source`         VARCHAR(32)          NOT NULL DEFAULT 'pcb_attr_extract_pipe',
    `source_product_url`  VARCHAR(1024)        NULL COMMENT '源产品页 URL（当前 NULL）',
    `create_at`           DATETIME             NULL DEFAULT CURRENT_TIMESTAMP,
    `update_at`           DATETIME             NULL DEFAULT CURRENT_TIMESTAMP,
    `version`             VARCHAR(100)         NULL COMMENT '抽取 schema 版本（溯源）',
    `minio_bucket`        VARCHAR(100)         NULL COMMENT '原始 PDF 所在 minio bucket（溯源）',
    `minio_file_path`     VARCHAR(255)         NULL COMMENT '原始 PDF 在 minio 中的路径（溯源）'
) ENGINE=OLAP
PRIMARY KEY(`id`, `partno`)
COMMENT 'PDF 抽取 param 适配层（pcb_attr_extract_pipe 源；prajson 为结构化抽取结果）'
DISTRIBUTED BY HASH(`id`) BUCKETS 32
PROPERTIES (
    "compression"             = "ZSTD",
    "replication_num"         = "1",
    "enable_persistent_index" = "true"
);

INSERT INTO dwd.dwd_pdf_extract_component_param
(
    id, partno, brandid, brandshort,
    category, category2, category_info, taginfo, note, note_cn,
    prajson, prajson2, image, datasheet_url,
    data_source, source_product_url, create_at, update_at,
    version, minio_bucket, minio_file_path
)
SELECT
    r.id                                                                AS id,
    r.partno                                                            AS partno,
    r.brandid                                                           AS brandid,
    substr(COALESCE(r.brandshort, ''), 1, 128)                          AS brandshort,
    r.category                                                          AS category,
    r.category2                                                         AS category2,
    r.category_info                                                     AS category_info,
    r.taginfo                                                           AS taginfo,
    r.note                                                              AS note,
    r.note_cn                                                           AS note_cn,
    r.prajson                                                           AS prajson,
    r.prajson2                                                          AS prajson2,
    r.image                                                             AS image,
    r.datasheet_url                                                     AS datasheet_url,
    'pcb_attr_extract_pipe'                                             AS data_source,
    r.source_product_url                                                AS source_product_url,
    COALESCE(r.create_at, CURRENT_TIMESTAMP())                          AS create_at,
    CURRENT_TIMESTAMP()                                                 AS update_at,
    r.version                                                           AS version,
    r.minio_bucket                                                      AS minio_bucket,
    r.minio_file_path                                                   AS minio_file_path
FROM ods.ods_pdf_extract_component_param r
WHERE r.partno IS NOT NULL
  AND TRIM(r.partno) <> ''
  AND r.prajson IS NOT NULL;


/* ---------- 校验 ---------- */
SELECT 'total' AS what, COUNT(*) AS rows_ FROM dwd.dwd_pdf_extract_component_param
UNION ALL SELECT 'has_brand',         COUNT(*) FROM dwd.dwd_pdf_extract_component_param WHERE brandshort IS NOT NULL AND brandshort <> ''
UNION ALL SELECT 'has_prajson',       COUNT(*) FROM dwd.dwd_pdf_extract_component_param WHERE prajson IS NOT NULL
UNION ALL SELECT 'has_category_info', COUNT(*) FROM dwd.dwd_pdf_extract_component_param WHERE category_info IS NOT NULL AND array_length(category_info) > 0
UNION ALL SELECT 'has_minio_path',    COUNT(*) FROM dwd.dwd_pdf_extract_component_param WHERE minio_file_path IS NOT NULL AND minio_file_path <> ''
UNION ALL SELECT 'distinct_partno',   COUNT(DISTINCT partno) FROM dwd.dwd_pdf_extract_component_param;

/* 品类分布 */
SELECT category, COUNT(*) AS cnt
FROM dwd.dwd_pdf_extract_component_param
GROUP BY category
ORDER BY cnt DESC;

/* 与得捷 param 的 partno 重叠核查（应为 0 或已知少量；重叠行用 data_source 隔离，不冲突） */
SELECT 'overlap_with_digikey' AS what, COUNT(*) AS n
FROM dwd.dwd_pdf_extract_component_param p
INNER JOIN dwd.dwd_digikey_component_param dk ON dk.partno = p.partno;
