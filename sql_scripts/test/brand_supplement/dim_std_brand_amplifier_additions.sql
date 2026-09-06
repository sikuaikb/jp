/* ============================================================
 * dim_std_brand_amplifier_additions.sql — amplifier icpdf 未命中品牌补录
 *
 * 按 PITFALLS §12a：上网查证归属 + 主表双重核验后补全。
 *
 * ⚠️ 2026-07-01 v2 修订（收到反馈「Part B 第二批 INSERT 了 9001831，但 prod 里已有
 *   9001138='Touchstone Semiconductor'」后修复）：
 *   1. **TOUCHSTONE 重复品牌**：v1 误建 9001831='Touchstone Semiconductor'，与生产库/test_dim
 *      已有的 9001138='Touchstone Semiconductor' 重复。根因两条叠加：
 *      (a) 核验时用 `name LIKE '%TOUCHSTONE%'`（全大写）匹配 `name='Touchstone Semiconductor'`
 *          （大小写混合）——**StarRocks 的 LIKE 默认大小写敏感**，返回 false，核验漏检；
 *      (b) 生产库 9001138 的 `related_words` 本身是脏数据（"TOUCHSTONE SEMICONDUCTOR" 被
 *          错误拆成 28 个单字符元素的数组），`array_contains` 同样查不到完整词，双重漏检。
 *      已用 UPPER() 包裹两边重新核验全部 14 个 v1 新建品牌，确认**仅 Touchstone 一例重复**，
 *      其余 13 个（Teledyne/Maxwell/Daico/UMS/BCDSEMI/IVO/Micronetics/Sensitron/HSMC/NJSEMI/
 *      Integral 等）经大小写不敏感核验仍确认生产库/test_dim 确实没有，非重复。
 *   2. **UPDATE 语句在 DUPLICATE KEY 表上不可移植**：test_dim.dim_std_brand 是
 *      `DUPLICATE KEY` 模型（`SHOW CREATE TABLE` 确认），StarRocks 对此类表不支持 UPDATE
 *      （报错 `table dim_std_brand does not support update`）。v1 的 11 条 UPDATE 语句在
 *      当次执行环境里侥幸生效（历史原因不明，可能表曾被以不同方式写入/重建），但脚本本身
 *      对任何新环境重跑都会失败，是不可移植的隐患。
 *   3. **修复方案**：全部「给已有品牌加别名」操作改为幂等的**纯 INSERT 贡献行**模式——
 *      复用目标品牌已有的 `brand_id_std`/`name`，只插入一行仅含新别名的 `related_words`，
 *      不改动、不删除原有行。`v_std_brand_alias` 视图本身是把 DUPLICATE KEY 表全部行的
 *      name/abbr/related_words 逐行 UNION 展开取别名，多贡献一行完全等价于"追加别名"，
 *      且只需 INSERT，不依赖 UPDATE/DELETE，对任何环境都可正确重跑（已用测试探针验证：
 *      INSERT 贡献行后 `v_std_brand_alias` 能正确解析出 `brand_id_std`/`canonical_name`）。
 *      幂等靠 `WHERE NOT EXISTS (SELECT 1 FROM v_std_brand_alias WHERE brand_key=...)` 守卫。
 *   4. brand_id_std=9001831 已废弃（原错误占用后已清理），后续新品牌从 9001832 起延续编号，
 *      不回收复用 9001831 避免混淆。
 *
 * 查证依据（partno + 主表 + 公开收购记录，v1 已完成，v2 未改变结论）：
 *   BB=Burr-Brown(ADS8509/DAC2904)→TI(2000 收购)
 *   AGILENT=Agilent 半导体(ACMD-7401 duplexer)→Avago(2005 分拆)
 *   SIPEX→MaxLinear(2011 收购)
 *   TELCOM=Telcom Semiconductor→Microchip(1998 收购)；SUPERTEX→Microchip(2014 收购)
 *   RAYTHEON/SONY/DYNEX/AUSTIN/DATEL/YAMAHA/MERCURY/ICMIC=主表已有"X..."全名条目，缺短别名
 *   TOUCHSTONE=主表已有 9001138='Touchstone Semiconductor'，缺短别名（v2 新增，v1 曾误建重复）
 *   TELEDYNE=Teledyne 继电器(CD00CFW SSR，误入 amplifier 类)→新 manual_extra
 *   MAXWELL=Maxwell(DAC 7545ARPFB)→新 manual_extra
 *   DAICO=Daico Electronics(GaAs RF 开关 DSW62188)→新 manual_extra
 *   UMS=United Monolithic Semiconductors(20-33GHz CHA2098RBF)→新 manual_extra
 *   BCDSEMI=BCD Semiconductor(2013 被 Diodes 收购，但 Diodes 不在主表)→新 manual_extra
 *   IVO/MICRONETICS/SENSITRON/HSMC/NJSEMI/INTEGRAL=主表核验确无，新 manual_extra
 *
 * 运行：mysql -D test_dim < dim_std_brand_amplifier_additions.sql
 * 补后须重跑 build（DATA_SOURCE=icpdf）使宽表 brand/brandid 生效。
 * ============================================================ */

/* ===== A. 给已有品牌补别名（幂等纯 INSERT 贡献行；不 UPDATE、不 DELETE）===== */

INSERT INTO test_dim.dim_std_brand (brand_id_std, name, related_words, source, state, level, type)
SELECT 1443490695275712519, '德州仪器-TI', ARRAY<VARCHAR(256)>['BB'], 'manual_extra_amplifier', 1, 3, 0
WHERE NOT EXISTS (SELECT 1 FROM test_dim.v_std_brand_alias WHERE brand_key = 'BB');

INSERT INTO test_dim.dim_std_brand (brand_id_std, name, related_words, source, state, level, type)
SELECT 1443490693379887111, '安华高-AVAGO', ARRAY<VARCHAR(256)>['AGILENT'], 'manual_extra_amplifier', 1, 3, 0
WHERE NOT EXISTS (SELECT 1 FROM test_dim.v_std_brand_alias WHERE brand_key = 'AGILENT');

INSERT INTO test_dim.dim_std_brand (brand_id_std, name, related_words, source, state, level, type)
SELECT 1443490695472844801, 'MaxLinear', ARRAY<VARCHAR(256)>['SIPEX'], 'manual_extra_amplifier', 1, 3, 0
WHERE NOT EXISTS (SELECT 1 FROM test_dim.v_std_brand_alias WHERE brand_key = 'SIPEX');

INSERT INTO test_dim.dim_std_brand (brand_id_std, name, related_words, source, state, level, type)
SELECT 1443490693837066244, '美国微芯-MICROCHIP', ARRAY<VARCHAR(256)>['TELCOM'], 'manual_extra_amplifier', 1, 3, 0
WHERE NOT EXISTS (SELECT 1 FROM test_dim.v_std_brand_alias WHERE brand_key = 'TELCOM');

INSERT INTO test_dim.dim_std_brand (brand_id_std, name, related_words, source, state, level, type)
SELECT 1443490693837066244, '美国微芯-MICROCHIP', ARRAY<VARCHAR(256)>['SUPERTEX'], 'manual_extra_amplifier', 1, 3, 0
WHERE NOT EXISTS (SELECT 1 FROM test_dim.v_std_brand_alias WHERE brand_key = 'SUPERTEX');

INSERT INTO test_dim.dim_std_brand (brand_id_std, name, related_words, source, state, level, type)
SELECT 9000601, 'Raytheon Semiconductor', ARRAY<VARCHAR(256)>['RAYTHEON'], 'manual_extra_amplifier', 1, 3, 0
WHERE NOT EXISTS (SELECT 1 FROM test_dim.v_std_brand_alias WHERE brand_key = 'RAYTHEON');

INSERT INTO test_dim.dim_std_brand (brand_id_std, name, related_words, source, state, level, type)
SELECT 9000603, 'Sony Semiconductor', ARRAY<VARCHAR(256)>['SONY'], 'manual_extra_amplifier', 1, 3, 0
WHERE NOT EXISTS (SELECT 1 FROM test_dim.v_std_brand_alias WHERE brand_key = 'SONY');

INSERT INTO test_dim.dim_std_brand (brand_id_std, name, related_words, source, state, level, type)
SELECT 9000605, 'Dynex Semiconductor', ARRAY<VARCHAR(256)>['DYNEX'], 'manual_extra_amplifier', 1, 3, 0
WHERE NOT EXISTS (SELECT 1 FROM test_dim.v_std_brand_alias WHERE brand_key = 'DYNEX');

INSERT INTO test_dim.dim_std_brand (brand_id_std, name, related_words, source, state, level, type)
SELECT 9000606, 'Austin Semiconductor Inc.', ARRAY<VARCHAR(256)>['AUSTIN'], 'manual_extra_amplifier', 1, 3, 0
WHERE NOT EXISTS (SELECT 1 FROM test_dim.v_std_brand_alias WHERE brand_key = 'AUSTIN');

INSERT INTO test_dim.dim_std_brand (brand_id_std, name, related_words, source, state, level, type)
SELECT 9000600, 'Datel Inc.', ARRAY<VARCHAR(256)>['DATEL'], 'manual_extra_amplifier', 1, 3, 0
WHERE NOT EXISTS (SELECT 1 FROM test_dim.v_std_brand_alias WHERE brand_key = 'DATEL');

INSERT INTO test_dim.dim_std_brand (brand_id_std, name, related_words, source, state, level, type)
SELECT 9000610, 'Yamaha Corporation', ARRAY<VARCHAR(256)>['YAMAHA'], 'manual_extra_amplifier', 1, 3, 0
WHERE NOT EXISTS (SELECT 1 FROM test_dim.v_std_brand_alias WHERE brand_key = 'YAMAHA');

INSERT INTO test_dim.dim_std_brand (brand_id_std, name, related_words, source, state, level, type)
SELECT 9000121, 'Mercury Systems, Inc.', ARRAY<VARCHAR(256)>['MERCURY'], 'manual_extra_amplifier', 1, 3, 0
WHERE NOT EXISTS (SELECT 1 FROM test_dim.v_std_brand_alias WHERE brand_key = 'MERCURY');

INSERT INTO test_dim.dim_std_brand (brand_id_std, name, related_words, source, state, level, type)
SELECT 9000602, 'Integrated Circuit Microsystems', ARRAY<VARCHAR(256)>['ICMIC'], 'manual_extra_amplifier', 1, 3, 0
WHERE NOT EXISTS (SELECT 1 FROM test_dim.v_std_brand_alias WHERE brand_key = 'ICMIC');

/* TOUCHSTONE：v1 曾误建重复品牌 9001831，v2 改为给已有 9001138 补别名（同一模式，幂等） */
INSERT INTO test_dim.dim_std_brand (brand_id_std, name, related_words, source, state, level, type)
SELECT 9001138, 'Touchstone Semiconductor', ARRAY<VARCHAR(256)>['TOUCHSTONE'], 'manual_extra_amplifier', 1, 3, 0
WHERE NOT EXISTS (SELECT 1 FROM test_dim.v_std_brand_alias WHERE brand_key = 'TOUCHSTONE');

/* ===== B. 新增 manual_extra 品牌（主表核验确无，幂等 NOT EXISTS）===== */
INSERT INTO test_dim.dim_std_brand
(brand_id_std, name, brand_en, brand_zh, abbr, related_words, source, state, level, type)
SELECT * FROM (
    SELECT 9001825 AS bid, 'Teledyne' AS nm, 'Teledyne' AS en, 'Teledyne' AS zh, 'TDY' AS ab,
           ARRAY<VARCHAR(256)>['TELEDYNE'] AS rw, 'manual_extra' AS src, 1 AS st, 3 AS lv, 0 AS tp
    UNION ALL SELECT 9001826,'Maxwell','Maxwell','Maxwell','MXW',ARRAY<VARCHAR(256)>['MAXWELL'],'manual_extra',1,3,0
    UNION ALL SELECT 9001827,'Daico Electronics','Daico Electronics','Daico Electronics','DAI',ARRAY<VARCHAR(256)>['DAICO'],'manual_extra',1,3,0
    UNION ALL SELECT 9001828,'United Monolithic Semiconductors','United Monolithic Semiconductors','联合单片半导体','UMS',ARRAY<VARCHAR(256)>['UMS'],'manual_extra',1,3,0
    UNION ALL SELECT 9001829,'BCD Semiconductor','BCD Semiconductor','BCD 半导体','BCD',ARRAY<VARCHAR(256)>['BCDSEMI','BCD'],'manual_extra',1,3,0
) s
WHERE NOT EXISTS (SELECT 1 FROM test_dim.dim_std_brand o WHERE o.brand_id_std = s.bid);

/* 第二批（brand_id_std 跳过已废弃的 9001831，从 9001832 起延续）*/
INSERT INTO test_dim.dim_std_brand
(brand_id_std, name, brand_en, brand_zh, abbr, related_words, source, state, level, type)
SELECT * FROM (
    SELECT 9001830 AS bid, 'IVO' AS nm, 'IVO' AS en, 'IVO' AS zh, 'IVO' AS ab,
           ARRAY<VARCHAR(256)>['IVO'] AS rw, 'manual_extra' AS src, 1 AS st, 3 AS lv, 0 AS tp
    UNION ALL SELECT 9001832,'Micronetics','Micronetics','Micronetics','MNT',ARRAY<VARCHAR(256)>['MICRONETICS'],'manual_extra',1,3,0
    UNION ALL SELECT 9001833,'Sensitron','Sensitron','Sensitron','SEN',ARRAY<VARCHAR(256)>['SENSITRON'],'manual_extra',1,3,0
    UNION ALL SELECT 9001834,'HSMC','HSMC','HSMC','HSMC',ARRAY<VARCHAR(256)>['HSMC'],'manual_extra',1,3,0
    UNION ALL SELECT 9001835,'NJ Semiconductor','NJ Semiconductor','NJ 半导体','NJS',ARRAY<VARCHAR(256)>['NJSEMI'],'manual_extra',1,3,0
    UNION ALL SELECT 9001836,'Integral','Integral','Integral','INT',ARRAY<VARCHAR(256)>['INTEGRAL'],'manual_extra',1,3,0
) s
WHERE NOT EXISTS (SELECT 1 FROM test_dim.dim_std_brand o WHERE o.brand_id_std = s.bid);
