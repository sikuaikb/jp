/* ============================================================
 * dwd.v_param_normalized —— 跨源 partno / brand 归一化视图
 *
 * 目的：为 icpdf + digikey 数据融合提供统一的 (brand_id_std, mpn_std) 匹配键。
 *       同一真实器件在两源 id 不同、partno 写法不同（包装后缀 / 描述段 / 大小写），
 *       本视图把两源 param 表归一到同一键空间，供下游 dwd_component_entity 实体解析。
 *
 * 路径：sql_scripts/foundation/v_param_normalized.sql
 * 依赖：dwd.dwd_icpdf_component_param、dwd.dwd_digikey_component_param、dim.v_std_brand_alias
 *
 * 归一化规则（链式，顺序敏感）：
 *   1. UPPER + TRIM
 *   2. 去描述性段 (QTY:xxx)        —— DigiKey 电缆类常带数量/长度段，不是 MPN 一部分
 *   3. 去括号包装段 (T&R)/(TR)/(T/R) —— ICPDF 常见
 *   4. 去尾部包装后缀（两层兜底，处理 -TR-ND 这类复合后缀）：
 *        #TR / -TR / -T&R / -T/R / -ND / #ND / -TR-ND / #TR-ND
 *   5. 去尾部连续分隔符 [-#/ ]+$
 *   6. 再 TRIM
 *
 * 保留（不清洗）：
 *   - 前导零：Molex 0639112900 等料号前导零有语义，保留
 *   - 中间的 / ：军工料号 M39003/01-5249 的 / 是料号一部分
 *   - 中间的 TR/字符：严格行尾锚定，不误删 MSP430FR2355TRHAR 中的 TR
 *
 * 字段：
 *   data_source      'icpdf' | 'digikey'
 *   id               源 param 表主键
 *   partno_raw       原始 partno
 *   mpn_std          归一化 MPN（匹配键）
 *   brand_id_std     经 v_std_brand_alias 归一的品牌 ID（未命中为 NULL）
 *   brand_std        归一品牌规范名（未命中为 NULL）
 *   brandshort_raw   原始 brandshort
 *   is_mpn_like      mpn_std 是否"像 MPN"：不含空格/中文/括号 → 1；含描述性内容 → 0
 *                    （下游融合时 is_mpn_like=0 的行降权或不参与强匹配）
 *
 * 注意：dwd_digikey_component_param 的 PK 是 (id, partno)，理论上 id 已是 hash(partno)
 *       唯一，但仍按源表每行产出，不去重；下游实体解析时再 DISTINCT。
 * ============================================================ */

DROP VIEW IF EXISTS dwd.v_param_normalized;

CREATE VIEW dwd.v_param_normalized AS
WITH base AS (
    SELECT
        CAST('icpdf' AS VARCHAR(32))  AS data_source,
        id,
        partno,
        brandshort
    FROM dwd.dwd_icpdf_component_param
    WHERE partno IS NOT NULL AND TRIM(partno) <> ''

    UNION ALL

    SELECT
        CAST('digikey' AS VARCHAR(32)) AS data_source,
        id,
        partno,
        brandshort
    FROM dwd.dwd_digikey_component_param
    WHERE partno IS NOT NULL AND TRIM(partno) <> ''
),
norm AS (
    SELECT
        b.data_source,
        b.id,
        b.partno AS partno_raw,
        b.brandshort AS brandshort_raw,
        TRIM(
            REGEXP_REPLACE(
                /* 第 6 步：去尾部连续分隔符 - / # 空格（如 KYOCERA AVX 的 CB182G105K-- 脏尾） */
                REGEXP_REPLACE(
                    /* 第二层兜底：去完第一层后缀后可能露出第二层 -TR / -ND */
                    REGEXP_REPLACE(
                        /* 第一层：去尾部包装后缀（行尾锚定，不误伤中间字符） */
                        REGEXP_REPLACE(
                            /* 去括号包装段 (T&R)/(TR)/(T/R) */
                            REGEXP_REPLACE(
                                /* 去描述性段 (QTY:xxx) */
                                UPPER(TRIM(b.partno)),
                                '\\(QTY:[^)]*\\)', ''
                            ),
                            '\\((T&R|TR|T/R)\\)', ''
                        ),
                        '(#TR-ND|-TR-ND|#TR|-TR|-T&R|-T/R|-ND|#ND)$', ''
                    ),
                    '(#TR|-TR|-T&R|-T/R|-ND|#ND)$', ''
                ),
                '[-#/ ]+$', ''
            )
        ) AS mpn_std
    FROM base b
)
SELECT
    n.data_source,
    n.id,
    n.partno_raw,
    n.mpn_std,
    a.brand_id_std,
    a.canonical_name AS brand_std,
    n.brandshort_raw,
    CASE
        WHEN n.mpn_std IS NULL OR TRIM(n.mpn_std) = '' THEN 0
        WHEN n.mpn_std REGEXP '[ ]' THEN 0
        WHEN n.mpn_std REGEXP '[一-龥]' THEN 0
        WHEN n.mpn_std REGEXP '[()]' THEN 0
        ELSE 1
    END AS is_mpn_like
FROM norm n
LEFT JOIN dim.v_std_brand_alias a
       ON a.brand_key = UPPER(TRIM(n.brandshort_raw));
