/*
 * 从 dwd_icpdf_component_param 抽样：电容 / 电阻 / 二极管（各最多 200 行）
 * - PDF 尽量不重复：按 md5file；若无 md5 则 foldpath/foldpath2/filename 拼键；每键保留一条（id 最小优先）
 * - 封装：prajson2 JSON 键「封装」「封装形式」「封装代码」
 *
 * 三大类判定（优先官方分类表，否则用语义兜底）：
 *   1) dwd_icpdf_component_class.l1_code ∈ (capacitor, resistor, diode)
 *   2) 否则按 category / category2 关键词（先判二极管，再电容，再电阻，减少交叉误分）
 *
 * 用法见 export_icpdf_sample_cap_res_diode_pdf_paths.sh
 */

WITH tagged AS (
    SELECT
        p.id,
        p.partno,
        p.brandshort,
        p.foldpath,
        p.foldpath2,
        p.filename,
        p.prajson2,
        COALESCE(
            CASE c.l1_code
                WHEN 'capacitor' THEN '电容'
                WHEN 'resistor' THEN '电阻'
                WHEN 'diode' THEN '二极管'
                ELSE NULL
            END,
            CASE
                WHEN p.category LIKE '%二极管%'
                  OR p.category LIKE '%Diode%'
                  OR p.category LIKE '%桥式整流%'
                  OR (p.category2 IS NOT NULL AND (
                        p.category2 LIKE '%二极管%'
                        OR p.category2 LIKE '%整流器%'
                      ))
                THEN '二极管'
                WHEN p.category LIKE '%电容%'
                  OR (p.category2 IS NOT NULL AND p.category2 LIKE '%电容%')
                THEN '电容'
                WHEN p.category LIKE '%电阻%'
                  OR (p.category2 IS NOT NULL AND p.category2 LIKE '%电阻%')
                THEN '电阻'
                ELSE NULL
            END
        ) AS major_cn,
        COALESCE(
            NULLIF(TRIM(p.md5file), ''),
            CONCAT(
                COALESCE(p.foldpath, ''),
                '/',
                COALESCE(p.foldpath2, ''),
                '/',
                COALESCE(p.filename, '')
            )
        ) AS pdf_key
    FROM dwd.dwd_icpdf_component_param p
    LEFT JOIN dwd.dwd_icpdf_component_class c
      ON c.id = p.id
     AND c.l3_code <> 'unclassified'
     AND c.l1_code IN ('capacitor', 'resistor', 'diode')
    WHERE p.filename IS NOT NULL
      AND TRIM(p.filename) <> ''
),
with_pkg AS (
    SELECT
        id,
        partno,
        brandshort,
        foldpath,
        foldpath2,
        filename,
        major_cn,
        pdf_key,
        NULLIF(
            TRIM(
                COALESCE(
                    NULLIF(get_json_string(prajson2, '$."封装"'), ''),
                    NULLIF(get_json_string(prajson2, '$."封装形式"'), ''),
                    NULLIF(get_json_string(prajson2, '$."封装代码"'), '')
                )
            ),
            ''
        ) AS package_name
    FROM tagged
    WHERE major_cn IS NOT NULL
),
dedup_pdf AS (
    SELECT
        *,
        ROW_NUMBER() OVER (PARTITION BY major_cn, pdf_key ORDER BY id) AS rn_dup
    FROM with_pkg
),
one_row_per_pdf AS (
    SELECT * FROM dedup_pdf WHERE rn_dup = 1
),
limited AS (
    SELECT
        *,
        ROW_NUMBER() OVER (PARTITION BY major_cn ORDER BY id) AS rn_pick
    FROM one_row_per_pdf
)
SELECT
    major_cn,
    id,
    brandshort,
    partno,
    package_name,
    foldpath,
    foldpath2,
    filename
FROM limited
WHERE rn_pick <= 200
ORDER BY major_cn, id;
