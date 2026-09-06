/* ============================================================
 * 重建 dim.v_std_brand_alias —— 增加 state=1 过滤
 *
 * 原视图未过滤 state，导致 state=0 的退役品牌别名仍会出现在视图里，
 * 软删后会污染 brand_key -> brand_id_std 映射。本补丁加 state=1 过滤。
 * 其余逻辑（name/abbr/related_words 展开 + ROW_NUMBER 去重）保持不变。
 * ============================================================ */

DROP VIEW IF EXISTS dim.v_std_brand_alias;

CREATE VIEW dim.v_std_brand_alias AS
WITH expanded AS (
    SELECT
        UPPER(TRIM(name)) AS brand_key,
        brand_id_std,
        name              AS canonical_name,
        'name'            AS alias_kind
    FROM dim.dim_std_brand
    WHERE state = 1 AND name IS NOT NULL AND TRIM(name) <> ''

    UNION ALL

    SELECT
        UPPER(TRIM(abbr)),
        brand_id_std,
        name,
        'abbr'
    FROM dim.dim_std_brand
    WHERE state = 1 AND abbr IS NOT NULL AND TRIM(abbr) <> ''

    UNION ALL

    SELECT
        UPPER(TRIM(rw)),
        b.brand_id_std,
        b.name,
        'related_word'
    FROM dim.dim_std_brand b,
         UNNEST(COALESCE(b.related_words, CAST([] AS ARRAY<VARCHAR(256)>))) AS u(rw)
    WHERE b.state = 1 AND TRIM(rw) <> ''
),
ranked AS (
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
