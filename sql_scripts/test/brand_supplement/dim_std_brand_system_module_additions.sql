/* dim_std_brand_system_module_additions.sql
 *
 * 为 system_module L1 attr-std 补录的品牌条目（写入共享表 test_dim.dim_std_brand）。
 * 依据 EXTRACT_RULE_QA.md §I：对 L2 宽表中高频 brandid=NULL 的源 brandshort：
 *   - case 1：主表已有该品牌、仅缺别名 → array_append related_words（视图 v_std_brand_alias 即时生效）
 *   - case 2：主表无该品牌 → 新增 manual_extra 行（brand_id_std 9001140+ 段，system_module 专用；勿用 9000601–9000622，已被其他 L1 占用）
 * 幂等：新增用 NOT EXISTS；别名追加用 NOT array_contains 守卫。
 *
 * 匹配口径：v_std_brand_alias.brand_key = UPPER(TRIM(related_word))；
 *   宽表 JOIN ON brand_key = UPPER(TRIM(p.brandshort))。
 *   故 related_words 直接取宽表里 UPPER(TRIM(brand)) 形态（UPPER 幂等，含 ü/™ 原样保留即可命中）。
 *
 * 执行：mysql -D test_dim < dim_std_brand_system_module_additions.sql；之后须重跑 4 张 L2 宽表 build。
 *
 * 注意：dim_std_brand 全 L1 共享，修改影响所有 L1 的 v_std_brand_alias。
 * 重要甄别：HALO ELECTRONICS, INC.（美国磁性/以太网变压器厂）≠ 主表「希荻微-Halo」（中国模拟 IC），独立建条目，勿误并。
 */

/* ============================================================
 * Step 1: 新增品牌行（manual_extra，INSERT WHERE NOT EXISTS，幂等）
 * ============================================================ */
INSERT INTO test_dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, related_words, state, source, create_at, update_at)
SELECT s.brand_id_std, s.name, s.brand_zh, s.brand_en, s.abbr, s.related_words,
       1, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
FROM (
    /* 9001140: VOX POWER LTD. — 爱尔兰模块电源厂 */
    SELECT CAST(9001140 AS BIGINT) brand_id_std, 'VOX POWER' name, 'Vox Power' brand_zh, 'VOX POWER' brand_en, 'VOXP' abbr,
           ARRAY<VARCHAR(256)>['VOX POWER LTD.','VOX POWER LTD','VOX POWER'] related_words
    UNION ALL  /* 9001141: GAPTEC ELECTRONIC — 德国 DC-DC 模块厂 */
    SELECT CAST(9001141 AS BIGINT), 'GAPTEC ELECTRONIC', 'GAPTEC', 'GAPTEC ELECTRONIC', 'GPT',
           ARRAY<VARCHAR(256)>['GAPTEC ELECTRONIC','GAPTEC']
    UNION ALL  /* 9001142: AIMTEC — 加拿大 DC-DC/AC-DC 模块电源 */
    SELECT CAST(9001142 AS BIGINT), 'AIMTEC', 'Aimtec', 'AIMTEC', 'AMT',
           ARRAY<VARCHAR(256)>['AIMTEC']
    UNION ALL  /* 9001143: MICROPOWER DIRECT — 美国 DC-DC 模块电源 */
    SELECT CAST(9001143 AS BIGINT), 'MICROPOWER DIRECT', 'MicroPower Direct', 'MICROPOWER DIRECT', 'MPD',
           ARRAY<VARCHAR(256)>['MICROPOWER DIRECT']
    UNION ALL  /* 9001144: ACOPIAN POWER SUPPLIES — 美国线性/可调电源 */
    SELECT CAST(9001144 AS BIGINT), 'ACOPIAN', 'Acopian', 'ACOPIAN', 'ACO',
           ARRAY<VARCHAR(256)>['ACOPIAN POWER SUPPLIES','ACOPIAN']
    UNION ALL  /* 9001145: SYNQOR — 美国高可靠 DC-DC 模块 */
    SELECT CAST(9001145 AS BIGINT), 'SYNQOR', 'SynQor', 'SYNQOR', 'SYQ',
           ARRAY<VARCHAR(256)>['SYNQOR']
    UNION ALL  /* 9001146: ASTRODYNE (TDI) — 美国电源/EMI 滤波 */
    SELECT CAST(9001146 AS BIGINT), 'ASTRODYNE TDI', 'Astrodyne', 'ASTRODYNE TDI', 'ADT',
           ARRAY<VARCHAR(256)>['ASTRODYNE','ASTRODYNE TDI']
    UNION ALL  /* 9001147: OMNION POWER — 电力系统/逆变 */
    SELECT CAST(9001147 AS BIGINT), 'OMNION POWER', 'Omnion Power', 'OMNION POWER', 'OMN',
           ARRAY<VARCHAR(256)>['OMNION POWER™','OMNION POWER']
    UNION ALL  /* 9001148: P-DUKE TECHNOLOGY — 台湾 DC-DC 模块 */
    SELECT CAST(9001148 AS BIGINT), 'P-DUKE TECHNOLOGY', 'P-DUKE', 'P-DUKE TECHNOLOGY', 'PDK',
           ARRAY<VARCHAR(256)>['P-DUKE TECHNOLOGY','P-DUKE']
    UNION ALL  /* 9001149: WALL INDUSTRIES — 美国 DC-DC/适配器 */
    SELECT CAST(9001149 AS BIGINT), 'WALL INDUSTRIES', 'Wall Industries', 'WALL INDUSTRIES', 'WLI',
           ARRAY<VARCHAR(256)>['WALL']
    UNION ALL  /* 9001150: DIWELL ELECTRONICS — 韩国 DC-DC 模块 */
    SELECT CAST(9001150 AS BIGINT), 'DIWELL ELECTRONICS', 'Diwell', 'DIWELL ELECTRONICS', 'DWL',
           ARRAY<VARCHAR(256)>['DIWELL ELECTRONICS','DIWELL']
    UNION ALL  /* 9001151: TRI-MAG, LLC — 美国磁性/电源 */
    SELECT CAST(9001151 AS BIGINT), 'TRI-MAG', 'Tri-Mag', 'TRI-MAG', 'TMG',
           ARRAY<VARCHAR(256)>['TRI-MAG, LLC','TRI-MAG']
    UNION ALL  /* 9001152: OPTO 22 — 美国工业 I/O / 控制 */
    SELECT CAST(9001152 AS BIGINT), 'OPTO 22', 'Opto 22', 'OPTO 22', 'OP22',
           ARRAY<VARCHAR(256)>['OPTO 22']
    UNION ALL  /* 9001153: POLOLU — 美国机器人/电子模块 */
    SELECT CAST(9001153 AS BIGINT), 'POLOLU', 'Pololu', 'POLOLU', 'POL',
           ARRAY<VARCHAR(256)>['POLOLU']
    UNION ALL  /* 9001154: ETA-USA — 电源供应商 */
    SELECT CAST(9001154 AS BIGINT), 'ETA-USA', 'ETA-USA', 'ETA-USA', 'ETAU',
           ARRAY<VARCHAR(256)>['ETA-USA']
    UNION ALL  /* 9001155: FSP TECHNOLOGY INC. — 台湾全汉电源 */
    SELECT CAST(9001155 AS BIGINT), 'FSP TECHNOLOGY', '全汉-FSP', 'FSP TECHNOLOGY', 'FSP',
           ARRAY<VARCHAR(256)>['FSP TECHNOLOGY INC.','FSP TECHNOLOGY','FSP']
    UNION ALL  /* 9001156: VOLGEN (Kaga) — 日本电源（+ FURUNO 渠道） */
    SELECT CAST(9001156 AS BIGINT), 'VOLGEN', 'Volgen', 'VOLGEN', 'VLG',
           ARRAY<VARCHAR(256)>['VOLGEN + FURUNO','VOLGEN']
    UNION ALL  /* 9001157: EDATEC — 树莓派工业计算/载板 */
    SELECT CAST(9001157 AS BIGINT), 'EDATEC', 'EDATEC', 'EDATEC', 'EDT',
           ARRAY<VARCHAR(256)>['EDATEC']
    UNION ALL  /* 9001158: MULTI-TECH SYSTEMS INC. — 美国蜂窝/通信模块 */
    SELECT CAST(9001158 AS BIGINT), 'MULTI-TECH SYSTEMS', 'MultiTech', 'MULTI-TECH SYSTEMS', 'MTS',
           ARRAY<VARCHAR(256)>['MULTI-TECH SYSTEMS INC.','MULTI-TECH SYSTEMS','MULTITECH']
    UNION ALL  /* 9001159: GAIA CONVERTER — 法国高可靠 DC-DC */
    SELECT CAST(9001159 AS BIGINT), 'GAIA CONVERTER', 'Gaia Converter', 'GAIA CONVERTER', 'GAIA',
           ARRAY<VARCHAR(256)>['GAIA CONVERTER']
    UNION ALL  /* 9001160: HVM TECHNOLOGY — 高压电源模块 */
    SELECT CAST(9001160 AS BIGINT), 'HVM TECHNOLOGY', 'HVM Technology', 'HVM TECHNOLOGY', 'HVM',
           ARRAY<VARCHAR(256)>['HVM TECHNOLOGY, INC.','HVM TECHNOLOGY']
    UNION ALL  /* 9001161: BANNER ENGINEERING — 美国工业传感/电源 */
    SELECT CAST(9001161 AS BIGINT), 'BANNER ENGINEERING', 'Banner Engineering', 'BANNER ENGINEERING', 'BAN',
           ARRAY<VARCHAR(256)>['BANNER ENGINEERING CORPORATION','BANNER ENGINEERING']
    UNION ALL  /* 9001162: VIGORTRONIX — 英国电源/变压器 */
    SELECT CAST(9001162 AS BIGINT), 'VIGORTRONIX', 'Vigortronix', 'VIGORTRONIX', 'VGX',
           ARRAY<VARCHAR(256)>['VIGORTRONIX']
    UNION ALL  /* 9001163: EZURIO — 原 Laird Connectivity，无线模块 */
    SELECT CAST(9001163 AS BIGINT), 'EZURIO', 'Ezurio', 'EZURIO', 'EZU',
           ARRAY<VARCHAR(256)>['EZURIO']
    UNION ALL  /* 9001164: ARCH ELECTRONICS CORP — DC-DC 模块电源 */
    SELECT CAST(9001164 AS BIGINT), 'ARCH ELECTRONICS', 'Arch', 'ARCH ELECTRONICS', 'ARC',
           ARRAY<VARCHAR(256)>['ARCH ELECTRONICS CORP','ARCH ELECTRONICS']
    UNION ALL  /* 9001165: INVENTUS POWER — 电池/电源系统 */
    SELECT CAST(9001165 AS BIGINT), 'INVENTUS POWER', 'Inventus Power', 'INVENTUS POWER', 'INV',
           ARRAY<VARCHAR(256)>['INVENTUS POWER']
    UNION ALL  /* 9001166: PHIHONG — 台湾飞宏电源 */
    SELECT CAST(9001166 AS BIGINT), 'PHIHONG', '飞宏-Phihong', 'PHIHONG', 'PHH',
           ARRAY<VARCHAR(256)>['PHIHONG USA','PHIHONG']
    UNION ALL  /* 9001167: FREEWAVE TECHNOLOGIES — 美国工业无线电台 */
    SELECT CAST(9001167 AS BIGINT), 'FREEWAVE TECHNOLOGIES', 'FreeWave', 'FREEWAVE TECHNOLOGIES', 'FRW',
           ARRAY<VARCHAR(256)>['FREEWAVE TECHNOLOGIES','FREEWAVE']
    UNION ALL  /* 9001168: HALO ELECTRONICS, INC. — 美国磁性/以太网变压器厂（≠希荻微-Halo） */
    SELECT CAST(9001168 AS BIGINT), 'HALO ELECTRONICS', 'Halo Electronics', 'HALO ELECTRONICS', 'HLE',
           ARRAY<VARCHAR(256)>['HALO ELECTRONICS, INC.','HALO ELECTRONICS']
    UNION ALL  /* 9001169: NUMATO LAB — 嵌入式/FPGA 模块 */
    SELECT CAST(9001169 AS BIGINT), 'NUMATO LAB', 'Numato Lab', 'NUMATO LAB', 'NML',
           ARRAY<VARCHAR(256)>['NUMATO LAB','NUMATO']
    UNION ALL  /* 9001170: TECHNEXION — 台湾 SoM/嵌入式模块 */
    SELECT CAST(9001170 AS BIGINT), 'TECHNEXION', 'TechNexion', 'TECHNEXION', 'TNX',
           ARRAY<VARCHAR(256)>['TECHNEXION']
    UNION ALL  /* 9001171: SOLAHD — 美国 SolaHD 工业电源 */
    SELECT CAST(9001171 AS BIGINT), 'SOLAHD', 'SolaHD', 'SOLAHD', 'SHD',
           ARRAY<VARCHAR(256)>['SOLAHD','SOLA HD']
    UNION ALL  /* 9001172: TRIAD MAGNETICS — 美国磁性/电源 */
    SELECT CAST(9001172 AS BIGINT), 'TRIAD MAGNETICS', 'Triad Magnetics', 'TRIAD MAGNETICS', 'TRM',
           ARRAY<VARCHAR(256)>['TRIAD MAGNETICS']
    UNION ALL  /* 9001173: CONTROLBYWEB (Xytronix) — 网络化 I/O */
    SELECT CAST(9001173 AS BIGINT), 'CONTROLBYWEB', 'ControlByWeb', 'CONTROLBYWEB', 'CBW',
           ARRAY<VARCHAR(256)>['CONTROLBYWEB']
    UNION ALL  /* 9001174: QUALTEK — 美国电源/连接器/热管理 */
    SELECT CAST(9001174 AS BIGINT), 'QUALTEK', 'Qualtek', 'QUALTEK', 'QTK',
           ARRAY<VARCHAR(256)>['QUALTEK']
    UNION ALL  /* 9001175: CARLO GAVAZZI — 意大利工业自动化/电源 */
    SELECT CAST(9001175 AS BIGINT), 'CARLO GAVAZZI', 'Carlo Gavazzi', 'CARLO GAVAZZI', 'CGV',
           ARRAY<VARCHAR(256)>['CARLO GAVAZZI INC.','CARLO GAVAZZI']
    UNION ALL  /* 9001176: CONTA-CLIP — 德国接线/接口模块 */
    SELECT CAST(9001176 AS BIGINT), 'CONTA-CLIP', 'Conta-Clip', 'CONTA-CLIP', 'CTC',
           ARRAY<VARCHAR(256)>['CONTA-CLIP, INC.','CONTA-CLIP']
    UNION ALL  /* 9001177: DABURN ELECTRONICS — 美国线缆/电子 */
    SELECT CAST(9001177 AS BIGINT), 'DABURN ELECTRONICS', 'Daburn', 'DABURN ELECTRONICS', 'DBN',
           ARRAY<VARCHAR(256)>['DABURN ELECTRONICS','DABURN']
    UNION ALL  /* 9001178: MAGIC POWER — 模块电源 */
    SELECT CAST(9001178 AS BIGINT), 'MAGIC POWER', 'Magic Power', 'MAGIC POWER', 'MGP',
           ARRAY<VARCHAR(256)>['MAGIC POWER']
    UNION ALL  /* 9001179: EMERSON NETWORK POWER — 后并入 Vertiv/Artesyn */
    SELECT CAST(9001179 AS BIGINT), 'EMERSON NETWORK POWER', 'Emerson Network Power', 'EMERSON NETWORK POWER', 'ENP',
           ARRAY<VARCHAR(256)>['EMERSON-NETWORKPOWER','EMERSON NETWORK POWER']
) s
WHERE NOT EXISTS (
    SELECT 1 FROM test_dim.dim_std_brand old WHERE old.brand_id_std = s.brand_id_std
)
AND NOT EXISTS (  /* 生产已有同名规范条目则不自建新号，改由「迭代轮4 Step 0a」按生产 id 回灌 */
    SELECT 1 FROM dim.dim_std_brand pr WHERE UPPER(TRIM(pr.name)) = UPPER(TRIM(s.name))
);

/* ============================================================
 * Step 2: 已有品牌追加 related_words（case 1，幂等：NOT array_contains）
 *   值取宽表 UPPER(TRIM(brand)) 形态，确保 UPPER(TRIM(rw)) 与源 brandshort 命中。
 * ============================================================ */

/* Cosel (1970677936250884097, abbr COSEL)：COSEL USA, INC. */
UPDATE test_dim.dim_std_brand SET related_words = array_append(related_words, 'COSEL USA, INC.'), update_at = CURRENT_TIMESTAMP()
WHERE brand_id_std = 1970677936250884097 AND NOT array_contains(COALESCE(related_words, CAST(ARRAY<VARCHAR(256)>[] AS ARRAY<VARCHAR(256)>)), 'COSEL USA, INC.');

/* Advanced Energy (1498548520179789825)：UltraVolt / SL Power / Excelsys 子品牌 */
UPDATE test_dim.dim_std_brand SET related_words = array_append(related_words, 'ULTRAVOLT / ADVANCED ENERGY'), update_at = CURRENT_TIMESTAMP()
WHERE brand_id_std = 1498548520179789825 AND NOT array_contains(COALESCE(related_words, CAST(ARRAY<VARCHAR(256)>[] AS ARRAY<VARCHAR(256)>)), 'ULTRAVOLT / ADVANCED ENERGY');
UPDATE test_dim.dim_std_brand SET related_words = array_append(related_words, 'SL POWER / ADVANCED ENERGY'), update_at = CURRENT_TIMESTAMP()
WHERE brand_id_std = 1498548520179789825 AND NOT array_contains(COALESCE(related_words, CAST(ARRAY<VARCHAR(256)>[] AS ARRAY<VARCHAR(256)>)), 'SL POWER / ADVANCED ENERGY');
UPDATE test_dim.dim_std_brand SET related_words = array_append(related_words, 'EXCELSYS / ADVANCED ENERGY'), update_at = CURRENT_TIMESTAMP()
WHERE brand_id_std = 1498548520179789825 AND NOT array_contains(COALESCE(related_words, CAST(ARRAY<VARCHAR(256)>[] AS ARRAY<VARCHAR(256)>)), 'EXCELSYS / ADVANCED ENERGY');

/* Artesyn (1448534630616387585)：ARTESYN / ADVANCED ENERGY */
UPDATE test_dim.dim_std_brand SET related_words = array_append(related_words, 'ARTESYN / ADVANCED ENERGY'), update_at = CURRENT_TIMESTAMP()
WHERE brand_id_std = 1448534630616387585 AND NOT array_contains(COALESCE(related_words, CAST(ARRAY<VARCHAR(256)>[] AS ARRAY<VARCHAR(256)>)), 'ARTESYN / ADVANCED ENERGY');

/* XP Power (1448104925496958978)：XPPOWER（无空格变体） */
UPDATE test_dim.dim_std_brand SET related_words = array_append(related_words, 'XPPOWER'), update_at = CURRENT_TIMESTAMP()
WHERE brand_id_std = 1448104925496958978 AND NOT array_contains(COALESCE(related_words, CAST(ARRAY<VARCHAR(256)>[] AS ARRAY<VARCHAR(256)>)), 'XPPOWER');

/* 幸康-Cincon (1498562128871747586)：CINCON ELECTRONICS CO. LTD / CINCON */
UPDATE test_dim.dim_std_brand SET related_words = array_append(related_words, 'CINCON ELECTRONICS CO. LTD'), update_at = CURRENT_TIMESTAMP()
WHERE brand_id_std = 1498562128871747586 AND NOT array_contains(COALESCE(related_words, CAST(ARRAY<VARCHAR(256)>[] AS ARRAY<VARCHAR(256)>)), 'CINCON ELECTRONICS CO. LTD');
UPDATE test_dim.dim_std_brand SET related_words = array_append(related_words, 'CINCON'), update_at = CURRENT_TIMESTAMP()
WHERE brand_id_std = 1498562128871747586 AND NOT array_contains(COALESCE(related_words, CAST(ARRAY<VARCHAR(256)>[] AS ARRAY<VARCHAR(256)>)), 'CINCON');

/* 三垦-SANKEN (1443490693967089666)：SANKEN ELECTRIC USA INC. */
UPDATE test_dim.dim_std_brand SET related_words = array_append(related_words, 'SANKEN ELECTRIC USA INC.'), update_at = CURRENT_TIMESTAMP()
WHERE brand_id_std = 1443490693967089666 AND NOT array_contains(COALESCE(related_words, CAST(ARRAY<VARCHAR(256)>[] AS ARRAY<VARCHAR(256)>)), 'SANKEN ELECTRIC USA INC.');

/* 泰科-TE Connectivity (1443490699323215873)：TE CONNECTIVITY LINX */
UPDATE test_dim.dim_std_brand SET related_words = array_append(related_words, 'TE CONNECTIVITY LINX'), update_at = CURRENT_TIMESTAMP()
WHERE brand_id_std = 1443490699323215873 AND NOT array_contains(COALESCE(related_words, CAST(ARRAY<VARCHAR(256)>[] AS ARRAY<VARCHAR(256)>)), 'TE CONNECTIVITY LINX');

/* 魏德米勒-weidmueller (1447755160083058690)：WEIDMÜLLER（源 ü 小写形态） */
UPDATE test_dim.dim_std_brand SET related_words = array_append(related_words, 'WEIDMüLLER'), update_at = CURRENT_TIMESTAMP()
WHERE brand_id_std = 1447755160083058690 AND NOT array_contains(COALESCE(related_words, CAST(ARRAY<VARCHAR(256)>[] AS ARRAY<VARCHAR(256)>)), 'WEIDMüLLER');

/* 台湾明纬-MW (1443490697305755653)：MEANWELL / MEAN WELL */
UPDATE test_dim.dim_std_brand SET related_words = array_append(related_words, 'MEANWELL'), update_at = CURRENT_TIMESTAMP()
WHERE brand_id_std = 1443490697305755653 AND NOT array_contains(COALESCE(related_words, CAST(ARRAY<VARCHAR(256)>[] AS ARRAY<VARCHAR(256)>)), 'MEANWELL');
UPDATE test_dim.dim_std_brand SET related_words = array_append(related_words, 'MEAN WELL'), update_at = CURRENT_TIMESTAMP()
WHERE brand_id_std = 1443490697305755653 AND NOT array_contains(COALESCE(related_words, CAST(ARRAY<VARCHAR(256)>[] AS ARRAY<VARCHAR(256)>)), 'MEAN WELL');

/* 台达-DELTA (1443490697037320202)：DELTA ELECTRONICS/INDUSTRIAL AUTOMATION / DELTA ELECTRONICS */
UPDATE test_dim.dim_std_brand SET related_words = array_append(related_words, 'DELTA ELECTRONICS/INDUSTRIAL AUTOMATION'), update_at = CURRENT_TIMESTAMP()
WHERE brand_id_std = 1443490697037320202 AND NOT array_contains(COALESCE(related_words, CAST(ARRAY<VARCHAR(256)>[] AS ARRAY<VARCHAR(256)>)), 'DELTA ELECTRONICS/INDUSTRIAL AUTOMATION');
UPDATE test_dim.dim_std_brand SET related_words = array_append(related_words, 'DELTA ELECTRONICS'), update_at = CURRENT_TIMESTAMP()
WHERE brand_id_std = 1443490697037320202 AND NOT array_contains(COALESCE(related_words, CAST(ARRAY<VARCHAR(256)>[] AS ARRAY<VARCHAR(256)>)), 'DELTA ELECTRONICS');

/* Analog Technologies (9000112)：ANALOG TECHNOLOGIES, INC. */
UPDATE test_dim.dim_std_brand SET related_words = array_append(related_words, 'ANALOG TECHNOLOGIES, INC.'), update_at = CURRENT_TIMESTAMP()
WHERE brand_id_std = 9000112 AND NOT array_contains(COALESCE(related_words, CAST(ARRAY<VARCHAR(256)>[] AS ARRAY<VARCHAR(256)>)), 'ANALOG TECHNOLOGIES, INC.');

/* TT ELECTRONICS/BI (1452914132033273857)：TT ELECTRONICS/POWER PARTNERS INC. */
UPDATE test_dim.dim_std_brand SET related_words = array_append(related_words, 'TT ELECTRONICS/POWER PARTNERS INC.'), update_at = CURRENT_TIMESTAMP()
WHERE brand_id_std = 1452914132033273857 AND NOT array_contains(COALESCE(related_words, CAST(ARRAY<VARCHAR(256)>[] AS ARRAY<VARCHAR(256)>)), 'TT ELECTRONICS/POWER PARTNERS INC.');

/* 伍尔特-Wurth (1443490691236597766)：WÜRTH ELEKTRONIK（源 ü 小写形态） */
UPDATE test_dim.dim_std_brand SET related_words = array_append(related_words, 'WüRTH ELEKTRONIK'), update_at = CURRENT_TIMESTAMP()
WHERE brand_id_std = 1443490691236597766 AND NOT array_contains(COALESCE(related_words, CAST(ARRAY<VARCHAR(256)>[] AS ARRAY<VARCHAR(256)>)), 'WüRTH ELEKTRONIK');

/* ============================================================
 * 迭代轮2：第二批高频未命中（首轮重跑后剩余）
 * ============================================================ */

/* Step 1b: 新增品牌（manual_extra 9001180+） */
INSERT INTO test_dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, related_words, state, source, create_at, update_at)
SELECT s.brand_id_std, s.name, s.brand_zh, s.brand_en, s.abbr, s.related_words,
       1, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
FROM (
    /* 9001180: SIERRA WIRELESS (AirLink) — 加拿大蜂窝/M2M 模块 */
    SELECT CAST(9001180 AS BIGINT) brand_id_std, 'SIERRA WIRELESS' name, 'Sierra Wireless' brand_zh, 'SIERRA WIRELESS' brand_en, 'SRW' abbr,
           ARRAY<VARCHAR(256)>['SIERRA WIRELESS AIRLINK','SIERRA WIRELESS'] related_words
    UNION ALL  /* 9001181: POWERBOX — 瑞典工业电源 */
    SELECT CAST(9001181 AS BIGINT), 'POWERBOX', 'Powerbox', 'POWERBOX', 'PWB',
           ARRAY<VARCHAR(256)>['POWERBOX']
    UNION ALL  /* 9001182: PIMORONI LTD — 英国树莓派/嵌入式配件 */
    SELECT CAST(9001182 AS BIGINT), 'PIMORONI', 'Pimoroni', 'PIMORONI', 'PMR',
           ARRAY<VARCHAR(256)>['PIMORONI LTD','PIMORONI']
    UNION ALL  /* 9001183: SELEC CONTROLS — 印度工业控制/电源 */
    SELECT CAST(9001183 AS BIGINT), 'SELEC CONTROLS', 'Selec', 'SELEC CONTROLS', 'SLC',
           ARRAY<VARCHAR(256)>['SELEC CONTROLS USA INC.','SELEC CONTROLS','SELEC']
    UNION ALL  /* 9001184: SYNAPSE WIRELESS — 美国无线网状网络模块 */
    SELECT CAST(9001184 AS BIGINT), 'SYNAPSE WIRELESS', 'Synapse Wireless', 'SYNAPSE WIRELESS', 'SYW',
           ARRAY<VARCHAR(256)>['SYNAPSE WIRELESS']
    UNION ALL  /* 9001185: RADIOCRAFTS AS — 挪威 RF/无线模块 */
    SELECT CAST(9001185 AS BIGINT), 'RADIOCRAFTS', 'Radiocrafts', 'RADIOCRAFTS', 'RDC',
           ARRAY<VARCHAR(256)>['RADIOCRAFTS AS','RADIOCRAFTS']
    UNION ALL  /* 9001186: SHENZHEN FEASYCOM — 蓝牙/WiFi 模块 */
    SELECT CAST(9001186 AS BIGINT), 'FEASYCOM', 'Feasycom', 'FEASYCOM', 'FSY',
           ARRAY<VARCHAR(256)>['SHENZHEN FEASYCOM CO., LTD','FEASYCOM']
    UNION ALL  /* 9001187: ENEDO — 芬兰/意大利工业电源（原 Efore/Powernet） */
    SELECT CAST(9001187 AS BIGINT), 'ENEDO', 'Enedo', 'ENEDO', 'END',
           ARRAY<VARCHAR(256)>['ENEDO']
    UNION ALL  /* 9001188: L-COM — 美国连接/网络器件 */
    SELECT CAST(9001188 AS BIGINT), 'L-COM', 'L-com', 'L-COM', 'LCM',
           ARRAY<VARCHAR(256)>['L-COM']
    UNION ALL  /* 9001189: TOTAL POWER INTERNATIONAL — 模块电源 */
    SELECT CAST(9001189 AS BIGINT), 'TOTAL POWER', 'Total Power', 'TOTAL POWER', 'TTP',
           ARRAY<VARCHAR(256)>['TOTAL-POWER']
    UNION ALL  /* 9001190: PERINET — 德国工业以太网/IIoT 模块 */
    SELECT CAST(9001190 AS BIGINT), 'PERINET', 'Perinet', 'PERINET', 'PRN',
           ARRAY<VARCHAR(256)>['PERINET']
    UNION ALL  /* 9001191: VECTOR ELECTRONICS — 美国原型板/机箱 */
    SELECT CAST(9001191 AS BIGINT), 'VECTOR ELECTRONICS', 'Vector Electronics', 'VECTOR ELECTRONICS', 'VEC',
           ARRAY<VARCHAR(256)>['VECTOR ELECTRONICS']
) s
WHERE NOT EXISTS (
    SELECT 1 FROM test_dim.dim_std_brand old WHERE old.brand_id_std = s.brand_id_std
)
AND NOT EXISTS (  /* 生产已有同名规范条目则不自建新号，改由「迭代轮4 Step 0a」按生产 id 回灌 */
    SELECT 1 FROM dim.dim_std_brand pr WHERE UPPER(TRIM(pr.name)) = UPPER(TRIM(s.name))
);

/* Step 2b: 已有品牌追加 related_words */

/* Advanced Energy (1498548520179789825)：SL Power 无后缀变体 SLPOWER / SL POWER */
UPDATE test_dim.dim_std_brand SET related_words = array_append(related_words, 'SLPOWER'), update_at = CURRENT_TIMESTAMP()
WHERE brand_id_std = 1498548520179789825 AND NOT array_contains(COALESCE(related_words, CAST(ARRAY<VARCHAR(256)>[] AS ARRAY<VARCHAR(256)>)), 'SLPOWER');
UPDATE test_dim.dim_std_brand SET related_words = array_append(related_words, 'SL POWER'), update_at = CURRENT_TIMESTAMP()
WHERE brand_id_std = 1498548520179789825 AND NOT array_contains(COALESCE(related_words, CAST(ARRAY<VARCHAR(256)>[] AS ARRAY<VARCHAR(256)>)), 'SL POWER');

/* Triad Magnetics (9001172，本脚本 Step 1 新增)：TRIAD 无后缀 */
UPDATE test_dim.dim_std_brand SET related_words = array_append(related_words, 'TRIAD'), update_at = CURRENT_TIMESTAMP()
WHERE brand_id_std = 9001172 AND NOT array_contains(COALESCE(related_words, CAST(ARRAY<VARCHAR(256)>[] AS ARRAY<VARCHAR(256)>)), 'TRIAD');

/* Lantronix (9000304)：LANTRONIX, INC. */
UPDATE test_dim.dim_std_brand SET related_words = array_append(related_words, 'LANTRONIX, INC.'), update_at = CURRENT_TIMESTAMP()
WHERE brand_id_std = 9000304 AND NOT array_contains(COALESCE(related_words, CAST(ARRAY<VARCHAR(256)>[] AS ARRAY<VARCHAR(256)>)), 'LANTRONIX, INC.');

/* METZ CONNECT (1443490700350820353)：METZ CONNECT USA INC. */
UPDATE test_dim.dim_std_brand SET related_words = array_append(related_words, 'METZ CONNECT USA INC.'), update_at = CURRENT_TIMESTAMP()
WHERE brand_id_std = 1443490700350820353 AND NOT array_contains(COALESCE(related_words, CAST(ARRAY<VARCHAR(256)>[] AS ARRAY<VARCHAR(256)>)), 'METZ CONNECT USA INC.');

/* 台湾光宝-LITEON (1443490693442801671)：LITEON POWER */
UPDATE test_dim.dim_std_brand SET related_words = array_append(related_words, 'LITEON POWER'), update_at = CURRENT_TIMESTAMP()
WHERE brand_id_std = 1443490693442801671 AND NOT array_contains(COALESCE(related_words, CAST(ARRAY<VARCHAR(256)>[] AS ARRAY<VARCHAR(256)>)), 'LITEON POWER');

/* ============================================================
 * 迭代轮3：全量长尾品牌（前两轮重跑后剩余约 65 个，逐一映射）
 *   原则：原始数据有品牌即映射；指向不明者已上网查证（见下方注释）。
 * ============================================================ */

/* Step 1c: 新增品牌（manual_extra 9001192–9001255） */
INSERT INTO test_dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, related_words, state, source, create_at, update_at)
SELECT s.brand_id_std, s.name, s.brand_zh, s.brand_en, s.abbr, s.related_words,
       1, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
FROM (
    SELECT CAST(9001192 AS BIGINT) brand_id_std, 'DIAMOND SYSTEMS' name, 'Diamond Systems' brand_zh, 'DIAMOND SYSTEMS' brand_en, 'DMS' abbr,
           ARRAY<VARCHAR(256)>['DIAMOND SYSTEMS'] related_words  /* 美国嵌入式 SBC/PC104 */
    UNION ALL SELECT CAST(9001193 AS BIGINT), 'FDK', '富士达-FDK', 'FDK', 'FDK',
           ARRAY<VARCHAR(256)>['FDK AMERICA, INC.','FDK AMERICA','FDK']  /* 富士通系 电池/磁性/电源 */
    UNION ALL SELECT CAST(9001194 AS BIGINT), 'CAMDENBOSS', 'CamdenBoss', 'CAMDENBOSS', 'CMB',
           ARRAY<VARCHAR(256)>['CAMDENBOSS LTD','CAMDENBOSS']  /* 英国机壳/端子 */
    UNION ALL SELECT CAST(9001195 AS BIGINT), 'PERLE SYSTEMS', 'Perle', 'PERLE SYSTEMS', 'PRL',
           ARRAY<VARCHAR(256)>['PERLE SYSTEMS']  /* 加拿大工业网络/串口服务器 */
    UNION ALL SELECT CAST(9001196 AS BIGINT), 'POWEREX', 'Powerex', 'POWEREX', 'PWX',
           ARRAY<VARCHAR(256)>['POWEREX INC.','POWEREX']  /* 美国功率半导体/模块 */
    UNION ALL SELECT CAST(9001197 AS BIGINT), 'FANSTEL', 'Fanstel', 'FANSTEL', 'FNS',
           ARRAY<VARCHAR(256)>['FANSTEL CORP.','FANSTEL']  /* 美国 BLE/无线模块 */
    UNION ALL SELECT CAST(9001198 AS BIGINT), 'SIRETTA', 'Siretta', 'SIRETTA', 'SRT',
           ARRAY<VARCHAR(256)>['SIRETTA LTD','SIRETTA']  /* 英国蜂窝调制解调器/天线 */
    UNION ALL SELECT CAST(9001199 AS BIGINT), 'ERP POWER', 'ERP Power', 'ERP POWER', 'ERP',
           ARRAY<VARCHAR(256)>['ERP POWER, LLC','ERP POWER']  /* 美国 LED 驱动/电源 */
    UNION ALL SELECT CAST(9001200 AS BIGINT), 'NEXCOBOT', 'NexCOBOT', 'NEXCOBOT', 'NCB',
           ARRAY<VARCHAR(256)>['NEXCOBOT CO., LTD.','NEXCOBOT']  /* NEXCOM 机器人控制子公司 */
    UNION ALL SELECT CAST(9001201 AS BIGINT), 'MURRELEKTRONIK', 'Murrelektronik', 'MURRELEKTRONIK', 'MUR',
           ARRAY<VARCHAR(256)>['MURRELEKTRONIK, INC','MURRELEKTRONIK']  /* 德国工业连接/电源 */
    UNION ALL SELECT CAST(9001202 AS BIGINT), 'BEACON EMBEDDEDWORKS', 'Beacon EmbeddedWorks', 'BEACON EMBEDDEDWORKS', 'BEW',
           ARRAY<VARCHAR(256)>['BEACON EMBEDDEDWORKS']  /* 原 Logic PD，SoM/嵌入式 */
    UNION ALL SELECT CAST(9001203 AS BIGINT), 'CELDUC', 'celduc', 'CELDUC', 'CLD',
           ARRAY<VARCHAR(256)>['CELDUC INC.','CELDUC']  /* 法国固态继电器/传感 */
    UNION ALL SELECT CAST(9001204 AS BIGINT), 'DEEPWAVE DIGITAL', 'Deepwave Digital', 'DEEPWAVE DIGITAL', 'DWV',
           ARRAY<VARCHAR(256)>['DEEPWAVE DIGITAL']  /* 美国 AI 软件无线电(AIR-T) */
    UNION ALL SELECT CAST(9001205 AS BIGINT), 'C-TON INDUSTRIES', 'C-TON', 'C-TON INDUSTRIES', 'CTN',
           ARRAY<VARCHAR(256)>['C-TON INDUSTRIES']  /* 美国电源模块 */
    UNION ALL SELECT CAST(9001206 AS BIGINT), 'DRESDEN ELEKTRONIK', 'dresden elektronik', 'DRESDEN ELEKTRONIK', 'DRE',
           ARRAY<VARCHAR(256)>['DRESDEN ELEKTRONIK']  /* 德国 Zigbee/无线模块 */
    UNION ALL SELECT CAST(9001207 AS BIGINT), 'MAXTENA', 'Maxtena', 'MAXTENA', 'MXT',
           ARRAY<VARCHAR(256)>['MAXTENA INC','MAXTENA']  /* 美国 GNSS/卫星天线 */
    UNION ALL SELECT CAST(9001208 AS BIGINT), 'SILVERTEL', 'Silvertel', 'SILVERTEL', 'SLV',
           ARRAY<VARCHAR(256)>['SILVERTEL']  /* 英国 PoE 模块 */
    UNION ALL SELECT CAST(9001209 AS BIGINT), 'SMART SENSOR DEVICES', 'Smart Sensor Devices', 'SMART SENSOR DEVICES', 'SSD',
           ARRAY<VARCHAR(256)>['SMART SENSOR DEVICES']  /* 瑞典 BLE 模块 */
    UNION ALL SELECT CAST(9001210 AS BIGINT), 'POWERCAST', 'Powercast', 'POWERCAST', 'PWC',
           ARRAY<VARCHAR(256)>['POWERCAST CORPORATION','POWERCAST']  /* 美国无线能量采集 */
    UNION ALL SELECT CAST(9001211 AS BIGINT), 'HMS NETWORKS', 'HMS Networks', 'HMS NETWORKS', 'HMS',
           ARRAY<VARCHAR(256)>['HMS NETWORKS']  /* 瑞典工业通信(Anybus) */
    UNION ALL SELECT CAST(9001212 AS BIGINT), 'COREHW', 'CoreHW', 'COREHW', 'CHW',
           ARRAY<VARCHAR(256)>['COREHW SEMICONDUCTOR LTD','COREHW']  /* 芬兰定位 IC */
    UNION ALL SELECT CAST(9001213 AS BIGINT), 'HUBER+SUHNER', 'Huber+Suhner', 'HUBER+SUHNER', 'HBS',
           ARRAY<VARCHAR(256)>['HUBER+SUHNER, INC.','HUBER+SUHNER']  /* 瑞士 RF/连接器 */
    UNION ALL SELECT CAST(9001214 AS BIGINT), 'RAYTAC', 'Raytac', 'RAYTAC', 'RYT',
           ARRAY<VARCHAR(256)>['RAYTAC']  /* 台湾 BLE 模块 */
    UNION ALL SELECT CAST(9001215 AS BIGINT), 'ILLUMRA', 'ILLUMRA', 'ILLUMRA', 'ILU',
           ARRAY<VARCHAR(256)>['ILLUMRA']  /* 美国能量采集无线开关 */
    UNION ALL SELECT CAST(9001216 AS BIGINT), 'INVENTEK SYSTEMS', 'Inventek Systems', 'INVENTEK SYSTEMS', 'IVK',
           ARRAY<VARCHAR(256)>['INVENTEK SYSTEMS']  /* 美国 WiFi/GNSS 模块 */
    UNION ALL SELECT CAST(9001217 AS BIGINT), 'THINXTRA', 'Thinxtra', 'THINXTRA', 'THX',
           ARRAY<VARCHAR(256)>['THINXTRA SOLUTIONS LIMITED','THINXTRA']  /* Sigfox IoT */
    UNION ALL SELECT CAST(9001218 AS BIGINT), 'TEKTELIC', 'Tektelic', 'TEKTELIC COMMUNICATIONS', 'TKT',
           ARRAY<VARCHAR(256)>['TEKTELIC COMMUNICATIONS INC.','TEKTELIC']  /* 加拿大 LoRaWAN */
    UNION ALL SELECT CAST(9001219 AS BIGINT), 'ENOCEAN', 'EnOcean', 'ENOCEAN', 'ENO',
           ARRAY<VARCHAR(256)>['ENOCEAN']  /* 德国能量采集无线 */
    UNION ALL SELECT CAST(9001220 AS BIGINT), 'KUNBUS', 'KUNBUS', 'KUNBUS', 'KBS',
           ARRAY<VARCHAR(256)>['KUNBUS GMBH','KUNBUS']  /* 德国工业网关/RevPi */
    UNION ALL SELECT CAST(9001221 AS BIGINT), 'RADIOCONTROLLI', 'Radiocontrolli', 'RADIOCONTROLLI', 'RDC2',
           ARRAY<VARCHAR(256)>['RADIOCONTROLLI']  /* 意大利 RF 模块 */
    UNION ALL SELECT CAST(9001222 AS BIGINT), 'TELIT CINTERION', 'Telit Cinterion', 'TELIT CINTERION', 'TLT',
           ARRAY<VARCHAR(256)>['TELIT CINTERION']  /* 蜂窝/IoT 模块巨头 */
    UNION ALL SELECT CAST(9001223 AS BIGINT), 'TYCON SYSTEMS', 'Tycon Systems', 'TYCON SYSTEMS', 'TYC',
           ARRAY<VARCHAR(256)>['TYCON SYSTEMS INC.','TYCON SYSTEMS']  /* 美国 PoE/太阳能 */
    UNION ALL SELECT CAST(9001224 AS BIGINT), 'VERSASENSE', 'VersaSense', 'VERSASENSE', 'VRS',
           ARRAY<VARCHAR(256)>['VERSASENSE']  /* 比利时工业 IoT */
    UNION ALL SELECT CAST(9001225 AS BIGINT), 'US ELECTRONICS', 'US Electronics', 'US ELECTRONICS', 'USE',
           ARRAY<VARCHAR(256)>['US ELECTRONICS INC.','US ELECTRONICS']
    UNION ALL SELECT CAST(9001226 AS BIGINT), 'RADIO BRIDGE', 'Radio Bridge', 'RADIO BRIDGE', 'RDB',
           ARRAY<VARCHAR(256)>['RADIO BRIDGE INC.','RADIO BRIDGE']  /* LoRaWAN 传感(MultiTech) */
    UNION ALL SELECT CAST(9001227 AS BIGINT), 'VARIOHM', 'Variohm', 'VARIOHM', 'VRH',
           ARRAY<VARCHAR(256)>['VARIOHM']  /* 英国传感器 */
    UNION ALL SELECT CAST(9001228 AS BIGINT), 'MMB NETWORKS', 'MMB Networks', 'MMB NETWORKS', 'MMB',
           ARRAY<VARCHAR(256)>['MMB NETWORKS']  /* Zigbee */
    UNION ALL SELECT CAST(9001229 AS BIGINT), 'ARTAFLEX', 'Artaflex', 'ARTAFLEX', 'ATF',
           ARRAY<VARCHAR(256)>['ARTAFLEX INC.','ARTAFLEX']  /* 加拿大无线模块 */
    UNION ALL SELECT CAST(9001230 AS BIGINT), 'ELECTRIC IMP', 'Electric Imp', 'ELECTRIC IMP', 'EIM',
           ARRAY<VARCHAR(256)>['ELECTRIC IMP INC.','ELECTRIC IMP']  /* IoT 平台(后 Twilio) */
    UNION ALL SELECT CAST(9001231 AS BIGINT), 'EM MICROELECTRONIC', '瑞士EM微电子', 'EM MICROELECTRONIC', 'EMM',
           ARRAY<VARCHAR(256)>['EM MICROELECTRONIC']  /* Swatch 系 EM Marin */
    UNION ALL SELECT CAST(9001232 AS BIGINT), 'AIRGAIN', 'Airgain', 'AIRGAIN', 'AGN',
           ARRAY<VARCHAR(256)>['AIRGAIN']  /* 美国天线 */
    UNION ALL SELECT CAST(9001233 AS BIGINT), 'CANAAN SEMICONDUCTOR', 'Canaan Semiconductor', 'CANAAN SEMICONDUCTOR', 'CNS',
           ARRAY<VARCHAR(256)>['CANAAN SEMICONDUCTOR PTY LTD','CANAAN SEMICONDUCTOR']  /* 澳洲(≠迦南/Canaan Creative) */
    UNION ALL SELECT CAST(9001234 AS BIGINT), 'IOTIZE', 'IoTize', 'IOTIZE', 'IOT',
           ARRAY<VARCHAR(256)>['IOTIZE']  /* 法国 IoT 接入模块 */
    UNION ALL SELECT CAST(9001235 AS BIGINT), 'COMPULAB', 'CompuLab', 'COMPULAB', 'CPL',
           ARRAY<VARCHAR(256)>['COMPULAB']  /* 以色列 SoM/迷你PC */
    UNION ALL SELECT CAST(9001236 AS BIGINT), 'CYTRON TECHNOLOGIES', 'Cytron', 'CYTRON TECHNOLOGIES', 'CYT',
           ARRAY<VARCHAR(256)>['CYTRON TECHNOLOGIES SDN BHD','CYTRON TECHNOLOGIES']  /* 马来西亚机器人/电子 */
    UNION ALL SELECT CAST(9001237 AS BIGINT), 'NEXAIOT', 'NexAIoT', 'NEXAIOT', 'NXA',
           ARRAY<VARCHAR(256)>['NEXAIOT CO., LTD.','NEXAIOT']  /* NEXCOM AIoT 子公司 */
    UNION ALL SELECT CAST(9001238 AS BIGINT), 'RAKWIRELESS', 'RAKwireless', 'RAKWIRELESS', 'RAK',
           ARRAY<VARCHAR(256)>['RAKWIRELESS TECHNOLOGY LIMITED','RAKWIRELESS']  /* LoRa/IoT 模块 */
    UNION ALL SELECT CAST(9001239 AS BIGINT), 'ASUS', '华硕-ASUS', 'ASUS', 'ASU',
           ARRAY<VARCHAR(256)>['ASUS']  /* 华硕 Tinker/嵌入式 */
    UNION ALL SELECT CAST(9001240 AS BIGINT), 'MYDEVICES', 'myDevices', 'MYDEVICES', 'MYD',
           ARRAY<VARCHAR(256)>['MYDEVICES, INC.','MYDEVICES']  /* IoT 平台(Cayenne) */
    UNION ALL SELECT CAST(9001241 AS BIGINT), 'MAKER EMPORIUM', 'Maker Emporium', 'MAKER EMPORIUM', 'MKE',
           ARRAY<VARCHAR(256)>['MAKER EMPORIUM LTD','MAKER EMPORIUM']
    UNION ALL SELECT CAST(9001242 AS BIGINT), 'FRIWO', 'FRIWO', 'FRIWO', 'FRW2',
           ARRAY<VARCHAR(256)>['FRIWO GERäTEBAU GMBH','FRIWO']  /* 德国电源/适配器 */
    UNION ALL SELECT CAST(9001243 AS BIGINT), 'ELECROW', 'Elecrow', 'ELECROW', 'ECR',
           ARRAY<VARCHAR(256)>['ELECROW']  /* 创客开发板 */
    UNION ALL SELECT CAST(9001244 AS BIGINT), 'VPT', 'VPT Power', 'VPT', 'VPT',
           ARRAY<VARCHAR(256)>['VPT']  /* 航空航天 DC-DC(VPT Inc.) */
    UNION ALL SELECT CAST(9001245 AS BIGINT), 'CHINFA', 'Chinfa', 'CHINFA', 'CHF',
           ARRAY<VARCHAR(256)>['CHINFA']  /* 台湾电源(Chinfa Electronics) */
    UNION ALL SELECT CAST(9001246 AS BIGINT), 'XSENS', 'Xsens-Movella', 'XSENS', 'XSN',
           ARRAY<VARCHAR(256)>['XSENS A MOVELLA BRAND','XSENS']  /* IMU/惯导 */
    UNION ALL SELECT CAST(9001247 AS BIGINT), 'PARTICLE', 'Particle', 'PARTICLE', 'PTC',
           ARRAY<VARCHAR(256)>['PARTICLE INDUSTRIES, INC.','PARTICLE INDUSTRIES','PARTICLE']  /* IoT 蜂窝模块 */
    UNION ALL SELECT CAST(9001248 AS BIGINT), 'LUMBERG AUTOMATION', 'Lumberg Automation', 'LUMBERG AUTOMATION', 'LMB',
           ARRAY<VARCHAR(256)>['LUMBERG AUTOMATION']  /* Belden 系工业连接 */
    UNION ALL SELECT CAST(9001249 AS BIGINT), 'SFERA LABS', 'Sfera Labs', 'SFERA LABS', 'SFL',
           ARRAY<VARCHAR(256)>['SFERA LABS']  /* 意大利工业树莓派 */
    UNION ALL SELECT CAST(9001250 AS BIGINT), 'PULS', 'PULS', 'PULS', 'PLS2',
           ARRAY<VARCHAR(256)>['PULS, LP','PULS']  /* 德国 DIN 导轨电源 */
    UNION ALL SELECT CAST(9001251 AS BIGINT), 'ZABER TECHNOLOGIES', 'Zaber', 'ZABER TECHNOLOGIES', 'ZBR',
           ARRAY<VARCHAR(256)>['ZABER TECHNOLOGIES']  /* 加拿大运动控制 */
    UNION ALL SELECT CAST(9001252 AS BIGINT), 'YIC', '裕中-YIC', 'YIC', 'YICc',
           ARRAY<VARCHAR(256)>['YIC']  /* Yuechung International 台湾 GNSS 厂(查证：MPN GT/GR-502MGG) */
    UNION ALL SELECT CAST(9001253 AS BIGINT), 'PEAK ELECTRONICS', 'PEAK electronics', 'PEAK ELECTRONICS', 'PKE',
           ARRAY<VARCHAR(256)>['PEAK']  /* 德国 PEAK electronics GmbH 电源(查证：PSD1-A 系列；≠3PEAK/PEAK-System) */
    UNION ALL SELECT CAST(9001254 AS BIGINT), 'DECIDE4ACTION', 'Decide4Action', 'DECIDE4ACTION', 'D4A',
           ARRAY<VARCHAR(256)>['DECIDE4ACTION']  /* 美国制造智能/硬件(查证：180086 等的厂商) */
    UNION ALL SELECT CAST(9001255 AS BIGINT), 'DATAWAVE', 'Datawave Wireless', 'DATAWAVE', 'DTW',
           ARRAY<VARCHAR(256)>['DATAWAVE LLC','DATAWAVE']  /* 查证：WB-USB-24HP 802.15.4 桥 */
) s
WHERE NOT EXISTS (
    SELECT 1 FROM test_dim.dim_std_brand old WHERE old.brand_id_std = s.brand_id_std
)
AND NOT EXISTS (  /* 生产已有同名规范条目则不自建新号，改由「迭代轮4 Step 0a」按生产 id 回灌 */
    SELECT 1 FROM dim.dim_std_brand pr WHERE UPPER(TRIM(pr.name)) = UPPER(TRIM(s.name))
);

/* Step 2c: 已有品牌追加 related_words（含 DCOMPONENTS→Aimtec 渠道归并） */

/* Aimtec (9001142)：DCOMPONENTS 为 Aimtec 授权分销商，MPN AM15E/AMSR3/AMES600 均 Aimtec（查证） */
UPDATE test_dim.dim_std_brand SET related_words = array_append(related_words, 'DCOMPONENTS'), update_at = CURRENT_TIMESTAMP()
WHERE brand_id_std = 9001142 AND NOT array_contains(COALESCE(related_words, CAST(ARRAY<VARCHAR(256)>[] AS ARRAY<VARCHAR(256)>)), 'DCOMPONENTS');

/* 安费诺-Amphenol (1443490699323215875)：AMPHENOL PCTEL（Amphenol 收购的天线品牌） */
UPDATE test_dim.dim_std_brand SET related_words = array_append(related_words, 'AMPHENOL PCTEL'), update_at = CURRENT_TIMESTAMP()
WHERE brand_id_std = 1443490699323215875 AND NOT array_contains(COALESCE(related_words, CAST(ARRAY<VARCHAR(256)>[] AS ARRAY<VARCHAR(256)>)), 'AMPHENOL PCTEL');

/* 伊顿-eaton (1443490691630862341)：EATON ELECTRICAL */
UPDATE test_dim.dim_std_brand SET related_words = array_append(related_words, 'EATON ELECTRICAL'), update_at = CURRENT_TIMESTAMP()
WHERE brand_id_std = 1443490691630862341 AND NOT array_contains(COALESCE(related_words, CAST(ARRAY<VARCHAR(256)>[] AS ARRAY<VARCHAR(256)>)), 'EATON ELECTRICAL');

/* NVE (1443490695728697350)：NVE CORP/ISOLATION PRODUCTS */
UPDATE test_dim.dim_std_brand SET related_words = array_append(related_words, 'NVE CORP/ISOLATION PRODUCTS'), update_at = CURRENT_TIMESTAMP()
WHERE brand_id_std = 1443490695728697350 AND NOT array_contains(COALESCE(related_words, CAST(ARRAY<VARCHAR(256)>[] AS ARRAY<VARCHAR(256)>)), 'NVE CORP/ISOLATION PRODUCTS');

/* THine (1443490695925829638)：THINE SOLUTIONS, INC. */
UPDATE test_dim.dim_std_brand SET related_words = array_append(related_words, 'THINE SOLUTIONS, INC.'), update_at = CURRENT_TIMESTAMP()
WHERE brand_id_std = 1443490695925829638 AND NOT array_contains(COALESCE(related_words, CAST(ARRAY<VARCHAR(256)>[] AS ARRAY<VARCHAR(256)>)), 'THINE SOLUTIONS, INC.');

/* 东光-TOKO (9000006)：TOKO AMERICA INC. */
UPDATE test_dim.dim_std_brand SET related_words = array_append(related_words, 'TOKO AMERICA INC.'), update_at = CURRENT_TIMESTAMP()
WHERE brand_id_std = 9000006 AND NOT array_contains(COALESCE(related_words, CAST(ARRAY<VARCHAR(256)>[] AS ARRAY<VARCHAR(256)>)), 'TOKO AMERICA INC.');

/* ============================================================
 * 迭代轮4：测试表向生产对齐（2026-06-24）
 *   背景与动机：
 *   (a) 共享表 test_dim.dim_std_brand 于 2026-06-24 被整体重灌为比生产少 137 行的不完整快照，
 *       把 6/23 本已与生产同步、且不在本脚本中的品牌刷掉，致 system_module 约 4700 件 brandid 回退为空。
 *   (b) 本脚本早期 9001140+ 段曾为「生产其实已有」的品牌另发新号（25 个，如 Ezurio 9001163 vs 生产 9001014），
 *       造成 test 与生产 id 双轨。
 *   对齐策略：凡生产 dim.dim_std_brand 已有的品牌，一律按生产 brand_id_std 回灌（不再用本脚本新号）；
 *       本脚本 9001140+ 段只保留「生产没有」的 system_module 专属品牌（已在上方各 Step 的 INSERT
 *       WHERE 加 “生产无同名” 守卫，自动跳过这 25 个，不再自建新号）。
 *   一次性清理（见 reports 记录，脚本不含 DELETE）：删除 test 中这 25 个旧 9001140+ 行及历史 9000608。
 *
 *   Step 0a：按生产规范 id 回灌（37 个 = 12 个重载丢失缺口 + 25 个原双轨品牌），幂等 NOT EXISTS。
 * ============================================================ */
INSERT INTO test_dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, related_words, state, source, create_at, update_at)
SELECT pr.brand_id_std, pr.name, pr.brand_zh, pr.brand_en, pr.abbr, pr.related_words, pr.state, pr.source,
       CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
FROM dim.dim_std_brand pr
WHERE pr.brand_id_std IN (
    /* — 重载丢失的 12 个缺口品牌（Advantech 不在此，见 Step 0b 合并到规范 id）— */
    9001045,             /* SolidRun LTD */
    9001027,             /* Red Lion Controls */
    9001049,             /* Olimex LTD */
    9000591,             /* Lantronix, Inc. */
    1970709309728698510, /* Terasic Inc. */
    1970709309728698475, /* NetBurner Inc. */
    9000605,             /* DFRobot */
    9001028,             /* SICK, Inc. */
    9001129,             /* Seco */
    9000617,             /* NI */
    9001118,             /* Innodisk USA Corporation */
    9001135,             /* Eaton Tripp Lite */
    /* — 原 9001140+ 与生产同名不同 id 的 25 个，改用生产 id — */
    9001020,             /* AIRGAIN */
    1970709309728698515, /* DECIDE4ACTION */
    1970709309728698400, /* DEEPWAVE DIGITAL */
    1970709309728698415, /* DRESDEN ELEKTRONIK */
    1970709309728698495, /* ELECROW */
    9000594,             /* EM MICROELECTRONIC */
    9000589,             /* ENOCEAN */
    9001014,             /* EZURIO */
    9001016,             /* FREEWAVE TECHNOLOGIES */
    9001061,             /* HMS NETWORKS */
    1970709309728698380, /* ILLUMRA */
    9000600,             /* INVENTEK SYSTEMS */
    1970709309728698490, /* IOTIZE */
    9000566,             /* L-COM */
    1970709309728698440, /* MMB NETWORKS */
    9000611,             /* POLOLU */
    9000573,             /* RADIOCONTROLLI */
    1970709309728698430, /* RAYTAC */
    9000599,             /* SIERRA WIRELESS */
    1970709309728698410, /* SMART SENSOR DEVICES */
    9001033,             /* SYNAPSE WIRELESS */
    9000570,             /* TELIT CINTERION */
    1970709309728698460, /* VARIOHM */
    1970709309728698455, /* VERSASENSE */
    9000581              /* YIC */
)
AND NOT EXISTS (SELECT 1 FROM test_dim.dim_std_brand te WHERE te.brand_id_std = pr.brand_id_std);

/* Step 0b：Advantech 在生产即重复（9000608 manual_extra「Advantech Corporation」与 1498507150190768129
 *   jp_brand「研华-Advantech」）。生产侧重复无法在本流程修，故仅在 test 合并到规范 id 1498…：
 *   不引入 9000608，改把两种源写法 ADVANTECH CORPORATION / ADVANTECH CORP 挂到规范条目。 */
UPDATE test_dim.dim_std_brand SET related_words = array_append(related_words, 'ADVANTECH CORPORATION'), update_at = CURRENT_TIMESTAMP()
WHERE brand_id_std = 1498507150190768129 AND NOT array_contains(COALESCE(related_words, CAST(ARRAY<VARCHAR(256)>[] AS ARRAY<VARCHAR(256)>)), 'ADVANTECH CORPORATION');
UPDATE test_dim.dim_std_brand SET related_words = array_append(related_words, 'ADVANTECH CORP'), update_at = CURRENT_TIMESTAMP()
WHERE brand_id_std = 1498507150190768129 AND NOT array_contains(COALESCE(related_words, CAST(ARRAY<VARCHAR(256)>[] AS ARRAY<VARCHAR(256)>)), 'ADVANTECH CORP');

/* Step 0c：生产条目未覆盖的源 brandshort 变体，补到对应生产 id（幂等） */
/* Lantronix, Inc. (9000591)：DigiKey 加拿大实体「Lantronix Canada ULC」 */
UPDATE test_dim.dim_std_brand SET related_words = array_append(related_words, 'LANTRONIX CANADA ULC'), update_at = CURRENT_TIMESTAMP()
WHERE brand_id_std = 9000591 AND NOT array_contains(COALESCE(related_words, CAST(ARRAY<VARCHAR(256)>[] AS ARRAY<VARCHAR(256)>)), 'LANTRONIX CANADA ULC');
/* FREEWAVE TECHNOLOGIES (9001016)：源裸名「FREEWAVE」（生产未含） */
UPDATE test_dim.dim_std_brand SET related_words = array_append(related_words, 'FREEWAVE'), update_at = CURRENT_TIMESTAMP()
WHERE brand_id_std = 9001016 AND NOT array_contains(COALESCE(related_words, CAST(ARRAY<VARCHAR(256)>[] AS ARRAY<VARCHAR(256)>)), 'FREEWAVE');
/* SIERRA WIRELESS (9000599)：源「SIERRA WIRELESS AIRLINK」（生产未含） */
UPDATE test_dim.dim_std_brand SET related_words = array_append(related_words, 'SIERRA WIRELESS AIRLINK'), update_at = CURRENT_TIMESTAMP()
WHERE brand_id_std = 9000599 AND NOT array_contains(COALESCE(related_words, CAST(ARRAY<VARCHAR(256)>[] AS ARRAY<VARCHAR(256)>)), 'SIERRA WIRELESS AIRLINK');
