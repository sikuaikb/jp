/* logic_ic 试点品牌补缺 — 仅增量，不重建全表 */

/* A.logic_ic.1 IDT */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr,
       array_distinct(array_concat(
           COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)),
           ARRAY<VARCHAR(256)>['QUALITY SEMICONDUCTOR','IDT, INTEGRATED DEVICE TECHNOLOGY INC']
       )),
       logo, state, official_website, level, type,
       'jp_brand+manual_extra', create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std = 1454984321260404738;

/* A.logic_ic.2 AMD */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr,
       array_distinct(array_concat(
           COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)),
           ARRAY<VARCHAR(256)>['ADVANCED MICRO DEVICES']
       )),
       logo, state, official_website, level, type,
       'jp_brand+manual_extra', create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std = 1970677917108080642;

/* A.logic_ic.3 RUNIC */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr,
       array_distinct(array_concat(
           COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)),
           ARRAY<VARCHAR(256)>['RUNIC TECHNOLOGY']
       )),
       logo, state, official_website, level, type,
       'jp_brand+manual_extra', create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std = 1443490697368670213;

INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
VALUES
(9000557, 'Rochester Electronics', NULL, 'Rochester Electronics, LLC', 'ROC',
 ARRAY<VARCHAR(256)>['ROCHESTER ELECTRONICS','ROCHESTER ELECTRONICS, LLC','ROCHESTER ELECTRONICS LLC'],
 NULL, 1, NULL, NULL, NULL, 'digikey_logic_ic_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9000558, 'Flip Electronics', NULL, 'Flip Electronics', 'FLP',
 ARRAY<VARCHAR(256)>['FLIP ELECTRONICS'],
 NULL, 1, NULL, NULL, NULL, 'digikey_logic_ic_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9000559, 'ADSANTEC', NULL, 'ADSANTEC Inc.', 'ADS',
 ARRAY<VARCHAR(256)>['ADSANTEC','ADSANTEC INC.'],
 NULL, 1, NULL, NULL, NULL, 'digikey_logic_ic_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9000560, 'TAEJIN Technology', NULL, 'TAEJIN Technology', 'TAJ',
 ARRAY<VARCHAR(256)>['TAEJIN','TAEJIN TECHNOLOGY'],
 NULL, 1, NULL, NULL, NULL, 'digikey_logic_ic_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9000561, 'EVVO', NULL, 'EVVO', 'EVV',
 ARRAY<VARCHAR(256)>['EVVO'],
 NULL, 1, NULL, NULL, NULL, 'digikey_logic_ic_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP());

/* A.logic_ic.4 强茂-Panjit */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr,
       array_distinct(array_concat(
           COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)),
           ARRAY<VARCHAR(256)>['PANJIT INTERNATIONAL INC.']
       )),
       logo, state, official_website, level, type,
       'jp_brand+manual_extra', create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std = 1443490693186949127;

/* A.logic_ic.5 Micrel → Microchip 收购 */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr,
       array_distinct(array_concat(
           COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)),
           ARRAY<VARCHAR(256)>['MICREL INC.']
       )),
       logo, state, official_website, level, type,
       'jp_brand+manual_extra', create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std = 1443490693837066244;
