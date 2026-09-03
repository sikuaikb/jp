/* ============================================================================
 * dim_std_brand 品牌补录：inductor + relay 未命中品牌（103 个）
 * 方案见 reports/inductor_attr_std/brand_curation_plan.md
 * 执行口径（用户确认 safe_only）：
 *   Part 1 = A 区 21 个高信心别名 → 给已有品牌 array_concat 补 related_words（整行重放，PK=REPLACE 保留其它列）
 *   Part 2 = 其余 82 个 key（含 A2 五个存疑、B 区全部）→ 新增 manual_extra 行（brand_id_std 9000251+）
 * 依赖：test_dim.v_std_brand_alias 为视图，补录后即时生效；之后需重建 inductor/relay 宽表。
 * 幂等：Part 2 带 NOT EXISTS 守卫（已在别名视图命中的跳过）；Part 1 重放会向 related_words 追加重复值，
 *       视图按 brand_key 去重，无害。注意：所有注释用块注释 /* *\/，勿用「-- 中文」行注释
 *       （mysql 客户端从 stdin 多语句切分时会因此误判，导致后续 INSERT 报 EOF 语法错误）。
 * ========================================================================== */

/* ---------- Part 1：别名补 related_words（按目标品牌分组） ---------- */
/* API Delevan */
INSERT INTO test_dim.dim_std_brand
SELECT brand_id_std, name, brand_zh, brand_en, abbr,
       array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), CAST(['DELEVAN'] AS ARRAY<VARCHAR(256)>)),
       logo, state, official_website, level, type, source, create_at, CURRENT_TIMESTAMP()
FROM test_dim.dim_std_brand WHERE brand_id_std=1498554570241003521;

/* 赛特勒-ZETTLER */
INSERT INTO test_dim.dim_std_brand
SELECT brand_id_std, name, brand_zh, brand_en, abbr,
       array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), CAST(['AMERICAN ZETTLER','AZETTLER','ZETTLER MAGNETICS'] AS ARRAY<VARCHAR(256)>)),
       logo, state, official_website, level, type, source, create_at, CURRENT_TIMESTAMP()
FROM test_dim.dim_std_brand WHERE brand_id_std=1443490699902029827;

/* 伍尔特-Wurth */
INSERT INTO test_dim.dim_std_brand
SELECT brand_id_std, name, brand_zh, brand_en, abbr,
       array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), CAST(['WüRTH ELEKTRONIK'] AS ARRAY<VARCHAR(256)>)),
       logo, state, official_website, level, type, source, create_at, CURRENT_TIMESTAMP()
FROM test_dim.dim_std_brand WHERE brand_id_std=1443490691236597766;

/* 魏德米勒-weidmueller */
INSERT INTO test_dim.dim_std_brand
SELECT brand_id_std, name, brand_zh, brand_en, abbr,
       array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), CAST(['WEIDMüLLER'] AS ARRAY<VARCHAR(256)>)),
       logo, state, official_website, level, type, source, create_at, CURRENT_TIMESTAMP()
FROM test_dim.dim_std_brand WHERE brand_id_std=1447755160083058690;

/* 夏弗纳-Schaffner */
INSERT INTO test_dim.dim_std_brand
SELECT brand_id_std, name, brand_zh, brand_en, abbr,
       array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), CAST(['TE CONNECTIVITY SCHAFFNER'] AS ARRAY<VARCHAR(256)>)),
       logo, state, official_website, level, type, source, create_at, CURRENT_TIMESTAMP()
FROM test_dim.dim_std_brand WHERE brand_id_std=1443490700417929217;

/* Sensata Technologies（含 GigaVac） */
INSERT INTO test_dim.dim_std_brand
SELECT brand_id_std, name, brand_zh, brand_en, abbr,
       array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), CAST(['SENSATA TECHNOLOGIES, INC.','SENSATA - GIGAVAC INDUSTRIAL'] AS ARRAY<VARCHAR(256)>)),
       logo, state, official_website, level, type, source, create_at, CURRENT_TIMESTAMP()
FROM test_dim.dim_std_brand WHERE brand_id_std=1970699754743476226;

/* Hammond */
INSERT INTO test_dim.dim_std_brand
SELECT brand_id_std, name, brand_zh, brand_en, abbr,
       array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), CAST(['HAMMOND MANUFACTURING'] AS ARRAY<VARCHAR(256)>)),
       logo, state, official_website, level, type, source, create_at, CURRENT_TIMESTAMP()
FROM test_dim.dim_std_brand WHERE brand_id_std=1443490700162076680;

/* 伊顿-eaton */
INSERT INTO test_dim.dim_std_brand
SELECT brand_id_std, name, brand_zh, brand_en, abbr,
       array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), CAST(['EATON ELECTRICAL'] AS ARRAY<VARCHAR(256)>)),
       logo, state, official_website, level, type, source, create_at, CURRENT_TIMESTAMP()
FROM test_dim.dim_std_brand WHERE brand_id_std=1443490691630862341;

/* BUSSMANN（Eaton-Bussmann 子品牌） */
INSERT INTO test_dim.dim_std_brand
SELECT brand_id_std, name, brand_zh, brand_en, abbr,
       array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), CAST(['EATON - BUSSMANN ELECTRICAL DIVISION'] AS ARRAY<VARCHAR(256)>)),
       logo, state, official_website, level, type, source, create_at, CURRENT_TIMESTAMP()
FROM test_dim.dim_std_brand WHERE brand_id_std=1443490693442801670;

/* 台湾佳邦-INPAQ */
INSERT INTO test_dim.dim_std_brand
SELECT brand_id_std, name, brand_zh, brand_en, abbr,
       array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), CAST(['INPAQ TECHNOLOGY CO., LTD'] AS ARRAY<VARCHAR(256)>)),
       logo, state, official_website, level, type, source, create_at, CURRENT_TIMESTAMP()
FROM test_dim.dim_std_brand WHERE brand_id_std=1443490693702848516;

/* 东光-TOKO */
INSERT INTO test_dim.dim_std_brand
SELECT brand_id_std, name, brand_zh, brand_en, abbr,
       array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), CAST(['TOKO AMERICA INC.'] AS ARRAY<VARCHAR(256)>)),
       logo, state, official_website, level, type, source, create_at, CURRENT_TIMESTAMP()
FROM test_dim.dim_std_brand WHERE brand_id_std=9000006;

/* Triad Magnetics */
INSERT INTO test_dim.dim_std_brand
SELECT brand_id_std, name, brand_zh, brand_en, abbr,
       array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), CAST(['TRIAD'] AS ARRAY<VARCHAR(256)>)),
       logo, state, official_website, level, type, source, create_at, CURRENT_TIMESTAMP()
FROM test_dim.dim_std_brand WHERE brand_id_std=9000238;

/* TT ELECTRONICS/BI */
INSERT INTO test_dim.dim_std_brand
SELECT brand_id_std, name, brand_zh, brand_en, abbr,
       array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), CAST(['TT ELECTRONICS/BI MAGNETICS'] AS ARRAY<VARCHAR(256)>)),
       logo, state, official_website, level, type, source, create_at, CURRENT_TIMESTAMP()
FROM test_dim.dim_std_brand WHERE brand_id_std=1452914132033273857;

/* 光颉-Viking（Viking Tech） */
INSERT INTO test_dim.dim_std_brand
SELECT brand_id_std, name, brand_zh, brand_en, abbr,
       array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), CAST(['VIKING TECH'] AS ARRAY<VARCHAR(256)>)),
       logo, state, official_website, level, type, source, create_at, CURRENT_TIMESTAMP()
FROM test_dim.dim_std_brand WHERE brand_id_std=1443490691173683207;

/* 斯丹麦德-STANDEXMEDER */
INSERT INTO test_dim.dim_std_brand
SELECT brand_id_std, name, brand_zh, brand_en, abbr,
       array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), CAST(['MEDER'] AS ARRAY<VARCHAR(256)>)),
       logo, state, official_website, level, type, source, create_at, CURRENT_TIMESTAMP()
FROM test_dim.dim_std_brand WHERE brand_id_std=1443490699776200713;

/* METZ CONNECT */
INSERT INTO test_dim.dim_std_brand
SELECT brand_id_std, name, brand_zh, brand_en, abbr,
       array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), CAST(['METZ CONNECT USA INC.'] AS ARRAY<VARCHAR(256)>)),
       logo, state, official_website, level, type, source, create_at, CURRENT_TIMESTAMP()
FROM test_dim.dim_std_brand WHERE brand_id_std=1443490700350820353;

/* AEM */
INSERT INTO test_dim.dim_std_brand
SELECT brand_id_std, name, brand_zh, brand_en, abbr,
       array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), CAST(['AEM, INC.'] AS ARRAY<VARCHAR(256)>)),
       logo, state, official_website, level, type, source, create_at, CURRENT_TIMESTAMP()
FROM test_dim.dim_std_brand WHERE brand_id_std=1443490692209676294;

/* CIT RELAY & SWITCH */
INSERT INTO test_dim.dim_std_brand
SELECT brand_id_std, name, brand_zh, brand_en, abbr,
       array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), CAST(['CIT RELAY AND SWITCH'] AS ARRAY<VARCHAR(256)>)),
       logo, state, official_website, level, type, source, create_at, CURRENT_TIMESTAMP()
FROM test_dim.dim_std_brand WHERE brand_id_std=1970677900989370369;


/* ---------- Part 2：新增 manual_extra（其余 82 个 key，brand_id_std 9000251+；NOT EXISTS 守卫保证幂等） ---------- */
INSERT INTO test_dim.dim_std_brand (brand_id_std, name, related_words, source)
WITH r AS (
    SELECT brand FROM test_dwd.dwd_l2_inductor_power_inductor_inductor   WHERE brandid IS NULL
    UNION ALL SELECT brand FROM test_dwd.dwd_l2_inductor_hf_chip_inductor_inductor    WHERE brandid IS NULL
    UNION ALL SELECT brand FROM test_dwd.dwd_l2_inductor_emi_filter_inductor_inductor WHERE brandid IS NULL
    UNION ALL SELECT brand FROM test_dwd.dwd_l2_relay_solid_state_relay_relay         WHERE brandid IS NULL
    UNION ALL SELECT brand FROM test_dwd.dwd_l2_relay_electromechanical_relay_relay   WHERE brandid IS NULL
),
u AS (
    SELECT UPPER(TRIM(brand)) AS bk, MAX(brand) AS orig_name
    FROM r WHERE NULLIF(TRIM(brand), '') IS NOT NULL
    GROUP BY UPPER(TRIM(brand))
),
f AS (
    SELECT bk, orig_name FROM u
    WHERE bk NOT IN (
        'DELEVAN','AMERICAN ZETTLER','AZETTLER','ZETTLER MAGNETICS','WüRTH ELEKTRONIK',
        'WEIDMüLLER','TE CONNECTIVITY SCHAFFNER','SENSATA TECHNOLOGIES, INC.','SENSATA - GIGAVAC INDUSTRIAL',
        'HAMMOND MANUFACTURING','EATON ELECTRICAL','EATON - BUSSMANN ELECTRICAL DIVISION',
        'INPAQ TECHNOLOGY CO., LTD','TOKO AMERICA INC.','TRIAD','TT ELECTRONICS/BI MAGNETICS',
        'VIKING TECH','MEDER','METZ CONNECT USA INC.','AEM, INC.','CIT RELAY AND SWITCH'
    )
      AND NOT EXISTS (SELECT 1 FROM test_dim.v_std_brand_alias a WHERE a.brand_key = u.bk)
)
SELECT 9000250 + CAST(ROW_NUMBER() OVER (ORDER BY bk) AS BIGINT) AS brand_id_std,
       orig_name AS name,
       CAST([bk] AS ARRAY<VARCHAR(256)>) AS related_words,
       'manual_extra' AS source
FROM f;
