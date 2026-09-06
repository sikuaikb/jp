/* ============================================================
 * brand_origin_backfill.sql —— 从 dim.dim_brand_origin JOIN 回写
 *   dim.dim_std_brand 的产地列（country_region/is_domestic/domestic_type）
 *
 * 路径：sql_scripts/2.attribute_standard/brand_origin_backfill.sql
 * 执行时机：sync_dim_std_brand.sh 在 manual_extra 之后、v_std_brand_alias 之前
 *
 * 原理：dim_std_brand 是 PK(brand_id_std) 模型，INSERT 一行同 PK 的数据
 *   会 UPSERT 覆盖。本脚本 SELECT 全列（含产地列）+ JOIN dim_brand_origin
 *   产地数据，重新 UPSERT 回 dim_std_brand，只更新产地列，其余列不变。
 *
 * 幂等：可重复执行，产地列始终与 dim_brand_origin 一致。
 * ============================================================ */

INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, related_words,
 logo, state, official_website, level, type, source,
 country_region, is_domestic, domestic_type,
 create_at, update_at)
SELECT
    b.brand_id_std,
    b.name,
    b.brand_zh,
    b.brand_en,
    b.abbr,
    b.related_words,
    b.logo,
    b.state,
    b.official_website,
    b.level,
    b.type,
    b.source,
    o.country_region,
    o.is_domestic,
    o.domestic_type,
    b.create_at,
    CURRENT_TIMESTAMP()
FROM dim.dim_std_brand b
INNER JOIN dim.dim_brand_origin o ON o.brand_id_std = b.brand_id_std;

