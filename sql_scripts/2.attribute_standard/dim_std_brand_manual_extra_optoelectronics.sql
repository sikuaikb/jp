/* ============================================================
 * optoelectronics_digikey_brand_gaps — 得捷光电器件品牌别名补缺
 * 生成日期: 2026-06-18
 * 来源 TSV: tmp/optoelectronics/artifacts/optoelectronics_brand_gap_audit_20260617.tsv
 * 种子 CSV: tmp/optoelectronics/seed/optoelectronics_brand_alias_seed.csv
 *
 * 生效: bash sql_scripts/2.attribute_standard/sync_dim_std_brand.sh test
 *       沙盒重刷见 tmp/optoelectronics/scripts/apply_brand_aliases_test_dim.sh
 * ============================================================ */

/* A.opto DigiKey/Cree (3行) */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr,
       array_distinct(array_concat(
           COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)),
           ARRAY<VARCHAR(256)>['DIGIKEY/CREE', 'DigiKey/Cree', 'DIGIKEY', 'CREE']
       )),
       logo, state, official_website, level, type,
       'jp_brand+manual_extra', create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std = 1443490693509910534;

/* A.opto Brady Corporation (10行) */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr,
       array_distinct(array_concat(
           COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)),
           ARRAY<VARCHAR(256)>['BRADY CORPORATION', 'Brady Corporation', 'BRADY']
       )),
       logo, state, official_website, level, type,
       'jp_brand+manual_extra', create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std = 1498585602474438657;

/* A.opto RAFI (1行) */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr,
       array_distinct(array_concat(
           COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)),
           ARRAY<VARCHAR(256)>['RAFI']
       )),
       logo, state, official_website, level, type,
       'jp_brand+manual_extra', create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std = 1498592537630265346;

/* A.opto Visual Communications Company - VCC (466行) */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr,
       array_distinct(array_concat(
           COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)),
           ARRAY<VARCHAR(256)>['VISUAL COMMUNICATIONS COMPANY - VCC', 'Visual Communications Company - VCC', 'VISUAL']
       )),
       logo, state, official_website, level, type,
       'jp_brand+manual_extra', create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std = 1498595370211528705;

/* B.opto 新增：jp_brand 无收录（brand_id_std 9_000_xxx 段） */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
VALUES
(9001081, 'American Opto Plus LED', NULL, 'American Opto Plus LED', 'AOP', ARRAY<VARCHAR(256)>['AMERICAN OPTO PLUS LED', 'American Opto Plus LED', 'OPTO PLUS LED CORP.', 'AMERICAN OPTO PLUS', 'OPTO PLUS LED', 'AMERICAN', 'OPTO'], NULL, 1, NULL, NULL, NULL, 'optoelectronics_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP())  /* 292 行 与 OPTO PLUS LED CORP. 同组 */,
(9001082, 'Excelitas Technologies', NULL, 'Excelitas Technologies', 'EXL', ARRAY<VARCHAR(256)>['EXCELITAS TECHNOLOGIES', 'Excelitas Technologies', 'EXCELITAS'], NULL, 1, NULL, NULL, NULL, 'optoelectronics_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP())  /* 981 行 jp_brand 无母公司 */,
(9001083, 'Bivar Inc.', NULL, 'Bivar Inc.', 'BVR', ARRAY<VARCHAR(256)>['BIVAR INC.', 'Bivar Inc.', 'BIVAR'], NULL, 1, NULL, NULL, NULL, 'optoelectronics_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP())  /* 701 行  */,
(9001084, 'Inolux', NULL, 'Inolux', 'INX', ARRAY<VARCHAR(256)>['INOLUX', 'Inolux'], NULL, 1, NULL, NULL, NULL, 'optoelectronics_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP())  /* 357 行  */,
(9001085, 'EPIGAP OSA Photonics', NULL, 'EPIGAP OSA Photonics', 'EPG', ARRAY<VARCHAR(256)>['EPIGAP OSA PHOTONICS', 'EPIGAP OSA Photonics', 'EPIGAP'], NULL, 1, NULL, NULL, NULL, 'optoelectronics_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP())  /* 171 行  */,
(9001086, 'ChromeLED', NULL, 'ChromeLED', 'CHR', ARRAY<VARCHAR(256)>['CHROMELED', 'ChromeLED'], NULL, 1, NULL, NULL, NULL, 'optoelectronics_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP())  /* 139 行  */,
(9001087, 'Quelighting Corp', NULL, 'Quelighting Corp', 'QTL', ARRAY<VARCHAR(256)>['QUELIGHTING CORP', 'Quelighting Corp', 'QUELIGHTING'], NULL, 1, NULL, NULL, NULL, 'optoelectronics_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP())  /* 113 行  */,
(9001088, 'JKL Components Corp.', NULL, 'JKL Components Corp.', 'JKL', ARRAY<VARCHAR(256)>['JKL COMPONENTS CORP.', 'JKL Components Corp.', 'JKL COMPONENTS', 'JKL'], NULL, 1, NULL, NULL, NULL, 'optoelectronics_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP())  /* 82 行  */,
(9001089, 'Lumimax Optoelectronic Technology', NULL, 'Lumimax Optoelectronic Technology', 'LMX', ARRAY<VARCHAR(256)>['LUMIMAX OPTOELECTRONIC TECHNOLOGY', 'Lumimax Optoelectronic Technology', 'LUMIMAX'], NULL, 1, NULL, NULL, NULL, 'optoelectronics_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP())  /* 72 行  */,
(9001090, 'Advanced Photonix', NULL, 'Advanced Photonix', 'APX', ARRAY<VARCHAR(256)>['ADVANCED PHOTONIX', 'Advanced Photonix', 'ADVANCED'], NULL, 1, NULL, NULL, NULL, 'optoelectronics_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP())  /* 65 行 非 ADI/AMD 系 */,
(9001091, 'XSSY Optoelectronics', NULL, 'XSSY Optoelectronics', 'XSS', ARRAY<VARCHAR(256)>['XSSY OPTOELECTRONICS CO.,LTD.', 'XSSY Optoelectronics Co.,Ltd.', 'XSSY OPTOELECTRONICS CO.', 'XSSY OPTOELECTRONICS', 'XSSY'], NULL, 1, NULL, NULL, NULL, 'optoelectronics_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP())  /* 57 行  */,
(9001092, 'NextGen Components', NULL, 'NextGen Components', 'NGC', ARRAY<VARCHAR(256)>['NEXTGEN COMPONENTS', 'NextGen Components', 'NEXTGEN'], NULL, 1, NULL, NULL, NULL, 'optoelectronics_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP())  /* 50 行  */,
(9001093, 'Inspired LED', NULL, 'Inspired LED', 'INS', ARRAY<VARCHAR(256)>['INSPIRED LED, LLC', 'Inspired LED, LLC', 'INSPIRED LED', 'INSPIRED'], NULL, 1, NULL, NULL, NULL, 'optoelectronics_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP())  /* 49 行 去掉 LLC 作 name */,
(9001094, 'Luxtech', NULL, 'Luxtech', 'LXT', ARRAY<VARCHAR(256)>['LUXTECH, LLC', 'Luxtech, LLC', 'LUXTECH,', 'LUXTECH'], NULL, 1, NULL, NULL, NULL, 'optoelectronics_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP())  /* 29 行  */,
(9001095, 'Opto Diode Corp', NULL, 'Opto Diode Corp', 'ODC', ARRAY<VARCHAR(256)>['OPTO DIODE CORP', 'Opto Diode Corp', 'OPTO DIODE', 'OPTO'], NULL, 1, NULL, NULL, NULL, 'optoelectronics_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP())  /* 28 行  */,
(9001096, 'Lighting Science Group', NULL, 'Lighting Science Group', 'LSG', ARRAY<VARCHAR(256)>['LIGHTING SCIENCE GROUP CORPORATION', 'Lighting Science Group Corporation', 'LIGHTING'], NULL, 1, NULL, NULL, NULL, 'optoelectronics_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP())  /* 26 行  */,
(9001097, 'ORIENTAL TECHNOLOGY', NULL, 'ORIENTAL TECHNOLOGY', 'ORT', ARRAY<VARCHAR(256)>['ORIENTAL TECHNOLOGY', 'ORIENTAL'], NULL, 1, NULL, NULL, NULL, 'optoelectronics_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP())  /* 10 行 非东微-ORIENTAL SEMI */,
(9001098, 'Kyoto Semiconductor', NULL, 'Kyoto Semiconductor', 'KYS', ARRAY<VARCHAR(256)>['KYOTO SEMICONDUCTOR', 'Kyoto Semiconductor', 'KYOTO'], NULL, 1, NULL, NULL, NULL, 'optoelectronics_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP())  /* 7 行  */,
(9001099, 'VaOpto', NULL, 'VaOpto', 'VAP', ARRAY<VARCHAR(256)>['VAOPTO', 'VaOpto'], NULL, 1, NULL, NULL, NULL, 'optoelectronics_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP())  /* 5 行  */,
(9001100, 'Enfis', NULL, 'Enfis', 'ENF', ARRAY<VARCHAR(256)>['ENFIS', 'Enfis'], NULL, 1, NULL, NULL, NULL, 'optoelectronics_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP())  /* 4 行  */,
(9001101, 'Hatch Lighting', NULL, 'Hatch Lighting', 'HAT', ARRAY<VARCHAR(256)>['HATCH LIGHTING', 'Hatch Lighting', 'HATCH'], NULL, 1, NULL, NULL, NULL, 'optoelectronics_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP())  /* 3 行  */,
(9001102, 'Ledil', NULL, 'Ledil', 'LDL', ARRAY<VARCHAR(256)>['LEDIL', 'Ledil'], NULL, 1, NULL, NULL, NULL, 'optoelectronics_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP())  /* 3 行  */,
(9001103, 'Kitronik', NULL, 'Kitronik', 'KIT', ARRAY<VARCHAR(256)>['KITRONIK LTD.', 'Kitronik Ltd.', 'KITRONIK'], NULL, 1, NULL, NULL, NULL, 'optoelectronics_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP())  /* 2 行  */,
(9001104, 'NMB Technologies', NULL, 'NMB Technologies', 'NMB', ARRAY<VARCHAR(256)>['NMB TECHNOLOGIES CORPORATION', 'NMB Technologies Corporation', 'NMB'], NULL, 1, NULL, NULL, NULL, 'optoelectronics_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP())  /* 2 行  */,
(9001105, 'Industrial Fiber Optics', NULL, 'Industrial Fiber Optics', 'IFO', ARRAY<VARCHAR(256)>['INDUSTRIAL FIBER OPTICS', 'Industrial Fiber Optics', 'INDUSTRIAL'], NULL, 1, NULL, NULL, NULL, 'optoelectronics_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP())  /* 2 行  */,
(9001106, 'Mag-LED Solutions', NULL, 'Mag-LED Solutions', 'MLS', ARRAY<VARCHAR(256)>['MAG-LED SOLUTIONS', 'Mag-LED Solutions', 'MAG-LED'], NULL, 1, NULL, NULL, NULL, 'optoelectronics_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP())  /* 1 行  */,
(9001107, 'Electroverge', NULL, 'Electroverge', 'ELV', ARRAY<VARCHAR(256)>['ELECTROVERGE', 'Electroverge'], NULL, 1, NULL, NULL, NULL, 'optoelectronics_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP())  /* 1 行  */,
(9001108, 'Custom Computer Services', NULL, 'Custom Computer Services', 'CCS', ARRAY<VARCHAR(256)>['CUSTOM COMPUTER SERVICES INC.', 'Custom Computer Services Inc.', 'CUSTOM COMPUTER SERVICES', 'CUSTOM'], NULL, 1, NULL, NULL, NULL, 'optoelectronics_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP())  /* 1 行  */,
(9001109, 'emcfixSHOP', NULL, 'emcfixSHOP', 'EMC', ARRAY<VARCHAR(256)>['EMCFIXSHOP', 'emcfixSHOP'], NULL, 1, NULL, NULL, NULL, 'optoelectronics_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP())  /* 1 行  */,
(9001110, 'Feztek', NULL, 'Feztek', 'FZT', ARRAY<VARCHAR(256)>['FEZTEK', 'Feztek'], NULL, 1, NULL, NULL, NULL, 'optoelectronics_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP())  /* 1 行  */;

/* C.opto 制造商字段 enrich（得捷 brandshort 空、宽表走 prajson「制造商」join） */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr,
       array_distinct(array_concat(
           COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)),
           ARRAY<VARCHAR(256)>['KINGBRIGHT']
       )),
       logo, state, official_website, level, type,
       'jp_brand+manual_extra', create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std = 1443490694432657418;

INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr,
       array_distinct(array_concat(
           COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)),
           ARRAY<VARCHAR(256)>['CREE LED']
       )),
       logo, state, official_website, level, type,
       'jp_brand+manual_extra', create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std = 1443490693509910534;

INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr,
       array_distinct(array_concat(
           COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)),
           ARRAY<VARCHAR(256)>['LITE-ON INC.', 'LITE-ON INC']
       )),
       logo, state, official_website, level, type,
       'jp_brand+manual_extra', create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std = 1443490693442801671;

INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr,
       array_distinct(array_concat(
           COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)),
           ARRAY<VARCHAR(256)>['LUMEX OPTO/COMPONENTS INC.', 'LUMEX OPTO/COMPONENTS']
       )),
       logo, state, official_website, level, type,
       'jp_brand+manual_extra', create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std = 1452893556589838338;

INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr,
       array_distinct(array_concat(
           COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)),
           ARRAY<VARCHAR(256)>['VISHAY SEMICONDUCTOR OPTO DIVISION']
       )),
       logo, state, official_website, level, type,
       'jp_brand+manual_extra', create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std = 1443490691043659780;

INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr,
       array_distinct(array_concat(
           COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)),
           ARRAY<VARCHAR(256)>['BRIDGELUX']
       )),
       logo, state, official_website, level, type,
       'jp_brand+manual_extra', create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std = 1443490695015665667;

INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr,
       array_distinct(array_concat(
           COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)),
           ARRAY<VARCHAR(256)>['VENKEL']
       )),
       logo, state, official_website, level, type,
       'jp_brand+manual_extra', create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std = 9000577;

INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr,
       array_distinct(array_concat(
           COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)),
           ARRAY<VARCHAR(256)>['SAMSUNG SEMICONDUCTOR, INC.', 'SAMSUNG SEMICONDUCTOR INC.']
       )),
       logo, state, official_website, level, type,
       'jp_brand+manual_extra', create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std = 1443490691043659781;

/* D.opto ICPDF brandshort 补缺（2026-07-07，详见 test/optoelectronics/audit/apply_brand_supplement_icpdf.sql） */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr,
       array_distinct(array_concat(
           COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)),
           ARRAY<VARCHAR(256)>['CML', 'CHICAGO MINIATURE LAMP', 'CHICAGO MINIATURE']
       )),
       logo, state, official_website, level, type,
       'jp_brand+manual_extra', create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std = 1498595370211528705;

INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr,
       array_distinct(array_concat(
           COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)),
           ARRAY<VARCHAR(256)>['ADVANCEDPHOTONIX', 'ADVANCED PHOTONIX INC']
       )),
       logo, state, official_website, level, type,
       'optoelectronics_icpdf_extra', create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std = 9001090;

INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr,
       array_distinct(array_concat(
           COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)),
           ARRAY<VARCHAR(256)>['OSA', 'OSA OPTO LIGHT', 'OSA OPTO LIGHT GMBH']
       )),
       logo, state, official_website, level, type,
       'optoelectronics_icpdf_extra', create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std = 9001460;

INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr,
       array_distinct(array_concat(
           COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)),
           ARRAY<VARCHAR(256)>['LUCKY-LIGHT', 'LUCKY LIGHT']
       )),
       logo, state, official_website, level, type,
       'optoelectronics_icpdf_extra', create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std = 1443490695082774536;

INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr,
       array_distinct(array_concat(
           COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)),
           ARRAY<VARCHAR(256)>['ASSMANN', 'ASSMANN WSW']
       )),
       logo, state, official_website, level, type,
       'optoelectronics_icpdf_extra', create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std = 9001180;

INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr,
       array_distinct(array_concat(
           COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)),
           ARRAY<VARCHAR(256)>['WINCHESTER', 'WINCHESTER INTERCONNECT']
       )),
       logo, state, official_website, level, type,
       'optoelectronics_icpdf_extra', create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std = 9001151;

INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr,
       array_distinct(array_concat(
           COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)),
           ARRAY<VARCHAR(256)>['ICHAUS', 'IC HAUS']
       )),
       logo, state, official_website, level, type,
       'optoelectronics_icpdf_extra', create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std = 1443490696252985354;

INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr,
       array_distinct(array_concat(
           COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)),
           ARRAY<VARCHAR(256)>['IDEA']
       )),
       logo, state, official_website, level, type,
       'optoelectronics_icpdf_extra', create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std = 1443490695665782791;

INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
VALUES
(9001111, 'Source Photonics', NULL, 'Source Photonics, Inc.', 'SRC',
 ARRAY<VARCHAR(256)>['SOURCE', 'SOURCE PHOTONICS', 'SOURCE PHOTONICS INC', 'SOURCE PHOTONICS, INC.'],
 NULL, 1, NULL, NULL, NULL, 'optoelectronics_icpdf_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001112, 'DB Lectro Inc.', NULL, 'DB Lectro Inc.', 'DBL',
 ARRAY<VARCHAR(256)>['DBLECTRO', 'DB LECTRO', 'DB LECTRO INC'],
 NULL, 1, NULL, NULL, NULL, 'optoelectronics_icpdf_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001113, 'Yellow Stone Corp', '早安', 'Yellow Stone Corp', 'YST',
 ARRAY<VARCHAR(256)>['YSTONE', 'YELLOW STONE', 'YELLOW STONE CORP', '早安股份有限公司'],
 NULL, 1, NULL, NULL, NULL, 'optoelectronics_icpdf_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001114, 'P-tec Corporation', NULL, 'P-tec Corporation', 'PTC',
 ARRAY<VARCHAR(256)>['P-TEC', 'P TEC', 'P-TEC CORPORATION', 'P-TEC CORP'],
 NULL, 1, NULL, NULL, NULL, 'optoelectronics_icpdf_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001115, 'A-BRIGHT Industrial', NULL, 'A-BRIGHT Industrial Co., Ltd', 'ABR',
 ARRAY<VARCHAR(256)>['A-BRIGHT', 'A BRIGHT', 'A-BRIGHT INC', 'A-BRIGHT INDUSTRIAL'],
 NULL, 1, NULL, NULL, NULL, 'optoelectronics_icpdf_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001116, 'Semelab Ltd', NULL, 'Semelab Ltd', 'SML',
 ARRAY<VARCHAR(256)>['SEME-LAB', 'SEMELAB', 'SEME LAB'],
 NULL, 1, NULL, NULL, NULL, 'optoelectronics_icpdf_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001117, 'China Semiconductor', NULL, 'China Semiconductor', 'CHS',
 ARRAY<VARCHAR(256)>['CHINASEMI', 'CHINA SEMI', 'CHINA SEMICONDUCTOR'],
 NULL, 1, NULL, NULL, NULL, 'optoelectronics_icpdf_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001118, 'EMCORE Corporation', NULL, 'EMCORE Corporation', 'EMC',
 ARRAY<VARCHAR(256)>['EMCORE', 'EMCORE CORP'],
 NULL, 1, NULL, NULL, NULL, 'optoelectronics_icpdf_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001119, 'Applied Micro Circuits', NULL, 'Applied Micro Circuits Corporation', 'AMC',
 ARRAY<VARCHAR(256)>['AMCC', 'APPLIED MICRO CIRCUITS', 'APPLIED MICRO CIRCUITS CORP'],
 NULL, 1, NULL, NULL, NULL, 'optoelectronics_icpdf_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP());

