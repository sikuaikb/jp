/* ============================================================
 * 跨源品牌补录回写（保全 sync 后不丢失）
 *
 * 背景：dim_std_brand.sql sync 时先 DROP 重建（只灌 ods_jp_brand 14 列），
 *       再跑本文件重新应用。DDL 已扩到 17 列（加 country_region/is_domestic/
 *       domestic_type），但 ods_jp_brand 无此 3 列源，sync 后会全 NULL。
 *       以下三段保全所有手工补录数据。
 *
 * 顺序：Part B（新品牌）→ Part C（jp_brand 3 列国产/地区数据）→ Part A（别名）
 *       Part A 在最后，带 17 列 SELECT 保留 Part C 填的 3 列不被覆盖；
 *       Part A 有 2 条别名依赖裸奔品牌，需 Part B 先插回。
 *
 * Part B: 735 个新品牌
 *         - 175 个历史裸奔品牌（源文件已不在仓库，从生产表导出保全）
 *           · digikey_sensor_v1629 / icpdf_data_converter_extra /
 *             manual_extra+clock_timing_dk / connector_digikey
 *         - 560 个本批跨源未命中真新品牌（9001265-9001824）
 * Part C: 2356 个 jp_brand 品牌的 country_region/is_domestic/domestic_type 3 列数据
 *         （ods 无此源，从生产表导出，JOIN 派生表填回，其余 14 列从 b 取）
 * Part A: 25 条高置信度别名（跨源融合 auto 档，带公司后缀写法变体）
 *         → 复用已有 brand_id_std，array_distinct(array_concat) 扩 related_words
 *
 * 幂等：Part B 主键 upsert；Part C JOIN 派生表；Part A array_distinct。可重复执行。
 * ============================================================ */


/* ============================================================
 * B. 跨源 + 历史裸奔新品牌（735 个，从生产表导出）
 * ============================================================ */

INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
VALUES
(9000557, 'NOSHOK', NULL, 'NOSHOK, Inc.', 'NSK', ARRAY<VARCHAR(256)>['[','"','N','O','S','H','O','K','"',',','"','N','O','S','H','O','K',',',' ','I','N','C','.','"',',','"','N','O','S','H','O','K',' ','I','N','C','.','"',',','"','N','O','S','H','O','K',' ','I','N','C','"',']'], NULL, 1, NULL, NULL, NULL, 'digikey_sensor_v1629', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9000558, 'Variohm', NULL, 'Variohm', 'VRH', ARRAY<VARCHAR(256)>['[','"','V','A','R','I','O','H','M','"',',','"','V','A','R','I','O','H','M',' ','E','U','R','O','S','E','N','S','O','R','S','"',']'], NULL, 1, NULL, NULL, NULL, 'digikey_sensor_v1629', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9000559, 'Applied Measurements', NULL, 'Applied Measurements Limited', 'APM', ARRAY<VARCHAR(256)>['[','"','A','P','P','L','I','E','D',' ','M','E','A','S','U','R','E','M','E','N','T','S','"',',','"','A','P','P','L','I','E','D',' ','M','E','A','S','U','R','E','M','E','N','T','S',' ','L','I','M','I','T','E','D','"',']'], NULL, 1, NULL, NULL, NULL, 'digikey_sensor_v1629', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9000560, 'Maker Emporium', NULL, 'Maker Emporium Ltd', 'MKE', ARRAY<VARCHAR(256)>['[','"','M','A','K','E','R',' ','E','M','P','O','R','I','U','M','"',',','"','M','A','K','E','R',' ','E','M','P','O','R','I','U','M',' ','L','T','D','"',']'], NULL, 1, NULL, NULL, NULL, 'digikey_sensor_v1629', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9000561, 'Pololu', NULL, 'Pololu Corporation', 'POL', ARRAY<VARCHAR(256)>['[','"','P','O','L','O','L','U','"',',','"','P','O','L','O','L','U',' ','C','O','R','P','O','R','A','T','I','O','N','"',']'], NULL, 1, NULL, NULL, NULL, 'digikey_sensor_v1629', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9000562, 'Status Instruments', NULL, 'Status Instruments Ltd', 'STS', ARRAY<VARCHAR(256)>['[','"','S','T','A','T','U','S',' ','I','N','S','T','R','U','M','E','N','T','S','"',',','"','S','T','A','T','U','S',' ','I','N','S','T','R','U','M','E','N','T','S',' ','L','T','D','"',']'], NULL, 1, NULL, NULL, NULL, 'digikey_sensor_v1629', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9000563, 'Flip Electronics', NULL, 'Flip Electronics', 'FLE', ARRAY<VARCHAR(256)>['[','"','F','L','I','P',' ','E','L','E','C','T','R','O','N','I','C','S','"',']'], NULL, 1, NULL, NULL, NULL, 'digikey_sensor_v1629', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9000564, 'Cobontech', NULL, 'Cobontech', 'CBT', ARRAY<VARCHAR(256)>['[','"','C','O','B','O','N','T','E','C','H','"',']'], NULL, 1, NULL, NULL, NULL, 'digikey_sensor_v1629', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9000565, 'Advanced Thermal Solutions', NULL, 'Advanced Thermal Solutions Inc.', 'ATS', ARRAY<VARCHAR(256)>['[','"','A','D','V','A','N','C','E','D',' ','T','H','E','R','M','A','L',' ','S','O','L','U','T','I','O','N','S','"',',','"','A','D','V','A','N','C','E','D',' ','T','H','E','R','M','A','L',' ','S','O','L','U','T','I','O','N','S',' ','I','N','C','.','"',']'], NULL, 1, NULL, NULL, NULL, 'digikey_sensor_v1629', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9000566, 'Tronics', NULL, 'Tronics Microsystems', 'TRN', ARRAY<VARCHAR(256)>['[','"','T','R','O','N','I','C','S','"',',','"','T','R','O','N','I','C','S',' ','M','I','C','R','O','S','Y','S','T','E','M','S','"',']'], NULL, 1, NULL, NULL, NULL, 'digikey_sensor_v1629', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9000567, 'Tell-i', NULL, 'Tell-i', 'TLI', ARRAY<VARCHAR(256)>['[','"','T','E','L','L','-','I','"',',','"','T','E','L','L',' ','I','"',']'], NULL, 1, NULL, NULL, NULL, 'digikey_sensor_v1629', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9000569, 'JUMO', NULL, 'JUMO Process Control, Inc.', 'JUM', ARRAY<VARCHAR(256)>['[','"','J','U','M','O',' ','P','R','O','C','E','S','S',' ','C','O','N','T','R','O','L','"',',','"','J','U','M','O',' ','P','R','O','C','E','S','S',' ','C','O','N','T','R','O','L',',',' ','I','N','C','.','"',']'], NULL, 1, NULL, NULL, NULL, 'digikey_sensor_v1629', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9000570, 'Curtis Instruments', NULL, 'Curtis Instruments Inc.', 'CUR', ARRAY<VARCHAR(256)>['[','"','C','U','R','T','I','S',' ','I','N','S','T','R','U','M','E','N','T','S','"',',','"','C','U','R','T','I','S',' ','I','N','S','T','R','U','M','E','N','T','S',' ','I','N','C','.','"',']'], NULL, 1, NULL, NULL, NULL, 'digikey_sensor_v1629', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9000572, 'Trafag', NULL, 'Trafag Sensors and Controls', 'TRF', ARRAY<VARCHAR(256)>['[','"','T','R','A','F','A','G','"',',','"','T','R','A','F','A','G',' ','S','E','N','S','O','R','S',' ','A','N','D',' ','C','O','N','T','R','O','L','S','"',']'], NULL, 1, NULL, NULL, NULL, 'digikey_sensor_v1629', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9000573, 'VersaSense', NULL, 'VersaSense', 'VSS', ARRAY<VARCHAR(256)>['[','"','V','E','R','S','A','S','E','N','S','E','"',']'], NULL, 1, NULL, NULL, NULL, 'digikey_sensor_v1629', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9000574, 'Phoenix America', NULL, 'Phoenix America', 'PHA', ARRAY<VARCHAR(256)>['[','"','P','H','O','E','N','I','X',' ','A','M','E','R','I','C','A','"',']'], NULL, 1, NULL, NULL, NULL, 'digikey_sensor_v1629', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9000575, 'AMBO', NULL, 'AMBO', 'AMB', ARRAY<VARCHAR(256)>['[','"','A','M','B','O','"',']'], NULL, 1, NULL, NULL, NULL, 'digikey_sensor_v1629', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9000576, 'Rincon Power', NULL, 'Rincon Power', 'RNP', ARRAY<VARCHAR(256)>['[','"','R','I','N','C','O','N',' ','P','O','W','E','R','"',']'], NULL, 1, NULL, NULL, NULL, 'digikey_sensor_v1629', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9000600, 'Datel Inc.', NULL, 'Datel Inc.', 'DTL', ARRAY<VARCHAR(256)>['[','"','D','A','T','E','L','"',',','"','D','A','T','E','L',' ','I','N','C','"',',','"','D','A','T','E','L',' ','I','N','C','.','"',']'], NULL, 1, NULL, NULL, NULL, 'icpdf_data_converter_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9000601, 'Raytheon Semiconductor', NULL, 'Raytheon Semiconductor', 'RTN', ARRAY<VARCHAR(256)>['[','"','R','A','Y','T','H','E','O','N','"',',','"','R','A','Y','T','H','E','O','N',' ','S','E','M','I','C','O','N','D','U','C','T','O','R','"',']'], NULL, 1, NULL, NULL, NULL, 'icpdf_data_converter_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9000602, 'Integrated Circuit Microsystems', NULL, 'Integrated Circuit Microsystems', 'ICM', ARRAY<VARCHAR(256)>['[','"','I','C','M','I','C','"',',','"','I','N','T','E','G','R','A','T','E','D',' ','C','I','R','C','U','I','T',' ','M','I','C','R','O','S','Y','S','T','E','M','S','"',']'], NULL, 1, NULL, NULL, NULL, 'icpdf_data_converter_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9000603, 'Sony Semiconductor', NULL, 'Sony Semiconductor Solutions', 'SNY', ARRAY<VARCHAR(256)>['[','"','S','O','N','Y','"',',','"','S','O','N','Y',' ','S','E','M','I','C','O','N','D','U','C','T','O','R','"',']'], NULL, 1, NULL, NULL, NULL, 'icpdf_data_converter_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9000604, 'AMSCO', NULL, 'AMSCO', 'AMC', ARRAY<VARCHAR(256)>['[','"','A','M','S','C','O','"',']'], NULL, 1, NULL, NULL, NULL, 'icpdf_data_converter_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9000605, 'Dynex Semiconductor', NULL, 'Dynex Semiconductor Ltd.', 'DYN', ARRAY<VARCHAR(256)>['[','"','D','Y','N','E','X','"',',','"','D','Y','N','E','X',' ','S','E','M','I','C','O','N','D','U','C','T','O','R','"',']'], NULL, 1, NULL, NULL, NULL, 'icpdf_data_converter_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9000606, 'Austin Semiconductor Inc.', NULL, 'Austin Semiconductor Inc.', 'AUS', ARRAY<VARCHAR(256)>['[','"','A','U','S','T','I','N','"',',','"','A','U','S','T','I','N',' ','S','E','M','I','C','O','N','D','U','C','T','O','R','"',']'], NULL, 1, NULL, NULL, NULL, 'icpdf_data_converter_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9000607, 'Lansdale Semiconductor Inc.', NULL, 'Lansdale Semiconductor Inc.', 'LSD', ARRAY<VARCHAR(256)>['[','"','L','A','N','S','D','A','L','E','"',',','"','L','A','N','S','D','A','L','E',' ','S','E','M','I','C','O','N','D','U','C','T','O','R','"',']'], NULL, 1, NULL, NULL, NULL, 'icpdf_data_converter_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9000608, 'Summit Microelectronics', NULL, 'Summit Microelectronics', 'SMT', ARRAY<VARCHAR(256)>['[','"','S','U','M','M','I','T','"',',','"','S','U','M','M','I','T',' ','M','I','C','R','O','E','L','E','C','T','R','O','N','I','C','S','"',']'], NULL, 1, NULL, NULL, NULL, 'icpdf_data_converter_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9000609, 'AIMtron Technology', NULL, 'AIMtron Technology Inc.', 'AIM', ARRAY<VARCHAR(256)>['[','"','A','I','M','T','R','O','N','"',',','"','A','I','M','T','R','O','N',' ','T','E','C','H','N','O','L','O','G','Y','"',']'], NULL, 1, NULL, NULL, NULL, 'icpdf_data_converter_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9000610, 'Yamaha Corporation', NULL, 'Yamaha Corporation', 'YMH', ARRAY<VARCHAR(256)>['[','"','Y','A','M','A','H','A','"',']'], NULL, 1, NULL, NULL, NULL, 'icpdf_data_converter_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9000611, 'Averlogic Inc.', NULL, 'Averlogic Inc.', 'AVL', ARRAY<VARCHAR(256)>['[','"','A','V','E','R','L','O','G','I','C','"',',','"','A','V','E','R','L','O','G','I','C',' ','I','N','C','"',']'], NULL, 1, NULL, NULL, NULL, 'icpdf_data_converter_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001064, 'TGS', NULL, 'TGS', 'TGS', ARRAY<VARCHAR(256)>['[','"','T','G','S','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra+clock_timing_dk', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001065, 'Geyer Electronic', NULL, 'Geyer Electronic America, Inc.', 'GEY', ARRAY<VARCHAR(256)>['[','"','G','E','Y','E','R',' ','E','L','E','C','T','R','O','N','I','C',' ','A','M','E','R','I','C','A',',',' ','I','N','C','.','"',',','"','G','E','Y','E','R',' ','E','L','E','C','T','R','O','N','I','C',' ','A','M','E','R','I','C','A',' ','I','N','C','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra+clock_timing_dk', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001066, 'HKC', NULL, 'HKC', 'HKC', ARRAY<VARCHAR(256)>['[','"','H','K','C','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra+clock_timing_dk', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001067, 'MMD', NULL, 'MMD', 'MMD', ARRAY<VARCHAR(256)>['[','"','M','M','D','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra+clock_timing_dk', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001068, 'Cardinal Components', NULL, 'Cardinal Components Inc.', 'CDL', ARRAY<VARCHAR(256)>['[','"','C','A','R','D','I','N','A','L',' ','C','O','M','P','O','N','E','N','T','S',' ','I','N','C','.','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra+clock_timing_dk', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001069, 'Transko Electronics', NULL, 'Transko Electronics, Inc.', 'TRK', ARRAY<VARCHAR(256)>['[','"','T','R','A','N','S','K','O',' ','E','L','E','C','T','R','O','N','I','C','S',',',' ','I','N','C','.','"',',','"','T','R','A','N','S','K','O',' ','E','L','E','C','T','R','O','N','I','C','S',' ','I','N','C','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra+clock_timing_dk', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001070, 'Golledge Electronics', NULL, 'Golledge Electronics Ltd', 'GOL', ARRAY<VARCHAR(256)>['[','"','G','O','L','L','E','D','G','E',' ','E','L','E','C','T','R','O','N','I','C','S',' ','L','T','D','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra+clock_timing_dk', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001071, 'Harmony Electronics', NULL, 'Harmony Electronics Corp', 'HAR', ARRAY<VARCHAR(256)>['[','"','H','A','R','M','O','N','Y',' ','E','L','E','C','T','R','O','N','I','C','S',' ','C','O','R','P',' ','/',' ','H','.','E','L','E','.','"',',','"','H','A','R','M','O','N','Y',' ','E','L','E','C','T','R','O','N','I','C','S',' ','C','O','R','P','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra+clock_timing_dk', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001072, 'Pletronics', NULL, 'Pletronics, Inc', 'PLE', ARRAY<VARCHAR(256)>['[','"','P','L','E','T','R','O','N','I','C','S',',',' ','I','N','C','"',',','"','P','L','E','T','R','O','N','I','C','S',' ','I','N','C','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra+clock_timing_dk', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001073, 'IBM', NULL, 'IBM', 'IBM', ARRAY<VARCHAR(256)>['[','"','I','B','M','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra+clock_timing_dk', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001074, 'Yangxing Technology', NULL, 'Shenzhen Yangxing Technology Co.,Ltd', 'YXT', ARRAY<VARCHAR(256)>['[','"','S','H','E','N','Z','H','E','N',' ','Y','A','N','G','X','I','N','G',' ','T','E','C','H','N','O','L','O','G','Y',' ','C','O','.',',','L','T','D','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra+clock_timing_dk', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001075, 'Cymbet Corporation', NULL, 'Cymbet Corporation', 'CYM', ARRAY<VARCHAR(256)>['[','"','C','Y','M','B','E','T',' ','C','O','R','P','O','R','A','T','I','O','N','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra+clock_timing_dk', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001076, 'Prowave', NULL, 'Prowave', 'PRW', ARRAY<VARCHAR(256)>['[','"','P','R','O','W','A','V','E','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra+clock_timing_dk', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001077, 'Simtek', NULL, 'Simtek', 'SIM', ARRAY<VARCHAR(256)>['[','"','S','I','M','T','E','K','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra+clock_timing_dk', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001078, 'Oscilent', NULL, 'Oscilent', 'OSC', ARRAY<VARCHAR(256)>['[','"','O','S','C','I','L','E','N','T','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra+clock_timing_dk', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001079, 'NextGen Components', NULL, 'NextGen Components', 'NGC', ARRAY<VARCHAR(256)>['[','"','N','E','X','T','G','E','N',' ','C','O','M','P','O','N','E','N','T','S','"',',','"','N','E','X','T','G','E','N',' ','C','O','M','P','O','N','E','N','T','S',' ','G','R','O','U','P','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra+clock_timing_dk', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001080, 'Hefei Jingweite Electronics', NULL, 'Hefei Jingweite Electronics Co., Ltd.', 'JWE', ARRAY<VARCHAR(256)>['[','"','H','E','F','E','I',' ','J','I','N','G','W','E','I','T','E',' ','E','L','E','C','T','R','O','N','I','C','S',' ','C','O','.',',',' ','L','T','D','.','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra+clock_timing_dk', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001137, 'Agere Systems', NULL, 'Agere Systems', 'AGR', ARRAY<VARCHAR(256)>['[','"','A','G','E','R','E',' ','S','Y','S','T','E','M','S','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra+clock_timing_dk', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001138, 'Touchstone Semiconductor', NULL, 'Touchstone Semiconductor', 'TSS', ARRAY<VARCHAR(256)>['[','"','T','O','U','C','H','S','T','O','N','E',' ','S','E','M','I','C','O','N','D','U','C','T','O','R','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra+clock_timing_dk', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001139, 'Ambiq Micro', NULL, 'Ambiq Micro, Inc.', 'AMQ', ARRAY<VARCHAR(256)>['[','"','A','M','B','I','Q',' ','M','I','C','R','O',',',' ','I','N','C','.','"',',','"','A','M','B','I','Q',' ','M','I','C','R','O',' ','I','N','C','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra+clock_timing_dk', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001140, 'Fischer Elektronik', NULL, 'Fischer Elektronik', 'FISCHE', ARRAY<VARCHAR(256)>['[','"','F','I','S','C','H','E','R',' ','E','L','E','K','T','R','O','N','I','K','"',',','"','F','i','s','c','h','e','r',' ','E','l','e','k','t','r','o','n','i','k','"',',','"','F','I','S','C','H','E','R','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001141, 'Curtis Industries', NULL, 'Curtis Industries', 'CURTIS', ARRAY<VARCHAR(256)>['[','"','C','U','R','T','I','S',' ','I','N','D','U','S','T','R','I','E','S','"',',','"','C','u','r','t','i','s',' ','I','n','d','u','s','t','r','i','e','s','"',',','"','C','U','R','T','I','S','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001142, 'On Shore Technology Inc.', NULL, 'On Shore Technology Inc.', 'ON', ARRAY<VARCHAR(256)>['[','"','O','N',' ','S','H','O','R','E',' ','T','E','C','H','N','O','L','O','G','Y',' ','I','N','C','.','"',',','"','O','n',' ','S','h','o','r','e',' ','T','e','c','h','n','o','l','o','g','y',' ','I','n','c','.','"',',','"','O','N',' ','S','H','O','R','E',' ','T','E','C','H','N','O','L','O','G','Y','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001143, 'Aries Electronics', NULL, 'Aries Electronics', 'ARIES', ARRAY<VARCHAR(256)>['[','"','A','R','I','E','S',' ','E','L','E','C','T','R','O','N','I','C','S','"',',','"','A','r','i','e','s',' ','E','l','e','c','t','r','o','n','i','c','s','"',',','"','A','R','I','E','S','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001144, 'METZ CONNECT USA Inc.', NULL, 'METZ CONNECT USA Inc.', 'METZ', ARRAY<VARCHAR(256)>['[','"','M','E','T','Z',' ','C','O','N','N','E','C','T',' ','U','S','A',' ','I','N','C','.','"',',','"','M','E','T','Z',' ','C','O','N','N','E','C','T',' ','U','S','A',' ','I','n','c','.','"',',','"','M','E','T','Z',' ','C','O','N','N','E','C','T',' ','U','S','A','"',',','"','M','E','T','Z','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001145, 'Lumberg Automation', NULL, 'Lumberg Automation', 'LUMBER', ARRAY<VARCHAR(256)>['[','"','L','U','M','B','E','R','G',' ','A','U','T','O','M','A','T','I','O','N','"',',','"','L','u','m','b','e','r','g',' ','A','u','t','o','m','a','t','i','o','n','"',',','"','L','U','M','B','E','R','G','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001146, 'Phyton Inc.', NULL, 'Phyton Inc.', 'PHYTON', ARRAY<VARCHAR(256)>['[','"','P','H','Y','T','O','N',' ','I','N','C','.','"',',','"','P','h','y','t','o','n',' ','I','n','c','.','"',',','"','P','H','Y','T','O','N','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001147, 'HALO Electronics, Inc.', NULL, 'HALO Electronics, Inc.', 'HALO', ARRAY<VARCHAR(256)>['[','"','H','A','L','O',' ','E','L','E','C','T','R','O','N','I','C','S',',',' ','I','N','C','.','"',',','"','H','A','L','O',' ','E','l','e','c','t','r','o','n','i','c','s',',',' ','I','n','c','.','"',',','"','H','A','L','O',' ','E','L','E','C','T','R','O','N','I','C','S','"',',','"','H','A','L','O','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001148, 'Cvilux USA', NULL, 'Cvilux USA', 'CVILUX', ARRAY<VARCHAR(256)>['[','"','C','V','I','L','U','X',' ','U','S','A','"',',','"','C','v','i','l','u','x',' ','U','S','A','"',',','"','C','V','I','L','U','X','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001149, 'Ease Electronics', NULL, 'Ease Electronics', 'EASE', ARRAY<VARCHAR(256)>['[','"','E','A','S','E',' ','E','L','E','C','T','R','O','N','I','C','S','"',',','"','E','a','s','e',' ','E','l','e','c','t','r','o','n','i','c','s','"',',','"','E','A','S','E','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001150, 'Oupiin', NULL, 'Oupiin', 'OUPIIN', ARRAY<VARCHAR(256)>['[','"','O','U','P','I','I','N','"',',','"','O','u','p','i','i','n','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001151, 'Winchester Interconnect', NULL, 'Winchester Interconnect', 'WINCHE', ARRAY<VARCHAR(256)>['[','"','W','I','N','C','H','E','S','T','E','R',' ','I','N','T','E','R','C','O','N','N','E','C','T','"',',','"','W','i','n','c','h','e','s','t','e','r',' ','I','n','t','e','r','c','o','n','n','e','c','t','"',',','"','W','I','N','C','H','E','S','T','E','R','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001152, 'CLIFF Electronic Components Ltd', NULL, 'CLIFF Electronic Components Ltd', 'CLIFF', ARRAY<VARCHAR(256)>['[','"','C','L','I','F','F',' ','E','L','E','C','T','R','O','N','I','C',' ','C','O','M','P','O','N','E','N','T','S',' ','L','T','D','"',',','"','C','L','I','F','F',' ','E','l','e','c','t','r','o','n','i','c',' ','C','o','m','p','o','n','e','n','t','s',' ','L','t','d','"',',','"','C','L','I','F','F',' ','E','L','E','C','T','R','O','N','I','C',' ','C','O','M','P','O','N','E','N','T','S','"',',','"','C','L','I','F','F','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001153, 'Cinch Connectivity Solutions Trompeter', NULL, 'Cinch Connectivity Solutions Trompeter', 'CINCH', ARRAY<VARCHAR(256)>['[','"','C','I','N','C','H',' ','C','O','N','N','E','C','T','I','V','I','T','Y',' ','S','O','L','U','T','I','O','N','S',' ','T','R','O','M','P','E','T','E','R','"',',','"','C','i','n','c','h',' ','C','o','n','n','e','c','t','i','v','i','t','y',' ','S','o','l','u','t','i','o','n','s',' ','T','r','o','m','p','e','t','e','r','"',',','"','C','I','N','C','H','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001154, 'Qualtek', NULL, 'Qualtek', 'QUALTE', ARRAY<VARCHAR(256)>['[','"','Q','U','A','L','T','E','K','"',',','"','Q','u','a','l','t','e','k','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001155, 'Kycon, Inc.', NULL, 'Kycon, Inc.', 'KYCON', ARRAY<VARCHAR(256)>['[','"','K','Y','C','O','N',',',' ','I','N','C','.','"',',','"','K','y','c','o','n',',',' ','I','n','c','.','"',',','"','K','Y','C','O','N',',','"',',','"','K','Y','C','O','N','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001156, 'Littelfuse Aerospace', NULL, 'Littelfuse Aerospace', 'LITTEL', ARRAY<VARCHAR(256)>['[','"','L','I','T','T','E','L','F','U','S','E',' ','A','E','R','O','S','P','A','C','E','"',',','"','L','i','t','t','e','l','f','u','s','e',' ','A','e','r','o','s','p','a','c','e','"',',','"','L','I','T','T','E','L','F','U','S','E','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001157, 'Stewart Connector', NULL, 'Stewart Connector', 'STEWAR', ARRAY<VARCHAR(256)>['[','"','S','T','E','W','A','R','T',' ','C','O','N','N','E','C','T','O','R','"',',','"','S','t','e','w','a','r','t',' ','C','o','n','n','e','c','t','o','r','"',',','"','S','T','E','W','A','R','T','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001158, 'Mueller Electric Co', NULL, 'Mueller Electric Co', 'MUELLE', ARRAY<VARCHAR(256)>['[','"','M','U','E','L','L','E','R',' ','E','L','E','C','T','R','I','C',' ','C','O','"',',','"','M','u','e','l','l','e','r',' ','E','l','e','c','t','r','i','c',' ','C','o','"',',','"','M','U','E','L','L','E','R','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001159, 'CW Industries', NULL, 'CW Industries', 'CW', ARRAY<VARCHAR(256)>['[','"','C','W',' ','I','N','D','U','S','T','R','I','E','S','"',',','"','C','W',' ','I','n','d','u','s','t','r','i','e','s','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001160, 'Heyco Products Corporation', NULL, 'Heyco Products Corporation', 'HEYCO', ARRAY<VARCHAR(256)>['[','"','H','E','Y','C','O',' ','P','R','O','D','U','C','T','S',' ','C','O','R','P','O','R','A','T','I','O','N','"',',','"','H','e','y','c','o',' ','P','r','o','d','u','c','t','s',' ','C','o','r','p','o','r','a','t','i','o','n','"',',','"','H','E','Y','C','O','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001161, 'WECO Electrical Connectors Inc.', NULL, 'WECO Electrical Connectors Inc.', 'WECO', ARRAY<VARCHAR(256)>['[','"','W','E','C','O',' ','E','L','E','C','T','R','I','C','A','L',' ','C','O','N','N','E','C','T','O','R','S',' ','I','N','C','.','"',',','"','W','E','C','O',' ','E','l','e','c','t','r','i','c','a','l',' ','C','o','n','n','e','c','t','o','r','s',' ','I','n','c','.','"',',','"','W','E','C','O',' ','E','L','E','C','T','R','I','C','A','L',' ','C','O','N','N','E','C','T','O','R','S','"',',','"','W','E','C','O','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001162, 'Greenconn', NULL, 'Greenconn', 'GREENC', ARRAY<VARCHAR(256)>['[','"','G','R','E','E','N','C','O','N','N','"',',','"','G','r','e','e','n','c','o','n','n','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001163, 'PTR Hartmann', NULL, 'PTR Hartmann', 'PTR', ARRAY<VARCHAR(256)>['[','"','P','T','R',' ','H','A','R','T','M','A','N','N','"',',','"','P','T','R',' ','H','a','r','t','m','a','n','n','"',',','"','P','T','R','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001164, 'ATTEND Technology', NULL, 'ATTEND Technology', 'ATTEND', ARRAY<VARCHAR(256)>['[','"','A','T','T','E','N','D',' ','T','E','C','H','N','O','L','O','G','Y','"',',','"','A','T','T','E','N','D',' ','T','e','c','h','n','o','l','o','g','y','"',',','"','A','T','T','E','N','D','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001165, 'Advanced Cable Ties, Inc.', NULL, 'Advanced Cable Ties, Inc.', 'ADVANC', ARRAY<VARCHAR(256)>['[','"','A','D','V','A','N','C','E','D',' ','C','A','B','L','E',' ','T','I','E','S',',',' ','I','N','C','.','"',',','"','A','d','v','a','n','c','e','d',' ','C','a','b','l','e',' ','T','i','e','s',',',' ','I','n','c','.','"',',','"','A','D','V','A','N','C','E','D',' ','C','A','B','L','E',' ','T','I','E','S','"',',','"','A','D','V','A','N','C','E','D','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001166, 'IRISO USA Inc.', NULL, 'IRISO USA Inc.', 'IRISO', ARRAY<VARCHAR(256)>['[','"','I','R','I','S','O',' ','U','S','A',' ','I','N','C','.','"',',','"','I','R','I','S','O',' ','U','S','A',' ','I','n','c','.','"',',','"','I','R','I','S','O',' ','U','S','A','"',',','"','I','R','I','S','O','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001167, 'ept, inc', NULL, 'ept, inc', 'EPT', ARRAY<VARCHAR(256)>['[','"','E','P','T',',',' ','I','N','C','"',',','"','e','p','t',',',' ','i','n','c','"',',','"','E','P','T',',','"',',','"','E','P','T','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001168, 'Pepperl+Fuchs, Inc.', NULL, 'Pepperl+Fuchs, Inc.', 'PEPPER', ARRAY<VARCHAR(256)>['[','"','P','E','P','P','E','R','L','+','F','U','C','H','S',',',' ','I','N','C','.','"',',','"','P','e','p','p','e','r','l','+','F','u','c','h','s',',',' ','I','n','c','.','"',',','"','P','E','P','P','E','R','L','+','F','U','C','H','S',',','"',',','"','P','E','P','P','E','R','L','+','F','U','C','H','S','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001169, 'Logical Systems Inc.', NULL, 'Logical Systems Inc.', 'LOGICA', ARRAY<VARCHAR(256)>['[','"','L','O','G','I','C','A','L',' ','S','Y','S','T','E','M','S',' ','I','N','C','.','"',',','"','L','o','g','i','c','a','l',' ','S','y','s','t','e','m','s',' ','I','n','c','.','"',',','"','L','O','G','I','C','A','L',' ','S','Y','S','T','E','M','S','"',',','"','L','O','G','I','C','A','L','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001170, 'Alpha Wire', NULL, 'Alpha Wire', 'ALPHA', ARRAY<VARCHAR(256)>['[','"','A','L','P','H','A',' ','W','I','R','E','"',',','"','A','l','p','h','a',' ','W','i','r','e','"',',','"','A','L','P','H','A','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001171, 'Xeltek Inc.', NULL, 'Xeltek Inc.', 'XELTEK', ARRAY<VARCHAR(256)>['[','"','X','E','L','T','E','K',' ','I','N','C','.','"',',','"','X','e','l','t','e','k',' ','I','n','c','.','"',',','"','X','E','L','T','E','K','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001172, 'Littelfuse/Commercial Vehicle Products', NULL, 'Littelfuse/Commercial Vehicle Products', 'LITTEL', ARRAY<VARCHAR(256)>['[','"','L','I','T','T','E','L','F','U','S','E','/','C','O','M','M','E','R','C','I','A','L',' ','V','E','H','I','C','L','E',' ','P','R','O','D','U','C','T','S','"',',','"','L','i','t','t','e','l','f','u','s','e','/','C','o','m','m','e','r','c','i','a','l',' ','V','e','h','i','c','l','e',' ','P','r','o','d','u','c','t','s','"',',','"','C','O','M','M','E','R','C','I','A','L',' ','V','E','H','I','C','L','E',' ','P','R','O','D','U','C','T','S','"',',','"','L','I','T','T','E','L','F','U','S','E','/','C','O','M','M','E','R','C','I','A','L','"',',','"','L','I','T','T','E','L','F','U','S','E','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001173, 'Dinkle Corporation, USA', NULL, 'Dinkle Corporation, USA', 'DINKLE', ARRAY<VARCHAR(256)>['[','"','D','I','N','K','L','E',' ','C','O','R','P','O','R','A','T','I','O','N',',',' ','U','S','A','"',',','"','D','i','n','k','l','e',' ','C','o','r','p','o','r','a','t','i','o','n',',',' ','U','S','A','"',',','"','D','I','N','K','L','E',' ','C','O','R','P','O','R','A','T','I','O','N','"',',','"','D','I','N','K','L','E','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001174, 'Lumberg Inc', NULL, 'Lumberg Inc', 'LUMBER', ARRAY<VARCHAR(256)>['[','"','L','U','M','B','E','R','G',' ','I','N','C','"',',','"','L','u','m','b','e','r','g',' ','I','n','c','"',',','"','L','U','M','B','E','R','G','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001175, 'CableMAX', NULL, 'CableMAX', 'CABLEM', ARRAY<VARCHAR(256)>['[','"','C','A','B','L','E','M','A','X','"',',','"','C','a','b','l','e','M','A','X','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001176, 'TE Energy & Utilities', NULL, 'TE Energy & Utilities', 'TE', ARRAY<VARCHAR(256)>['[','"','T','E',' ','E','N','E','R','G','Y',' ','&',' ','U','T','I','L','I','T','I','E','S','"',',','"','T','E',' ','E','n','e','r','g','y',' ','&',' ','U','t','i','l','i','t','i','e','s','"',',','"','T','E',' ','A','P','P','L','I','C','A','T','I','O','N',' ','T','O','O','L','I','N','G','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001177, 'MH Connectors', NULL, 'MH Connectors', 'MH', ARRAY<VARCHAR(256)>['[','"','M','H',' ','C','O','N','N','E','C','T','O','R','S','"',',','"','M','H',' ','C','o','n','n','e','c','t','o','r','s','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001178, 'Adels-Contact', NULL, 'Adels-Contact', 'ADELSC', ARRAY<VARCHAR(256)>['[','"','A','D','E','L','S','-','C','O','N','T','A','C','T','"',',','"','A','d','e','l','s','-','C','o','n','t','a','c','t','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001179, 'Tensility International Corp', NULL, 'Tensility International Corp', 'TENSIL', ARRAY<VARCHAR(256)>['[','"','T','E','N','S','I','L','I','T','Y',' ','I','N','T','E','R','N','A','T','I','O','N','A','L',' ','C','O','R','P','"',',','"','T','e','n','s','i','l','i','t','y',' ','I','n','t','e','r','n','a','t','i','o','n','a','l',' ','C','o','r','p','"',',','"','T','E','N','S','I','L','I','T','Y',' ','I','N','T','E','R','N','A','T','I','O','N','A','L','"',',','"','T','E','N','S','I','L','I','T','Y','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001180, 'Assmann WSW Components', NULL, 'Assmann WSW Components', 'ASSMAN', ARRAY<VARCHAR(256)>['[','"','A','S','S','M','A','N','N',' ','W','S','W',' ','C','O','M','P','O','N','E','N','T','S','"',',','"','A','s','s','m','a','n','n',' ','W','S','W',' ','C','o','m','p','o','n','e','n','t','s','"',',','"','A','S','S','M','A','N','N',' ','W','S','W','"',',','"','A','S','S','M','A','N','N','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001181, 'LAPP', NULL, 'LAPP', 'LAPP', ARRAY<VARCHAR(256)>['[','"','L','A','P','P','"',',','"','L','A','P','P',' ','K','A','B','E','L','"',',','"','L','A','P','P',' ','U','S','A','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001182, 'RF Industries', NULL, 'RF Industries', 'RF', ARRAY<VARCHAR(256)>['[','"','R','F',' ','I','N','D','U','S','T','R','I','E','S','"',',','"','R','F',' ','I','n','d','u','s','t','r','i','e','s','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001183, 'Murrelektronik, Inc', NULL, 'Murrelektronik, Inc', 'MURREL', ARRAY<VARCHAR(256)>['[','"','M','U','R','R','E','L','E','K','T','R','O','N','I','K',',',' ','I','N','C','"',',','"','M','u','r','r','e','l','e','k','t','r','o','n','i','k',',',' ','I','n','c','"',',','"','M','U','R','R','E','L','E','K','T','R','O','N','I','K',',','"',',','"','M','U','R','R','E','L','E','K','T','R','O','N','I','K','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001184, 'BellWether', NULL, 'BellWether', 'BELLWE', ARRAY<VARCHAR(256)>['[','"','B','E','L','L','W','E','T','H','E','R','"',',','"','B','e','l','l','W','e','t','h','e','r','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001185, 'Linkplex', NULL, 'Linkplex', 'LINKPL', ARRAY<VARCHAR(256)>['[','"','L','I','N','K','P','L','E','X','"',',','"','L','i','n','k','p','l','e','x','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001186, 'Menbers', NULL, 'Menbers', 'MENBER', ARRAY<VARCHAR(256)>['[','"','M','E','N','B','E','R','S','"',',','"','M','e','n','b','e','r','s','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001187, 'AC Connectors', NULL, 'AC Connectors', 'AC', ARRAY<VARCHAR(256)>['[','"','A','C',' ','C','O','N','N','E','C','T','O','R','S','"',',','"','A','C',' ','C','o','n','n','e','c','t','o','r','s','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001188, 'Sauro Electronic Connectors', NULL, 'Sauro Electronic Connectors', 'SAURO', ARRAY<VARCHAR(256)>['[','"','S','A','U','R','O',' ','E','L','E','C','T','R','O','N','I','C',' ','C','O','N','N','E','C','T','O','R','S','"',',','"','S','a','u','r','o',' ','E','l','e','c','t','r','o','n','i','c',' ','C','o','n','n','e','c','t','o','r','s','"',',','"','S','A','U','R','O','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001189, 'Lighthorse Technologies, Inc', NULL, 'Lighthorse Technologies, Inc', 'LIGHTH', ARRAY<VARCHAR(256)>['[','"','L','I','G','H','T','H','O','R','S','E',' ','T','E','C','H','N','O','L','O','G','I','E','S',',',' ','I','N','C','"',',','"','L','i','g','h','t','h','o','r','s','e',' ','T','e','c','h','n','o','l','o','g','i','e','s',',',' ','I','n','c','"',',','"','L','I','G','H','T','H','O','R','S','E',' ','T','E','C','H','N','O','L','O','G','I','E','S','"',',','"','L','I','G','H','T','H','O','R','S','E','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001190, 'Vector Electronics', NULL, 'Vector Electronics', 'VECTOR', ARRAY<VARCHAR(256)>['[','"','V','E','C','T','O','R',' ','E','L','E','C','T','R','O','N','I','C','S','"',',','"','V','e','c','t','o','r',' ','E','l','e','c','t','r','o','n','i','c','s','"',',','"','V','E','C','T','O','R','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001191, 'StarTech.com', NULL, 'StarTech.com', 'STARTE', ARRAY<VARCHAR(256)>['[','"','S','T','A','R','T','E','C','H','.','C','O','M','"',',','"','S','t','a','r','T','e','c','h','.','c','o','m','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001192, 'Schaltbau', NULL, 'Schaltbau', 'SCHALT', ARRAY<VARCHAR(256)>['[','"','S','C','H','A','L','T','B','A','U','"',',','"','S','c','h','a','l','t','b','a','u','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001193, 'Millimeter Wave Technologies', NULL, 'Millimeter Wave Technologies', 'MILLIM', ARRAY<VARCHAR(256)>['[','"','M','I','L','L','I','M','E','T','E','R',' ','W','A','V','E',' ','T','E','C','H','N','O','L','O','G','I','E','S','"',',','"','M','i','l','l','i','m','e','t','e','r',' ','W','a','v','e',' ','T','e','c','h','n','o','l','o','g','i','e','s','"',',','"','M','I','L','L','I','M','E','T','E','R','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001194, 'I-PEX', NULL, 'I-PEX', 'IPEX', ARRAY<VARCHAR(256)>['[','"','I','-','P','E','X','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001195, 'Encitech Connectors AB', NULL, 'Encitech Connectors AB', 'ENCITE', ARRAY<VARCHAR(256)>['[','"','E','N','C','I','T','E','C','H',' ','C','O','N','N','E','C','T','O','R','S',' ','A','B','"',',','"','E','n','c','i','t','e','c','h',' ','C','o','n','n','e','c','t','o','r','s',' ','A','B','"',',','"','E','N','C','I','T','E','C','H',' ','C','O','N','N','E','C','T','O','R','S','"',',','"','E','N','C','I','T','E','C','H','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001196, 'Triplett', NULL, 'Triplett', 'TRIPLE', ARRAY<VARCHAR(256)>['[','"','T','R','I','P','L','E','T','T','"',',','"','T','r','i','p','l','e','t','t','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001197, 'CompuCablePlusUSA', NULL, 'CompuCablePlusUSA', 'COMPUC', ARRAY<VARCHAR(256)>['[','"','C','O','M','P','U','C','A','B','L','E','P','L','U','S','U','S','A','"',',','"','C','o','m','p','u','C','a','b','l','e','P','l','u','s','U','S','A','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001198, 'Northern Technologies', NULL, 'Northern Technologies', 'NORTHE', ARRAY<VARCHAR(256)>['[','"','N','O','R','T','H','E','R','N',' ','T','E','C','H','N','O','L','O','G','I','E','S','"',',','"','N','o','r','t','h','e','r','n',' ','T','e','c','h','n','o','l','o','g','i','e','s','"',',','"','N','O','R','T','H','E','R','N','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001199, 'Walta', NULL, 'Walta', 'WALTA', ARRAY<VARCHAR(256)>['[','"','W','A','L','T','A','"',',','"','W','a','l','t','a','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001200, 'TechTools', NULL, 'TechTools', 'TECHTO', ARRAY<VARCHAR(256)>['[','"','T','E','C','H','T','O','O','L','S','"',',','"','T','e','c','h','T','o','o','l','s','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001201, 'Micro-Mode', NULL, 'Micro-Mode', 'MICROM', ARRAY<VARCHAR(256)>['[','"','M','I','C','R','O','-','M','O','D','E','"',',','"','M','i','c','r','o','-','M','o','d','e','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001202, 'Coax Connectors Ltd', NULL, 'Coax Connectors Ltd', 'COAX', ARRAY<VARCHAR(256)>['[','"','C','O','A','X',' ','C','O','N','N','E','C','T','O','R','S',' ','L','T','D','"',',','"','C','o','a','x',' ','C','o','n','n','e','c','t','o','r','s',' ','L','t','d','"',',','"','C','O','A','X',' ','C','O','N','N','E','C','T','O','R','S','"',',','"','C','O','A','X','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001203, 'Greenlee Communications', NULL, 'Greenlee Communications', 'GREENL', ARRAY<VARCHAR(256)>['[','"','G','R','E','E','N','L','E','E',' ','C','O','M','M','U','N','I','C','A','T','I','O','N','S','"',',','"','G','r','e','e','n','l','e','e',' ','C','o','m','m','u','n','i','c','a','t','i','o','n','s','"',',','"','G','R','E','E','N','L','E','E','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001204, 'SUPERIOR TECH', NULL, 'SUPERIOR TECH', 'SUPERI', ARRAY<VARCHAR(256)>['[','"','S','U','P','E','R','I','O','R',' ','T','E','C','H','"',',','"','S','U','P','E','R','I','O','R','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001205, 'Tempo Communications', NULL, 'Tempo Communications', 'TEMPO', ARRAY<VARCHAR(256)>['[','"','T','E','M','P','O',' ','C','O','M','M','U','N','I','C','A','T','I','O','N','S','"',',','"','T','e','m','p','o',' ','C','o','m','m','u','n','i','c','a','t','i','o','n','s','"',',','"','T','E','M','P','O','"',',','"','T','E','M','P','O',' ','S','E','M','I','C','O','N','D','U','C','T','O','R',',',' ','I','N','C','.','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001206, 'Klein Tools, Inc.', NULL, 'Klein Tools, Inc.', 'KLEIN', ARRAY<VARCHAR(256)>['[','"','K','L','E','I','N',' ','T','O','O','L','S',',',' ','I','N','C','.','"',',','"','K','l','e','i','n',' ','T','o','o','l','s',',',' ','I','n','c','.','"',',','"','K','L','E','I','N',' ','T','O','O','L','S','"',',','"','K','L','E','I','N','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001207, 'KOINO', NULL, 'KOINO', 'KOINO', ARRAY<VARCHAR(256)>['[','"','K','O','I','N','O','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001208, 'Chogori Technologies Inc.', NULL, 'Chogori Technologies Inc.', 'CHOGOR', ARRAY<VARCHAR(256)>['[','"','C','H','O','G','O','R','I',' ','T','E','C','H','N','O','L','O','G','I','E','S',' ','I','N','C','.','"',',','"','C','h','o','g','o','r','i',' ','T','e','c','h','n','o','l','o','g','i','e','s',' ','I','n','c','.','"',',','"','C','H','O','G','O','R','I',' ','T','E','C','H','N','O','L','O','G','I','E','S','"',',','"','C','H','O','G','O','R','I','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001209, 'BlockMaster Electronics', NULL, 'BlockMaster Electronics', 'BLOCKM', ARRAY<VARCHAR(256)>['[','"','B','L','O','C','K','M','A','S','T','E','R',' ','E','L','E','C','T','R','O','N','I','C','S','"',',','"','B','l','o','c','k','M','a','s','t','e','r',' ','E','l','e','c','t','r','o','n','i','c','s','"',',','"','B','L','O','C','K','M','A','S','T','E','R','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001210, 'Schroff', NULL, 'Schroff', 'SCHROF', ARRAY<VARCHAR(256)>['[','"','S','C','H','R','O','F','F','"',',','"','S','c','h','r','o','f','f','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001211, 'ConductRF', NULL, 'ConductRF', 'CONDUC', ARRAY<VARCHAR(256)>['[','"','C','O','N','D','U','C','T','R','F','"',',','"','C','o','n','d','u','c','t','R','F','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001212, 'Schmartboard, Inc.', NULL, 'Schmartboard, Inc.', 'SCHMAR', ARRAY<VARCHAR(256)>['[','"','S','C','H','M','A','R','T','B','O','A','R','D',',',' ','I','N','C','.','"',',','"','S','c','h','m','a','r','t','b','o','a','r','d',',',' ','I','n','c','.','"',',','"','S','C','H','M','A','R','T','B','O','A','R','D',',','"',',','"','S','C','H','M','A','R','T','B','O','A','R','D','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001213, 'Nicomatic', NULL, 'Nicomatic', 'NICOMA', ARRAY<VARCHAR(256)>['[','"','N','I','C','O','M','A','T','I','C','"',',','"','N','i','c','o','m','a','t','i','c','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001214, 'Elpress Inc.', NULL, 'Elpress Inc.', 'ELPRES', ARRAY<VARCHAR(256)>['[','"','E','L','P','R','E','S','S',' ','I','N','C','.','"',',','"','E','l','p','r','e','s','s',' ','I','n','c','.','"',',','"','E','L','P','R','E','S','S','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001215, 'IO Audio Technologies', NULL, 'IO Audio Technologies', 'IO', ARRAY<VARCHAR(256)>['[','"','I','O',' ','A','U','D','I','O',' ','T','E','C','H','N','O','L','O','G','I','E','S','"',',','"','I','O',' ','A','u','d','i','o',' ','T','e','c','h','n','o','l','o','g','i','e','s','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001216, 'Elprotronic Inc.', NULL, 'Elprotronic Inc.', 'ELPROT', ARRAY<VARCHAR(256)>['[','"','E','L','P','R','O','T','R','O','N','I','C',' ','I','N','C','.','"',',','"','E','l','p','r','o','t','r','o','n','i','c',' ','I','n','c','.','"',',','"','E','L','P','R','O','T','R','O','N','I','C','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001217, 'CamdenBoss Ltd', NULL, 'CamdenBoss Ltd', 'CAMDEN', ARRAY<VARCHAR(256)>['[','"','C','A','M','D','E','N','B','O','S','S',' ','L','T','D','"',',','"','C','a','m','d','e','n','B','o','s','s',' ','L','t','d','"',',','"','C','A','M','D','E','N','B','O','S','S','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001218, 'Newnex', NULL, 'Newnex', 'NEWNEX', ARRAY<VARCHAR(256)>['[','"','N','E','W','N','E','X','"',',','"','N','e','w','n','e','x','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001219, 'Cole Hersee', NULL, 'Cole Hersee', 'COLE', ARRAY<VARCHAR(256)>['[','"','C','O','L','E',' ','H','E','R','S','E','E','"',',','"','C','o','l','e',' ','H','e','r','s','e','e','"',',','"','C','O','L','E','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001220, 'Triplett Test Equipment and Tools', NULL, 'Triplett Test Equipment and Tools', 'TRIPLE', ARRAY<VARCHAR(256)>['[','"','T','R','I','P','L','E','T','T',' ','T','E','S','T',' ','E','Q','U','I','P','M','E','N','T',' ','A','N','D',' ','T','O','O','L','S','"',',','"','T','r','i','p','l','e','t','t',' ','T','e','s','t',' ','E','q','u','i','p','m','e','n','t',' ','a','n','d',' ','T','o','o','l','s','"',',','"','T','R','I','P','L','E','T','T','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001221, 'Autonics.', NULL, 'Autonics.', 'AUTONI', ARRAY<VARCHAR(256)>['[','"','A','U','T','O','N','I','C','S','.','"',',','"','A','u','t','o','n','i','c','s','.','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001222, 'Tri-Star Electronics', NULL, 'Tri-Star Electronics', 'TRISTA', ARRAY<VARCHAR(256)>['[','"','T','R','I','-','S','T','A','R',' ','E','L','E','C','T','R','O','N','I','C','S','"',',','"','T','r','i','-','S','t','a','r',' ','E','l','e','c','t','r','o','n','i','c','s','"',',','"','T','R','I','-','S','T','A','R','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001223, 'Boyd Laconia, LLC', NULL, 'Boyd Laconia, LLC', 'BOYD', ARRAY<VARCHAR(256)>['[','"','B','O','Y','D',' ','L','A','C','O','N','I','A',',',' ','L','L','C','"',',','"','B','o','y','d',' ','L','a','c','o','n','i','a',',',' ','L','L','C','"',',','"','B','O','Y','D',' ','L','A','C','O','N','I','A','"',',','"','B','O','Y','D','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001224, 'E-Z-Hook', NULL, 'E-Z-Hook', 'EZHOOK', ARRAY<VARCHAR(256)>['[','"','E','-','Z','-','H','O','O','K','"',',','"','E','-','Z','-','H','o','o','k','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001225, 'Hoffman Enclosures, Inc.', NULL, 'Hoffman Enclosures, Inc.', 'HOFFMA', ARRAY<VARCHAR(256)>['[','"','H','O','F','F','M','A','N',' ','E','N','C','L','O','S','U','R','E','S',',',' ','I','N','C','.','"',',','"','H','o','f','f','m','a','n',' ','E','n','c','l','o','s','u','r','e','s',',',' ','I','n','c','.','"',',','"','H','O','F','F','M','A','N',' ','E','N','C','L','O','S','U','R','E','S','"',',','"','H','O','F','F','M','A','N','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001226, 'MPD', NULL, 'MPD', 'MPD', ARRAY<VARCHAR(256)>['[','"','M','P','D','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001227, 'MegaChips Corporation', NULL, 'MegaChips Corporation', 'MEGACH', ARRAY<VARCHAR(256)>['[','"','M','E','G','A','C','H','I','P','S',' ','C','O','R','P','O','R','A','T','I','O','N','"',',','"','M','e','g','a','C','h','i','p','s',' ','C','o','r','p','o','r','a','t','i','o','n','"',',','"','M','E','G','A','C','H','I','P','S','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001228, 'MoSys, Inc.', NULL, 'MoSys, Inc.', 'MOSYS', ARRAY<VARCHAR(256)>['[','"','M','O','S','Y','S',',',' ','I','N','C','.','"',',','"','M','o','S','y','s',',',' ','I','n','c','.','"',',','"','M','O','S','Y','S',',','"',',','"','M','O','S','Y','S','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001229, 'Honda Connector', NULL, 'Honda Connector', 'HONDA', ARRAY<VARCHAR(256)>['[','"','H','O','N','D','A',' ','C','O','N','N','E','C','T','O','R','"',',','"','H','o','n','d','a',' ','C','o','n','n','e','c','t','o','r','"',',','"','H','O','N','D','A','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001230, 'Bud Industries', NULL, 'Bud Industries', 'BUD', ARRAY<VARCHAR(256)>['[','"','B','U','D',' ','I','N','D','U','S','T','R','I','E','S','"',',','"','B','u','d',' ','I','n','d','u','s','t','r','i','e','s','"',',','"','B','U','D','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001231, 'Supirit Inc.', NULL, 'Supirit Inc.', 'SUPIRI', ARRAY<VARCHAR(256)>['[','"','S','U','P','I','R','I','T',' ','I','N','C','.','"',',','"','S','u','p','i','r','i','t',' ','I','n','c','.','"',',','"','S','U','P','I','R','I','T','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001232, 'Atlas Scientific', NULL, 'Atlas Scientific', 'ATLAS', ARRAY<VARCHAR(256)>['[','"','A','T','L','A','S',' ','S','C','I','E','N','T','I','F','I','C','"',',','"','A','t','l','a','s',' ','S','c','i','e','n','t','i','f','i','c','"',',','"','A','T','L','A','S','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001233, 'Roman-Jones Inc.', NULL, 'Roman-Jones Inc.', 'ROMANJ', ARRAY<VARCHAR(256)>['[','"','R','O','M','A','N','-','J','O','N','E','S',' ','I','N','C','.','"',',','"','R','o','m','a','n','-','J','o','n','e','s',' ','I','n','c','.','"',',','"','R','O','M','A','N','-','J','O','N','E','S','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001234, 'Metcal', NULL, 'Metcal', 'METCAL', ARRAY<VARCHAR(256)>['[','"','M','E','T','C','A','L','"',',','"','M','e','t','c','a','l','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001235, 'Carlo Gavazzi Inc.', NULL, 'Carlo Gavazzi Inc.', 'CARLO', ARRAY<VARCHAR(256)>['[','"','C','A','R','L','O',' ','G','A','V','A','Z','Z','I',' ','I','N','C','.','"',',','"','C','a','r','l','o',' ','G','a','v','a','z','z','i',' ','I','n','c','.','"',',','"','C','A','R','L','O',' ','G','A','V','A','Z','Z','I','"',',','"','C','A','R','L','O','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001236, 'Staco Energy Products Company', NULL, 'Staco Energy Products Company', 'STACO', ARRAY<VARCHAR(256)>['[','"','S','T','A','C','O',' ','E','N','E','R','G','Y',' ','P','R','O','D','U','C','T','S',' ','C','O','M','P','A','N','Y','"',',','"','S','t','a','c','o',' ','E','n','e','r','g','y',' ','P','r','o','d','u','c','t','s',' ','C','o','m','p','a','n','y','"',',','"','S','T','A','C','O','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001237, 'Celduc Inc.', NULL, 'Celduc Inc.', 'CELDUC', ARRAY<VARCHAR(256)>['[','"','C','E','L','D','U','C',' ','I','N','C','.','"',',','"','C','e','l','d','u','c',' ','I','n','c','.','"',',','"','C','E','L','D','U','C','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001238, 'Milspecwest, LLC', NULL, 'Milspecwest, LLC', 'MILSPE', ARRAY<VARCHAR(256)>['[','"','M','I','L','S','P','E','C','W','E','S','T',',',' ','L','L','C','"',',','"','M','i','l','s','p','e','c','w','e','s','t',',',' ','L','L','C','"',',','"','M','I','L','S','P','E','C','W','E','S','T',',','"',',','"','M','I','L','S','P','E','C','W','E','S','T','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001239, 'Powerbx Inc.', NULL, 'Powerbx Inc.', 'POWERB', ARRAY<VARCHAR(256)>['[','"','P','O','W','E','R','B','X',' ','I','N','C','.','"',',','"','P','o','w','e','r','b','x',' ','I','n','c','.','"',',','"','P','O','W','E','R','B','X','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001240, 'Lantiq', NULL, 'Lantiq', 'LANTIQ', ARRAY<VARCHAR(256)>['[','"','L','A','N','T','I','Q','"',',','"','L','a','n','t','i','q','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001241, 'QuickLogic', NULL, 'QuickLogic', 'QUICKL', ARRAY<VARCHAR(256)>['[','"','Q','U','I','C','K','L','O','G','I','C','"',',','"','Q','u','i','c','k','L','o','g','i','c','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001242, 'GC Electronics', NULL, 'GC Electronics', 'GC', ARRAY<VARCHAR(256)>['[','"','G','C',' ','E','L','E','C','T','R','O','N','I','C','S','"',',','"','G','C',' ','E','l','e','c','t','r','o','n','i','c','s','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001243, 'Waldom', NULL, 'Waldom', 'WALDOM', ARRAY<VARCHAR(256)>['[','"','W','A','L','D','O','M','"',',','"','W','a','l','d','o','m','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001244, 'Brainboxes', NULL, 'Brainboxes', 'BRAINB', ARRAY<VARCHAR(256)>['[','"','B','R','A','I','N','B','O','X','E','S','"',',','"','B','r','a','i','n','b','o','x','e','s','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001245, 'AC WORKS®', NULL, 'AC WORKS®', 'AC', ARRAY<VARCHAR(256)>['[','"','A','C',' ','W','O','R','K','S','®','"',',','"','A','C',' ','W','O','R','K','S','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001246, 'Botron Company Inc.', NULL, 'Botron Company Inc.', 'BOTRON', ARRAY<VARCHAR(256)>['[','"','B','O','T','R','O','N',' ','C','O','M','P','A','N','Y',' ','I','N','C','.','"',',','"','B','o','t','r','o','n',' ','C','o','m','p','a','n','y',' ','I','n','c','.','"',',','"','B','O','T','R','O','N',' ','C','O','M','P','A','N','Y','"',',','"','B','O','T','R','O','N','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001247, 'BotBlox', NULL, 'BotBlox', 'BOTBLO', ARRAY<VARCHAR(256)>['[','"','B','O','T','B','L','O','X','"',',','"','B','o','t','B','l','o','x','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001248, 'Earth People Technology', NULL, 'Earth People Technology', 'EARTH', ARRAY<VARCHAR(256)>['[','"','E','A','R','T','H',' ','P','E','O','P','L','E',' ','T','E','C','H','N','O','L','O','G','Y','"',',','"','E','a','r','t','h',' ','P','e','o','p','l','e',' ','T','e','c','h','n','o','l','o','g','y','"',',','"','E','A','R','T','H','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001249, 'Ironwood Electronics', NULL, 'Ironwood Electronics', 'IRONWO', ARRAY<VARCHAR(256)>['[','"','I','R','O','N','W','O','O','D',' ','E','L','E','C','T','R','O','N','I','C','S','"',',','"','I','r','o','n','w','o','o','d',' ','E','l','e','c','t','r','o','n','i','c','s','"',',','"','I','R','O','N','W','O','O','D','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001250, 'B&K Precision', NULL, 'B&K Precision', 'BK', ARRAY<VARCHAR(256)>['[','"','B','&','K',' ','P','R','E','C','I','S','I','O','N','"',',','"','B','&','K',' ','P','r','e','c','i','s','i','o','n','"',',','"','B','&','K','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001251, 'Gennum', NULL, 'Gennum', 'GENNUM', ARRAY<VARCHAR(256)>['[','"','G','E','N','N','U','M','"',',','"','G','e','n','n','u','m','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001252, 'Montech', NULL, 'Montech', 'MONTEC', ARRAY<VARCHAR(256)>['[','"','M','O','N','T','E','C','H','"',',','"','M','o','n','t','e','c','h','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001253, 'iWave Global', NULL, 'iWave Global', 'IWAVE', ARRAY<VARCHAR(256)>['[','"','I','W','A','V','E',' ','G','L','O','B','A','L','"',',','"','i','W','a','v','e',' ','G','l','o','b','a','l','"',',','"','I','W','A','V','E','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001254, 'ISL Products International', NULL, 'ISL Products International', 'ISL', ARRAY<VARCHAR(256)>['[','"','I','S','L',' ','P','R','O','D','U','C','T','S',' ','I','N','T','E','R','N','A','T','I','O','N','A','L','"',',','"','I','S','L',' ','P','r','o','d','u','c','t','s',' ','I','n','t','e','r','n','a','t','i','o','n','a','l','"',',','"','I','S','L','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001255, 'Encore Wire', NULL, 'Encore Wire', 'ENCORE', ARRAY<VARCHAR(256)>['[','"','E','N','C','O','R','E',' ','W','I','R','E','"',',','"','E','n','c','o','r','e',' ','W','i','r','e','"',',','"','E','N','C','O','R','E','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001256, 'Chip Quik Inc.', NULL, 'Chip Quik Inc.', 'CHIPQU', ARRAY<VARCHAR(256)>['[','"','C','H','I','P',' ','Q','U','I','K',' ','I','N','C','.','"',',','"','C','h','i','p',' ','Q','u','i','k',' ','I','n','c','.','"',',','"','C','H','I','P',' ','Q','U','I','K','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001257, 'KEL USA', NULL, 'KEL USA', 'KELUSA', ARRAY<VARCHAR(256)>['[','"','K','E','L',' ','U','S','A','"',',','"','K','E','L','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001258, 'Mersen USA Newburyport-MA L.L.C.', NULL, 'Mersen USA Newburyport-MA L.L.C.', 'MERSEN', ARRAY<VARCHAR(256)>['[','"','M','E','R','S','E','N',' ','U','S','A',' ','N','E','W','B','U','R','Y','P','O','R','T','-','M','A',' ','L','.','L','.','C','.','"',',','"','M','e','r','s','e','n',' ','U','S','A',' ','N','e','w','b','u','r','y','p','o','r','t','-','M','A',' ','L','.','L','.','C','.','"',',','"','M','E','R','S','E','N',' ','U','S','A',' ','N','E','W','B','U','R','Y','P','O','R','T','-','M','A','"',',','"','M','E','R','S','E','N','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001259, 'Central Components Manufacturing', NULL, 'Central Components Manufacturing', 'CENTRA', ARRAY<VARCHAR(256)>['[','"','C','E','N','T','R','A','L',' ','C','O','M','P','O','N','E','N','T','S',' ','M','A','N','U','F','A','C','T','U','R','I','N','G','"',',','"','C','e','n','t','r','a','l',' ','C','o','m','p','o','n','e','n','t','s',' ','M','a','n','u','f','a','c','t','u','r','i','n','g','"',',','"','C','E','N','T','R','A','L',' ','C','O','M','P','O','N','E','N','T','S','"',',','"','C','E','N','T','R','A','L','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001260, 'Kinetic Technologies', NULL, 'Kinetic Technologies', 'KINETI', ARRAY<VARCHAR(256)>['[','"','K','I','N','E','T','I','C',' ','T','E','C','H','N','O','L','O','G','I','E','S','"',',','"','K','i','n','e','t','i','c',' ','T','e','c','h','n','o','l','o','g','i','e','s','"',',','"','K','I','N','E','T','I','C','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001261, 'GES High Voltage', NULL, 'GES High Voltage', 'GESHV', ARRAY<VARCHAR(256)>['[','"','G','E','S',' ','H','I','G','H',' ','V','O','L','T','A','G','E','"',',','"','G','E','S',' ','H','i','g','h',' ','V','o','l','t','a','g','e','"',',','"','G','E','S','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001262, 'Essentra Components', NULL, 'Essentra Components', 'ESSENT', ARRAY<VARCHAR(256)>['[','"','E','S','S','E','N','T','R','A',' ','C','O','M','P','O','N','E','N','T','S','"',',','"','E','s','s','e','n','t','r','a',' ','C','o','m','p','o','n','e','n','t','s','"',',','"','E','S','S','E','N','T','R','A','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001263, 'Holt Integrated Circuits Inc.', NULL, 'Holt Integrated Circuits Inc.', 'HOLT', ARRAY<VARCHAR(256)>['[','"','H','O','L','T',' ','I','N','T','E','G','R','A','T','E','D',' ','C','I','R','C','U','I','T','S',' ','I','N','C','.','"',',','"','H','o','l','t',' ','I','n','t','e','g','r','a','t','e','d',' ','C','i','r','c','u','i','t','s',' ','I','n','c','.','"',',','"','H','O','L','T',' ','I','N','T','E','G','R','A','T','E','D',' ','C','I','R','C','U','I','T','S','"',',','"','H','O','L','T',' ','I','N','T','E','G','R','A','T','E','D','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001264, 'NVE Corp/Sensor Products', NULL, 'NVE Corp/Sensor Products', 'NVE', ARRAY<VARCHAR(256)>['[','"','N','V','E',' ','C','O','R','P','/','S','E','N','S','O','R',' ','P','R','O','D','U','C','T','S','"',',','"','N','V','E',' ','C','o','r','p','/','S','e','n','s','o','r',' ','P','r','o','d','u','c','t','s','"',',','"','N','V','E',' ','C','O','R','P','/','S','E','N','S','O','R','"',',','"','N','V','E',' ','C','O','R','P','"',']'], NULL, 1, NULL, NULL, NULL, 'connector_digikey', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001265, 'MTRONPTI', NULL, 'MTRONPTI', NULL, ARRAY<VARCHAR(256)>['[','"','M','T','R','O','N','P','T','I','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001266, 'Bivar Inc.', NULL, 'Bivar Inc.', NULL, ARRAY<VARCHAR(256)>['[','"','B','I','V','A','R',' ','I','N','C','.','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001267, 'EUROQUARTZ', NULL, 'EUROQUARTZ', NULL, ARRAY<VARCHAR(256)>['[','"','E','U','R','O','Q','U','A','R','T','Z','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001268, 'SSDI', NULL, 'SSDI', NULL, ARRAY<VARCHAR(256)>['[','"','S','S','D','I','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001269, 'GSI', NULL, 'GSI', NULL, ARRAY<VARCHAR(256)>['[','"','G','S','I','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001270, 'CATALYST', NULL, 'CATALYST', NULL, ARRAY<VARCHAR(256)>['[','"','C','A','T','A','L','Y','S','T','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001271, 'ATGBICS', NULL, 'ATGBICS', NULL, ARRAY<VARCHAR(256)>['[','"','A','T','G','B','I','C','S','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001272, 'QT', NULL, 'QT', NULL, ARRAY<VARCHAR(256)>['[','"','Q','T','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001273, 'Century Spring Corp', NULL, 'Century Spring Corp', NULL, ARRAY<VARCHAR(256)>['[','"','C','E','N','T','U','R','Y',' ','S','P','R','I','N','G',' ','C','O','R','P','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001274, 'CRYDOM', NULL, 'CRYDOM', NULL, ARRAY<VARCHAR(256)>['[','"','C','R','Y','D','O','M','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001275, 'OPTOWAY', NULL, 'OPTOWAY', NULL, ARRAY<VARCHAR(256)>['[','"','O','P','T','O','W','A','Y','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001276, 'DATADELAY', NULL, 'DATADELAY', NULL, ARRAY<VARCHAR(256)>['[','"','D','A','T','A','D','E','L','A','Y','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001277, 'Conta-Clip, Inc.', NULL, 'Conta-Clip, Inc.', NULL, ARRAY<VARCHAR(256)>['[','"','C','O','N','T','A','-','C','L','I','P',',',' ','I','N','C','.','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001278, 'XPPOWER', NULL, 'XPPOWER', NULL, ARRAY<VARCHAR(256)>['[','"','X','P','P','O','W','E','R','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001279, 'DIGITRON', NULL, 'DIGITRON', NULL, ARRAY<VARCHAR(256)>['[','"','D','I','G','I','T','R','O','N','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001280, 'TEMEX', NULL, 'TEMEX', NULL, ARRAY<VARCHAR(256)>['[','"','T','E','M','E','X','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001281, 'DDK', NULL, 'DDK', NULL, ARRAY<VARCHAR(256)>['[','"','D','D','K','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001282, 'STATEK', NULL, 'STATEK', NULL, ARRAY<VARCHAR(256)>['[','"','S','T','A','T','E','K','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001283, 'SYNQOR', NULL, 'SYNQOR', NULL, ARRAY<VARCHAR(256)>['[','"','S','Y','N','Q','O','R','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001284, 'PYRAMID', NULL, 'PYRAMID', NULL, ARRAY<VARCHAR(256)>['[','"','P','Y','R','A','M','I','D','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001285, 'Moujen', NULL, 'Moujen', NULL, ARRAY<VARCHAR(256)>['[','"','M','O','U','J','E','N','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001286, 'NUMONYX', NULL, 'NUMONYX', NULL, ARRAY<VARCHAR(256)>['[','"','N','U','M','O','N','Y','X','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001287, 'MEANWELL', NULL, 'MEANWELL', NULL, ARRAY<VARCHAR(256)>['[','"','M','E','A','N','W','E','L','L','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001288, 'ACTEL', NULL, 'ACTEL', NULL, ARRAY<VARCHAR(256)>['[','"','A','C','T','E','L','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001289, 'Astrodyne TDI', NULL, 'Astrodyne TDI', NULL, ARRAY<VARCHAR(256)>['[','"','A','S','T','R','O','D','Y','N','E',' ','T','D','I','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001290, 'Dremel', NULL, 'Dremel', NULL, ARRAY<VARCHAR(256)>['[','"','D','R','E','M','E','L','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001291, 'Serpac', NULL, 'Serpac', NULL, ARRAY<VARCHAR(256)>['[','"','S','E','R','P','A','C','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001292, 'MAJOR-LEAGUE', NULL, 'MAJOR-LEAGUE', NULL, ARRAY<VARCHAR(256)>['[','"','M','A','J','O','R','-','L','E','A','G','U','E','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001293, 'CRANE', NULL, 'CRANE', NULL, ARRAY<VARCHAR(256)>['[','"','C','R','A','N','E','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001294, 'Huber+Suhner, Inc.', NULL, 'Huber+Suhner, Inc.', NULL, ARRAY<VARCHAR(256)>['[','"','H','U','B','E','R','+','S','U','H','N','E','R',',',' ','I','N','C','.','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001295, 'SolidRun LTD', NULL, 'SolidRun LTD', NULL, ARRAY<VARCHAR(256)>['[','"','S','O','L','I','D','R','U','N',' ','L','T','D','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001296, 'WALL', NULL, 'WALL', NULL, ARRAY<VARCHAR(256)>['[','"','W','A','L','L','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001297, 'Orion Fans', NULL, 'Orion Fans', NULL, ARRAY<VARCHAR(256)>['[','"','O','R','I','O','N',' ','F','A','N','S','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001298, 'Powerex Inc.', NULL, 'Powerex Inc.', NULL, ARRAY<VARCHAR(256)>['[','"','P','O','W','E','R','E','X',' ','I','N','C','.','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001299, 'POWEREX', NULL, 'POWEREX', NULL, ARRAY<VARCHAR(256)>['[','"','P','O','W','E','R','E','X','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001300, 'POMONA', NULL, 'POMONA', NULL, ARRAY<VARCHAR(256)>['[','"','P','O','M','O','N','A','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001301, 'ELPIDA', NULL, 'ELPIDA', NULL, ARRAY<VARCHAR(256)>['[','"','E','L','P','I','D','A','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001302, 'WERMA USA Inc.', NULL, 'WERMA USA Inc.', NULL, ARRAY<VARCHAR(256)>['[','"','W','E','R','M','A',' ','U','S','A',' ','I','N','C','.','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001303, 'DigiKey', NULL, 'DigiKey', NULL, ARRAY<VARCHAR(256)>['[','"','D','I','G','I','K','E','Y','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001304, 'CALOGIC', NULL, 'CALOGIC', NULL, ARRAY<VARCHAR(256)>['[','"','C','A','L','O','G','I','C','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001305, 'POWERDYNAMICS', NULL, 'POWERDYNAMICS', NULL, ARRAY<VARCHAR(256)>['[','"','P','O','W','E','R','D','Y','N','A','M','I','C','S','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001306, 'ADPOW', NULL, 'ADPOW', NULL, ARRAY<VARCHAR(256)>['[','"','A','D','P','O','W','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001307, 'FORMOSA', NULL, 'FORMOSA', NULL, ARRAY<VARCHAR(256)>['[','"','F','O','R','M','O','S','A','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001308, 'ICSI', NULL, 'ICSI', NULL, ARRAY<VARCHAR(256)>['[','"','I','C','S','I','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001309, 'OPTO PLUS LED CORP.', NULL, 'OPTO PLUS LED CORP.', NULL, ARRAY<VARCHAR(256)>['[','"','O','P','T','O',' ','P','L','U','S',' ','L','E','D',' ','C','O','R','P','.','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001310, 'Bertech', NULL, 'Bertech', NULL, ARRAY<VARCHAR(256)>['[','"','B','E','R','T','E','C','H','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001311, 'CDIL', NULL, 'CDIL', NULL, ARRAY<VARCHAR(256)>['[','"','C','D','I','L','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001312, 'Swissbit', NULL, 'Swissbit', NULL, ARRAY<VARCHAR(256)>['[','"','S','W','I','S','S','B','I','T','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001313, 'SLPOWER', NULL, 'SLPOWER', NULL, ARRAY<VARCHAR(256)>['[','"','S','L','P','O','W','E','R','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001314, 'HAMAMATSU', NULL, 'HAMAMATSU', NULL, ARRAY<VARCHAR(256)>['[','"','H','A','M','A','M','A','T','S','U','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001315, 'SECOS', NULL, 'SECOS', NULL, ARRAY<VARCHAR(256)>['[','"','S','E','C','O','S','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001316, 'MSPI', NULL, 'MSPI', NULL, ARRAY<VARCHAR(256)>['[','"','M','S','P','I','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001317, 'AZDISPLAYS', NULL, 'AZDISPLAYS', NULL, ARRAY<VARCHAR(256)>['[','"','A','Z','D','I','S','P','L','A','Y','S','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001318, 'Astro Tool Corp', NULL, 'Astro Tool Corp', NULL, ARRAY<VARCHAR(256)>['[','"','A','S','T','R','O',' ','T','O','O','L',' ','C','O','R','P','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001319, 'WEITRON', NULL, 'WEITRON', NULL, ARRAY<VARCHAR(256)>['[','"','W','E','I','T','R','O','N','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001320, 'BSI', NULL, 'BSI', NULL, ARRAY<VARCHAR(256)>['[','"','B','S','I','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001321, 'JDSU', NULL, 'JDSU', NULL, ARRAY<VARCHAR(256)>['[','"','J','D','S','U','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001322, 'Desco', NULL, 'Desco', NULL, ARRAY<VARCHAR(256)>['[','"','D','E','S','C','O','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001323, 'FINISAR', NULL, 'FINISAR', NULL, ARRAY<VARCHAR(256)>['[','"','F','I','N','I','S','A','R','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001324, 'MaxBotix Inc.', NULL, 'MaxBotix Inc.', NULL, ARRAY<VARCHAR(256)>['[','"','M','A','X','B','O','T','I','X',' ','I','N','C','.','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001325, 'LMB Heeger Inc.', NULL, 'LMB Heeger Inc.', NULL, ARRAY<VARCHAR(256)>['[','"','L','M','B',' ','H','E','E','G','E','R',' ','I','N','C','.','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001326, 'TAITRON', NULL, 'TAITRON', NULL, ARRAY<VARCHAR(256)>['[','"','T','A','I','T','R','O','N','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001327, 'ASTRODYNE', NULL, 'ASTRODYNE', NULL, ARRAY<VARCHAR(256)>['[','"','A','S','T','R','O','D','Y','N','E','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001328, 'LEI Indias', NULL, 'LEI Indias', NULL, ARRAY<VARCHAR(256)>['[','"','L','E','I',' ','I','N','D','I','A','S','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001329, 'ECM', NULL, 'ECM', NULL, ARRAY<VARCHAR(256)>['[','"','E','C','M','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001330, 'ACCUTEK', NULL, 'ACCUTEK', NULL, ARRAY<VARCHAR(256)>['[','"','A','C','C','U','T','E','K','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001331, 'Bergquist', NULL, 'Bergquist', NULL, ARRAY<VARCHAR(256)>['[','"','B','E','R','G','Q','U','I','S','T','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001332, 'Franjobaim', NULL, 'Franjobaim', NULL, ARRAY<VARCHAR(256)>['[','"','F','R','A','N','J','O','B','A','I','M','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001333, 'ebm-papst Inc.', NULL, 'ebm-papst Inc.', NULL, ARRAY<VARCHAR(256)>['[','"','E','B','M','-','P','A','P','S','T',' ','I','N','C','.','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001334, 'OmniOn Power™', NULL, 'OmniOn Power™', NULL, ARRAY<VARCHAR(256)>['[','"','O','M','N','I','O','N',' ','P','O','W','E','R','™','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001335, 'SCS', NULL, 'SCS', NULL, ARRAY<VARCHAR(256)>['[','"','S','C','S','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001336, 'ALPHAWIRE', NULL, 'ALPHAWIRE', NULL, ARRAY<VARCHAR(256)>['[','"','A','L','P','H','A','W','I','R','E','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001337, 'MERRIMAC', NULL, 'MERRIMAC', NULL, ARRAY<VARCHAR(256)>['[','"','M','E','R','R','I','M','A','C','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001338, 'EMERSON-NETWORKPOWER', NULL, 'EMERSON-NETWORKPOWER', NULL, ARRAY<VARCHAR(256)>['[','"','E','M','E','R','S','O','N','-','N','E','T','W','O','R','K','P','O','W','E','R','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001339, 'LIGITEK', NULL, 'LIGITEK', NULL, ARRAY<VARCHAR(256)>['[','"','L','I','G','I','T','E','K','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001340, 'SANREX', NULL, 'SANREX', NULL, ARRAY<VARCHAR(256)>['[','"','S','A','N','R','E','X','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001341, 'OptiFuse', NULL, 'OptiFuse', NULL, ARRAY<VARCHAR(256)>['[','"','O','P','T','I','F','U','S','E','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001342, 'ADATA', NULL, 'ADATA', NULL, ARRAY<VARCHAR(256)>['[','"','A','D','A','T','A','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001343, 'Chinsan', NULL, 'Chinsan', NULL, ARRAY<VARCHAR(256)>['[','"','C','H','I','N','S','A','N','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001344, 'Finisar Corporation', NULL, 'Finisar Corporation', NULL, ARRAY<VARCHAR(256)>['[','"','F','I','N','I','S','A','R',' ','C','O','R','P','O','R','A','T','I','O','N','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001345, 'BOARDCOM', NULL, 'BOARDCOM', NULL, ARRAY<VARCHAR(256)>['[','"','B','O','A','R','D','C','O','M','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001346, 'TRSYS', NULL, 'TRSYS', NULL, ARRAY<VARCHAR(256)>['[','"','T','R','S','Y','S','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001347, 'P-DUKE', NULL, 'P-DUKE', NULL, ARRAY<VARCHAR(256)>['[','"','P','-','D','U','K','E','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001348, 'Lantronix, Inc.', NULL, 'Lantronix, Inc.', NULL, ARRAY<VARCHAR(256)>['[','"','L','A','N','T','R','O','N','I','X',',',' ','I','N','C','.','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001349, 'VMI', NULL, 'VMI', NULL, ARRAY<VARCHAR(256)>['[','"','V','M','I','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001350, 'FLIR Extech', NULL, 'FLIR Extech', NULL, ARRAY<VARCHAR(256)>['[','"','F','L','I','R',' ','E','X','T','E','C','H','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001351, 'OKAYA', NULL, 'OKAYA', NULL, ARRAY<VARCHAR(256)>['[','"','O','K','A','Y','A','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001352, 'TPI', NULL, 'TPI', NULL, ARRAY<VARCHAR(256)>['[','"','T','P','I','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001353, 'MINMAX', NULL, 'MINMAX', NULL, ARRAY<VARCHAR(256)>['[','"','M','I','N','M','A','X','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001354, 'INOLUX', NULL, 'INOLUX', NULL, ARRAY<VARCHAR(256)>['[','"','I','N','O','L','U','X','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001355, 'MIMIX', NULL, 'MIMIX', NULL, ARRAY<VARCHAR(256)>['[','"','M','I','M','I','X','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001356, 'SYNERGY', NULL, 'SYNERGY', NULL, ARRAY<VARCHAR(256)>['[','"','S','Y','N','E','R','G','Y','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001357, 'HANBIT', NULL, 'HANBIT', NULL, ARRAY<VARCHAR(256)>['[','"','H','A','N','B','I','T','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001358, 'FREQUENCYDEVICES', NULL, 'FREQUENCYDEVICES', NULL, ARRAY<VARCHAR(256)>['[','"','F','R','E','Q','U','E','N','C','Y','D','E','V','I','C','E','S','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001359, 'Pflitsch', NULL, 'Pflitsch', NULL, ARRAY<VARCHAR(256)>['[','"','P','F','L','I','T','S','C','H','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001360, 'EDAL', NULL, 'EDAL', NULL, ARRAY<VARCHAR(256)>['[','"','E','D','A','L','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001361, 'ISAHAYA', NULL, 'ISAHAYA', NULL, ARRAY<VARCHAR(256)>['[','"','I','S','A','H','A','Y','A','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001362, 'WITHWAVE CO LTD', NULL, 'WITHWAVE CO LTD', NULL, ARRAY<VARCHAR(256)>['[','"','W','I','T','H','W','A','V','E',' ','C','O',' ','L','T','D','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001363, 'Flambeau Inc.', NULL, 'Flambeau Inc.', NULL, ARRAY<VARCHAR(256)>['[','"','F','L','A','M','B','E','A','U',' ','I','N','C','.','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001364, 'CMLMICRO', NULL, 'CMLMICRO', NULL, ARRAY<VARCHAR(256)>['[','"','C','M','L','M','I','C','R','O','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001365, 'MOSEL', NULL, 'MOSEL', NULL, ARRAY<VARCHAR(256)>['[','"','M','O','S','E','L','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001366, 'TechNexion', NULL, 'TechNexion', NULL, ARRAY<VARCHAR(256)>['[','"','T','E','C','H','N','E','X','I','O','N','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001367, 'Comair Rotron', NULL, 'Comair Rotron', NULL, ARRAY<VARCHAR(256)>['[','"','C','O','M','A','I','R',' ','R','O','T','R','O','N','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001368, 'TRIQUINT', NULL, 'TRIQUINT', NULL, ARRAY<VARCHAR(256)>['[','"','T','R','I','Q','U','I','N','T','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001369, 'Magnasphere Corp', NULL, 'Magnasphere Corp', NULL, ARRAY<VARCHAR(256)>['[','"','M','A','G','N','A','S','P','H','E','R','E',' ','C','O','R','P','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001370, 'MENDA', NULL, 'MENDA', NULL, ARRAY<VARCHAR(256)>['[','"','M','E','N','D','A','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001371, 'HP', NULL, 'HP', NULL, ARRAY<VARCHAR(256)>['[','"','H','P','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001372, 'VITESSE', NULL, 'VITESSE', NULL, ARRAY<VARCHAR(256)>['[','"','V','I','T','E','S','S','E','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001373, 'CLARE', NULL, 'CLARE', NULL, ARRAY<VARCHAR(256)>['[','"','C','L','A','R','E','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001374, 'PHIHONG', NULL, 'PHIHONG', NULL, ARRAY<VARCHAR(256)>['[','"','P','H','I','H','O','N','G','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001375, 'YEONHO', NULL, 'YEONHO', NULL, ARRAY<VARCHAR(256)>['[','"','Y','E','O','N','H','O','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001376, 'Bopla Enclosures', NULL, 'Bopla Enclosures', NULL, ARRAY<VARCHAR(256)>['[','"','B','O','P','L','A',' ','E','N','C','L','O','S','U','R','E','S','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001377, 'Parlex USA LLC', NULL, 'Parlex USA LLC', NULL, ARRAY<VARCHAR(256)>['[','"','P','A','R','L','E','X',' ','U','S','A',' ','L','L','C','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001378, 'POWERBOX', NULL, 'POWERBOX', NULL, ARRAY<VARCHAR(256)>['[','"','P','O','W','E','R','B','O','X','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001379, 'EUDYNA', NULL, 'EUDYNA', NULL, ARRAY<VARCHAR(256)>['[','"','E','U','D','Y','N','A','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001380, 'HUTSON', NULL, 'HUTSON', NULL, ARRAY<VARCHAR(256)>['[','"','H','U','T','S','O','N','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001381, 'Digilent, Inc.', NULL, 'Digilent, Inc.', NULL, ARRAY<VARCHAR(256)>['[','"','D','I','G','I','L','E','N','T',',',' ','I','N','C','.','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001382, 'Virtium LLC', NULL, 'Virtium LLC', NULL, ARRAY<VARCHAR(256)>['[','"','V','I','R','T','I','U','M',' ','L','L','C','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001383, 'Innodisk USA Corporation', NULL, 'Innodisk USA Corporation', NULL, ARRAY<VARCHAR(256)>['[','"','I','N','N','O','D','I','S','K',' ','U','S','A',' ','C','O','R','P','O','R','A','T','I','O','N','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001384, 'Rose Enclosures', NULL, 'Rose Enclosures', NULL, ARRAY<VARCHAR(256)>['[','"','R','O','S','E',' ','E','N','C','L','O','S','U','R','E','S','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001385, 'Orbel Corporation', NULL, 'Orbel Corporation', NULL, ARRAY<VARCHAR(256)>['[','"','O','R','B','E','L',' ','C','O','R','P','O','R','A','T','I','O','N','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001386, 'UOT', NULL, 'UOT', NULL, ARRAY<VARCHAR(256)>['[','"','U','O','T','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001387, 'Phihong USA', NULL, 'Phihong USA', NULL, ARRAY<VARCHAR(256)>['[','"','P','H','I','H','O','N','G',' ','U','S','A','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001388, 'Harvatek Corporation', NULL, 'Harvatek Corporation', NULL, ARRAY<VARCHAR(256)>['[','"','H','A','R','V','A','T','E','K',' ','C','O','R','P','O','R','A','T','I','O','N','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001389, 'RFMD', NULL, 'RFMD', NULL, ARRAY<VARCHAR(256)>['[','"','R','F','M','D','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001390, 'iFixit', NULL, 'iFixit', NULL, ARRAY<VARCHAR(256)>['[','"','I','F','I','X','I','T','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001391, 'EDATEC', NULL, 'EDATEC', NULL, ARRAY<VARCHAR(256)>['[','"','E','D','A','T','E','C','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001392, 'LEDIL', NULL, 'LEDIL', NULL, ARRAY<VARCHAR(256)>['[','"','L','E','D','I','L','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001393, 'ALSC', NULL, 'ALSC', NULL, ARRAY<VARCHAR(256)>['[','"','A','L','S','C','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001394, 'POINN', NULL, 'POINN', NULL, ARRAY<VARCHAR(256)>['[','"','P','O','I','N','N','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001395, 'Conductive Containers, Inc.', NULL, 'Conductive Containers, Inc.', NULL, ARRAY<VARCHAR(256)>['[','"','C','O','N','D','U','C','T','I','V','E',' ','C','O','N','T','A','I','N','E','R','S',',',' ','I','N','C','.','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001396, 'PURDY', NULL, 'PURDY', NULL, ARRAY<VARCHAR(256)>['[','"','P','U','R','D','Y','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001397, 'SolaHD', NULL, 'SolaHD', NULL, ARRAY<VARCHAR(256)>['[','"','S','O','L','A','H','D','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001398, 'TRIPPLITE', NULL, 'TRIPPLITE', NULL, ARRAY<VARCHAR(256)>['[','"','T','R','I','P','P','L','I','T','E','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001399, 'ACL Staticide Inc', NULL, 'ACL Staticide Inc', NULL, ARRAY<VARCHAR(256)>['[','"','A','C','L',' ','S','T','A','T','I','C','I','D','E',' ','I','N','C','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001400, 'CHINFA', NULL, 'CHINFA', NULL, ARRAY<VARCHAR(256)>['[','"','C','H','I','N','F','A','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001401, 'PF', NULL, 'PF', NULL, ARRAY<VARCHAR(256)>['[','"','P','F','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001402, 'EUPEC', NULL, 'EUPEC', NULL, ARRAY<VARCHAR(256)>['[','"','E','U','P','E','C','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001403, 'ORIONFANS', NULL, 'ORIONFANS', NULL, ARRAY<VARCHAR(256)>['[','"','O','R','I','O','N','F','A','N','S','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001404, 'EXTECH', NULL, 'EXTECH', NULL, ARRAY<VARCHAR(256)>['[','"','E','X','T','E','C','H','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001405, 'BOCA', NULL, 'BOCA', NULL, ARRAY<VARCHAR(256)>['[','"','B','O','C','A','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001406, 'DATATRONICS', NULL, 'DATATRONICS', NULL, ARRAY<VARCHAR(256)>['[','"','D','A','T','A','T','R','O','N','I','C','S','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001407, 'PMI', NULL, 'PMI', NULL, ARRAY<VARCHAR(256)>['[','"','P','M','I','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001408, 'Parker Chomerics', NULL, 'Parker Chomerics', NULL, ARRAY<VARCHAR(256)>['[','"','P','A','R','K','E','R',' ','C','H','O','M','E','R','I','C','S','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001409, 'EMMICRO', NULL, 'EMMICRO', NULL, ARRAY<VARCHAR(256)>['[','"','E','M','M','I','C','R','O','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001410, 'REDLION', NULL, 'REDLION', NULL, ARRAY<VARCHAR(256)>['[','"','R','E','D','L','I','O','N','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001411, 'Akoustis- RFMi', NULL, 'Akoustis- RFMi', NULL, ARRAY<VARCHAR(256)>['[','"','A','K','O','U','S','T','I','S','-',' ','R','F','M','I','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001412, 'PLL', NULL, 'PLL', NULL, ARRAY<VARCHAR(256)>['[','"','P','L','L','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001413, 'FUJIKURA', NULL, 'FUJIKURA', NULL, ARRAY<VARCHAR(256)>['[','"','F','U','J','I','K','U','R','A','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001414, 'Ezurio', NULL, 'Ezurio', NULL, ARRAY<VARCHAR(256)>['[','"','E','Z','U','R','I','O','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001415, 'TERIDIAN', NULL, 'TERIDIAN', NULL, ARRAY<VARCHAR(256)>['[','"','T','E','R','I','D','I','A','N','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001416, 'TYCLON', NULL, 'TYCLON', NULL, ARRAY<VARCHAR(256)>['[','"','T','Y','C','L','O','N','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001417, 'Davies Molding, LLC', NULL, 'Davies Molding, LLC', NULL, ARRAY<VARCHAR(256)>['[','"','D','A','V','I','E','S',' ','M','O','L','D','I','N','G',',',' ','L','L','C','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001418, 'PMC', NULL, 'PMC', NULL, ARRAY<VARCHAR(256)>['[','"','P','M','C','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001419, 'Agilink Microwires', NULL, 'Agilink Microwires', NULL, ARRAY<VARCHAR(256)>['[','"','A','G','I','L','I','N','K',' ','M','I','C','R','O','W','I','R','E','S','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001420, 'ROCKWELL', NULL, 'ROCKWELL', NULL, ARRAY<VARCHAR(256)>['[','"','R','O','C','K','W','E','L','L','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001421, 'TRUMPOWER', NULL, 'TRUMPOWER', NULL, ARRAY<VARCHAR(256)>['[','"','T','R','U','M','P','O','W','E','R','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001422, '80/20, LLC', NULL, '80/20, LLC', NULL, ARRAY<VARCHAR(256)>['[','"','8','0','/','2','0',',',' ','L','L','C','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001423, 'VANLONG', NULL, 'VANLONG', NULL, ARRAY<VARCHAR(256)>['[','"','V','A','N','L','O','N','G','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001424, 'Opto 22', NULL, 'Opto 22', NULL, ARRAY<VARCHAR(256)>['[','"','O','P','T','O',' ','2','2','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001425, 'PULS, LP', NULL, 'PULS, LP', NULL, ARRAY<VARCHAR(256)>['[','"','P','U','L','S',',',' ','L','P','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001426, 'Festo Corporation', NULL, 'Festo Corporation', NULL, ARRAY<VARCHAR(256)>['[','"','F','E','S','T','O',' ','C','O','R','P','O','R','A','T','I','O','N','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001427, 'PUIAUDIO', NULL, 'PUIAUDIO', NULL, ARRAY<VARCHAR(256)>['[','"','P','U','I','A','U','D','I','O','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001428, 'MUSIC', NULL, 'MUSIC', NULL, ARRAY<VARCHAR(256)>['[','"','M','U','S','I','C','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001429, 'NICHIA', NULL, 'NICHIA', NULL, ARRAY<VARCHAR(256)>['[','"','N','I','C','H','I','A','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001430, 'PLX', NULL, 'PLX', NULL, ARRAY<VARCHAR(256)>['[','"','P','L','X','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001431, 'LEDTRONICS', NULL, 'LEDTRONICS', NULL, ARRAY<VARCHAR(256)>['[','"','L','E','D','T','R','O','N','I','C','S','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001432, 'Peerless by Tymphany', NULL, 'Peerless by Tymphany', NULL, ARRAY<VARCHAR(256)>['[','"','P','E','E','R','L','E','S','S',' ','B','Y',' ','T','Y','M','P','H','A','N','Y','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001433, 'PERKINELMER', NULL, 'PERKINELMER', NULL, ARRAY<VARCHAR(256)>['[','"','P','E','R','K','I','N','E','L','M','E','R','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001434, 'CERAMATE', NULL, 'CERAMATE', NULL, ARRAY<VARCHAR(256)>['[','"','C','E','R','A','M','A','T','E','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001435, 'Passive Plus', NULL, 'Passive Plus', NULL, ARRAY<VARCHAR(256)>['[','"','P','A','S','S','I','V','E',' ','P','L','U','S','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001436, 'Maxtena Inc', NULL, 'Maxtena Inc', NULL, ARRAY<VARCHAR(256)>['[','"','M','A','X','T','E','N','A',' ','I','N','C','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001437, 'EPtronics, Inc.', NULL, 'EPtronics, Inc.', NULL, ARRAY<VARCHAR(256)>['[','"','E','P','T','R','O','N','I','C','S',',',' ','I','N','C','.','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001438, 'MG Chemicals', NULL, 'MG Chemicals', NULL, ARRAY<VARCHAR(256)>['[','"','M','G',' ','C','H','E','M','I','C','A','L','S','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001439, 'BYTES', NULL, 'BYTES', NULL, ARRAY<VARCHAR(256)>['[','"','B','Y','T','E','S','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001440, 'CAIG Laboratories, Inc.', NULL, 'CAIG Laboratories, Inc.', NULL, ARRAY<VARCHAR(256)>['[','"','C','A','I','G',' ','L','A','B','O','R','A','T','O','R','I','E','S',',',' ','I','N','C','.','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001441, 'A1PROS', NULL, 'A1PROS', NULL, ARRAY<VARCHAR(256)>['[','"','A','1','P','R','O','S','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001442, 'FiberSource, Inc', NULL, 'FiberSource, Inc', NULL, ARRAY<VARCHAR(256)>['[','"','F','I','B','E','R','S','O','U','R','C','E',',',' ','I','N','C','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001443, 'RICHCO', NULL, 'RICHCO', NULL, ARRAY<VARCHAR(256)>['[','"','R','I','C','H','C','O','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001444, 'TMT', NULL, 'TMT', NULL, ARRAY<VARCHAR(256)>['[','"','T','M','T','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001445, 'Syntiant', NULL, 'Syntiant', NULL, ARRAY<VARCHAR(256)>['[','"','S','Y','N','T','I','A','N','T','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001446, 'Coherent', NULL, 'Coherent', NULL, ARRAY<VARCHAR(256)>['[','"','C','O','H','E','R','E','N','T','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001447, 'NEWHAVEN', NULL, 'NEWHAVEN', NULL, ARRAY<VARCHAR(256)>['[','"','N','E','W','H','A','V','E','N','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001448, 'Peplink', NULL, 'Peplink', NULL, ARRAY<VARCHAR(256)>['[','"','P','E','P','L','I','N','K','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001449, 'DOMINANT', NULL, 'DOMINANT', NULL, ARRAY<VARCHAR(256)>['[','"','D','O','M','I','N','A','N','T','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001450, 'FIBOX Enclosures', NULL, 'FIBOX Enclosures', NULL, ARRAY<VARCHAR(256)>['[','"','F','I','B','O','X',' ','E','N','C','L','O','S','U','R','E','S','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001451, 'New Age Enclosures', NULL, 'New Age Enclosures', NULL, ARRAY<VARCHAR(256)>['[','"','N','E','W',' ','A','G','E',' ','E','N','C','L','O','S','U','R','E','S','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001452, 'XFMRS', NULL, 'XFMRS', NULL, ARRAY<VARCHAR(256)>['[','"','X','F','M','R','S','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001453, 'UMC', NULL, 'UMC', NULL, ARRAY<VARCHAR(256)>['[','"','U','M','C','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001454, 'HPC Optics', NULL, 'HPC Optics', NULL, ARRAY<VARCHAR(256)>['[','"','H','P','C',' ','O','P','T','I','C','S','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001455, 'EOREX', NULL, 'EOREX', NULL, ARRAY<VARCHAR(256)>['[','"','E','O','R','E','X','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001456, 'XiangJiang', NULL, 'XiangJiang', NULL, ARRAY<VARCHAR(256)>['[','"','X','I','A','N','G','J','I','A','N','G','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001457, 'WJCI', NULL, 'WJCI', NULL, ARRAY<VARCHAR(256)>['[','"','W','J','C','I','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001458, 'HANTRONIX', NULL, 'HANTRONIX', NULL, ARRAY<VARCHAR(256)>['[','"','H','A','N','T','R','O','N','I','X','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001459, 'Kitronik Ltd.', NULL, 'Kitronik Ltd.', NULL, ARRAY<VARCHAR(256)>['[','"','K','I','T','R','O','N','I','K',' ','L','T','D','.','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001460, 'EPIGAP OSA Photonics', NULL, 'EPIGAP OSA Photonics', NULL, ARRAY<VARCHAR(256)>['[','"','E','P','I','G','A','P',' ','O','S','A',' ','P','H','O','T','O','N','I','C','S','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001461, 'IQD', NULL, 'IQD', NULL, ARRAY<VARCHAR(256)>['[','"','I','Q','D','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001462, 'ETA-USA', NULL, 'ETA-USA', NULL, ARRAY<VARCHAR(256)>['[','"','E','T','A','-','U','S','A','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001463, 'Kurtz Ersa', NULL, 'Kurtz Ersa', NULL, ARRAY<VARCHAR(256)>['[','"','K','U','R','T','Z',' ','E','R','S','A','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001464, 'CARLOGAVAZZI', NULL, 'CARLOGAVAZZI', NULL, ARRAY<VARCHAR(256)>['[','"','C','A','R','L','O','G','A','V','A','Z','Z','I','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001465, 'ZMD', NULL, 'ZMD', NULL, ARRAY<VARCHAR(256)>['[','"','Z','M','D','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001466, 'Leopard Imaging Inc.', NULL, 'Leopard Imaging Inc.', NULL, ARRAY<VARCHAR(256)>['[','"','L','E','O','P','A','R','D',' ','I','M','A','G','I','N','G',' ','I','N','C','.','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001467, 'ANYSOLAR Ltd', NULL, 'ANYSOLAR Ltd', NULL, ARRAY<VARCHAR(256)>['[','"','A','N','Y','S','O','L','A','R',' ','L','T','D','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001468, 'E-Z LOK', NULL, 'E-Z LOK', NULL, ARRAY<VARCHAR(256)>['[','"','E','-','Z',' ','L','O','K','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001469, 'POLYFET', NULL, 'POLYFET', NULL, ARRAY<VARCHAR(256)>['[','"','P','O','L','Y','F','E','T','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001470, 'BZBGEAR', NULL, 'BZBGEAR', NULL, ARRAY<VARCHAR(256)>['[','"','B','Z','B','G','E','A','R','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001471, 'ROITHNER', NULL, 'ROITHNER', NULL, ARRAY<VARCHAR(256)>['[','"','R','O','I','T','H','N','E','R','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001472, 'Panavise', NULL, 'Panavise', NULL, ARRAY<VARCHAR(256)>['[','"','P','A','N','A','V','I','S','E','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001473, 'SanRex Corporation', NULL, 'SanRex Corporation', NULL, ARRAY<VARCHAR(256)>['[','"','S','A','N','R','E','X',' ','C','O','R','P','O','R','A','T','I','O','N','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001474, 'CONEXANT', NULL, 'CONEXANT', NULL, ARRAY<VARCHAR(256)>['[','"','C','O','N','E','X','A','N','T','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001475, 'SILONEX', NULL, 'SILONEX', NULL, ARRAY<VARCHAR(256)>['[','"','S','I','L','O','N','E','X','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001476, 'Terasic Inc.', NULL, 'Terasic Inc.', NULL, ARRAY<VARCHAR(256)>['[','"','T','E','R','A','S','I','C',' ','I','N','C','.','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001477, 'KEYSIGHT', NULL, 'KEYSIGHT', NULL, ARRAY<VARCHAR(256)>['[','"','K','E','Y','S','I','G','H','T','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001478, 'BOWEI', NULL, 'BOWEI', NULL, ARRAY<VARCHAR(256)>['[','"','B','O','W','E','I','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001479, 'LINEAGEPOWER', NULL, 'LINEAGEPOWER', NULL, ARRAY<VARCHAR(256)>['[','"','L','I','N','E','A','G','E','P','O','W','E','R','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001480, 'NANOAMP', NULL, 'NANOAMP', NULL, ARRAY<VARCHAR(256)>['[','"','N','A','N','O','A','M','P','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001481, 'Techspray', NULL, 'Techspray', NULL, ARRAY<VARCHAR(256)>['[','"','T','E','C','H','S','P','R','A','Y','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001482, 'AZM', NULL, 'AZM', NULL, ARRAY<VARCHAR(256)>['[','"','A','Z','M','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001483, 'FILTRONIC', NULL, 'FILTRONIC', NULL, ARRAY<VARCHAR(256)>['[','"','F','I','L','T','R','O','N','I','C','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001484, 'VPT', NULL, 'VPT', NULL, ARRAY<VARCHAR(256)>['[','"','V','P','T','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001485, 'DEIAZ', NULL, 'DEIAZ', NULL, ARRAY<VARCHAR(256)>['[','"','D','E','I','A','Z','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001486, 'Chemtronics', NULL, 'Chemtronics', NULL, ARRAY<VARCHAR(256)>['[','"','C','H','E','M','T','R','O','N','I','C','S','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001487, 'Vigortronix', NULL, 'Vigortronix', NULL, ARRAY<VARCHAR(256)>['[','"','V','I','G','O','R','T','R','O','N','I','X','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001488, 'ELMOS', NULL, 'ELMOS', NULL, ARRAY<VARCHAR(256)>['[','"','E','L','M','O','S','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001489, 'LSTD', NULL, 'LSTD', NULL, ARRAY<VARCHAR(256)>['[','"','L','S','T','D','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001490, 'TEKTRONIX', NULL, 'TEKTRONIX', NULL, ARRAY<VARCHAR(256)>['[','"','T','E','K','T','R','O','N','I','X','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001491, 'Sorbothane', NULL, 'Sorbothane', NULL, ARRAY<VARCHAR(256)>['[','"','S','O','R','B','O','T','H','A','N','E','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001492, 'Custom Computer Services Inc.', NULL, 'Custom Computer Services Inc.', NULL, ARRAY<VARCHAR(256)>['[','"','C','U','S','T','O','M',' ','C','O','M','P','U','T','E','R',' ','S','E','R','V','I','C','E','S',' ','I','N','C','.','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001493, 'Stahlin', NULL, 'Stahlin', NULL, ARRAY<VARCHAR(256)>['[','"','S','T','A','H','L','I','N','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001494, 'Simco-Ion', NULL, 'Simco-Ion', NULL, ARRAY<VARCHAR(256)>['[','"','S','I','M','C','O','-','I','O','N','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001495, 'Quelighting Corp', NULL, 'Quelighting Corp', NULL, ARRAY<VARCHAR(256)>['[','"','Q','U','E','L','I','G','H','T','I','N','G',' ','C','O','R','P','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001496, 'Display Visions', NULL, 'Display Visions', NULL, ARRAY<VARCHAR(256)>['[','"','D','I','S','P','L','A','Y',' ','V','I','S','I','O','N','S','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001497, 'Amprobe', NULL, 'Amprobe', NULL, ARRAY<VARCHAR(256)>['[','"','A','M','P','R','O','B','E','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001498, 'RFHIC', NULL, 'RFHIC', NULL, ARRAY<VARCHAR(256)>['[','"','R','F','H','I','C','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001499, 'European Thermodynamics Ltd', NULL, 'European Thermodynamics Ltd', NULL, ARRAY<VARCHAR(256)>['[','"','E','U','R','O','P','E','A','N',' ','T','H','E','R','M','O','D','Y','N','A','M','I','C','S',' ','L','T','D','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001500, 'SIRENZA', NULL, 'SIRENZA', NULL, ARRAY<VARCHAR(256)>['[','"','S','I','R','E','N','Z','A','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001501, 'SUNTAN', NULL, 'SUNTAN', NULL, ARRAY<VARCHAR(256)>['[','"','S','U','N','T','A','N','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001502, 'Nearson Inc.', NULL, 'Nearson Inc.', NULL, ARRAY<VARCHAR(256)>['[','"','N','E','A','R','S','O','N',' ','I','N','C','.','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001503, 'Avery Dennison RFID', NULL, 'Avery Dennison RFID', NULL, ARRAY<VARCHAR(256)>['[','"','A','V','E','R','Y',' ','D','E','N','N','I','S','O','N',' ','R','F','I','D','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001504, 'Wöhrle', NULL, 'Wöhrle', NULL, ARRAY<VARCHAR(256)>['[','"','W','ö','H','R','L','E','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001505, 'INNOVASIC', NULL, 'INNOVASIC', NULL, ARRAY<VARCHAR(256)>['[','"','I','N','N','O','V','A','S','I','C','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001506, 'HMS Networks', NULL, 'HMS Networks', NULL, ARRAY<VARCHAR(256)>['[','"','H','M','S',' ','N','E','T','W','O','R','K','S','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001507, 'Silvertel', NULL, 'Silvertel', NULL, ARRAY<VARCHAR(256)>['[','"','S','I','L','V','E','R','T','E','L','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001508, 'Thomas & Betts', NULL, 'Thomas & Betts', NULL, ARRAY<VARCHAR(256)>['[','"','T','H','O','M','A','S',' ','&',' ','B','E','T','T','S','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001509, 'Inspired LED, LLC', NULL, 'Inspired LED, LLC', NULL, ARRAY<VARCHAR(256)>['[','"','I','N','S','P','I','R','E','D',' ','L','E','D',',',' ','L','L','C','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001510, 'POWERTIP', NULL, 'POWERTIP', NULL, ARRAY<VARCHAR(256)>['[','"','P','O','W','E','R','T','I','P','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001511, 'RFSOLUTIONS', NULL, 'RFSOLUTIONS', NULL, ARRAY<VARCHAR(256)>['[','"','R','F','S','O','L','U','T','I','O','N','S','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001512, 'Synzen', NULL, 'Synzen', NULL, ARRAY<VARCHAR(256)>['[','"','S','Y','N','Z','E','N','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001513, 'DigiKey Standard', NULL, 'DigiKey Standard', NULL, ARRAY<VARCHAR(256)>['[','"','D','I','G','I','K','E','Y',' ','S','T','A','N','D','A','R','D','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001514, 'ACUTECH', NULL, 'ACUTECH', NULL, ARRAY<VARCHAR(256)>['[','"','A','C','U','T','E','C','H','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001515, 'ADDTEK', NULL, 'ADDTEK', NULL, ARRAY<VARCHAR(256)>['[','"','A','D','D','T','E','K','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001516, 'SensoPart', NULL, 'SensoPart', NULL, ARRAY<VARCHAR(256)>['[','"','S','E','N','S','O','P','A','R','T','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001517, 'YOBON', NULL, 'YOBON', NULL, ARRAY<VARCHAR(256)>['[','"','Y','O','B','O','N','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001518, 'TRANSCEND', NULL, 'TRANSCEND', NULL, ARRAY<VARCHAR(256)>['[','"','T','R','A','N','S','C','E','N','D','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001519, 'CGS Tape', NULL, 'CGS Tape', NULL, ARRAY<VARCHAR(256)>['[','"','C','G','S',' ','T','A','P','E','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001520, 'APLUS', NULL, 'APLUS', NULL, ARRAY<VARCHAR(256)>['[','"','A','P','L','U','S','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001521, 'mightyZAP', NULL, 'mightyZAP', NULL, ARRAY<VARCHAR(256)>['[','"','M','I','G','H','T','Y','Z','A','P','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001522, 'SSOUSA', NULL, 'SSOUSA', NULL, ARRAY<VARCHAR(256)>['[','"','S','S','O','U','S','A','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001523, 'MAKE-PS', NULL, 'MAKE-PS', NULL, ARRAY<VARCHAR(256)>['[','"','M','A','K','E','-','P','S','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001524, 'O''Reilly Media', NULL, 'O''Reilly Media', NULL, ARRAY<VARCHAR(256)>['[','"','O','''','R','E','I','L','L','Y',' ','M','E','D','I','A','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001525, 'POTATO', NULL, 'POTATO', NULL, ARRAY<VARCHAR(256)>['[','"','P','O','T','A','T','O','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001526, 'CLAIREX', NULL, 'CLAIREX', NULL, ARRAY<VARCHAR(256)>['[','"','C','L','A','I','R','E','X','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001527, 'Suscon', NULL, 'Suscon', NULL, ARRAY<VARCHAR(256)>['[','"','S','U','S','C','O','N','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001528, 'MINILOGIC', NULL, 'MINILOGIC', NULL, ARRAY<VARCHAR(256)>['[','"','M','I','N','I','L','O','G','I','C','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001529, 'WINSON', NULL, 'WINSON', NULL, ARRAY<VARCHAR(256)>['[','"','W','I','N','S','O','N','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001530, 'AVMATRIX', NULL, 'AVMATRIX', NULL, ARRAY<VARCHAR(256)>['[','"','A','V','M','A','T','R','I','X','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001531, 'Cooling Source', NULL, 'Cooling Source', NULL, ARRAY<VARCHAR(256)>['[','"','C','O','O','L','I','N','G',' ','S','O','U','R','C','E','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001532, 'FILTRAN', NULL, 'FILTRAN', NULL, ARRAY<VARCHAR(256)>['[','"','F','I','L','T','R','A','N','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001533, 'TRANSCOM', NULL, 'TRANSCOM', NULL, ARRAY<VARCHAR(256)>['[','"','T','R','A','N','S','C','O','M','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001534, 'OPNEXT', NULL, 'OPNEXT', NULL, ARRAY<VARCHAR(256)>['[','"','O','P','N','E','X','T','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001535, 'Marutsuelec Co., Ltd.', NULL, 'Marutsuelec Co., Ltd.', NULL, ARRAY<VARCHAR(256)>['[','"','M','A','R','U','T','S','U','E','L','E','C',' ','C','O','.',',',' ','L','T','D','.','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001536, 'EDSYN INCORPORATED', NULL, 'EDSYN INCORPORATED', NULL, ARRAY<VARCHAR(256)>['[','"','E','D','S','Y','N',' ','I','N','C','O','R','P','O','R','A','T','E','D','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001537, 'ELBA LUBES', NULL, 'ELBA LUBES', NULL, ARRAY<VARCHAR(256)>['[','"','E','L','B','A',' ','L','U','B','E','S','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001538, 'PENCOM', NULL, 'PENCOM', NULL, ARRAY<VARCHAR(256)>['[','"','P','E','N','C','O','M','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001539, 'SWST', NULL, 'SWST', NULL, ARRAY<VARCHAR(256)>['[','"','S','W','S','T','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001540, 'Airgain', NULL, 'Airgain', NULL, ARRAY<VARCHAR(256)>['[','"','A','I','R','G','A','I','N','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001541, 'SunFounder', NULL, 'SunFounder', NULL, ARRAY<VARCHAR(256)>['[','"','S','U','N','F','O','U','N','D','E','R','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001542, 'VINCOTECH', NULL, 'VINCOTECH', NULL, ARRAY<VARCHAR(256)>['[','"','V','I','N','C','O','T','E','C','H','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001543, 'NetBurner Inc.', NULL, 'NetBurner Inc.', NULL, ARRAY<VARCHAR(256)>['[','"','N','E','T','B','U','R','N','E','R',' ','I','N','C','.','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001544, 'TRANSWITCH', NULL, 'TRANSWITCH', NULL, ARRAY<VARCHAR(256)>['[','"','T','R','A','N','S','W','I','T','C','H','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001545, 'QUANTUM', NULL, 'QUANTUM', NULL, ARRAY<VARCHAR(256)>['[','"','Q','U','A','N','T','U','M','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001546, 'Calmark/Birtcher', NULL, 'Calmark/Birtcher', NULL, ARRAY<VARCHAR(256)>['[','"','C','A','L','M','A','R','K','/','B','I','R','T','C','H','E','R','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001547, 'APM Hexseal', NULL, 'APM Hexseal', NULL, ARRAY<VARCHAR(256)>['[','"','A','P','M',' ','H','E','X','S','E','A','L','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001548, 'GHZTECH', NULL, 'GHZTECH', NULL, ARRAY<VARCHAR(256)>['[','"','G','H','Z','T','E','C','H','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001549, 'Alberko Heatsinkonline', NULL, 'Alberko Heatsinkonline', NULL, ARRAY<VARCHAR(256)>['[','"','A','L','B','E','R','K','O',' ','H','E','A','T','S','I','N','K','O','N','L','I','N','E','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001550, 'GENESI ELETTRONICA', NULL, 'GENESI ELETTRONICA', NULL, ARRAY<VARCHAR(256)>['[','"','G','E','N','E','S','I',' ','E','L','E','T','T','R','O','N','I','C','A','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001551, 'Teltonika', NULL, 'Teltonika', NULL, ARRAY<VARCHAR(256)>['[','"','T','E','L','T','O','N','I','K','A','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001552, 'Harimatec Inc.', NULL, 'Harimatec Inc.', NULL, ARRAY<VARCHAR(256)>['[','"','H','A','R','I','M','A','T','E','C',' ','I','N','C','.','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001553, 'Infraeo Inc.', NULL, 'Infraeo Inc.', NULL, ARRAY<VARCHAR(256)>['[','"','I','N','F','R','A','E','O',' ','I','N','C','.','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001554, 'Gelmec', NULL, 'Gelmec', NULL, ARRAY<VARCHAR(256)>['[','"','G','E','L','M','E','C','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001555, 'PowerFilm Inc.', NULL, 'PowerFilm Inc.', NULL, ARRAY<VARCHAR(256)>['[','"','P','O','W','E','R','F','I','L','M',' ','I','N','C','.','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001556, 'Xsens a Movella brand', NULL, 'Xsens a Movella brand', NULL, ARRAY<VARCHAR(256)>['[','"','X','S','E','N','S',' ','A',' ','M','O','V','E','L','L','A',' ','B','R','A','N','D','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001557, 'ControlByWeb', NULL, 'ControlByWeb', NULL, ARRAY<VARCHAR(256)>['[','"','C','O','N','T','R','O','L','B','Y','W','E','B','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001558, 'ENERGIZER', NULL, 'ENERGIZER', NULL, ARRAY<VARCHAR(256)>['[','"','E','N','E','R','G','I','Z','E','R','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001559, 'NEW TRY', NULL, 'NEW TRY', NULL, ARRAY<VARCHAR(256)>['[','"','N','E','W',' ','T','R','Y','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001560, 'OXFORD', NULL, 'OXFORD', NULL, ARRAY<VARCHAR(256)>['[','"','O','X','F','O','R','D','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001561, 'Neonode Inc.', NULL, 'Neonode Inc.', NULL, ARRAY<VARCHAR(256)>['[','"','N','E','O','N','O','D','E',' ','I','N','C','.','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001562, 'MicroCare Corporation', NULL, 'MicroCare Corporation', NULL, ARRAY<VARCHAR(256)>['[','"','M','I','C','R','O','C','A','R','E',' ','C','O','R','P','O','R','A','T','I','O','N','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001563, 'Trumeter', NULL, 'Trumeter', NULL, ARRAY<VARCHAR(256)>['[','"','T','R','U','M','E','T','E','R','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001564, 'VML', NULL, 'VML', NULL, ARRAY<VARCHAR(256)>['[','"','V','M','L','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001565, 'BB-BATTERY', NULL, 'BB-BATTERY', NULL, ARRAY<VARCHAR(256)>['[','"','B','B','-','B','A','T','T','E','R','Y','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001566, 'Seco', NULL, 'Seco', NULL, ARRAY<VARCHAR(256)>['[','"','S','E','C','O','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001567, 'VTI', NULL, 'VTI', NULL, ARRAY<VARCHAR(256)>['[','"','V','T','I','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001568, 'NIEC', NULL, 'NIEC', NULL, ARRAY<VARCHAR(256)>['[','"','N','I','E','C','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001569, 'PRD Plastics', NULL, 'PRD Plastics', NULL, ARRAY<VARCHAR(256)>['[','"','P','R','D',' ','P','L','A','S','T','I','C','S','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001570, 'SHOULDER', NULL, 'SHOULDER', NULL, ARRAY<VARCHAR(256)>['[','"','S','H','O','U','L','D','E','R','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001571, 'PICKER', NULL, 'PICKER', NULL, ARRAY<VARCHAR(256)>['[','"','P','I','C','K','E','R','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001572, 'EZmotion', NULL, 'EZmotion', NULL, ARRAY<VARCHAR(256)>['[','"','E','Z','M','O','T','I','O','N','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001573, 'Nicslab', NULL, 'Nicslab', NULL, ARRAY<VARCHAR(256)>['[','"','N','I','C','S','L','A','B','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001574, 'YOUDA', NULL, 'YOUDA', NULL, ARRAY<VARCHAR(256)>['[','"','Y','O','U','D','A','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001575, 'BTCPOWER', NULL, 'BTCPOWER', NULL, ARRAY<VARCHAR(256)>['[','"','B','T','C','P','O','W','E','R','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001576, 'Elecrow', NULL, 'Elecrow', NULL, ARRAY<VARCHAR(256)>['[','"','E','L','E','C','R','O','W','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001577, 'ENPIRION', NULL, 'ENPIRION', NULL, ARRAY<VARCHAR(256)>['[','"','E','N','P','I','R','I','O','N','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001578, 'TRIPATH', NULL, 'TRIPATH', NULL, ARRAY<VARCHAR(256)>['[','"','T','R','I','P','A','T','H','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001579, 'SOLITRON', NULL, 'SOLITRON', NULL, ARRAY<VARCHAR(256)>['[','"','S','O','L','I','T','R','O','N','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001580, 'YUANDEAN', NULL, 'YUANDEAN', NULL, ARRAY<VARCHAR(256)>['[','"','Y','U','A','N','D','E','A','N','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001581, 'Beacon EmbeddedWorks', NULL, 'Beacon EmbeddedWorks', NULL, ARRAY<VARCHAR(256)>['[','"','B','E','A','C','O','N',' ','E','M','B','E','D','D','E','D','W','O','R','K','S','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001582, 'Entaniya', NULL, 'Entaniya', NULL, ARRAY<VARCHAR(256)>['[','"','E','N','T','A','N','I','Y','A','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001583, 'Fraenkische USA, LP', NULL, 'Fraenkische USA, LP', NULL, ARRAY<VARCHAR(256)>['[','"','F','R','A','E','N','K','I','S','C','H','E',' ','U','S','A',',',' ','L','P','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001584, 'Newhaven Display Intl', NULL, 'Newhaven Display Intl', NULL, ARRAY<VARCHAR(256)>['[','"','N','E','W','H','A','V','E','N',' ','D','I','S','P','L','A','Y',' ','I','N','T','L','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001585, 'Quarton Inc.', NULL, 'Quarton Inc.', NULL, ARRAY<VARCHAR(256)>['[','"','Q','U','A','R','T','O','N',' ','I','N','C','.','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001586, 'AXIOMTEK', NULL, 'AXIOMTEK', NULL, ARRAY<VARCHAR(256)>['[','"','A','X','I','O','M','T','E','K','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001587, 'Luxtech, LLC', NULL, 'Luxtech, LLC', NULL, ARRAY<VARCHAR(256)>['[','"','L','U','X','T','E','C','H',',',' ','L','L','C','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001588, 'NexTek', NULL, 'NexTek', NULL, ARRAY<VARCHAR(256)>['[','"','N','E','X','T','E','K','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001589, 'RealSense', NULL, 'RealSense', NULL, ARRAY<VARCHAR(256)>['[','"','R','E','A','L','S','E','N','S','E','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001590, 'B&J-USA, Inc.', NULL, 'B&J-USA, Inc.', NULL, ARRAY<VARCHAR(256)>['[','"','B','&','J','-','U','S','A',',',' ','I','N','C','.','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001591, 'DigiKey Kit', NULL, 'DigiKey Kit', NULL, ARRAY<VARCHAR(256)>['[','"','D','I','G','I','K','E','Y',' ','K','I','T','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001592, 'Gearmo', NULL, 'Gearmo', NULL, ARRAY<VARCHAR(256)>['[','"','G','E','A','R','M','O','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001593, 'IOT-BOTS.COM', NULL, 'IOT-BOTS.COM', NULL, ARRAY<VARCHAR(256)>['[','"','I','O','T','-','B','O','T','S','.','C','O','M','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001594, 'NPC', NULL, 'NPC', NULL, ARRAY<VARCHAR(256)>['[','"','N','P','C','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001595, 'Powercast Corporation', NULL, 'Powercast Corporation', NULL, ARRAY<VARCHAR(256)>['[','"','P','O','W','E','R','C','A','S','T',' ','C','O','R','P','O','R','A','T','I','O','N','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001596, 'Sanwa', NULL, 'Sanwa', NULL, ARRAY<VARCHAR(256)>['[','"','S','A','N','W','A','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001597, 'MICROSS', NULL, 'MICROSS', NULL, ARRAY<VARCHAR(256)>['[','"','M','I','C','R','O','S','S','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001598, 'RAMXEED', NULL, 'RAMXEED', NULL, ARRAY<VARCHAR(256)>['[','"','R','A','M','X','E','E','D','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001599, 'Jabil Inc.', NULL, 'Jabil Inc.', NULL, ARRAY<VARCHAR(256)>['[','"','J','A','B','I','L',' ','I','N','C','.','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001600, 'McGraw-Hill Education', NULL, 'McGraw-Hill Education', NULL, ARRAY<VARCHAR(256)>['[','"','M','C','G','R','A','W','-','H','I','L','L',' ','E','D','U','C','A','T','I','O','N','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001601, 'ENTITY ELETTRONICA', NULL, 'ENTITY ELETTRONICA', NULL, ARRAY<VARCHAR(256)>['[','"','E','N','T','I','T','Y',' ','E','L','E','T','T','R','O','N','I','C','A','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001602, 'HOSIDEN', NULL, 'HOSIDEN', NULL, ARRAY<VARCHAR(256)>['[','"','H','O','S','I','D','E','N','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001603, 'CONTRINEX', NULL, 'CONTRINEX', NULL, ARRAY<VARCHAR(256)>['[','"','C','O','N','T','R','I','N','E','X','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001604, 'Embedded Artists', NULL, 'Embedded Artists', NULL, ARRAY<VARCHAR(256)>['[','"','E','M','B','E','D','D','E','D',' ','A','R','T','I','S','T','S','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001605, 'ZORAN', NULL, 'ZORAN', NULL, ARRAY<VARCHAR(256)>['[','"','Z','O','R','A','N','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001606, 'Aquantia Corp', NULL, 'Aquantia Corp', NULL, ARRAY<VARCHAR(256)>['[','"','A','Q','U','A','N','T','I','A',' ','C','O','R','P','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001607, 'Enocean', NULL, 'Enocean', NULL, ARRAY<VARCHAR(256)>['[','"','E','N','O','C','E','A','N','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001608, 'LIGHTEL', NULL, 'LIGHTEL', NULL, ARRAY<VARCHAR(256)>['[','"','L','I','G','H','T','E','L','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001609, 'LOCTITE', NULL, 'LOCTITE', NULL, ARRAY<VARCHAR(256)>['[','"','L','O','C','T','I','T','E','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001610, 'NAIS', NULL, 'NAIS', NULL, ARRAY<VARCHAR(256)>['[','"','N','A','I','S','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001611, 'Perinet', NULL, 'Perinet', NULL, ARRAY<VARCHAR(256)>['[','"','P','E','R','I','N','E','T','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001612, 'REV Robotics', NULL, 'REV Robotics', NULL, ARRAY<VARCHAR(256)>['[','"','R','E','V',' ','R','O','B','O','T','I','C','S','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001613, 'Bluelec', NULL, 'Bluelec', NULL, ARRAY<VARCHAR(256)>['[','"','B','L','U','E','L','E','C','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001614, 'DComponents', NULL, 'DComponents', NULL, ARRAY<VARCHAR(256)>['[','"','D','C','O','M','P','O','N','E','N','T','S','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001615, 'Kable Kontrol', NULL, 'Kable Kontrol', NULL, ARRAY<VARCHAR(256)>['[','"','K','A','B','L','E',' ','K','O','N','T','R','O','L','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001616, 'Kenco Label & Tag', NULL, 'Kenco Label & Tag', NULL, ARRAY<VARCHAR(256)>['[','"','K','E','N','C','O',' ','L','A','B','E','L',' ','&',' ','T','A','G','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001617, 'Tronex', NULL, 'Tronex', NULL, ARRAY<VARCHAR(256)>['[','"','T','R','O','N','E','X','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001618, 'Ignion', NULL, 'Ignion', NULL, ARRAY<VARCHAR(256)>['[','"','I','G','N','I','O','N','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001619, 'PTSolns', NULL, 'PTSolns', NULL, ARRAY<VARCHAR(256)>['[','"','P','T','S','O','L','N','S','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001620, 'Pycom Ltd.', NULL, 'Pycom Ltd.', NULL, ARRAY<VARCHAR(256)>['[','"','P','Y','C','O','M',' ','L','T','D','.','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001621, 'UDINFO', NULL, 'UDINFO', NULL, ARRAY<VARCHAR(256)>['[','"','U','D','I','N','F','O','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001622, 'Corelis', NULL, 'Corelis', NULL, ARRAY<VARCHAR(256)>['[','"','C','O','R','E','L','I','S','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001623, 'D-Line USA', NULL, 'D-Line USA', NULL, ARRAY<VARCHAR(256)>['[','"','D','-','L','I','N','E',' ','U','S','A','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001624, 'ETAL', NULL, 'ETAL', NULL, ARRAY<VARCHAR(256)>['[','"','E','T','A','L','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001625, 'Arieltech', NULL, 'Arieltech', NULL, ARRAY<VARCHAR(256)>['[','"','A','R','I','E','L','T','E','C','H','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001626, 'Bruckewell', NULL, 'Bruckewell', NULL, ARRAY<VARCHAR(256)>['[','"','B','R','U','C','K','E','W','E','L','L','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001627, 'Fujicon', NULL, 'Fujicon', NULL, ARRAY<VARCHAR(256)>['[','"','F','U','J','I','C','O','N','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001628, 'Labsland', NULL, 'Labsland', NULL, ARRAY<VARCHAR(256)>['[','"','L','A','B','S','L','A','N','D','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001629, 'Onion Corporation', NULL, 'Onion Corporation', NULL, ARRAY<VARCHAR(256)>['[','"','O','N','I','O','N',' ','C','O','R','P','O','R','A','T','I','O','N','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001630, 'Option NV', NULL, 'Option NV', NULL, ARRAY<VARCHAR(256)>['[','"','O','P','T','I','O','N',' ','N','V','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001631, 'VARITRONIX', NULL, 'VARITRONIX', NULL, ARRAY<VARCHAR(256)>['[','"','V','A','R','I','T','R','O','N','I','X','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001632, 'Agiltron Inc', NULL, 'Agiltron Inc', NULL, ARRAY<VARCHAR(256)>['[','"','A','G','I','L','T','R','O','N',' ','I','N','C','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001633, 'enDAQ', NULL, 'enDAQ', NULL, ARRAY<VARCHAR(256)>['[','"','E','N','D','A','Q','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001634, 'ENEDO', NULL, 'ENEDO', NULL, ARRAY<VARCHAR(256)>['[','"','E','N','E','D','O','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001635, 'Moticont', NULL, 'Moticont', NULL, ARRAY<VARCHAR(256)>['[','"','M','O','T','I','C','O','N','T','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001636, 'Azumo', NULL, 'Azumo', NULL, ARRAY<VARCHAR(256)>['[','"','A','Z','U','M','O','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001637, 'CITEL', NULL, 'CITEL', NULL, ARRAY<VARCHAR(256)>['[','"','C','I','T','E','L','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001638, 'Coolmag TC', NULL, 'Coolmag TC', NULL, ARRAY<VARCHAR(256)>['[','"','C','O','O','L','M','A','G',' ','T','C','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001639, 'JJM', NULL, 'JJM', NULL, ARRAY<VARCHAR(256)>['[','"','J','J','M','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001640, 'SUYIN-USA', NULL, 'SUYIN-USA', NULL, ARRAY<VARCHAR(256)>['[','"','S','U','Y','I','N','-','U','S','A','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001641, 'VIETES', NULL, 'VIETES', NULL, ARRAY<VARCHAR(256)>['[','"','V','I','E','T','E','S','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001642, 'metraTec', NULL, 'metraTec', NULL, ARRAY<VARCHAR(256)>['[','"','M','E','T','R','A','T','E','C','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001643, 'OPTREX', NULL, 'OPTREX', NULL, ARRAY<VARCHAR(256)>['[','"','O','P','T','R','E','X','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001644, 'P1dB Inc', NULL, 'P1dB Inc', NULL, ARRAY<VARCHAR(256)>['[','"','P','1','D','B',' ','I','N','C','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001645, 'Pervasive Displays', NULL, 'Pervasive Displays', NULL, ARRAY<VARCHAR(256)>['[','"','P','E','R','V','A','S','I','V','E',' ','D','I','S','P','L','A','Y','S','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001646, 'REYAX', NULL, 'REYAX', NULL, ARRAY<VARCHAR(256)>['[','"','R','E','Y','A','X','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001647, 'SOSHIN', NULL, 'SOSHIN', NULL, ARRAY<VARCHAR(256)>['[','"','S','O','S','H','I','N','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001648, 'Vantis', NULL, 'Vantis', NULL, ARRAY<VARCHAR(256)>['[','"','V','A','N','T','I','S','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001649, 'Amtery Corporation', NULL, 'Amtery Corporation', NULL, ARRAY<VARCHAR(256)>['[','"','A','M','T','E','R','Y',' ','C','O','R','P','O','R','A','T','I','O','N','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001650, 'GroupGets LLC', NULL, 'GroupGets LLC', NULL, ARRAY<VARCHAR(256)>['[','"','G','R','O','U','P','G','E','T','S',' ','L','L','C','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001651, 'Tekscan', NULL, 'Tekscan', NULL, ARRAY<VARCHAR(256)>['[','"','T','E','K','S','C','A','N','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001652, 'TokyLabs', NULL, 'TokyLabs', NULL, ARRAY<VARCHAR(256)>['[','"','T','O','K','Y','L','A','B','S','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001653, 'Unrise USA', NULL, 'Unrise USA', NULL, ARRAY<VARCHAR(256)>['[','"','U','N','R','I','S','E',' ','U','S','A','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001654, 'WILLAS', NULL, 'WILLAS', NULL, ARRAY<VARCHAR(256)>['[','"','W','I','L','L','A','S','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001655, 'Ascentta', NULL, 'Ascentta', NULL, ARRAY<VARCHAR(256)>['[','"','A','S','C','E','N','T','T','A','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001656, 'ESPROS Photonics AG', NULL, 'ESPROS Photonics AG', NULL, ARRAY<VARCHAR(256)>['[','"','E','S','P','R','O','S',' ','P','H','O','T','O','N','I','C','S',' ','A','G','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001657, 'Opsero', NULL, 'Opsero', NULL, ARRAY<VARCHAR(256)>['[','"','O','P','S','E','R','O','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001658, 'Soundskrit, Inc.', NULL, 'Soundskrit, Inc.', NULL, ARRAY<VARCHAR(256)>['[','"','S','O','U','N','D','S','K','R','I','T',',',' ','I','N','C','.','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001659, 'STIRRI', NULL, 'STIRRI', NULL, ARRAY<VARCHAR(256)>['[','"','S','T','I','R','R','I','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001660, 'Workswell', NULL, 'Workswell', NULL, ARRAY<VARCHAR(256)>['[','"','W','O','R','K','S','W','E','L','L','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001661, 'YOUWANG', NULL, 'YOUWANG', NULL, ARRAY<VARCHAR(256)>['[','"','Y','O','U','W','A','N','G','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001662, 'AIStorm, Inc', NULL, 'AIStorm, Inc', NULL, ARRAY<VARCHAR(256)>['[','"','A','I','S','T','O','R','M',',',' ','I','N','C','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001663, 'Canon', NULL, 'Canon', NULL, ARRAY<VARCHAR(256)>['[','"','C','A','N','O','N','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001664, 'FRESH DIGIT', NULL, 'FRESH DIGIT', NULL, ARRAY<VARCHAR(256)>['[','"','F','R','E','S','H',' ','D','I','G','I','T','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001665, 'Lantronix Canada ULC', NULL, 'Lantronix Canada ULC', NULL, ARRAY<VARCHAR(256)>['[','"','L','A','N','T','R','O','N','I','X',' ','C','A','N','A','D','A',' ','U','L','C','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001666, 'Zeroplus', NULL, 'Zeroplus', NULL, ARRAY<VARCHAR(256)>['[','"','Z','E','R','O','P','L','U','S','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001667, 'ARCTIC', NULL, 'ARCTIC', NULL, ARRAY<VARCHAR(256)>['[','"','A','R','C','T','I','C','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001668, 'Datawave LLC', NULL, 'Datawave LLC', NULL, ARRAY<VARCHAR(256)>['[','"','D','A','T','A','W','A','V','E',' ','L','L','C','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001669, 'FLIR Lepton', NULL, 'FLIR Lepton', NULL, ARRAY<VARCHAR(256)>['[','"','F','L','I','R',' ','L','E','P','T','O','N','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001670, 'GE', NULL, 'GE', NULL, ARRAY<VARCHAR(256)>['[','"','G','E','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001671, 'Joulescope®', NULL, 'Joulescope®', NULL, ARRAY<VARCHAR(256)>['[','"','J','O','U','L','E','S','C','O','P','E','®','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001672, 'Terabee SAS', NULL, 'Terabee SAS', NULL, ARRAY<VARCHAR(256)>['[','"','T','E','R','A','B','E','E',' ','S','A','S','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001673, 'USBGear', NULL, 'USBGear', NULL, ARRAY<VARCHAR(256)>['[','"','U','S','B','G','E','A','R','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001674, 'CADEKA', NULL, 'CADEKA', NULL, ARRAY<VARCHAR(256)>['[','"','C','A','D','E','K','A','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001675, 'DECIDE4ACTION', NULL, 'DECIDE4ACTION', NULL, ARRAY<VARCHAR(256)>['[','"','D','E','C','I','D','E','4','A','C','T','I','O','N','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001676, 'MPLUSE', NULL, 'MPLUSE', NULL, ARRAY<VARCHAR(256)>['[','"','M','P','L','U','S','E','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001677, 'Senix Corporation', NULL, 'Senix Corporation', NULL, ARRAY<VARCHAR(256)>['[','"','S','E','N','I','X',' ','C','O','R','P','O','R','A','T','I','O','N','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001678, 'Spyraflo, Inc.', NULL, 'Spyraflo, Inc.', NULL, ARRAY<VARCHAR(256)>['[','"','S','P','Y','R','A','F','L','O',',',' ','I','N','C','.','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001679, 'WAVEPIA.,Co.Ltd', NULL, 'WAVEPIA.,Co.Ltd', NULL, ARRAY<VARCHAR(256)>['[','"','W','A','V','E','P','I','A','.',',','C','O','.','L','T','D','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001680, 'B&J-USA Inc.', NULL, 'B&J-USA Inc.', NULL, ARRAY<VARCHAR(256)>['[','"','B','&','J','-','U','S','A',' ','I','N','C','.','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001681, 'BVLED', NULL, 'BVLED', NULL, ARRAY<VARCHAR(256)>['[','"','B','V','L','E','D','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001682, 'ADLINK', NULL, 'ADLINK', NULL, ARRAY<VARCHAR(256)>['[','"','A','D','L','I','N','K','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001683, 'APACER', NULL, 'APACER', NULL, ARRAY<VARCHAR(256)>['[','"','A','P','A','C','E','R','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001684, 'AZ Displays', NULL, 'AZ Displays', NULL, ARRAY<VARCHAR(256)>['[','"','A','Z',' ','D','I','S','P','L','A','Y','S','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001685, 'ETL', NULL, 'ETL', NULL, ARRAY<VARCHAR(256)>['[','"','E','T','L','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001686, 'Garmin Canada Inc.', NULL, 'Garmin Canada Inc.', NULL, ARRAY<VARCHAR(256)>['[','"','G','A','R','M','I','N',' ','C','A','N','A','D','A',' ','I','N','C','.','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001687, 'Glass Acoustic Innovations Co. Ltd.', NULL, 'Glass Acoustic Innovations Co. Ltd.', NULL, ARRAY<VARCHAR(256)>['[','"','G','L','A','S','S',' ','A','C','O','U','S','T','I','C',' ','I','N','N','O','V','A','T','I','O','N','S',' ','C','O','.',' ','L','T','D','.','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001688, 'KUKA Robotics Corporation', NULL, 'KUKA Robotics Corporation', NULL, ARRAY<VARCHAR(256)>['[','"','K','U','K','A',' ','R','O','B','O','T','I','C','S',' ','C','O','R','P','O','R','A','T','I','O','N','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001689, 'LAPIS', NULL, 'LAPIS', NULL, ARRAY<VARCHAR(256)>['[','"','L','A','P','I','S','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001690, 'NEXCOM', NULL, 'NEXCOM', NULL, ARRAY<VARCHAR(256)>['[','"','N','E','X','C','O','M','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001691, 'Yamar', NULL, 'Yamar', NULL, ARRAY<VARCHAR(256)>['[','"','Y','A','M','A','R','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001692, '5G HUB', NULL, '5G HUB', NULL, ARRAY<VARCHAR(256)>['[','"','5','G',' ','H','U','B','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001693, 'AMX Solar', NULL, 'AMX Solar', NULL, ARRAY<VARCHAR(256)>['[','"','A','M','X',' ','S','O','L','A','R','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001694, 'Arducam', NULL, 'Arducam', NULL, ARRAY<VARCHAR(256)>['[','"','A','R','D','U','C','A','M','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001695, 'Compulab', NULL, 'Compulab', NULL, ARRAY<VARCHAR(256)>['[','"','C','O','M','P','U','L','A','B','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001696, 'EMOSAFE', NULL, 'EMOSAFE', NULL, ARRAY<VARCHAR(256)>['[','"','E','M','O','S','A','F','E','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001697, 'EnerSys', NULL, 'EnerSys', NULL, ARRAY<VARCHAR(256)>['[','"','E','N','E','R','S','Y','S','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001698, 'Focus LCDs', NULL, 'Focus LCDs', NULL, ARRAY<VARCHAR(256)>['[','"','F','O','C','U','S',' ','L','C','D','S','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001699, 'GP BATTERIES', NULL, 'GP BATTERIES', NULL, ARRAY<VARCHAR(256)>['[','"','G','P',' ','B','A','T','T','E','R','I','E','S','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001700, 'IKALOGIC', NULL, 'IKALOGIC', NULL, ARRAY<VARCHAR(256)>['[','"','I','K','A','L','O','G','I','C','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001701, 'InPlay Inc', NULL, 'InPlay Inc', NULL, ARRAY<VARCHAR(256)>['[','"','I','N','P','L','A','Y',' ','I','N','C','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001702, 'Micrium Inc.', NULL, 'Micrium Inc.', NULL, ARRAY<VARCHAR(256)>['[','"','M','I','C','R','I','U','M',' ','I','N','C','.','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001703, 'Neurochrome', NULL, 'Neurochrome', NULL, ARRAY<VARCHAR(256)>['[','"','N','E','U','R','O','C','H','R','O','M','E','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001704, 'NexCOBOT CO., LTD.', NULL, 'NexCOBOT CO., LTD.', NULL, ARRAY<VARCHAR(256)>['[','"','N','E','X','C','O','B','O','T',' ','C','O','.',',',' ','L','T','D','.','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001705, 'Omnielektronik', NULL, 'Omnielektronik', NULL, ARRAY<VARCHAR(256)>['[','"','O','M','N','I','E','L','E','K','T','R','O','N','I','K','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001706, 'PMC-Sierra', NULL, 'PMC-Sierra', NULL, ARRAY<VARCHAR(256)>['[','"','P','M','C','-','S','I','E','R','R','A','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001707, 'Portescap', NULL, 'Portescap', NULL, ARRAY<VARCHAR(256)>['[','"','P','O','R','T','E','S','C','A','P','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001708, 'Powersight', NULL, 'Powersight', NULL, ARRAY<VARCHAR(256)>['[','"','P','O','W','E','R','S','I','G','H','T','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001709, 'Qoitech AB', NULL, 'Qoitech AB', NULL, ARRAY<VARCHAR(256)>['[','"','Q','O','I','T','E','C','H',' ','A','B','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001710, 'SONGCHUAN', NULL, 'SONGCHUAN', NULL, ARRAY<VARCHAR(256)>['[','"','S','O','N','G','C','H','U','A','N','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001711, 'STAF Corporation', NULL, 'STAF Corporation', NULL, ARRAY<VARCHAR(256)>['[','"','S','T','A','F',' ','C','O','R','P','O','R','A','T','I','O','N','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001712, 'Tecdia Inc.', NULL, 'Tecdia Inc.', NULL, ARRAY<VARCHAR(256)>['[','"','T','E','C','D','I','A',' ','I','N','C','.','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001713, 'Availink', NULL, 'Availink', NULL, ARRAY<VARCHAR(256)>['[','"','A','V','A','I','L','I','N','K','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001714, 'Berkeley Nuclonics Corporation', NULL, 'Berkeley Nuclonics Corporation', NULL, ARRAY<VARCHAR(256)>['[','"','B','E','R','K','E','L','E','Y',' ','N','U','C','L','O','N','I','C','S',' ','C','O','R','P','O','R','A','T','I','O','N','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001715, 'Dgtronix', NULL, 'Dgtronix', NULL, ARRAY<VARCHAR(256)>['[','"','D','G','T','R','O','N','I','X','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001716, 'ETRI', NULL, 'ETRI', NULL, ARRAY<VARCHAR(256)>['[','"','E','T','R','I','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001717, 'Feztek', NULL, 'Feztek', NULL, ARRAY<VARCHAR(256)>['[','"','F','E','Z','T','E','K','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001718, 'QNAP', NULL, 'QNAP', NULL, ARRAY<VARCHAR(256)>['[','"','Q','N','A','P','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001719, 'SAFT', NULL, 'SAFT', NULL, ARRAY<VARCHAR(256)>['[','"','S','A','F','T','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001720, 'SAN-TRON', NULL, 'SAN-TRON', NULL, ARRAY<VARCHAR(256)>['[','"','S','A','N','-','T','R','O','N','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001721, 'SLS', NULL, 'SLS', NULL, ARRAY<VARCHAR(256)>['[','"','S','L','S','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001722, 'TE Kemtron', NULL, 'TE Kemtron', NULL, ARRAY<VARCHAR(256)>['[','"','T','E',' ','K','E','M','T','R','O','N','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001723, 'VaOpto', NULL, 'VaOpto', NULL, ARRAY<VARCHAR(256)>['[','"','V','A','O','P','T','O','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001724, 'DOW-KEY', NULL, 'DOW-KEY', NULL, ARRAY<VARCHAR(256)>['[','"','D','O','W','-','K','E','Y','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001725, 'Ebelong', NULL, 'Ebelong', NULL, ARRAY<VARCHAR(256)>['[','"','E','B','E','L','O','N','G','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001726, 'Enfis', NULL, 'Enfis', NULL, ARRAY<VARCHAR(256)>['[','"','E','N','F','I','S','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001727, 'EPC Space, LLC', NULL, 'EPC Space, LLC', NULL, ARRAY<VARCHAR(256)>['[','"','E','P','C',' ','S','P','A','C','E',',',' ','L','L','C','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001728, 'FIBAsource', NULL, 'FIBAsource', NULL, ARRAY<VARCHAR(256)>['[','"','F','I','B','A','S','O','U','R','C','E','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001729, 'Gardtec Incorporated', NULL, 'Gardtec Incorporated', NULL, ARRAY<VARCHAR(256)>['[','"','G','A','R','D','T','E','C',' ','I','N','C','O','R','P','O','R','A','T','E','D','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001730, 'Innergie', NULL, 'Innergie', NULL, ARRAY<VARCHAR(256)>['[','"','I','N','N','E','R','G','I','E','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001731, 'LUXPIA', NULL, 'LUXPIA', NULL, ARRAY<VARCHAR(256)>['[','"','L','U','X','P','I','A','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001732, 'Raytac', NULL, 'Raytac', NULL, ARRAY<VARCHAR(256)>['[','"','R','A','Y','T','A','C','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001733, 'RELPOL S.A.', NULL, 'RELPOL S.A.', NULL, ARRAY<VARCHAR(256)>['[','"','R','E','L','P','O','L',' ','S','.','A','.','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001734, 'Schmalz Inc', NULL, 'Schmalz Inc', NULL, ARRAY<VARCHAR(256)>['[','"','S','C','H','M','A','L','Z',' ','I','N','C','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001735, 'SIGE', NULL, 'SIGE', NULL, ARRAY<VARCHAR(256)>['[','"','S','I','G','E','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001736, 'Sigfox', NULL, 'Sigfox', NULL, ARRAY<VARCHAR(256)>['[','"','S','I','G','F','O','X','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001737, 'SkyMirr', NULL, 'SkyMirr', NULL, ARRAY<VARCHAR(256)>['[','"','S','K','Y','M','I','R','R','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001738, 'Starlogixs', NULL, 'Starlogixs', NULL, ARRAY<VARCHAR(256)>['[','"','S','T','A','R','L','O','G','I','X','S','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001739, 'SVTronics Inc.', NULL, 'SVTronics Inc.', NULL, ARRAY<VARCHAR(256)>['[','"','S','V','T','R','O','N','I','C','S',' ','I','N','C','.','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001740, 'XTool', NULL, 'XTool', NULL, ARRAY<VARCHAR(256)>['[','"','X','T','O','O','L','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001741, 'CRYPTNOX', NULL, 'CRYPTNOX', NULL, ARRAY<VARCHAR(256)>['[','"','C','R','Y','P','T','N','O','X','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001742, 'Fingerprint Cards AB', NULL, 'Fingerprint Cards AB', NULL, ARRAY<VARCHAR(256)>['[','"','F','I','N','G','E','R','P','R','I','N','T',' ','C','A','R','D','S',' ','A','B','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001743, 'HALA', NULL, 'HALA', NULL, ARRAY<VARCHAR(256)>['[','"','H','A','L','A','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001744, 'Hvtools', NULL, 'Hvtools', NULL, ARRAY<VARCHAR(256)>['[','"','H','V','T','O','O','L','S','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001745, 'iCana', NULL, 'iCana', NULL, ARRAY<VARCHAR(256)>['[','"','I','C','A','N','A','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001746, 'ICOMTECH, INC.', NULL, 'ICOMTECH, INC.', NULL, ARRAY<VARCHAR(256)>['[','"','I','C','O','M','T','E','C','H',',',' ','I','N','C','.','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001747, 'Mabuchi Motor', NULL, 'Mabuchi Motor', NULL, ARRAY<VARCHAR(256)>['[','"','M','A','B','U','C','H','I',' ','M','O','T','O','R','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001748, 'Midas Displays', NULL, 'Midas Displays', NULL, ARRAY<VARCHAR(256)>['[','"','M','I','D','A','S',' ','D','I','S','P','L','A','Y','S','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001749, 'NanoSen', NULL, 'NanoSen', NULL, ARRAY<VARCHAR(256)>['[','"','N','A','N','O','S','E','N','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001750, 'NeoCortec', NULL, 'NeoCortec', NULL, ARRAY<VARCHAR(256)>['[','"','N','E','O','C','O','R','T','E','C','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001751, 'OTAX', NULL, 'OTAX', NULL, ARRAY<VARCHAR(256)>['[','"','O','T','A','X','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001752, 'Pro''sKit', NULL, 'Pro''sKit', NULL, ARRAY<VARCHAR(256)>['[','"','P','R','O','''','S','K','I','T','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001753, 'TygerClaw', NULL, 'TygerClaw', NULL, ARRAY<VARCHAR(256)>['[','"','T','Y','G','E','R','C','L','A','W','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001754, 'UBIROS INC.', NULL, 'UBIROS INC.', NULL, ARRAY<VARCHAR(256)>['[','"','U','B','I','R','O','S',' ','I','N','C','.','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001755, 'Vividia', NULL, 'Vividia', NULL, ARRAY<VARCHAR(256)>['[','"','V','I','V','I','D','I','A','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001756, 'Xavitech', NULL, 'Xavitech', NULL, ARRAY<VARCHAR(256)>['[','"','X','A','V','I','T','E','C','H','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001757, '3M Healthcare', NULL, '3M Healthcare', NULL, ARRAY<VARCHAR(256)>['[','"','3','M',' ','H','E','A','L','T','H','C','A','R','E','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001758, 'Cubit', NULL, 'Cubit', NULL, ARRAY<VARCHAR(256)>['[','"','C','U','B','I','T','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001759, 'Dobot', NULL, 'Dobot', NULL, ARRAY<VARCHAR(256)>['[','"','D','O','B','O','T','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001760, 'Fedco Batteries', NULL, 'Fedco Batteries', NULL, ARRAY<VARCHAR(256)>['[','"','F','E','D','C','O',' ','B','A','T','T','E','R','I','E','S','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001761, 'Hiblow', NULL, 'Hiblow', NULL, ARRAY<VARCHAR(256)>['[','"','H','I','B','L','O','W','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001762, 'HUMIREL', NULL, 'HUMIREL', NULL, ARRAY<VARCHAR(256)>['[','"','H','U','M','I','R','E','L','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001763, 'INTRONICS', NULL, 'INTRONICS', NULL, ARRAY<VARCHAR(256)>['[','"','I','N','T','R','O','N','I','C','S','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001764, 'IoTize', NULL, 'IoTize', NULL, ARRAY<VARCHAR(256)>['[','"','I','O','T','I','Z','E','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001765, 'IPDiA', NULL, 'IPDiA', NULL, ARRAY<VARCHAR(256)>['[','"','I','P','D','I','A','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001766, 'LogiSwitch', NULL, 'LogiSwitch', NULL, ARRAY<VARCHAR(256)>['[','"','L','O','G','I','S','W','I','T','C','H','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001767, 'Micro:bit', NULL, 'Micro:bit', NULL, ARRAY<VARCHAR(256)>['[','"','M','I','C','R','O',':','B','I','T','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001768, 'MMB Networks', NULL, 'MMB Networks', NULL, ARRAY<VARCHAR(256)>['[','"','M','M','B',' ','N','E','T','W','O','R','K','S','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001769, 'Moddable', NULL, 'Moddable', NULL, ARRAY<VARCHAR(256)>['[','"','M','O','D','D','A','B','L','E','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001770, 'mydpi', NULL, 'mydpi', NULL, ARRAY<VARCHAR(256)>['[','"','M','Y','D','P','I','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001771, 'Nextera Video', NULL, 'Nextera Video', NULL, ARRAY<VARCHAR(256)>['[','"','N','E','X','T','E','R','A',' ','V','I','D','E','O','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001772, 'Noveltronics', NULL, 'Noveltronics', NULL, ARRAY<VARCHAR(256)>['[','"','N','O','V','E','L','T','R','O','N','I','C','S','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001773, 'Orion RepTech', NULL, 'Orion RepTech', NULL, ARRAY<VARCHAR(256)>['[','"','O','R','I','O','N',' ','R','E','P','T','E','C','H','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001774, 'Pacific Lasertec', NULL, 'Pacific Lasertec', NULL, ARRAY<VARCHAR(256)>['[','"','P','A','C','I','F','I','C',' ','L','A','S','E','R','T','E','C','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001775, 'Protempis', NULL, 'Protempis', NULL, ARRAY<VARCHAR(256)>['[','"','P','R','O','T','E','M','P','I','S','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001776, 'Pulsar', NULL, 'Pulsar', NULL, ARRAY<VARCHAR(256)>['[','"','P','U','L','S','A','R','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001777, 'Quadcept Inc.', NULL, 'Quadcept Inc.', NULL, ARRAY<VARCHAR(256)>['[','"','Q','U','A','D','C','E','P','T',' ','I','N','C','.','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001778, 'RangeAnt', NULL, 'RangeAnt', NULL, ARRAY<VARCHAR(256)>['[','"','R','A','N','G','E','A','N','T','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001779, 'RFID Inc', NULL, 'RFID Inc', NULL, ARRAY<VARCHAR(256)>['[','"','R','F','I','D',' ','I','N','C','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001780, 'Triscend', NULL, 'Triscend', NULL, ARRAY<VARCHAR(256)>['[','"','T','R','I','S','C','E','N','D','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001781, 'Ultra Librarian', NULL, 'Ultra Librarian', NULL, ARRAY<VARCHAR(256)>['[','"','U','L','T','R','A',' ','L','I','B','R','A','R','I','A','N','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001782, 'VigilLink', NULL, 'VigilLink', NULL, ARRAY<VARCHAR(256)>['[','"','V','I','G','I','L','L','I','N','K','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001783, 'ZIEHL', NULL, 'ZIEHL', NULL, ARRAY<VARCHAR(256)>['[','"','Z','I','E','H','L','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001784, 'Zubax Robotics', NULL, 'Zubax Robotics', NULL, ARRAY<VARCHAR(256)>['[','"','Z','U','B','A','X',' ','R','O','B','O','T','I','C','S','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001785, 'Aconno', NULL, 'Aconno', NULL, ARRAY<VARCHAR(256)>['[','"','A','C','O','N','N','O','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001786, 'Aitronics Inc.', NULL, 'Aitronics Inc.', NULL, ARRAY<VARCHAR(256)>['[','"','A','I','T','R','O','N','I','C','S',' ','I','N','C','.','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001787, 'ArkX Laboratories', NULL, 'ArkX Laboratories', NULL, ARRAY<VARCHAR(256)>['[','"','A','R','K','X',' ','L','A','B','O','R','A','T','O','R','I','E','S','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001788, 'Asus', NULL, 'Asus', NULL, ARRAY<VARCHAR(256)>['[','"','A','S','U','S','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001789, 'AURIS', NULL, 'AURIS', NULL, ARRAY<VARCHAR(256)>['[','"','A','U','R','I','S','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001790, 'Benjamin VERNOUX', NULL, 'Benjamin VERNOUX', NULL, ARRAY<VARCHAR(256)>['[','"','B','E','N','J','A','M','I','N',' ','V','E','R','N','O','U','X','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001791, 'CAVU', NULL, 'CAVU', NULL, ARRAY<VARCHAR(256)>['[','"','C','A','V','U','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001792, 'CODIXX AG', NULL, 'CODIXX AG', NULL, ARRAY<VARCHAR(256)>['[','"','C','O','D','I','X','X',' ','A','G','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001793, 'Corsair', NULL, 'Corsair', NULL, ARRAY<VARCHAR(256)>['[','"','C','O','R','S','A','I','R','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001794, 'Critical Link LLC', NULL, 'Critical Link LLC', NULL, ARRAY<VARCHAR(256)>['[','"','C','R','I','T','I','C','A','L',' ','L','I','N','K',' ','L','L','C','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001795, 'DENRYO', NULL, 'DENRYO', NULL, ARRAY<VARCHAR(256)>['[','"','D','E','N','R','Y','O','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001796, 'DILABS', NULL, 'DILABS', NULL, ARRAY<VARCHAR(256)>['[','"','D','I','L','A','B','S','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001797, 'E Ink Corporation', NULL, 'E Ink Corporation', NULL, ARRAY<VARCHAR(256)>['[','"','E',' ','I','N','K',' ','C','O','R','P','O','R','A','T','I','O','N','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001798, 'Embention', NULL, 'Embention', NULL, ARRAY<VARCHAR(256)>['[','"','E','M','B','E','N','T','I','O','N','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001799, 'EMO Inc.', NULL, 'EMO Inc.', NULL, ARRAY<VARCHAR(256)>['[','"','E','M','O',' ','I','N','C','.','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001800, 'FORYARD', NULL, 'FORYARD', NULL, ARRAY<VARCHAR(256)>['[','"','F','O','R','Y','A','R','D','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001801, 'Himax', NULL, 'Himax', NULL, ARRAY<VARCHAR(256)>['[','"','H','I','M','A','X','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001802, 'Inphi Corporation', NULL, 'Inphi Corporation', NULL, ARRAY<VARCHAR(256)>['[','"','I','N','P','H','I',' ','C','O','R','P','O','R','A','T','I','O','N','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001803, 'IOT747', NULL, 'IOT747', NULL, ARRAY<VARCHAR(256)>['[','"','I','O','T','7','4','7','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001804, 'Labjack Corporation', NULL, 'Labjack Corporation', NULL, ARRAY<VARCHAR(256)>['[','"','L','A','B','J','A','C','K',' ','C','O','R','P','O','R','A','T','I','O','N','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001805, 'LightWare LiDAR Inc.', NULL, 'LightWare LiDAR Inc.', NULL, ARRAY<VARCHAR(256)>['[','"','L','I','G','H','T','W','A','R','E',' ','L','I','D','A','R',' ','I','N','C','.','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001806, 'Lucent', NULL, 'Lucent', NULL, ARRAY<VARCHAR(256)>['[','"','L','U','C','E','N','T','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001807, 'LulzBot', NULL, 'LulzBot', NULL, ARRAY<VARCHAR(256)>['[','"','L','U','L','Z','B','O','T','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001808, 'Micropower Battery Company', NULL, 'Micropower Battery Company', NULL, ARRAY<VARCHAR(256)>['[','"','M','I','C','R','O','P','O','W','E','R',' ','B','A','T','T','E','R','Y',' ','C','O','M','P','A','N','Y','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001809, 'MICROTEST', NULL, 'MICROTEST', NULL, ARRAY<VARCHAR(256)>['[','"','M','I','C','R','O','T','E','S','T','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001810, 'Netsol', NULL, 'Netsol', NULL, ARRAY<VARCHAR(256)>['[','"','N','E','T','S','O','L','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001811, 'Neware', NULL, 'Neware', NULL, ARRAY<VARCHAR(256)>['[','"','N','E','W','A','R','E','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001812, 'Pacific Goal', NULL, 'Pacific Goal', NULL, ARRAY<VARCHAR(256)>['[','"','P','A','C','I','F','I','C',' ','G','O','A','L','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001813, 'PalmSens BV', NULL, 'PalmSens BV', NULL, ARRAY<VARCHAR(256)>['[','"','P','A','L','M','S','E','N','S',' ','B','V','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001814, 'Parretto', NULL, 'Parretto', NULL, ARRAY<VARCHAR(256)>['[','"','P','A','R','R','E','T','T','O','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001815, 'PETERMANN', NULL, 'PETERMANN', NULL, ARRAY<VARCHAR(256)>['[','"','P','E','T','E','R','M','A','N','N','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001816, 'Ridgeback Lighting LLC', NULL, 'Ridgeback Lighting LLC', NULL, ARRAY<VARCHAR(256)>['[','"','R','I','D','G','E','B','A','C','K',' ','L','I','G','H','T','I','N','G',' ','L','L','C','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001817, 'ROBOT DOMESTICI SRL', NULL, 'ROBOT DOMESTICI SRL', NULL, ARRAY<VARCHAR(256)>['[','"','R','O','B','O','T',' ','D','O','M','E','S','T','I','C','I',' ','S','R','L','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001818, 'Rose+Krieger', NULL, 'Rose+Krieger', NULL, ARRAY<VARCHAR(256)>['[','"','R','O','S','E','+','K','R','I','E','G','E','R','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001819, 'Sagrad Inc.', NULL, 'Sagrad Inc.', NULL, ARRAY<VARCHAR(256)>['[','"','S','A','G','R','A','D',' ','I','N','C','.','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001820, 'TALLYSMAN', NULL, 'TALLYSMAN', NULL, ARRAY<VARCHAR(256)>['[','"','T','A','L','L','Y','S','M','A','N','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001821, 'Techship', NULL, 'Techship', NULL, ARRAY<VARCHAR(256)>['[','"','T','E','C','H','S','H','I','P','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001822, 'Thermaltronics', NULL, 'Thermaltronics', NULL, ARRAY<VARCHAR(256)>['[','"','T','H','E','R','M','A','L','T','R','O','N','I','C','S','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001823, 'Vizmonet', NULL, 'Vizmonet', NULL, ARRAY<VARCHAR(256)>['[','"','V','I','Z','M','O','N','E','T','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
(9001824, 'Zero ASIC Corporation', NULL, 'Zero ASIC Corporation', NULL, ARRAY<VARCHAR(256)>['[','"','Z','E','R','O',' ','A','S','I','C',' ','C','O','R','P','O','R','A','T','I','O','N','"',']'], NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP());


/* ============================================================
 * C. jp_brand 国产/地区数据保全（2356 行，JOIN 派生表填 3 列）
 * ============================================================ */

INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT b.brand_id_std, b.name, b.brand_zh, b.brand_en, b.abbr,
       g.country_region, g.is_domestic, g.domestic_type,
       b.related_words, b.logo, b.state, b.official_website, b.level, b.type, b.source, b.create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand b
JOIN (
  SELECT CAST(9000001 AS BIGINT) AS brand_id_std, CAST('US' AS VARCHAR(8)) AS country_region, CAST(0 AS TINYINT) AS is_domestic, CAST('overseas' AS VARCHAR(20)) AS domestic_type
  UNION ALL SELECT 9000002, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 9000003, 'US', 0, 'overseas'
  UNION ALL SELECT 9000004, 'US', 0, 'overseas'
  UNION ALL SELECT 9000005, 'DE', 0, 'overseas'
  UNION ALL SELECT 9000006, 'JP', 0, 'overseas'
  UNION ALL SELECT 9000007, 'US', 0, 'overseas'
  UNION ALL SELECT 9000008, 'GB', 0, 'overseas'
  UNION ALL SELECT 9000009, 'JP', 0, 'overseas'
  UNION ALL SELECT 9000010, 'US', 0, 'overseas'
  UNION ALL SELECT 9000011, 'US', 0, 'overseas'
  UNION ALL SELECT 9000012, 'US', 0, 'overseas'
  UNION ALL SELECT 9000013, 'US', 0, 'overseas'
  UNION ALL SELECT 9000015, 'US', 0, 'overseas'
  UNION ALL SELECT 9000016, 'SE', 0, 'overseas'
  UNION ALL SELECT 9000101, 'US', 0, 'overseas'
  UNION ALL SELECT 9000102, 'CH', 0, 'overseas'
  UNION ALL SELECT 9000103, 'PL', 0, 'overseas'
  UNION ALL SELECT 9000104, 'CH', 0, 'overseas'
  UNION ALL SELECT 9000105, 'US', 0, 'overseas'
  UNION ALL SELECT 9000106, 'US', 0, 'overseas'
  UNION ALL SELECT 9000107, 'GB', 0, 'overseas'
  UNION ALL SELECT 9000108, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 9000109, 'DE', 0, 'overseas'
  UNION ALL SELECT 9000110, 'JP', 0, 'overseas'
  UNION ALL SELECT 9000111, 'US', 0, 'overseas'
  UNION ALL SELECT 9000112, 'US', 0, 'overseas'
  UNION ALL SELECT 9000113, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 9000115, 'US', 0, 'overseas'
  UNION ALL SELECT 9000116, 'US', 0, 'overseas'
  UNION ALL SELECT 9000117, 'KR', 0, 'overseas'
  UNION ALL SELECT 9000118, 'US', 0, 'overseas'
  UNION ALL SELECT 9000119, 'US', 0, 'overseas'
  UNION ALL SELECT 9000120, 'US', 0, 'overseas'
  UNION ALL SELECT 9000121, 'US', 0, 'overseas'
  UNION ALL SELECT 9000122, 'CA', 0, 'overseas'
  UNION ALL SELECT 9000123, 'IN', 0, 'overseas'
  UNION ALL SELECT 9000124, 'US', 0, 'overseas'
  UNION ALL SELECT 9000125, 'US', 0, 'overseas'
  UNION ALL SELECT 9000126, 'US', 0, 'overseas'
  UNION ALL SELECT 9000127, 'GB', 0, 'overseas'
  UNION ALL SELECT 9000224, 'US', 0, 'overseas'
  UNION ALL SELECT 9000300, 'US', 0, 'overseas'
  UNION ALL SELECT 9000301, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 9000302, 'US', 0, 'overseas'
  UNION ALL SELECT 9000303, 'US', 0, 'overseas'
  UNION ALL SELECT 9000304, 'US', 0, 'overseas'
  UNION ALL SELECT 9000305, 'TW', 1, 'taiwan'
  UNION ALL SELECT 9000306, 'US', 0, 'overseas'
  UNION ALL SELECT 9000307, 'US', 0, 'overseas'
  UNION ALL SELECT 9000308, 'US', 0, 'overseas'
  UNION ALL SELECT 9000309, 'US', 0, 'overseas'
  UNION ALL SELECT 9000310, 'US', 0, 'overseas'
  UNION ALL SELECT 9000311, 'US', 0, 'overseas'
  UNION ALL SELECT 9000312, 'DK', 0, 'overseas'
  UNION ALL SELECT 9000313, 'GB', 0, 'overseas'
  UNION ALL SELECT 9000314, 'TW', 1, 'taiwan'
  UNION ALL SELECT 9000315, 'SG', 0, 'overseas'
  UNION ALL SELECT 9000317, 'US', 0, 'overseas'
  UNION ALL SELECT 9000318, 'JP', 0, 'overseas'
  UNION ALL SELECT 9000319, 'TW', 1, 'taiwan'
  UNION ALL SELECT 9000320, 'US', 0, 'overseas'
  UNION ALL SELECT 9000321, 'US', 0, 'overseas'
  UNION ALL SELECT 9000322, 'CA', 0, 'overseas'
  UNION ALL SELECT 9000323, 'ES', 0, 'overseas'
  UNION ALL SELECT 9000324, 'US', 0, 'overseas'
  UNION ALL SELECT 9000325, 'US', 0, 'overseas'
  UNION ALL SELECT 9000328, 'US', 0, 'overseas'
  UNION ALL SELECT 9000329, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 9000330, 'US', 0, 'overseas'
  UNION ALL SELECT 9000331, 'DE', 0, 'overseas'
  UNION ALL SELECT 9000332, 'US', 0, 'overseas'
  UNION ALL SELECT 9000333, 'US', 0, 'overseas'
  UNION ALL SELECT 9000334, 'US', 0, 'overseas'
  UNION ALL SELECT 9000463, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 9000464, 'GB', 0, 'overseas'
  UNION ALL SELECT 9000500, 'US', 0, 'overseas'
  UNION ALL SELECT 9000501, 'GB', 0, 'overseas'
  UNION ALL SELECT 9000502, 'SE', 0, 'overseas'
  UNION ALL SELECT 9000503, 'GB', 0, 'overseas'
  UNION ALL SELECT 9000504, 'US', 0, 'overseas'
  UNION ALL SELECT 9000505, 'GB', 0, 'overseas'
  UNION ALL SELECT 9000506, 'KR', 0, 'overseas'
  UNION ALL SELECT 9000507, 'KR', 0, 'overseas'
  UNION ALL SELECT 9000508, 'CH', 0, 'overseas'
  UNION ALL SELECT 9000509, 'CA', 0, 'overseas'
  UNION ALL SELECT 9000510, 'US', 0, 'overseas'
  UNION ALL SELECT 9000511, 'US', 0, 'overseas'
  UNION ALL SELECT 9000512, 'DE', 0, 'overseas'
  UNION ALL SELECT 9000513, 'DE', 0, 'overseas'
  UNION ALL SELECT 9000514, 'US', 0, 'overseas'
  UNION ALL SELECT 9000515, 'US', 0, 'overseas'
  UNION ALL SELECT 9000516, 'US', 0, 'overseas'
  UNION ALL SELECT 9000517, 'US', 0, 'overseas'
  UNION ALL SELECT 9000518, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 9000520, 'BG', 0, 'overseas'
  UNION ALL SELECT 9000521, 'US', 0, 'overseas'
  UNION ALL SELECT 9000522, 'CA', 0, 'overseas'
  UNION ALL SELECT 9000523, 'FR', 0, 'overseas'
  UNION ALL SELECT 9000524, 'SE', 0, 'overseas'
  UNION ALL SELECT 9000525, 'SE', 0, 'overseas'
  UNION ALL SELECT 9000526, 'DE', 0, 'overseas'
  UNION ALL SELECT 9000527, 'US', 0, 'overseas'
  UNION ALL SELECT 9000528, 'NZ', 0, 'overseas'
  UNION ALL SELECT 9000529, 'TW', 1, 'taiwan'
  UNION ALL SELECT 9000530, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 9000531, 'TR', 0, 'overseas'
  UNION ALL SELECT 9000532, 'TW', 1, 'taiwan'
  UNION ALL SELECT 9000533, 'US', 0, 'overseas'
  UNION ALL SELECT 9000534, 'US', 0, 'overseas'
  UNION ALL SELECT 9000535, 'DE', 0, 'overseas'
  UNION ALL SELECT 9000538, 'BE', 0, 'overseas'
  UNION ALL SELECT 9000539, 'DK', 0, 'overseas'
  UNION ALL SELECT 9000540, 'AT', 0, 'overseas'
  UNION ALL SELECT 9000541, 'US', 0, 'overseas'
  UNION ALL SELECT 9000542, 'TW', 1, 'taiwan'
  UNION ALL SELECT 9000544, 'RS', 0, 'overseas'
  UNION ALL SELECT 9000545, 'GB', 0, 'overseas'
  UNION ALL SELECT 9000546, 'CA', 0, 'overseas'
  UNION ALL SELECT 9000547, 'US', 0, 'overseas'
  UNION ALL SELECT 9000548, 'US', 0, 'overseas'
  UNION ALL SELECT 9000549, 'US', 0, 'overseas'
  UNION ALL SELECT 9000550, 'US', 0, 'overseas'
  UNION ALL SELECT 9000551, 'US', 0, 'overseas'
  UNION ALL SELECT 9000552, 'DE', 0, 'overseas'
  UNION ALL SELECT 9000553, 'GB', 0, 'overseas'
  UNION ALL SELECT 9000554, 'US', 0, 'overseas'
  UNION ALL SELECT 9000555, 'US', 0, 'overseas'
  UNION ALL SELECT 9000556, 'US', 0, 'overseas'
  UNION ALL SELECT 9000603, 'JP', 0, 'overseas'
  UNION ALL SELECT 9000605, 'GB', 0, 'overseas'
  UNION ALL SELECT 9001065, 'DE', 0, 'overseas'
  UNION ALL SELECT 9001067, 'GB', 0, 'overseas'
  UNION ALL SELECT 9001071, 'TW', 1, 'taiwan'
  UNION ALL SELECT 9001072, 'US', 0, 'overseas'
  UNION ALL SELECT 9001076, 'TW', 1, 'taiwan'
  UNION ALL SELECT 9001077, 'US', 0, 'overseas'
  UNION ALL SELECT 9001078, 'US', 0, 'overseas'
  UNION ALL SELECT 9001137, 'US', 0, 'overseas'
  UNION ALL SELECT 9001138, 'US', 0, 'overseas'
  UNION ALL SELECT 9001139, 'US', 0, 'overseas'
  UNION ALL SELECT 9001140, 'DE', 0, 'overseas'
  UNION ALL SELECT 9001141, 'US', 0, 'overseas'
  UNION ALL SELECT 9001142, 'US', 0, 'overseas'
  UNION ALL SELECT 9001143, 'US', 0, 'overseas'
  UNION ALL SELECT 9001144, 'DE', 0, 'overseas'
  UNION ALL SELECT 9001145, 'DE', 0, 'overseas'
  UNION ALL SELECT 9001146, 'US', 0, 'overseas'
  UNION ALL SELECT 9001147, 'US', 0, 'overseas'
  UNION ALL SELECT 9001148, 'TW', 1, 'taiwan'
  UNION ALL SELECT 9001150, 'TW', 1, 'taiwan'
  UNION ALL SELECT 9001151, 'US', 0, 'overseas'
  UNION ALL SELECT 9001152, 'US', 0, 'overseas'
  UNION ALL SELECT 9001153, 'US', 0, 'overseas'
  UNION ALL SELECT 9001154, 'US', 0, 'overseas'
  UNION ALL SELECT 9001155, 'US', 0, 'overseas'
  UNION ALL SELECT 9001156, 'US', 0, 'overseas'
  UNION ALL SELECT 9001157, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 9001158, 'US', 0, 'overseas'
  UNION ALL SELECT 9001159, 'US', 0, 'overseas'
  UNION ALL SELECT 9001160, 'US', 0, 'overseas'
  UNION ALL SELECT 9001161, 'CA', 0, 'overseas'
  UNION ALL SELECT 9001162, 'TW', 1, 'taiwan'
  UNION ALL SELECT 9001163, 'DE', 0, 'overseas'
  UNION ALL SELECT 9001164, 'TW', 1, 'taiwan'
  UNION ALL SELECT 9001165, 'US', 0, 'overseas'
  UNION ALL SELECT 9001166, 'JP', 0, 'overseas'
  UNION ALL SELECT 9001167, 'DE', 0, 'overseas'
  UNION ALL SELECT 9001168, 'DE', 0, 'overseas'
  UNION ALL SELECT 9001169, 'IN', 0, 'overseas'
  UNION ALL SELECT 9001170, 'TW', 1, 'taiwan'
  UNION ALL SELECT 9001171, 'US', 0, 'overseas'
  UNION ALL SELECT 9001172, 'US', 0, 'overseas'
  UNION ALL SELECT 9001173, 'TW', 1, 'taiwan'
  UNION ALL SELECT 9001174, 'DE', 0, 'overseas'
  UNION ALL SELECT 9001176, 'DE', 0, 'overseas'
  UNION ALL SELECT 9001177, 'GB', 0, 'overseas'
  UNION ALL SELECT 9001178, 'DE', 0, 'overseas'
  UNION ALL SELECT 9001179, 'US', 0, 'overseas'
  UNION ALL SELECT 9001180, 'DE', 0, 'overseas'
  UNION ALL SELECT 9001181, 'SE', 0, 'overseas'
  UNION ALL SELECT 9001182, 'GB', 0, 'overseas'
  UNION ALL SELECT 9001183, 'DE', 0, 'overseas'
  UNION ALL SELECT 9001187, 'US', 0, 'overseas'
  UNION ALL SELECT 9001188, 'IT', 0, 'overseas'
  UNION ALL SELECT 9001190, 'US', 0, 'overseas'
  UNION ALL SELECT 9001191, 'US', 0, 'overseas'
  UNION ALL SELECT 9001192, 'DE', 0, 'overseas'
  UNION ALL SELECT 9001194, 'JP', 0, 'overseas'
  UNION ALL SELECT 9001195, 'CA', 0, 'overseas'
  UNION ALL SELECT 9001196, 'US', 0, 'overseas'
  UNION ALL SELECT 9001197, 'US', 0, 'overseas'
  UNION ALL SELECT 9001200, 'TW', 1, 'taiwan'
  UNION ALL SELECT 9001202, 'US', 0, 'overseas'
  UNION ALL SELECT 9001203, 'FR', 0, 'overseas'
  UNION ALL SELECT 9001205, 'US', 0, 'overseas'
  UNION ALL SELECT 9001206, 'US', 0, 'overseas'
  UNION ALL SELECT 9001207, 'KR', 0, 'overseas'
  UNION ALL SELECT 9001208, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 9001209, 'US', 0, 'overseas'
  UNION ALL SELECT 9001210, 'DE', 0, 'overseas'
  UNION ALL SELECT 9001211, 'US', 0, 'overseas'
  UNION ALL SELECT 9001212, 'FI', 0, 'overseas'
  UNION ALL SELECT 9001213, 'FR', 0, 'overseas'
  UNION ALL SELECT 9001216, 'CA', 0, 'overseas'
  UNION ALL SELECT 9001217, 'GB', 0, 'overseas'
  UNION ALL SELECT 9001218, 'US', 0, 'overseas'
  UNION ALL SELECT 9001219, 'US', 0, 'overseas'
  UNION ALL SELECT 9001220, 'US', 0, 'overseas'
  UNION ALL SELECT 9001221, 'KR', 0, 'overseas'
  UNION ALL SELECT 9001222, 'US', 0, 'overseas'
  UNION ALL SELECT 9001223, 'US', 0, 'overseas'
  UNION ALL SELECT 9001224, 'US', 0, 'overseas'
  UNION ALL SELECT 9001225, 'US', 0, 'overseas'
  UNION ALL SELECT 9001226, 'US', 0, 'overseas'
  UNION ALL SELECT 9001227, 'JP', 0, 'overseas'
  UNION ALL SELECT 9001228, 'US', 0, 'overseas'
  UNION ALL SELECT 9001229, 'CA', 0, 'overseas'
  UNION ALL SELECT 9001230, 'US', 0, 'overseas'
  UNION ALL SELECT 9001232, 'US', 0, 'overseas'
  UNION ALL SELECT 9001234, 'US', 0, 'overseas'
  UNION ALL SELECT 9001235, 'IT', 0, 'overseas'
  UNION ALL SELECT 9001236, 'MY', 0, 'overseas'
  UNION ALL SELECT 9001237, 'FR', 0, 'overseas'
  UNION ALL SELECT 9001240, 'US', 0, 'overseas'
  UNION ALL SELECT 9001241, 'US', 0, 'overseas'
  UNION ALL SELECT 9001242, 'US', 0, 'overseas'
  UNION ALL SELECT 9001243, 'US', 0, 'overseas'
  UNION ALL SELECT 9001244, 'GB', 0, 'overseas'
  UNION ALL SELECT 9001245, 'TW', 1, 'taiwan'
  UNION ALL SELECT 9001246, 'US', 0, 'overseas'
  UNION ALL SELECT 9001247, 'GB', 0, 'overseas'
  UNION ALL SELECT 9001248, 'DE', 0, 'overseas'
  UNION ALL SELECT 9001249, 'US', 0, 'overseas'
  UNION ALL SELECT 9001250, 'US', 0, 'overseas'
  UNION ALL SELECT 9001251, 'CA', 0, 'overseas'
  UNION ALL SELECT 9001252, 'CH', 0, 'overseas'
  UNION ALL SELECT 9001254, 'US', 0, 'overseas'
  UNION ALL SELECT 9001255, 'US', 0, 'overseas'
  UNION ALL SELECT 9001256, 'US', 0, 'overseas'
  UNION ALL SELECT 9001257, 'JP', 0, 'overseas'
  UNION ALL SELECT 9001258, 'FR', 0, 'overseas'
  UNION ALL SELECT 9001261, 'DE', 0, 'overseas'
  UNION ALL SELECT 9001262, 'GB', 0, 'overseas'
  UNION ALL SELECT 9001263, 'US', 0, 'overseas'
  UNION ALL SELECT 9001264, 'US', 0, 'overseas'
  UNION ALL SELECT 900152805, 'JP', 0, 'overseas'
  UNION ALL SELECT 1443490691031076865, 'JP', 0, 'overseas'
  UNION ALL SELECT 1443490691043659778, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490691043659779, 'JP', 0, 'overseas'
  UNION ALL SELECT 1443490691043659780, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490691043659781, 'KR', 0, 'overseas'
  UNION ALL SELECT 1443490691043659782, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490691043659783, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490691106574338, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490691106574339, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490691106574340, 'JP', 0, 'overseas'
  UNION ALL SELECT 1443490691106574341, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490691106574342, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490691106574343, 'JP', 0, 'overseas'
  UNION ALL SELECT 1443490691173683201, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490691173683202, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490691173683203, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490691173683204, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490691173683205, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490691173683206, 'JP', 0, 'overseas'
  UNION ALL SELECT 1443490691173683207, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490691236597762, 'HK', 1, 'hk_mo'
  UNION ALL SELECT 1443490691236597763, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490691236597764, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490691236597765, 'JP', 0, 'overseas'
  UNION ALL SELECT 1443490691236597766, 'DE', 0, 'overseas'
  UNION ALL SELECT 1443490691236597767, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490691236597768, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490691236597769, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490691299512321, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490691299512322, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490691299512323, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490691299512324, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490691299512325, 'JP', 0, 'overseas'
  UNION ALL SELECT 1443490691299512326, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490691299512327, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490691362426881, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490691362426882, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490691362426883, 'JP', 0, 'overseas'
  UNION ALL SELECT 1443490691362426884, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490691362426885, 'KR', 0, 'overseas'
  UNION ALL SELECT 1443490691362426886, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490691362426887, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490691362426888, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490691429535746, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490691429535747, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490691429535748, 'JP', 0, 'overseas'
  UNION ALL SELECT 1443490691429535749, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490691429535750, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490691429535751, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490691429535752, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490691429535753, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490691496644610, 'KR', 0, 'overseas'
  UNION ALL SELECT 1443490691496644611, 'KR', 0, 'overseas'
  UNION ALL SELECT 1443490691496644612, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490691496644613, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490691496644614, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490691496644615, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490691496644616, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490691496644617, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490691496644618, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490691563753474, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490691563753475, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490691563753476, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490691563753477, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490691563753478, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490691563753479, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490691563753480, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490691630862337, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490691630862338, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490691630862339, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490691630862340, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490691630862341, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490691630862342, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490691630862343, 'JP', 0, 'overseas'
  UNION ALL SELECT 1443490691630862344, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490691693776897, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490691693776898, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490691693776899, 'JP', 0, 'overseas'
  UNION ALL SELECT 1443490691693776900, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490691693776901, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490691693776902, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490691693776903, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490691693776904, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490691760885761, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490691760885762, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490691760885763, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490691760885764, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490691760885765, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490691760885766, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490691760885767, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490691760885768, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490691819606018, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490691819606019, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490691819606020, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490691819606021, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490691819606022, 'KR', 0, 'overseas'
  UNION ALL SELECT 1443490691819606023, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490691819606024, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490691819606025, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490691886714881, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490691886714882, 'JP', 0, 'overseas'
  UNION ALL SELECT 1443490691886714883, 'JP', 0, 'overseas'
  UNION ALL SELECT 1443490691886714884, 'JP', 0, 'overseas'
  UNION ALL SELECT 1443490691886714885, 'JP', 0, 'overseas'
  UNION ALL SELECT 1443490691886714886, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490691886714887, 'KR', 0, 'overseas'
  UNION ALL SELECT 1443490691886714888, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490691949629442, 'JP', 0, 'overseas'
  UNION ALL SELECT 1443490691949629443, 'JP', 0, 'overseas'
  UNION ALL SELECT 1443490691949629444, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490691949629445, 'DE', 0, 'overseas'
  UNION ALL SELECT 1443490691949629446, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490691949629447, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490691949629448, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490691949629449, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490691949629450, 'JP', 0, 'overseas'
  UNION ALL SELECT 1443490692016738306, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490692016738307, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490692016738308, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490692016738309, 'JP', 0, 'overseas'
  UNION ALL SELECT 1443490692016738310, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490692016738311, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490692016738312, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490692016738313, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490692079652866, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490692079652867, 'KR', 0, 'overseas'
  UNION ALL SELECT 1443490692079652868, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490692079652869, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490692079652870, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490692079652871, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490692079652872, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490692079652873, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490692142567425, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490692142567426, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490692142567427, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490692142567428, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490692142567429, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490692142567430, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490692142567431, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490692142567432, 'DE', 0, 'overseas'
  UNION ALL SELECT 1443490692142567433, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490692209676290, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490692209676291, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490692209676292, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490692209676293, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490692209676294, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490692209676295, 'JP', 0, 'overseas'
  UNION ALL SELECT 1443490692209676296, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490692209676297, 'KR', 0, 'overseas'
  UNION ALL SELECT 1443490692209676298, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490692276785153, 'ES', 0, 'overseas'
  UNION ALL SELECT 1443490692276785154, 'GB', 0, 'overseas'
  UNION ALL SELECT 1443490692276785155, 'SG', 0, 'overseas'
  UNION ALL SELECT 1443490692276785156, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490692276785157, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490692276785158, 'CA', 0, 'overseas'
  UNION ALL SELECT 1443490692276785159, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490692276785160, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490692343894017, 'JP', 0, 'overseas'
  UNION ALL SELECT 1443490692343894018, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490692343894019, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490692343894020, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490692343894021, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490692343894022, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490692343894023, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490692343894024, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490692411002881, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490692411002882, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490692411002883, 'JP', 0, 'overseas'
  UNION ALL SELECT 1443490692411002884, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490692411002885, 'DE', 0, 'overseas'
  UNION ALL SELECT 1443490692411002886, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490692411002887, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490692411002888, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490692473917441, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490692473917442, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490692473917443, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490692473917444, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490692473917445, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490692473917446, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490692473917447, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490692473917448, 'GB', 0, 'overseas'
  UNION ALL SELECT 1443490692536832002, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490692536832003, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490692536832004, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490692536832005, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490692536832006, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490692536832007, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490692536832008, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490692536832009, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490692536832010, 'JP', 0, 'overseas'
  UNION ALL SELECT 1443490692603940866, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490692603940867, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490692603940868, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490692603940869, 'JP', 0, 'overseas'
  UNION ALL SELECT 1443490692603940870, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490692603940871, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490692603940872, 'JP', 0, 'overseas'
  UNION ALL SELECT 1443490692603940873, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490692603940874, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490692603940875, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490692666855425, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490692666855426, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490692666855427, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490692666855428, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490692666855429, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490692666855430, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490692666855431, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490692666855432, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490692666855433, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490692733964290, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490692733964291, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490692733964292, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490692733964293, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490692733964294, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490692733964295, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490692733964296, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490692733964297, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490692733964298, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490692733964299, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490692796878849, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490692796878850, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490692796878851, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490692796878852, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490692796878853, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490692796878854, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490692796878855, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490692796878856, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490692796878857, 'DE', 0, 'overseas'
  UNION ALL SELECT 1443490692796878858, 'KR', 0, 'overseas'
  UNION ALL SELECT 1443490692859793410, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490692859793411, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490692859793412, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490692859793413, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490692859793414, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490692859793415, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490692859793416, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490692859793417, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490692859793418, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490692859793419, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490692922707969, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490692922707970, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490692922707971, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490692922707972, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490692922707973, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490692922707974, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490692922707975, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490692922707976, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490692922707977, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490692989816833, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490692989816834, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490692989816835, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490692989816836, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490692989816837, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490692989816838, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490692989816839, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490692989816840, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490692989816841, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490692989816842, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490693056925697, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490693056925698, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490693056925699, 'DE', 0, 'overseas'
  UNION ALL SELECT 1443490693056925700, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490693056925701, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490693056925702, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490693056925703, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490693056925704, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490693056925705, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490693056925706, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490693056925707, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490693119840258, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490693119840259, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490693119840260, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490693119840262, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490693119840263, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490693119840264, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490693119840265, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490693119840266, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490693119840267, 'NL', 1, 'mainland_acquired'
  UNION ALL SELECT 1443490693186949121, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490693186949122, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490693186949123, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490693186949124, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490693186949125, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490693186949126, 'JP', 0, 'overseas'
  UNION ALL SELECT 1443490693186949127, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490693186949128, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490693186949129, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490693249863682, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490693249863683, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490693249863684, 'JP', 0, 'overseas'
  UNION ALL SELECT 1443490693249863685, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490693249863686, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490693249863688, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490693249863689, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490693316972545, 'JP', 0, 'overseas'
  UNION ALL SELECT 1443490693316972546, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490693316972547, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490693316972550, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490693316972551, 'JP', 0, 'overseas'
  UNION ALL SELECT 1443490693316972552, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490693316972553, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490693379887106, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490693379887107, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490693379887108, 'DE', 0, 'overseas'
  UNION ALL SELECT 1443490693379887109, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490693379887110, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490693379887111, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490693379887112, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490693379887113, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490693379887114, 'CH', 0, 'overseas'
  UNION ALL SELECT 1443490693442801666, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490693442801667, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490693442801668, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490693442801669, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490693442801670, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490693442801671, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490693442801672, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490693442801673, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490693442801674, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490693442801675, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490693509910530, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490693509910531, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490693509910532, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490693509910533, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490693509910534, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490693509910535, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490693509910536, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490693509910537, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490693577019393, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490693577019394, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490693577019396, 'TH', 0, 'overseas'
  UNION ALL SELECT 1443490693577019397, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490693577019398, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490693577019399, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490693577019400, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490693577019401, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490693639933954, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490693639933955, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490693639933956, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490693639933957, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490693639933958, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490693639933959, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490693639933960, 'JP', 0, 'overseas'
  UNION ALL SELECT 1443490693639933961, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490693639933962, 'KR', 0, 'overseas'
  UNION ALL SELECT 1443490693639933963, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490693702848513, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490693702848516, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490693702848517, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490693702848518, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490693702848520, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490693702848521, 'KR', 0, 'overseas'
  UNION ALL SELECT 1443490693702848522, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490693769957378, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490693769957379, 'JP', 0, 'overseas'
  UNION ALL SELECT 1443490693769957380, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490693769957381, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490693769957382, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490693769957384, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490693769957385, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490693769957386, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490693837066243, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490693837066244, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490693837066245, 'JP', 0, 'overseas'
  UNION ALL SELECT 1443490693837066246, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490693837066247, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490693837066248, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490693899980803, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490693899980804, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490693899980805, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490693899980806, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490693899980807, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490693899980809, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490693967089665, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490693967089666, 'JP', 0, 'overseas'
  UNION ALL SELECT 1443490693967089667, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490693967089670, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490693967089672, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490693967089673, 'JP', 0, 'overseas'
  UNION ALL SELECT 1443490694034198529, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490694034198530, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490694034198531, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490694034198533, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490694034198534, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490694034198535, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490694034198536, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490694034198537, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490694101307394, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490694101307395, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490694101307396, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490694101307397, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490694101307398, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490694101307399, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490694101307400, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490694101307401, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490694101307402, 'DE', 0, 'overseas'
  UNION ALL SELECT 1443490694101307403, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490694168416258, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490694168416259, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490694168416260, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490694168416261, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490694168416262, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490694168416263, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490694168416264, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490694168416265, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490694168416266, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490694168416267, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490694235525122, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490694235525123, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490694235525124, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490694235525125, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490694235525126, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490694235525127, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490694235525128, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490694235525129, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490694235525130, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490694298439682, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490694298439683, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490694298439684, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490694298439685, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490694298439686, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490694298439687, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490694298439688, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490694298439689, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490694298439690, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490694369742850, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490694369742851, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490694369742852, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490694369742853, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490694369742854, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490694369742855, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490694369742856, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490694369742857, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490694369742858, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490694369742859, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490694432657409, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490694432657410, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490694432657411, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490694432657412, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490694432657413, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490694432657414, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490694432657415, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490694432657416, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490694432657417, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490694432657418, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490694499766274, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490694499766275, 'KR', 0, 'overseas'
  UNION ALL SELECT 1443490694499766276, 'JP', 0, 'overseas'
  UNION ALL SELECT 1443490694499766277, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490694499766278, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490694499766279, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490694499766280, 'JP', 0, 'overseas'
  UNION ALL SELECT 1443490694499766281, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490694499766282, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490694499766283, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490694499766284, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490694566875138, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490694566875141, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490694566875142, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490694566875143, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490694566875144, 'KR', 0, 'overseas'
  UNION ALL SELECT 1443490694566875145, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490694566875146, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490694566875147, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490694629789697, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490694629789698, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490694629789699, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490694629789700, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490694629789701, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490694629789702, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490694629789703, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490694692704258, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490694692704259, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490694692704260, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490694692704261, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490694692704262, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490694692704263, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490694692704264, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490694759813122, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490694759813123, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490694759813124, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490694759813125, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490694759813126, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490694759813127, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490694759813128, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490694759813129, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490694759813130, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490694822727681, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490694822727682, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490694822727683, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490694822727684, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490694822727685, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490694822727686, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490694822727687, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490694822727688, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490694822727689, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490694885642241, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490694885642242, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490694885642243, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490694885642244, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490694885642245, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490694885642246, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490694885642247, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490694885642248, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490694885642249, 'FR', 0, 'overseas'
  UNION ALL SELECT 1443490694885642250, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490694952751105, 'CH', 0, 'overseas'
  UNION ALL SELECT 1443490694952751106, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490694952751107, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490694952751108, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490694952751109, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490694952751110, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490694952751111, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490694952751112, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490694952751113, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490695015665666, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490695015665667, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490695015665668, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490695015665669, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490695015665670, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490695015665671, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490695015665672, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490695015665673, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490695015665674, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490695015665675, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490695082774529, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490695082774530, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490695082774531, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490695082774532, 'JP', 0, 'overseas'
  UNION ALL SELECT 1443490695082774533, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490695082774534, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490695082774535, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490695082774536, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490695082774537, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490695082774538, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490695082774539, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490695149883393, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490695149883394, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490695149883395, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490695149883396, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490695149883397, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490695149883398, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490695149883399, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490695149883400, 'KR', 0, 'overseas'
  UNION ALL SELECT 1443490695149883401, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490695212797954, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490695212797955, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490695212797956, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490695212797957, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490695212797958, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490695212797959, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490695212797960, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490695212797961, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490695212797962, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490695212797963, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490695275712513, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490695275712514, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490695275712515, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490695275712516, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490695275712517, 'CH', 0, 'overseas'
  UNION ALL SELECT 1443490695275712518, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490695275712519, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490695342821378, 'JP', 0, 'overseas'
  UNION ALL SELECT 1443490695342821379, 'JP', 0, 'overseas'
  UNION ALL SELECT 1443490695342821380, 'NL', 0, 'overseas'
  UNION ALL SELECT 1443490695342821381, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490695342821383, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490695342821385, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490695342821386, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490695342821387, 'GB', 0, 'overseas'
  UNION ALL SELECT 1443490695409930242, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490695409930244, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490695409930246, 'GB', 0, 'overseas'
  UNION ALL SELECT 1443490695409930248, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490695472844801, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490695472844802, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490695472844803, 'BE', 0, 'overseas'
  UNION ALL SELECT 1443490695472844804, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490695472844807, 'NO', 0, 'overseas'
  UNION ALL SELECT 1443490695472844808, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490695472844809, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490695535759362, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490695535759363, 'KR', 0, 'overseas'
  UNION ALL SELECT 1443490695535759364, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490695535759365, 'GB', 0, 'overseas'
  UNION ALL SELECT 1443490695535759366, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490695535759367, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490695535759368, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490695535759369, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490695598673922, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490695598673923, 'KR', 0, 'overseas'
  UNION ALL SELECT 1443490695598673924, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490695598673926, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490695598673928, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490695665782785, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490695665782786, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490695665782787, 'KR', 0, 'overseas'
  UNION ALL SELECT 1443490695665782788, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490695665782789, 'JP', 0, 'overseas'
  UNION ALL SELECT 1443490695665782790, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490695665782791, 'JP', 0, 'overseas'
  UNION ALL SELECT 1443490695665782792, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490695665782793, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490695728697345, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490695728697346, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490695728697347, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490695728697348, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490695728697349, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490695728697350, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490695728697351, 'KR', 0, 'overseas'
  UNION ALL SELECT 1443490695728697352, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490695728697353, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490695728697354, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490695795806209, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490695795806210, 'AT', 0, 'overseas'
  UNION ALL SELECT 1443490695795806211, 'JP', 0, 'overseas'
  UNION ALL SELECT 1443490695795806212, 'JP', 0, 'overseas'
  UNION ALL SELECT 1443490695795806213, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490695795806214, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490695795806215, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490695795806216, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490695795806217, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490695795806218, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490695858720769, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490695858720770, 'ZA', 0, 'overseas'
  UNION ALL SELECT 1443490695858720771, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490695858720772, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490695858720773, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490695858720774, 'US', 1, 'mainland_acquired'
  UNION ALL SELECT 1443490695858720775, 'US', 1, 'mainland_acquired'
  UNION ALL SELECT 1443490695858720776, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490695858720777, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490695925829634, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490695925829635, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490695925829636, 'JP', 0, 'overseas'
  UNION ALL SELECT 1443490695925829637, 'HK', 1, 'hk_mo'
  UNION ALL SELECT 1443490695925829638, 'JP', 0, 'overseas'
  UNION ALL SELECT 1443490695925829639, 'DE', 0, 'overseas'
  UNION ALL SELECT 1443490695925829640, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490695925829641, 'DE', 0, 'overseas'
  UNION ALL SELECT 1443490695925829642, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490695925829643, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490695988744193, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490695988744194, 'JP', 0, 'overseas'
  UNION ALL SELECT 1443490695988744195, 'JP', 0, 'overseas'
  UNION ALL SELECT 1443490695988744196, 'KR', 0, 'overseas'
  UNION ALL SELECT 1443490695988744197, 'JP', 0, 'overseas'
  UNION ALL SELECT 1443490695988744198, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490695988744199, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490695988744201, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490695988744202, 'IE', 0, 'overseas'
  UNION ALL SELECT 1443490696055853057, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490696055853058, 'FR', 0, 'overseas'
  UNION ALL SELECT 1443490696055853059, 'FR', 0, 'overseas'
  UNION ALL SELECT 1443490696055853060, 'KR', 0, 'overseas'
  UNION ALL SELECT 1443490696055853061, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490696055853062, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490696055853063, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490696055853064, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490696055853065, 'JP', 0, 'overseas'
  UNION ALL SELECT 1443490696055853066, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490696118767617, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490696118767618, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490696118767620, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490696118767621, 'HK', 1, 'hk_mo'
  UNION ALL SELECT 1443490696118767622, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490696185876481, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490696185876482, 'KR', 0, 'overseas'
  UNION ALL SELECT 1443490696185876483, 'DE', 0, 'overseas'
  UNION ALL SELECT 1443490696185876484, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490696185876485, 'DE', 0, 'overseas'
  UNION ALL SELECT 1443490696185876486, 'DE', 0, 'overseas'
  UNION ALL SELECT 1443490696185876487, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490696185876488, 'CH', 0, 'overseas'
  UNION ALL SELECT 1443490696185876489, 'RU', 0, 'overseas'
  UNION ALL SELECT 1443490696185876490, 'US', 1, 'mainland_acquired'
  UNION ALL SELECT 1443490696252985346, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490696252985347, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490696252985348, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490696252985349, 'CA', 0, 'overseas'
  UNION ALL SELECT 1443490696252985350, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490696252985351, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490696252985352, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490696252985353, 'KR', 0, 'overseas'
  UNION ALL SELECT 1443490696252985354, 'DE', 0, 'overseas'
  UNION ALL SELECT 1443490696320094209, 'KR', 0, 'overseas'
  UNION ALL SELECT 1443490696320094210, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490696320094211, 'JP', 0, 'overseas'
  UNION ALL SELECT 1443490696320094212, 'KR', 0, 'overseas'
  UNION ALL SELECT 1443490696320094213, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490696320094214, 'JP', 0, 'overseas'
  UNION ALL SELECT 1443490696320094215, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490696320094216, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490696320094217, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490696320094218, 'CA', 0, 'overseas'
  UNION ALL SELECT 1443490696320094219, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490696387203074, 'GB', 0, 'overseas'
  UNION ALL SELECT 1443490696387203075, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490696387203076, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490696387203077, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490696387203079, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490696387203080, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490696387203081, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490696387203082, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490696450117634, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490696450117635, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490696450117636, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490696450117637, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490696450117638, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490696450117639, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490696450117640, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490696450117641, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490696450117642, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490696517226498, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490696517226499, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490696517226500, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490696517226502, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490696517226503, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490696517226504, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490696580141058, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490696580141059, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490696580141060, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490696580141063, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490696580141064, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490696580141065, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490696580141066, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490696580141067, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490696647249921, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490696647249922, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490696647249923, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490696647249924, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490696647249925, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490696647249926, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490696647249927, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490696647249928, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490696647249929, 'JP', 0, 'overseas'
  UNION ALL SELECT 1443490696710164481, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490696710164483, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490696710164484, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490696710164485, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490696710164486, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490696710164487, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490696710164488, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490696710164489, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490696710164490, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490696773079042, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490696773079043, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490696773079044, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490696773079045, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490696773079046, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490696773079047, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490696773079048, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490696773079050, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490696773079051, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490696840187905, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490696840187906, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490696840187907, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490696840187908, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490696840187909, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490696840187910, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490696840187911, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490696840187912, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490696840187913, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490696840187914, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490696907296769, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490696907296770, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490696907296771, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490696907296772, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490696907296773, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490696907296774, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490696907296775, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490696907296776, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490696907296777, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490696974405634, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490696974405635, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490696974405636, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490696974405637, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490696974405638, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490696974405639, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490696974405640, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697037320194, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697037320195, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697037320196, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697037320197, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697037320199, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697037320200, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697037320201, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697037320202, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490697037320203, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697037320204, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697104429058, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697104429059, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490697104429060, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697104429061, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490697104429062, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697104429063, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490697104429064, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697104429065, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697104429066, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490697104429067, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697104429068, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697171537921, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697171537922, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697171537923, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697171537924, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697171537925, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697171537926, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697171537927, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697171537928, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697171537929, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490697171537930, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697171537931, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697238646785, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697238646786, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697238646787, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697238646788, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697238646789, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697238646790, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697238646791, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697238646792, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697238646793, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697238646794, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697238646795, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697305755650, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697305755651, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697305755652, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490697305755653, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490697305755654, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490697305755655, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697305755656, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697305755657, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697305755658, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697305755659, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697368670209, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490697368670210, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697368670211, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697368670212, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697368670213, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697368670214, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697368670215, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697368670216, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697368670217, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697368670218, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697368670219, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697435779074, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697435779075, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697435779076, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697435779077, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697435779078, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697435779079, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697435779080, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697435779081, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697435779082, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697435779083, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697435779084, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697502887937, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697502887938, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697502887939, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697502887940, 'HK', 1, 'hk_mo'
  UNION ALL SELECT 1443490697502887941, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697502887942, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697502887943, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697502887944, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697502887945, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697502887946, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697565802497, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697565802498, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697565802499, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490697565802500, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697565802501, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697565802502, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697565802503, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697565802504, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697565802505, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697565802506, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697565802507, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697628717058, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697628717059, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697628717060, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697628717061, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697628717062, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697628717063, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697628717064, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697628717065, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697628717066, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697628717067, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490697691631617, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697691631618, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697691631619, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697691631620, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697691631621, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490697691631622, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697691631623, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697691631624, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697691631625, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490697691631626, 'GB', 0, 'overseas'
  UNION ALL SELECT 1443490697758740482, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490697758740483, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697758740484, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697758740485, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697758740486, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697758740487, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490697758740488, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490697758740489, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697758740490, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697758740491, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697821655041, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490697821655042, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490697821655043, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697821655044, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490697821655045, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490697821655046, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697821655047, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697821655048, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697821655049, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697821655050, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697888763906, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490697888763907, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697888763908, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697888763909, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697888763910, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697888763911, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697888763912, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697888763913, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697888763914, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697888763915, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697951678465, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697951678466, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697951678467, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490697951678468, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697951678469, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697951678470, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697951678471, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490697951678472, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490697951678473, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490697951678474, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698014593025, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698014593026, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698014593027, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698014593028, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698014593029, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698014593030, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698014593031, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698014593032, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490698014593033, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698081701889, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698081701890, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698081701891, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490698081701892, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698081701893, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490698081701894, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490698081701895, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698081701896, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698081701897, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698081701898, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698081701899, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698148810754, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698148810755, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698148810756, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698148810757, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698148810758, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698148810759, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490698148810760, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698148810761, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698148810762, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698215919618, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698215919619, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698215919620, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698215919621, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698215919622, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698215919623, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698215919624, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490698215919625, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698215919626, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698215919627, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698283028482, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698283028483, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698283028484, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698283028485, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698283028486, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698283028487, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698283028488, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698283028489, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698283028490, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490698283028491, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698283028492, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698350137346, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490698350137347, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698350137348, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698350137349, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698350137350, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698350137351, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698350137352, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698350137353, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698417246209, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698417246210, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698417246211, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698417246212, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490698417246213, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698417246214, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490698417246215, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698417246216, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698417246217, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698484355074, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490698484355075, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698484355076, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698484355077, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490698484355078, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698484355079, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698484355080, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698547269633, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698547269634, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698547269635, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698547269636, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698547269637, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698547269638, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698547269639, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698547269640, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698547269641, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698547269642, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698610184194, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698610184195, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698610184196, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698610184197, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698610184198, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698610184199, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698610184200, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698610184201, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698610184202, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698610184203, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490698677293057, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490698677293058, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698677293059, 'JP', 0, 'overseas'
  UNION ALL SELECT 1443490698677293060, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698677293061, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698677293062, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698677293063, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698677293064, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490698677293065, 'JP', 0, 'overseas'
  UNION ALL SELECT 1443490698677293066, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698740207618, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490698740207619, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698740207620, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698740207621, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698740207622, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698740207623, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698740207624, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698740207625, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698740207626, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698740207627, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490698803122177, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698803122178, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698803122179, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698803122180, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698803122181, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698803122182, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698803122183, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698803122184, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490698803122185, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698803122186, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698803122187, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490698870231041, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698870231042, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698870231043, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698870231044, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490698870231045, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490698870231046, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698870231047, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698870231048, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698870231049, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698870231050, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698937339906, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698937339907, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698937339908, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698937339909, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698937339910, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698937339911, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698937339912, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698937339913, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490698937339914, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490699000254465, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490699000254466, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490699000254467, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490699000254468, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490699000254469, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490699000254470, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490699000254471, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490699000254472, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490699000254473, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490699000254474, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490699067363330, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490699067363331, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490699067363332, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490699067363333, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490699067363334, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490699067363335, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490699067363336, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490699067363337, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490699067363338, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490699130277890, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490699130277891, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490699130277892, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490699130277893, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490699130277894, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490699130277895, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490699130277896, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490699130277897, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490699130277898, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490699130277899, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490699193192450, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490699193192451, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490699193192452, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490699193192453, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490699193192454, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490699193192455, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490699193192456, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490699260301314, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490699260301315, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490699260301316, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490699260301317, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490699260301318, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490699260301319, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490699260301320, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490699260301321, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490699323215873, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490699323215874, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490699323215875, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490699323215876, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490699323215877, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490699323215878, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490699323215879, 'JP', 0, 'overseas'
  UNION ALL SELECT 1443490699386130433, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490699386130434, 'JP', 0, 'overseas'
  UNION ALL SELECT 1443490699386130435, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490699386130437, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490699386130438, 'JP', 0, 'overseas'
  UNION ALL SELECT 1443490699386130439, 'JP', 0, 'overseas'
  UNION ALL SELECT 1443490699386130440, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490699386130441, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490699386130442, 'DE', 0, 'overseas'
  UNION ALL SELECT 1443490699386130443, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490699453239297, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490699453239298, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490699453239299, 'JP', 0, 'overseas'
  UNION ALL SELECT 1443490699453239300, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490699453239301, 'CH', 0, 'overseas'
  UNION ALL SELECT 1443490699453239302, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490699453239303, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490699453239304, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490699453239306, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490699520348161, 'CH', 0, 'overseas'
  UNION ALL SELECT 1443490699520348162, 'DE', 0, 'overseas'
  UNION ALL SELECT 1443490699520348163, 'JP', 0, 'overseas'
  UNION ALL SELECT 1443490699520348164, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490699520348165, 'DE', 0, 'overseas'
  UNION ALL SELECT 1443490699520348166, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490699520348167, 'JP', 0, 'overseas'
  UNION ALL SELECT 1443490699520348168, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490699520348169, 'JP', 0, 'overseas'
  UNION ALL SELECT 1443490699583262722, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490699583262723, 'DE', 0, 'overseas'
  UNION ALL SELECT 1443490699583262724, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490699583262725, 'JP', 0, 'overseas'
  UNION ALL SELECT 1443490699583262726, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490699583262727, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490699583262728, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490699583262729, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490699583262730, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490699646177282, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490699646177283, 'JP', 0, 'overseas'
  UNION ALL SELECT 1443490699646177284, 'GB', 0, 'overseas'
  UNION ALL SELECT 1443490699646177285, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490699646177286, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490699646177287, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490699646177288, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490699646177289, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490699646177290, 'JP', 0, 'overseas'
  UNION ALL SELECT 1443490699646177291, 'KR', 0, 'overseas'
  UNION ALL SELECT 1443490699709091841, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490699709091842, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490699709091843, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490699709091844, 'JP', 0, 'overseas'
  UNION ALL SELECT 1443490699709091845, 'JP', 0, 'overseas'
  UNION ALL SELECT 1443490699709091846, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490699709091847, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490699709091848, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490699709091849, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490699709091850, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490699776200706, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490699776200707, 'JP', 0, 'overseas'
  UNION ALL SELECT 1443490699776200708, 'KR', 0, 'overseas'
  UNION ALL SELECT 1443490699776200709, 'KR', 0, 'overseas'
  UNION ALL SELECT 1443490699776200710, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490699776200711, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490699776200712, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490699776200713, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490699776200714, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490699776200715, 'KR', 0, 'overseas'
  UNION ALL SELECT 1443490699776200716, 'JP', 0, 'overseas'
  UNION ALL SELECT 1443490699839115265, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490699839115266, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490699839115267, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490699839115268, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490699839115269, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490699839115271, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490699839115272, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490699839115273, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490699902029826, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490699902029827, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490699902029828, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490699902029829, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490699902029830, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490699902029831, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490699902029832, 'FR', 0, 'overseas'
  UNION ALL SELECT 1443490699902029833, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490699902029834, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490699902029835, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490699964944386, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490699964944387, 'KR', 0, 'overseas'
  UNION ALL SELECT 1443490699964944388, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490699964944389, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490699964944390, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490699964944391, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490699964944392, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490699964944394, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490699964944395, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490700027858946, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490700027858947, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490700027858949, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490700027858950, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490700027858951, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490700027858952, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490700027858953, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490700027858954, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490700027858955, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490700094967809, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490700094967810, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490700094967811, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490700094967812, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490700094967813, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490700094967814, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490700094967815, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490700094967816, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490700094967817, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490700162076674, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490700162076675, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490700162076676, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490700162076677, 'GB', 0, 'overseas'
  UNION ALL SELECT 1443490700162076678, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490700162076679, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490700162076680, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490700162076681, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490700220796930, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490700220796931, 'HK', 1, 'hk_mo'
  UNION ALL SELECT 1443490700220796932, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490700220796933, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490700220796934, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490700220796935, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490700220796936, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490700220796937, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490700220796938, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490700220796939, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490700287905794, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490700287905795, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490700287905796, 'KR', 0, 'overseas'
  UNION ALL SELECT 1443490700287905797, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490700287905798, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490700287905799, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490700287905800, 'KR', 0, 'overseas'
  UNION ALL SELECT 1443490700287905801, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490700287905802, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490700287905803, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490700350820353, 'DE', 0, 'overseas'
  UNION ALL SELECT 1443490700350820354, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490700350820355, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490700350820356, 'LI', 0, 'overseas'
  UNION ALL SELECT 1443490700350820357, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490700350820358, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490700350820359, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490700350820360, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490700350820361, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490700350820362, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490700417929217, 'CH', 0, 'overseas'
  UNION ALL SELECT 1443490700417929218, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490700417929219, 'CH', 0, 'overseas'
  UNION ALL SELECT 1443490700417929220, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490700417929221, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490700417929222, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490700417929223, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490700417929224, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490700417929225, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490700417929226, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490700417929227, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490700480843778, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490700480843779, 'DE', 0, 'overseas'
  UNION ALL SELECT 1443490700480843780, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490700480843781, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490700480843782, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490700480843783, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490700480843784, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490700480843785, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490700480843786, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490700480843787, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490700543758337, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490700543758338, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490700543758339, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490700543758340, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490700543758341, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490700543758342, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490700543758343, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490700543758344, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490700543758345, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490700543758346, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490700606672898, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490700606672899, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490700606672900, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490700606672901, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490700606672902, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490700606672903, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490700606672904, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490700606672905, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490700606672906, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490700606672907, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490700673781761, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490700673781762, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490700673781763, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490700673781764, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490700673781765, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490700673781766, 'JP', 0, 'overseas'
  UNION ALL SELECT 1443490700673781767, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490700673781768, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490700736696322, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490700736696323, 'HK', 1, 'hk_mo'
  UNION ALL SELECT 1443490700736696324, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490700736696325, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490700736696326, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490700736696327, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490700736696328, 'GB', 0, 'overseas'
  UNION ALL SELECT 1443490700736696329, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490700736696330, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490700803805186, 'JP', 0, 'overseas'
  UNION ALL SELECT 1443490700803805187, 'JP', 0, 'overseas'
  UNION ALL SELECT 1443490700803805188, 'JP', 0, 'overseas'
  UNION ALL SELECT 1443490700803805189, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490700803805190, 'JP', 0, 'overseas'
  UNION ALL SELECT 1443490700803805191, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490700803805192, 'KR', 0, 'overseas'
  UNION ALL SELECT 1443490700803805193, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490700803805194, 'CH', 0, 'overseas'
  UNION ALL SELECT 1443490700803805195, 'JP', 0, 'overseas'
  UNION ALL SELECT 1443490700870914050, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490700870914051, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490700870914052, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490700870914053, 'JP', 0, 'overseas'
  UNION ALL SELECT 1443490700870914054, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490700870914055, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490700870914056, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490700870914057, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490700870914058, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490700870914059, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490700933828609, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490700933828610, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490700933828611, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1443490700933828612, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490700933828613, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490700933828614, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490700933828615, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490700933828616, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490700933828617, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490700933828618, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490700933828619, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490701000937474, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490701000937475, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490701000937476, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490701000937477, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490701000937478, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490701000937479, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490701000937480, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490701000937481, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490701000937482, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490701000937483, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490701063852034, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490701063852035, 'IT', 0, 'overseas'
  UNION ALL SELECT 1443490701063852036, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490701063852037, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490701063852038, 'US', 0, 'overseas'
  UNION ALL SELECT 1443490701063852039, 'GB', 0, 'overseas'
  UNION ALL SELECT 1443490701063852040, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490701063852041, 'GB', 0, 'overseas'
  UNION ALL SELECT 1443490701063852042, 'DE', 0, 'overseas'
  UNION ALL SELECT 1443490701063852043, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1443490701063852044, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1446684337159118849, 'US', 0, 'overseas'
  UNION ALL SELECT 1447509321808916481, 'US', 0, 'overseas'
  UNION ALL SELECT 1447745418887536641, 'DE', 0, 'overseas'
  UNION ALL SELECT 1447748545531408385, 'CH', 0, 'overseas'
  UNION ALL SELECT 1447755160083058690, 'DE', 0, 'overseas'
  UNION ALL SELECT 1447759188288458754, 'US', 0, 'overseas'
  UNION ALL SELECT 1447777432986566658, 'DE', 0, 'overseas'
  UNION ALL SELECT 1448102447535710210, 'CH', 0, 'overseas'
  UNION ALL SELECT 1448102890353561602, 'US', 0, 'overseas'
  UNION ALL SELECT 1448103679801249794, 'IE', 0, 'overseas'
  UNION ALL SELECT 1448104473720057857, 'US', 0, 'overseas'
  UNION ALL SELECT 1448104925496958978, 'GB', 0, 'overseas'
  UNION ALL SELECT 1448109546693013506, 'CH', 0, 'overseas'
  UNION ALL SELECT 1448110004627087362, 'US', 0, 'overseas'
  UNION ALL SELECT 1448111464626561026, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1448115413278621698, 'US', 0, 'overseas'
  UNION ALL SELECT 1448533642975199233, 'US', 0, 'overseas'
  UNION ALL SELECT 1448533914069778433, 'US', 0, 'overseas'
  UNION ALL SELECT 1448534194945568770, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1448534396255428609, 'US', 0, 'overseas'
  UNION ALL SELECT 1448534630616387585, 'US', 0, 'overseas'
  UNION ALL SELECT 1448535060297625601, 'US', 0, 'overseas'
  UNION ALL SELECT 1448535326401073154, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1448535478889177090, 'US', 0, 'overseas'
  UNION ALL SELECT 1448535624037273601, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1448535855516721154, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1448536108819111937, 'US', 0, 'overseas'
  UNION ALL SELECT 1448536321856118785, 'IT', 0, 'overseas'
  UNION ALL SELECT 1448536615407165441, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1448536790754242561, 'US', 0, 'overseas'
  UNION ALL SELECT 1448536940885172226, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1448537107394830337, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1448537231080640514, 'CH', 0, 'overseas'
  UNION ALL SELECT 1448537461553426433, 'US', 0, 'overseas'
  UNION ALL SELECT 1448537603010539522, 'US', 0, 'overseas'
  UNION ALL SELECT 1448537811693948930, 'US', 0, 'overseas'
  UNION ALL SELECT 1448537993672216578, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1448538214959513602, 'GB', 0, 'overseas'
  UNION ALL SELECT 1448538370090033153, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1448538570493865986, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1448538726735867906, 'GB', 0, 'overseas'
  UNION ALL SELECT 1448538956055248898, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1448539154018025473, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1448539350454026242, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1448539525666881537, 'US', 0, 'overseas'
  UNION ALL SELECT 1448539709889175554, 'US', 0, 'overseas'
  UNION ALL SELECT 1448855351708168193, 'US', 0, 'overseas'
  UNION ALL SELECT 1448856246319677441, 'US', 0, 'overseas'
  UNION ALL SELECT 1448856424388820994, 'US', 0, 'overseas'
  UNION ALL SELECT 1448856661006311426, 'US', 0, 'overseas'
  UNION ALL SELECT 1448856893010059266, 'US', 0, 'overseas'
  UNION ALL SELECT 1448857108605636609, 'JP', 0, 'overseas'
  UNION ALL SELECT 1448857436231102466, 'DE', 0, 'overseas'
  UNION ALL SELECT 1448857648584531970, 'DE', 0, 'overseas'
  UNION ALL SELECT 1448857831422644226, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1448857970866454530, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1448858137766215681, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1448858323011850241, 'US', 0, 'overseas'
  UNION ALL SELECT 1448858602750980098, 'FR', 0, 'overseas'
  UNION ALL SELECT 1448858840257527809, 'US', 0, 'overseas'
  UNION ALL SELECT 1450346469595922434, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1452550943194062850, 'US', 0, 'overseas'
  UNION ALL SELECT 1452551332354162689, 'US', 0, 'overseas'
  UNION ALL SELECT 1452551748122955778, 'US', 0, 'overseas'
  UNION ALL SELECT 1452551896815194114, 'US', 0, 'overseas'
  UNION ALL SELECT 1452552364228370433, 'US', 0, 'overseas'
  UNION ALL SELECT 1452552521317691393, 'US', 0, 'overseas'
  UNION ALL SELECT 1452552859022082049, 'US', 0, 'overseas'
  UNION ALL SELECT 1452553023325515778, 'US', 0, 'overseas'
  UNION ALL SELECT 1452553154607235073, 'DE', 0, 'overseas'
  UNION ALL SELECT 1452553458769829889, 'US', 0, 'overseas'
  UNION ALL SELECT 1452553572838100993, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1452553744003489793, 'US', 0, 'overseas'
  UNION ALL SELECT 1452554504086872065, 'US', 0, 'overseas'
  UNION ALL SELECT 1452554720429035521, 'GB', 0, 'overseas'
  UNION ALL SELECT 1452554881150595073, 'US', 0, 'overseas'
  UNION ALL SELECT 1452555117080211458, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1452555381686226945, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1452557167994146817, 'JP', 0, 'overseas'
  UNION ALL SELECT 1452557325267955714, 'US', 0, 'overseas'
  UNION ALL SELECT 1452557506159943681, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1452559087039221761, 'US', 0, 'overseas'
  UNION ALL SELECT 1452559268736499714, 'FR', 0, 'overseas'
  UNION ALL SELECT 1452559375183659009, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1452559561737953281, 'US', 0, 'overseas'
  UNION ALL SELECT 1452559784023478274, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1452559952403853313, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1452560101314211841, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1452560269325467649, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1452560413714358273, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1452560572527448066, 'AU', 0, 'overseas'
  UNION ALL SELECT 1452560759132073986, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1452560943442354178, 'US', 0, 'overseas'
  UNION ALL SELECT 1452561208119762946, 'GB', 0, 'overseas'
  UNION ALL SELECT 1452561437300740098, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1452561551608086530, 'IN', 0, 'overseas'
  UNION ALL SELECT 1452561664350937089, 'FR', 0, 'overseas'
  UNION ALL SELECT 1452561744265035778, 'SI', 0, 'overseas'
  UNION ALL SELECT 1452562129105043458, 'US', 0, 'overseas'
  UNION ALL SELECT 1452562310697410562, 'US', 0, 'overseas'
  UNION ALL SELECT 1452562622770409473, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1452563980646969345, 'DE', 0, 'overseas'
  UNION ALL SELECT 1452564354082586625, 'GB', 0, 'overseas'
  UNION ALL SELECT 1452564795419852801, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1452564942010798082, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1452565279505473537, 'GB', 0, 'overseas'
  UNION ALL SELECT 1452565421713297409, 'GB', 0, 'overseas'
  UNION ALL SELECT 1452565591578431489, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1452566564807999489, 'DK', 0, 'overseas'
  UNION ALL SELECT 1452566707322023937, 'US', 0, 'overseas'
  UNION ALL SELECT 1452566797428244481, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1452566894283173890, 'NL', 0, 'overseas'
  UNION ALL SELECT 1452568570729713666, 'IT', 0, 'overseas'
  UNION ALL SELECT 1452569418603995137, 'JP', 0, 'overseas'
  UNION ALL SELECT 1452569580592283649, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1452569753737277441, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1452569975926370306, 'US', 0, 'overseas'
  UNION ALL SELECT 1452570691667574786, 'DE', 0, 'overseas'
  UNION ALL SELECT 1452571442867412993, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1452842070891634690, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1452844720823541762, 'US', 0, 'overseas'
  UNION ALL SELECT 1452845897648799746, 'US', 0, 'overseas'
  UNION ALL SELECT 1452846820265619458, 'FR', 0, 'overseas'
  UNION ALL SELECT 1452878214891163649, 'US', 0, 'overseas'
  UNION ALL SELECT 1452884739135193090, 'DE', 0, 'overseas'
  UNION ALL SELECT 1452885097387462658, 'US', 0, 'overseas'
  UNION ALL SELECT 1452885646614786049, 'DE', 0, 'overseas'
  UNION ALL SELECT 1452885770946539521, 'US', 0, 'overseas'
  UNION ALL SELECT 1452893246907572225, 'US', 0, 'overseas'
  UNION ALL SELECT 1452893556589838338, 'US', 0, 'overseas'
  UNION ALL SELECT 1452893921204834305, 'DK', 0, 'overseas'
  UNION ALL SELECT 1452906068840382465, 'JP', 0, 'overseas'
  UNION ALL SELECT 1452911515844517889, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1452912277467181057, 'US', 0, 'overseas'
  UNION ALL SELECT 1452912454429085697, 'KR', 0, 'overseas'
  UNION ALL SELECT 1452912817630728193, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1452913286390288386, 'JP', 0, 'overseas'
  UNION ALL SELECT 1452913478032269313, 'US', 0, 'overseas'
  UNION ALL SELECT 1452914023291801601, 'US', 0, 'overseas'
  UNION ALL SELECT 1452914132033273857, 'GB', 0, 'overseas'
  UNION ALL SELECT 1452914445330997250, 'CH', 0, 'overseas'
  UNION ALL SELECT 1452922146341584897, 'US', 0, 'overseas'
  UNION ALL SELECT 1452922426902835202, 'GB', 0, 'overseas'
  UNION ALL SELECT 1452922762321240066, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1452930575722430466, 'US', 0, 'overseas'
  UNION ALL SELECT 1453177233882251266, 'DE', 0, 'overseas'
  UNION ALL SELECT 1453533021154902018, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1453654166227243010, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1453658845925449730, 'KR', 0, 'overseas'
  UNION ALL SELECT 1453921894431264770, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1454978494805905410, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1454978797030674434, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1454979022571032578, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1454979659471839234, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1454980045079425026, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1454980136926273537, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1454980348608589826, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1454982001323737089, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1454982270673567745, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1454982672064294913, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1454983358856364034, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1454983637660151809, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1454983885979734018, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1454984133594664961, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1454984321260404738, 'US', 0, 'overseas'
  UNION ALL SELECT 1454984453624270850, 'US', 0, 'overseas'
  UNION ALL SELECT 1454984603365138434, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1454984865441988609, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1454985527378636801, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1455357246392029186, 'US', 0, 'overseas'
  UNION ALL SELECT 1455357479368802306, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1455357722621714434, 'US', 0, 'overseas'
  UNION ALL SELECT 1455357878373007361, 'US', 0, 'overseas'
  UNION ALL SELECT 1455358098964049922, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1455359153172934658, 'US', 0, 'overseas'
  UNION ALL SELECT 1455359462456786946, 'NL', 0, 'overseas'
  UNION ALL SELECT 1455359728270770178, 'GB', 0, 'overseas'
  UNION ALL SELECT 1456193673786896385, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1478627914139316226, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1478629717539041281, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1478630107110305794, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1478634367990378497, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1478635574096048130, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1479336744330571777, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1481823304493936642, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1482955709208350721, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1482962564034875393, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1482968307404394497, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1482990301671960577, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1483035831546433537, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1483250210787405826, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1483264405452992514, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1484097723878715393, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1491950032700596226, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1491950282064551938, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1492012017500839939, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1492012397714489345, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1492012507605262337, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1492012886778724354, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1492013013211824130, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1492013208314068993, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1492013269081145346, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1492013349146214402, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1492022936196898818, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1492023801418891265, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1492028530874146817, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1492401194155491330, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1492402455172988929, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1492405926387367937, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1493770758000844802, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1493771639454801921, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1493772470828687361, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1493773279020736514, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1493773368850145282, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1493781641913495554, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1493781707051077634, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1493781789615910914, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1493782432351055874, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1493782612093800449, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1493785068966047745, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1493865926649548801, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1493875916651204610, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1494190302813003778, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1494190907241562114, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1494193981376995329, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1494194258012315649, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1494194417546854402, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1494194519661379585, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1494194710208610305, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1494194818333573121, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1494194903297597442, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1494195016866758658, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1494195110676570113, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1494195428109877250, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1494196143112880130, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1494196225979744258, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1494196609192337410, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1494196940198412289, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1494197379019087873, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1494197470081613825, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1494197529238077441, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1494197694262968322, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1494518929597435906, 'US', 0, 'overseas'
  UNION ALL SELECT 1495689701099651074, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1496383576789303298, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1496387555757690881, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1496388844663115777, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1496695618905640961, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1497126598544003073, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1497134345897447426, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1497393945603330050, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1497400921276112897, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1497465515000467458, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1497468204476272642, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1498198214543720449, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1498209331546472450, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1498216225031897089, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1498217430063824898, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1498218500957716481, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1498218995080282113, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1498222788379459586, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1498225655207215106, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1498504674561552386, 'CA', 0, 'overseas'
  UNION ALL SELECT 1498505769841119234, 'DE', 0, 'overseas'
  UNION ALL SELECT 1498507150190768129, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1498507971611652097, 'JP', 0, 'overseas'
  UNION ALL SELECT 1498548520179789825, 'US', 0, 'overseas'
  UNION ALL SELECT 1498550091584172034, 'US', 0, 'overseas'
  UNION ALL SELECT 1498551699688706050, 'DE', 0, 'overseas'
  UNION ALL SELECT 1498554570241003521, 'US', 0, 'overseas'
  UNION ALL SELECT 1498555631123091458, 'CH', 0, 'overseas'
  UNION ALL SELECT 1498556724385206273, 'US', 0, 'overseas'
  UNION ALL SELECT 1498562128871747586, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1498565729786580994, 'ID', 0, 'overseas'
  UNION ALL SELECT 1498567138456170497, 'FR', 0, 'overseas'
  UNION ALL SELECT 1498568512988303361, 'US', 0, 'overseas'
  UNION ALL SELECT 1498585602474438657, 'US', 0, 'overseas'
  UNION ALL SELECT 1498588734503841794, 'US', 0, 'overseas'
  UNION ALL SELECT 1498589805397733378, 'US', 0, 'overseas'
  UNION ALL SELECT 1498590927759921153, 'HK', 1, 'hk_mo'
  UNION ALL SELECT 1498592537630265346, 'DE', 0, 'overseas'
  UNION ALL SELECT 1498594237866889217, 'US', 0, 'overseas'
  UNION ALL SELECT 1498595370211528705, 'US', 0, 'overseas'
  UNION ALL SELECT 1498596206622863361, 'US', 0, 'overseas'
  UNION ALL SELECT 1501373087122210818, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1503654413665931266, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1503655297275760642, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1503655949485744130, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1503658114832932865, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1504697174120734721, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1505828641420877826, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1505832594988605441, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1506455158471532546, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1506523148789489665, 'CH', 0, 'overseas'
  UNION ALL SELECT 1506525027120455682, 'KR', 0, 'overseas'
  UNION ALL SELECT 1506526899470344194, 'US', 0, 'overseas'
  UNION ALL SELECT 1506531707145162754, 'JP', 0, 'overseas'
  UNION ALL SELECT 1506536541290242050, 'US', 0, 'overseas'
  UNION ALL SELECT 1506546843029348354, 'US', 0, 'overseas'
  UNION ALL SELECT 1506548288524914690, 'US', 0, 'overseas'
  UNION ALL SELECT 1506549905093562369, 'US', 0, 'overseas'
  UNION ALL SELECT 1506555297563414529, 'US', 0, 'overseas'
  UNION ALL SELECT 1506798402497695746, 'SG', 0, 'overseas'
  UNION ALL SELECT 1506801548485742594, 'JP', 0, 'overseas'
  UNION ALL SELECT 1506803194276106241, 'US', 0, 'overseas'
  UNION ALL SELECT 1506804379699662850, 'US', 0, 'overseas'
  UNION ALL SELECT 1506805370876612609, 'DE', 0, 'overseas'
  UNION ALL SELECT 1506807412571525122, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1506809356253954050, 'DE', 0, 'overseas'
  UNION ALL SELECT 1506816509102604290, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1506817897085878273, 'DE', 0, 'overseas'
  UNION ALL SELECT 1506835333247959041, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1506838622593122305, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1506868091810775041, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1506869209257246722, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1506870529217298433, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1506871732282146817, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1506873223143260162, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1506874347241897985, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1506880192415612929, 'US', 0, 'overseas'
  UNION ALL SELECT 1506881413952077826, 'US', 0, 'overseas'
  UNION ALL SELECT 1506882217853353986, 'NL', 0, 'overseas'
  UNION ALL SELECT 1506883939367682050, 'US', 0, 'overseas'
  UNION ALL SELECT 1506885550315962370, 'US', 0, 'overseas'
  UNION ALL SELECT 1506886951465205762, 'US', 0, 'overseas'
  UNION ALL SELECT 1506889163448811521, 'US', 0, 'overseas'
  UNION ALL SELECT 1507244513284849666, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1508639801262268417, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1508725394705027074, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1509376312039550977, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1509404553991225346, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1509404991062867970, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1509406528824737793, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1509407503794896898, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1509407969819820034, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1509415880650457090, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1509428064252133377, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1509429439811878914, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1509429864573239297, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1509430296716574722, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1509431975595802625, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1509432648068562946, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1509433400828690434, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1509433828177936386, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1509434324972273666, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1509435372503891969, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1509435858132992002, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1509436388464988162, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1509439096563503106, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1509439494963662849, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1509439857183752194, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1509440260487028738, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1509440635529134082, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1509442062573936641, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1509442630197485569, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1509443757597040642, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1509444468305076226, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1509445211846123522, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1509446344379514882, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1509447440514719745, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1509448145552056322, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1509448997616525313, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1509449815916847106, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1509450195866263554, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1509450932985831425, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1509451386444587010, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1509452419904348162, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1509455507218276353, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1509456711742693378, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1509458119351083009, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1509462074697195521, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1509463034274291714, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1509463392421715969, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1509466114264965121, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1509467477094998017, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1509771602542264321, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1509773923816898562, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1509774475296571394, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1509774976792723458, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1509775743884787713, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1509778704316825601, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1509779279490121730, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1509779779153362946, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1509780615006846977, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1510063462988906497, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1510063918687453186, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1510065149493379073, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1510067352132124674, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1510067874952118273, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1510068424892575745, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1510082778174062594, 'KR', 0, 'overseas'
  UNION ALL SELECT 1510085153748156418, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1510085771405651970, 'US', 0, 'overseas'
  UNION ALL SELECT 1510086575076147202, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1510094059790663681, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1510103112390635521, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1510133310439911425, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1510160090466877441, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1510160575303254018, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1510161169082576898, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1510162149782061058, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1511612135677886465, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1513369073482846209, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1515927240431431682, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1516318209249140738, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1516972614138998785, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1518087670075502593, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1518089040346230786, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1518418034568474625, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1519861979823546370, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1522047907728031745, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1522090916444209153, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1522110232493391873, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1522134229754937345, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1522145746483249153, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1522169006298071042, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1522410501458436098, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1524265603622338561, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1524576834388328449, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1524585656897052674, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1524589166128603138, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1524601290628366337, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1524641177381470209, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1527497109547298817, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1527559492764479490, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1528645211067019266, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1528652717772259329, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1528652901545689090, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1528653336755060738, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1528653523879739394, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1528653710564016129, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1528653847159914497, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1528654209631678466, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1528654460950179841, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1528654633856167938, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1528654858603741185, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1528655015093235714, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1528655343763079169, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1528656026344112129, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1528656254287769602, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1528656398865428482, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1528656655745576962, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1528656835345661954, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1528658322088017921, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1528658548211347458, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1528658711810174978, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1528658956967243777, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1530167641933676545, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1534435048684584962, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1534458600603287553, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1534828101249302530, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1535140458408280065, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1535163801291292673, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1535164690571821057, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1535169628047728641, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1535172455277060098, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1536629887983476737, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1537243666068897793, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1539525196455723009, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1548954132654678017, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1549932958905806849, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1550356311785451522, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1550363758654664706, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1550375021669527553, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1552472092677603330, 'US', 0, 'overseas'
  UNION ALL SELECT 1552472441173934082, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1552473047024369665, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1552838180603002882, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1552842442082975746, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1552844237823901697, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1552955707295367170, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1554000090589396993, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1554020063219122178, 'US', 0, 'overseas'
  UNION ALL SELECT 1554020759607803906, 'JP', 0, 'overseas'
  UNION ALL SELECT 1554024324170612737, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1555090742525927426, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1556471363148029953, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1556523953097383938, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1556879621822193665, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1556913770444374017, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1556937721228926978, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1556941662846992386, 'US', 0, 'overseas'
  UNION ALL SELECT 1557284334577229826, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1557618542696833026, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1559423542813106178, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1560148117066739713, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1560175540835577858, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1560184500678422529, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1560190288780193793, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1560195942727151618, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1560211761410461698, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1562472247782928385, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1562633712015896577, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1562688015699136514, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1562699231066705921, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1562744046290587649, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1564526580548628482, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1566616891068379138, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1567317513912578049, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1567410748081172481, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1567442151707635713, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1567683993544028161, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1571669112738934786, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1573147727540383746, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1573150022059552769, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1573150180935585794, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1574640581370564610, 'US', 0, 'overseas'
  UNION ALL SELECT 1574641442347839490, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1574643022119858178, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1574643791611154434, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1574647638945550338, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1574649427472183298, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1574650015387774977, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1574651085442895873, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1574653354829705218, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1574654561883377665, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1574656741549920257, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1574661823054073857, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1574667577731436545, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1574683585305145345, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1574687647920582658, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1574688237824274434, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1574693933747810305, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1574694419389493250, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1574694792569303042, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1574697006029352962, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1574701595688448002, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1574952351465222146, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1578586322921074689, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1585465219402969090, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1585469438344355842, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1585472914264698882, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1585474054205267969, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1587624483638738945, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1587625629363220482, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1587703682449813505, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1588078721489698817, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1590952551468056577, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1599610477376208898, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1602946032277192705, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1604719941049679874, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1605394010602536962, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1607198386463768578, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1608703607392268290, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1612623691533873154, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1612629090110631938, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1612630517667164162, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1612633395580379137, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1612637516995850241, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1612639422589706241, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1612646867068264450, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1612654887256989698, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1612655788097105922, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1612705560325529601, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1612993176115703809, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1613006599834660865, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1613016082002571265, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1613017136433819649, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1613055652580564993, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1613070768915095553, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1613074056909778946, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1613075258292576258, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1613076219832659970, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1613348739299155970, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1613357996400713730, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1627848088746029058, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1627858463830843394, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1627908433170669569, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1627940290880872449, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1630813644440825857, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1636895015785512962, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1640285560419434497, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1646341119107186690, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1646342409979785218, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1651140548993576961, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1656925214585438209, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1656930153353277441, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1656931303259467777, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1658346844113125377, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1658348349713072130, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1662992992639741953, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1689924082721669121, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1689927643308322817, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1703698113761427457, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1713754882839724033, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1714852922828832770, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1714852995230953474, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1729691283032686593, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1772157080073957378, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1777252119653412866, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1778666120899751937, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1970675706982518785, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1970677619559960577, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1970677625570398210, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1970677748891324418, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1970677750216724481, 'US', 0, 'overseas'
  UNION ALL SELECT 1970677883926941697, 'GB', 0, 'overseas'
  UNION ALL SELECT 1970677885894070274, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1970677886615490561, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1970677887206887425, 'US', 0, 'overseas'
  UNION ALL SELECT 1970677887341105154, 'US', 0, 'overseas'
  UNION ALL SELECT 1970677887538237441, 'US', 0, 'overseas'
  UNION ALL SELECT 1970677897013170178, 'US', 0, 'overseas'
  UNION ALL SELECT 1970677897474543617, 'US', 0, 'overseas'
  UNION ALL SELECT 1970677897931722754, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1970677900989370369, 'US', 0, 'overseas'
  UNION ALL SELECT 1970677915673628674, 'GB', 0, 'overseas'
  UNION ALL SELECT 1970677916780924929, 'US', 0, 'overseas'
  UNION ALL SELECT 1970677917108080642, 'US', 0, 'overseas'
  UNION ALL SELECT 1970677935785316354, 'US', 0, 'overseas'
  UNION ALL SELECT 1970677936250884097, 'JP', 0, 'overseas'
  UNION ALL SELECT 1970677936510930946, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1970677936640954369, 'DE', 0, 'overseas'
  UNION ALL SELECT 1970677938931044354, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1970678249347289089, 'US', 0, 'overseas'
  UNION ALL SELECT 1970678249540227074, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1970678250270035970, 'KR', 0, 'overseas'
  UNION ALL SELECT 1970678250869821441, 'DE', 0, 'overseas'
  UNION ALL SELECT 1970678266501992449, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1970678272223023105, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1970678276572516354, 'GB', 0, 'overseas'
  UNION ALL SELECT 1970678279143624706, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1970678281190445058, 'US', 0, 'overseas'
  UNION ALL SELECT 1970678289637773314, 'DE', 0, 'overseas'
  UNION ALL SELECT 1970678341127049217, 'JP', 0, 'overseas'
  UNION ALL SELECT 1970678357098958849, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1970678727061737474, 'US', 1, 'mainland_acquired'
  UNION ALL SELECT 1970678757277503489, 'JP', 0, 'overseas'
  UNION ALL SELECT 1970678758070226945, 'JP', 0, 'overseas'
  UNION ALL SELECT 1970678759911526401, 'JP', 0, 'overseas'
  UNION ALL SELECT 1970678760045744130, 'JP', 0, 'overseas'
  UNION ALL SELECT 1970678767952007170, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1970678883538636802, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1970678883798683650, 'US', 0, 'overseas'
  UNION ALL SELECT 1970678883932901377, 'JP', 0, 'overseas'
  UNION ALL SELECT 1970678934021279745, 'US', 0, 'overseas'
  UNION ALL SELECT 1970678939998162945, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1970679345381838850, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1970679534708527105, 'JP', 0, 'overseas'
  UNION ALL SELECT 1970680266761375746, 'US', 0, 'overseas'
  UNION ALL SELECT 1970680270393643010, 'US', 0, 'overseas'
  UNION ALL SELECT 1970680442754371586, 'HK', 1, 'hk_mo'
  UNION ALL SELECT 1970680462144638978, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1970680975254818818, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1970681033975074817, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1970681046780284929, 'US', 0, 'overseas'
  UNION ALL SELECT 1970681056880168961, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1970681059329642498, 'US', 0, 'overseas'
  UNION ALL SELECT 1970699680630124546, 'TH', 0, 'overseas'
  UNION ALL SELECT 1970699754743476226, 'US', 0, 'overseas'
  UNION ALL SELECT 1970700185095843842, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1970700187859890178, 'US', 0, 'overseas'
  UNION ALL SELECT 1970700195799707649, 'US', 0, 'overseas'
  UNION ALL SELECT 1970700195996839938, 'US', 0, 'overseas'
  UNION ALL SELECT 1970700196533710849, 'AT', 0, 'overseas'
  UNION ALL SELECT 1970700906285445122, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1970701011365343234, 'HK', 1, 'hk_mo'
  UNION ALL SELECT 1970705882462236673, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1970705882659368962, 'JP', 0, 'overseas'
  UNION ALL SELECT 1970705902003499010, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1970705905384108033, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1970705906160054273, 'DE', 0, 'overseas'
  UNION ALL SELECT 1970706292547727362, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1970707833321107458, 'JP', 0, 'overseas'
  UNION ALL SELECT 1970707834919137282, 'LI', 0, 'overseas'
  UNION ALL SELECT 1970708026800156674, 'US', 0, 'overseas'
  UNION ALL SELECT 1970708046790209537, 'US', 0, 'overseas'
  UNION ALL SELECT 1970708129791291393, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1970708130059726850, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1970708131125080065, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1970708187966287874, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1970708197374111746, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1970708217620017154, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1970708238486679554, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1970708245138845697, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1970708402404274177, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1970708404711141378, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1970708412718067713, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1970708435883208705, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1970708437669982210, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1970708530221494274, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1970708588232912898, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1970708648349872130, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1970708700770283521, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1970708712417865729, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1970708715710394370, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1970708726611390466, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1970708767770095618, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1970708782534045697, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1970708807406268418, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1970708807804727297, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1970709006237249538, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1970709012260270082, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1970709019927457793, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1970709055595819009, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1970709059551047681, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1970709062067630081, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1970709062268956674, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1970709081545977858, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1970709082074460161, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1970709082942681090, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1970709098277056514, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1970709103255695362, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1970709144783499265, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1970709158888943617, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1970709163569786882, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1970709182708396034, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1970709183173963778, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1970709184289648641, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1970709193718444034, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1970709193986879490, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1970709206066475009, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1970709207177965570, 'TW', 1, 'taiwan'
  UNION ALL SELECT 1970709208482394114, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1970709283136811009, 'CN', 1, 'mainland_native'
  UNION ALL SELECT 1970709309728698370, 'CN', 1, 'mainland_native'
) g ON b.brand_id_std = g.brand_id_std;


/* ============================================================
 * A. 跨源融合 auto 别名：扩 related_words（17 列 SELECT，保留 Part C 填的 3 列）
 * ============================================================ */

/* A.CS1 TE Application Tooling -> TE Energy & Utilities (id 9001176)  [suffix_strip_abbr[TE APPLICATION TOOLING]] */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(
           COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)),
           ARRAY<VARCHAR(256)>['TE APPLICATION TOOLING']
       )),
       logo, state, official_website, level, type,
       'jp_brand+manual_extra', create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std = 9001176;

/* A.CS2 Cree LED -> 科锐-CREE (id 1443490693509910534)  [suffix_strip_en[CREE LED]] */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(
           COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)),
           ARRAY<VARCHAR(256)>['CREE LED']
       )),
       logo, state, official_website, level, type,
       'jp_brand+manual_extra', create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std = 1443490693509910534;

/* A.CS3 Brady Corporation -> 贝迪-Brady (id 1498585602474438657)  [suffix_strip_en[BRADY CORPORATION]] */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(
           COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)),
           ARRAY<VARCHAR(256)>['BRADY CORPORATION']
       )),
       logo, state, official_website, level, type,
       'jp_brand+manual_extra', create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std = 1498585602474438657;

/* A.CS4 Cosel USA, Inc. -> Cosel (id 1970677936250884097)  [suffix_strip_en[COSEL USA, INC.]] */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(
           COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)),
           ARRAY<VARCHAR(256)>['COSEL USA, INC.']
       )),
       logo, state, official_website, level, type,
       'jp_brand+manual_extra', create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std = 1970677936250884097;

/* A.CS5 Samsung Semiconductor, Inc. -> 三星-SAMSUNG (id 1443490691043659781)  [suffix_strip_en[SAMSUNG SEMICONDUCTOR, INC.]] */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(
           COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)),
           ARRAY<VARCHAR(256)>['SAMSUNG SEMICONDUCTOR, INC.']
       )),
       logo, state, official_website, level, type,
       'jp_brand+manual_extra', create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std = 1443490691043659781;

/* A.CS6 Radiall USA, Inc. -> 雷迪埃-Radiall (id 1498567138456170497)  [suffix_strip_en[RADIALL USA, INC.]] */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(
           COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)),
           ARRAY<VARCHAR(256)>['RADIALL USA, INC.']
       )),
       logo, state, official_website, level, type,
       'jp_brand+manual_extra', create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std = 1498567138456170497;

/* A.CS7 ARTESYN / Advanced Energy -> Artesyn (id 1448534630616387585)  [suffix_strip_en[ARTESYN / ADVANCED ENERGY]] */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(
           COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)),
           ARRAY<VARCHAR(256)>['ARTESYN / ADVANCED ENERGY']
       )),
       logo, state, official_website, level, type,
       'jp_brand+manual_extra', create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std = 1448534630616387585;

/* A.CS8 SL POWER / Advanced Energy -> SL Power (id 1448858323011850241)  [suffix_strip_en[SL POWER / ADVANCED ENERGY]] */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(
           COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)),
           ARRAY<VARCHAR(256)>['SL POWER / ADVANCED ENERGY']
       )),
       logo, state, official_website, level, type,
       'jp_brand+manual_extra', create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std = 1448858323011850241;

/* A.CS9 RAFI -> 纳安斐-RAFI (id 1498592537630265346)  [exact_en] */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(
           COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)),
           ARRAY<VARCHAR(256)>['RAFI']
       )),
       logo, state, official_website, level, type,
       'jp_brand+manual_extra', create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std = 1498592537630265346;

/* A.CS10 LEDdynamics Inc. -> LEDdynamics (id 1443490695665782793)  [suffix_strip_en[LEDDYNAMICS INC.]] */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(
           COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)),
           ARRAY<VARCHAR(256)>['LEDDYNAMICS INC.']
       )),
       logo, state, official_website, level, type,
       'jp_brand+manual_extra', create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std = 1443490695665782793;

/* A.CS11 CINCON -> 幸康-Cincon (id 1498562128871747586)  [exact_en] */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(
           COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)),
           ARRAY<VARCHAR(256)>['CINCON']
       )),
       logo, state, official_website, level, type,
       'jp_brand+manual_extra', create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std = 1498562128871747586;

/* A.CS12 Wolfspeed, Inc. -> Wolfspeed (id 1506881413952077826)  [suffix_strip_en[WOLFSPEED, INC.]] */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(
           COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)),
           ARRAY<VARCHAR(256)>['WOLFSPEED, INC.']
       )),
       logo, state, official_website, level, type,
       'jp_brand+manual_extra', create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std = 1506881413952077826;

/* A.CS13 C/A Design -> Protec (id 9000014)  [suffix_strip_alias[C/A DESIGN]] */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(
           COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)),
           ARRAY<VARCHAR(256)>['C/A DESIGN']
       )),
       logo, state, official_website, level, type,
       'jp_brand+manual_extra', create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std = 9000014;

/* A.CS14 Soberton Inc. -> Soberton (id 1970700195799707649)  [suffix_strip_en[SOBERTON INC.]] */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(
           COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)),
           ARRAY<VARCHAR(256)>['SOBERTON INC.']
       )),
       logo, state, official_website, level, type,
       'jp_brand+manual_extra', create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std = 1970700195799707649;

/* A.CS15 Allied Vision, Inc. -> Allied Vision (id 1506805370876612609)  [suffix_strip_en[ALLIED VISION, INC.]] */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(
           COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)),
           ARRAY<VARCHAR(256)>['ALLIED VISION, INC.']
       )),
       logo, state, official_website, level, type,
       'jp_brand+manual_extra', create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std = 1506805370876612609;

/* A.CS16 ANBON SEMICONDUCTOR -> 台湾安邦-AnBon (id 1443490693056925707)  [suffix_strip_en[ANBON SEMICONDUCTOR]] */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(
           COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)),
           ARRAY<VARCHAR(256)>['ANBON SEMICONDUCTOR']
       )),
       logo, state, official_website, level, type,
       'jp_brand+manual_extra', create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std = 1443490693056925707;

/* A.CS17 Goford Semiconductor -> 谷峰-GOFORD (id 1443490694369742859)  [suffix_strip_en[GOFORD SEMICONDUCTOR]] */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(
           COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)),
           ARRAY<VARCHAR(256)>['GOFORD SEMICONDUCTOR']
       )),
       logo, state, official_website, level, type,
       'jp_brand+manual_extra', create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std = 1443490694369742859;

/* A.CS18 Cornell Dubilier / Illinois Capacitor -> Cornell Dubilier-DUBILIER (id 9000015)  [suffix_strip_en[CORNELL DUBILIER / ILLINOIS CAPACITOR]] */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(
           COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)),
           ARRAY<VARCHAR(256)>['CORNELL DUBILIER / ILLINOIS CAPACITOR']
       )),
       logo, state, official_website, level, type,
       'jp_brand+manual_extra', create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std = 9000015;

/* A.CS19 NEC Corporation -> 日电电子-NEC (id 1443490694499766280)  [suffix_strip_en[NEC CORPORATION]] */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(
           COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)),
           ARRAY<VARCHAR(256)>['NEC CORPORATION']
       )),
       logo, state, official_website, level, type,
       'jp_brand+manual_extra', create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std = 1443490694499766280;

/* A.CS20 Littelfuse/Menbers -> 美国力特-Littelfuse (id 1443490693119840264)  [suffix_strip_en[LITTELFUSE/MENBERS]] */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(
           COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)),
           ARRAY<VARCHAR(256)>['LITTELFUSE/MENBERS']
       )),
       logo, state, official_website, level, type,
       'jp_brand+manual_extra', create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std = 1443490693119840264;

/* A.CS21 Tempo Semiconductor, Inc. -> Tempo Communications (id 9001205)  [suffix_strip_abbr[TEMPO SEMICONDUCTOR, INC.]] */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(
           COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)),
           ARRAY<VARCHAR(256)>['TEMPO SEMICONDUCTOR, INC.']
       )),
       logo, state, official_website, level, type,
       'jp_brand+manual_extra', create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std = 9001205;

/* A.CS22 Advantech Corp -> 研华-Advantech (id 1498507150190768129)  [suffix_strip_en[ADVANTECH CORP]] */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(
           COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)),
           ARRAY<VARCHAR(256)>['ADVANTECH CORP']
       )),
       logo, state, official_website, level, type,
       'jp_brand+manual_extra', create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std = 1498507150190768129;

/* A.CS23 Marvell Semiconductor, Inc. -> 迈威-MARVELL (id 1443490695858720776)  [suffix_strip_en[MARVELL SEMICONDUCTOR, INC.]] */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(
           COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)),
           ARRAY<VARCHAR(256)>['MARVELL SEMICONDUCTOR, INC.']
       )),
       logo, state, official_website, level, type,
       'jp_brand+manual_extra', create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std = 1443490695858720776;

/* A.CS24 UNEO Inc. -> UNEO (id 1443490696252985351)  [suffix_strip_en[UNEO INC.]] */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(
           COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)),
           ARRAY<VARCHAR(256)>['UNEO INC.']
       )),
       logo, state, official_website, level, type,
       'jp_brand+manual_extra', create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std = 1443490696252985351;

/* A.CS25 Fluke Electronics -> 福禄克-FLUKE (id 1443490700606672900)  [suffix_strip_en[FLUKE ELECTRONICS]] */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr, country_region, is_domestic, domestic_type,
       array_distinct(array_concat(
           COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)),
           ARRAY<VARCHAR(256)>['FLUKE ELECTRONICS']
       )),
       logo, state, official_website, level, type,
       'jp_brand+manual_extra', create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std = 1443490700606672900;
