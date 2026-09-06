-- ============================================================
-- DWD 清洗：ods.ods_icpdf_component_detail -> dwd.dwd_icpdf_component_detail
--
-- 【数据流（与本目录其它脚本顺序）】
--   ods.ods_icpdf_component_detail
--     └─ data_json（整包 JSON 字符串）
--     └─ 本脚本：内层子查询将 data_json 规整为 dj（去非法控制字符 + 常见非法反斜杠转义），
--        外层从 dj 解析字段 → INSERT 主键表 dwd.dwd_icpdf_component_detail（按 dt 分区 upsert）
--   dwd.dwd_icpdf_component_detail
--     └─ 下游：dwd_icpdf_component_param.sql（筛选 prajson IS NOT NULL OR prajson2 IS NOT NULL）
--
-- 【prajson】非法片段（,,、尾逗号、非法 \\ 转义等）在本脚本内清洗；有问题分区请重跑本 INSERT。
-- 【prajson2】原 repairs 中对 JSON 结果的 HTML 实体解码（&amp;#176; 等）已并入下方构造链路，
--   在 dt/dd 转 JSON 之前对原始 HTML 串解码（客户端/会话宜用 utf8mb4）。
--
-- 字段清洗要点：
--   1. 把 data_json 按业务字段打平；
--   2. prajson / prajson2 / pdfReplacePartNoArr 转成 JSON 原生类型；
--   3. category__info 去掉 <a></a>，再按 " &gt; " 切成 ARRAY<VARCHAR>；
--   4. taginfo 按 "|" 切成 ARRAY<VARCHAR>；
--   5. bigImg 提取 <img src=".."> 后去掉前导 "//"，其他 URL 字段同样去掉 "//"；
--   6. 主键 (id, dt) 支持按分区重跑上卷（upsert 语义）；
--   7. 子查询里用 replace() 链先剥掉非法 JSON 控制字符（0x00-0x08、0x0B、0x0C、0x0E-0x1F），
--      因为源爬虫偶尔在字符串里混入 \x10 等二进制残渣会让 parse_json 直接失败。
--      这里不用 regexp_replace —— 4.0.2 版本 BE 在同一 SELECT 里对同一大列多次 regexp_replace
--      会触发 "slot_id already exists" bug，改成 replace() 链稳定。
-- ============================================================

-- 1) 建表（幂等）
CREATE TABLE IF NOT EXISTS dwd.dwd_icpdf_component_detail (
    `id`                     BIGINT                NOT NULL COMMENT '组件唯一ID（data_json.pdf.id）',
    `dt`                     DATE                  NOT NULL COMMENT '分区字段（数据入库日期，与 ODS 对齐）',
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
    `taginfo`                ARRAY<VARCHAR(256)>   NULL     COMMENT '标签数组（原字符串按 | 切分）',
    `prajson`                JSON                  NULL     COMMENT '参数明细 JSON 数组',
    `prajson2`               JSON                  NULL     COMMENT '参数表 dt/dd 转 JSON 对象',
    `image2`                 VARCHAR(512)          NULL     COMMENT '缩略图/图标（可能是 URL 或 CSS 类名）',
    `category_info`          ARRAY<VARCHAR(256)>   NULL     COMMENT '分类面包屑数组（按 &gt; 切分的多级分类）',
    `createtime`             DATETIME              NULL     COMMENT '源系统创建时间',
    `updatetime`             DATETIME              NULL     COMMENT '源系统更新时间',
    `praid`                  BIGINT                NULL     COMMENT '参数表外键ID',
    `all_info`               VARCHAR(2048)         NULL     COMMENT '汇总说明文本',
    `pdf_replace_partno_arr` JSON                  NULL     COMMENT '替代料数组',
    `big_img`                VARCHAR(1024)         NULL     COMMENT '大图 URL（去掉 // 前缀）',
    `pin_diagram`            VARCHAR(1024)         NULL     COMMENT '引脚图 URL（去掉 // 前缀）',
    `schematic_diagram`      VARCHAR(1024)         NULL     COMMENT '原理图 URL（去掉 // 前缀）',
    `package_pad_diagram`    VARCHAR(1024)         NULL     COMMENT '封装焊盘图 URL（去掉 // 前缀）',
    `create_at`              DATETIME              NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'DWD 入库时间',
    `update_at`              DATETIME              NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'DWD 更新时间'
) ENGINE=OLAP
PRIMARY KEY(`id`, `dt`)
COMMENT 'ICPDF 组件详情明细层（DWD）'
PARTITION BY RANGE(`dt`) ()
DISTRIBUTED BY HASH(`id`) BUCKETS 16
PROPERTIES (
    "compression" = "ZSTD",
    "datacache.enable" = "true",
    "dynamic_partition.enable" = "true",
    "dynamic_partition.time_unit" = "DAY",
    "dynamic_partition.time_zone" = "Asia/Shanghai",
    "dynamic_partition.start" = "-365",
    "dynamic_partition.end" = "3",
    "dynamic_partition.prefix" = "p",
    "dynamic_partition.buckets" = "16",
    "dynamic_partition.history_partition_num" = "0",
    "replication_num" = "1"
);


-- 2) 回补历史分区（动态分区只建当天+未来；历史分区需先暂停动态分区再补）
--    跑其他历史分区时照抄即可。
-- ALTER TABLE dwd.dwd_icpdf_component_detail SET ("dynamic_partition.enable" = "false");
-- ALTER TABLE dwd.dwd_icpdf_component_detail ADD PARTITION IF NOT EXISTS p20260401
--     VALUES [('2026-04-01'), ('2026-04-02'));
-- ALTER TABLE dwd.dwd_icpdf_component_detail SET ("dynamic_partition.enable" = "true");


-- 3) 清洗写入 p20260401 分区
--    主键表 (id, dt) 重复执行会 upsert，可放心重跑。
INSERT INTO dwd.dwd_icpdf_component_detail
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
    id,
    dt,
    get_json_string(dj, '$.pdf.partno')                                  AS partno,
    CAST(NULLIF(get_json_string(dj, '$.pdf.brandid'), '') AS BIGINT)     AS brandid,
    get_json_string(dj, '$.pdf.brandshort')                              AS brandshort,
    CAST(NULLIF(get_json_string(dj, '$.pdf.pdf_file_id'), '') AS BIGINT) AS pdf_file_id,
    get_json_string(dj, '$.pdf.foldpath')                                AS foldpath,
    get_json_string(dj, '$.pdf.foldpath2')                               AS foldpath2,
    get_json_string(dj, '$.pdf.filename')                                AS filename,
    CAST(NULLIF(get_json_string(dj, '$.pdf.page'), '') AS INT)           AS page,
    CAST(NULLIF(get_json_string(dj, '$.pdf.filesize'), '') AS BIGINT)    AS filesize,
    get_json_string(dj, '$.pdf.md5file')                                 AS md5file,
    get_json_string(dj, '$.pdf.categoryid')                              AS categoryid,
    get_json_string(dj, '$.pdf.category')                                AS category,
    get_json_string(dj, '$.pdf.category2')                               AS category2,
    get_json_string(dj, '$.pdf.note')                                    AS note,
    get_json_string(dj, '$.pdf.note_cn')                                 AS note_cn,

    /* ---------- taginfo: "|a|b|c|" -> ARRAY["a","b","c"] ---------- */
    CASE
        WHEN NULLIF(get_json_string(dj, '$.pdf.taginfo'), '') IS NULL THEN NULL
        ELSE array_remove(split(get_json_string(dj, '$.pdf.taginfo'), '|'), '')
    END                                                                  AS taginfo,

    /* prajson: 源存在多种非法 JSON，分层清洗
     *   (a) translate: 去掉 0x00-0x1F 控制字符（含字面 \n/\r/\t），避免字符串值里混入原生换行
     *   (b) regexp_replace ',{2,}' -> ',': 合并数组空元素（例如 "},,,{"）
     *   (c) regexp_replace ',(\s*[\]}])' -> '\1': 去掉 "},]" / ",}" 这类尾逗号
     *   (d) regexp_replace '\\([^"\\\/bfnrtu])' -> '\1': 剥掉非法反斜杠转义（\+、\-、\空格 等）
     */
    parse_json(
        regexp_replace(
          regexp_replace(
            regexp_replace(
              translate(
                NULLIF(get_json_string(dj, '$.pdf.prajson'), ''),
                concat(char(0), char(1), char(2), char(3), char(4), char(5), char(6), char(7), char(8),
                       char(9), char(10), char(11), char(12), char(13), char(14), char(15), char(16),
                       char(17), char(18), char(19), char(20), char(21), char(22), char(23), char(24),
                       char(25), char(26), char(27), char(28), char(29), char(30), char(31)),
                ''
              ),
              ',{2,}', ','
            ),
            ',(\\s*[\\]\\}])', '\\1'
          ),
          '\\\\([^"\\\\/bfnrtu])', '\\1'
        )
    )                                                                     AS prajson,

    /* ---------- prajson2: HTML 实体解码 + <dt>k</dt><dd>v</dd> -> JSON 对象 ----------
     *   replace 链：先 &amp;amp;，再数值/命名实体，最后单层 &#digits;（°µΩ 等为 UTF-8 字面量）
     */
    CASE
        WHEN NULLIF(get_json_string(dj, '$.pdf.prajson2'), '') IS NULL THEN NULL
        ELSE parse_json(
            concat('{',
                regexp_replace(
                    regexp_replace(
                        replace(
                        replace(
                        replace(
                        replace(
                        replace(
                        replace(
                        replace(
                        replace(
                        replace(
                        replace(
                        replace(
                        replace(
                        replace(
                        replace(
                            get_json_string(dj, '$.pdf.prajson2'),
                            '&amp;amp;', '&'),
                            '&amp;#176;', '°'),
                            '&amp;#181;', 'µ'),
                            '&amp;#937;', 'Ω'),
                            '&amp;#x3a9;', 'Ω'),
                            '&amp;#x3A9;', 'Ω'),
                            '&amp;quot;', CHAR(34)),
                            '&amp;gt;', '>'),
                            '&amp;lt;', '<'),
                            '&amp;nbsp;', ' '),
                            '&amp;', '&'),
                            '&#176;', '°'),
                            '&#181;', 'µ'),
                            '&#937;', 'Ω'),
                        '<dt>\\s*([^<]*?)\\s*</dt><dd>\\s*([^<]*?)\\s*</dd>',
                        '"\\1":"\\2",'
                    ),
                    ',$',
                    ''
                ),
            '}')
        )
    END                                                                  AS prajson2,

    get_json_string(dj, '$.pdf.image2')                                  AS image2,

    /* ---------- category_info: 去链接 + 按 &gt; 切成数组 ---------- */
    CASE
        WHEN NULLIF(get_json_string(dj, '$.pdf.category__info'), '') IS NULL THEN NULL
        ELSE array_remove(
                split(
                    regexp_replace(
                        regexp_replace(
                            get_json_string(dj, '$.pdf.category__info'),
                            '<a[^>]*>|</a>',
                            ''
                        ),
                        '\\s*&gt;\\s*',
                        '|'
                    ),
                    '|'
                ),
                ''
             )
    END                                                                  AS category_info,

    CAST(NULLIF(get_json_string(dj, '$.pdf.createtime'), '') AS DATETIME) AS createtime,
    CAST(NULLIF(get_json_string(dj, '$.pdf.updatetime'), '') AS DATETIME) AS updatetime,
    CAST(NULLIF(get_json_string(dj, '$.pdf.praid'), '') AS BIGINT)       AS praid,

    get_json_string(dj, '$.allInfo')                                     AS all_info,
    parse_json(NULLIF(get_json_string(dj, '$.pdfReplacePartNoArr'), '')) AS pdf_replace_partno_arr,

    /* ---------- 4 个 URL 字段：去掉前导 "//" ---------- */
    regexp_replace(
        regexp_extract(get_json_string(dj, '$.bigImg'), 'src="([^"]+)"', 1),
        '^//', ''
    )                                                                    AS big_img,
    regexp_replace(get_json_string(dj, '$.pinDiagram'),         '^//', '') AS pin_diagram,
    regexp_replace(get_json_string(dj, '$.schematicDiagram'),   '^//', '') AS schematic_diagram,
    regexp_replace(get_json_string(dj, '$.packagePadDiagram'),  '^//', '') AS package_pad_diagram,

    CURRENT_TIMESTAMP()                                                  AS create_at,
    CURRENT_TIMESTAMP()                                                  AS update_at
FROM (
    /* sanitize：一次 translate() 干掉所有非法控制字符，再用若干 replace() 处理
       反斜杠相关的非法转义。不用 regexp_replace —— 4.0.2 版本 BE 在同一 SELECT 对
       同一大列多次 regexp_replace 会触发 slot_id 冲突 bug。
       (a) translate: 删除 0x00-0x08、0x0B、0x0C、0x0E-0x1F（保留 \t \n \r）；
       (b) replace \\  -> CHAR(1)：先把合法的 \\ 用占位符保护起来，避免下面误伤；
       (c) replace \< -> <  （源爬虫常见 "IF \< 10mA" 写法，JSON 规范不认 \< ）；
       (d) replace \> -> >；
       (e) replace \& -> &  （源爬虫偶有 "60\&ordm;" 写法）；
       (f) replace \* -> *、\1 -> 1、\<space> -> <space>（极少见）；
       (g) replace CHAR(1) -> \\ 还原。
       经过 9200 条全量坏行扫描，非法转义仅出现上述 6 种字符。
       另有极少数行（~0.02%）在 JSON 字符串里混入字面换行符，JSON 规范不允许，
       当前方案无法救援，会落成 null 的 partno，可接受。 */
    SELECT id, dt,
        replace(
          replace(
            replace(
              replace(
                replace(
                  replace(
                    replace(
                      replace(
                        translate(data_json,
                          concat(char(0), char(1), char(2), char(3), char(4), char(5), char(6), char(7), char(8),
                                 char(11), char(12),
                                 char(14), char(15), char(16), char(17), char(18), char(19), char(20), char(21),
                                 char(22), char(23), char(24), char(25), char(26), char(27), char(28), char(29),
                                 char(30), char(31)),
                          ''),
                        concat(char(92), char(92)), char(1)),
                      concat(char(92), '<'), '<'),
                    concat(char(92), '>'), '>'),
                  concat(char(92), '&'), '&'),
                concat(char(92), '*'), '*'),
              concat(char(92), '1'), '1'),
            concat(char(92), ' '), ' '),
          char(1), concat(char(92), char(92))
        ) AS dj
    FROM ods.ods_icpdf_component_detail PARTITION(p20260401)
    WHERE data_json IS NOT NULL AND data_json <> ''
) t;


-- 4) 校验
SELECT
    (SELECT COUNT(*) FROM ods.ods_icpdf_component_detail PARTITION(p20260401)
        WHERE data_json IS NOT NULL AND data_json <> '') AS ods_rows,
    (SELECT COUNT(*) FROM dwd.dwd_icpdf_component_detail PARTITION(p20260401)) AS dwd_rows,
    (SELECT COUNT(*) FROM dwd.dwd_icpdf_component_detail PARTITION(p20260401)
        WHERE partno IS NULL OR partno = '') AS null_partno_rows;
