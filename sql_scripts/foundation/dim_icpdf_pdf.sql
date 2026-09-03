/* ============================================================
 * DIM: ICPDF PDF 维表
 *
 * 来源：dwd.dwd_icpdf_component_detail （按 pdf_file_id 去重）
 * 定位：描述"PDF 文件"本身的属性 —— 多个 component 可能引用同一张 PDF
 *       （平均 ~12 个 partno 共用一张 datasheet PDF）
 *
 * 重跑策略：INSERT INTO ... SELECT，主键 upsert，create_at 沿用历史
 *   create_at: COALESCE(old.create_at, CURRENT_TIMESTAMP())
 *   update_at: CURRENT_TIMESTAMP()
 * ============================================================ */

CREATE TABLE IF NOT EXISTS dim.dim_icpdf_pdf (
    `pdf_file_id`     BIGINT         NOT NULL COMMENT 'PDF 文件主键（icpdf 原始 id）',
    `fold_path`       VARCHAR(64)    NULL     COMMENT '一级目录',
    `fold_path2`      VARCHAR(64)    NULL     COMMENT '二级目录',
    `file_name`       VARCHAR(256)   NULL     COMMENT 'PDF 文件名',
    `page_count`      INT            NULL     COMMENT 'PDF 总页数',
    `file_size`       BIGINT         NULL     COMMENT 'PDF 文件大小（字节）',
    `md5_file`        VARCHAR(64)    NULL     COMMENT 'PDF 文件 MD5',

    `component_count` INT            NULL     COMMENT '引用此 PDF 的 detail 记录数',

    `create_at`       DATETIME       NULL DEFAULT CURRENT_TIMESTAMP COMMENT '入库时间（仅新行写入）',
    `update_at`       DATETIME       NULL DEFAULT CURRENT_TIMESTAMP COMMENT '最近一次更新时间'
) ENGINE=OLAP
PRIMARY KEY(`pdf_file_id`)
COMMENT 'ICPDF PDF 文件维表（按 pdf_file_id 去重）'
DISTRIBUTED BY HASH(`pdf_file_id`) BUCKETS 16
PROPERTIES (
    "compression"             = "ZSTD",
    "replication_num"         = "1",
    "enable_persistent_index" = "true"
);


/* ---------- 从 detail 聚合 → upsert 到 dim.dim_icpdf_pdf ---------- */
INSERT INTO dim.dim_icpdf_pdf
(pdf_file_id, fold_path, fold_path2, file_name, page_count, file_size, md5_file,
 component_count, create_at, update_at)
WITH agg AS (
    SELECT
        pdf_file_id,
        MAX(foldpath)     AS fold_path,
        MAX(foldpath2)    AS fold_path2,
        MAX(filename)     AS file_name,
        MAX(page)         AS page_count,
        MAX(filesize)     AS file_size,
        MAX(md5file)      AS md5_file,
        COUNT(*)          AS component_count
    FROM dwd.dwd_icpdf_component_detail
    WHERE pdf_file_id IS NOT NULL
    GROUP BY pdf_file_id
)
SELECT
    a.pdf_file_id,
    a.fold_path,
    a.fold_path2,
    a.file_name,
    a.page_count,
    a.file_size,
    a.md5_file,
    a.component_count,
    COALESCE(old.create_at, CURRENT_TIMESTAMP()) AS create_at,
    CURRENT_TIMESTAMP()                          AS update_at
FROM agg a
LEFT JOIN dim.dim_icpdf_pdf old ON old.pdf_file_id = a.pdf_file_id;


/* ---------- 校验 ---------- */
SELECT 'dim_row_count'                AS k, COUNT(*) AS v FROM dim.dim_icpdf_pdf
UNION ALL
SELECT 'dim_component_total',            SUM(component_count) FROM dim.dim_icpdf_pdf
UNION ALL
SELECT 'detail_distinct_pdf_file_id',    COUNT(DISTINCT pdf_file_id)
FROM dwd.dwd_icpdf_component_detail WHERE pdf_file_id IS NOT NULL;

SELECT
    CASE WHEN component_count = 1        THEN '1'
         WHEN component_count <= 5       THEN '2-5'
         WHEN component_count <= 20      THEN '6-20'
         WHEN component_count <= 100     THEN '21-100'
         ELSE                                 '>100'
    END AS bucket,
    COUNT(*) AS pdfs
FROM dim.dim_icpdf_pdf
GROUP BY 1 ORDER BY MIN(component_count);
