/* ============================================================
 * dim.v_std_brand_alias —— 品牌别名查询视图
 *
 * 路径：sql_scripts/2.attribute_standard/v_std_brand_alias.sql
 * 数据源：dim.dim_std_brand（主表）
 *
 * 视图把主表的 name / abbr / related_words 展开为 (brand_key → brand_id_std) 一对一映射，
 * 视图内 ROW_NUMBER 解决 brand_key 跨品牌冲突，保证 brand_key 在视图层全局唯一。
 *
 * 冲突解决优先级（PARTITION BY brand_key 内 ROW_NUMBER ORDER BY ...）：
 *   1. source = 'manual_extra' > 'jp_brand'   —— 手工修订一定赢
 *   2. alias_kind = 'name' > 'abbr' > 'related_word'  —— 精确度递减
 *   3. brand_id_std 升序                       —— 兜底，保证确定性
 *
 * L2 build 用法：
 *   LEFT JOIN dim.v_std_brand_alias a
 *          ON a.brand_key = UPPER(TRIM(p.brandshort))
 * ============================================================ */

DROP VIEW IF EXISTS dim.v_std_brand_alias;

CREATE VIEW dim.v_std_brand_alias AS
WITH expanded AS (
    /* 仅以 related_words 作为统一规则入口；name / abbr 也作为额外别名补充以兜底，
     * 但视图整体仍保证 brand_key 全局唯一（ROW_NUMBER + rn=1 dedup）。 */
    SELECT
        UPPER(TRIM(name)) AS brand_key,
        brand_id_std,
        name              AS canonical_name,
        'name'            AS alias_kind
    FROM dim.dim_std_brand
    WHERE name IS NOT NULL AND TRIM(name) <> ''

    UNION ALL

    SELECT
        UPPER(TRIM(abbr)),
        brand_id_std,
        name,
        'abbr'
    FROM dim.dim_std_brand
    WHERE abbr IS NOT NULL AND TRIM(abbr) <> ''

    UNION ALL

    SELECT
        UPPER(TRIM(rw)),
        b.brand_id_std,
        b.name,
        'related_word'
    FROM dim.dim_std_brand b,
         UNNEST(COALESCE(b.related_words, CAST([] AS ARRAY<VARCHAR(256)>))) AS u(rw)
    WHERE TRIM(rw) <> ''
),
ranked AS (
    /* 冲突解决（同 brand_key 跨多个 brand_id_std）：
     *   1) alias_kind: name > abbr > related_word（精确度递减）
     *   2) brand_id_std 升序兜底，保证确定性 */
    SELECT
        brand_key,
        brand_id_std,
        canonical_name,
        alias_kind,
        ROW_NUMBER() OVER (
            PARTITION BY brand_key
            ORDER BY
                CASE alias_kind
                    WHEN 'name'         THEN 0
                    WHEN 'abbr'         THEN 1
                    WHEN 'related_word' THEN 2
                    ELSE 3
                END,
                brand_id_std ASC
        ) AS rn
    FROM expanded
)
SELECT brand_key, brand_id_std, canonical_name, alias_kind
FROM ranked
WHERE rn = 1;
