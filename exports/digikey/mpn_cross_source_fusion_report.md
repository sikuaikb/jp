# ICPDF / DigiKey 跨源 MPN 归一化与融合可行性报告

> 初版：2026-06-30　｜　**更新：2026-07-09**（阶段 2.5 补录已写入 sync 保全路径）
> 数据源：`dwd.dwd_icpdf_component_param`（7,019,307 行）、`dwd.dwd_digikey_component_param`（7,717,330 行）
> 归一化视图：`dwd.v_param_normalized`（本报告产出物，见 `sql_scripts/foundation/v_param_normalized.sql`）

---

## 1. 结论速览

| 维度 | 阶段 1（归一化后） | 阶段 2（auto+manual） | **阶段 2.5（semi 收尾，当前）** |
|---|---:|---:|---:|
| 两源总行数 | 14,736,637 | 14,736,637 | **14,736,637** |
| 跨源强匹配实体键 `(brand_id_std, mpn_std)` | 594,894 | 618,929 | **634,124** |
| 强匹配总实体数（含单源） | 11,706,458 | 12,384,284 | **12,454,641** |
| 强匹配覆盖总行数 | 12,376,548 | 13,078,741 | **13,435,690** |
| 品牌归一命中率（icpdf / digikey） | 91.75% / 88.92% | 97.44% / 93.13% | **99.98% / 99.99%** |
| `is_mpn_like=1`（可参与强匹配）占比 | icpdf 99.2% / digikey 91.2% | 同左 | 同左 |
| 未命中品牌 distinct | 1,224 | 0（误报，semi 未处理） | **6**（1,534 行，可忽略） |

**主要结论**

1. **融合价值大且可行** —— 当前 **63.4 万**个 `(brand, mpn)` 键在两源同时存在（阶段 1 为 59.5 万），强匹配样例肉眼复核 `ic_raw == dk_raw`，归一质量高。
2. **mpn 命名差异是"包装后缀 + 描述段"问题，不是 MPN 本体差异** —— ICPDF 几乎是纯 MPN（99.2% `is_mpn_like`），脏数据集中在包装后缀与 DigiKey 描述性 partno。
3. **品牌归一已基本完成** —— 经 auto 25 + manual 560 + semi 分档批量补录（别名 ~150 条、新品牌 ~530 个），命中率 icpdf **99.98%**、digikey **99.99%**。剩余 6 distinct 均为子串歧义边缘 case，合计 1,534 行。
4. **semi 638 已通过规则+联网核实自动分档** —— 无需人工逐条复核。详见 `exports/brand_supplement/brand_miss_mapping_triaged.csv`。
5. **品牌门控已打通；本专项下一步是实体融合** —— L2 宽表多数已双源（约 854 万 icpdf / 1152 万 digikey），缺 icpdf 的品类由属性 ETL 流程补齐。跨源融合专项应推进 `dws_component_entity` 生产化 + 按 `entity_id` 的字段级融合视图。

---

## 2. 两源 partno 形态对比

### 2.1 基础统计

| 指标 | ICPDF | DigiKey |
|---|---:|---:|
| 总行数 | 7,019,307 | 7,717,330 |
| partno 非空率 | 100% | 100% |
| 平均长度 | 13.98 | 15.65 |
| 最大长度 | 40 | 50 |
| 含小写字母 | 2,617 | 280,961 |
| 含空格 | 8,788 | 198,954 |
| 含斜杠 `/` | 401,725 | 252,750 |

> ICPDF partno 几乎全大写、无空格，是规整的制造商料号；DigiKey 含较多描述性 partno（电缆/连接器品类），故长度更大、含空格/小写更多。

### 2.2 包装/格式后缀分布

| 后缀模式 | ICPDF 行数 | DigiKey 行数 | 说明 |
|---|---:|---:|---|
| 括号 `(T&R)`/`(TR)`/`(T/R)` | 424,299 | — | Tape&Reel 编带包装，ICPDF 主导 |
| 尾部 `-TR`（不带括号） | 95,009 | 32,874 | 同上，写法不同 |
| 尾部 `-ND`/`#ND` | 256 | 1,471 | DigiKey 订购料号后缀 |
| 前导零 | 110,285 | — | Molex 等料号有语义，**保留** |
| 下划线 `_` | 10,306 | — | — |
| 含中文 | 2 | — | 异常值，已判 `is_mpn_like=0` |

> 注：`(QTY:xxx)` 描述段为 DigiKey 电缆类特有，归一化时单独剥离；ICPDF 不含。

### 2.3 ICPDF partno 随机样例

```
MLL5231A-1TRE3          MICROSEMI    XC6115A433ML            TOREX
IMU01020.2NHBL3.3N      VISHAY       74HCT533DB              NXP
LTC1415CSW#TR           Linear       DSPIC33FJ16GS402-I/MM   MICROCHIP
MAX6891ETP-T            MAXIM        XC2VP30-6FG676C         XILINX
M83723/73R1610Y-LC      TE           1633767-4               TE
```

### 2.4 DigiKey partno 随机样例（含描述性 partno）

```
RG213-TF-UM(QTY:30ft)          McGill Microwave   电缆，非纯 MPN
JTN00RE-10-13PA(SR)            AMPHENOL AEROSPACE 连接器插座变体
6QCD-078-01.73-SBR-TED-1-S     Samtec Inc.        矩形电缆组件
1N6004B BK PBFREE              Central            含空格描述
5300-07-TR-RC                  Bourns Inc.        含 -TR 尾缀
```

---

## 3. mpn_std 归一化规则

视图 `dwd.v_param_normalized` 对两源统一执行链式归一（顺序敏感）：

| 步骤 | 规则 | 作用 |
|---|---|---|
| 1 | `UPPER(TRIM(partno))` | 统一大写、去首尾空格 |
| 2 | 去 `\(QTY:[^)]*\)` | 剥离 DigiKey 电缆数量/长度描述段 |
| 3 | 去 `\((T&R|TR|T/R)\)` | 剥离括号包装段（ICPDF 主导） |
| 4 | 去尾部 `(#TR-ND|-TR-ND|#TR|-TR|-T&R|-T/R|-ND|#ND)$` | 第一层包装后缀 |
| 5 | 去尾部 `(#TR|-TR|-T&R|-T/R|-ND|#ND)$` | 第二层兜底（复合后缀剥离后露出第二层） |
| 6 | 去尾部 `[-#/ ]+$` | 清理脏尾分隔符（如 `CB182G105K--`） |
| 7 | `TRIM` | 收尾 |

**刻意保留**（不清洗）：
- 前导零：`0639112900` 等 Molex 料号前导零有语义
- 中间的 `/`：军工料号 `M39003/01-5249` 的 `/` 是料号一部分
- 中间字符：严格行尾 `$` 锚定，不误删 `MSP430FR2355TRHAR` 中的 `TR`

**`is_mpn_like` 标记**：归一后 `mpn_std` 若含空格/中文/括号 → `0`，下游强匹配时降权或不参与。

---

## 4. mpn_std 规则质量抽检（方案 + 结果）

> 抽检时间：2026-07-09　｜　脚本：`sql_scripts/test/_qa_mpn_std_rules.py`  
> 口径：在 `dwd.v_param_normalized` 上做边界用例 + 源内碰撞 + 跨源 raw 一致性 + 假阳性/假阴性代理。

### 4.1 抽检方案（四层）

| 层 | 目的 | 方法 |
|---|---|---|
| **A. 边界用例** | 规则不误伤 / 该剥的剥掉 | 固定 10 条 `partno_raw → expected mpn_std`，对视图实测 |
| **B. 源内碰撞率** | 同 `(brand_id_std, mpn_std)` 是否过度合并 | 每源统计 multi-row key 占比、avg/max 行数 |
| **C. 跨源 raw 一致性** | 强匹配键是否真是同料 | 跨源 JOIN 后比较 `ic_raw` vs `dk_raw` vs `mpn_std` |
| **D. 假阳性 / 假阴性代理** | 误并 / 漏并 | FP：两源 raw 都≠std 且互不相同；FN：`ic.mpn_std = UPPER(dk.partno_raw)` 但 `dk.mpn_std` 不同 |

设计原则：**宁可少匹配，也不把不同料并成一个 entity**（行尾锚定、不剥中间 TR、连接器变体走 `is_mpn_like=0`）。

### 4.2 边界用例结果（层 A）

| partno_raw | mpn_std | 结果 |
|---|---|---|
| `MSP430FR2355TRHAR` | `MSP430FR2355TRHAR` | ✅ 中间 TR 保留 |
| `LTC4244CGN-1#TR` | `LTC4244CGN-1` | ✅ 尾部 #TR 去除 |
| `LTC2614CGN-1#TRPBF` | `LTC2614CGN-1#TRPBF` | ✅ 已知遗留行为（中间 #TR 不剥） |
| `TSM-110-01-T-DH-P-TR` | `TSM-110-01-T-DH-P` | ✅ 尾部 -TR 去除 |
| `M39003/01-5249` | `M39003/01-5249` | ✅ 军工料号 / 保留 |
| `0639112900` | `0639112900` | ✅ 前导零保留 |
| `CB182G105K--` | `CB182G105K` | ✅ 脏尾 -- 清理 |
| `MAX21000+` | `MAX21000+` | ✅ + 是 Maxim lead-free 标识保留 |
| `MX5KP11E3/TR12` | `MX5KP11E3/TR12` | ✅ 中间 /TR 保留 |
| `LMR-400-LSZH-NM-UF(QTY:30ft)` | `LMR-400-LSZH-NM-UF` | ✅ QTY 描述段剥离 |

**边界用例：10 / 10 PASS。**

### 4.3 量化结果（层 B–D，2026-07-09）

| 指标 | digikey | icpdf |
|---|---:|---:|
| 总行数 | 7,717,330 | 7,019,307 |
| `is_mpn_like=1` | 7,040,116（91.22%） | 6,964,968（99.23%） |
| 强匹配可参与行（品牌命中 ∩ mpn_like） | 6,788,582 | 6,963,872 |
| 源内唯一键数 | 6,490,533 | 6,903,045 |
| 源内 multi-row 键占比 | **0.362%** | **0.868%** |
| 平均每键行数 | **1.0459** | **1.0088** |
| 归一化实际改写比例（raw≠mpn_std） | **4.99%** | **1.44%** |

**跨源强匹配（634,124 键）raw 关系：**

| raw 关系 | 键数 | 占比 | 含义 |
|---|---:|---:|---|
| `exact`（两源 raw 完全一致） | 630,863 | **99.49%** | 同料，规则未改写或两边同样干净 |
| `one_eq_std`（一侧 = mpn_std） | 3,261 | **0.51%** | 正常：一侧带包装、一侧已是干净 MPN |
| `diff_raw` 且两侧都≠std（硬假阳性候选） | **0** | 0% | 未见「两源 raw 都改过且互不相同却并上」 |

**假阳性 / 假阴性代理：**

| 探针 | 结果 |
|---|---|
| FP 硬候选（两源 raw 都≠std 且互不相同） | **0** |
| FN 代理（`ic.mpn_std = UPPER(dk.partno_raw)` 但 `dk.mpn_std` 不同） | **0 对 / 0 键** |
| 已知遗留 `#TRPBF` | 8,516 行 / 6,955 distinct mpn_std（故意不剥中间 #TR，避免误并） |

### 4.4 抽检结论

1. **规则适合做跨源 SKU 键** —— 跨源并上的键中 **99.49%** 两源原始 partno 完全一致；硬假阳性候选为 0。
2. **改写面很窄** —— 只动 digikey ~5%、icpdf ~1.4% 的行，主要是包装后缀，不是大面积改写料号。
3. **源内碰撞可控** —— 平均每键约 1.01–1.05 行；multi-row 键 <1%，无需复杂去重。
4. **已知遗留不破坏强匹配** —— ADI `#TRPBF` 等中间复合后缀不进通用链；若以后要抬召回，再建 `dim_mpn_brand_specific_suffix` 按品牌精确替换。

> 复跑：`python sql_scripts/test/_qa_mpn_std_rules.py`

---

## 5. 跨源匹配规模

### 5.1 视图产出

| data_source | rows | mpn_std 非空 | 品牌命中 | `is_mpn_like=1` |
|---|---:|---:|---:|---:|
| icpdf | 7,019,307 | 7,019,307 | 6,440,031 (91.75%) | 6,964,968 (99.2%) |
| digikey | 7,717,330 | 7,717,330 | 6,600,509 (88.92%) | 7,040,114 (91.2%) |

### 5.2 强匹配键规模（`is_mpn_like=1` 且品牌命中）

| 指标 | 值 |
|---|---:|
| icpdf 唯一键 `(brand_id_std, mpn_std)` | 6,328,717 |
| digikey 唯一键 | 5,972,635 |
| **跨源强匹配键** | **594,894** |
| 覆盖 icpdf 行数 | 603,597 |
| 覆盖 digikey 行数 | 600,160 |
| **可融合总行数** | **1,203,757** |
| 平均每键 icpdf 行数 | 1.01 |
| 平均每键 digikey 行数 | 1.01 |

> 平均每键 1.01 行 → 绝大多数 `(brand, mpn)` 在每源内部唯一，匹配精度高，无需复杂去重。

### 5.3 强匹配样例（肉眼复核，全部 `ic_raw == dk_raw`）

| brand_std | mpn_std | icpdf_raw | digikey_raw |
|---|---|---|---|
| 摩托罗拉-Motorola | 1N4370ARL | 1N4370ARL | 1N4370ARL |
| CHEMI-CON-黑金刚 | EKMQ100ELL102MJC5S | EKMQ100ELL102MJC5S | EKMQ100ELL102MJC5S |
| Pasternack | PE3498-12 | PE3498-12 | PE3498-12 |
| Aimtec | AM2D-0524SZ | AM2D-0524SZ | AM2D-0524SZ |
| Banner Engineering | WLS28-2XW710XPB | WLS28-2XW710XPB | WLS28-2XW710XPB |
| Advanced Thermal Solutions | ATS-08G-30-C1-R0 | ATS-08G-30-C1-R0 | ATS-08G-30-C1-R0 |

---

## 6. 命名差异根因分类

| 根因 | 影响规模 | 处理方式 | 状态 |
|---|---|---|---|
| 包装后缀 `#TR`/`-TR`/`(T&R)` | ~55 万行 | 归一化剥离 | ✅ 已解决 |
| DigiKey 描述段 `(QTY:xxx)` | 数万行（电缆类） | 归一化剥离 + `is_mpn_like=0` 降权 | ✅ 已解决 |
| DigiKey 连接器插座变体 `(SR)`/`(416)` | 数万行 | `is_mpn_like=0`，不参与强匹配 | ⚠️ 保守降权，后续可按品牌精确匹配 |
| ADI 复合后缀 `#TRPBF`/`#PBF` | 数千行 | 通用归一不动，留品牌特例表 | ⚠️ 待补 |
| 品牌未命中（小众/长尾） | icpdf 58 万 / digikey 111 万 | 补 `dim_std_brand` 别名/新品牌 | ✅ 阶段 2.5 已完成（命中率→99.98%/99.99%，剩 6 distinct） |
| 跨源 `id` 体系不同 | 全量 | 建 `dws_component_entity` 映射层 | ✅ `test_dws` 已装数（13,435,690 行 / 622,179 跨源实体） |

---

## 7. 阶段 2 详细：品牌补录与强匹配实体层

### 7.1 未命中品牌摸底

对 `dwd.v_param_normalized` 中 `brand_id_std IS NULL` 的行按 `UPPER(TRIM(brandshort_raw))` 去重，得到 **1,224 个未命中品牌**。用 Python 端做字符串匹配（去公司后缀 + 包含 + token 重叠），分三档：

| 档 | 品牌数 | 覆盖行数 | 置信度 | 处理方式 |
|---|---:|---:|---|---|
| auto（去后缀精确命中已有品牌） | 25 | 163,128 | ≥0.95 | 直接补 `related_words` 别名 |
| semi（有候选但需人工复核） | 638 | 687,799 | 0.6–0.8 | 留人工 review CSV，噪声大不自动执行 |
| manual（无候选，真新品牌） | 560 | 549,267 | 0 | 以 `manual_extra` 段新增品牌 |

### 7.2 auto 25 条安全别名（已执行）

经"去公司/业务后缀后精确命中 `brand_en`/`abbr`/`related_words`"匹配，25 个高置信度别名补录到 `dim.dim_std_brand.related_words`。Top 样例：

| 未命中 brand_key | 命中已有品牌 | 匹配方式 | 覆盖行数 |
|---|---|---|---:|
| `TE APPLICATION TOOLING` | TE Energy & Utilities | 去后缀命中 abbr | 53,101 |
| `CREE LED` | 科锐-CREE | 去业务后缀 LED | 38,814 |
| `BRADY CORPORATION` | 贝迪-Brady | 去公司后缀 | 28,828 |
| `COSEL USA, INC.` | Cosel | 去地理+公司后缀 | 11,148 |
| `SAMSUNG SEMICONDUCTOR, INC.` | 三星-SAMSUNG | 去业务+公司后缀 | 10,560 |
| `RADIALL USA, INC.` | 雷迪埃-Radiall | 去地理+公司后缀 | 9,607 |
| `NEC CORPORATION` | 日电电子-NEC | 去公司后缀 | 20 |
| `MARVELL SEMICONDUCTOR, INC.` | 迈威-MARVELL | 去业务+公司后缀 | 7 |

SQL：`sql_scripts/test/brand_supplement/dim_std_brand_supplement_cross_source.sql`（`INSERT ... SELECT` 全 17 列 + `array_concat` 追加 + `NOT EXISTS` 幂等守卫，已执行到 dim 生产库）。

### 7.3 manual 560 个真新品牌（已执行）

manual 档是自动匹配无候选的真新品牌，以 `manual_extra` 段（`brand_id_std` 9,001,265–9,001,824）补录。Top 样例（均合法独立品牌）：

| brand_key | raw_sample | 覆盖行数 | 业务领域 |
|---|---|---:|---|
| `MTRONPTI` | MTRONPTI | 137,708 | 晶振 |
| `BIVAR INC.` | Bivar Inc. | 38,777 | LED 安装支架 |
| `EUROQUARTZ` | EUROQUARTZ | 34,668 | 晶振 |
| `SSDI` | SSDI | 22,901 | 固态器件 |
| `CRYDOM` | CRYDOM | 10,321 | 继电器 |
| `SYNQOR` | SYNQOR | 4,793 | 电源模块 |
| `XPPOWER` | XPPOWER | 7,014 | 电源 |

SQL：`sql_scripts/test/brand_supplement/dim_std_brand_manual_extra_cross_source.sql`（`INSERT ... SELECT FROM UNION ALL 派生表 + ROW_NUMBER 分配 id + NOT EXISTS 幂等`，已执行到 dim 生产库）。

### 7.4 `dws_component_entity` 强匹配实体表

建在 `test_dws` schema，PK `(entity_id, data_source, source_id)`，`entity_id = xx_hash3_64(brand_id_std || mpn_std)`。装数条件：`is_mpn_like=1` 且 `brand_id_std IS NOT NULL`。`is_primary` 按 `data_source='digikey' 优先、source_id 升序` 选锚点行。

### 7.5 阶段 2 量化收益

| 指标 | 阶段 1 | +auto 25 | +manual 560 | 累计增量 |
|---|---:|---:|---:|---:|
| 跨源强匹配实体 | 594,894 | 618,920 | **618,929** | +24,035 |
| 强匹配总实体 | 11,706,458 | 11,845,339 | **12,384,284** | +677,826 |
| 强匹配总行数 | 12,376,548 | 12,539,483 | **13,078,741** | +702,193 |
| DigiKey 品牌命中率 | 88.92% | 91.11% | **93.13%** | +4.21pp |
| ICPDF 品牌命中率 | 91.75% | 91.75% | **97.44%** | +5.69pp |

**关键发现**：auto 别名是跨源收益主力（+24,026 跨源实体，因为带公司后缀的写法变体在两源都存在）；manual 560 个真新品牌几乎都是单源独有品牌（跨源仅 +9），主要价值是把 53.9 万行从 `brand_id_std=NULL` 拉进 entity 层，为后续中/弱匹配提供候选。

### 7.6 semi 638 个（✅ 阶段 2.5 已收尾）

原 semi 档有候选但包含匹配噪声大（如 `MCGILL MICROWAVE→STE`、`SENSITRON→SIT` 子串误命中），**不宜直接自动入库**。

**处理方式（2026-07-08）**：用 `_triage_semi_brands.py` 规则分档 + 联网核实高影响项，将 638 条压缩为：

| 分档 | 品牌数 | 处理 |
|---|---:|---|
| approve_alias / approve_first_only | 123 | 补 `related_words` 别名（已执行 dim） |
| new_brand | 33 + review 裁定 | `manual_extra` 新品牌入库（已执行 dim） |
| reject_fp | 446 | 忽略错误建议，按新品牌入库（batch2，已执行 dim） |
| review | 36 | 联网核实后 5 条转别名、30 条转新品牌、1 条 reject |

**踩坑**：逐条 `INSERT ... array_concat` 补别名极慢（49 条 × 2 schema ≈ 10 分钟+）；改为**按 `brand_id_std` 分组批量 `array_concat`** 后 2.5 秒完成。脚本见 `_gen_remaining_brand_fast.py`。

**剩余未命中**（`exports/brand_supplement/brand_miss_remaining.csv`）：6 distinct / 1,534 行——TELEDYNE、Slkor、SUMMIT、MICRONETICS、UMS、DNMICRON，均为子串歧义，收益可忽略。

---

## 8. 推荐落地路径

### 阶段 1（✅ 已完成）：归一化与可行性验证
- ✅ `dwd.v_param_normalized` 视图
- ✅ 量化跨源匹配规模（初始 594,894 键 / 120 万行）

### 阶段 2（✅ 已完成）：品牌补录 + 强匹配实体层
- ✅ auto 25 条高置信度别名 → `dim.dim_std_brand.related_words`
- ✅ manual 560 个真新品牌 → `manual_extra` 段（brand_id_std 9,001,265–9,001,824）
- ✅ `test_dws.dws_component_entity` 强匹配版建表装数

### 阶段 2.5（✅ 已完成，2026-07-08；✅ sync 保全 2026-07-09）
- ✅ semi 638 规则分档 + 联网核实 → `brand_miss_mapping_triaged.csv`
- ✅ 别名补录 ~150 条 + 新品牌 ~530 个（`brand_id_std` 延续至 9,00xxxx 段）
- ✅ 品牌命中率 → **icpdf 99.98% / digikey 99.99%**；跨源键 **634,124**；`dws_component_entity` 重跑至 **13,435,690 行 / 622,179 跨源实体**
- ✅ **已写入 sync 入口**（防同事 `sync_dim_std_brand.sh` DROP 重建后丢失）：
  - `sql_scripts/2.attribute_standard/dim_std_brand_manual_extra_stage25.sql`（Part B2 486 新品牌 + Part A2 136 组别名；20 个归一化撞名已转别名）
  - `sync_dim_std_brand.sh` 在 `manual_extra.sql` 之后执行 stage25
  - 清单：`exports/brand_supplement/stage25_new_brands.csv` / `stage25_aliases.csv`
  - 再生：`python sql_scripts/test/_export_stage25_brand_persist.py`
  - Windows 无 bash 时可用：`python sql_scripts/test/_sync_dim_std_brand_py.py test`
- ⚠️ `validate_brand_dim_dup` 在**不加 stage25** 时已有 ~70 组历史未豁免重复（jp_brand/manual_extra 存量）；stage25 相对基线 **0 新增**。prod sync 前需单独处理该门控，或临时 `--warn-only`。
- ⏸️ 剩余 6 distinct 未命中（1,534 行）——可选，非阻塞
- ⏸️ **尚未跑 prod sync**（需显式 `ALLOW_PROD=1`）

### 阶段 3（❌ 非本专项范围）：L2 宽表多源化
- L2 宽表 icpdf 补齐由**各品类属性 ETL 流程**持续推进，不属于跨源融合专项。
- 现状（2026-07-09 复核）：113 张 `dwd_l2_*` 中 **83 张已双源**；icpdf 合计约 **854 万行**、digikey 约 **1152 万行**（L2 总约 2007 万行）。仅 digikey 的约 14 张表为流程未跑到，非阻塞。

### 阶段 4（⏳ 本专项下一步）：融合视图 + 字段级优先级
- 先把 `test_dws.dws_component_entity` **推广到 `dws` 生产 schema**（当前仅 test）
- 建 `dwd_l2_*_fused`（或统一融合视图）按 `entity_id` 聚合两源 L2 行
- 字段优先级草案：电气参数 icpdf 优先、package/lifecycle digikey 优先、datasheet_url icpdf 优先
- 冲突字段写 `dq_flags`（如 `voltage_mismatch_dk_vs_icpdf`）

### 阶段 5：去重与交叉校验
- 视下游需求决定是否合并成单行（模式 B）
- 数值字段交叉校验，输出 `dq_score`

### 可选改进（非阻塞）
- ADI `#TRPBF`→`#PBF` 等品牌特有后缀 → `dim_mpn_brand_specific_suffix` 别名表
- 剩余 6 个品牌边缘 case 手工补录（1,534 行）

---

## 附：产出文件

| 文件 | 说明 |
|---|---|
| `sql_scripts/foundation/v_param_normalized.sql` | 跨源 partno/brand 归一化视图（本报告核心产出） |
| `sql_scripts/foundation/dws_schema.sql` | DWS / test_dws 库定义 |
| `sql_scripts/foundation/dws_component_entity.sql` | DWS 跨源实体映射表 DDL + 强匹配装数逻辑 |
| `sql_scripts/test/_probe_mpn_normalize.py` | 两源 partno 形态摸底脚本 |
| `sql_scripts/test/_probe_mpn_regex.py` | StarRocks REGEXP 锚定行为验证脚本 |
| `sql_scripts/test/_probe_mpn_view.py` | 视图创建 + 抽样校验 + 跨源匹配统计脚本 |
| `sql_scripts/test/_qa_mpn_std_rules.py` | mpn_std 规则质量抽检（边界用例 + FP/FN 代理，§4） |
| `sql_scripts/test/_probe_brand_miss_mapping.py` | 未命中品牌清单导出 + 三档半自动映射脚本 |
| `sql_scripts/test/_gen_brand_supplement_sql.py` | auto 安全别名 supplement SQL 生成器 |
| `sql_scripts/test/_gen_brand_manual_extra_sql.py` | manual 真新品牌 manual_extra SQL 生成器 |
| `sql_scripts/test/_apply_brand_supplement.py` | auto 别名执行 + 重跑 + 量化脚本 |
| `sql_scripts/test/_apply_brand_manual_extra.py` | manual 新品牌执行 + 重跑 + 量化脚本 |
| `sql_scripts/test/brand_supplement/dim_std_brand_supplement_cross_source.sql` | auto 25 条别名 supplement SQL（已执行 dim） |
| `sql_scripts/test/brand_supplement/dim_std_brand_manual_extra_cross_source.sql` | manual 560 条新品牌 INSERT SQL（已执行 dim） |
| `sql_scripts/test/brand_supplement/dim_std_brand_supplement_semi_triage.sql` | semi approve 档 128 条别名 SQL（已执行 dim） |
| `sql_scripts/test/brand_supplement/dim_std_brand_manual_extra_semi_top10.sql` | semi 高影响 Top10 新品牌 SQL（已执行 dim） |
| `sql_scripts/test/brand_supplement/dim_std_brand_manual_extra_semi_batch2.sql` | semi reject_fp + 剩余 new_brand 499 条 SQL（已执行 dim） |
| `sql_scripts/test/brand_supplement/dim_std_brand_supplement_remaining_fast.sql` | 最终 72→6 别名分组补录 SQL（已执行 dim） |
| `exports/brand_supplement/brand_miss_list.csv` | 1,224 个未命中品牌清单（初版） |
| `exports/brand_supplement/brand_miss_mapping.csv` | auto/semi/manual 三档映射建议（初版） |
| `exports/brand_supplement/brand_miss_mapping_triaged.csv` | semi 638 自动分档结果（含 verdict） |
| `exports/brand_supplement/brand_miss_mapping_review_verdicts.csv` | review 36 条联网裁定 |
| `exports/brand_supplement/brand_miss_remaining.csv` | 当前剩余 6 个未命中品牌 |
| `sql_scripts/test/_triage_semi_brands.py` | semi 分档脚本 |
| `sql_scripts/test/_gen_semi_triage_sql.py` | semi 批次 SQL 生成器 |
| `sql_scripts/test/_apply_semi_triage_brands.py` | semi 批次执行 + 量化脚本 |
| `sql_scripts/test/_snapshot_fusion_metrics.py` | 融合指标快照（报告更新用） |
| `exports/digikey/mpn_cross_source_fusion_report.md` | 本报告 |
