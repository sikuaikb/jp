/* ============================================================
 * 历史品牌查重合并（A 类）：loser → keep related_words
 *
 * 来源：exports/brand_supplement/brand_dup_triage.csv（联网核实 2026-07-09）
 * 合并组：54；loser 行已从 manual_extra/stage25 VALUES 删除
 * 豁免：LEADER / AIC / HELIX → validate_brand_dim_dup BUILTIN_WAIVER
 *
 * 幂等：array_distinct(array_concat)；可重复执行
 * 由 sync_dim_std_brand.sh 在 stage25 之后执行
 * ============================================================ */

/* M.1 BeRex Corp (BEREX) <- 1 keys */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), ARRAY<VARCHAR(256)>['BEREX INC'])),
       logo, state, official_website, level, type,
       source, create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std=9000117;

/* M.2 Superworld Electronics (SUPERWORLD) <- 2 keys */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), ARRAY<VARCHAR(256)>['SUPERWORLD ELECTRONICS', 'SUPERWORLD'])),
       logo, state, official_website, level, type,
       source, create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std=9000315;

/* M.3 NextGen Components (NEXTGEN) <- 2 keys */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), ARRAY<VARCHAR(256)>['NEXTGEN COMPONENTS', 'NGC'])),
       logo, state, official_website, level, type,
       source, create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std=9000332;

/* M.4 ISL Products International (ISLPRODUCTSINTERNATIONAL) <- 1 keys */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), ARRAY<VARCHAR(256)>['ISL PRODUCTS INTERNATIONAL'])),
       logo, state, official_website, level, type,
       source, create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std=9000333;

/* M.5 Integra Technologies (INTEGRA) <- 3 keys */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), ARRAY<VARCHAR(256)>['INTEGRA TECHNOLOGIES INC.', 'INTEGRA TECHNOLOGIES', 'INTEGRA TECHNOLOGIES INC'])),
       logo, state, official_website, level, type,
       source, create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std=9000464;

/* M.6 Pepperl+Fuchs (PEPPERLFUCHS) <- 1 keys */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), ARRAY<VARCHAR(256)>['PEPPERL+FUCHS, INC.'])),
       logo, state, official_website, level, type,
       source, create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std=9000513;

/* M.7 Atlas Scientific (ATLASSCIENTIFIC) <- 1 keys */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), ARRAY<VARCHAR(256)>['ATLAS SCIENTIFIC'])),
       logo, state, official_website, level, type,
       source, create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std=9000547;

/* M.8 Cole Hersee (COLEHERSEE) <- 1 keys */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), ARRAY<VARCHAR(256)>['COLE HERSEE'])),
       logo, state, official_website, level, type,
       source, create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std=9000550;

/* M.9 Golledge Electronics (GOLLEDGE) <- 3 keys */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), ARRAY<VARCHAR(256)>['GOLLEDGE ELECTRONICS', 'GOLLEDGE', 'TECHPOINT GOLLEDGE'])),
       logo, state, official_website, level, type,
       source, create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std=9001070;

/* M.10 Swissbit (SWISSBIT) <- 1 keys */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), ARRAY<VARCHAR(256)>['SWISSBIT'])),
       logo, state, official_website, level, type,
       source, create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std=9001112;

/* M.11 ADATA (ADATA) <- 1 keys */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), ARRAY<VARCHAR(256)>['ADATA'])),
       logo, state, official_website, level, type,
       source, create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std=9001114;

/* M.12 Virtium LLC (VIRTIUM) <- 1 keys */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), ARRAY<VARCHAR(256)>['VIRTIUM LLC'])),
       logo, state, official_website, level, type,
       source, create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std=9001117;

/* M.13 Innodisk USA Corporation (INNODISKUSA) <- 1 keys */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), ARRAY<VARCHAR(256)>['INNODISK USA CORPORATION'])),
       logo, state, official_website, level, type,
       source, create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std=9001118;

/* M.14 iFixit (IFIXIT) <- 1 keys */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), ARRAY<VARCHAR(256)>['IFIXIT'])),
       logo, state, official_website, level, type,
       source, create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std=9001124;

/* M.15 UDINFO (UDINFO) <- 1 keys */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), ARRAY<VARCHAR(256)>['UDINFO'])),
       logo, state, official_website, level, type,
       source, create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std=9001127;

/* M.16 Seco (SECO) <- 1 keys */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), ARRAY<VARCHAR(256)>['SECO'])),
       logo, state, official_website, level, type,
       source, create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std=9001129;

/* M.17 CRYPTNOX (CRYPTNOX) <- 1 keys */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), ARRAY<VARCHAR(256)>['CRYPTNOX'])),
       logo, state, official_website, level, type,
       source, create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std=9001132;

/* M.18 CATALYST (CATALYST) <- 1 keys */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), ARRAY<VARCHAR(256)>['CATALYST SEMICONDUCTOR INC.'])),
       logo, state, official_website, level, type,
       source, create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std=9001270;

/* M.19 Orion Fans (ORIONFANS) <- 1 keys */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), ARRAY<VARCHAR(256)>['ORIONFANS'])),
       logo, state, official_website, level, type,
       source, create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std=9001297;

/* M.20 Powerex Inc. (POWEREX) <- 1 keys */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), ARRAY<VARCHAR(256)>['POWEREX'])),
       logo, state, official_website, level, type,
       source, create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std=9001298;

/* M.21 POMONA (POMONA) <- 1 keys */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), ARRAY<VARCHAR(256)>['POMONA ELECTRONICS'])),
       logo, state, official_website, level, type,
       source, create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std=9001300;

/* M.22 AZDISPLAYS (AZDISPLAYS) <- 1 keys */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), ARRAY<VARCHAR(256)>['AZ DISPLAYS'])),
       logo, state, official_website, level, type,
       source, create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std=9001317;

/* M.23 FINISAR (FINISAR) <- 1 keys */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), ARRAY<VARCHAR(256)>['FINISAR CORPORATION'])),
       logo, state, official_website, level, type,
       source, create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std=9001323;

/* M.24 ALPHAWIRE (ALPHAWIRE) <- 1 keys */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), ARRAY<VARCHAR(256)>['ALPHA WIRE'])),
       logo, state, official_website, level, type,
       source, create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std=9001336;

/* M.25 SANREX (SANREX) <- 1 keys */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), ARRAY<VARCHAR(256)>['SANREX CORPORATION'])),
       logo, state, official_website, level, type,
       source, create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std=9001340;

/* M.26 P-DUKE (PDUKE) <- 1 keys */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), ARRAY<VARCHAR(256)>['P-DUKE TECHNOLOGY'])),
       logo, state, official_website, level, type,
       source, create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std=9001347;

/* M.27 PUIAUDIO (PUIAUDIO) <- 2 keys */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), ARRAY<VARCHAR(256)>['PUI AUDIO', 'PUI AUDIO, INC.'])),
       logo, state, official_website, level, type,
       source, create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std=9001427;

/* M.28 CARLOGAVAZZI (CARLOGAVAZZI) <- 1 keys */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), ARRAY<VARCHAR(256)>['CARLO GAVAZZI INC.'])),
       logo, state, official_website, level, type,
       source, create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std=9001464;

/* M.29 PICKER (PICKER) <- 1 keys */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), ARRAY<VARCHAR(256)>['PICKER COMPONENTS'])),
       logo, state, official_website, level, type,
       source, create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std=9001571;

/* M.30 B&J-USA, Inc. (BJUSA) <- 1 keys */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), ARRAY<VARCHAR(256)>['B&J-USA INC.'])),
       logo, state, official_website, level, type,
       source, create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std=9001590;

/* M.31 MDE Semiconductor Inc (MDE) <- 1 keys */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), ARRAY<VARCHAR(256)>['MDE'])),
       logo, state, official_website, level, type,
       source, create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std=9001877;

/* M.32 ADVANCEDPHOTONIX (ADVANCEDPHOTONIX) <- 1 keys */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), ARRAY<VARCHAR(256)>['ADVANCED PHOTONIX'])),
       logo, state, official_website, level, type,
       source, create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std=9001953;

/* M.33 Analog Power Inc. (ANALOGPOWER) <- 1 keys */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), ARRAY<VARCHAR(256)>['ANALOGPOWER'])),
       logo, state, official_website, level, type,
       source, create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std=9002026;

/* M.34 Power Sonic Corporation (POWERSONIC) <- 1 keys */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), ARRAY<VARCHAR(256)>['POWER-SONIC'])),
       logo, state, official_website, level, type,
       source, create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std=9002113;

/* M.35 台湾冠坤-Su'scon (SUSCON) <- 1 keys */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), ARRAY<VARCHAR(256)>['SUSCON'])),
       logo, state, official_website, level, type,
       source, create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std=1443490691949629449;

/* M.36 虹扬-HY (HY) <- 1 keys */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), ARRAY<VARCHAR(256)>['HY ELECTRONIC'])),
       logo, state, official_website, level, type,
       source, create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std=1443490693702848513;

/* M.37 佳光-LUCKYLIGHT (LUCKYLIGHT) <- 1 keys */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), ARRAY<VARCHAR(256)>['LUCKY-LIGHT'])),
       logo, state, official_website, level, type,
       source, create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std=1443490695082774536;

/* M.38 CEVA (CEVA) <- 1 keys */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), ARRAY<VARCHAR(256)>['CEVA TECHNOLOGIES, INC.'])),
       logo, state, official_website, level, type,
       source, create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std=1443490696185876484;

/* M.39 IC-HAUS (ICHAUS) <- 1 keys */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), ARRAY<VARCHAR(256)>['ICHAUS'])),
       logo, state, official_website, level, type,
       source, create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std=1443490696252985354;

/* M.40 芯凯-KINETIC (KINETIC) <- 1 keys */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), ARRAY<VARCHAR(256)>['KINETIC TECHNOLOGIES'])),
       logo, state, official_website, level, type,
       source, create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std=1443490697238646789;

/* M.41 安碁科技-AKER (AKER) <- 2 keys */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), ARRAY<VARCHAR(256)>['AKER TECHNOLOGY CORP.', 'AKER TECHNOLOGY CORP'])),
       logo, state, official_website, level, type,
       source, create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std=1443490697951678467;

/* M.42 松川-Song Chuan (SONGCHUAN) <- 1 keys */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), ARRAY<VARCHAR(256)>['SONGCHUAN'])),
       logo, state, official_website, level, type,
       source, create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std=1443490699776200711;

/* M.43 益升华-Essentra (ESSENTRA) <- 1 keys */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), ARRAY<VARCHAR(256)>['ESSENTRA COMPONENTS'])),
       logo, state, official_website, level, type,
       source, create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std=1443490700162076677;

/* M.44 On-Shore Technology, Inc. (ONSHORE) <- 1 keys */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), ARRAY<VARCHAR(256)>['ON SHORE TECHNOLOGY INC.'])),
       logo, state, official_website, level, type,
       source, create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std=1443490700350820358;

/* M.45 ebmpapst (EBMPAPST) <- 1 keys */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), ARRAY<VARCHAR(256)>['EBM-PAPST INC.'])),
       logo, state, official_website, level, type,
       source, create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std=1443490701063852042;

/* M.46 XP Power (XPPOWER) <- 1 keys */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), ARRAY<VARCHAR(256)>['XPPOWER'])),
       logo, state, official_website, level, type,
       source, create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std=1448104925496958978;

/* M.47 SL Power (SLPOWER) <- 1 keys */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), ARRAY<VARCHAR(256)>['SLPOWER'])),
       logo, state, official_website, level, type,
       source, create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std=1448858323011850241;

/* M.48 EPT GMBH (EPT) <- 1 keys */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), ARRAY<VARCHAR(256)>['EPT, INC'])),
       logo, state, official_website, level, type,
       source, create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std=1452553154607235073;

/* M.49 RF Solutions (RFSOLUTIONS) <- 1 keys */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), ARRAY<VARCHAR(256)>['RFSOLUTIONS'])),
       logo, state, official_website, level, type,
       source, create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std=1452554720429035521;

/* M.50 慧荣科技-SiliconMotion (SILICONMOTION) <- 1 keys */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), ARRAY<VARCHAR(256)>['SILICON MOTION, INC.'])),
       logo, state, official_website, level, type,
       source, create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std=1452555117080211458;

/* M.51 兆龙-CT-Micro (CTMICRO) <- 1 keys */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), ARRAY<VARCHAR(256)>['CTMICRO'])),
       logo, state, official_website, level, type,
       source, create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std=1452560759132073986;

/* M.52 研华-Advantech (ADVANTECH) <- 2 keys */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), ARRAY<VARCHAR(256)>['ADVANTECH', 'ADVANTECH CORPORATION'])),
       logo, state, official_website, level, type,
       source, create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std=1498507150190768129;

/* M.53 Excel Cell Electronics (EXCELCELL) <- 1 keys */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), ARRAY<VARCHAR(256)>['EXCEL CELL ELECTRONIC CO., LTD.'])),
       logo, state, official_website, level, type,
       source, create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std=1970678272223023105;

/* M.54 Greenconn Technology (GREENCONN) <- 1 keys */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), ARRAY<VARCHAR(256)>['GREENCONN'])),
       logo, state, official_website, level, type,
       source, create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std=1970678279143624706;


/* ==== JP-brand remaining dups (post stage25 merge) ==== */

/* JP.1 ADAM (ADAM) <- losers 1970677887341105154 */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), ARRAY<VARCHAR(256)>['ADAM TECHNOLOGIES', 'ADAMTECHNOLOGIES'])),
       logo, state, official_website, level, type,
       source, create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std=1448110004627087362;

DELETE FROM dim.dim_std_brand WHERE brand_id_std=1970677887341105154;

/* JP.2 Adesto (ADESTO) <- losers 1452930575722430466 */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), ARRAY<VARCHAR(256)>['ADESTO TECHNOLOGIES', 'ADT'])),
       logo, state, official_website, level, type,
       source, create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std=1443490695795806216;

DELETE FROM dim.dim_std_brand WHERE brand_id_std=1452930575722430466;

/* JP.3 AKM (AKM) <- losers 1970678250270035970 */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), ARRAY<VARCHAR(256)>['AKM SEMICONDUCTOR', 'AKMSEMICONDUCTOR'])),
       logo, state, official_website, level, type,
       source, create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std=1443490695342821379;

DELETE FROM dim.dim_std_brand WHERE brand_id_std=1970678250270035970;

/* JP.4 宝乘-baocheng (BAOCHENG) <- losers 1970708767770095618 */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), ARRAY<VARCHAR(256)>['BAO CHENG ELECTRONICS', 'BAOCHENGELECTRONICS'])),
       logo, state, official_website, level, type,
       source, create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std=1443490693119840260;

DELETE FROM dim.dim_std_brand WHERE brand_id_std=1970708767770095618;

/* JP.5 belfuse (BELFUSE) <- losers 1452878214891163649 */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), ARRAY<VARCHAR(256)>['BEL FUSE', 'BEF'])),
       logo, state, official_website, level, type,
       source, create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std=1443490694885642242;

DELETE FROM dim.dim_std_brand WHERE brand_id_std=1452878214891163649;

/* JP.6 中移物联网-Chinamobile (CHINAMOBILE) <- losers 1970709184289648641 */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), ARRAY<VARCHAR(256)>['CHINA MOBILE', 'CHINAMOBILE'])),
       logo, state, official_website, level, type,
       source, create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std=1443490698937339909;

DELETE FROM dim.dim_std_brand WHERE brand_id_std=1970709184289648641;

/* JP.7 CIT Relay & Switch (CITRELAYSWITCH) <- losers 1970677900989370369 */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), ARRAY<VARCHAR(256)>['CIT RELAY & SWITCH', 'CITRELAYSWITCH'])),
       logo, state, official_website, level, type,
       source, create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std=1498556724385206273;

DELETE FROM dim.dim_std_brand WHERE brand_id_std=1970677900989370369;

/* JP.8 康纳温菲尔德-Connor-Winfield (CONNORWINFIELD) <- losers 1452552521317691393 */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), ARRAY<VARCHAR(256)>['康纳温菲尔德-CONNORWINFIELD', 'CONNORWINFIELD', 'CWF'])),
       logo, state, official_website, level, type,
       source, create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std=1447509321808916481;

DELETE FROM dim.dim_std_brand WHERE brand_id_std=1452552521317691393;

/* JP.9 Cosel (COSEL) <- losers 1970677936250884097 */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), ARRAY<VARCHAR(256)>['COSEL'])),
       logo, state, official_website, level, type,
       source, create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std=1498507971611652097;

DELETE FROM dim.dim_std_brand WHERE brand_id_std=1970677936250884097;

/* JP.10 冠西-cosmo (COSMO) <- losers 1970677936510930946 */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), ARRAY<VARCHAR(256)>['COSMO ELECTRONICS', 'COSMOELECTRONICS'])),
       logo, state, official_website, level, type,
       source, create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std=1443490699386130443;

DELETE FROM dim.dim_std_brand WHERE brand_id_std=1970677936510930946;

/* JP.11 兆龙-CT-Micro (CTMICRO) <- losers 1443490695015665672 */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), ARRAY<VARCHAR(256)>['CT MICRO', 'CTM'])),
       logo, state, official_website, level, type,
       source, create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std=1452560759132073986;

DELETE FROM dim.dim_std_brand WHERE brand_id_std=1443490695015665672;

/* JP.12 德利威-Dailywell (DAILYWELL) <- losers 1970677938931044354 */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), ARRAY<VARCHAR(256)>['DAILYWELL ELECTRONICS', 'DAILYWELLELECTRONICS'])),
       logo, state, official_website, level, type,
       source, create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std=1443490699453239298;

DELETE FROM dim.dim_std_brand WHERE brand_id_std=1970677938931044354;

/* JP.13 德艺隆-DEALON (DEALON) <- losers 1970709144783499265 */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), ARRAY<VARCHAR(256)>['DEALON'])),
       logo, state, official_website, level, type,
       source, create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std=1509434324972273666;

DELETE FROM dim.dim_std_brand WHERE brand_id_std=1970709144783499265;

/* JP.14 EIC (EIC) <- losers 1970678249540227074 */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), ARRAY<VARCHAR(256)>['EIC SEMICONDUCTOR', 'EICSEMICONDUCTOR'])),
       logo, state, official_website, level, type,
       source, create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std=1443490693577019396;

DELETE FROM dim.dim_std_brand WHERE brand_id_std=1970678249540227074;

/* JP.15 ElecSuper(静芯微） (ELECSUPER) <- losers 1970709055595819009 */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), ARRAY<VARCHAR(256)>['ELECSUPER'])),
       logo, state, official_website, level, type,
       source, create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std=1656931303259467777;

DELETE FROM dim.dim_std_brand WHERE brand_id_std=1970709055595819009;

/* JP.16 ERNI (ERNI) <- losers 1970678250869821441 */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), ARRAY<VARCHAR(256)>['ERNI ELECTRONICS', 'ERNIELECTRONICS'])),
       logo, state, official_website, level, type,
       source, create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std=1443490699453239301;

DELETE FROM dim.dim_std_brand WHERE brand_id_std=1970678250869821441;

/* JP.17 台湾亿光-EVERLIGHT (EVERLIGHT) <- losers 1970678266501992449 */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), ARRAY<VARCHAR(256)>['EVERLIGHT ELECTRONICS', 'EVERLIGHTELECTRONICS'])),
       logo, state, official_website, level, type,
       source, create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std=1443490693442801669;

DELETE FROM dim.dim_std_brand WHERE brand_id_std=1970678266501992449;

/* JP.18 佳利电子-GLEAD (GLEAD) <- losers 1496695618905640961 */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), ARRAY<VARCHAR(256)>['GLEAD', 'GLA'])),
       logo, state, official_website, level, type,
       source, create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std=1519861979823546370;

DELETE FROM dim.dim_std_brand WHERE brand_id_std=1496695618905640961;

/* JP.19 浩亭-Harting (HARTING) <- losers 1970678289637773314 */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), ARRAY<VARCHAR(256)>['HARTING TECHNOLOGY', 'HARTINGTECHNOLOGY'])),
       logo, state, official_website, level, type,
       source, create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std=1443490699520348165;

DELETE FROM dim.dim_std_brand WHERE brand_id_std=1970678289637773314;

/* JP.20 华德共创-HDGC (HDGC) <- losers 1970708648349872130 */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), ARRAY<VARCHAR(256)>['HDGC'])),
       logo, state, official_website, level, type,
       source, create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std=1509440635529134082;

DELETE FROM dim.dim_std_brand WHERE brand_id_std=1970708648349872130;

/* JP.21 康比-Hornby (HORNBY) <- losers 1454984865441988609 */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), ARRAY<VARCHAR(256)>['南通康比-HORNBY ELECTRONIC', 'HORNBY ELECTRONIC', 'NKB'])),
       logo, state, official_website, level, type,
       source, create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std=1448538726735867906;

DELETE FROM dim.dim_std_brand WHERE brand_id_std=1454984865441988609;

/* JP.22 晶创和立-JCHL (JCHL) <- losers 1656930153353277441 */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), ARRAY<VARCHAR(256)>['JCHL(晶创和立)', 'CHH'])),
       logo, state, official_website, level, type,
       source, create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std=1443490692411002886;

DELETE FROM dim.dim_std_brand WHERE brand_id_std=1656930153353277441;

/* JP.23 JOHANSON (JOHANSON) <- losers 1448539709889175554 */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), ARRAY<VARCHAR(256)>['JOHANSON TECHNOLOGY', 'JTL'])),
       logo, state, official_website, level, type,
       source, create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std=1443490691819606018;

DELETE FROM dim.dim_std_brand WHERE brand_id_std=1448539709889175554;

/* JP.24 台湾钧宝-Kingcore (KINGCORE) <- losers 1970678883538636802 */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), ARRAY<VARCHAR(256)>['KING CORE', 'KINGCORE'])),
       logo, state, official_website, level, type,
       source, create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std=1443490692796878849;

DELETE FROM dim.dim_std_brand WHERE brand_id_std=1970678883538636802;

/* JP.25 可天士-Kodenshi (KODENSHI) <- losers 1970678883932901377 */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), ARRAY<VARCHAR(256)>['KODENSHI'])),
       logo, state, official_website, level, type,
       source, create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std=1443490695082774532;

DELETE FROM dim.dim_std_brand WHERE brand_id_std=1970678883932901377;

/* JP.26 莱迪斯-LATTICE (LATTICE) <- losers 1452893246907572225;1970678934021279745 */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), ARRAY<VARCHAR(256)>['莱迪思-LATTICE SEMICONDUCTOR', 'LATTICE SEMICONDUCTOR', 'SMR', 'LATTICESEMICONDUCTOR'])),
       logo, state, official_website, level, type,
       source, create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std=1443490695409930248;

DELETE FROM dim.dim_std_brand WHERE brand_id_std=1452893246907572225;
DELETE FROM dim.dim_std_brand WHERE brand_id_std=1970678934021279745;

/* JP.27 MaxLinear (MAXLINEAR) <- losers 1970708026800156674 */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), ARRAY<VARCHAR(256)>['MAXLINEAR'])),
       logo, state, official_website, level, type,
       source, create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std=1443490695472844801;

DELETE FROM dim.dim_std_brand WHERE brand_id_std=1970708026800156674;

/* JP.28 Micro Crystal (MICROCRYSTAL) <- losers 1970679534708527105 */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), ARRAY<VARCHAR(256)>['MICRO CRYSTAL', 'MICROCRYSTAL'])),
       logo, state, official_website, level, type,
       source, create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std=1443490695988744195;

DELETE FROM dim.dim_std_brand WHERE brand_id_std=1970679534708527105;

/* JP.29 镁光-micron (MICRON) <- losers 1970680266761375746 */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), ARRAY<VARCHAR(256)>['MICRON TECHNOLOGY', 'MICRONTECHNOLOGY'])),
       logo, state, official_website, level, type,
       source, create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std=1443490693837066245;

DELETE FROM dim.dim_std_brand WHERE brand_id_std=1970680266761375746;

/* JP.30 优曲克-NEUTRIK (NEUTRIK) <- losers 1970707834919137282 */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), ARRAY<VARCHAR(256)>['NEUTRIK GROUP', 'NEUTRIKGROUP'])),
       logo, state, official_website, level, type,
       source, create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std=1443490700350820356;

DELETE FROM dim.dim_std_brand WHERE brand_id_std=1970707834919137282;

/* JP.31 台湾正凌-Nextron (NEXTRON) <- losers 1970680442754371586 */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), ARRAY<VARCHAR(256)>['NEXTRON COMPONENTS', 'NEXTRONCOMPONENTS'])),
       logo, state, official_website, level, type,
       source, create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std=1443490700350820357;

DELETE FROM dim.dim_std_brand WHERE brand_id_std=1970680442754371586;

/* JP.32 日本电产-NIDEC (NIDEC) <- losers 9000110 */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), ARRAY<VARCHAR(256)>['NIDEC COMPONENTS', 'NIDEC'])),
       logo, state, official_website, level, type,
       source, create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std=1443490699709091844;

DELETE FROM dim.dim_std_brand WHERE brand_id_std=9000110;

/* JP.33 强茂-Panjit (PANJIT) <- losers 1970680975254818818 */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), ARRAY<VARCHAR(256)>['PAN JIT', 'PANJIT'])),
       logo, state, official_website, level, type,
       source, create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std=1443490693186949127;

DELETE FROM dim.dim_std_brand WHERE brand_id_std=1970680975254818818;

/* JP.34 台湾光鼎-PARALIGHT (PARALIGHT) <- losers 1970681033975074817 */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), ARRAY<VARCHAR(256)>['PARA LIGHT ELECTRONICS', 'PARALIGHTELECTRONICS'])),
       logo, state, official_website, level, type,
       source, create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std=1443490695149883398;

DELETE FROM dim.dim_std_brand WHERE brand_id_std=1970681033975074817;

/* JP.35 品腾-PinTENG (PINTENG) <- losers 1970709006237249538 */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), ARRAY<VARCHAR(256)>['PINTENG'])),
       logo, state, official_website, level, type,
       source, create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std=1509450195866263554;

DELETE FROM dim.dim_std_brand WHERE brand_id_std=1970709006237249538;

/* JP.36 上海矽睿-QST (QST) <- losers 1970709208482394114 */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), ARRAY<VARCHAR(256)>['QST CORPORATION', 'QSTCORPORATION'])),
       logo, state, official_website, level, type,
       source, create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std=1443490698677293062;

DELETE FROM dim.dim_std_brand WHERE brand_id_std=1970709208482394114;

/* JP.37 美国纬创电子-RALTRON (RALTRON) <- losers 1970681059329642498 */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), ARRAY<VARCHAR(256)>['RALTRON ELECTRONICS', 'RALTRONELECTRONICS'])),
       logo, state, official_website, level, type,
       source, create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std=1443490695925829642;

DELETE FROM dim.dim_std_brand WHERE brand_id_std=1970681059329642498;

/* JP.38 Sensata (SENSATA) <- losers 1970699754743476226 */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), ARRAY<VARCHAR(256)>['SENSATA TECHNOLOGIES', 'SENSATATECHNOLOGIES'])),
       logo, state, official_website, level, type,
       source, create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std=1443490699776200706;

DELETE FROM dim.dim_std_brand WHERE brand_id_std=1970699754743476226;

/* JP.39 思佳讯-Skyworks (SKYWORKS) <- losers 1443490694034198530 */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), ARRAY<VARCHAR(256)>['SKYWORKS', 'SKY'])),
       logo, state, official_website, level, type,
       source, create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std=1552472092677603330;

DELETE FROM dim.dim_std_brand WHERE brand_id_std=1443490694034198530;

/* JP.40 SparkFun Electronics (SPARKFUN) <- losers 1970700195996839938 */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), ARRAY<VARCHAR(256)>['SPARKFUN'])),
       logo, state, official_website, level, type,
       source, create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std=1443490699776200712;

DELETE FROM dim.dim_std_brand WHERE brand_id_std=1970700195996839938;

/* JP.41 顺络-Sunlord (SUNLORD) <- losers 1970700906285445122 */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), ARRAY<VARCHAR(256)>['SUNLORD ELECTRONICS', 'SUNLORDELECTRONICS'])),
       logo, state, official_website, level, type,
       source, create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std=1443490691236597767;

DELETE FROM dim.dim_std_brand WHERE brand_id_std=1970700906285445122;

/* JP.42 华新科-Walsin (WALSIN) <- losers 1970706292547727362 */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), ARRAY<VARCHAR(256)>['WALSIN TECHNOLOGIES', 'WALSINTECHNOLOGIES'])),
       logo, state, official_website, level, type,
       source, create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std=1443490691173683201;

DELETE FROM dim.dim_std_brand WHERE brand_id_std=1970706292547727362;

/* JP.43 怡远-YIYUAN (YIYUAN) <- losers 1970708782534045697 */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), ARRAY<VARCHAR(256)>['YIYUAN'])),
       logo, state, official_website, level, type,
       source, create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std=1509433828177936386;

DELETE FROM dim.dim_std_brand WHERE brand_id_std=1970708782534045697;

/* ============================================================
 * Soft near-dup merges (USA/International) — web verified 2026-07-09
 * Source: exports/brand_supplement/brand_dup_triage_soft_usa.csv
 * ============================================================ */

/* SOFT.1 瀚荃-Cvilux (CVILUX) <- 9001148 Cvilux USA */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), ARRAY<VARCHAR(256)>['CVILUX USA', 'CVILUXUSA', 'CVILUX U.S.A'])),
       logo, state, official_website, level, type,
       source, create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std=1443490700094967810;

DELETE FROM dim.dim_std_brand WHERE brand_id_std=9001148;

/* SOFT.2 台湾町洋-dinkle (DINKLE) <- 9001173 Dinkle Corporation, USA */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), ARRAY<VARCHAR(256)>['DINKLE CORPORATION, USA', 'DINKLE USA', 'DINKLE CORPORATION USA'])),
       logo, state, official_website, level, type,
       source, create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std=1443490700094967816;

DELETE FROM dim.dim_std_brand WHERE brand_id_std=9001173;

/* SOFT.3 伊娜-ELNA (ELNA) <- 9001964 Elna America */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), ARRAY<VARCHAR(256)>['ELNA AMERICA', 'ELNAAMERICA', 'ELNA AMERICA, INC.'])),
       logo, state, official_website, level, type,
       source, create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std=1443490691630862343;

DELETE FROM dim.dim_std_brand WHERE brand_id_std=9001964;

/* SOFT.4 METZ CONNECT (METZCONNECT) <- 9001144 METZ CONNECT USA Inc. */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), ARRAY<VARCHAR(256)>['METZ CONNECT USA INC.', 'METZ CONNECT USA', 'METZCONNECTUSA'])),
       logo, state, official_website, level, type,
       source, create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std=1443490700350820353;

DELETE FROM dim.dim_std_brand WHERE brand_id_std=9001144;

/* SOFT.5 PHIHONG (PHIHONG) <- 9001387 Phihong USA */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), ARRAY<VARCHAR(256)>['PHIHONG USA', 'PHIHONGUSA', 'PHIHONG USA CORP.'])),
       logo, state, official_website, level, type,
       source, create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std=9001374;

DELETE FROM dim.dim_std_brand WHERE brand_id_std=9001387;

/* SOFT.6 Iriso Electronic (IRISO) <- 9001166 IRISO USA Inc. */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), ARRAY<VARCHAR(256)>['IRISO USA INC.', 'IRISO USA', 'IRISO U.S.A., INC.'])),
       logo, state, official_website, level, type,
       source, create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std=1970678757277503489;

DELETE FROM dim.dim_std_brand WHERE brand_id_std=9001166;

/* SOFT.7 强茂-Panjit (PANJIT) <- 9000542 Panjit International */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), ARRAY<VARCHAR(256)>['PANJIT INTERNATIONAL', 'PANJIT INTERNATIONAL INC.', 'PANJITINTERNATIONAL'])),
       logo, state, official_website, level, type,
       source, create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std=1443490693186949127;

DELETE FROM dim.dim_std_brand WHERE brand_id_std=9000542;

/* SOFT.8 英联-Union (UNION) <- 9002171 Union Semiconductor International Limited */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), ARRAY<VARCHAR(256)>['UNION SEMICONDUCTOR INTERNATIONAL LIMITED', 'UNION SEMICONDUCTOR', 'UNIONSEMI', 'UNION-IC'])),
       logo, state, official_website, level, type,
       source, create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std=1443490697502887940;

DELETE FROM dim.dim_std_brand WHERE brand_id_std=9002171;

/* SOFT.8b 厚声误挂 UNION SEMICONDUCTOR → 清掉，避免抢英联别名（id 更小会赢 ROW_NUMBER） */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_remove(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), 'UNION SEMICONDUCTOR'),
       logo, state, official_website, level, type,
       source, create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std=1443490691106574338;

/* SOFT.9 ECS (ECS) <- 1970678249347289089 ECS International */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)), ARRAY<VARCHAR(256)>['ECS INTERNATIONAL', 'ECS INC. INTERNATIONAL', 'ECS INC INTERNATIONAL'])),
       logo, state, official_website, level, type,
       source, create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std=1443490695988744193;

DELETE FROM dim.dim_std_brand WHERE brand_id_std=1970678249347289089;
