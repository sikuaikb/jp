/* ============================================================
 * PDF 抽取 ODS → dwd.dwd_pdf_extract_component_param 增量灌入（主键 upsert）
 *
 * 数据源：ods.ods_pdf_extract_component_param
 *
 * 策略：
 *   1) param 缺失的 partno，或 param 已有但 prajson IS NULL（ODS 修正后重刷）
 *   2) 同 partno 多行：ODS 已按 (id, partno) 主键去重；若仍有重复，优选 prajson 非空、
 *      row_bucket='confident'（prajson.__extract__.row_bucket）、minio_file_path 非空者
 *   3) 透传模式：prajson 原样灌入，不做 JSON 拼装（与得捷 upsert 的核心差异）
 *
 * 执行：mysql … < sql_scripts/foundation/upsert_pdf_extract_component_param_from_ods.sql
 * ============================================================ */

INSERT INTO dwd.dwd_pdf_extract_component_param
(
    id, partno, brandid, brandshort,
    category, category2, category_info, taginfo, note, note_cn,
    prajson, prajson2, image, datasheet_url,
    data_source, source_product_url, create_at, update_at,
    version, minio_bucket, minio_file_path
)
WITH ods_new AS (
    SELECT r.*
    FROM ods.ods_pdf_extract_component_param r
    LEFT JOIN dwd.dwd_pdf_extract_component_param p
        ON p.id = r.id
       AND p.partno = r.partno
    WHERE r.partno IS NOT NULL
      AND TRIM(r.partno) <> ''
      AND r.prajson IS NOT NULL
      AND (p.id IS NULL OR p.prajson IS NULL)
),
ods_pick AS (
    SELECT *
    FROM (
        SELECT
            o.*,
            ROW_NUMBER() OVER (
                PARTITION BY o.partno
                ORDER BY
                    /* prajson 非空优先（已在 WHERE 保证，这里防御性） */
                    CASE WHEN o.prajson IS NOT NULL THEN 0 ELSE 1 END,
                    /* 抽取置信度高优先：row_bucket='confident' 排前 */
                    CASE WHEN get_json_string(o.prajson, '$.__extract__.row_bucket') = '"confident"' THEN 0
                         ELSE 1 END,
                    /* 有 PDF 路径优先（溯源完整） */
                    CASE WHEN o.minio_file_path IS NOT NULL AND o.minio_file_path <> '' THEN 0
                         ELSE 1 END,
                    o.id ASC
            ) AS rn
        FROM ods_new o
    ) t
    WHERE rn = 1
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
FROM ods_pick r;

/* ---------- 验收 ---------- */
SELECT 'param_total' AS what, COUNT(*) AS n FROM dwd.dwd_pdf_extract_component_param
UNION ALL
SELECT 'still_missing', COUNT(*)
FROM ods.ods_pdf_extract_component_param r
LEFT JOIN dwd.dwd_pdf_extract_component_param p
  ON p.id = r.id AND p.partno = r.partno
WHERE r.partno IS NOT NULL AND TRIM(r.partno) <> '' AND r.prajson IS NOT NULL AND p.id IS NULL
UNION ALL
SELECT 'still_prajson_null', COUNT(*)
FROM ods.ods_pdf_extract_component_param r
JOIN dwd.dwd_pdf_extract_component_param p
  ON p.id = r.id AND p.partno = r.partno
WHERE r.prajson IS NOT NULL AND p.prajson IS NULL
UNION ALL
SELECT 'has_minio_path', COUNT(*) FROM dwd.dwd_pdf_extract_component_param
WHERE minio_file_path IS NOT NULL AND minio_file_path <> ''
UNION ALL
SELECT 'distinct_partno', COUNT(DISTINCT partno) FROM dwd.dwd_pdf_extract_component_param;
