/* ============================================================================
 * dim_std_brand 品牌补录：diode + transistor 未命中品牌
 * 背景：diode/transistor L2 build 原 brandid 兜底 COALESCE(a.brand_id_std, p.brandid)，
 *       已改为 a.brand_id_std（未命中即 NULL，全 L1 统一）；切换后孤儿品牌需补录。
 * 口径：99 个孤儿品牌中，17 个已被 inductor/relay 补录覆盖（rebuild 即解决），
 *       Part 1 = 2 个安全别名（TAK_CHEONG→Tak Cheong；SUPERTEX→Microchip，与已映射的 SMSC/ZARLINK 一致），
 *       Part 2 = 其余真新品牌 → manual_extra（id 接续 9M 段当前最大值，NOT EXISTS 守卫保幂等）。
 * 注：注释一律用块注释 /* *\/，勿用「-- 中文」行注释（mysql 从 stdin 多语句会误切分）。
 *     执行后需重建 diode/transistor 14 张 L2 宽表。
 * ========================================================================== */

/* ---------- Part 1：安全别名 ---------- */
/* Tak Cheong Electronics Holdings ← TAK_CHEONG */
INSERT INTO test_dim.dim_std_brand
SELECT brand_id_std, name, brand_zh, brand_en, abbr,
       array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), CAST(['TAK_CHEONG'] AS ARRAY<VARCHAR(256)>)),
       logo, state, official_website, level, type, source, create_at, CURRENT_TIMESTAMP()
FROM test_dim.dim_std_brand WHERE brand_id_std=1970701011365343234;

/* 美国微芯-MICROCHIP ← SUPERTEX（与已映射的 SMSC/ZARLINK 同属 Microchip） */
INSERT INTO test_dim.dim_std_brand
SELECT brand_id_std, name, brand_zh, brand_en, abbr,
       array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), CAST(['SUPERTEX'] AS ARRAY<VARCHAR(256)>)),
       logo, state, official_website, level, type, source, create_at, CURRENT_TIMESTAMP()
FROM test_dim.dim_std_brand WHERE brand_id_std=1443490693837066244;


/* ---------- Part 2：新增 manual_extra（其余真新品牌；NOT EXISTS 守卫，幂等） ---------- */
INSERT INTO test_dim.dim_std_brand (brand_id_std, name, related_words, source)
WITH w AS (
    SELECT brand, brandid FROM test_dwd.dwd_l2_diode_rectifier_switching_diode_diode
    UNION ALL SELECT brand, brandid FROM test_dwd.dwd_l2_diode_rf_special_diode_diode
    UNION ALL SELECT brand, brandid FROM test_dwd.dwd_l2_diode_voltage_reg_protection_diode_diode
    UNION ALL SELECT brand, brandid FROM test_dwd.dwd_l2_transistor_bipolar_transistor_base_transistor
    UNION ALL SELECT brand, brandid FROM test_dwd.dwd_l2_transistor_fet_base_transistor
    UNION ALL SELECT brand, brandid FROM test_dwd.dwd_l2_transistor_igbt_base_transistor
    UNION ALL SELECT brand, brandid FROM test_dwd.dwd_l2_transistor_thyristor_base_transistor
),
o AS (
    /* 未命中 = brandid 为 NULL（源无 brandid 或重建后未命中）或 orphan（指向 dim 不存在的 id，重建前残留）。
       两种都覆盖，重建前/后均可安全重跑。 */
    SELECT UPPER(TRIM(w.brand)) AS bk, MAX(w.brand) AS orig
    FROM w LEFT JOIN test_dim.dim_std_brand b ON b.brand_id_std = w.brandid
    WHERE (w.brandid IS NULL OR b.brand_id_std IS NULL) AND NULLIF(TRIM(w.brand), '') IS NOT NULL
    GROUP BY UPPER(TRIM(w.brand))
),
f AS (
    SELECT bk, orig FROM o
    WHERE NOT EXISTS (SELECT 1 FROM test_dim.v_std_brand_alias a WHERE a.brand_key = o.bk)
)
SELECT (SELECT COALESCE(MAX(brand_id_std), 9000250) FROM test_dim.dim_std_brand WHERE brand_id_std BETWEEN 9000251 AND 9999999)
        + CAST(ROW_NUMBER() OVER (ORDER BY bk) AS BIGINT) AS brand_id_std,
       orig AS name,
       CAST([bk] AS ARRAY<VARCHAR(256)>) AS related_words,
       'manual_extra' AS source
FROM f;
