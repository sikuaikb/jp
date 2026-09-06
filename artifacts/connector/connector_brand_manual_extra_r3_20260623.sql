/* ============================================================
 * connector_digikey_brand_gaps_r3 — 长尾 19 品牌最后一轮 enrich + 新建
 * 生成日期: 2026-06-23
 * ============================================================ */

/* A.r3 FCI Deutschland → Amphenol FCI */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr,
       array_distinct(array_concat(
           COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)),
           ARRAY<VARCHAR(256)>['FCI DEUTSCHLAND GMBH', 'FCI Deutschland GmbH', 'FCI DEUTSCHLAND']
       )),
       logo, state, official_website, level, type,
       'jp_brand+manual_extra', create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std = 1443490692209676298;

/* A.r3 Amphenol 子公司 → Amphenol */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr,
       array_distinct(array_concat(
           COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)),
           ARRAY<VARCHAR(256)>[
             'AMPHENOL WILCOXON SENSING TECHNOLOGIES', 'Amphenol Wilcoxon Sensing Technologies',
             'AMPHENOL ALDEN PRODUCTS COMPANY', 'Amphenol Alden Products Company',
             'AMPHENOL ONANON', 'Amphenol Onanon'
           ]
       )),
       logo, state, official_website, level, type,
       'jp_brand+manual_extra', create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std = 1494518929597435906;

/* A.r3 Delta Industrial Automation → 台达 */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr,
       array_distinct(array_concat(
           COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)),
           ARRAY<VARCHAR(256)>['DELTA ELECTRONICS/INDUSTRIAL AUTOMATION', 'Delta Electronics/Industrial Automation', 'DELTA ELECTRONICS/INDUSTRIAL', 'INDUSTRIAL AUTOMATION']
       )),
       logo, state, official_website, level, type,
       'jp_brand+manual_extra', create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std = 1443490697037320202;

/* A.r3 Honeywell Sensing → Honeywell */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr,
       array_distinct(array_concat(
           COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)),
           ARRAY<VARCHAR(256)>['HONEYWELL SENSING AND PRODUCTIVITY SOLUTIONS T&M', 'Honeywell Sensing and Productivity Solutions T&M', 'HONEYWELL SENSING AND PRODUCTIVITY SOLUTIONS']
       )),
       logo, state, official_website, level, type,
       'jp_brand+manual_extra', create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std = 1443490699453239303;

/* A.r3 Eaton Electrical → Eaton */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr,
       array_distinct(array_concat(
           COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)),
           ARRAY<VARCHAR(256)>['EATON ELECTRICAL', 'Eaton Electrical']
       )),
       logo, state, official_website, level, type,
       'jp_brand+manual_extra', create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std = 1443490691630862341;

/* A.r3 Bel Inc. → BEL FUSE */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr,
       array_distinct(array_concat(
           COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)),
           ARRAY<VARCHAR(256)>['BEL INC.', 'Bel Inc.', 'BEL INC']
       )),
       logo, state, official_website, level, type,
       'jp_brand+manual_extra', create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std = 1452878214891163649;

/* B.r3 新建 */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
VALUES
(9001256, 'Chip Quik Inc.', NULL, 'Chip Quik Inc.', 'CHIPQU', ARRAY<VARCHAR(256)>['CHIP QUIK INC.', 'Chip Quik Inc.', 'CHIP QUIK'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001257, 'KEL USA', NULL, 'KEL USA', 'KELUSA', ARRAY<VARCHAR(256)>['KEL USA', 'KEL'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001258, 'Mersen USA Newburyport-MA L.L.C.', NULL, 'Mersen USA Newburyport-MA L.L.C.', 'MERSEN', ARRAY<VARCHAR(256)>['MERSEN USA NEWBURYPORT-MA L.L.C.', 'Mersen USA Newburyport-MA L.L.C.', 'MERSEN USA NEWBURYPORT-MA', 'MERSEN'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001259, 'Central Components Manufacturing', NULL, 'Central Components Manufacturing', 'CENTRA', ARRAY<VARCHAR(256)>['CENTRAL COMPONENTS MANUFACTURING', 'Central Components Manufacturing', 'CENTRAL COMPONENTS', 'CENTRAL'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001260, 'Kinetic Technologies', NULL, 'Kinetic Technologies', 'KINETI', ARRAY<VARCHAR(256)>['KINETIC TECHNOLOGIES', 'Kinetic Technologies', 'KINETIC'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001261, 'GES High Voltage', NULL, 'GES High Voltage', 'GESHV', ARRAY<VARCHAR(256)>['GES HIGH VOLTAGE', 'GES High Voltage', 'GES'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001262, 'Essentra Components', NULL, 'Essentra Components', 'ESSENT', ARRAY<VARCHAR(256)>['ESSENTRA COMPONENTS', 'Essentra Components', 'ESSENTRA'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001263, 'Holt Integrated Circuits Inc.', NULL, 'Holt Integrated Circuits Inc.', 'HOLT', ARRAY<VARCHAR(256)>['HOLT INTEGRATED CIRCUITS INC.', 'Holt Integrated Circuits Inc.', 'HOLT INTEGRATED CIRCUITS', 'HOLT INTEGRATED'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001264, 'NVE Corp/Sensor Products', NULL, 'NVE Corp/Sensor Products', 'NVE', ARRAY<VARCHAR(256)>['NVE CORP/SENSOR PRODUCTS', 'NVE Corp/Sensor Products', 'NVE CORP/SENSOR', 'NVE CORP'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP());
