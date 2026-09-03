/* dim_std_brand_isolator_additions.sql
 *
 * 为 isolator L1 分类结果补录的品牌条目（写入共享表 test_dim.dim_std_brand）。
 * 幂等：INSERT 前检查 brand_id_std 是否已存在；related_words 追加前检查是否已含目标值。
 *
 * 执行：mysql -D test_dim < dim_std_brand_isolator_additions.sql
 *
 * 新增历史：
 *   2026-06-12 迭代轮1：BB(9000465)、MAXWELL(9000466)、SHENZHEN ORIENT(9000467)、XIAMEN HUALIAN(9000468)
 *   2026-06-12 迭代轮1.5（网络核实）：MERCURY ELECTRONIC(9000469)、SILONEX(9000470)、MERRIMAC(9000471)
 *   2026-06-12 related_words 更新：CT MICRO(1443490695015665672) 追加 CTMICRO
 *
 * 注意：dim_std_brand 是全 L1 共享主表，修改会影响所有 L1 的 v_std_brand_alias 视图。
 *       请在 build 重跑前执行本脚本，确保宽表 brand/brandid 正确。
 */

/* ============================================================
 * Step 1: 新增品牌行（INSERT WHERE NOT EXISTS，幂等）
 * ============================================================ */
INSERT INTO test_dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, related_words, state, source, create_at, update_at)
SELECT s.brand_id_std, s.name, s.brand_zh, s.brand_en, s.abbr, s.related_words,
       1, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
FROM (
    /* 9000465: BURR-BROWN (BB) — TI 前身，隔离放大器/光耦 */
    SELECT CAST(9000465 AS BIGINT) brand_id_std, 'BURR-BROWN' name, '德州仪器-伯朗' brand_zh, 'BURR-BROWN' brand_en, 'BB' abbr,
           ARRAY<VARCHAR(256)>['BB','BURR-BROWN','BURR-BROWN CORP','BURR BROWN','BURR-BROWN CORPORATION'] related_words

    UNION ALL
    /* 9000466: MAXWELL TECHNOLOGIES — 光耦/特种电子元器件 */
    SELECT CAST(9000466 AS BIGINT), 'MAXWELL TECHNOLOGIES', '麦克斯韦科技', 'MAXWELL TECHNOLOGIES', 'MAW',
           ARRAY<VARCHAR(256)>['MAXWELL','MAXWELL TECHNOLOGIES','MAXWELL TECHNOLOGIES INC','MAXWELL CORPORATION']

    UNION ALL
    /* 9000467: SHENZHEN ORIENT COMPONENTS — 深圳光耦代工厂 */
    SELECT CAST(9000467 AS BIGINT), 'SHENZHEN ORIENT COMPONENTS', '深圳东方电子', 'SHENZHEN ORIENT COMPONENTS', 'SOC',
           ARRAY<VARCHAR(256)>['SHENZHEN ORIENT COMPONENTS CO., LTD','ORIENT COMPONENTS','SHENZHEN ORIENT']

    UNION ALL
    /* 9000468: XIAMEN HUALIAN ELECTRONICS — 厦门华联电子 */
    SELECT CAST(9000468 AS BIGINT), 'XIAMEN HUALIAN ELECTRONICS', '厦门华联电子', 'XIAMEN HUALIAN ELECTRONICS', 'XHE',
           ARRAY<VARCHAR(256)>['XIAMEN HUALIAN ELECTRONICS CORP. LTD.','XIAMEN HUALIAN','HUALIAN ELECTRONICS']

    UNION ALL
    /* 9000469: MERCURY ELECTRONIC IND CO LTD — 台湾光耦/RF隔离器制造商（CNY17/EL817系列） */
    SELECT CAST(9000469 AS BIGINT), 'MERCURY ELECTRONIC IND', '水星电子工业', 'MERCURY ELECTRONIC IND', 'MER',
           ARRAY<VARCHAR(256)>['MERCURY','MERCURY ELECTRONIC','MERCURY ELECTRONIC IND CO LTD',
                               'MERCURY ELECTRONIC IND CO., LTD','MERCURY ELECTRONICS']

    UNION ALL
    /* 9000470: SILONEX INC — 加拿大光电元件厂（1958年，Audiohm光耦、CdS光敏） */
    SELECT CAST(9000470 AS BIGINT), 'SILONEX', '赛乐尼克斯', 'SILONEX', 'SLX',
           ARRAY<VARCHAR(256)>['SILONEX','SILONEX INC','SILONEX INCCASCO','ADVANCED PHOTONIX SILONEX']

    UNION ALL
    /* 9000471: MERRIMAC INDUSTRIES INC — RF定向耦合器/隔离器制造商（NJ，1960年代创立） */
    SELECT CAST(9000471 AS BIGINT), 'MERRIMAC INDUSTRIES', '梅里马克工业', 'MERRIMAC INDUSTRIES', 'MRI',
           ARRAY<VARCHAR(256)>['MERRIMAC','MERRIMAC INDUSTRIES','MERRIMAC INDUSTRIES INC',
                               'MERRIMAC INDUSTRIES, INC.']
    UNION ALL
    /* 9000472: AGILENT TECHNOLOGIES — HP半导体事业部分拆，HCPL/ACPL光耦系列（后→Avago→Broadcom） */
    SELECT CAST(9000472 AS BIGINT), 'AGILENT TECHNOLOGIES', '安捷伦科技', 'AGILENT TECHNOLOGIES', 'AGI',
           ARRAY<VARCHAR(256)>['AGILENT','AGILENT TECHNOLOGIES','AGILENT TECHNOLOGIES INC',
                               'AGILENT TECHNOLOGIES INC.']

    UNION ALL
    /* 9000473: HP SEMICONDUCTOR — Hewlett-Packard（Agilent 前身）老型号光耦 */
    SELECT CAST(9000473 AS BIGINT), 'HP SEMICONDUCTOR', '惠普半导体', 'HP SEMICONDUCTOR', 'HPS',
           ARRAY<VARCHAR(256)>['HP','HEWLETT PACKARD','HEWLETT PACKARD CO','HEWLETT-PACKARD',
                               'HEWLETT PACKARD COMPANY']

    UNION ALL
    /* 9000474: QT OPTOELECTRONICS — 光电耦合器制造商 */
    SELECT CAST(9000474 AS BIGINT), 'QT OPTOELECTRONICS', 'QT光电', 'QT OPTOELECTRONICS', 'QTO',
           ARRAY<VARCHAR(256)>['QT','QT OPTOELECTRONICS','QT OPTOELECTRONICS INC']

    UNION ALL
    /* 9000475: DYNEX SEMICONDUCTOR — GEC Plessey Semiconductors 后续（功率半导体/光耦） */
    SELECT CAST(9000475 AS BIGINT), 'DYNEX SEMICONDUCTOR', 'Dynex半导体', 'DYNEX SEMICONDUCTOR', 'DYN',
           ARRAY<VARCHAR(256)>['DYNEX','DYNEX SEMICONDUCTOR','GEC PLESSEY SEMICONDUCTORS',
                               'DYNEX SEMICONDUCTOR LTD']

    UNION ALL
    /* 9000476: HAMAMATSU PHOTONICS — 浜松光子（日本，光耦/光传感器） */
    SELECT CAST(9000476 AS BIGINT), 'HAMAMATSU PHOTONICS', '浜松光子', 'HAMAMATSU PHOTONICS', 'HPK',
           ARRAY<VARCHAR(256)>['HAMAMATSU','HAMAMATSU PHOTONICS','HAMAMATSU PHOTONICS K.K.',
                               'HAMAMATSU CORPORATION']

    UNION ALL
    /* 9000477: CRYDOM — 固态继电器/光耦制造商 */
    SELECT CAST(9000477 AS BIGINT), 'CRYDOM', 'Crydom', 'CRYDOM', 'CRY',
           ARRAY<VARCHAR(256)>['CRYDOM','CRYDOM INC','CRYDOM CO.']

    UNION ALL
    /* 9000478: TEMEX COMPONENTS — 法国 RF 无源器件/隔离器制造商 */
    SELECT CAST(9000478 AS BIGINT), 'TEMEX COMPONENTS', 'Temex', 'TEMEX COMPONENTS', 'TMX',
           ARRAY<VARCHAR(256)>['TEMEX','TEMEX COMPONENTS','TEMEX CERAMICS']

    UNION ALL
    /* 9000479: HITACHI METALS — 日立金属（RF 铁氧体器件/隔离器） */
    SELECT CAST(9000479 AS BIGINT), 'HITACHI METALS', '日立金属', 'HITACHI METALS', 'HMT',
           ARRAY<VARCHAR(256)>['HITACHI-METALS','HITACHI METALS','HITACHI METALS LTD']

    UNION ALL
    /* 9000480: SIPEX CORPORATION — 模拟半导体/线性光耦 */
    SELECT CAST(9000480 AS BIGINT), 'SIPEX CORPORATION', 'Sipex', 'SIPEX CORPORATION', 'SPX',
           ARRAY<VARCHAR(256)>['SIPEX','SIPEX CORP','SIPEX CORPORATION']

    UNION ALL
    /* 9000481: SENSITRON SEMICONDUCTOR — 高速光耦 */
    SELECT CAST(9000481 AS BIGINT), 'SENSITRON SEMICONDUCTOR', 'Sensitron', 'SENSITRON SEMICONDUCTOR', 'SEN',
           ARRAY<VARCHAR(256)>['SENSITRON','SENSITRON SEMICONDUCTOR']

    UNION ALL
    /* 9000482: PASTERNACK ENTERPRISES — RF 器件经销商/环行器制造商 */
    SELECT CAST(9000482 AS BIGINT), 'PASTERNACK ENTERPRISES', 'Pasternack', 'PASTERNACK ENTERPRISES', 'PAS',
           ARRAY<VARCHAR(256)>['PASTERNACK','PASTERNACK ENTERPRISES','PASTERNACK ENTERPRISES INC']

    UNION ALL
    /* 9000483: MICRO ELECTRONICS LTD — 光耦制造商 */
    SELECT CAST(9000483 AS BIGINT), 'MICRO ELECTRONICS', 'Micro Electronics', 'MICRO ELECTRONICS', 'MEL',
           ARRAY<VARCHAR(256)>['MICRO-ELECTRONICS','MICRO ELECTRONICS','MICRO ELECTRONICS LTD']

    UNION ALL
    /* 9000484: OKI SEMICONDUCTOR — 日本冲电气半导体（线性/晶体管光耦） */
    SELECT CAST(9000484 AS BIGINT), 'OKI SEMICONDUCTOR', '冲半导体', 'OKI SEMICONDUCTOR', 'OKI',
           ARRAY<VARCHAR(256)>['OKI','OKI SEMICONDUCTOR','OKI ELECTRIC INDUSTRY']

    UNION ALL
    /* 9000485: CLAIREX TECHNOLOGIES — CdS 光电/晶体管输出光耦 */
    SELECT CAST(9000485 AS BIGINT), 'CLAIREX TECHNOLOGIES', 'Clairex', 'CLAIREX TECHNOLOGIES', 'CLX',
           ARRAY<VARCHAR(256)>['CLAIREX','CLAIREX TECHNOLOGIES','CLAIREX TECHNOLOGIES INC']

    UNION ALL
    /* 9000486: SSOUSA — 分销商/小型光耦供应商 */
    SELECT CAST(9000486 AS BIGINT), 'SSOUSA', 'SSOUSA', 'SSOUSA', 'SSO',
           ARRAY<VARCHAR(256)>['SSOUSA']
) s
WHERE NOT EXISTS (
    SELECT 1 FROM test_dim.dim_std_brand old WHERE old.brand_id_std = s.brand_id_std
);

/* ============================================================
 * Step 3: 更新现有品牌的 related_words（追加拼写变体）
 * ============================================================ */

/* CT MICRO (1443490695015665672): 追加 CTMICRO（无空格变体） — 已在 Step 2 处理 */

/* 博通-Broadcom (1443490695858720771): 追加 BOARDCOM（icpdf 中的拼写错误变体，70行） */
UPDATE test_dim.dim_std_brand
SET related_words = array_append(related_words, 'BOARDCOM'),
    update_at = CURRENT_TIMESTAMP()
WHERE brand_id_std = 1443490695858720771
  AND NOT array_contains(COALESCE(related_words, CAST(ARRAY<VARCHAR(256)>[] AS ARRAY<VARCHAR(256)>)), 'BOARDCOM');

/* ============================================================
 * Step 2: CT MICRO related_words 追加 CTMICRO（无空格变体）
 * ============================================================ */
UPDATE test_dim.dim_std_brand
SET related_words = array_append(related_words, 'CTMICRO'),
    update_at = CURRENT_TIMESTAMP()
WHERE brand_id_std = 1443490695015665672
  AND NOT array_contains(COALESCE(related_words, CAST(ARRAY<VARCHAR(256)>[] AS ARRAY<VARCHAR(256)>)), 'CTMICRO');
