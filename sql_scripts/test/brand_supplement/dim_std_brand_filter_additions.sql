/* ============================================================
 * dim_std_brand_filter_additions.sql — filter icpdf 未命中品牌补录
 *
 * 按 PITFALLS §12a：上网查证归属 + 主表双重核验（dim.dim_std_brand name/related_words）后补全。
 * QA 05 brand_unmapped（icpdf）：GOLLEDGE(1038)/VECTRON(608)/FRONTER(23)/ZCOMM(4)/
 *   SUPERWORLD(1)/HITACHI-METALS(1)，共 1675 行，占 icpdf 全量 2.8%。
 *
 * 查证依据：
 *   GOLLEDGE=Golledge Electronics（英国频率控制器件厂商，1990 年成立，2022 年被 TechPoint
 *     集团收购更名 TechPoint Golledge，仍以 Golledge 品牌销售晶振/SAW滤波器/晶体滤波器）
 *     → 主表无对应条目 → 新 manual_extra
 *   VECTRON=Vectron International（频率控制/SAW/BAW滤波器厂商，2017 年被 Microsemi 收购，
 *     2018 年随 Microsemi 并入 Microchip Technology；但 Microchip 本身不在主表，且行业内
 *     仍普遍以"Vectron International"品牌单独标注器件，不与 Microchip 合并使用）
 *     → 主表无 Microchip/Vectron 条目 → 新 manual_extra
 *   FRONTER=Fronter Electronics Co., Ltd（中国深圳，1991 年成立，品牌"FT"，晶振/晶体滤波器/
 *     陶瓷滤波器厂商）→ 主表无对应条目 → 新 manual_extra
 *   ZCOMM=Z-Communications, Inc.（美国 Poway，RF/微波 VCO 与 PLL 厂商）
 *     → 主表无对应条目 → 新 manual_extra
 *   SUPERWORLD=Superworld Electronics（新加坡/台湾磁性元件厂商，共模扼流圈/磁珠/电感）
 *     → 主表无对应条目 → 新 manual_extra
 *   HITACHI-METALS=Hitachi Metals（日立金属，现更名 Proterial，铁氧体磁芯/磁珠材料厂商，
 *     隶属日立集团）→ 主表已有"日立-HIT"条目（related_words 含 HITACHI）→ 补充别名，不新建
 *
 * 运行：mysql -D test_dim < dim_std_brand_filter_additions.sql
 * 补后须重跑 build（DATA_SOURCE=icpdf）使宽表 brand/brandid 生效。
 * ============================================================ */

/* ===== A. UPDATE 已有品牌加别名（幂等）===== */
UPDATE test_dim.dim_std_brand
SET related_words = array_concat(related_words, ARRAY<VARCHAR(256)>['HITACHI-METALS','HITACHI METALS']),
    update_at = CURRENT_TIMESTAMP()
WHERE brand_id_std = 1443490693639933960 /* 日立-HIT */
  AND NOT array_contains(related_words, 'HITACHI-METALS');

/* ===== B. INSERT 新 manual_extra 品牌（幂等 NOT EXISTS）===== */
INSERT INTO test_dim.dim_std_brand
(brand_id_std, name, brand_en, brand_zh, abbr, related_words, source, state, level, type)
SELECT * FROM (
    SELECT 9001837 AS bid, 'Golledge Electronics' AS nm, 'Golledge Electronics' AS en, '戈莱奇' AS zh, 'GOL' AS ab,
           ARRAY<VARCHAR(256)>['GOLLEDGE','TECHPOINT GOLLEDGE'] AS rw, 'manual_extra' AS src, 1 AS st, 3 AS lv, 0 AS tp
    UNION ALL SELECT 9001838,'Vectron International','Vectron International','维克创','VEC',ARRAY<VARCHAR(256)>['VECTRON'],'manual_extra',1,3,0
    UNION ALL SELECT 9001839,'Fronter Electronics','Fronter Electronics','丰达电子','FT',ARRAY<VARCHAR(256)>['FRONTER'],'manual_extra',1,3,0
    UNION ALL SELECT 9001840,'Z-Communications','Z-Communications','Z-Comm','ZCOMM',ARRAY<VARCHAR(256)>['ZCOMM','Z-COMM'],'manual_extra',1,3,0
    UNION ALL SELECT 9001841,'Superworld Electronics','Superworld Electronics','超世界电子','SW',ARRAY<VARCHAR(256)>['SUPERWORLD'],'manual_extra',1,3,0
) s
WHERE NOT EXISTS (SELECT 1 FROM test_dim.dim_std_brand o WHERE o.brand_id_std = s.bid);
