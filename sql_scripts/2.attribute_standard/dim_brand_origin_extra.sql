/* ============================================================
 * dim_brand_origin_extra.sql —— 品牌产地手工补录
 *
 * 路径：sql_scripts/2.attribute_standard/dim_brand_origin_extra.sql
 * 上游：dim_brand_origin.sql（先执行：CREATE TABLE IF NOT EXISTS）。
 * 下游：brand_origin_backfill.sql（JOIN 回写 dim_std_brand 产地列）。
 *
 * 设计原则（与 dim_std_brand_manual_extra.sql 对称）：
 *   1. **brand_id_std 唯一**：每行对应一个品牌，PK UPSERT 覆盖；
 *      复用 manual_extra 的 brand_id_std（jp_brand 的 19 位 ID 或 9_000_001+ 段）。
 *   2. **产地三件套**：country_region / is_domestic / domestic_type 必须配套填写，
 *      不允许只填其中一个（要么全填，要么不补这行）。
 *   3. **不知道产地就不补**：产地是可选维度，不补 = NULL，不影响品牌本身。
 *
 * 字段含义：
 *   country_region   品牌起源地 ISO-2 码（CN/TW/HK/US/JP/DE…），NULL=未定
 *   is_domestic      1=中国资本/品牌（含台港澳+中资收购），0=海外，NULL=未定
 *   domestic_type    mainland_native / mainland_acquired / taiwan / hk_mo / overseas
 *
 * 维护方式：
 *   新增/修正产地 → 在下方追加 INSERT VALUES（PK UPSERT，可重复执行）。
 *   跑 sync_dim_std_brand.sh 后自动生效（第 3.5 步执行本文件 → 第 4 步 backfill 回写）。
 *
 * 幂等：PK 模型 UPSERT，重复执行只覆盖不报错。
 * ============================================================ */


/* ============================================================
 * 手工补录产地（按 brand_id_std 追加，每行一个品牌）
 *
 * 格式：
 * INSERT INTO dim.dim_brand_origin
 * (brand_id_std, country_region, is_domestic, domestic_type, update_at)
 * VALUES
 * (<brand_id_std>, '<ISO-2>', <0|1>, '<domestic_type>', CURRENT_TIMESTAMP());
 *
 * 示例（占位，无实际数据）：
 * INSERT INTO dim.dim_brand_origin
 * (brand_id_std, country_region, is_domestic, domestic_type, update_at)
 * VALUES
 * (<brand_id_std>, '<ISO-2>', <0|1>, '<domestic_type>', CURRENT_TIMESTAMP());
 * ============================================================ */


/* ============================================================
 * 规则引擎推断产地 (infer_brand_origin.py, 非联网核定)
 * 覆盖 656 个 NULL 品牌中规则可判的 10 条 (high/medium)
 *   - R1 策展反推 8 条 (medium): 来自 classification.csv 已核定品牌英文名映射
 *   - R2 地区词 2 条 (high): Swissbit->CH, LEI Indias->IN
 * 剩余 646 条 (14 分部后缀 low + 632 纯英文无 website) 需联网核定,
 *   见 sql_scripts/test/_infer_brand_origin_web_queue.csv
 * ============================================================ */

/* NextGen Components (manual_extra+clock_timing_dk) [medium] 策展: NextGen Components->US */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001079, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* XPPOWER (manual_extra) [medium] 策展: XPPOWER->GB */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001278, 'GB', 0, 'overseas', CURRENT_TIMESTAMP());

/* Swissbit (manual_extra) [high] 地区词: SWISS */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001312, 'CH', 0, 'overseas', CURRENT_TIMESTAMP());

/* SLPOWER (manual_extra) [medium] 策展: SLPOWER->US */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001313, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* LEI Indias (manual_extra) [high] 地区词: INDIA */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001328, 'IN', 0, 'overseas', CURRENT_TIMESTAMP());

/* ALPHAWIRE (manual_extra) [medium] 策展: ALPHAWIRE->TW */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001336, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* PUIAUDIO (manual_extra) [medium] 策展: PUIAUDIO->US */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001427, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* RFSOLUTIONS (manual_extra) [medium] 策展: RFSOLUTIONS->GB */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001511, 'GB', 0, 'overseas', CURRENT_TIMESTAMP());

/* Suscon (manual_extra) [medium] 策展: Suscon->TW */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001527, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* SONGCHUAN (manual_extra) [medium] 策展: SONGCHUAN->TW */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001710, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());


/* ============================================================
 * 联网核定产地 (WebSearch 核实总部, 2026-06)
 * 覆盖规则引擎 R2_branch 分部后缀 14 条 (规则判 US/CA 分部, 联网核实真实总部)
 * high=12 条直接采用; medium=3 条 (Parlex/B&J-USA x2) 母公司归属模糊, 带 basis 供复核
 * ============================================================ */

/* Phoenix America [high] Fort Wayne Indiana USA (母公司 discoverIE Group plc 英) */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9000574, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* WERMA USA Inc. [high] WERMA Signaltechnik GmbH+Co.KG, Rietheim-Weilheim 德国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001302, 'DE', 0, 'overseas', CURRENT_TIMESTAMP());

/* Parlex USA LLC [medium] Johnson Electric 旗下, 运营总部 Isle of Wight 英; 母公司香港 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001377, 'GB', 0, 'overseas', CURRENT_TIMESTAMP());

/* Innodisk USA Corporation [high] 宜鼎国际, 新北汐止, TPEx:5289 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001383, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* Phihong USA [high] 飞宏科技, 桃园龟山, TWSE:2457 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001387, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* ETA-USA [high] ETA-USA Inc. Morgan Hill CA 硅谷 (founder 关联日本 BETA POWER) */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001462, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Fraenkische USA, LP [high] FRÄNKISCHE Group, Königsberg 德国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001583, 'DE', 0, 'overseas', CURRENT_TIMESTAMP());

/* B&J-USA, Inc. [medium] Benedikt & Jäger 维也纳 1920 奥地利品牌, B&J-USA 北美分销 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001590, 'AT', 0, 'overseas', CURRENT_TIMESTAMP());

/* D-Line USA [high] D-Line (Europe) Ltd, North Shields 英; 2024 被 Luceco 收购 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001623, 'GB', 0, 'overseas', CURRENT_TIMESTAMP());

/* SUYIN-USA [high] 實盈股份 SUYIN, 新北汐止, 1981 成立 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001640, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* Unrise USA [high] Unirise USA LLC, Irvine CA */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001653, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Lantronix Canada ULC [high] Lantronix Inc, Irvine CA, NASDAQ:LTRX */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001665, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* B&J-USA Inc. [medium] 同 9001590, Benedikt & Jäger 奥地利品牌 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001680, 'AT', 0, 'overseas', CURRENT_TIMESTAMP());

/* Garmin Canada Inc. [high] Garmin Ltd 运营总部 Olathe Kansas 美 (注册瑞士 Schaffhausen) */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001686, 'US', 0, 'overseas', CURRENT_TIMESTAMP());


/* ============================================================
 * 联网核定产地 (WebSearch 核实总部, 2026-06, R5 unknown 高频品牌 Top 16)
 * 覆盖 632 个 R5 unknown 中器件数 Top 16 (合计 ~44 万器件, 占 632 品牌 60%)
 * high=14 直接采用; medium=2 (Central Components 台湾关联/Numonyx 已 defunct) 带 basis 复核
 * ============================================================ */

/* MTRONPTI [high] M-tron Industries Inc, Orlando FL, NYSE:MPTI, 1965 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001265, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Advanced Thermal Solutions [high] ATS Inc, Norwood MA, 1989 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9000565, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Bivar Inc. [high] Bivar Inc, Irvine CA, 1965, ESOP */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001266, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* EUROQUARTZ [high] Euroquartz Ltd, Crewkerne Somerset 英, 1982 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001267, 'GB', 0, 'overseas', CURRENT_TIMESTAMP());

/* CRYDOM [high] Crydom Inc, San Diego CA, Sensata 旗下 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001274, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* MEANWELL [high] 明纬企业, 新北五股, 1982 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001287, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* SYNQOR [high] SynQor Inc, Salem NH (2026 从 Boxborough MA 搬), 1997 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001283, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Astrodyne TDI [high] Astrodyne TDI, Hackettstown NJ, 1960 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001289, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Central Components Manufacturing [medium] Middlesex NJ 1990; scribd 提示台湾 Tai Linear/Central Ent 关联, 需复核 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001259, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* SSDI [high] Solid State Devices Inc, La Mirada CA, 1967 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001268, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* NOSHOK [high] NOSHOK Inc, Berea Ohio, 1967 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9000557, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Century Spring Corp [high] Century Spring Corp, Commerce CA, 1927, MW Components 旗下 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001273, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Conta-Clip [high] CONTA-CLIP Verbindungstechnik GmbH, Hövelhof 德国, 1978 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001277, 'DE', 0, 'overseas', CURRENT_TIMESTAMP());

/* Moujen [high] 茂仁电机 Moujen Electric, 台南仁德, 1961 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001285, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* NUMONYX [medium] Numonyx, Rolle 瑞士, Intel+STMicro 合资 2008, 2010 被 Micron 收购 (已 defunct) */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001286, 'CH', 0, 'overseas', CURRENT_TIMESTAMP());

/* ACTEL [high] Actel Corp, Mountain View CA, 1985, 2010 被 Microsemi 收购 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001288, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* ============================================================
 * ORIGIN_GAP_19 — 活品牌产地仅在 test_dim、未进 prod 种子（2026-07-09）
 * 来源：exports/brand_supplement/brand_origin_gap_19.csv
 * ============================================================ */

/* Mueller Electric Co [connector_digikey] */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001158, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* WECO Electrical Connectors Inc. [connector_digikey] */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001161, 'CA', 0, 'overseas', CURRENT_TIMESTAMP());

/* RF Industries [connector_digikey] */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001182, 'GB', 0, 'overseas', CURRENT_TIMESTAMP());

/* CompuCablePlusUSA [connector_digikey] */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001197, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* KOINO [connector_digikey] */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001207, 'KR', 0, 'overseas', CURRENT_TIMESTAMP());

/* Schroff [connector_digikey] */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001210, 'DE', 0, 'overseas', CURRENT_TIMESTAMP());

/* Boyd Laconia, LLC [connector_digikey] */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001223, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* MPD [connector_digikey] */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001226, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Honda Connector [connector_digikey] */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001229, 'CA', 0, 'overseas', CURRENT_TIMESTAMP());

/* Bud Industries [connector_digikey] */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001230, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Lantiq [connector_digikey] */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001240, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Encore Wire [connector_digikey] */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001255, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* JOHANSON [jp_brand] */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(1443490691819606018, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* 镁光-micron [jp_brand] */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(1443490693837066245, 'JP', 0, 'overseas', CURRENT_TIMESTAMP());

/* 莱迪斯-LATTICE [jp_brand] */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(1443490695409930248, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* 中移物联网-Chinamobile [jp_brand] */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(1443490698937339909, 'CN', 1, 'mainland_native', CURRENT_TIMESTAMP());

/* 康纳温菲尔德-Connor-Winfield [jp_brand] */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(1447509321808916481, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* 思佳讯-Skyworks [jp_brand] */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(1552472092677603330, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Central Semiconductor [jp_brand] */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(1970677897474543617, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* ============================================================
 * ORIGIN_WEB_VERIFY_BATCH1 — 联网核实 2026-07-09（严格分档抽样）
 * 见 exports/brand_supplement/brand_origin_web_verdicts_sample.md
 * ============================================================ */

/* CHINASEMI = China Semiconductor Corp (LED), 总部台北；规则误推 CN */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001980, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* PHIHONG = 飞宏科技 Phihong Technology, 总部桃园 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001374, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* NBK America → 母公司 Nabeya Bi-tech Kaisha (NBK), 总部日本岐阜 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001857, 'JP', 0, 'overseas', CURRENT_TIMESTAMP());

/* ============================================================
 * ORIGIN_WEB_VERIFY_BATCH2 — R2_branch 14 组联网核实 2026-07-09
 * 见 exports/brand_supplement/brand_origin_web_verdicts_branch14.md
 * （NBK 已在 BATCH1）
 * ============================================================ */

/* Selec Controls USA → 母公司 Selec Controls Pvt Ltd, 印度新孟买 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001925, 'IN', 0, 'overseas', CURRENT_TIMESTAMP());

/* Swanstrom Tools USA — 美国家族企业，总部威斯康星 Superior（非外国分部） */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001937, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* ELKO EP North America → ELKO EP Holding, 捷克 Holešov */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001945, 'CZ', 0, 'overseas', CURRENT_TIMESTAMP());

/* Helukabel USA → HELUKABEL GmbH, 德国 Hemmingen */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001967, 'DE', 0, 'overseas', CURRENT_TIMESTAMP());

/* Taica North America → 株式会社タイカ Taica, 东京 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001987, 'JP', 0, 'overseas', CURRENT_TIMESTAMP());

/* FDK America → FDK CORPORATION, 东京（总部；2025 后台资 Silitech 大股东） */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001998, 'JP', 0, 'overseas', CURRENT_TIMESTAMP());

/* Indium Corporation of America — 美国总部 Clinton NY（1934 创立，非外国分部） */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002000, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Khatod North America → Khatod Optoelectronic, 意大利米兰 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002063, 'IT', 0, 'overseas', CURRENT_TIMESTAMP());

/* YS Tech USA → 元山科技 Yen Sun Technology, 高雄台湾 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002071, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* Steinel America → Steinel GmbH, 德国 Herzebrock-Clarholz */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002141, 'DE', 0, 'overseas', CURRENT_TIMESTAMP());

/* TPK America → TPK Holding, 台北 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002170, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* Hoei America → 株式会社豊栄電機 HOEI DENKI, 大阪 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002199, 'JP', 0, 'overseas', CURRENT_TIMESTAMP());

/* KAGA FEI AMERICA → KAGA FEI / Kaga Electronics, 日本 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002262, 'JP', 0, 'overseas', CURRENT_TIMESTAMP());

/* ============================================================
 * ORIGIN_WEB_VERIFY_BATCH3 — R2_region_kw 5 + connector_digikey 18
 * 见 exports/brand_supplement/brand_origin_web_verdicts_batch3.md
 * ============================================================ */

/* American Opto Plus LED → Opto Plus Technology, 台北 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001897, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* American Technical Ceramics — 美国总部 Huntington Station NY */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002093, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* American High Voltage — 美国总部 Elko NV */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002229, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* American P.C.B Company — TI 参考设计裸板供应商，香港 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002247, 'HK', 1, 'hk_mo', CURRENT_TIMESTAMP());

/* American Recorder Technologies — 美国总部 Simi Valley CA */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002274, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Ease Electronics — 珠海连接器/CCTV 线缆 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001149, 'CN', 1, 'mainland_native', CURRENT_TIMESTAMP());

/* CableMAX → Cable Max Electronics, 台北 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001175, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* BellWether → 贝尔威勒, 桃园台湾 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001184, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* Linkplex Technology Limited, 香港 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001185, 'HK', 1, 'hk_mo', CURRENT_TIMESTAMP());

/* Menbers → Menber's S.p.A., 意大利 Legnago */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001186, 'IT', 0, 'overseas', CURRENT_TIMESTAMP());

/* Lighthorse Technologies — 美国总部 San Diego CA */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001189, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Millimeter Wave Technologies — RF 连接器, Chandler AZ */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001193, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Northern Technologies — 连接器分部 EDAC, Charlotte NC */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001198, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Walta Electronic — 台北 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001199, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* Micro-Mode Products — 美国总部 El Cajon CA */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001201, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* SUPERIOR TECH → 竣豪电子, 新北台湾 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001204, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* Elpress Inc → 母公司 Elpress AB, 瑞典 Kramfors */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001214, 'SE', 0, 'overseas', CURRENT_TIMESTAMP());

/* IO Audio Technologies — Knight Electronics 品牌, Dallas TX */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001215, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Supirit Inc — 总部 Brampton ON 加拿大 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001231, 'CA', 0, 'overseas', CURRENT_TIMESTAMP());

/* Roman-Jones Inc — 工程服务, Empire MI */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001233, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Milspecwest LLC — 微连接器, State Road NC */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001238, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Powerbx Inc — 总部 Salt Lake City UT */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001239, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* iWave Global → iWave Systems, 班加罗尔印度 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001253, 'IN', 0, 'overseas', CURRENT_TIMESTAMP());

/* ============================================================
 * ORIGIN_WEB_VERIFY_R5_BATCH — R5_unknown 全量联网核实
 * 1046 条 | 见 brand_origin_r5_resolved_summary.md
 * ============================================================ */

/* Protec [high] Alias C/A Design Inc.; HQ Exeter NH USA (Heico thermal solutions) */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9000014, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* WEC [medium] Well Expediting Ent. Co. Ltd. (WEC) Taiwan; short name ambiguous */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9000114, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* CALIBER [medium] Caliber Interconnects HQ Singapore; name collision possible */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9000316, 'SG', 0, 'overseas', CURRENT_TIMESTAMP());

/* PCA [high] PCA Electronics Inc. HQ North Hills CA */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9000326, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* MICRO-ELECTRONICS [low] Micro Electronics Inc. (Seekonk MA); generic name multiple entities */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9000327, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Unitense [high] Shenzhen Unitense Innovation Electronics Co. Ltd. */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9000519, 'CN', 1, 'mainland_native', CURRENT_TIMESTAMP());

/* PML [low] PML acronym ambiguous; no single HQ verified for DigiKey sensor context */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9000536, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* MyDevices [high] myDevices Inc. HQ Burbank CA */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9000537, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* EVVO [medium] Evvos S.A. HQ Howald Luxembourg (EVVO spelling variant) */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9000543, 'LU', 0, 'overseas', CURRENT_TIMESTAMP());

/* Variohm [high] Variohm Eurosensor UK */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9000558, 'GB', 0, 'overseas', CURRENT_TIMESTAMP());

/* Applied Measurements [high] Applied Measurements Ltd UK */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9000559, 'GB', 0, 'overseas', CURRENT_TIMESTAMP());

/* Maker Emporium [high] Maker Emporium Ltd UK */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9000560, 'GB', 0, 'overseas', CURRENT_TIMESTAMP());

/* Pololu [high] Pololu Corporation Nevada USA */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9000561, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Status Instruments [high] Status Instruments Ltd UK */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9000562, 'GB', 0, 'overseas', CURRENT_TIMESTAMP());

/* Flip Electronics [high] Flip Electronics USA distributor */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9000563, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Cobontech [high] Cobontech Co. Ltd. HQ Cheongju South Korea */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9000564, 'KR', 0, 'overseas', CURRENT_TIMESTAMP());

/* Tronics [high] Tronics Microsystems SA HQ Crolles France (TDK) */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9000566, 'FR', 0, 'overseas', CURRENT_TIMESTAMP());

/* Tell-i [high] Tell-i Technologies HQ Charlotte NC */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9000567, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* JUMO [high] JUMO GmbH parent Fulda Germany (not US subsidiary) */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9000569, 'DE', 0, 'overseas', CURRENT_TIMESTAMP());

/* Curtis Instruments [high] Curtis Instruments Inc. USA */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9000570, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Trafag [high] Trafag AG Switzerland */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9000572, 'CH', 0, 'overseas', CURRENT_TIMESTAMP());

/* VersaSense [high] VersaSense NV Belgium (imec spinoff) */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9000573, 'BE', 0, 'overseas', CURRENT_TIMESTAMP());

/* AMBO [high] AMBO Technology Co. Ltd. New Taipei Taiwan */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9000575, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* Rincon Power [high] Rincon Power California USA */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9000576, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Datel Inc. [high] Datel Inc. Massachusetts USA */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9000600, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Raytheon Semiconductor [high] Raytheon Semiconductor USA (legacy) */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9000601, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Integrated Circuit Microsystems [high] Integrated Circuit Microsystems USA */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9000602, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* AMSCO [medium] Amsco U.S. Inc. Paramount CA; icpdf context may differ */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9000604, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Austin Semiconductor Inc. [high] Austin Semiconductor Inc. Texas USA */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9000606, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Lansdale Semiconductor Inc. [high] Lansdale Semiconductor Inc. Pennsylvania USA */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9000607, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Summit Microelectronics [high] Summit Microelectronics USA (acquired by Qualcomm) */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9000608, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* AIMtron Technology [high] AIMtron Technology Inc. Taiwan */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9000609, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* Yamaha Corporation [high] Yamaha Corporation Japan */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9000610, 'JP', 0, 'overseas', CURRENT_TIMESTAMP());

/* Averlogic Inc. [high] Averlogic Inc. Taiwan */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9000611, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* TGS [medium] TGS (Tokyo Gas Sensor / timing components) Japan */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001064, 'JP', 0, 'overseas', CURRENT_TIMESTAMP());

/* HKC [high] Hong Kong X'tals Ltd (HKC) HQ Hong Kong */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001066, 'HK', 1, 'hk_mo', CURRENT_TIMESTAMP());

/* Cardinal Components [high] Cardinal Components Inc. USA */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001068, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Transko Electronics [high] Transko Electronics Inc. Taiwan */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001069, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* Golledge Electronics [high] Golledge Electronics Ltd UK */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001070, 'GB', 0, 'overseas', CURRENT_TIMESTAMP());

/* IBM [high] IBM Corporation USA */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001073, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Yangxing Technology [high] Shenzhen Yangxing Technology Co. Ltd. */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001074, 'CN', 1, 'mainland_native', CURRENT_TIMESTAMP());

/* Cymbet Corporation [high] Cymbet Corporation Minnesota USA */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001075, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Hefei Jingweite Electronics [high] Hefei Jingweite Electronics Co. Ltd. Anhui China */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001080, 'CN', 1, 'mainland_native', CURRENT_TIMESTAMP());

/* GSI [medium] GSI Technology Inc. Sunnyvale CA; GSI Electronics SG also exists */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001269, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* CATALYST [high] Catalyst Semiconductor Inc. USA (ON Semi legacy) */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001270, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* ATGBICS [high] ATGBICS HQ Bournemouth UK */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001271, 'GB', 0, 'overseas', CURRENT_TIMESTAMP());

/* QT [medium] QT-Brightek Corporation Milpitas CA; Brightek TW separate entity */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001272, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* OPTOWAY [high] Optoway Technology Inc. Hsinchu Taiwan */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001275, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* DATADELAY [high] Data Delay Devices Inc. USA */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001276, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* DIGITRON [high] Digitron Inc. USA */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001279, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* TEMEX [high] Temex ceramics France (Exxelia group) */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001280, 'FR', 0, 'overseas', CURRENT_TIMESTAMP());

/* DDK [high] DDK Ltd Japan connector manufacturer */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001281, 'JP', 0, 'overseas', CURRENT_TIMESTAMP());

/* STATEK [high] Statek Corporation California USA crystals */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001282, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* PYRAMID [medium] Pyramid Semiconductor USA */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001284, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Dremel [high] Dremel brand USA (Bosch Tool subsidiary) */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001290, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Serpac [high] Serpac Inc. USA enclosures */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001291, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* MAJOR-LEAGUE [low] MAJOR-LEAGUE short name; no definitive HQ found */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001292, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* CRANE [medium] Crane Co. / Crane Electronics USA */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001293, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Huber+Suhner, Inc. [high] Huber+Suhner AG parent HQ Switzerland */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001294, 'CH', 0, 'overseas', CURRENT_TIMESTAMP());

/* SolidRun LTD [high] SolidRun Ltd Israel */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001295, 'IL', 0, 'overseas', CURRENT_TIMESTAMP());

/* WALL [low] WALL short name ambiguous; no verified HQ */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001296, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Orion Fans [high] Orion Fans (Knight Electronics) USA */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001297, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Powerex Inc. [high] Powerex Inc. USA (Mitsubishi JV, HQ Pennsylvania) */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001298, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* ELPIDA [high] Elpida Memory Inc. Japan */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001301, 'JP', 0, 'overseas', CURRENT_TIMESTAMP());

/* DigiKey [high] DigiKey Corporation Thief River Falls MN */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001303, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* CALOGIC [high] Calogic LLC USA (legacy analog IC) */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001304, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* POWERDYNAMICS [low] POWERDYNAMICS short name ambiguous */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001305, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* ADPOW [medium] ADPOW likely China power brand; limited public HQ data */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001306, 'CN', 1, 'mainland_native', CURRENT_TIMESTAMP());

/* FORMOSA [high] Formosa (Taiwan semiconductor/industrial context) */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001307, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* ICSI [medium] ICSI Taiwan integrated circuit solutions context */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001308, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* OPTO PLUS LED CORP. [high] Opto Plus LED Corp. Taiwan */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001309, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* Bertech [high] Bertech USA ESD products */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001310, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* CDIL [high] Continental Device India Ltd (CDIL) India */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001311, 'IN', 0, 'overseas', CURRENT_TIMESTAMP());

/* HAMAMATSU [high] Hamamatsu Photonics Japan */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001314, 'JP', 0, 'overseas', CURRENT_TIMESTAMP());

/* SECOS [medium] SECOS GmbH Germany packaging; name ambiguous */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001315, 'DE', 0, 'overseas', CURRENT_TIMESTAMP());

/* MSPI [low] MSPI short name ambiguous */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001316, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* AZDISPLAYS [medium] AZ Displays USA LCD modules */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001317, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Astro Tool Corp [high] Astro Tool Corp USA */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001318, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* WEITRON [high] Weitron Electronics Taiwan */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001319, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* BSI [medium] BSI UK context (British Standards / BSI Electronics) */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001320, 'GB', 0, 'overseas', CURRENT_TIMESTAMP());

/* JDSU [high] JDS Uniphase (JDSU) USA */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001321, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Desco [high] Desco Industries USA ESD */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001322, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* FINISAR [high] Finisar Corporation USA */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001323, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* MaxBotix Inc. [high] MaxBotix Inc. USA */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001324, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* LMB Heeger Inc. [high] LMB Heeger Inc. USA */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001325, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* TAITRON [high] Taitron Components Inc. Taiwan */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001326, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* ASTRODYNE [high] Astrodyne TDI USA power supplies */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001327, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* ECM [low] ECM short name ambiguous (multiple ECM entities) */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001329, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* ACCUTEK [medium] AccuTek Microcircuit USA */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001330, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Bergquist [high] Bergquist Company USA (Henkel) */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001331, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Franjobaim [medium] Franjobaim Group Netherlands (Amsterdam operations) */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001332, 'NL', 0, 'overseas', CURRENT_TIMESTAMP());

/* OmniOn Power™ [high] OmniOn Power USA (GE/Vertiv spinoff) */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001334, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* SCS [high] SCS (Static Control Systems) USA */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001335, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* MERRIMAC [high] Merrimac Industries USA RF */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001337, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* EMERSON-NETWORKPOWER [high] Emerson Network Power USA */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001338, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* LIGITEK [high] Ligitek Electronics Taiwan LED */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001339, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* SANREX [high] Sanrex Corporation Japan power semiconductors */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001340, 'JP', 0, 'overseas', CURRENT_TIMESTAMP());

/* OptiFuse [high] OptiFuse USA fuses */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001341, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Chinsan [high] Chinsan Electronic Corp. Taiwan */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001343, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* BOARDCOM [medium] Boardcom Taiwan networking */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001345, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* TRSYS [low] TRSYS short name ambiguous */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001346, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* P-DUKE [high] P-Duke Technology Co. Ltd. Taiwan power supplies */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001347, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* Lantronix, Inc. [high] Lantronix Inc. USA */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001348, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* VMI [high] Virginia Microelectronics (VMI) USA */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001349, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* FLIR Extech [high] FLIR/Extech USA test instruments */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001350, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* OKAYA [high] Okaya Electric Industries Japan */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001351, 'JP', 0, 'overseas', CURRENT_TIMESTAMP());

/* TPI [high] Test Products International (TPI) USA */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001352, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* MINMAX [high] Minmax Technology Taiwan power modules */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001353, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* INOLUX [medium] Inolux LED Taiwan */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001354, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* MIMIX [high] Mimix Broadband USA (acquired) */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001355, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* SYNERGY [low] SYNERGY generic name; multiple US entities */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001356, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* HANBIT [high] Hanbit Electronics Korea */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001357, 'KR', 0, 'overseas', CURRENT_TIMESTAMP());

/* FREQUENCYDEVICES [high] Frequency Devices Inc. USA */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001358, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Pflitsch [high] Pflitsch GmbH Germany cable glands */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001359, 'DE', 0, 'overseas', CURRENT_TIMESTAMP());

/* EDAL [high] EDAL USA interconnect */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001360, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* ISAHAYA [high] Isahaya Electronics Japan */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001361, 'JP', 0, 'overseas', CURRENT_TIMESTAMP());

/* WITHWAVE CO LTD [high] Withwave Co. Ltd. Korea RF */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001362, 'KR', 0, 'overseas', CURRENT_TIMESTAMP());

/* Flambeau Inc. [high] Flambeau Inc. USA */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001363, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* CMLMICRO [high] CML Microcircuits UK */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001364, 'GB', 0, 'overseas', CURRENT_TIMESTAMP());

/* MOSEL [high] Mosel Vitelic / Mosel Taiwan semiconductor legacy */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001365, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* TechNexion [high] TechNexion Taiwan embedded */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001366, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* Comair Rotron [high] Comair Rotron USA fans (SPX) */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001367, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* TRIQUINT [high] TriQuint Semiconductor USA */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001368, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Magnasphere Corp [high] Magnasphere Corp USA sensors */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001369, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* MENDA [high] Menda/Esd Products USA */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001370, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* HP [high] HP Inc. / Hewlett-Packard USA */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001371, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* VITESSE [high] Vitesse Semiconductor USA */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001372, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* CLARE [high] Clare Inc. USA (IXYS) */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001373, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* YEONHO [high] Yeonho Electronic Korea connectors */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001375, 'KR', 0, 'overseas', CURRENT_TIMESTAMP());

/* Bopla Enclosures [high] bopla enclosures Germany (Phoenix Mecano) */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001376, 'DE', 0, 'overseas', CURRENT_TIMESTAMP());

/* POWERBOX [high] Powerbox International Sweden */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001378, 'SE', 0, 'overseas', CURRENT_TIMESTAMP());

/* EUDYNA [high] Eudyna Devices Japan (Fujitsu/Fujitsu RF) */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001379, 'JP', 0, 'overseas', CURRENT_TIMESTAMP());

/* HUTSON [low] HUTSON short name ambiguous */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001380, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Digilent, Inc. [high] Digilent Inc. USA */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001381, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Rose Enclosures [high] Rose Enclosures USA (Pentair) */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001384, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Orbel Corporation [high] Orbel Corporation USA EMI shielding */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001385, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* UOT [medium] UOT Taiwan optoelectronics context */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001386, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* Harvatek Corporation [high] Harvatek Corporation Taiwan LED */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001388, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* RFMD [high] RF Micro Devices (RFMD) USA */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001389, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* EDATEC [high] EDATEC Shenzhen China embedded boards */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001391, 'CN', 1, 'mainland_native', CURRENT_TIMESTAMP());

/* LEDIL [high] LEDiL Oy Finland optics */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001392, 'FI', 0, 'overseas', CURRENT_TIMESTAMP());

/* ALSC [medium] ALSC China LED/display context */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001393, 'CN', 1, 'mainland_native', CURRENT_TIMESTAMP());

/* POINN [medium] Poinn Shenzhen China electronics */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001394, 'CN', 1, 'mainland_native', CURRENT_TIMESTAMP());

/* Conductive Containers, Inc. [high] Conductive Containers Inc. USA */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001395, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* PURDY [high] Purdy Electronics USA distributor */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001396, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* SolaHD [high] SolaHD USA (Emerson/Vertiv) */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001397, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* TRIPPLITE [high] Tripp Lite USA power */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001398, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* ACL Staticide Inc [high] ACL Staticide Inc. USA */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001399, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* CHINFA [high] Chinfa Electronics Taiwan */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001400, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* PF [low] PF short name ambiguous */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001401, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* EUPEC [high] eupec GmbH Germany (Infineon legacy) */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001402, 'DE', 0, 'overseas', CURRENT_TIMESTAMP());

/* EXTECH [high] Extech Instruments USA */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001404, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* BOCA [high] Boca Systems USA printers */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001405, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* DATATRONICS [high] Datatronics Romoland USA magnetics */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001406, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* PMI [medium] PMI USA multiple entities; precision microwave context */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001407, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Parker Chomerics [high] Parker Chomerics USA thermal/EMI */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001408, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* EMMICRO [medium] EM Microelectronic context; EMMICRO legacy US/EU */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001409, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* REDLION [high] Red Lion Controls USA */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001410, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Akoustis- RFMi [high] Akoustis Technologies USA (RFMi) */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001411, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* PLL [low] PLL short name ambiguous */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001412, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* FUJIKURA [high] Fujikura Ltd Japan */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001413, 'JP', 0, 'overseas', CURRENT_TIMESTAMP());

/* Ezurio [high] Ezurio USA (Laird Connectivity) */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001414, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* TERIDIAN [high] Teridian Semiconductor USA */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001415, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* TYCLON [medium] Tyclon Taiwan timing/crystal context */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001416, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* Davies Molding, LLC [high] Davies Molding LLC USA */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001417, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* PMC [low] PMC short name ambiguous (multiple PMC companies) */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001418, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Agilink Microwires [medium] Agilink Microwires France */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001419, 'FR', 0, 'overseas', CURRENT_TIMESTAMP());

/* ROCKWELL [high] Rockwell Automation USA */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001420, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* TRUMPOWER [high] Trumpower Technology Taiwan power supplies */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001421, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* 80/20, LLC [high] 80/20 LLC USA extrusions */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001422, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* VANLONG [medium] Vanlong China electronics context */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001423, 'CN', 1, 'mainland_native', CURRENT_TIMESTAMP());

/* Opto 22 [high] Opto 22 USA automation */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001424, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* PULS, LP [high] PULS GmbH parent Germany (PULS LP US subsidiary) */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001425, 'DE', 0, 'overseas', CURRENT_TIMESTAMP());

/* Festo Corporation [high] Festo AG parent Germany */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001426, 'DE', 0, 'overseas', CURRENT_TIMESTAMP());

/* MUSIC [medium] Music Electronics Co. Ltd. Wuhan/Dongguan China */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001428, 'CN', 1, 'mainland_native', CURRENT_TIMESTAMP());

/* NICHIA [high] Nichia Corporation Japan */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001429, 'JP', 0, 'overseas', CURRENT_TIMESTAMP());

/* PLX [high] PLX Technology Inc. Sunnyvale CA (Broadcom legacy) */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001430, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* LEDTRONICS [high] Ledtronics USA */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001431, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Peerless by Tymphany [high] Peerless/Tymphany USA audio (parent HK ops) */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001432, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* PERKINELMER [high] PerkinElmer Inc. USA */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001433, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* CERAMATE [medium] Ceramate Taiwan ceramic components */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001434, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* Passive Plus [high] Passive Plus Inc. USA RF components */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001435, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Maxtena Inc [high] Maxtena Inc. USA antennas */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001436, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* EPtronics, Inc. [high] EPtronics Inc. USA */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001437, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* MG Chemicals [high] MG Chemicals Canada */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001438, 'CA', 0, 'overseas', CURRENT_TIMESTAMP());

/* BYTES [low] BYTES short name ambiguous */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001439, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* CAIG Laboratories, Inc. [high] CAIG Laboratories Inc. USA */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001440, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* A1PROS [low] A1PROS short name; limited HQ verification */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001441, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* FiberSource, Inc [high] FiberSource Inc. USA */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001442, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* RICHCO [high] Richco (Essentra) USA hardware */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001443, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* TMT [medium] TMT Taiwan electronics context */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001444, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* Syntiant [high] Syntiant Corp USA AI chips */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001445, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Coherent [high] Coherent Corp. USA */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001446, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* NEWHAVEN [high] Newhaven Display USA */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001447, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Peplink [high] Peplink (Plover Bay Technologies) HQ Hong Kong */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001448, 'HK', 1, 'hk_mo', CURRENT_TIMESTAMP());

/* DOMINANT [high] Dominant Opto Technologies Malaysia */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001449, 'MY', 0, 'overseas', CURRENT_TIMESTAMP());

/* FIBOX Enclosures [high] FIBOX Enclosures Finland */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001450, 'FI', 0, 'overseas', CURRENT_TIMESTAMP());

/* New Age Enclosures [high] New Age Enclosures USA */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001451, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* XFMRS [medium] XFMRS USA transformers/magnetics */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001452, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* UMC [high] UMC Electronics Co. Ltd. Japan (not TSMC UMC) */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001453, 'JP', 0, 'overseas', CURRENT_TIMESTAMP());

/* HPC Optics [high] HPC Optics 官网总部 Deerfield IL */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001454, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* EOREX [high] Eorex/森富科技 台湾公司登记 桃园杨梅 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001455, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* XiangJiang [medium] XiangJiang 多家中国 LED/光电企业 深圳/广州 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001456, 'CN', 1, 'mainland_native', CURRENT_TIMESTAMP());

/* WJCI [high] WJCI=WJ Communications 总部 San Jose CA (SEC/Qorvo) */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001457, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* HANTRONIX [high] Hantronix Inc. 总部 Cupertino CA */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001458, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Kitronik Ltd. [high] Kitronik Ltd. 英国教育电子 Nottingham */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001459, 'GB', 0, 'overseas', CURRENT_TIMESTAMP());

/* EPIGAP OSA Photonics [high] EPIGAP OSA Photonics 德国柏林光电 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001460, 'DE', 0, 'overseas', CURRENT_TIMESTAMP());

/* IQD [high] IQD Frequency Products 英国频率元件 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001461, 'GB', 0, 'overseas', CURRENT_TIMESTAMP());

/* Kurtz Ersa [high] Kurtz Ersa 总部德国 Wertheim 焊接设备 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001463, 'DE', 0, 'overseas', CURRENT_TIMESTAMP());

/* CARLOGAVAZZI [high] Carlo Gavazzi 总部意大利 Lainate */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001464, 'IT', 0, 'overseas', CURRENT_TIMESTAMP());

/* ZMD [high] ZMD AG 德国德累斯顿半导体(历史品牌) */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001465, 'DE', 0, 'overseas', CURRENT_TIMESTAMP());

/* Leopard Imaging Inc. [high] Leopard Imaging Inc. 总部 Fremont CA */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001466, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* ANYSOLAR Ltd [high] ANYSOLAR Ltd 英国太阳能模块 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001467, 'GB', 0, 'overseas', CURRENT_TIMESTAMP());

/* E-Z LOK [high] E-Z LOK 美国螺纹嵌件 Gardena CA */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001468, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* POLYFET [high] POLYFET 美国射频功率器件 NJ */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001469, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* BZBGEAR [high] BZBGEAR 美国 AV 设备 Huntington Beach CA */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001470, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* ROITHNER [high] Roithner Laser 奥地利维也纳激光 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001471, 'AT', 0, 'overseas', CURRENT_TIMESTAMP());

/* Panavise [high] Panavise 美国工具支架 Reno NV */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001472, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* CONEXANT [high] Conexant 美国 Irvine CA 半导体 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001474, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* SILONEX [high] Silonex 印度光耦/半导体 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001475, 'IN', 0, 'overseas', CURRENT_TIMESTAMP());

/* Terasic Inc. [high] Terasic Inc. 台湾 FPGA 开发板 台北 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001476, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* KEYSIGHT [high] Keysight Technologies 总部 Santa Rosa CA */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001477, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* BOWEI [high] BOWEI 安徽博微电子 合肥总部 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001478, 'CN', 1, 'mainland_native', CURRENT_TIMESTAMP());

/* LINEAGEPOWER [high] Lineage Power(原 Emerson Network Power) 美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001479, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* NANOAMP [medium] NanoAmp 美国射频/放大器品牌 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001480, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Techspray [high] Techspray 美国 ITW 旗下化学品 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001481, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* AZM [medium] AZM Electronics 美国电子元件 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001482, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* FILTRONIC [high] Filtronic 英国 Sedgefield 射频 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001483, 'GB', 0, 'overseas', CURRENT_TIMESTAMP());

/* VPT [high] VPT Inc. 美国 Blacksburg VA 电源 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001484, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* DEIAZ [medium] DEiAv/DEIAZ 美国工业控制配件 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001485, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Chemtronics [high] Chemtronics 美国 Kennesaw GA 化学品 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001486, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Vigortronix [high] Vigortronix 英国电源 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001487, 'GB', 0, 'overseas', CURRENT_TIMESTAMP());

/* ELMOS [high] Elmos Semiconductor 德国 Dortmund */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001488, 'DE', 0, 'overseas', CURRENT_TIMESTAMP());

/* LSTD [medium] LSTD 深圳联盛通达电子 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001489, 'CN', 1, 'mainland_native', CURRENT_TIMESTAMP());

/* TEKTRONIX [high] Tektronix(Keysight) 总部 Beaverton OR */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001490, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Sorbothane [high] Sorbothane 美国 Kent OH 减震材料 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001491, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Custom Computer Services Inc. [high] Custom Computer Services(CCS) 美国 WI */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001492, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Stahlin [high] Stahlin 美国 Belding MI 电气外壳 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001493, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Simco-Ion [high] Simco-Ion 美国 ITW 静电控制 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001494, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Quelighting Corp [medium] Quelighting Corp 中国 LED 照明 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001495, 'CN', 1, 'mainland_native', CURRENT_TIMESTAMP());

/* Display Visions [high] Display Visions 德国 Stockach 显示 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001496, 'DE', 0, 'overseas', CURRENT_TIMESTAMP());

/* Amprobe [high] Amprobe(Fluke) 美国 Everett WA */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001497, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* RFHIC [high] RFHIC 韩国京畿道 射频功放 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001498, 'KR', 0, 'overseas', CURRENT_TIMESTAMP());

/* European Thermodynamics Ltd [high] European Thermodynamics 英国 Leicester */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001499, 'GB', 0, 'overseas', CURRENT_TIMESTAMP());

/* SIRENZA [high] SiGe/Sierra Monolithics(SIRENZA) 美国 RF IC */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001500, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* SUNTAN [high] Suntan Technology 总部香港 Fanling */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001501, 'HK', 1, 'hk_mo', CURRENT_TIMESTAMP());

/* Nearson Inc. [high] Nearson Inc. 美国天线 Doral FL */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001502, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Avery Dennison RFID [high] Avery Dennison 总部 Mentor OH */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001503, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Wöhrle [high] Wöhrle 德国 Nürtingen 变压器 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001504, 'DE', 0, 'overseas', CURRENT_TIMESTAMP());

/* INNOVASIC [high] Innovasic(Microchip) 美国 Albuquerque NM */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001505, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* HMS Networks [high] HMS Networks 总部瑞典 Halmstad */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001506, 'SE', 0, 'overseas', CURRENT_TIMESTAMP());

/* Silvertel [high] Silvertel 英国 PoE 模块 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001507, 'GB', 0, 'overseas', CURRENT_TIMESTAMP());

/* Thomas & Betts [high] Thomas & Betts(ABB) 美国 Memphis TN */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001508, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Inspired LED, LLC [high] Inspired LED LLC 美国 St. George UT */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001509, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* POWERTIP [high] Powertip Technology 总部台中 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001510, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* Synzen [high] Synzen Precision 总部台北内湖 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001512, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* DigiKey Standard [high] DigiKey Standard=DigiKey 自有品牌 总部 MN */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001513, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* ACUTECH [medium] AcuTech Process Equipment 美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001514, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* ADDTEK [high] ADDtek Corp 总部台北 模拟IC设计 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001515, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* SensoPart [high] SensoPart 德国 Göppingen 传感器 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001516, 'DE', 0, 'overseas', CURRENT_TIMESTAMP());

/* YOBON [high] YOBON Technologies 总部台北 PMIC */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001517, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* TRANSCEND [high] Transcend 创见 总部台北 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001518, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* CGS Tape [high] CGS Tape 美国 Islandia NY 胶带 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001519, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* APLUS [high] Aplus Display 总部深圳 LCD */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001520, 'CN', 1, 'mainland_native', CURRENT_TIMESTAMP());

/* mightyZAP [high] mightyZAP=IR Robot 韩国富川 线性舵机 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001521, 'KR', 0, 'overseas', CURRENT_TIMESTAMP());

/* SSOUSA [high] SSOUSA=Solid State Optronics 圣何塞 CA */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001522, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* MAKE-PS [medium] MAKE-PS 美国电源模块小品牌 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001523, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* O'Reilly Media [high] O'Reilly Media 总部 Sebastopol CA */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001524, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* POTATO [low] POTATO 中国创客电子小品牌 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001525, 'CN', 1, 'mainland_native', CURRENT_TIMESTAMP());

/* CLAIREX [high] Clairex Technologies 总部 Plano TX 光耦 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001526, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* MINILOGIC [medium] MiniLogic 台湾逻辑器件/分销 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001528, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* WINSON [high] WINSON=Shenzhen Winson Electronics 深圳 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001529, 'CN', 1, 'mainland_native', CURRENT_TIMESTAMP());

/* AVMATRIX [high] AVMATRIX=漳州矩阵电子 总部漳州 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001530, 'CN', 1, 'mainland_native', CURRENT_TIMESTAMP());

/* Cooling Source [high] Cooling Source 美国 Santa Clara 散热 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001531, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* FILTRAN [high] Filtran 美国 RF 滤波器 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001532, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* TRANSCOM [medium] Transcom Inc. 美国防务通信 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001533, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* OPNEXT [high] Opnext/Oclaro 日本神奈川 光模块 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001534, 'JP', 0, 'overseas', CURRENT_TIMESTAMP());

/* Marutsuelec Co., Ltd. [high] Marutsuelec 丸嗣电子 日本大阪 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001535, 'JP', 0, 'overseas', CURRENT_TIMESTAMP());

/* EDSYN INCORPORATED [high] EDSYN 美国 Sylmar CA 焊接工具 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001536, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* ELBA LUBES [high] ELBA LUBES 美国润滑剂 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001537, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* PENCOM [high] PENCOM 美国 Mountain View CA 紧固件 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001538, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* SWST [low] SWST 台湾电子元件 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001539, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* Airgain [high] Airgain 总部 San Diego CA 天线 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001540, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* SunFounder [high] SunFounder 深圳创客教育电子 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001541, 'CN', 1, 'mainland_native', CURRENT_TIMESTAMP());

/* VINCOTECH [high] Vincotech 德国功率模块 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001542, 'DE', 0, 'overseas', CURRENT_TIMESTAMP());

/* NetBurner Inc. [high] NetBurner 美国嵌入式网络 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001543, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* TRANSWITCH [high] TranSwitch 美国 Shelton CT 通信芯片 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001544, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* QUANTUM [high] Quantum Corp 美国 San Jose 存储 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001545, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Calmark/Birtcher [high] Calmark/Birtcher 美国热管理 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001546, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* APM Hexseal [high] APM Hexseal 美国 Englewood NJ 密封 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001547, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* GHZTECH [high] GHz Technology(Microsemi) 总部 Santa Clara CA */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001548, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Alberko Heatsinkonline [medium] Alberko Heatsinkonline 美国散热器分销 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001549, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* GENESI ELETTRONICA [high] Genesi Elettronica 意大利电子 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001550, 'IT', 0, 'overseas', CURRENT_TIMESTAMP());

/* Teltonika [high] Teltonika 立陶宛 Vilnius IoT */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001551, 'LT', 0, 'overseas', CURRENT_TIMESTAMP());

/* Harimatec Inc. [high] Harimatec=日商哈利玛化成美国分部→母公司日本 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001552, 'JP', 0, 'overseas', CURRENT_TIMESTAMP());

/* Infraeo Inc. [medium] Infraeo Inc. 美国红外传感 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001553, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Gelmec [high] Gelmec 英国减振安装件 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001554, 'GB', 0, 'overseas', CURRENT_TIMESTAMP());

/* PowerFilm Inc. [high] PowerFilm 美国 Ames IA 柔性太阳能 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001555, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Xsens a Movella brand [high] Xsens(Movella) 荷兰 Enschede IMU */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001556, 'NL', 0, 'overseas', CURRENT_TIMESTAMP());

/* ControlByWeb [high] ControlByWeb 美国 Logan UT IoT */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001557, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* ENERGIZER [high] Energizer 美国 St. Louis MO */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001558, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* NEW TRY [low] NEW TRY 中国电子贸易品牌 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001559, 'CN', 1, 'mainland_native', CURRENT_TIMESTAMP());

/* OXFORD [medium] Oxford Instruments/出版社系 英国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001560, 'GB', 0, 'overseas', CURRENT_TIMESTAMP());

/* Neonode Inc. [high] Neonode 总部 Stockholm 触控 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001561, 'SE', 0, 'overseas', CURRENT_TIMESTAMP());

/* MicroCare Corporation [high] MicroCare 美国 Bristol CT 清洁 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001562, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Trumeter [high] Trumeter 英国 Salford 测量 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001563, 'GB', 0, 'overseas', CURRENT_TIMESTAMP());

/* VML [low] VML Technologies 美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001564, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* BB-BATTERY [high] BB-BATTERY=美美电池台湾 总部台湾 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001565, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* VTI [high] VTI Technologies(Murata) 芬兰 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001567, 'FI', 0, 'overseas', CURRENT_TIMESTAMP());

/* NIEC [high] NIEC=Nihon Inter Electronics 神奈川 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001568, 'JP', 0, 'overseas', CURRENT_TIMESTAMP());

/* PRD Plastics [high] PRD Plastics 美国塑料件 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001569, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* SHOULDER [low] SHOULDER 中国电子配件品牌 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001570, 'CN', 1, 'mainland_native', CURRENT_TIMESTAMP());

/* PICKER [medium] Picker International 美国医疗影像(历史) */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001571, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* EZmotion [medium] EZmotion 台湾运动控制 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001572, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* Nicslab [medium] Nicslab 深圳物联网硬件 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001573, 'CN', 1, 'mainland_native', CURRENT_TIMESTAMP());

/* YOUDA [medium] YOUDA 中国电子元件品牌 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001574, 'CN', 1, 'mainland_native', CURRENT_TIMESTAMP());

/* BTCPOWER [high] BTCPower 美国 Santa Ana CA 充电 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001575, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Elecrow [high] Elecrow 总部深圳宝安 开源硬件 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001576, 'CN', 1, 'mainland_native', CURRENT_TIMESTAMP());

/* ENPIRION [high] Enpirion(Intel) 美国电源模块 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001577, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* TRIPATH [high] Tripath 美国 Santa Clara 音频功放 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001578, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* SOLITRON [high] Solitron 美国 Oceanside CA 半导体 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001579, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* YUANDEAN [medium] YUANDEAN 中国电子品牌 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001580, 'CN', 1, 'mainland_native', CURRENT_TIMESTAMP());

/* Beacon EmbeddedWorks [high] Beacon EmbeddedWorks(Logic) 美国 MN */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001581, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Entaniya [high] Entaniya 日本大阪鱼眼镜头 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001582, 'JP', 0, 'overseas', CURRENT_TIMESTAMP());

/* Newhaven Display Intl [high] Newhaven Display 美国 Lake Grove IL */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001584, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Quarton Inc. [high] Quarton Inc. 台湾激光模块 台北 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001585, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* AXIOMTEK [high] Axiomtek 艾讯科技 总部台北 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001586, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* Luxtech, LLC [high] Luxtech LLC 美国 LED 照明 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001587, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* NexTek [high] NexTek 美国 Charlottesville VA EMI */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001588, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* RealSense [high] RealSense(Intel) 美国机器视觉 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001589, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* DigiKey Kit [high] DigiKey Kit=DigiKey 套件自有品牌 总部 MN */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001591, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Gearmo [high] Gearmo 美国 USB 适配器 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001592, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* IOT-BOTS.COM [high] IOT-BOTS.COM 美国教育机器人 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001593, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* NPC [high] NPC=Nippon Precision Circuits 日本 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001594, 'JP', 0, 'overseas', CURRENT_TIMESTAMP());

/* Powercast Corporation [high] Powercast 美国 Pittsburgh PA 无线充电 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001595, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Sanwa [high] Sanwa Electric 三和电气 日本 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001596, 'JP', 0, 'overseas', CURRENT_TIMESTAMP());

/* MICROSS [high] Microsemi/MICROSS 美国防务微电子 CT */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001597, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* RAMXEED [high] RAMXEED(原富士通存储) 总部横滨 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001598, 'JP', 0, 'overseas', CURRENT_TIMESTAMP());

/* Jabil Inc. [high] Jabil 总部 St. Petersburg FL */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001599, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* McGraw-Hill Education [high] McGraw-Hill Education 美国纽约 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001600, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* ENTITY ELETTRONICA [high] Entity Elettronica 意大利电子 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001601, 'IT', 0, 'overseas', CURRENT_TIMESTAMP());

/* HOSIDEN [high] Hosiden 星电 日本八尾大阪 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001602, 'JP', 0, 'overseas', CURRENT_TIMESTAMP());

/* CONTRINEX [high] Contrinex 瑞士 Grenchen 传感器 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001603, 'CH', 0, 'overseas', CURRENT_TIMESTAMP());

/* Embedded Artists [high] Embedded Artists 瑞典 Lund 模块 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001604, 'SE', 0, 'overseas', CURRENT_TIMESTAMP());

/* ZORAN [high] Zoran 美国 San Jose 多媒体芯片 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001605, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Aquantia Corp [high] Aquantia(Marvell) 美国 Santa Clara */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001606, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Enocean [high] EnOcean 德国 Oberhaching 能量采集 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001607, 'DE', 0, 'overseas', CURRENT_TIMESTAMP());

/* LIGHTEL [high] Lightel 美国光纤测试 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001608, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* LOCTITE [high] Loctite(Henkel) 德国 Düsseldorf */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001609, 'DE', 0, 'overseas', CURRENT_TIMESTAMP());

/* NAIS [high] NAIS=Panasonic 日本 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001610, 'JP', 0, 'overseas', CURRENT_TIMESTAMP());

/* Perinet [high] Perinet GmbH 德国工业物联网 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001611, 'DE', 0, 'overseas', CURRENT_TIMESTAMP());

/* REV Robotics [high] REV Robotics 美国 Manassas VA FRC */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001612, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Bluelec [medium] Bluelec 中国电子元件 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001613, 'CN', 1, 'mainland_native', CURRENT_TIMESTAMP());

/* DComponents [medium] DComponents 中国元器件分销 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001614, 'CN', 1, 'mainland_native', CURRENT_TIMESTAMP());

/* Kable Kontrol [high] Kable Kontrol 美国线缆管理 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001615, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Kenco Label & Tag [high] Kenco Label & Tag 美国标签 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001616, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Tronex [high] Tronex 美国工具/剪刀 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001617, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Ignion [high] Ignion 总部 Barcelona 天线 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001618, 'ES', 0, 'overseas', CURRENT_TIMESTAMP());

/* PTSolns [medium] PTSolns 美国工程方案 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001619, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Pycom Ltd. [high] Pycom Ltd 英国剑桥 IoT(已清算) */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001620, 'GB', 0, 'overseas', CURRENT_TIMESTAMP());

/* Corelis [high] Corelis 美国 Lake Oswego OR JTAG */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001622, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* ETAL [high] ETAL Group 英国变压器 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001624, 'GB', 0, 'overseas', CURRENT_TIMESTAMP());

/* Arieltech [medium] Arieltech 中国电子科技 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001625, 'CN', 1, 'mainland_native', CURRENT_TIMESTAMP());

/* Bruckewell [high] Bruckewell Technology 总部新竹竹北 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001626, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* Fujicon [medium] Fujicon 日本连接器 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001627, 'JP', 0, 'overseas', CURRENT_TIMESTAMP());

/* Labsland [high] Labsland 西班牙 Pamplona 教育 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001628, 'ES', 0, 'overseas', CURRENT_TIMESTAMP());

/* Onion Corporation [high] Onion Corporation 美国 Boston IoT */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001629, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Option NV [high] Option NV 比利时 Leuven 无线 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001630, 'BE', 0, 'overseas', CURRENT_TIMESTAMP());

/* VARITRONIX [high] Varitronix 伟信 香港显示 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001631, 'HK', 1, 'hk_mo', CURRENT_TIMESTAMP());

/* Agiltron Inc [high] Agiltron 美国 San Jose 光纤 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001632, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* enDAQ [high] enDAQ 美国 Woburn MA 数据采集 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001633, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* ENEDO [high] Enedo(Enics) 芬兰电源 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001634, 'FI', 0, 'overseas', CURRENT_TIMESTAMP());

/* Moticont [high] Moticont 美国 Van Nuys CA 电机 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001635, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Azumo [high] Azumo 美国 Chicago 反射显示 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001636, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* CITEL [high] CITEL 法国浪涌保护 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001637, 'FR', 0, 'overseas', CURRENT_TIMESTAMP());

/* Coolmag TC [medium] Coolmag TC 西班牙导热材料 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001638, 'ES', 0, 'overseas', CURRENT_TIMESTAMP());

/* JJM [medium] JJM 韩国电子元件 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001639, 'KR', 0, 'overseas', CURRENT_TIMESTAMP());

/* VIETES [medium] VIETES 越南电子 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001641, 'VN', 0, 'overseas', CURRENT_TIMESTAMP());

/* metraTec [high] metraTec 德国 Dresden RFID */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001642, 'DE', 0, 'overseas', CURRENT_TIMESTAMP());

/* OPTREX [high] Optrex(Kyocera Display) 日本东京 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001643, 'JP', 0, 'overseas', CURRENT_TIMESTAMP());

/* P1dB Inc [high] P1dB Inc 美国 RF 器件 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001644, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Pervasive Displays [high] Pervasive Displays 总部台南科学园 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001645, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* REYAX [high] REYAX Technology 总部台北内湖 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001646, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* SOSHIN [high] Soshin Electric 东京 SOSHDIN */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001647, 'JP', 0, 'overseas', CURRENT_TIMESTAMP());

/* Vantis [medium] Vantis 美国 PLD(历史品牌) */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001648, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Amtery Corporation [medium] Amtery Corporation 美国 Fremont CA */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001649, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* GroupGets LLC [high] GroupGets 美国众筹分销 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001650, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Tekscan [high] Tekscan 美国 Boston 压力传感 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001651, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* TokyLabs [high] TokyLabs 西班牙 Madrid 教育 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001652, 'ES', 0, 'overseas', CURRENT_TIMESTAMP());

/* WILLAS [medium] WILLAS 台湾电子 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001654, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* Ascentta [high] Ascentta Inc. 总部 Somerset NJ 光纤 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001655, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* ESPROS Photonics AG [high] ESPROS Photonics AG 瑞士 3D ToF */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001656, 'CH', 0, 'overseas', CURRENT_TIMESTAMP());

/* Opsero [high] Opsero 加拿大 Vancouver FPGA */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001657, 'CA', 0, 'overseas', CURRENT_TIMESTAMP());

/* Soundskrit, Inc. [high] Soundskrit 加拿大 Montreal 麦克风 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001658, 'CA', 0, 'overseas', CURRENT_TIMESTAMP());

/* STIRRI [low] STIRRI 挪威电子配件 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001659, 'NO', 0, 'overseas', CURRENT_TIMESTAMP());

/* Workswell [high] Workswell 捷克 Prague 热成像 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001660, 'CZ', 0, 'overseas', CURRENT_TIMESTAMP());

/* YOUWANG [medium] YOUWANG 中国电子品牌 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001661, 'CN', 1, 'mainland_native', CURRENT_TIMESTAMP());

/* AIStorm, Inc [high] AIStorm Inc. 总部 Houston TX */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001662, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Canon [high] Canon 佳能 总部东京 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001663, 'JP', 0, 'overseas', CURRENT_TIMESTAMP());

/* FRESH DIGIT [high] FRESH DIGIT 总部 Lake Forest CA */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001664, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Zeroplus [high] ZEROPLUS TECHNOLOGY 总部新北中和 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001666, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* ARCTIC [high] ARCTIC GmbH 总部德国不伦瑞克 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001667, 'DE', 0, 'overseas', CURRENT_TIMESTAMP());

/* Datawave LLC [high] Datawave LLC 美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001668, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* FLIR Lepton [high] Teledyne FLIR 总部美国俄勒冈 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001669, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* GE [high] General Electric 总部美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001670, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Joulescope® [high] Joulescope LLC 总部美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001671, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Terabee SAS [high] Terabee SAS 总部法国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001672, 'FR', 0, 'overseas', CURRENT_TIMESTAMP());

/* USBGear [high] USBGear 总部美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001673, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* CADEKA [high] Cadeka Microcircuits 总部美国科罗拉多 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001674, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* DECIDE4ACTION [high] DECIDE4ACTION 总部美国南卡罗来纳格林维尔 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001675, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* MPLUSE [high] M-Pulse Microwave Inc 总部美国加州圣何塞 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001676, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Senix Corporation [high] Senix Corporation 总部美国佛蒙特 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001677, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Spyraflo, Inc. [high] Spyraflo Inc 总部美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001678, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* WAVEPIA.,Co.Ltd [high] WAVEPIA Co Ltd 总部韩国华城 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001679, 'KR', 0, 'overseas', CURRENT_TIMESTAMP());

/* BVLED [high] Bright View Electronic (BVLED) 总部台湾新北中和 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001681, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* ADLINK [high] ADLINK 总部台湾 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001682, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* APACER [high] Apacer Technology 总部台湾 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001683, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* ETL [high] ETL Systems Ltd 总部英国赫里福德 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001685, 'GB', 0, 'overseas', CURRENT_TIMESTAMP());

/* Glass Acoustic Innovations Co. Ltd. [high] Glass Acoustic Innovations 总部台湾新北中和 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001687, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* KUKA Robotics Corporation [high] KUKA AG 总部德国奥格斯堡 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001688, 'DE', 0, 'overseas', CURRENT_TIMESTAMP());

/* LAPIS [high] LAPIS Semiconductor (Rohm) 总部日本 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001689, 'JP', 0, 'overseas', CURRENT_TIMESTAMP());

/* NEXCOM [high] NEXCOM 总部台湾台北 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001690, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* Yamar [high] Yamar AS 总部挪威 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001691, 'NO', 0, 'overseas', CURRENT_TIMESTAMP());

/* 5G HUB [high] 5G Hub Technologies Inc 总部美国华盛顿州 Bothell */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001692, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* AMX Solar [high] AMX Solar/AMX3d 总部美国伊利诺伊 Lisle */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001693, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Arducam [high] Arducam 总部中国深圳 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001694, 'CN', 1, 'mainland_native', CURRENT_TIMESTAMP());

/* Compulab [high] Compulab 总部以色列 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001695, 'IL', 0, 'overseas', CURRENT_TIMESTAMP());

/* EMOSAFE [high] EMO Systems GmbH (EMOSAFE) 总部德国柏林 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001696, 'DE', 0, 'overseas', CURRENT_TIMESTAMP());

/* EnerSys [high] EnerSys 总部美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001697, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Focus LCDs [high] Focus LCDs 总部美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001698, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* GP BATTERIES [high] GP Batteries (Gold Peak) 总部香港 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001699, 'HK', 1, 'hk_mo', CURRENT_TIMESTAMP());

/* IKALOGIC [high] IKALOGIC 总部法国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001700, 'FR', 0, 'overseas', CURRENT_TIMESTAMP());

/* InPlay Inc [high] InPlay Inc 总部台湾 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001701, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* Micrium Inc. [high] Micrium Inc 总部美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001702, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Neurochrome [high] Neurochrome 总部加拿大 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001703, 'CA', 0, 'overseas', CURRENT_TIMESTAMP());

/* NexCOBOT CO., LTD. [high] NexCOBOT 总部台湾 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001704, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* Omnielektronik [high] OMNI ELEKTRONIK GmbH 总部德国 Lindlar */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001705, 'DE', 0, 'overseas', CURRENT_TIMESTAMP());

/* PMC-Sierra [high] PMC-Sierra 总部美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001706, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Portescap [high] Portescap 总部瑞士 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001707, 'CH', 0, 'overseas', CURRENT_TIMESTAMP());

/* Powersight [high] Powersight 总部美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001708, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Qoitech AB [high] Qoitech AB 总部瑞典 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001709, 'SE', 0, 'overseas', CURRENT_TIMESTAMP());

/* STAF Corporation [high] STAF Corporation 总部日本 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001711, 'JP', 0, 'overseas', CURRENT_TIMESTAMP());

/* Tecdia Inc. [high] Tecdia Inc 总部日本 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001712, 'JP', 0, 'overseas', CURRENT_TIMESTAMP());

/* Availink [high] Availink 总部美国圣何塞 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001713, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Berkeley Nuclonics Corporation [high] Berkeley Nuclonics Corporation 总部美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001714, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Dgtronix [high] Dgtronix Ltd 总部以色列拉阿纳纳 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001715, 'IL', 0, 'overseas', CURRENT_TIMESTAMP());

/* ETRI [high] ETRI 韩国电子通信研究院总部大田 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001716, 'KR', 0, 'overseas', CURRENT_TIMESTAMP());

/* Feztek [high] Feztek LLC 总部美国密歇根 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001717, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* QNAP [high] QNAP 总部台湾 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001718, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* SAFT [high] Saft 总部法国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001719, 'FR', 0, 'overseas', CURRENT_TIMESTAMP());

/* SAN-TRON [high] SAN-TRON 总部美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001720, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* SLS [high] Sports Leisure Systems (SLS) 总部日本大阪 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001721, 'JP', 0, 'overseas', CURRENT_TIMESTAMP());

/* TE Kemtron [high] TE Kemtron (TE Connectivity) 总部美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001722, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* VaOpto [high] VaOpto LLC 总部美国内华达拉斯维加斯 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001723, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* DOW-KEY [high] Dow-Key Microwave 总部美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001724, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Ebelong [high] Ebelong 总部中国深圳宝安 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001725, 'CN', 1, 'mainland_native', CURRENT_TIMESTAMP());

/* Enfis [high] Enfis 总部英国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001726, 'GB', 0, 'overseas', CURRENT_TIMESTAMP());

/* EPC Space, LLC [high] EPC Space LLC 总部美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001727, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* FIBAsource [high] FIBAsource Ltd 注册总部英国苏格兰 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001728, 'GB', 0, 'overseas', CURRENT_TIMESTAMP());

/* Gardtec Incorporated [high] Gardtec Incorporated 总部美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001729, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Innergie [high] Innergie (Delta) 总部台湾 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001730, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* LUXPIA [high] Luxpia Co Ltd 总部韩国水原 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001731, 'KR', 0, 'overseas', CURRENT_TIMESTAMP());

/* Raytac [high] Raytac Corporation 全球总部台湾新北 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001732, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* RELPOL S.A. [high] RELPOL S.A. 总部波兰 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001733, 'PL', 0, 'overseas', CURRENT_TIMESTAMP());

/* Schmalz Inc [high] Schmalz 母公司总部德国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001734, 'DE', 0, 'overseas', CURRENT_TIMESTAMP());

/* SIGE [high] SiGe Semiconductor 历史总部美国马萨诸塞 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001735, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Sigfox [high] Sigfox 总部法国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001736, 'FR', 0, 'overseas', CURRENT_TIMESTAMP());

/* SkyMirr [high] SkyMirr Inc 总部美国佛罗里达 Melbourne */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001737, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Starlogixs [high] StarLogixs Pty Ltd 总部澳大利亚 NSW Deepwater */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001738, 'AU', 0, 'overseas', CURRENT_TIMESTAMP());

/* SVTronics Inc. [high] SVTronics Inc 总部美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001739, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* XTool [high] xTool (Makeblock) 总部中国深圳 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001740, 'CN', 1, 'mainland_native', CURRENT_TIMESTAMP());

/* Fingerprint Cards AB [high] Fingerprint Cards AB 总部瑞典 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001742, 'SE', 0, 'overseas', CURRENT_TIMESTAMP());

/* HALA [medium] HALA 疑为台湾 LED/光电器件品牌(待品类复核) */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001743, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* Hvtools [medium] Hvtools 美国工具/测试设备供应商 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001744, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* iCana [medium] iCana 中国电子元器件品牌 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001745, 'CN', 1, 'mainland_native', CURRENT_TIMESTAMP());

/* ICOMTECH, INC. [high] iComTech Inc 总部美国加州尔湾 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001746, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Mabuchi Motor [high] Mabuchi Motor 总部日本 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001747, 'JP', 0, 'overseas', CURRENT_TIMESTAMP());

/* Midas Displays [high] Midas Displays 总部英国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001748, 'GB', 0, 'overseas', CURRENT_TIMESTAMP());

/* NanoSen [high] NanoSen GmbH 总部德国开姆尼茨 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001749, 'DE', 0, 'overseas', CURRENT_TIMESTAMP());

/* NeoCortec [high] NeoCortec 总部丹麦 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001750, 'DK', 0, 'overseas', CURRENT_TIMESTAMP());

/* OTAX [high] OTAX Co Ltd 总部日本横滨 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001751, 'JP', 0, 'overseas', CURRENT_TIMESTAMP());

/* Pro'sKit [high] Pro'sKit (宝工实业) 总部台湾新北新店 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001752, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* TygerClaw [high] TygerClaw (GGI) 总部加拿大安大略万锦 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001753, 'CA', 0, 'overseas', CURRENT_TIMESTAMP());

/* UBIROS INC. [high] UBIROS INC 总部美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001754, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Vividia [high] Vividia Technologies 总部美国南卡罗来纳 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001755, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Xavitech [high] Xavitech 总部瑞典 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001756, 'SE', 0, 'overseas', CURRENT_TIMESTAMP());

/* 3M Healthcare [high] 3M Healthcare (3M) 总部美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001757, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Cubit [medium] Cubit 美国电子/开发板品牌 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001758, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Dobot [high] Dobot 总部中国深圳 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001759, 'CN', 1, 'mainland_native', CURRENT_TIMESTAMP());

/* Fedco Batteries [high] Fedco Batteries 总部美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001760, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Hiblow [high] Hiblow 总部日本 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001761, 'JP', 0, 'overseas', CURRENT_TIMESTAMP());

/* HUMIREL [high] HUMIREL (Sensirion) 总部法国/瑞士体系 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001762, 'FR', 0, 'overseas', CURRENT_TIMESTAMP());

/* INTRONICS [high] Intronics BV 总部荷兰 Barneveld */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001763, 'NL', 0, 'overseas', CURRENT_TIMESTAMP());

/* IoTize [high] IoTize 总部法国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001764, 'FR', 0, 'overseas', CURRENT_TIMESTAMP());

/* IPDiA [high] IPDiA (Murata) 总部法国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001765, 'FR', 0, 'overseas', CURRENT_TIMESTAMP());

/* LogiSwitch [high] LogiSwitch 总部美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001766, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Micro:bit [high] Micro:bit Educational Foundation 总部英国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001767, 'GB', 0, 'overseas', CURRENT_TIMESTAMP());

/* MMB Networks [high] MMB Networks 总部加拿大 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001768, 'CA', 0, 'overseas', CURRENT_TIMESTAMP());

/* Moddable [high] Moddable 总部美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001769, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* mydpi [medium] mydpi 美国显示/接口品牌 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001770, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Nextera Video [high] Nextera Video 总部美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001771, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Noveltronics [medium] Noveltronics 美国电子品牌 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001772, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Orion RepTech [high] Orion RepTech Inc 总部加拿大魁北克 Kirkland */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001773, 'CA', 0, 'overseas', CURRENT_TIMESTAMP());

/* Pacific Lasertec [high] Pacific Lasertec 总部美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001774, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Protempis [high] Protempis 总部美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001775, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Pulsar [high] Pulsar Microwave Corporation 总部美国新泽西 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001776, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Quadcept Inc. [high] Quadcept Inc 总部日本 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001777, 'JP', 0, 'overseas', CURRENT_TIMESTAMP());

/* RangeAnt [high] RangeAnt 总部瑞典卡尔斯塔德 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001778, 'SE', 0, 'overseas', CURRENT_TIMESTAMP());

/* RFID Inc [high] RFID Inc 总部美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001779, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Triscend [high] Triscend 总部美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001780, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Ultra Librarian [high] Ultra Librarian 总部美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001781, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* VigilLink [medium] VigilLink 美国网络/安防品牌 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001782, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* ZIEHL [high] ZIEHL-ABEGG 总部德国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001783, 'DE', 0, 'overseas', CURRENT_TIMESTAMP());

/* Zubax Robotics [high] Zubax Robotics OÜ 总部爱沙尼亚塔林 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001784, 'EE', 0, 'overseas', CURRENT_TIMESTAMP());

/* Aconno [high] aconno GmbH 总部德国杜塞尔多夫 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001785, 'DE', 0, 'overseas', CURRENT_TIMESTAMP());

/* Aitronics Inc. [medium] Aitronics Inc 台湾电子品牌 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001786, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* ArkX Laboratories [high] ArkX Laboratories 总部美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001787, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Asus [high] ASUS (ASUSTeK) 总部台湾台北 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001788, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* AURIS [medium] AURIS 德国音频/电子品牌 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001789, 'DE', 0, 'overseas', CURRENT_TIMESTAMP());

/* Benjamin VERNOUX [high] Benjamin Vernoux 法国个人/开源硬件 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001790, 'FR', 0, 'overseas', CURRENT_TIMESTAMP());

/* CAVU [medium] CAVU 美国航空电子/连接器分销品牌 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001791, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* CODIXX AG [high] CODIXX AG 总部德国 Barleben */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001792, 'DE', 0, 'overseas', CURRENT_TIMESTAMP());

/* Corsair [high] Corsair 总部美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001793, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Critical Link LLC [high] Critical Link LLC 总部美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001794, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* DENRYO [high] DENRYO 总部日本东京 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001795, 'JP', 0, 'overseas', CURRENT_TIMESTAMP());

/* DILABS [medium] DILABS 美国实验室/测试设备品牌 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001796, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* E Ink Corporation [high] E Ink Corporation 总部台湾新竹 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001797, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* Embention [high] Embention 总部西班牙 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001798, 'ES', 0, 'overseas', CURRENT_TIMESTAMP());

/* EMO Inc. [medium] EMO Inc 日本电子品牌 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001799, 'JP', 0, 'overseas', CURRENT_TIMESTAMP());

/* FORYARD [high] FORYARD (宁波福耀光电) 总部中国宁波 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001800, 'CN', 1, 'mainland_native', CURRENT_TIMESTAMP());

/* Himax [high] Himax Technologies 总部台湾 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001801, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* Inphi Corporation [high] Inphi Corporation 总部美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001802, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* IOT747 [high] IOT747 (CompanyDeep Ltd) 总部英国剑桥 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001803, 'GB', 0, 'overseas', CURRENT_TIMESTAMP());

/* Labjack Corporation [high] Labjack Corporation 总部美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001804, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* LightWare LiDAR Inc. [high] LightWare LiDAR 总部南非 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001805, 'ZA', 0, 'overseas', CURRENT_TIMESTAMP());

/* Lucent [high] Lucent Technologies 历史总部美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001806, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* LulzBot [high] LulzBot (Aleph Objects) 总部美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001807, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Micropower Battery Company [high] Micropower Battery Company 总部美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001808, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* MICROTEST [high] MICROTEST 总部台湾 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001809, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* Netsol [medium] Netsol 美国 Netsol Technologies 体系 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001810, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Neware [high] Neware Technology 总部中国深圳 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001811, 'CN', 1, 'mainland_native', CURRENT_TIMESTAMP());

/* Pacific Goal [high] Pacific Goal Optronics 注册总部香港元朗 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001812, 'HK', 1, 'hk_mo', CURRENT_TIMESTAMP());

/* PalmSens BV [high] PalmSens BV 总部荷兰 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001813, 'NL', 0, 'overseas', CURRENT_TIMESTAMP());

/* Parretto [medium] Parretto 意大利连接器/线束品牌 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001814, 'IT', 0, 'overseas', CURRENT_TIMESTAMP());

/* PETERMANN [high] PETERMANN 总部德国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001815, 'DE', 0, 'overseas', CURRENT_TIMESTAMP());

/* Ridgeback Lighting LLC [high] Ridgeback Lighting LLC 总部美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001816, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* ROBOT DOMESTICI SRL [high] ROBOT DOMESTICI SRL 总部意大利 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001817, 'IT', 0, 'overseas', CURRENT_TIMESTAMP());

/* Rose+Krieger [high] Rose+Krieger 总部德国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001818, 'DE', 0, 'overseas', CURRENT_TIMESTAMP());

/* Sagrad Inc. [high] Sagrad Inc 总部美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001819, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* TALLYSMAN [high] Tallysman Wireless 总部加拿大渥太华 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001820, 'CA', 0, 'overseas', CURRENT_TIMESTAMP());

/* Techship [high] Techship 总部瑞典 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001821, 'SE', 0, 'overseas', CURRENT_TIMESTAMP());

/* Thermaltronics [high] Thermaltronics 总部美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001822, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Vizmonet [medium] Vizmonet 中国显示/支付终端品牌 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001823, 'CN', 1, 'mainland_native', CURRENT_TIMESTAMP());

/* Zero ASIC Corporation [high] Zero ASIC Corporation 总部美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001824, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* McGill Microwave Systems [high] McGill Microwave Systems 总部英国苏格兰 Kirkcaldy */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001825, 'GB', 0, 'overseas', CURRENT_TIMESTAMP());

/* SOURCE [high] Source Photonics 总部美国加州 West Hills */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001826, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Leader Tech Inc. [high] Leader Tech Inc 总部美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001827, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Vox Power Ltd. [high] Vox Power Ltd 总部英国/爱尔兰 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001828, 'GB', 0, 'overseas', CURRENT_TIMESTAMP());

/* Gedore Tools, Inc. [high] Gedore 母公司总部德国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001829, 'DE', 0, 'overseas', CURRENT_TIMESTAMP());

/* Apex Tool Group [high] Apex Tool Group 总部美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001830, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* GAPTEC Electronic [high] GAPTEC Electronic GmbH 总部德国 Langen */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001831, 'DE', 0, 'overseas', CURRENT_TIMESTAMP());

/* EMCORE [high] EMCORE Corporation 总部美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001832, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* CDI-DIODE [high] CDI (Compensated Devices) 历史总部美国马萨诸塞 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001842, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* FCI-CONNECTOR [high] FCI (Amphenol FCI) 起源总部法国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001843, 'FR', 0, 'overseas', CURRENT_TIMESTAMP());

/* MicroPower Direct [high] MicroPower Direct 总部美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001844, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Mallory Sonalert Products Inc. [high] Mallory Sonalert 总部美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001845, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Wakefield Thermal Solutions [high] Wakefield Thermal Solutions 总部美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001846, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* NMB Technologies Corporation [high] NMB Technologies (NMB) 母公司总部日本 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001847, 'JP', 0, 'overseas', CURRENT_TIMESTAMP());

/* Magnetics, a division of Spang & Co. [high] Magnetics (Spang) 总部美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001848, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* TECCOR [high] TECCOR (Littelfuse) 总部美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001849, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* t-Global Technology [high] T-Global Technology 总部台湾桃园 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001850, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* YAMAICHI [high] YAMAICHI ELECTRONICS 总部日本 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001851, 'JP', 0, 'overseas', CURRENT_TIMESTAMP());

/* Acopian Power Supplies [high] Acopian Power Supplies 总部美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001852, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* SEME-LAB [high] Semelab (TT Electronics) 品牌总部英国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001853, 'GB', 0, 'overseas', CURRENT_TIMESTAMP());

/* Wera Tools NA Inc. [high] Wera 母公司总部德国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001854, 'DE', 0, 'overseas', CURRENT_TIMESTAMP());

/* PEAK [high] PEAK electronics GmbH 总部德国 Nackenheim */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001855, 'DE', 0, 'overseas', CURRENT_TIMESTAMP());

/* WON-TOP [high] Won-Top Electronics 总部台湾高雄 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001856, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* Rittal [high] Rittal 总部德国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001858, 'DE', 0, 'overseas', CURRENT_TIMESTAMP());

/* BCDSEMI [high] BCD Semiconductor 历史总部中国上海 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001859, 'CN', 1, 'mainland_native', CURRENT_TIMESTAMP());

/* Cal Test Electronics [high] Cal Test Electronics 总部美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001860, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Mechatronics Fan Group [high] Mechatronics Fan Group 总部美国华盛顿州 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001862, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Murrplastik Systems, Inc. [high] Murrplastik 母公司总部德国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001863, 'DE', 0, 'overseas', CURRENT_TIMESTAMP());

/* AEROFLEX [high] Aeroflex 历史总部美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001864, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* CRYSTEKMICROWAVE [high] Crystek Corporation 总部美国佛罗里达 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001865, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* MOSAIC [high] Dongguan Mosaic Electronics 总部中国东莞 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001866, 'CN', 1, 'mainland_native', CURRENT_TIMESTAMP());

/* SYNSEMI [high] SynSemi 企业总部美国硅谷 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001867, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Daburn Electronics [high] Daburn Electronics 总部美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001868, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* QIMONDA [high] Qimonda AG 历史总部德国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001869, 'DE', 0, 'overseas', CURRENT_TIMESTAMP());

/* EON [medium] EON 美国电子/电源品牌 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001870, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Transforming Technologies [high] Transforming Technologies 总部美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001871, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Navitas Semiconductor, Inc. [high] Navitas Semiconductor 总部爱尔兰都柏林 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001872, 'IE', 0, 'overseas', CURRENT_TIMESTAMP());

/* Tark Thermal Solutions [high] Tark Thermal Solutions 总部美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001873, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Visual Communications Company - VCC [high] Visual Communications Company (VCC) 总部美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001874, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Knipex Tools LP [high] Knipex 母公司总部德国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001875, 'DE', 0, 'overseas', CURRENT_TIMESTAMP());

/* O.C. White Co. [high] O.C. White Co 总部美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001876, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* MDE Semiconductor Inc [high] MDE Semiconductor Inc 总部美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001877, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Altran Magnetics, LLC [high] Altran Magnetics LLC 总部美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001878, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* ElectronAix [high] ElectronAix GmbH 总部德国亚琛 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001879, 'DE', 0, 'overseas', CURRENT_TIMESTAMP());

/* Integra Enclosures [high] Integra Enclosures 总部美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001880, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* NEL [high] NEL Frequency Controls 总部美国威斯康星 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001881, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Masach Tech Ltd. [high] 官网 masach.com 总部以色列 Modi'in */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001882, 'IL', 0, 'overseas', CURRENT_TIMESTAMP());

/* GULFSEMI [high] Gulf Semiconductor 官网/HKTDC 总部香港 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001884, 'HK', 1, 'hk_mo', CURRENT_TIMESTAMP());

/* AMCC [high] Applied Micro Circuits Corp 总部美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001885, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* EDI [high] Electronic Devices Inc (EDI) 总部纽约 Yonkers */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001886, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Cicoil [high] Cicoil 总部加州 Chatsworth */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001887, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Visaton GmbH & Co. KG [high] Visaton GmbH 德国扬声器制造商 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001889, 'DE', 0, 'overseas', CURRENT_TIMESTAMP());

/* Aven Tools [high] Aven Tools 美国工具制造商 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001890, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* PCE Instruments [high] PCE Instruments 德国 PCE Deutschland */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001891, 'DE', 0, 'overseas', CURRENT_TIMESTAMP());

/* New Energy [medium] New Energy 深圳新能源电子元件厂 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001892, 'CN', 1, 'mainland_native', CURRENT_TIMESTAMP());

/* Shiu Li Technology Co., Ltd. [high] 旭立科技 LiPOLY 总部桃园 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001893, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* BL Galaxy Electrical [high] 常州银河微电子 Changzhou Galaxy/BL Galaxy */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001894, 'CN', 1, 'mainland_native', CURRENT_TIMESTAMP());

/* Holy Stone Enterprise Co., Ltd. [high] 禾伸堂 Holy Stone 总部台北内湖 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001895, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* Pimoroni Ltd [high] Pimoroni Ltd 英国 Sheffield */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001896, 'GB', 0, 'overseas', CURRENT_TIMESTAMP());

/* Rennsteig Tools, Inc. [high] Rennsteig Tools Inc 母公司 Rennsteig 德国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001898, 'DE', 0, 'overseas', CURRENT_TIMESTAMP());

/* TOTAL-POWER [high] Total Power International 总部 Lowell MA */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001899, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Jensen Global Inc. [high] Jensen Global Inc 美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001900, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* ChromeLED [medium] ChromeLED 台湾 LED 元件商 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001901, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* DATAFORTH [high] DATAFORTH 总部亚利桑那 Tucson */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001902, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* 2J Antennas [high] 2J Antennas s.r.o. 斯洛伐克 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001903, 'SK', 0, 'overseas', CURRENT_TIMESTAMP());

/* Tri-Mag, LLC [high] Tri-Mag LLC 美国磁铁制造商 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001904, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* INTERFET [high] INTERFET 美国 FET 制造商 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001905, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* M5Stack Technology Co., Ltd. [high] M5Stack 总部深圳宝安 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001906, 'CN', 1, 'mainland_native', CURRENT_TIMESTAMP());

/* Zaber Technologies [high] Zaber Technologies 总部加拿大 Vancouver */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001907, 'CA', 0, 'overseas', CURRENT_TIMESTAMP());

/* P-TEC [medium] P-TEC 美国电子元件分销商 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001908, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* CHENG-YI [medium] 正一電機 CHENG-YI 台湾 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001909, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* CTS Thermal Management Products [high] CTS Corporation 热管理 总部美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001910, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* DCCOM [high] DC Components (DCCOM) 总部台中 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001911, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* Teledyne FLIR Commercial Systems [high] Teledyne FLIR 母公司 Teledyne 美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001912, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* ERP Power, LLC [high] ERP Power LLC 美国电源 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001913, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Excelta Corporation [high] Excelta Corporation 美国精密工具 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001914, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* PREDIP [high] PRECI-DIP SA 总部瑞士 Delémont */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001915, 'CH', 0, 'overseas', CURRENT_TIMESTAMP());

/* Aces Connectors [medium] Aces Connectors 美国连接器 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001916, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Eclipse Magnetics Ltd [high] Eclipse Magnetics Ltd 英国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001917, 'GB', 0, 'overseas', CURRENT_TIMESTAMP());

/* COMSET [high] Comset Semiconductor 总部布鲁塞尔 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001918, 'BE', 0, 'overseas', CURRENT_TIMESTAMP());

/* R-K Electronics, Inc. [high] R-K Electronics Inc 美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001919, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* DAICO [high] DAICO 日本电子元件 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001920, 'JP', 0, 'overseas', CURRENT_TIMESTAMP());

/* Intematix Corporation [high] Intematix 总部加州 Fremont */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001921, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Tycon Systems Inc. [high] Tycon Systems Inc 美国 PoE 设备 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001922, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Ferrite International [medium] Ferrite International 美国铁氧体 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001923, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Multi-Tech Systems Inc. [high] Multi-Tech Systems 总部明尼苏达 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001924, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Marlow Industries, Inc. [high] Marlow Industries 总部德州 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001926, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* SYNC-POWER [high] 擎力科技 SYNC-POWER 总部台北南港 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001927, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* Aearo Technologies LLC, a 3M company [high] Aearo Technologies 3M 子公司 美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001928, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Anatech Electronics Inc. [high] Anatech Electronics 美国滤波器 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001929, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* SRA Soldering Products [high] SRA Soldering Products 美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001930, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Excel Blades [high] Excel Blades 美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001931, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Advanced Fiber Resources [high] Advanced Fiber Resources 福州光通讯 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001932, 'CN', 1, 'mainland_native', CURRENT_TIMESTAMP());

/* FEIG Electronic [high] FEIG Electronic 德国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001933, 'DE', 0, 'overseas', CURRENT_TIMESTAMP());

/* FreeWave Technologies [high] FreeWave Technologies 总部科罗拉多 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001934, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* VIITOR SEMICONDUCTOR CO., LTD [high] 微特半导体 Viitor 总部新北新店 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001935, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* TTM Technologies, Inc. [high] TTM Technologies 总部美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001936, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Linear Integrated Systems, Inc. [high] Linear Integrated Systems 加州 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001938, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* VOLGEN [high] VOLGEN 美国电源 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001939, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* PIC GmbH [high] PIC GmbH 德国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001940, 'DE', 0, 'overseas', CURRENT_TIMESTAMP());

/* Kester Solder [high] Kester Solder 美国焊接材料 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001941, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Soldered Electronics [medium] Soldered Electronics 英国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001943, 'GB', 0, 'overseas', CURRENT_TIMESTAMP());

/* Benedict GmbH [high] Benedict GmbH 德国精密工具 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001944, 'DE', 0, 'overseas', CURRENT_TIMESTAMP());

/* Nemco [medium] Nemco Electronics 美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001946, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Ruffy Controls Inc. [high] Ruffy Controls Inc 美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001947, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Hatch Lighting [high] Hatch Lighting 美国照明 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001949, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Oslo Switch [medium] Oslo Switch 美国开关 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001950, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* FSP Technology Inc. [high] 全汉 FSP Technology 总部台北 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001951, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* Volgen + Furuno [medium] Volgen+Furuno 复合标; Volgen 美国为主 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001952, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* ADVANCEDPHOTONIX [high] Advanced Photonix 总部密歇根 Ann Arbor */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001953, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Industrial Fiber Optics [high] Industrial Fiber Optics 美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001954, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* JKL Components Corp. [high] JKL Components Corp 美国 LED */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001955, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* ATC-Diversified Electronics [high] ATC-Diversified Electronics 美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001956, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Joymax Electronics [medium] Joymax Electronics 台湾 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001957, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* Coolgear [high] Coolgear 美国 USB 设备 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001959, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Lilliput Electronics [medium] Lilliput Electronics 香港利普 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001960, 'HK', 1, 'hk_mo', CURRENT_TIMESTAMP());

/* Antenova [high] Antenova 英国天线 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001961, 'GB', 0, 'overseas', CURRENT_TIMESTAMP());

/* Formerica Optoelectronics Inc. [high] Formerica 母公司台湾光联 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001962, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* IMPALA [medium] Impala Linear 美国半导体(现 Fairchild) */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001963, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Tri-Star Industries, Inc. [high] Tri-Star Industries 美国连接器 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001965, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Roth Elektronik [high] Roth Elektronik Würth 德国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001966, 'DE', 0, 'overseas', CURRENT_TIMESTAMP());

/* Mechanical Products [high] Mechanical Products 美国断路器 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001968, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* JC Antenna [medium] JC Antenna 台湾天线 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001969, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* FLIR Integrated Imaging Solutions, Inc. [high] Teledyne FLIR IIS 母公司 Teledyne 美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001970, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* GHI Electronics, LLC [high] GHI Electronics 美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001971, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Industrial Shields [high] Industrial Shields 西班牙 PLC */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001972, 'ES', 0, 'overseas', CURRENT_TIMESTAMP());

/* Chip Shine / CSRF [medium] Chip Shine/CSRF 中国大陆半导体分销 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001973, 'CN', 1, 'mainland_native', CURRENT_TIMESTAMP());

/* Twin Industries [high] Twin Industries 美国原型板 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001974, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* The Antenna Company [high] The Antenna Company 荷兰 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001975, 'NL', 0, 'overseas', CURRENT_TIMESTAMP());

/* TinyCircuits [high] TinyCircuits 美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001976, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* HVM Technology, Inc. [high] HVM Technology 美国高压器件 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001977, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* ARCH Electronics Corp [high] ARCH Electronics Corp 美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001978, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Global Specialties [high] Global Specialties 美国实验设备 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001979, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* EM Microelectronic [high] EM Microelectronic 瑞士 Swatch Group */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001981, 'CH', 0, 'overseas', CURRENT_TIMESTAMP());

/* Avondale Innovative Products LLC [high] Avondale Innovative Products 美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001982, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* BusBoard Prototype Systems [high] BusBoard Prototype Systems 美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001983, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Bantam Tools [high] Bantam Tools 美国(原 Other Machine) */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001984, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Plazmo Industries [medium] Plazmo Industries 美国显示 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001985, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Gaia Converter [high] Gaia Converter 法国电源模块 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001986, 'FR', 0, 'overseas', CURRENT_TIMESTAMP());

/* Modular Cable Assemblies [high] Modular Cable Assemblies 美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001988, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Prosperity Dielectrics Co. Ltd [high] 华新科 PDC Prosperity Dielectrics 台湾 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001989, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* TT Electronics/Power Partners Inc. [high] TT Electronics 母公司英国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001990, 'GB', 0, 'overseas', CURRENT_TIMESTAMP());

/* Suzhou Maswell Communication Technology Co. Ltd [high] 苏州 Maswell 通信科技 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001992, 'CN', 1, 'mainland_native', CURRENT_TIMESTAMP());

/* Songtian Electronic Technology [medium] 松田/颂天 Songtian 中国电子 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001993, 'CN', 1, 'mainland_native', CURRENT_TIMESTAMP());

/* Auer Signal [high] Auer Signal 奥地利信号设备 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001994, 'AT', 0, 'overseas', CURRENT_TIMESTAMP());

/* Verotronic Technologies Pte Ltd. [high] Verotronic Technologies 新加坡 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001995, 'SG', 0, 'overseas', CURRENT_TIMESTAMP());

/* Malico Inc. [high] Malico 美隆电子 总部台湾 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001996, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* ATOP Technologies [high] 亚拓 ATOP Technologies 台湾工业网络 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001997, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* Segger Microcontroller Systems [high] SEGGER 总部德国 Monheim am Rhein */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001999, 'DE', 0, 'overseas', CURRENT_TIMESTAMP());

/* SB Components Ltd [high] SB Components Ltd 英国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002001, 'GB', 0, 'overseas', CURRENT_TIMESTAMP());

/* SCHUNK Intec Inc. [high] SCHUNK Intec 母公司 SCHUNK 德国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002002, 'DE', 0, 'overseas', CURRENT_TIMESTAMP());

/* Unictron Technologies Corporation [high] Unictron 咏业科技 总部台湾 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002003, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* Yenyo Technology [medium] Yenyo Technology 台湾 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002004, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* GLF Integrated Power [high] GLF Integrated Power 美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002005, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Inventus Power [high] Inventus Power 美国电池 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002006, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Telit Cinterion [high] Telit Cinterion 总部 Boca Raton FL */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002007, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* AMEC Thermasol [high] AMEC Thermasol 美国蒸汽浴 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002008, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Challenge Electronics [high] Challenge Electronics 美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002009, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* SEMIPOWER [high] 芯派科技 Semipower 总部西安 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002010, 'CN', 1, 'mainland_native', CURRENT_TIMESTAMP());

/* EXCELICS [high] Excelics Semiconductor 加州 Sunnyvale */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002011, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* MED [medium] MED Associates 美国医疗电子 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002012, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Pro-face [high] Pro-face 母公司 Digital 日本 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002014, 'JP', 0, 'overseas', CURRENT_TIMESTAMP());

/* Noren Thermal Solutions [high] Noren Thermal Solutions 美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002015, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Numato Lab [high] Numato Lab 美国/印度裔创立 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002016, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Gelid Solutions LLC [high] Gelid Solutions 香港散热 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002017, 'HK', 1, 'hk_mo', CURRENT_TIMESTAMP());

/* Magic Power [medium] Magic Power 台湾电源 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002018, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* Fabco-Air Inc. [high] Fabco-Air 美国气动 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002019, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Ideal Power Ltd. [high] Ideal Power 英国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002020, 'GB', 0, 'overseas', CURRENT_TIMESTAMP());

/* MDTIC [medium] MDTIC 台湾分立器件 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002021, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* OSA [high] OSA Opto Light 总部柏林 现 EPIGAP OSA */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002022, 'DE', 0, 'overseas', CURRENT_TIMESTAMP());

/* Pelonis Technologies [high] Pelonis Technologies 美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002023, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Spectra Symbol [high] Spectra Symbol 美国传感器 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002024, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* CalRamic Technologies LLC [high] CalRamic Technologies 美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002025, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Analog Power Inc. [high] Analog Power Inc 美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002026, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Toward Technologies, Inc. [high] 拓能 Toward Technologies 台湾 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002027, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* Penchem Technologies Sdn Bhd [high] Penchem Technologies 马来西亚 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002028, 'MY', 0, 'overseas', CURRENT_TIMESTAMP());

/* RadioControlli [high] RadioControlli 意大利 RF */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002029, 'IT', 0, 'overseas', CURRENT_TIMESTAMP());

/* XSSY Optoelectronics Co.,Ltd. [high] XSSY 深圳光电器件 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002030, 'CN', 1, 'mainland_native', CURRENT_TIMESTAMP());

/* Judco Manufacturing Inc. [high] Judco Manufacturing 美国开关 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002031, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Mechatronics Bearing Group [high] Mechatronics Bearing Group 美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002032, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* RADIOMETRIX [high] Radiometrix 英国 RF 模块 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002033, 'GB', 0, 'overseas', CURRENT_TIMESTAMP());

/* Sanan Power Semiconductor [high] 三安 Sanan Power Semiconductor 中国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002034, 'CN', 1, 'mainland_native', CURRENT_TIMESTAMP());

/* SAMES [high] SAMES 法国静电设备 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002035, 'FR', 0, 'overseas', CURRENT_TIMESTAMP());

/* ADSANTEC [medium] ADSANTEC 日本高速 ADC */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002036, 'JP', 0, 'overseas', CURRENT_TIMESTAMP());

/* Equinox Technologies [high] Equinox Technologies 美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002037, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* NUVOTEM TALEMA [high] Nuvotem Talema 总部英国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002038, 'GB', 0, 'overseas', CURRENT_TIMESTAMP());

/* Radial Magnets, Inc. [high] Radial Magnets Inc 美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002039, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* BFirst Industrial [medium] BFirst Industrial 中国工业元件 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002040, 'CN', 1, 'mainland_native', CURRENT_TIMESTAMP());

/* Basler Inc. [high] Basler Inc 母公司 Basler AG 德国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002041, 'DE', 0, 'overseas', CURRENT_TIMESTAMP());

/* Future Designs Inc. [high] Future Designs Inc 美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002042, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* MGCHIP [medium] MGCHIP 中国芯片分销/封装品牌 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002043, 'CN', 1, 'mainland_native', CURRENT_TIMESTAMP());

/* Snaptron [high] Snaptron 美国金属弹片 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002044, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Softlog Systems [high] Softlog Systems 总部以色列 Or Yehuda */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002045, 'IL', 0, 'overseas', CURRENT_TIMESTAMP());

/* Actuonix Motion Devices Inc [high] Actuonix Motion Devices 加拿大 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002046, 'CA', 0, 'overseas', CURRENT_TIMESTAMP());

/* Acute Technology, Inc. [high] Acute Technology 台湾逻辑分析仪 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002047, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* Diamond Systems [high] Diamond Systems 美国嵌入式 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002048, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Digital Six Labs [high] Digital Six Labs 美国无线 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002049, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* IAR Systems Software Inc. [high] IAR Systems 母公司瑞典 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002050, 'SE', 0, 'overseas', CURRENT_TIMESTAMP());

/* Artekit Labs [high] Artekit Labs 意大利 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002051, 'IT', 0, 'overseas', CURRENT_TIMESTAMP());

/* fastSiC [high] fastSiC 即思创意 总部新竹 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002052, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* Owon Technology Lilliput Electronics [high] Owon/利普特 中国示波器 漳州 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002053, 'CN', 1, 'mainland_native', CURRENT_TIMESTAMP());

/* Shenzhen ADTEK Technology Co., Ltd [high] 深圳 ADTEK 爱德泰 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002054, 'CN', 1, 'mainland_native', CURRENT_TIMESTAMP());

/* Sper Scientific [high] Sper Scientific 美国仪器 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002055, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* GWINSTEK [high] 固纬 GWINSTEK 总部台湾 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002056, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* INTERPION [high] INTERPION 韩国 INTERPION */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002057, 'KR', 0, 'overseas', CURRENT_TIMESTAMP());

/* Sfera Labs [high] Sfera Labs 意大利 IoT */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002058, 'IT', 0, 'overseas', CURRENT_TIMESTAMP());

/* Digital View Inc. [high] Digital View 美国显示控制器 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002060, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Interlink Electronics [high] Interlink Electronics 美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002061, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Kunbus GmbH [high] Kunbus GmbH 德国工业 PC */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002062, 'DE', 0, 'overseas', CURRENT_TIMESTAMP());

/* Maswell Communication Tech. [high] Maswell 苏州通信(同 9001992 系) */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002064, 'CN', 1, 'mainland_native', CURRENT_TIMESTAMP());

/* Techflex [high] Techflex 美国线缆保护 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002065, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* PicoLAS GmbH [high] PicoLAS GmbH 德国激光驱动 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002067, 'DE', 0, 'overseas', CURRENT_TIMESTAMP());

/* Storm Interface [high] Storm Interface 英国 HMI */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002068, 'GB', 0, 'overseas', CURRENT_TIMESTAMP());

/* DB Products [medium] DB Products 美国连接器 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002069, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* EXCELSEMI [high] EXCELSEMI 优先苏州半导体 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002070, 'CN', 1, 'mainland_native', CURRENT_TIMESTAMP());

/* AIC tech Inc. [high] AIC tech 台湾工业电脑 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002072, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* AK-Nord GmbH [high] AK-Nord GmbH 德国线缆 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002073, 'DE', 0, 'overseas', CURRENT_TIMESTAMP());

/* Applied Kilovolts Ltd. [high] Applied Kilovolts 英国高压 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002074, 'GB', 0, 'overseas', CURRENT_TIMESTAMP());

/* Eccel Technology Limited [high] Eccel Technology 英国 RFID */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002075, 'GB', 0, 'overseas', CURRENT_TIMESTAMP());

/* Finecables [high] Finecables 英国线缆 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002076, 'GB', 0, 'overseas', CURRENT_TIMESTAMP());

/* Camemake [high] Camemake 母公司 Motoshot 香港 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002077, 'HK', 1, 'hk_mo', CURRENT_TIMESTAMP());

/* Peak Electronic Design Limited [high] Peak Electronic Design 英国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002078, 'GB', 0, 'overseas', CURRENT_TIMESTAMP());

/* Reed Semiconductor Corp. [medium] Reed Semiconductor 美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002079, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* TAEJIN [high] TAEJIN 韩国太进 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002080, 'KR', 0, 'overseas', CURRENT_TIMESTAMP());

/* Component Basics [medium] Component Basics 美国分销 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002081, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Lin Engineering [high] Lin Engineering 美国步进电机 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002082, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* SITRONIX [high] 矽创 Sitronix 总部新竹竹北 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002083, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* US Electronics Inc. [high] US Electronics Inc 美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002084, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Lighting Science Group Corporation [high] Lighting Science Group 美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002085, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* EMO Systems Inc [high] EMO Systems 德国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002086, 'DE', 0, 'overseas', CURRENT_TIMESTAMP());

/* Inventek Systems [high] Inventek Systems 美国 WiFi 模块 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002087, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Maanshan New Conda Magnetic Industrial Co.,Ltd. [high] 马鞍山新康达磁业 中国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002088, 'CN', 1, 'mainland_native', CURRENT_TIMESTAMP());

/* Opto Diode Corp [high] Opto Diode Corp 美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002089, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Red Pitaya d.d. [high] Red Pitaya 斯洛文尼亚 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002090, 'SI', 0, 'overseas', CURRENT_TIMESTAMP());

/* Sprague-Goodman [high] Sprague-Goodman 美国可变电容 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002091, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* USound GmbH [high] USound GmbH 奥地利微扬声器 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002092, 'AT', 0, 'overseas', CURRENT_TIMESTAMP());

/* Amstat Industries, Inc. [high] Amstat Industries 美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002094, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* JM Concept [high] JM Concept 法国工业仪表 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002095, 'FR', 0, 'overseas', CURRENT_TIMESTAMP());

/* Linear Systems [high] Linear Systems 美国 JFET */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002096, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Unified-E [high] Unified-E 德国工业自动化 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002097, 'DE', 0, 'overseas', CURRENT_TIMESTAMP());

/* Ziitek Technology [high] 兆科 Ziitek 总部东莞 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002098, 'CN', 1, 'mainland_native', CURRENT_TIMESTAMP());

/* Insignis Technology Corporation [medium] Insignis Technology 台湾 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002099, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* Tag-Connect LLC [high] Tag-Connect 美国调试连接器 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002100, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* ThingMagic, a JADAK brand [high] ThingMagic/JADAK 母公司 Novanta 美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002101, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* UKB Electronics Ltd [high] UKB Electronics Ltd 英国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002102, 'GB', 0, 'overseas', CURRENT_TIMESTAMP());

/* Copper Mountain Technologies [high] Copper Mountain Technologies 美国 VNA */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002103, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Enclustra FPGA Solutions [high] 官网/LinkedIn: Enclustra GmbH 总部苏黎世 CH-8045 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002104, 'CH', 0, 'overseas', CURRENT_TIMESTAMP());

/* Watterott Electronic GmbH [high] 法律后缀 GmbH; Watterott Electronic 德国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002105, 'DE', 0, 'overseas', CURRENT_TIMESTAMP());

/* DACO Semiconductor [medium] DACO Semiconductor 美国模拟半导体厂商 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002106, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Dycotec Materials Ltd [high] Ltd + Dycotec Materials 英国 Witney 纳米材料 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002107, 'GB', 0, 'overseas', CURRENT_TIMESTAMP());

/* Practical Instrument Electronics [high] PIE (Practical Instrument Electronics) 总部 Chester CT */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002108, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Thermoelectric Conversion Systems Ltd [high] Ltd + Thermoelectric Conversion Systems 英国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002109, 'GB', 0, 'overseas', CURRENT_TIMESTAMP());

/* Amulet Technologies LLC [high] LLC + Amulet Technologies 总部 San Jose CA */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002110, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* emcfixSHOP [high] 官网 emcfixshop.co.uk 英国 EMC 配件商 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002111, 'GB', 0, 'overseas', CURRENT_TIMESTAMP());

/* Meerstetter [high] 官网 meerstetter.ch: Rubigen 瑞士总部 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002112, 'CH', 0, 'overseas', CURRENT_TIMESTAMP());

/* Power Sonic Corporation [high] Power Sonic Corporation 总部 Bloomfield CT */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002113, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Acconeer AB [high] 法律后缀 AB; Acconeer 瑞典 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002114, 'SE', 0, 'overseas', CURRENT_TIMESTAMP());

/* Crystal IS [high] Crystal IS (Asahi Kasei) 总部 Green Island NY */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002115, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* HEADWAY TRADING CO., LTD. [high] 官网 hdw.com.tw: HEADWAY TRADING 高雄总部 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002116, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* Radiocrafts AS [high] 法律后缀 AS; Radiocrafts 挪威 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002117, 'NO', 0, 'overseas', CURRENT_TIMESTAMP());

/* Rubis Tech [high] Rubis Tech = Outils Rubis SA 瑞士 Stabio 精密镊子 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002118, 'CH', 0, 'overseas', CURRENT_TIMESTAMP());

/* AideTek [high] AideTek = Syncont Inc 总部 Monrovia CA */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002119, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Beanair Sensors [high] BeanAir GmbH 总部柏林德国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002120, 'DE', 0, 'overseas', CURRENT_TIMESTAMP());

/* ITECH ELECTRONIC CO.,LTD. [high] ITECH Electronic 总部南京江苏; 外资台港澳投资企业 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002121, 'CN', 1, 'mainland_native', CURRENT_TIMESTAMP());

/* PRIMO COMPANY LIMITED [medium] PRIMO COMPANY LIMITED 香港电子贸易公司 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002122, 'HK', 1, 'hk_mo', CURRENT_TIMESTAMP());

/* Boyd Woburn [high] Boyd Woburn = Boyd Corp 热管理分部 Woburn MA */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002123, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* LIMITLESS SHIELDING LIMITED [high] LIMITLESS SHIELDING LIMITED 英国 EMI 屏蔽 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002124, 'GB', 0, 'overseas', CURRENT_TIMESTAMP());

/* Smarts Electronic & Technology [high] 官网 smarts-electronics.com: 泉州斯玛特电子 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002125, 'CN', 1, 'mainland_native', CURRENT_TIMESTAMP());

/* System-On-Chip [high] System-On-Chip = SoC-e S.L. 总部毕尔巴鄂西班牙 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002126, 'ES', 0, 'overseas', CURRENT_TIMESTAMP());

/* Atom Adhesives [medium] Atom Adhesives 美国环氧胶粘剂 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002127, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* FRIWO Gerätebau GmbH [high] FRIWO Gerätebau GmbH 德国电源 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002128, 'DE', 0, 'overseas', CURRENT_TIMESTAMP());

/* MECHATRONICS [medium] Mechatronics Inc 美国传感器/操纵杆 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002129, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Silanna Semiconductor [high] Silanna Semiconductor 半导体分部总部 San Diego CA */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002130, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Duracell Industrial Operations, Inc. [high] Duracell Industrial Operations Inc 美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002131, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Fanstel Corp. [high] Fanstel Corp 总部 San Diego 蓝牙模块 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002132, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* IET [high] IET Labs 总部 West Brooklyn NY 精密电阻 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002133, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Quatech-Division of B&B Electronics [high] Quatech 原 Ohio 串口卡; B&B Electronics 美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002134, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* TTM Technologies Trading [high] TTM Technologies 总部 Costa Mesa CA PCB */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002135, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Upside Down Labs [high] Upside Down Labs 印度开源硬件 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002136, 'IN', 0, 'overseas', CURRENT_TIMESTAMP());

/* ACCES I/O Products, Inc. [high] ACCES I/O Products Inc 总部 San Diego */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002137, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* IRI [medium] IRI PowerGen File 美国硅胶灌封材料 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002138, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Particle Industries, Inc. [high] Particle Industries = particle.io 总部 San Francisco */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002139, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Performance Motion Devices, Inc. [high] Performance Motion Devices Inc 总部 Vermont */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002140, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Anatech Microwave Company [high] Anatech Microwave Company 美国 NJ */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002142, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* AnDAPT, Inc. [high] AnDAPT Inc 总部 San Jose 自适应电源 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002143, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Camelion [high] Camelion Battery 深圳飞狮电池总部深圳 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002144, 'CN', 1, 'mainland_native', CURRENT_TIMESTAMP());

/* Connective Peripherals Pte Ltd [high] Pte Ltd; Connective Peripherals 新加坡 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002145, 'SG', 0, 'overseas', CURRENT_TIMESTAMP());

/* E2IP Technologies Inc. [high] E2IP Technologies Inc 总部 Montreal 加拿大 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002146, 'CA', 0, 'overseas', CURRENT_TIMESTAMP());

/* Flexco Microwave [medium] Flexco Microwave Inc 美国微波 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002147, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Mobile Mark Antenna Solutions [high] Mobile Mark Antenna Solutions 总部 Illinois */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002148, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Patco Electronics [medium] Patco Electronics 美国电子 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002149, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Pi-Top [high] Pi-Top 总部伦敦英国教育硬件 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002150, 'GB', 0, 'overseas', CURRENT_TIMESTAMP());

/* Superxon [medium] Superxon 深圳光学/LED 品牌 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002151, 'CN', 1, 'mainland_native', CURRENT_TIMESTAMP());

/* Vesper Technologies Inc. [high] Vesper Technologies Inc 总部 Boston MEMS 麦克风 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002152, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Alorium Technology, LLC [high] Alorium Technology LLC 总部 Minneapolis FPGA */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002153, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Computer Components Inc [medium] Computer Components Inc 美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002154, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Image Quality Labs, Inc. [medium] Image Quality Labs Inc 美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002155, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Matrix Industries, Inc. [high] Matrix Industries Inc 美国热电穿戴 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002156, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* NexAIoT CO., LTD. [high] NexAIoT = Nexcom 子公司 台湾 IoT */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002157, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* Taoglas - Public Safety [high] Taoglas 爱尔兰天线总部 Dublin */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002158, 'IE', 0, 'overseas', CURRENT_TIMESTAMP());

/* CH Products [high] CH Products 总部 California 工业操纵杆 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002159, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Dioo Microcircuits Co., Ltd. [high] Dioo Microcircuits 帝奥微 总部上海/中国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002160, 'CN', 1, 'mainland_native', CURRENT_TIMESTAMP());

/* GE Aerospace [high] GE Aerospace 总部美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002161, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Shenzhen Feasycom Co., LTD [high] 名称含 Shenzhen; Feasycom 深圳 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002162, 'CN', 1, 'mainland_native', CURRENT_TIMESTAMP());

/* CoreHW Semiconductor Ltd [high] CoreHW Semiconductor Ltd 芬兰 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002163, 'FI', 0, 'overseas', CURRENT_TIMESTAMP());

/* Cytron Technologies Sdn Bhd [high] Sdn Bhd; Cytron Technologies 马来西亚 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002164, 'MY', 0, 'overseas', CURRENT_TIMESTAMP());

/* I.O. Interconnect [high] I.O. Interconnect Inc 总部新北/台北 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002165, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* IAM Electronic [high] IAM Electronic GmbH 总部 Leipzig 德国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002166, 'DE', 0, 'overseas', CURRENT_TIMESTAMP());

/* RPM Systems Corp [medium] RPM Systems Corp 美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002167, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* SEQUENT MICROSYSTEMS [high] Sequent Microsystems 美国 Raspberry Pi 扩展板 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002168, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Top Shelf Acoustics, LLC [medium] Top Shelf Acoustics LLC 美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002169, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Astera Labs, Inc. [high] Astera Labs Inc 总部 Santa Clara */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002172, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Menlo Microsystems, Inc [high] Menlo Microsystems Inc 总部 Menlo Park CA */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002173, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Perle Systems [high] Perle Systems 总部 Toronto 加拿大 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002174, 'CA', 0, 'overseas', CURRENT_TIMESTAMP());

/* Saiko Systems Ltd. [medium] Saiko Systems Ltd 英国 SBC 方案 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002175, 'GB', 0, 'overseas', CURRENT_TIMESTAMP());

/* 3-5 Power Electronics GmbH [high] 3-5 Power Electronics GmbH 德国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002176, 'DE', 0, 'overseas', CURRENT_TIMESTAMP());

/* Aufmaster [high] 官网 aufmaster.com: Aufmaster GmbH 法兰克福 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002177, 'DE', 0, 'overseas', CURRENT_TIMESTAMP());

/* BiPOM Electronics, Inc. [high] BiPOM Electronics Inc 美国开发板 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002178, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Dresden Elektronik [high] Dresden Elektronik 德国德累斯顿 ZigBee */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002179, 'DE', 0, 'overseas', CURRENT_TIMESTAMP());

/* EBconnections [high] EBconnections = EBE Elektronik 德国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002180, 'DE', 0, 'overseas', CURRENT_TIMESTAMP());

/* FERYSTER [high] FERYSTER 波兰热敏电阻 Feryster */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002181, 'PL', 0, 'overseas', CURRENT_TIMESTAMP());

/* New Scale Technologies, Inc. [high] New Scale Technologies Inc 总部 Victor NY */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002182, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Sanyu Switch [high] Sanyu Switch 三友开关 日本 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002183, 'JP', 0, 'overseas', CURRENT_TIMESTAMP());

/* Xiamen Hualian Electronics Corp. Ltd. [high] 名称含 Xiamen; 厦门华联电子 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002184, 'CN', 1, 'mainland_native', CURRENT_TIMESTAMP());

/* ZEUS Battery Products [medium] ZEUS Battery Products 美国电池 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002185, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Antenom Antenna Technologies [medium] Antenom Antenna Technologies 土耳其天线 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002186, 'TR', 0, 'overseas', CURRENT_TIMESTAMP());

/* BECOM Systems GmbH [high] BECOM Systems GmbH 德国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002187, 'DE', 0, 'overseas', CURRENT_TIMESTAMP());

/* CTi Sensors [medium] CTi Sensors 美国传感器 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002188, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Deepwave Digital [high] Deepwave Digital 美国 RF AI */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002190, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Kyoto Semiconductor [high] Kyoto Semiconductor 京都半导体 日本 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002191, 'JP', 0, 'overseas', CURRENT_TIMESTAMP());

/* Lotus Microsystems [high] Lotus Microsystems 瑞士 MEMS */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002192, 'CH', 0, 'overseas', CURRENT_TIMESTAMP());

/* Quest Manufacturing Co. [medium] Quest Manufacturing Co 美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002193, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* ABCO [low] ABCO 美国电子通用名; 多同名公司 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002194, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Adamczewski Elektronische Messtechnik GmbH [high] Adamczewski Elektronische Messtechnik GmbH 德国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002195, 'DE', 0, 'overseas', CURRENT_TIMESTAMP());

/* GroundStudio [high] GroundStudio = ArduShop SRL 罗马尼亚 Sibiu */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002197, 'RO', 0, 'overseas', CURRENT_TIMESTAMP());

/* Hirst Magnetic Instruments Ltd [high] Hirst Magnetic Instruments Ltd 英国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002198, 'GB', 0, 'overseas', CURRENT_TIMESTAMP());

/* iDTRONIC [high] iDTRONIC 法国 RFID */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002200, 'FR', 0, 'overseas', CURRENT_TIMESTAMP());

/* KSM Electronics Inc. [medium] KSM Electronics Inc 美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002201, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Lindy International [high] Lindy International 德国线缆/AV Lindy */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002202, 'DE', 0, 'overseas', CURRENT_TIMESTAMP());

/* Okika Devices [high] Okika Devices 总部 Colorado Springs CO */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002203, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Seek Thermal [high] Seek Thermal 总部 Santa Barbara CA */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002204, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Silver Fox [medium] Silver Fox 美国线缆标识 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002205, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Boreas Technologies [high] Boreas Technologies 总部 Montreal 压电 MEMS */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002206, 'CA', 0, 'overseas', CURRENT_TIMESTAMP());

/* California Micro Devices [high] California Micro Devices 美国加州 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002207, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Cambridge GaN Devices [high] Cambridge GaN Devices 英国剑桥 GaN */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002208, 'GB', 0, 'overseas', CURRENT_TIMESTAMP());

/* Circuitco Electronics LLC [high] Circuitco Electronics LLC 德州 BeagleBone */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002209, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* DigiKey/Cree [high] DigiKey/Cree = Wolfspeed 美国半导体 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002210, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Kennedy Labs, a division of Hub Incorporated [medium] Kennedy Labs / Hub Inc 美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002211, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Kilo International [medium] Kilo International 美国连接器 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002212, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Quest Semi [medium] Quest Semi 美国半导体 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002213, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* RFbeam Microwave GmbH [high] RFbeam Microwave GmbH 总部 St. Gallen 瑞士 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002214, 'CH', 0, 'overseas', CURRENT_TIMESTAMP());

/* UEi Test Instruments [high] UEi Test Instruments 美国测试仪表 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002215, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* ARDUSIMPLE [high] ARDUSIMPLE 西班牙 GPS 模块 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002216, 'ES', 0, 'overseas', CURRENT_TIMESTAMP());

/* Control Products, Inc. [high] Control Products Inc 美国工业开关 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002218, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Electro Terminal GmbH & Co KG [high] Electro Terminal GmbH & Co KG 德国端子 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002219, 'DE', 0, 'overseas', CURRENT_TIMESTAMP());

/* Leapers Semiconductor Co.,Ltd [high] 无锡芯跃半导体 Leapers Semiconductor 总部无锡 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002220, 'CN', 1, 'mainland_native', CURRENT_TIMESTAMP());

/* Mixtile Limited [high] 官网 mixtile.com: 总部深圳福田 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002221, 'CN', 1, 'mainland_native', CURRENT_TIMESTAMP());

/* Pokit Innovations [high] Pokit Innovations 澳大利亚万用表 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002222, 'AU', 0, 'overseas', CURRENT_TIMESTAMP());

/* Siborg Systems Inc. [high] Siborg Systems Inc 加拿大 Waterloo */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002224, 'CA', 0, 'overseas', CURRENT_TIMESTAMP());

/* Sivers Semiconductor [high] Sivers Semiconductor 瑞典 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002225, 'SE', 0, 'overseas', CURRENT_TIMESTAMP());

/* TESSERA TECHNOLOGY [high] TESSERA TECHNOLOGY INC 横滨日本 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002226, 'JP', 0, 'overseas', CURRENT_TIMESTAMP());

/* ABB Electrification [high] ABB Electrification 母公司 ABB 总部苏黎世 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002227, 'CH', 0, 'overseas', CURRENT_TIMESTAMP());

/* ACT [medium] ACT = Advanced Cable Ties 美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002228, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Artaflex Inc. [medium] Artaflex Inc 加拿大 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002230, 'CA', 0, 'overseas', CURRENT_TIMESTAMP());

/* ElectronicMaster [low] ElectronicMaster 在线电子零售商 美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002231, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* ETS Alliance [medium] ETS Alliance 法国电子测试联盟 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002232, 'FR', 0, 'overseas', CURRENT_TIMESTAMP());

/* Hacksmith Tools [high] Hacksmith Tools 加拿大创客/YouTube */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002233, 'CA', 0, 'overseas', CURRENT_TIMESTAMP());

/* Helium Systems, Inc. [high] Helium Systems Inc 总部 San Francisco IoT */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002234, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Jorjin Technologies Inc. [high] Jorjin Technologies 佐臻 台湾 AR/VR */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002235, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* Lime Microsystems Ltd [high] Lime Microsystems Ltd 英国 SDR */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002236, 'GB', 0, 'overseas', CURRENT_TIMESTAMP());

/* Macraigor Systems LLC [high] Macraigor Systems LLC 美国 JTAG 调试 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002237, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* PicoBricks [high] PicoBricks 土耳其教育硬件 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002238, 'TR', 0, 'overseas', CURRENT_TIMESTAMP());

/* Powerland Technology, Inc. [high] Powerland Technology Inc 美国电源 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002239, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* ReVibe Energy AB [high] ReVibe Energy AB 瑞典能量采集 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002240, 'SE', 0, 'overseas', CURRENT_TIMESTAMP());

/* SOSHIN ELECTRIC CO., LTD. [high] SOSHIN ELECTRIC CO LTD 総進電子 日本 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002241, 'JP', 0, 'overseas', CURRENT_TIMESTAMP());

/* SPARK Microsystems International Inc. [high] SPARK Microsystems 总部 Montreal */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002242, 'CA', 0, 'overseas', CURRENT_TIMESTAMP());

/* Synaptics [high] Synaptics 总部 San Jose CA */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002243, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* TE Intercontec [high] TE Intercontec 德国连接器品牌 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002244, 'DE', 0, 'overseas', CURRENT_TIMESTAMP());

/* Thinxtra Solutions Limited [high] Thinxtra Solutions 澳大利亚 Sigfox */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002245, 'AU', 0, 'overseas', CURRENT_TIMESTAMP());

/* Able Systems Ltd [high] Able Systems Ltd 英国打印机 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002246, 'GB', 0, 'overseas', CURRENT_TIMESTAMP());

/* Cologne Chip [high] Cologne Chip 科隆德国 GateMate FPGA */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002249, 'DE', 0, 'overseas', CURRENT_TIMESTAMP());

/* Desco Industries, Inc, ESDSystems [high] Desco Industries / ESDSystems 美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002250, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Diamond Technologies Inc. [medium] Diamond Technologies Inc 美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002251, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Electric Imp Inc. [high] Electric Imp Inc 美国 IoT */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002252, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* EMA Design Automation [high] EMA Design Automation 总部 Rochester NY */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002253, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* FIDELIX [high] FIDELIX 韩国存储/显示驱动 IC */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002254, 'KR', 0, 'overseas', CURRENT_TIMESTAMP());

/* FlexiForce [high] FlexiForce = Tekscan 美国压力传感器 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002255, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Fremont Micro Devices Ltd [high] Fremont Micro Devices 富晶微电子 总部台湾 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002256, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* Fresnel Factory Inc. [high] Fresnel Factory Inc 总部水原韩国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002257, 'KR', 0, 'overseas', CURRENT_TIMESTAMP());

/* Gi Far technology Co., Ltd [medium] Gi Far technology 台湾电子 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002258, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* HDP Power [medium] HDP Power 美国电源 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002259, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Helix Semiconductors [high] Helix Semiconductors 美国 fabless */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002260, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Initial State Technologies, Inc. [high] Initial State Technologies Inc 美国 IoT */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002261, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Karakamlar Aerospace [high] Karakamlar Aerospace 土耳其航空电子 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002263, 'TR', 0, 'overseas', CURRENT_TIMESTAMP());

/* Mide Technology Corporation [high] Mide Technology Corporation 美国压电 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002264, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Octavo Systems LLC [high] Octavo Systems LLC 总部 Houston TX SIP */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002265, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Pocket VNA [high] Pocket VNA 官网 pocketvna.com 德国 Neubeuern */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002266, 'DE', 0, 'overseas', CURRENT_TIMESTAMP());

/* TAW ELECTRONICS, INC [medium] TAW ELECTRONICS INC 美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002267, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Winmate Communications US, Inc. [high] Winmate 台湾母公司; US Inc 为美国子公司 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002268, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* Wise-Integration [high] Wise-Integration 法国 GaN 电源 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002269, 'FR', 0, 'overseas', CURRENT_TIMESTAMP());

/* Adapteva Inc. [high] Adapteva Inc 美国并行计算 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002270, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Advance IR [medium] Advance IR 美国红外测温方案 advanceir.com */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002271, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Alicat Scientific [high] Alicat Scientific 总部 Arizona 质量流量 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002272, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Alliance Sensors Group [high] Alliance Sensors Group 总部 NJ 传感器 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002273, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Antimatter Research, Inc. [medium] Antimatter Research Inc 美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002275, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* BeagleBoard [high] BeagleBoard.org Foundation 美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002276, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Bend Labs, Inc. [high] Bend Labs Inc 总部 Utah 柔性传感器 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002277, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Brainchip [high] Brainchip 总部 Sydney 澳大利亚 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002278, 'AU', 0, 'overseas', CURRENT_TIMESTAMP());

/* Bynav Technology [high] Bynav Technology 上海北云科技 GNSS */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002279, 'CN', 1, 'mainland_native', CURRENT_TIMESTAMP());

/* BYNET TESTING SYSTEMS [medium] BYNET TESTING SYSTEMS 以色列测试系统 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002280, 'IL', 0, 'overseas', CURRENT_TIMESTAMP());

/* BYTe Semiconductor [high] BYTe Semiconductor 总部 San Jose CA */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002281, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Canaan Semiconductor Pty Ltd [medium] Canaan Semiconductor Pty Ltd 澳大利亚 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002282, 'AU', 0, 'overseas', CURRENT_TIMESTAMP());

/* Centron Technology Inc. [medium] Centron Technology Inc 美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002283, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Compass Instruments [medium] Compass Instruments 美国仪器 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002284, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* DEEPX [high] DEEPX 韩国 AI 芯片 首尔 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002285, 'KR', 0, 'overseas', CURRENT_TIMESTAMP());

/* DigiKey Evaluation Boards [high] DigiKey Evaluation Boards = DigiKey 美国分销商策展 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002286, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Dow-Key Microwave Corporation [high] Dow-Key Microwave Corporation 美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002287, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Electroverge [high] Electroverge 印度创客电子 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002288, 'IN', 0, 'overseas', CURRENT_TIMESTAMP());

/* Endeavor Consulting Group, LLC [medium] Endeavor Consulting Group LLC 美国咨询 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002289, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Energy Re-Connect Ltd. [high] Energy Re-Connect Ltd 英国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002290, 'GB', 0, 'overseas', CURRENT_TIMESTAMP());

/* enmo Technologies [high] enmo Technologies 德国 IoT */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002291, 'DE', 0, 'overseas', CURRENT_TIMESTAMP());

/* Fibox GmbH [high] Fibox Oy 总部芬兰; GmbH 为德国子公司 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002292, 'FI', 0, 'overseas', CURRENT_TIMESTAMP());

/* Ham Radio Workbench Podcast [high] Ham Radio Workbench Podcast 美国播客策展 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002293, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Imagetek Mfg inc [medium] Imagetek Mfg inc 美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002294, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Imperix [high] Imperix 瑞士电力电子 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002295, 'CH', 0, 'overseas', CURRENT_TIMESTAMP());

/* Integra Optics [high] Integra Optics 总部 New Hampshire 光纤 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002296, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Keywave Technology Limited [high] Keywave Technology 台湾无线模块 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002297, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* LECIP [high] LECIP レシップ 日本 LED/显示 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002298, 'JP', 0, 'overseas', CURRENT_TIMESTAMP());

/* LM Technologies [high] LM Technologies 英国蓝牙模块 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002299, 'GB', 0, 'overseas', CURRENT_TIMESTAMP());

/* Mag-LED Solutions [medium] Mag-LED Solutions 美国 LED */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002300, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* OptConnect Management, LLC [high] OptConnect Management LLC 美国蜂窝连接 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002301, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Piera Systems [high] Piera Systems 加拿大空气质量传感 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002302, 'CA', 0, 'overseas', CURRENT_TIMESTAMP());

/* Plusivo [high] Plusivo SRL 总部罗马尼亚 Ilfov */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002303, 'RO', 0, 'overseas', CURRENT_TIMESTAMP());

/* Point Labs [medium] Point Labs 美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002304, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Prodigy Technovations [high] Prodigy Technovations 印度班加罗尔协议分析仪 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002305, 'IN', 0, 'overseas', CURRENT_TIMESTAMP());

/* RHOPOINT [high] RHOPOINT 英国光泽度仪 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002306, 'GB', 0, 'overseas', CURRENT_TIMESTAMP());

/* SBG Systems [high] SBG Systems 法国 IMU/GNSS */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002307, 'FR', 0, 'overseas', CURRENT_TIMESTAMP());

/* Senther Technology [high] Senther Technology 土耳其传感器 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002308, 'TR', 0, 'overseas', CURRENT_TIMESTAMP());

/* SerialGear [medium] SerialGear 美国串口配件 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002309, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Shenzhen Creality 3D Technology Co., Ltd [high] 名称含 Shenzhen; Creality 创想三维 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002310, 'CN', 1, 'mainland_native', CURRENT_TIMESTAMP());

/* Signatrol Limited [high] Signatrol Limited 英国数据记录 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002311, 'GB', 0, 'overseas', CURRENT_TIMESTAMP());

/* Simplex Motion AB [high] Simplex Motion AB 瑞典 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002312, 'SE', 0, 'overseas', CURRENT_TIMESTAMP());

/* SRT Microceramique [high] SRT Microceramique 法国陶瓷电容 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002313, 'FR', 0, 'overseas', CURRENT_TIMESTAMP());

/* Steute [high] Steute 德国 steute Schaltgeräte */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002314, 'DE', 0, 'overseas', CURRENT_TIMESTAMP());

/* Syndesy Technologies, Inc. [medium] Syndesy Technologies Inc 美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002315, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Transcell Technology Inc. [high] Transcell Technology 台湾称重传感 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002316, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* Trustcap [high] 信容科技 Trustcap Technology 苗栗台湾 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002317, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* Unisonic Technologies Co., Ltd. [high] 友順科技 UTC 新北总部 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002318, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* UPI [medium] UPI/United Process Instruments USA 传感器语境 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002319, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Werbel Microwave LLC [high] Werbel Microwave 美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002320, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Wieland-Werke AG [high] Wieland-Werke AG 德国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002321, 'DE', 0, 'overseas', CURRENT_TIMESTAMP());

/* Xaptum, Inc. [high] Xaptum IoT 美国芝加哥 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002322, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Weidmüller [high] Weidmüller GmbH Detmold 德国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002323, 'DE', 0, 'overseas', CURRENT_TIMESTAMP());

/* DBLECTRO [medium] DB Lectro 德国连接器 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002324, 'DE', 0, 'overseas', CURRENT_TIMESTAMP());

/* IVO [medium] IVO AG 瑞士 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002325, 'CH', 0, 'overseas', CURRENT_TIMESTAMP());

/* MAXWELL [high] Maxwell Technologies 美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002326, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* CWIND [medium] CW Industries UK */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002327, 'GB', 0, 'overseas', CURRENT_TIMESTAMP());

/* HAMLIN [high] Hamlin/Littelfuse 美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002328, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* IQD Frequency Products [high] IQD Frequency Products UK */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002330, 'GB', 0, 'overseas', CURRENT_TIMESTAMP());

/* Advanced Linear Devices Inc. [high] ALD Inc. 美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002331, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* International Rectifier [high] International Rectifier 美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002332, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Master Appliance Co [high] Master Appliance 美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002333, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* Quest Technology International Inc. [high] Quest Technology 美国 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002334, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

/* euro-block [high] Euroblock 德国 Phoenix 系 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002335, 'DE', 0, 'overseas', CURRENT_TIMESTAMP());

/* Rich Bay [medium] Rich Bay 台湾连接器 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002336, 'TW', 1, 'taiwan', CURRENT_TIMESTAMP());

/* E-tec Interconnect AG [high] E-tec Interconnect AG 瑞士 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002337, 'CH', 0, 'overseas', CURRENT_TIMESTAMP());

/* TT Electronics/Roxspur Measurement & Control Ltd [high] TT Electronics Roxspur UK */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9002338, 'GB', 0, 'overseas', CURRENT_TIMESTAMP());

/* ICT [low] jp_brand 缩写默认日本 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(1443490693702848514, 'JP', 0, 'overseas', CURRENT_TIMESTAMP());

/* PFC [low] jp_brand 缩写默认日本 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(1443490693899980802, 'JP', 0, 'overseas', CURRENT_TIMESTAMP());

/* AP [low] jp_brand 缩写默认日本 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(1443490694298439681, 'JP', 0, 'overseas', CURRENT_TIMESTAMP());

/* RICKY [low] jp_brand 缩写默认日本 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(1443490694566875140, 'JP', 0, 'overseas', CURRENT_TIMESTAMP());

/* PJ [low] jp_brand 缩写默认日本 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(1443490695988744200, 'JP', 0, 'overseas', CURRENT_TIMESTAMP());

/* PIXEL [low] jp_brand 缩写默认日本 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(1443490696252985345, 'JP', 0, 'overseas', CURRENT_TIMESTAMP());

/* FAST [low] jp_brand 缩写默认日本 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(1443490698610184193, 'JP', 0, 'overseas', CURRENT_TIMESTAMP());

/* YE [low] jp_brand 缩写默认日本 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(1443490699839115270, 'JP', 0, 'overseas', CURRENT_TIMESTAMP());

/* CCB [low] jp_brand 缩写默认日本 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(1443490700027858948, 'JP', 0, 'overseas', CURRENT_TIMESTAMP());

/* CIRCUIT INTERRUPTION [low] jp_brand 缩写默认日本 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(1452551596557524994, 'JP', 0, 'overseas', CURRENT_TIMESTAMP());

/* PPI [low] jp_brand 缩写默认日本 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(1452567003054022657, 'JP', 0, 'overseas', CURRENT_TIMESTAMP());

/* RS [low] jp_brand 缩写默认日本 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(1452568903551827970, 'JP', 0, 'overseas', CURRENT_TIMESTAMP());

/* SuperTIA [low] jp_brand 缩写默认日本 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(1493861363427110914, 'JP', 0, 'overseas', CURRENT_TIMESTAMP());

/* JK ELECTRONICS [low] jp_brand 缩写默认日本 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(1493863857649676290, 'JP', 0, 'overseas', CURRENT_TIMESTAMP());

/* JSK [low] jp_brand 缩写默认日本 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(1493864876295122945, 'JP', 0, 'overseas', CURRENT_TIMESTAMP());

/* ECONET [low] jp_brand 缩写默认日本 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(1498200749526589441, 'JP', 0, 'overseas', CURRENT_TIMESTAMP());

/* GREAT [low] jp_brand 缩写默认日本 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(1574696643918393345, 'JP', 0, 'overseas', CURRENT_TIMESTAMP());

/* HJ [low] jp_brand 缩写默认日本 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(1970708101924335618, 'JP', 0, 'overseas', CURRENT_TIMESTAMP());

/* EAST [low] jp_brand 缩写默认日本 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(1970708123462086658, 'JP', 0, 'overseas', CURRENT_TIMESTAMP());

/* YF [low] jp_brand 缩写默认日本 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(1970708455382528002, 'JP', 0, 'overseas', CURRENT_TIMESTAMP());

/* KE [low] jp_brand 缩写默认日本 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(1970708538593325058, 'JP', 0, 'overseas', CURRENT_TIMESTAMP());

/* WF [low] jp_brand 缩写默认日本 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(1970708745234100225, 'JP', 0, 'overseas', CURRENT_TIMESTAMP());

/* RH [low] jp_brand 缩写默认日本 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(1970708765580668929, 'JP', 0, 'overseas', CURRENT_TIMESTAMP());

/* ST [low] jp_brand 缩写默认日本 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(1970709019596107777, 'JP', 0, 'overseas', CURRENT_TIMESTAMP());

/* FC [low] jp_brand 缩写默认日本 */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(1970709175682936833, 'JP', 0, 'overseas', CURRENT_TIMESTAMP());

/* POMONA = Pomona Electronics, 美国总部 Everett WA（9001861 已 merge 入此行） */
INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES
(9001300, 'US', 0, 'overseas', CURRENT_TIMESTAMP());

