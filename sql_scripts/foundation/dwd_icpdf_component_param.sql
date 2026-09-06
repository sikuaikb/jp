/*
 * dwd.dwd_icpdf_component_param
 *
 * 【定位】从 dwd.dwd_icpdf_component_detail **透传**切片（不在此脚本做 prajson 级二次清洗）。
 *   prajson / prajson2 的解析与纠错见 upstream：
 *   sql_scripts/pipelines/foundation/dwd_icpdf_component_detail.sql
 *   （含 prajson 非法 JSON 规整、prajson2 HTML 实体解码与 dt/dd → JSON）。
 *   若 detail 已重跑：再执行本脚本全量 INSERT 即可刷新 param（主键 upsert）。
 *
 *   source : dwd.dwd_icpdf_component_detail
 *   filter : prajson IS NOT NULL OR prajson2 IS NOT NULL
 *   layout : no partition, HASH(id) 16 buckets, PRIMARY KEY upsert
 *   run    : mysql ... -D dwd < sql_scripts/pipelines/foundation/dwd_icpdf_component_param.sql
 *            （StarRocks 不接受裸行注释分段标题，下文一律使用块注释。）
 */

/* 1) create table (idempotent) */
CREATE TABLE IF NOT EXISTS dwd.dwd_icpdf_component_param (
    `id`                     BIGINT                NOT NULL COMMENT '组件唯一ID（沿用 detail 表主键）',
    `dt`                     DATE                  NULL     COMMENT '来源分区日期（仅做普通列保留，不再作为分区字段）',
    `partno`                 VARCHAR(256)          NULL     COMMENT '型号 partno',
    `brandid`                BIGINT                NULL     COMMENT '品牌ID',
    `brandshort`             VARCHAR(128)          NULL     COMMENT '品牌简称',
    `pdf_file_id`            BIGINT                NULL     COMMENT 'PDF 文件ID',
    `foldpath`               VARCHAR(64)           NULL     COMMENT '一级目录',
    `foldpath2`              VARCHAR(64)           NULL     COMMENT '二级目录',
    `filename`               VARCHAR(256)          NULL     COMMENT 'PDF 文件名',
    `page`                   INT                   NULL     COMMENT 'PDF 页数',
    `filesize`               BIGINT                NULL     COMMENT 'PDF 大小（字节）',
    `md5file`                VARCHAR(64)           NULL     COMMENT 'PDF MD5',
    `categoryid`             VARCHAR(64)           NULL     COMMENT '分类ID',
    `category`               VARCHAR(256)          NULL     COMMENT '分类名',
    `category2`              VARCHAR(256)          NULL     COMMENT '分类名2',
    `note`                   VARCHAR(4096)         NULL     COMMENT '备注（英文）',
    `note_cn`                VARCHAR(2048)         NULL     COMMENT '备注（中文）',
    `taginfo`                ARRAY<VARCHAR(256)>   NULL     COMMENT '标签数组',
    `prajson`                JSON                  NULL     COMMENT '参数明细 JSON 数组',
    `prajson2`               JSON                  NULL     COMMENT '参数表 dt/dd 转 JSON 对象',
    `image2`                 VARCHAR(512)          NULL     COMMENT '缩略图/图标',
    `category_info`          ARRAY<VARCHAR(256)>   NULL     COMMENT '分类面包屑数组',
    `createtime`             DATETIME              NULL     COMMENT '源系统创建时间',
    `updatetime`             DATETIME              NULL     COMMENT '源系统更新时间',
    `praid`                  BIGINT                NULL     COMMENT '参数表外键ID',
    `all_info`               VARCHAR(2048)         NULL     COMMENT '汇总说明文本',
    `pdf_replace_partno_arr` JSON                  NULL     COMMENT '替代料数组',
    `big_img`                VARCHAR(1024)         NULL     COMMENT '大图 URL',
    `pin_diagram`            VARCHAR(1024)         NULL     COMMENT '引脚图 URL',
    `schematic_diagram`      VARCHAR(1024)         NULL     COMMENT '原理图 URL',
    `package_pad_diagram`    VARCHAR(1024)         NULL     COMMENT '封装焊盘图 URL',
    `create_at`              DATETIME              NULL DEFAULT CURRENT_TIMESTAMP COMMENT '本表入库时间',
    `update_at`              DATETIME              NULL DEFAULT CURRENT_TIMESTAMP COMMENT '本表更新时间'
) ENGINE=OLAP
PRIMARY KEY(`id`)
COMMENT 'ICPDF 具备参数信息（prajson / prajson2）的组件明细'
DISTRIBUTED BY HASH(`id`) BUCKETS 16
PROPERTIES (
    "compression"        = "ZSTD",
    "datacache.enable"   = "true",
    "replication_num"    = "1",
    "enable_persistent_index" = "true"
);


/* 2) load data (primary-key upsert, safe to re-run) */
INSERT INTO dwd.dwd_icpdf_component_param
(
    id, dt,
    partno, brandid, brandshort,
    pdf_file_id, foldpath, foldpath2, filename, page, filesize,
    md5file, categoryid, category, category2,
    note, note_cn, taginfo,
    prajson, prajson2,
    image2, category_info,
    createtime, updatetime, praid,
    all_info, pdf_replace_partno_arr,
    big_img, pin_diagram, schematic_diagram, package_pad_diagram,
    create_at, update_at
)
SELECT
    id, dt,
    partno, brandid, brandshort,
    pdf_file_id, foldpath, foldpath2, filename, page, filesize,
    md5file, categoryid, category, category2,
    note, note_cn, taginfo,
    prajson, prajson2,
    image2, category_info,
    createtime, updatetime, praid,
    all_info, pdf_replace_partno_arr,
    big_img, pin_diagram, schematic_diagram, package_pad_diagram,
    CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
FROM dwd.dwd_icpdf_component_detail
WHERE prajson IS NOT NULL OR prajson2 IS NOT NULL;


/* 3) sanity check */
SELECT
    (SELECT COUNT(*) FROM dwd.dwd_icpdf_component_detail
        WHERE prajson IS NOT NULL OR prajson2 IS NOT NULL)  AS src_expected_rows,
    (SELECT COUNT(*) FROM dwd.dwd_icpdf_component_param)    AS dst_rows,
    (SELECT COUNT(*) FROM dwd.dwd_icpdf_component_param
        WHERE prajson IS NULL AND prajson2 IS NULL)         AS dst_both_null_should_be_0;
