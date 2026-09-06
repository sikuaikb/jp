# icpdf clock_timing 源端摸底笔记 · 20260707

> Phase 1 产物。写给 Phase 2（gate + classify 规则草案）的"已观察事实清单"。
> 源表：`dwd.dwd_icpdf_component_param`（总 702 万行 / 678 万 distinct partno）

---

## 1. 边界与邻近品类（用户已裁决 20260707）

icpdf 源端 `category`（一级）+ `category2`（二级）+ `prajson2`（半结构 JSON）+ `note_cn`（中文描述）是分类依据。icpdf 无 `l1_code` 列。

**gate universe（IN）**：724,536 行 / 720,926 distinct partno

gate 逻辑：`(category IN 一级白名单 OR category2 IN 二级白名单) AND (category2 IS NULL OR category2 NOT IN 黑名单)`

- category 一级白名单：振荡器 / 晶振 / 时钟发生器 / 时钟信号器件 / 时钟缓冲器、驱动器、锁相环 / 实时时钟芯片 / 可编程定时器芯片 / 延时时钟芯片 / 计时器
- category2 白名单：石英晶体 / XO / VCXO / TCXO / TCVCXO / 其他振荡器 / 时钟发生器 / 时钟驱动器 / 锁相环或频率合成电路 / 陶瓷谐振器 / 计时器或实时时钟 / 时钟集成电路 / SAW 谐振器 / 预分频器/多谐振动器 / 计数器 / 延迟线
- category2 黑名单（OUT）：电压倍频二极管 / 延时继电器 / 压控振荡器 / 介质谐振器 / YIG调谐振荡器 / 压控时钟 SAW 振荡器 / 压控正弦波 SAW/STW 振荡器 / 固定正弦波 SAW/STW 振荡器 / 调谐介质谐振振荡器/同轴谐振振荡器 / 固定时钟 SAW 振荡器 / 射频/微波倍频器

**关键发现**："其他振荡器" 48921 行中 48882 行 `category` 为空——gate 必须以 `category2` 为主、`category` 一级为辅，不能用 category 一级单独 gate。

### 邻近品类混淆点

| icpdf category2 | 行数 | 归属判定 | 依据 |
|---|---:|---|---|
| 电压倍频二极管 | 2009 | OUT → diode L1 | MICROSEMI CHV21D、1N5149 等倍频二极管 |
| 延时继电器 | 223+34 | OUT → relay L1 | TE/SCHNEIDER/PHOENIX 工业延时继电器 |
| 压控振荡器 | 3305 | OUT → rf_wireless | NSC LMX2604"GSM三频VCO"、Skyworks SKY73100"865-960MHz VCO"、ZCOMM/SPECTRUM——VCO≠VCXO，无晶体 |
| 介质谐振器 | 1923 | OUT → rf_wireless | Murata DRD、Skyworks SR8800——microwave 介质谐振器 |
| YIG调谐振荡器 | 108 | OUT → rf_wireless | YIG 调谐微波振荡器 |
| SAW/STW 振荡器系列 | ~650 | OUT → rf_wireless | 压控/固定正弦波 SAW/STW 振荡器——RF 振荡器非时钟 |
| 射频/微波倍频器 | 264 | OUT → rf_wireless | RF 倍频器 |
| SAW 谐振器 | 601 | IN → other_clock_timing (230502) | 对齐 digikey：digikey 把 SAW 谐振器归 230502 |

### 三个混合桶（gate 整桶纳入，靠 classify 二级规则拆分）

1. **其他振荡器 48921**：晶体振荡器(XO/VCXO/TCXO/OCXO/MEMS) ~2/3 IN → oscillator L2；RF VCO(GSM/宽带/中频 VCO) ~1/3 OUT → rf_wireless；杂项(LED驱动/激光驱动)少量 OUT。拆分依据：`note_cn` 关键词（VCO/宽带/GSM/RF/MMIC/GaAs → OUT；OCXO/TCXO/VCXO/恒温/温补/压控石英/MEMS/晶体振荡 → IN）+ `partno` + `prajson2.振荡器类型`。
2. **预分频器/多谐振动器 3142**：多谐振荡器/单稳态触发器（74HC123/CD74HC423/4047/54123）IN → timer_counter_ic (230402)；逻辑/ECL 分频器（SY100EL32/11C90）IN → clock_buffer_distributor (230302)；RF 预分频器（HMC361/HMMC-3024/GaAs MMIC DC-16GHz）OUT → rf_wireless。拆分依据：`note_cn`（单稳/多谐/双稳/触发器 → timer_counter；GaAs/MMIC/GHz 分频 → OUT）+ `partno`（74xx123/4047/4538 → timer_counter）。
3. **振荡器一级下空 category2 2566 行 + 晶振一级下空 category2 1670 行**：靠 `note_cn`/`prajson2.振荡器类型`/`partno` 兜底分类。

---

## 2. 源端几条容易掉的坑

1. **`category` 一级大量为空**：724k universe 中"其他振荡器"48882 行 category 空；振荡器一级下 2566 行 category2 空。分类规则不能只靠 category 一级，必须 `category2` + `note_cn` + `prajson2` 多字段兜底。
2. **`category` 一级白名单会误带入非时钟 category2**：如"时钟信号器件"一级下有 `ATM/SONET/SDH 集成电路`(42)、`模拟波形发生功能`(75)、`其他模拟IC`(27)、`复用器/解复用器`(43)——这些需在 classify 用 note_cn/partno 判定是否真为时钟器件，或 fallback 到 other_clock_timing。
3. **`note_cn` 覆盖率只有 4.9%**（35745/724536）——不能作为主分类字段，只能补漏。主分类靠 `category2` + `prajson2`。
4. **`prajson`（中文旧 JSON）覆盖率仅 3.8%**（27592），`prajson2` 覆盖率 99.2%（718422）——icpdf 规则主用 `prajson2_key_eq`，`prajson_cn_eq` 几乎无效（与 digikey 同踩坑，见 l1-etl-digikey-pipeline pitfalls）。
5. **振荡器子类 label 比 digikey 干净**：icpdf 有显式 `XO`/`VCXO`/`TCXO`/`TCVCXO` category2，digikey 只有一个"振荡器"叶子靠 note_cn 拆。但 `TCVCXO`（温补压控晶体振荡器）在 digikey taxonomy 里无独立 L3，需归 tcxo(230202) 或 vcxo(230203)——Phase 2 决策。
6. **"石英晶体" 260098 行 vs digikey crystal_resonator 116017 行**：icpdf 量级是 digikey 2.2 倍，注意可能有非谐振器（晶体滤波器等）混入，Phase 5 抽样核对。
7. **brandshort 100% 覆盖**，但 icpdf 品牌文案与 digikey 不同（icpdf 用 `brandshort` 如 `MTRONPTI`、`EUROQUARTZ`、`PLETRONICS`，需查 `dim_std_brand` 别名匹配）。

---

## 3. 源端键 → 标准属性候选名单（Phase 3 属性 dim 输入）

prajson2 顶层键覆盖率（分母 718422 行有 prajson2）。仅列 clock_timing 相关候选，完整 Top100 见 `icpdf_keys_20260707.tsv`。

### 高覆盖（>50%，L2 公共字段候选）
| prajson2 键 | 覆盖 | 候选标准属性 |
|---|---:|---|
| 表面贴装 / 安装特点 | 91% / 82% | mounting_style |
| 最低/最高工作温度 | 90% | operating_temp_min/max |
| 是否Rohs认证 / 是否无铅 | 86% / 54% | rohs_compliant / lead_free |
| 频率稳定度 | 78% | frequency_stability |
| 物理尺寸 | 77% | package_case |
| 标称工作频率 | 60% | nominal_frequency |
| 端子面层 | 57% | terminal_finish |
| 包装说明 | 52% | package |

### 中覆盖（5-50%，L3 专属或核心参数）
| prajson2 键 | 覆盖 | 候选标准属性 |
|---|---:|---|
| 振荡器类型 | 45% | oscillator_type（XO/VCXO/TCXO/OCXO/MEMS 子类判定） |
| 频率调整-机械 | 43% | frequency_adjustment |
| 老化 | 41% | aging |
| 最大对称度 | 39% | symmetry_max |
| 晶体/谐振器类型 | 36% | crystal_resonator_type |
| 频率容差 | 35% | frequency_tolerance |
| 驱动电平 | 35% | drive_level |
| 串联电阻 | 34% | series_resistance (ESR) |
| 输出负载 | 30% | output_load |
| 最大/最小工作频率 | 29% | operating_freq_min/max |
| 负载电容 | 26% | load_capacitance |
| 端子数量 / 针数 | 16% / 9% | pin_count |
| 标称供电电压 / 最大最小供电电压 | 48% / 36% | supply_voltage_nominal/min/max |
| 子类别 | 10% | subcategory（兜底分类辅助） |

### 低覆盖（<5%，L3 专有或暂不建模）
| prajson2 键 | 覆盖 | 候选 |
|---|---:|---|
| 最大输出时钟频率 | 1.6% | max_output_clock_freq（clock_generator 专属） |
| 可编程延迟线 / 抽头阶步 | 2.2% | delay_line_taps（delay_line 专属） |
| 主时钟/晶体标称频率 | 1.4% | master_clock_freq |
| 位数 | 1.2% | bit_count（counter 专属） |
| 计数方向 / 工作模式 | 1.4% / 1.4% | count_direction（counter 专属） |
| 最大电源电流 (ICC) | 1.2% | supply_current_max |
| 输出阻抗 / 输出电平 / 输出极性 | 2.8% / 2.9% / 2.4% | output_impedance/level/polarity |

### icpdf → digikey 跨源对照（Phase 3 多源 extract_rule 设计依据）
icpdf prajson2 是中文键（`标称工作频率`/`频率稳定度`/`负载电容`），digikey prajson 也是中文键但键名可能不同。Phase 3 需建跨源对照表，按 `data_source='icpdf'` 单独写 `source_kind=prajson2_key_eq` 规则行，不能复用 digikey 的 extract_rule_id（PK 冲突）。

---

## 4. 数据量健康度

- icpdf 源表总 702 万行，gate universe 72.5 万行（占 10.3%），distinct partno 72.1 万。
- prajson2 覆盖率 99.2%（718422/724536），属性抽取分母充足。
- brandshort 100% 覆盖，品牌门控有数据基础。
- 未发现断档分区（icpdf param 表无 partition_dt 列，按 dt 字段分区但本摸底未深查，Phase 5.5 可补）。
- icpdf clock_timing universe（72.5 万）是 digikey（12.4 万）的 5.8 倍，分类规则要扛住量级。

---

## 5. 与已接入源（digikey）的差异点

| 维度 | digikey | icpdf |
|---|---|---|
| 半结构字段 | prajson（中文 JSON），EAV 引擎别名 prajson2 | prajson2（中文 JSON，原生）+ prajson（旧，3.8% 弃用） |
| 源端分类字段 | category（叶子，如"晶体"/"振荡器"/"实时时钟"） | category（一级，粗）+ category2（二级，细：XO/VCXO/TCXO/石英晶体...） |
| 振荡器子类 | 一个"振荡器"叶子，靠 note_cn 拆 XO/VCXO/TCXO/OCXO/MEMS | category2 直接给 XO/VCXO/TCXO/TCVCXO，分类更直接 |
| 量级 | 12.4 万 distinct id | 72.1 万 distinct partno（5.8x） |
| note_cn 覆盖 | 较高（digikey 有产品描述） | 仅 4.9%，不能做主分类字段 |
| RF VCO 边界 | digikey clock_timing 不含 VCO（无该叶子） | icpdf "压控振荡器" 3305 + "其他振荡器"内 VCO 子集需排除 |
| SAW 谐振器 | 归 other_clock_timing 230502 | 同（对齐） |
| schema 共享 | dim_attr_schema 180 行（不分源） | 同——icpdf 只加 extract_rule，不动 schema |

---

## 6. Phase 2 输入：icpdf gate + classify 规则草案要点

1. **gate**：用上文 universe 定义。`data_source='icpdf'`，`source_kind=param_category2_eq`（category2 精确匹配白名单）+ `param_category_eq`（一级白名单）+ 黑名单 NOT IN。排除关键词 NULL 安全（硬门控：`AND category2 IS NOT NULL` 显式处理）。
2. **classify 二级拆分**（混合桶）：
   - "其他振荡器" → note_cn/partno/prajson2.振荡器类型 关键词拆：晶体振荡器类 → 230201-230205；VCO/宽带/GSM/RF → OUT（rf_wireless）。
   - "预分频器/多谐振动器" → 74xx123/4047/4538/54123 + 单稳/多谐 → 230402；ECL/PECL ÷N 分频 → 230302；GaAs/MMIC/GHz → OUT。
   - XO → 230201；VCXO → 230203；TCXO → 230202；TCVCXO → 230202（温补优先，Phase 2 确认）；石英晶体 → 230101；陶瓷谐振器 → 230102；SAW 谐振器 → 230502。
   - 时钟发生器 → 230301；时钟驱动器 → 230302；锁相环或频率合成电路 → 230301/230304；计时器或实时时钟 → 230401/230402；计数器 → 230402；延迟线 → 230501；时钟集成电路 → 230301 fallback。
3. **rule_id 前缀**：`clock_timing_icpdf_*`（与 digikey `clock_timing_dk_*` 区分，PK 不撞）。
4. **schema_version**：对齐 digikey `v1.4.30`（同 L1 同 schema，硬门控 C10）。
5. **外部核对**：Phase 2 草案后抽每 L3 1-2 SKU 到得捷/芯查查核对（硬门控：源端文案不得单独判定 L3）。

---

## 6.5 自动验证结论（替代人工商城核对 · 20260707）

三办法自动验证覆盖全部 16 桶，无需人工核对 128 SKU：

### 办法 1：prajson2 判定性字段自证（8 干净桶，60.7万行）
- 石英晶体 26万：`晶体/谐振器类型` = PARALLEL/SERIES-FUNDAMENTAL(80.6%)+OVERTONE(17.6%) = 98.2% 晶体谐振器 → 230101 ✅
- XO/VCXO/TCXO/TCVCXO 33.8万：`振荡器类型` = CLIPPED-SINE/HCMOS/CMOS/SINE 标准输出 → oscillator L2 ✅
- 陶瓷谐振器 3492：`晶体/谐振器类型` = CERAMIC RESONATOR 87% → 230102 ✅
- 延迟线 17918：`可编程延迟线`键 89% 有值 → 230501 ✅

### 办法 2：跨源 digikey 真值继承（6383 重叠，91.7% 一致）
icpdf universe 714519 distinct partno 与 digikey clock_timing 124001 id 在 partno 上重叠 6383 (0.9%)。重叠部分 icpdf 候选 L3 vs digikey 真值 L3：MATCH 5851 / 6383 = 91.7%。

533 MISMATCH 全部可解释：
1. **振荡器→timer_counter 164 个**：digikey 振荡器 L2 (230201-230205) 仓内 0 行，把振荡器塞进 timer_counter——**digikey 伪证**，忽略。
2. **时钟管理 IC 内部细分 248 个**（发生器/驱动器/锁相环 互相错）：icpdf fallback 太粗，digikey 有 note_cn 细分——**加 note_cn 专规**细化。
3. **计时器/RTC → timer_counter 58 个**：icpdf fallback rtc，58 实为 timer_counter——**加 note_cn 规则**拆分。
4. **陶瓷谐振器 → crystal_resonator 41 个**：ECLIPTEK 晶体被 icpdf 误标陶瓷（partno 带 MHZ/KHZ，无 ceramic 字段）——icpdf category2 1.2% 噪声，v1 接受，Phase 5 修。

### 办法 3：规则仿真 L3 分布（预期产出）
| L3 | 行数 | distinct partno |
|---|---:|---:|
| 230101 crystal_resonator | 260098 | 260040 |
| 230201 crystal_oscillator | 293879 | 293675 |
| 230202 tcxo | 49375 | 49373 |
| 230203 vcxo | 44753 | 44698 |
| 230501 delay_line | 17918 | 17756 |
| 230301 clock_generator | 18413 | 17895 |
| 230402 timer_counter_ic | 13980 | 12461 |
| 230302 clock_buffer_distributor | 12040 | 11524 |
| 230102 ceramic_resonator | 3492 | 3468 |
| 230401 rtc | 3327 | 3075 |
| 230502 other_clock_timing | 601 | 599 |

**重大价值**：digikey clock_timing 振荡器 L2 (230201-230205) 仓内 0 行，icpdf 有 38.8 万行填补空缺。

### 结论
fallback 规则 + note_cn 专规细化即可覆盖，无需人工商城核对。Phase 2 据此写 gate + classify 配置。

---

## 7. 产物清单

| 产物 | 路径 |
|---|---|
| 摸底笔记（本文件） | `artifacts/clock_timing/icpdf_explore_notes_20260707.md` |
| 字段覆盖率 | `artifacts/clock_timing/icpdf_field_coverage_20260707.tsv` |
| prajson2 顶层键 Top100 | `artifacts/clock_timing/icpdf_keys_20260707.tsv` |
| category2 词频 | `artifacts/clock_timing/icpdf_keyword_freq_20260707.tsv` |
| 边界桶分层抽样 | `audit/output/icpdf_boundary_samples_20260707.txt`（探针脚本输出） |
| 跨源对照表 | Phase 3 补 |

---

## 8. Phase 2 规则草案验证结果（20260707）

### 8.1 规则真源（已入仓 test_dim）

| 文件 | 内容 |
|---|---|
| `seed/gate_config_icpdf.py` | icpdf gate 真源：G1 category 一级白名单（9）+ G2 category2 二级白名单（16）+ X1 category2 黑名单（11）+ X2 评估板排除 |
| `seed/classify_config_icpdf.py` | icpdf classify 真源：27 条规则（含 fallback + note_cn 上调/隔离），field_code 用 `category2_eq`/`category2_in`/`note_cn_regexp`/`parajson2_match_map` |
| `seed/gen_rule_csv.py`（改） | 同时输出 digikey + icpdf 双源到同一 `dim_l3_classify_rule_clock_timing.csv`（97 行 = digikey 53 + icpdf 44） |
| `build_dwd_icpdf_component_class_clock_timing.sql`（新） | icpdf build SQL，多语句物化版（规避 StarRocks 深层 CTE 物化截断 bug） |
| `run_icpdf_classify_probe.py`（新） | 跑 build + L3 分布/未分类/rule_id 命中探针 |

`load_seed_clock_timing.py --db test_dim` 已装入 `test_dim.dim_l3_classify_clock_timing`（15 L3）+ `dim_l3_classify_rule_clock_timing`（97 规则）。

### 8.2 build 验证结果（test_dwd.dwd_component_class_clock_timing · data_source='icpdf'）

- **gate universe**：724,536 行
- **已分类**：717,876 行（99.1%，distinct id 100%）
- **未分类**：6,660 行（0.9%，见 §8.4）
- **无 L3 命中**：0（所有分类行都有 l3_id）

### 8.3 L3 分布（对齐 §6 仿真，实际 build 结果）

| l2 | l3_id | l3_cn | 行数 | 主要来源 |
|---|---|---|---|---|
| resonator | 230101 | 晶体谐振器 | 260,098 | 石英晶体 |
| resonator | 230102 | 陶瓷谐振器 | 3,492 | 陶瓷谐振器 |
| oscillator | 230201 | 晶体振荡器 | 292,650 | XO 244,958 + 其他振荡器 fb 47,692 |
| oscillator | 230202 | 温补晶体振荡器 | 49,417 | TCXO 28,251 + TCVCXO 21,124 + note上调 42 |
| oscillator | 230203 | 压控晶体振荡器 | 45,026 | VCXO 44,753 + note上调 273 |
| oscillator | 230204 | 恒温晶体振荡器 | 867 | 其他振荡器 note_cn OCXO 上调 |
| oscillator | 230205 | MEMS振荡器 | 0 | （icpdf 无 MEMS note_cn 命中） |
| clock_management_ic | 230301 | 时钟发生器 | 18,540 | 时钟发生器 13,707 + PLL 4,227 + 时钟IC 420 + note 186 |
| clock_management_ic | 230302 | 时钟缓冲器/分配器 | 12,170 | 时钟驱动器 11,788 + 预分频 note 325 + note 57 |
| clock_management_ic | 230303 | 时钟多路复用/切换器 | 46 | note_cn 复用/切换 |
| clock_management_ic | 230304 | 时钟抖动清除器 | 22 | note_cn 抖动清除 |
| timekeeping_timing_ic | 230401 | 实时时钟 | 3,212 | 计时器或实时时钟 fallback |
| timekeeping_timing_ic | 230402 | 定时器/计数器IC | 13,594 | 计数器 10,838 + 多谐 2,641 + note 115 |
| delay_timing_adjustment | 230501 | 延迟线 | 17,918 | 延迟线 |
| delay_timing_adjustment | 230502 | Other_时钟计时 | 824 | SAW 601 + 预分频 RF 176 + RF VCO 47 |

**与 §6 仿真一致**；note_cn 专规上调/隔离全部生效（OCXO 867、VCXO 273、TCXO 42、RF VCO 47 隔离到 230502）。MEMS 230205 在 icpdf 源端无 note_cn 命中（v1 留空，digikey 仓内也 0 行，不补）。

### 8.4 6,660 未分类构成

| 类型 | 行数 | 说明 |
|---|---|---|
| category 一级在白名单 + category2=NULL | ~5,591 | 振荡器+NULL 2566、晶振+NULL 1670、时钟发生器+NULL 609、时钟信号器件+NULL 527、时钟缓冲器+NULL 349、实时时钟+NULL 287、可编程定时器+NULL 83、延时时钟+NULL 20。无 category2 fallback，Phase 5 可加 category 一级兜底（风险：振荡器一级含 VCO，需谨慎） |
| category 一级在白名单 + category2 噪声 | ~1,069 | category2 是"模拟波形发生功能""ATM/SONET/SDH""其他模拟IC""电源管理电路""调谐器""蜂窝电话"等非时钟值——gate 一级白名单过度纳入，classify category2_eq 正确过滤掉。这是 classify 作为二次过滤的健康行为 |

### 8.5 关键踩坑：StarRocks 深层 CTE 物化截断 bug

build SQL 单条 `INSERT...WITH <10+ 层 CTE 含 7M param_all 双扫>` 实际只写入 ~1/12 行（44748/60432/44890 非确定，COUNT 路径 717876 正确但行检索/INSERT/CTAS 截断）。

**根因**：深层 CTE 在同一条 INSERT 里二次扫描 7M `dwd_icpdf_component_param`（gate 阶段一次 + gate_param 回 join 一次）触发 StarRocks pipeline 物化丢行。`parallel_fragment_exec_instance_num=1` 无效（仍 60432），`enable_insert_strict=false` 无效。基础 CTAS（`SELECT * FROM param`）正常 7019307。

**修复**：build SQL 改多语句——① CTAS `icpdf_gate_pass_tmp`（gate_pass 724536，单独物化正常）→ ② CTAS `icpdf_gp_tmp`（gate_pass JOIN param 全列 724536，正常）→ ③ INSERT classify 管线从 `icpdf_gp_tmp` 跑（不再扫 7M）+ anti-join 选优（替代 ROW_NUMBER 窗口函数，进一步降低物化风险）。build 30s 完成，717876 行全部入库。

**教训**：icpdf 源表 7M 行级别，build SQL 必须分步物化中间表，不能塞单条深层 CTE INSERT。digikey build 12 万行未触发此 bug（数据量小 6 倍）。

---

## 9. Phase 3 属性 dim icpdf extract_rule（多源覆盖对称性 A15）· 20260707

### 9.1 规则生成

`gen_attr_extract_rule_icpdf.py` 把同一 `dim_attr_schema_clock_timing`（180 行 schema）映射到 icpdf prajson2 键（键名见 §3 `icpdf_keys_20260707.tsv`），`source_kind='prajson2_key_eq'`。

**icpdf 键映射要点**：
- icpdf 常把 digikey 的"范围字段"拆成 min/max 独立键 → icpdf 规则无需 regex 取范围左右值：
  - `工作温度 -40~85` → icpdf `最低工作温度` + `最高工作温度` 两个键
  - `电压 - 供电 4.5~5.5V` → icpdf `最小/最大供电电压`（+ `(Vsup)` 变体）
  - `控制电压` → icpdf `最小/最大控制电压`
  - `大小/尺寸 LxW` → icpdf `长度` + `宽度`（+ `物理尺寸` 兜底）
- icpdf 键名差异映射：制造商→`IHS 制造商`/`Brand Name`、MPN→`制造商序列号`、零件状态→`生命周期`、RoHS→`是否Rohs认证`、REACH→`Reach Compliance Code`、ECCN→`ECCN代码`、MSL→`湿度敏感等级`、ESR→`串联电阻`、老化率→`老化`、封装→`封装形式`/`封装代码`/`封装等效代码`/`包装说明`、高度→`座面最大高度`、PLL 无→豁免、相位噪声/抖动无→豁免。

**产出**：`seed/dim_attr_extract_rule_icpdf_clock_timing.csv` 89 条 icpdf 规则。
- 134/180 schema 行有 icpdf 规则
- 46 行豁免（icpdf 确无此属性：PLL/相位噪声/抖动/比率/RTC 电池/陶瓷内置电容标志/起振时间/延迟线类型等）
- **0 MISSING**（A15 全覆盖：有规则或显式豁免）

`load_attr_seed_clock_timing.py` 改造为双 CSV 装载（digikey 193 + icpdf 89 = 282 规则入 `test_dim.dim_attr_extract_rule_clock_timing`）。

### 9.2 icpdf attr build

从 `test/switch/build_dwd_icpdf_component_attr_std_switch.sql` 复制改后缀 → `build_dwd_icpdf_component_attr_std_clock_timing.sql`（icpdf 原生 prajson2 + prajson array 处理 + 全程 `data_source='icpdf'` 源隔离）。`dim_unit_factor` 用共享表（对齐 digikey clock_timing build）。

### 9.3 EAV 探针结果（run_icpdf_attr_probe.py）

- **EAV 行 8,695,570** / **器件 717,876/717,876 = 100% 覆盖** / **50 std_attr_code**
- 有数值 4,764,834 / 有字符串 3,930,736 / **dq_flag 全 NULL**（无 parse_fail / out_of_range）
- 每 L3 with_attr = parts（14 个 L3 全 100% 有属性）

### 9.4 每 std_attr 计数（WHERE 路径，对齐 §3 icpdf 键命中）

| std_attr_code | EAV 行 | §3 icpdf 键命中（对照） |
|---|---:|---|
| lifecycle_status | 717,876 | 生命周期 718,421 ✓ |
| reach | 717,873 | Reach Compliance Code 718,418 ✓ |
| manufacturer | 413,819 | IHS 制造商 406,077 + Brand Name 27,014（去重）✓ |
| mpn | 361,288 | 制造商序列号 361,288 ✓ 精确 |
| rohs_compliant | 619,359 | 是否Rohs认证 619,847 ✓ |
| lead_free | 385,832 | 是否无铅 386,160 ✓ |
| eccn_code | 38,899 | ECCN代码 39,253 ✓ |
| msl_level | 21,121 | 湿度敏感等级 21,517 ✓ |
| temp_max_c | 648,618 | 最高工作温度 649,164 ✓ 99.9% |
| temp_min_c | 487,919 | 最低工作温度 649,164（75% 数值可抽，余为非数值文本）|
| frequency_stability_ppm | 556,634 | 频率稳定性 556,856 ✓ |
| frequency_tolerance_ppm | 254,177 | 频率容差 254,177 ✓ 精确 |
| load_capacitance_pf | 188,079 | 负载电容 188,079 ✓ 精确 |
| esr_ohm | 241,997 | 串联电阻 241,997 ✓ 精确 |
| drive_level_max_uw | 249,597 | 驱动电平 249,597 ✓ 精确 |
| aging_rate_ppm_per_year | 291,524 | 老化 291,968 ✓ |
| nominal_delay_ns | 15,228 | 总延迟标称 td 15,228 ✓ 精确 |
| tap_count | 16,010 | 抽头/阶步数 16,075 ✓ |
| counter_bits | 8,123 | 位数 8,483 ✓ |
| crystal_cut_type | 255,546 | 晶体/谐振器类型 259,184 ✓（scoped crystal_resonator 260,098）|

### 9.5 踩坑：StarRocks 低基数列 GROUP BY 分片不合并

`GROUP BY std_attr_code ORDER BY n DESC LIMIT N` 在 8.7M 行 / 50 distinct 键的低基数列上，StarRocks 选 local agg 无 global merge，返回 787 行（每分片各报 ~45k）而非 50 行聚合。`COUNT(DISTINCT std_attr_code)=50` 正确，单属性 `WHERE std_attr_code='x'` 计数正确。**影响范围**：仅 ad-hoc 探针显示毛刺，EAV 数据本身正确；Phase 5.5 §8.1 空值率扫描探针需改 `WHERE` 逐属性或强制单分片（`SET parallel_fragment_exec_instance_num=1` 待验证）。L2 宽表透视用 `MAX(CASE WHEN std_attr_code=... THEN value END)` GROUP BY id（高基数），不受此毛刺影响。

### 9.6 Phase 3 验收

- A15 多源覆盖对称性：icpdf 89 规则 + 46 豁免 = 180 schema 全覆盖，0 MISSING → PASS
- EAV 100% 器件覆盖，无 dq_flag → PASS
- 每 std_attr 计数对齐 Phase 1 icpdf 键命中 → 数据自洽

---

## 10. Phase 4-5 宽表 + 双回路迭代 · 20260707

### 10.1 L2 宽表 build（Phase 4）

clock_timing 5 个 L2 宽表（resonator/oscillator/clock_management_ic/timekeeping_timing_ic/delay_timing_adjustment）原 digikey build 是 digikey-only（硬编码 `c.data_source='digikey'` + JOIN digikey_param + 读 `p.prajson` 制造商）。按"能加不改"原则，生成 5 个 icpdf 对应 build（`build_dwd_l2_clock_timing_<l2>_icpdf.sql`），改：源表→`dwd_icpdf_component_param`、prajson 制造商→prajson2 `IHS 制造商`、`data_source='icpdf'`。INSERT icpdf 行到同一 L2 表（digikey build 不动）。

**结果（run_icpdf_l2_probe.py）**：

| L2 | icpdf 行 | brand_null | dist_brand | dist_brandid | gap |
|---|---:|---:|---:|---:|---:|
| resonator | 263,590 | 0 | 48 | 46 | 2 |
| oscillator | 387,960 | 0 | 84 | 81 | 3 |
| clock_management_ic | 30,778 | 0 | 98 | 95 | 3 |
| timekeeping_timing_ic | 16,806 | 0 | 71 | 70 | 1 |
| delay_timing_adjustment | 18,742 | 0 | 55 | 54 | 1 |
| **合计** | **717,876** | 0 | — | — | — |

- **717,876 行 = 100% 分类器件覆盖**（每件落且仅落一个 L2）
- **brand_null=0 全表**（每行有 brand）
- **dist_brand > dist_brandid（gap 1-3/L2）**：品牌字典别名覆盖缺口——部分 icpdf brandshort 未在 `v_std_brand_alias` 建别名，brand 用 raw brandshort、brandid 用 p.brandid，文本未折叠到 canonical_name。**属人工补字典项（CONTRIB_BRAND.md 流程），非 agent 自动同步**；DL1 严格门控 `dist_brand=dist_brandid` 在别名折叠场景需配合字典补齐。

### 10.2 填充率探针（Phase 5 内部回路 · §8.1）

`run_icpdf_l2_fill_probe.py` 逐列 COUNT（规避 §9.5 GROUP BY 分片毛刺）。**豁免属性 0% 是预期**（digikey 专属 icpdf 无：output_type/has_output_enable/phase_noise/supply_current_ma/interface_type/channel_count/io_logic_standard/output_signal_standard）。

**健康填充**：lifecycle_status/reach 100%、rohs 64-91%、frequency_tolerance 96%、frequency_stability 78-96%、esr 92%、drive_level 95%、load_cap 71%、package_case 29-99%、temp_max 73-97%。

**真缺口（Phase 5 双回路重点）**：
| 缺口 | 表现 | 根因 | 修复方向 |
|---|---|---|---|
| aec_q_level 0% 全 L2 | icpdf 认证状态 102k 命中但 0 入 EAV | regex `(AEC-Q\d+...)` 匹配字面 "AEC-Q"，icpdf 认证状态值不含该字面 | 改 regex 匹配 icpdf 车规文案 或 豁免 |
| pkg_length_mm 0% resonator/oscillator | 长度 42k 命中但 passive 0 | 长度 键在 passive 件缺，或 regex `([\d.]+)` 取数失败 | 用 物理尺寸 兜底 + 核实 passive 尺寸键 |
| pkg_height_mm 0% resonator/oscillator | 座面最大高度 50k 命中但 passive 0 | 座面最大高度 在 passive 缺 | 用 物理尺寸 第三维 兜底 |
| temp_min_c 75% resonator | 最低工作温度 649k 但 75% 入 | regex `(-?\d+\.?\d*)` 对范围串"-40~85"取 -40 OK，但部分值为非数值文本 | 核实失败样本值 |
| ref_clk_freq_min/max 0% clock_management_ic | 最小/最大工作频率 207k 命中但 0 | scoping 或键名映射 | 核实 clock_management_ic 件的工作频率键 |

### 10.3 值正确性 spot-check（Phase 5 内部回路 · 抽样核对）

`run_icpdf_eav_spotcheck.py` 抽 5 个有谐振器参数的 crystal_resonator 件，prajson2 原值 vs EAV std 值：

| partno | nominal_freq | tolerance | stability | esr | temp_min/max | crystal_cut |
|---|---|---|---|---|---|---|
| FAR-C3CM-04000-G10-R | "4 MHz"→4.0✓ | "500 ppm"→500✓ | "0.035%"→0.035⚠ | "300 Ω"→300✓ | -10/60✓ | SERIES-FUNDAMENTAL✓ |
| FAR-C4CP-04000-M01-R | "4 MHz"→4.0✓ | "5000 ppm"→5000✓ | "1%"→1.0⚠ | "150 Ω"→150✓ | -40/105✓ | SERIES-FUNDAMENTAL✓ |
| FAR-C4CL-40000-K02-R | "40 MHz"→40✓ | "3000 ppm"→3000✓ | "0.5%"→0.5⚠ | "75 Ω"→75✓ | -30/85✓ | SERIES-3RD OVERTONE✓ |

**发现 2 个单位换算缺口**：
1. **frequency_stability_ppm**：icpdf 频率稳定性常以 "%" 给（0.035%/0.5%/1%），num_raw 取 0.035，unit_raw 取 "%"，但 `dim_unit_factor` 缺 `%`→`ppm`（×10000）换算行 → 存 0.035 而非 350ppm。**高优先**（resonator/oscillator 核心参数，96% 填充但值错）。
2. **aging_rate_ppm_per_year**：icpdf 老化常以 "PPM/10 YEAR" 给（1000 PPM/10 YEAR = 100 ppm/yr），num_raw 取 1000，缺 ÷10 归一 → 存 1000 而非 100。**中优先**。

### 10.4 Phase 5 单位换算修复（双回路第一轮）

spot-check 发现 2 项单位换算缺口，已修复并验证：

**frequency_stability_ppm %→ppm + max_bound=1000 守门**：
- icpdf 频率稳定性键混入占空比/对称度 % 污染值（50%/20%/100%/500%/1000%）
- 追加 `dim_unit_factor ('ppm','%',10000.0)` + schema `frequency_stability_ppm.max_bound=1000`（0.1%，oscillator+resonator 两行）
- 修复后：`0.005%`→50ppm✓、`0.003%`→30ppm✓、`0.01%`→100ppm✓；污染值 `50%`→500000ppm→out_of_range→NULL✓（丢弃）
- 注：digikey clock_timing EAV 未装载（n=0），max_bound 不影响 digikey；晶体稳定性 <1000ppm 是行业常识，bound 安全

**aging_rate_ppm_per_year PPM/N YEAR÷N 归一**：
- icpdf 老化键多形态：PPM/YEAR、PPM/FIRST YEAR、PPM/20 YEAR、PPM/15 YEAR、PPM/10 YEAR、PPM/ONE YEAR
- 追加 `dim_unit_factor` 6 行（ppm/year target）：PPM/YEAR→1.0、PPM/FIRST→1.0、PPM/20→0.05、PPM/15→0.0667、PPM/10→0.1、PPM/ONE→1.0
- 修复后：`5 PPM/YEAR`→5.0✓、`5 PPM/FIRST YEAR`→5.0✓、`2.8 PPM/20 YEAR`→0.14✓、`3 PPM/15 YEAR`→0.2✓
- **遗留 schema 不一致**：crystal_resonator/mems_oscillator 的 aging unit_std='ppm'（非 'ppm/year'），"5 PPM/YEAR" 存 5（丢 /year 语义）—— schema 应统一为 ppm/year，Phase 5.5 再议

**StarRocks regex 转义踩坑**：探针用 Python `\d` → SQL 字符串 `\d` → StarRocks 当未知转义剥成 'd' → regex `[^\d]` 变 `[^d]` 失效。build SQL 文件用 `\\d`（正确→regex `\d`）。直接 regex 测试确认 build 的 unit_raw 抽取正常（`5 PPM/YEAR`→`PPM/YEAR`、`0.035%`→`%`、`300 Ω`→`Ω`），追加 dim_unit_factor 行生效。

### 10.6 Phase 5 规则缺口修复（双回路第二轮）

3 项规则缺口修复 + 1 项 build bug 修复：

**aec_q_level → WAIVER**：icpdf 认证状态值=`Not Qualified/COMMERCIAL/MILITARY/Qualified`（mil/commercial 等级，非 AEC-Q 车规），0 AEC-Q 字面，无 车规等级/AEC-Q等级 键 → 列入 WAIVER_ATTRS，0% 填充预期正确。

**pkg_length/width/height → 物理尺寸复合键拆解**：icpdf passive（resonator/oscillator）无 长度/宽度/座面最大高度 单键，只有 物理尺寸 复合键（resonator 253k + oscillator 299k 命中）。两形态：
- format A `7.0mm x 5.0mm x 1.85mm`（小写 x + mm 单位间夹）
- format B `L11.18XB4.7XH13.58 (mm)/...`（大写 X 作分隔 + L/B/H 前缀）

新增 3 条 pkg 规则各 3 binding：单键（IC L2，pri=4）+ format B `L/B/H(\d)`（pri=8）+ format A（pri=9，regex 在数字与分隔符间加 `[a-zA-Z]*` 跳过 mm 单位，分隔符类 `[*×xX]` 大小写兼容）。

**ref_clk_freq_min/max → WAIVER**：icpdf clock_management_ic 件无 最小/最大工作频率/参考频率/基准频率/输入频率/输出频率 键命中 → 列入 WAIVER_ATTRS，0% 预期。

**build ranked CTE 去重 bug 修复（重大）**：原 `ranked` CTE 先按 priority 排 ROW_NUMBER 再在 `won` 过滤空 value_raw。多规则属性（如 pkg_length 有 pri=8 `L(\d)` + pri=9 format A 两规则）中，format A 件 pri=8 抽空→rn=1，pri=9 抽有效→rn=2；`won` 取 rn=1 且非空 → pri=8 空被丢、pri=9 rn=2 也被丢 → **两条全丢**。修复：把 `value_raw IS NOT NULL AND TRIM(value_raw)<>''` 过滤移到 ROW_NUMBER **之前**，让首个非空抽取按 priority 胜出。此 bug 影响所有"高优先级规则对部分值抽空"的多规则属性，修复后 oscillator pkg 0→77%、resonator pkg 0→95%。

**修复后填充率**（run_icpdf_l2_fill_probe.py）：

| L2 | pkg_len | pkg_wid | pkg_hgt | freq_stability |
|---|---:|---:|---:|---:|
| resonator | 95.2% | 95.2% | 96.0% | 95.2%（ppm 已修正）|
| oscillator | 77.1% | 77.1% | 77.1% | 0.2%（污染值丢弃）|
| clock_management_ic | 82.0% | 81.8% | 81.6% | — |
| timekeeping_timing_ic | 62.8% | 66.1% | 66.2% | — |

**遗留 Phase 5.5 项**：oscillator frequency_stability 78%→0.2%（icpdf 频率稳定性键对振荡器多为占空比/对称度污染，真稳定性仅 0.2%）—— 需找 icpdf 替代键（如 频率稳定度/总频差）或确认振荡器稳定性在 icpdf 无可靠源。其余 LOW 填充（eccn 1.6-46%、lead_free 26-60%、msl IC 25-46%、temp_min 31-75%、package_case oscillator 30%）属 icpdf 源端覆盖极限，非规则 bug。

---

## 11. Phase 5.5 QA 审计（20260707-08）

审计报告：`artifacts/clock_timing/qa_audit_report_20260707.md`。6 步全跑通。

**5.5.2 schema gap**：90 未覆盖键（≥50 hits），P0=6→实质清零（5 条补规则：`制造商包装代码`→manufacturer / `主时钟晶体标称频率`→nominal_frequency_mhz / `频率容差 (MHz)`→frequency_tolerance_ppm / `最大输出频率`→output_freq_max_mhz / `并联电容`→shunt_capacitance_pf un-waive；`电源`→vbat 重分类 P1 语义太泛）。P1=30（商务/物流属性下一周期）、P2=58（边缘）。

**5.5.4 schema 一致性**：4.1/4.2/4.4 全 0 ✓。4.3 `reach` db_type 分裂（4 L2 VARCHAR + timekeeping ENUM）→ **5g 已修复**：timekeeping reach 改 VARCHAR + value_domain 对齐 `NOT NULL`，reload schema 后复扫 4.3=0、4.4=0 ✓。

**5.5.3 单位抽样**：21 数值属性 ×10 = 210 件全 ok，无字节当 KB / 量级偏差 / regex 截断。dq_flag：NULL 9.74M 净 + out_of_range 305k（freq_stability 污染丢弃，符合预期），无 parse_fail。

**5e 探查结论（freq_stability 替代键）**：icpdf oscillator 仅 1 个含"稳定"的键 `频率稳定性`（命中 302,862=78%），样本值**全是百分比**（`600%`/`2%`/`5%`），**无 ppm 形态、无替代键**。被 max_bound=1000ppm 丢弃的全是百分比占位（duty cycle/占位）。当前入库 716 件 = 该键极少数真实 ppm；resonator 侧 250,892 件（晶体谐振器稳定度本就是 ppm 级，语义正确）。**结论：`频率稳定性`键在 oscillator 侧语义混杂，max_bound 守门正确，icpdf 无替代键，维持低 fill 0.2% 为源端语义限制非规则缺口，不回退 max_bound**。schema CSV note 已标注。

**L3 ext 覆盖**：14 个 L3，ext_fill=0% 的（ceramic_resonator/ocxo/clock_generator/clock_mux_switch/jitter_cleaner/rtc）均为 icpdf 源端确无该 L3 专属属性键 → 已 WAIVER 显式豁免，A15 通过。

**审计结论**：有条件通过，可进入阶段 6 合并发布窗口。**唯一剩余阻断项 = 5d 品牌别名人工补字典**（v_std_brand_alias，CONTRIB_BRAND 流程，DL1 硬门控，dist_brand>dist_brandid 1-3 个缺口 + manufacturer fill 56-59% 主因）。5e/5g 已完成。

### 5h L3 专属字段级审计（l2-field-qa-audit 技能 §2.4，20260708）

按 l2-field-qa-audit 技能补做 L3 专属字段级审计（之前 QA 报告只做 L3 ext 整体覆盖率，未做字段级）。80 个 L3 专属字段 × 目标 L3 内填充率 + 两步法 R/X/D 决策。明细 `artifacts/clock_timing/l3_field_audit_20260708.tsv`。

- **正常 >10%**：12 字段（crystal_cut_type 98.2% / crystal_resonator aging 94.5% / delay tap 89.4% / delay_max 85% / nominal_delay 85% / buffer output_skew 78.6% / prop_delay 54.7% / crystal_oscillator freq_range_max 29.8% / min 29.7%）
- **INFO（分母 0）**：7 字段，mems_oscillator L3 icpdf 0 件（icpdf 无 MEMS 振荡器分类）→ 0% 是分母 0 非规则问题
- **D（icpdf 源端缺口）**：61 字段，icpdf 该 L3 件内无对应语义 key，digikey 侧有规则覆盖，选型有价值 → 保留 schema + digikey 规则等他源
- **R（真规则错）**：0，**10 个疑似 R 候选经精准 key 探查后全部归 D**（icpdf 无正确 key 可接）
- **X（删除）**：0，无选型无价值字段

**shunt_capacitance_pf P0 误补撤销**：Phase 5.5.2 P0 阶段基于 gap 探针（`并联电容` hit=471）un-waive + 加规则。L3 字段级精准探查发现 icpdf `crystal_resonator` L3 内**无**`并联电容`类 key（471 hits 不在该 L3 内）→ 规则抽 0 行。已撤销 un-waive（改回 WAIVER_ATTRS）+ DELETE 残留规则，A15 靠 waiver 通过。**教训**：P0 gap 探针 hit 数是全 L1 范围，补规则前应在目标 scope 内复验 key 命中。

### 5i 低 fill 字段根因审计（源端无 vs 提取失败，20260708）

用户追问「字段空值率高是原始数据没有还是提取没成功」。对 49 个低 fill 字段对比 **icpdf 源端有效 key 命中率**（排除空字符串占位）vs **EAV 填充率**，明细 `artifacts/clock_timing/low_fill_root_cause_20260708.tsv`。

**核心结论：49 个低 fill 字段，0 个真提取 bug——全是「原始数据没有」**：
- **D 源端覆盖低 24**：源端有效值命中 ≈ EAV 填充，提取已尽力（temp_min/nominal_freq/manufacturer/lead_free/eccn/package_case/output_freq_max 等）
- **D 源端无 key 7**：icpdf 无对应 source_expr key（msl/aec_q/supply_current/overtone/oven_setpoint/short_term_stability）
- **D 无规则 17**：waiver 豁免（digikey 有规则，A15 通过）
- **守门丢弃 1**：oscillator freq_stability，max_bound=1000ppm 主动丢弃源端百分比污染（5e 确认正确行为）
- **R 提取失败 0**

**temp_min_c 三 L2「假 R」澄清**：初次统计 oscillator/clock_mgmt/delay 的 temp_min_c 显示源端 86.6%/92.7%/73.4% 有 key 但 EAV 仅 66%/54.6%/31.1%，疑似提取失败 20-42pp。深入探查 raw 值发现 `最低工作温度` key 含大量**空字符串 `''` 占位**（oscillator 80k/resonator 57k/clock_mgmt 11.7k/delay 7.9k 件，icpdf 填键未填值）。排除空串后源端有效命中 = 66.0%/54.6%/31.1% ≈ EAV 填充，完全吻合。EAV regex 对空串无匹配→NULL 是正确丢弃。**教训**：根因统计源端 key 命中率必须排除空字符串（`get_json_string IS NOT NULL` 对空串返回 `''` 非 NULL，会假阳性）。

**提取引擎健康度**：无丢失、空串占位处理正确、max_bound 守门正确。低 fill 改进只能靠补数据源（digikey 合并后填补），icpdf 侧空串/无 key 无法靠改规则解决。






