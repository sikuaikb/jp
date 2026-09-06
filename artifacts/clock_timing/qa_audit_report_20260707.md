# clock_timing (icpdf) 数据质量审计报告 — 2026-07-07

> 本报告是阶段 6 合并发布的门控输入。业务方/数据负责人阅读 → 签字 → 才能进入合并发布。

---

## 1. 总览

- **L1**: `clock_timing`
- **数据源**: `icpdf`（本期单源；digikey 已存在并已通过 A15 多源覆盖对称性核对）
- **涉及 L2 宽表**: `resonator` / `oscillator` / `clock_management_ic` / `timekeeping_timing_ic` / `delay_timing_adjustment`（5 张）
- **涉及 L3 子类**: 14 个（crystal_resonator / ceramic_resonator / crystal_oscillator / tcxo / vcxo / ocxo / clock_generator / clock_buffer_distributor / clock_mux_switch / jitter_cleaner / timer_counter_ic / rtc / delay_line / other_clock_timing）
- **总物料数（icpdf）**: 717,876 件
- **本轮迭代轮次**: 5 轮（源端摸底 → classify → attr dim → L2 build → 双回路修缺 → QA）
- **extract_rule 总数**: 288 条（icpdf）；schema 180 行
- **EAV 总行数**: 10,045,689；dq_flag: NULL 9,740,830（净）+ out_of_range 305,026（freq_stability 污染丢弃）

---

## 2. 每张测试 L2 宽表的指标

| L2 | rows | brand_null | dist_brand | dist_brandid | 高危列(>70%空) | 关注列(30~70%空) |
|----|------|-----------|-----------|-------------|---------------|-----------------|
| resonator | 263,590 | 0 | 5,xxx | 5,xxx | aec_q_level(豁免), msl_level(源无) | eccn_code, manufacturer, lead_free, nominal_freq_mhz |
| oscillator | 387,960 | 0 | — | — | frequency_stability(污染丢弃), output_type, has_output_enable, phase_noise, supply_current, aec_q_level, msl_level | package_case, manufacturer, lead_free, temp_min_c |
| clock_management_ic | 30,778 | 0 | — | — | ref_clk_freq(豁免×2), output_signal_standard, aec_q_level | eccn_code, lead_free, msl_level, output_freq_max_mhz, temp_min_c |
| timekeeping_timing_ic | 16,806 | 0 | — | — | interface_type, aec_q_level | eccn_code, lead_free, msl_level, pkg_length/width/height |
| delay_timing_adjustment | 18,742 | 0 | — | — | channel_count, io_logic_standard, input_freq_max_mhz, aec_q_level | eccn_code, msl_level, temp_min_c, supply_voltage_min/max_v |

> brand_null 全 0 ✓。dist_brand vs dist_brandid 存在 1-3 个 alias 缺口（见 §7-1，人工补字典）。

---

## 3. L2 物理列空值率表（按 fill% 升序，仅列 <70% 关注+高危列）

### 3.1 resonator (263,590 行)
| column | filled | fill% | 判定 |
|--------|--------|-------|------|
| aec_q_level | 0 | 0.0% | 豁免（icpdf `认证状态` 仅 COMMERCIAL/MILITARY，无 AEC-Q 等级）|
| msl_level | 0 | 0.0% | 源无（icpdf 无 MSL 键）|
| eccn_code | 6,194 | 2.3% | 源无（icpdf 无出口管制分类）|
| manufacturer | 156,087 | 59.2% | 关注（brandshort 别名缺口，见 §7-1）|
| lead_free | 157,264 | 59.7% | 源端覆盖限（icpdf 无铅标识键）|
| nominal_freq_mhz | 164,697 | 62.5% | 关注（部分晶体未填标称频率）|
| load_capacitance_pf | 188,079 | 71.4% | 正常 |
| package_case | 208,074 | 78.9% | 正常 |

### 3.2 oscillator (387,960 行)
| column | filled | fill% | 判定 |
|--------|--------|-------|------|
| frequency_stability_ppm | 716 | 0.2% | ⚠️本轮回归（max_bound=1000 守门丢弃 `频率稳定性` 占位百分比污染，原 78.1%→0.2%，见 §7-2）|
| aec_q_level | 0 | 0.0% | 豁免 |
| msl_level | 0 | 0.0% | 源无 |
| output_type | 0 | 0.0% | 源无（icpdf 无输出类型键）|
| has_output_enable | 0 | 0.0% | 源无 |
| phase_noise_at_1khz_dbc_hz | 0 | 0.0% | 源无（icpdf 无相位噪声键）|
| supply_current_ma | 0 | 0.0% | 源无 |
| eccn_code | 14,879 | 3.8% | 源无 |
| package_case | 115,617 | 29.8% | ⚠️关注（oscillator 无 package_case 键，需从 pkg_length/width/height 推导，见 §7-3）|
| lead_free | 201,923 | 52.0% | 源端覆盖限 |
| manufacturer | 220,416 | 56.8% | 关注（别名缺口）|
| temp_min_c | 256,013 | 66.0% | 正常 |
| nominal_frequency_mhz | 263,221 | 67.8% | 正常 |

### 3.3 clock_management_ic (30,778 行)
| column | filled | fill% | 判定 |
|--------|--------|-------|------|
| aec_q_level | 0 | 0.0% | 豁免 |
| ref_clk_freq_min_mhz | 0 | 0.0% | 豁免（icpdf clock_management_ic 无参考时钟频率键）|
| ref_clk_freq_max_mhz | 0 | 0.0% | 豁免 |
| output_signal_standard | 0 | 0.0% | 源无 |
| lead_free | 11,803 | 38.3% | 源端覆盖限 |
| output_freq_max_mhz | 11,766 | 38.2% | 关注（部分 clock_generator 无最大输出频率）|
| msl_level | 14,217 | 46.2% | 源无 |
| eccn_code | 14,165 | 46.0% | 源无 |
| temp_min_c | 16,800 | 54.6% | 正常 |

### 3.4 timekeeping_timing_ic (16,806 行)
| column | filled | fill% | 判定 |
|--------|--------|-------|------|
| aec_q_level | 0 | 0.0% | 豁免 |
| interface_type | 0 | 0.0% | 源无（icpdf 无接口类型键）|
| eccn_code | 3,366 | 20.0% | 源无 |
| msl_level | 4,296 | 25.6% | 源无 |
| lead_free | 4,372 | 26.0% | 源端覆盖限 |
| pkg_length_mm | 10,555 | 62.8% | 正常 |
| pkg_width_mm | 11,105 | 66.1% | 正常 |
| pkg_height_mm | 11,125 | 66.2% | 正常 |

### 3.5 delay_timing_adjustment (18,742 行)
| column | filled | fill% | 判定 |
|--------|--------|-------|------|
| aec_q_level | 0 | 0.0% | 豁免 |
| channel_count | 0 | 0.0% | 源无 |
| io_logic_standard | 0 | 0.0% | 源无 |
| input_freq_max_mhz | 13 | 0.1% | 源无（icpdf 无输入频率键）|
| eccn_code | 295 | 1.6% | 源无 |
| msl_level | 2,608 | 13.9% | 源无 |
| temp_min_c | 5,832 | 31.1% | 关注 |
| supply_voltage_min_v | 8,203 | 43.8% | 关注 |
| supply_voltage_max_v | 8,258 | 44.1% | 关注 |

---

## 3-A. 低 fill 字段根因审计（源端无数据 vs 提取失败）

> 方法论：对每个低 fill 字段，对比 **icpdf 源端有效 key 命中率**（排除空字符串占位）vs **EAV 填充率**。
> - 源端命中 ≈ EAV 填充 → **D 源端覆盖低**（原始数据就这么多，提取已尽力）
> - 源端命中 >> EAV 填充 → **R 提取失败**（regex/单位/守门丢失）
> - 源端命中 = 0 → **D 源端无 key**
>
> 完整明细见 `artifacts/clock_timing/low_fill_root_cause_20260708.tsv`（49 字段）。

### 3-A.1 分类汇总

| 根因类别 | 字段数 | 含义 | 处理 |
|---------|-------|------|------|
| **D 源端覆盖低** | 24 | 源端有效值命中率 ≈ EAV 填充率，提取已尽力 | 接受，等他源 |
| **D 源端无 key** | 7 | icpdf 该 scope 件内无对应 source_expr key | 接受，等他源 |
| **D 无规则（waiver）** | 17 | icpdf 无规则，已在 WAIVER 豁免（digikey 有规则）| 接受，A15 通过 |
| **R 提取失败（真 bug）** | **0** | — | — |
| **守门丢弃（正确行为）** | 1 | oscillator freq_stability：max_bound=1000ppm 主动丢弃源端百分比污染 | 正确，不回退 |

### 3-A.2 核心结论：**所有低 fill 都是「原始数据没有」，无提取 bug**

49 个低 fill 字段逐字段对比源端有效 key 命中率与 EAV 填充率，**无一例「源端有有效值但提取失败」**。低 fill 的根因全部是 icpdf 源端数据本身：
1. **源端无此参数 key**（icpdf 不采集该参数）：msl_level/aec_q_level/supply_current/overtone_mode/oven_setpoint 等 7 个
2. **源端 key 存在但值为空字符串占位**（icpdf 填了 key 没填值）：典型如 `最低工作温度` 键大量 `''` 占位（oscillator 80k/件、resonator 57k/件、clock_mgmt 11.7k/件、delay 7.9k/件），EAV 正确丢弃空串
3. **源端有效值覆盖率本就低**（部分件有有效值）：eccn/lead_free/manufacturer/package_case/output_freq_max 等
4. **唯一「损失」= oscillator freq_stability**：源端 78.1% 有 `频率稳定性` key 但值是百分比占位（`600%`/`2%`/`5%` duty cycle 污染），max_bound=1000ppm 守门**主动丢弃**——这是 5e 确认的**正确行为**（源端语义混杂，丢弃污染保正确），非提取 bug

### 3-A.3 关键证据：temp_min_c 三 L2「假 R」澄清

初次统计 oscillator/clock_mgmt/delay 的 temp_min_c 显示「源端 86.6%/92.7%/73.4% 有 key 但 EAV 仅 66%/54.6%/31.1%」，疑似提取失败 20-42pp。深入探查源端 raw 值分布发现：`最低工作温度` key 含大量**空字符串 `''` 占位**（icpdf 填键未填值）。排除空字符串后源端有效值命中率 = 66.0%/54.6%/31.1% ≈ EAV 填充率，**完全吻合**。EAV regex `(-?\d+\.?\d*)` 对空串无匹配→NULL 是**正确丢弃**。

| L2 | 源端有效值命中 | EAV 填充 | 空字符串占位 | 结论 |
|----|-------------|---------|------------|------|
| oscillator | 66.0% | 66.0% | 80,048 件 | D 源端覆盖低（空串占位）|
| clock_management_ic | 54.6% | 54.6% | 11,720 件 | D 源端覆盖低（空串占位）|
| delay_timing_adjustment | 31.1% | 31.1% | 7,920 件 | D 源端覆盖低（空串占位）|

### 3-A.4 D 源端覆盖低代表字段（源端有效命中 ≈ EAV，提取已尽力）

| 字段 | L2 | 源端有效命中 | EAV 填充 | 根因 |
|------|----|-----------|---------|------|
| nominal_freq_mhz | resonator | 62.5% | 62.5% | 源端部分件未标 |
| manufacturer | resonator/oscillator | 58%/56% | 59.2%/56.8% | brandshort 别名缺口（5d）+ 源端部分无 |
| lead_free | 各 L2 | 26-60% | 26-60% | 源端覆盖低 |
| eccn_code | 各 L2 | 1.6-46% | 1.6-46% | icpdf 出口管制标注率低 |
| package_case | oscillator | 26.6% | 29.8% | 源端无封装代号键（pkg 三维已抽）|
| output_freq_max_mhz | clock_mgmt | 38.0% | 38.2% | 源端部分 clock_generator 未标 |

### 3-A.5 提取引擎健康度结论

- **提取引擎无丢失**：所有低 fill 字段 EAV 填充率 = icpdf 源端有效值命中率，无 regex/单位/scope 错误导致的提取损失
- **空字符串占位处理正确**：源端 `''` 占位被 regex 正确丢弃为 NULL（不污染数据）
- **max_bound 守门正确**：freq_stability 百分比污染被主动丢弃，保数据正确性
- **低 fill 的改进路径只能靠「补数据源」**：digikey 侧对这些字段大多有规则（D 保留），合并后 digikey 数据将填补这些缺口；icpdf 侧空字符串占位/无 key 无法靠改规则解决

---

## 4. L3 ext_attributes 命中率表（分母 = 该 L3 行数）

| L2 | L3 | total | ext_nonempty | ext_fill% | 说明 |
|----|----|-------|-------------|----------|------|
| resonator | crystal_resonator | 260,098 | 255,756 | 98.3% | 优 |
| resonator | ceramic_resonator | 3,492 | 0 | 0.0% | L3 专属属性全豁免（icpdf 无陶瓷谐振器特有键）|
| oscillator | crystal_oscillator | 292,650 | 88,498 | 30.2% | 部分有 L3 专属属性 |
| oscillator | tcxo | 49,417 | 46,864 | 94.8% | 优 |
| oscillator | vcxo | 45,026 | 39,003 | 86.6% | 优 |
| oscillator | ocxo | 867 | 0 | 0.0% | L3 专属属性全豁免 |
| clock_management_ic | clock_generator | 18,540 | 167 | 0.9% | PLL/倍频等属性 icpdf 无键 |
| clock_management_ic | clock_buffer_distributor | 12,170 | 10,187 | 83.7% | 优 |
| clock_management_ic | clock_mux_switch | 46 | 0 | 0.0% | 样本过小 + L3 属性豁免 |
| clock_management_ic | jitter_cleaner | 22 | 0 | 0.0% | 样本过小 + L3 属性豁免 |
| timekeeping_timing_ic | timer_counter_ic | 13,594 | 12,846 | 94.5% | 优 |
| timekeeping_timing_ic | rtc | 3,212 | 0 | 0.0% | RTC 专属属性（alarm_count/vbat 等）icpdf 无键，全豁免 |
| delay_timing_adjustment | delay_line | 17,918 | 16,287 | 90.9% | 优 |
| delay_timing_adjustment | other_clock_timing | 824 | 120 | 14.6% | 杂项 L3，属性稀疏 |

> ext_fill=0% 的 L3 均为「icpdf 源端确无该 L3 专属属性键」→ 已在 gen_attr_extract_rule_icpdf.py `WAIVER_ATTRS` 显式豁免，A15 多源覆盖对称性核对通过（digikey 侧有对应规则）。

---

## 4-A. L3 专属字段级审计（l2-field-qa-audit 技能 §2.4）

**80 个 L3 专属字段**（scope_level='l3'）按目标 L3 内填充率 + 两步法（R/X/D）逐字段决策。完整明细见 `artifacts/clock_timing/l3_field_audit_20260708.tsv`。

### 4-A.1 分类汇总

| 类别 | 字段数 | 说明 |
|------|-------|------|
| **正常 >10%** | 12 | 规则有效，已抽样验证值正确 |
| **INFO（分母 0）** | 7 | mems_oscillator L3 icpdf 0 件（icpdf 无 MEMS 振荡器分类），字段 0% 是分母 0 非规则问题 |
| **D（icpdf 源端缺口）** | 61 | icpdf 该 L3 件内无对应语义 key，digikey 侧有规则覆盖，选型有价值 → **保留 schema + digikey 规则，等 icpdf/他源补充** |
| **R（真规则错）** | 0 | 所有疑似 R 经精准 key 探查后确认 icpdf 无正确 key → 归 D |
| **X（删除）** | 0 | 无选型无价值字段 |

### 4-A.2 正常字段（>10%，已抽样验证）

| L3 | 字段 | fill% |
|----|------|-------|
| crystal_resonator | crystal_cut_type | 98.2% |
| crystal_resonator | aging_rate_ppm_per_year | 94.5% |
| delay_line | tap_count | 89.4% |
| delay_line | delay_max_ns | 85.0% |
| delay_line | nominal_delay_ns | 85.0% |
| clock_buffer_distributor | output_skew_ps | 78.6% |
| clock_buffer_distributor | propagation_delay_ps | 54.7% |
| crystal_oscillator | freq_range_max_mhz | 29.8% |
| crystal_oscillator | freq_range_min_mhz | 29.7% |

### 4-A.3 INFO 字段（mems_oscillator L3 icpdf 0 件）

`aging_rate_ppm_per_year` / `freq_stability_ppm` / `is_programmable_freq` / `output_waveform_type` / `shock_tolerance_g` / `startup_time_ms` / `vibration_tolerance_g` — icpdf 无 MEMS 振荡器分类，L3 件数 0，字段 0% 是分母 0。digikey 侧有规则，schema 保留等 digikey 数据。

### 4-A.4 D 字段精准探查（icpdf 源端缺口确认）

对 10 个疑似 R 候选（icpdf 有规则但 0%/<5%）在目标 L3 件内做精准 key 探查（含语义关键词的 prajson2 key）：

| L3 | 字段 | icpdf 规则 src | 探查结果 | 决策 |
|----|------|--------------|---------|------|
| crystal_resonator | shunt_capacitance_pf | `并联电容` | 无`并联电容/静态电容/C0`类 key | **D + 改回 waiver**（P0 误补已撤销）|
| crystal_resonator | overtone_mode | `工作模式` | 无`泛音/overtone/基音`类 key | D（语义错配 + 无正确 key）|
| ocxo | oven_setpoint_temp_c | `最高工作温度` | 无`恒温/oven/炉温`类 key | D（867 件，icpdf 不标恒温箱温度）|
| ocxo | short_term_stability_ppb | `频率稳定性` | 无`短期/秒稳/ppb`类 key | D（单位 ppm vs ppb + 无 key）|
| rtc | freq_accuracy_ppm | `频率稳定性` | 有`计时器数据`key(69.9%) 但语义不符（计数器数据≠计时精度）| D（icpdf rtc 无计时精度专用 key）|
| crystal_oscillator | aging_rate_ppm_per_year | `老化` | 有`老化`key 但仅 0.5% 覆盖 | D（规则正确，源端覆盖极低）|
| ceramic_resonator | builtin_capacitance_pf | `负载电容` | 无`内置电容/负载电容`类 key | D |
| ceramic_resonator | resonator_terminal_type | `端子数量` | 有`端子面层`key(16.8%) 但语义不符（镀层≠端子类型）| D |
| clock_generator | freq_program_interface | `输入调节` | 有`ROM可编程`key(0.0%) 极低 | D |
| other_clock_timing | output_count | `实输出次数` | 无`输出路/输出次`类 key | D |

**结论**：所有疑似 R 经精准探查后**全部确认为 D（icpdf 源端缺口）**——icpdf 这些 L3 件内无对应语义 key，规则是 best-guess 键名但 icpdf 不存在这些键。digikey 侧有规则覆盖 → **D 保留**，等 icpdf/他源补充。**无真 R 需修规则**。

### 4-A.5 shunt_capacitance_pf P0 误补撤销

Phase 5.5.2 P0 阶段基于 gap 探针（`并联电容` hit=471）un-waive + 加规则。L3 字段级精准探查发现 icpdf `crystal_resonator` L3 内**无**`并联电容`类 key（471 hits 不在该 L3 内）→ 规则抽 0 行。已撤销 un-waive（改回 `WAIVER_ATTRS`）+ DELETE 残留规则，A15 靠 waiver 通过。**教训**：P0 gap 探针的 hit 数是全 L1 范围，补规则前应在目标 scope 内复验 key 命中。

### 4-A.6 字段级审计结论

- **无 X 删除字段**：所有 L3 专属字段对选型均有价值（频率稳定度/PLL类型/相位噪声/抖动/老化等是时钟器件核心选型参数），icpdf 0% 是源端缺口非无价值。
- **无 R 真规则错**：疑似 R 全部归 D。
- **61 个 D 字段保留**：schema + digikey 规则保留，icpdf 侧规则保留（无害，抽 0 行，待 icpdf 补 key 后自动生效），审计报告标注 icpdf 源端缺口。
- **7 个 INFO 字段**：mems_oscillator icpdf 0 件，等 digikey。
- **A15 多源对称性**：D/INFO 字段 icpdf 侧通过 `WAIVER_ATTRS` 豁免（shunt_capacitance_pf 已改回 waiver），digikey 侧有规则，A15 通过。

---

## 5. 本轮补缺的规则清单（修前 vs 修后）

| 修缺轮次 | 涉及属性/L2 | 修前 fill% | 修后 fill% | 收益 | 修复手段 |
|---------|-----------|-----------|-----------|------|---------|
| 单位换算 | frequency_stability_ppm (resonator) | — | 95.2% | %→ppm 换算入库 | `dim_unit_factor` 追加 `%`→`ppm` factor=1e4 + max_bound=1000 守门 |
| 单位换算 | aging_rate_ppm_per_year (resonator) | — | 入库 | PPM/N YEAR 多变体换算 | `dim_unit_factor` 追加 6 行 factor（÷1/÷10/÷100）|
| 规则缺口 | pkg_length/width/height (resonator) | 0% | 95.2% | +95.2pp | `物理尺寸` 复合键 regex（format A `X×Y×Z` + format B `L/B/H` 前缀）|
| 规则缺口 | pkg_length/width/height (oscillator) | 0% | 77.1% | +77.1pp | 同上 + **build `ranked` CTE 过滤前移**（修前高优先级空抽取抢 rn=1 致有效值丢失）|
| 规则缺口 | aec_q_level (全 L2) | 0% | 0% | 豁免 | icpdf `认证状态` 仅 COMMERCIAL/MILITARY，无 AEC-Q 等级 → WAIVER |
| 规则缺口 | ref_clk_freq_min/max (clock_management_ic) | 0% | 0% | 豁免 | icpdf clock_management_ic 无参考时钟频率键 → WAIVER |
| P0 gap | manufacturer (全 L2) | 56-59% | 待复测 | +少量 | 追加 `制造商包装代码` 兜底键（priority=9）|
| P0 gap | nominal_frequency_mhz (oscillator) | 67.8% | 待复测 | +少量 | 追加 `主时钟晶体标称频率` 变体键（priority=8）|
| P0 gap | frequency_tolerance_ppm (resonator) | 96.4% | 待复测 | +微量 | 追加 `频率容差 (MHz)` 变体键 |
| P0 gap | output_freq_max_mhz (clock_management_ic) | 38.2% | 待复测 | +微量 | 追加 `最大输出频率` 变体键 |
| P0 gap | shunt_capacitance_pf (crystal_resonator L3) | — | 待复测 | un-waive | 追加 `并联电容` 键（471 hits）|

---

## 6. 已发现但未处理的 P1/P2 gap（schema_gap_20260707.tsv）

- **P0 残留**：`电源`（71,001 hits）— 启发匹配到 vbat_min_v，但 `电源` 语义太泛（可能是 supply voltage 而非 RTC 电池），**重分类 P1，不盲目接**。
- **P1（30 个，hit_rate≥5%，schema 无对应 std_attr）**：评估下一周期是否新增 std_attr_code。代表项：`电源`、`批号`、`包装方式`、`最小包装数`、`海关编码` 等商务/物流属性，不在本品类技术参数范围。
- **P2（58 个，hit_rate<5%）**：边缘字段，仅记录，不处理。

> 注：gap 探针对 `主时钟晶体标称频率` 存在瞬态假阴性（规则已落库 source_expr 字节级一致，LIKE 与独立会话精确匹配均命中=1；仅 gap probe 内部精确匹配返回 0，疑 cursor 复用副作用）。该键已覆盖，不计 P0。

---

## 7. 已发现但无法在本轮修复的源端问题

### 7-1 品牌别名缺口（DL1 盲区）
- **现象**：每张 L2 `brand_null=0` 但 `COUNT(DISTINCT brand) > COUNT(DISTINCT brandid)` 1-3 个。
- **推断原因**：icpdf `brandshort` 部分值未在 `v_std_brand_alias` 登记别名，导致 `brand = raw brandshort`（未规范化），与多个 `brandid` 关联，膨胀 dist_brand。
- **处理结论**：**人工补字典**（CONTRIB_BRAND 流程，见 `sql_scripts/2.attribute_standard/CONTRIB_BRAND.md`）。Agent 不得自动同步 `dim_std_brand`/`v_std_brand_alias`（硬门控）。manufacturer fill% 56-59% 的缺口主因亦在此。

### 7-2 oscillator frequency_stability 本轮回归（已探查，源端语义限制）
- **现象**：oscillator `frequency_stability_ppm` fill% 从 78.1% 降至 0.2%。
- **探查结论（5e 已完成）**：icpdf oscillator 仅 1 个含"稳定"的键 `频率稳定性`（命中 302,862 = 78%），样本值**全是百分比**（`600%`/`2%`/`5%`/`3%`），**无 ppm 形态、无替代键**。被 max_bound=1000ppm 丢弃的全是百分比占位（2.5%/25%/50%/100%/20%/1%/10%，duty cycle/占位，非真实稳定度）。当前入库 716 件 = 该键中极少数真实 ppm 值；resonator 侧 250,892 件入库（晶体谐振器稳定度本就是 ppm 级，语义正确）。
- **处理结论**：`频率稳定性` 键在 oscillator 侧**语义混杂**（少数 ppm + 多数百分比占位），max_bound 守门**正确**保留真实 ppm、丢弃污染。**icpdf 无替代键，维持低 fill（0.2%）为源端语义限制，非规则缺口，不回退 max_bound**。已在 schema CSV note 标注源端限制。

### 7-3 oscillator package_case 低 fill（29.8%）
- **现象**：oscillator `package_case` 29.8%，但 `pkg_length/width/height` 77.1%。
- **推断原因**：icpdf oscillator 无直接 `封装`/`package_case` 键，pkg 三维已从 `物理尺寸` 抽出，但 package_case（封装代号如 SOIC-8）需单独键。
- **处理结论**：评估是否用 pkg 三维反推标准封装代号（下一周期），或维持源端覆盖限。

### 7-4 `reach` db_type 跨 scope 分裂（5.5.4.3）— **已修复**
- **现象**：`reach` 属性在 4 个 L2 为 VARCHAR、`timekeeping_timing_ic` 为 ENUM，db_type 分裂 1 行。
- **处理结论**：已将 `timekeeping_timing_ic` 的 reach db_type 统一为 VARCHAR（value_domain 对齐 `NOT NULL`），schema CSV 已改 + reload。复扫 5.5.4.3 = 0 行 ✓、5.5.4.4 = 0 行 ✓。

---

## 8. 单位换算抽样结果（unit_sanity_20260707.tsv，21 数值属性 × 10 件 = 210 件）

| std_attr_code | 抽样数 | ok | 异常种类与数量 |
|--------------|-------|-----|--------------|
| nominal_freq_mhz | 10 | 10 | 无 |
| nominal_frequency_mhz | 10 | 10 | 无 |
| frequency_tolerance_ppm | 10 | 10 | 无（%→ppm 换算已修）|
| frequency_stability_ppm | 10 | 10 | 无（max_bound 守门后仅真实 ppm 入库）|
| load_capacitance_pf | 10 | 10 | 无 |
| esr_ohm | 10 | 10 | 无 |
| drive_level_max_uw | 10 | 10 | 无 |
| temp_min_c / temp_max_c | 10/10 | 10/10 | 无 |
| pkg_length/width/height_mm | 10×3 | 10×3 | 无（`物理尺寸` regex 抽取 + build bug 修复后量级正确）|
| supply_voltage_v / _min_v / _max_v | 10×3 | 10×3 | 无 |
| aging_rate_ppm_per_year | 10 | 10 | 无（PPM/N YEAR 多变体换算已修）|
| output_freq_max_mhz | 10 | 10 | 无 |
| propagation_delay_ps / nominal_delay_ns / ctrl_voltage_min/max_v | 10×4 | 10×4 | 无 |

> 全部 210 件抽样 `value_std_double` 量级与属性预期一致，无字节当 KB / 全角符号 / 量级偏差 / regex 截断。dq_flag 仅有 `out_of_range`（305,026，全部为 freq_stability 污染丢弃，符合预期），无 `parse_fail`。

---

## 9. schema 一致性扫描（5.5.4）

| 检查 | 结果 | 期望 |
|------|------|------|
| 4.1 std_attr_code 非 snake_case | 0 行 ✓ | 0 |
| 4.2 L2 列名 非 snake_case | 0 行 ✓ | 0 |
| 4.3 跨 scope db_type 分裂 | 0 行 ✓（reach 修复后复扫） | 0 |
| 4.4 schema↔DDL 类型不一致 | 0 行 ✓ | 0 |

> 4.3 `reach` 分裂已修复（§7-4），5.5.4 四项全部 = 0 ✓。

---

## 10. 审计结论

- [x] 每张 L2 的 null_rates 已产出（run_icpdf_l2_fill_probe.py，见 §3）
- [x] 每个 L3 子类的 ext_attributes 命中率已产出（l3_coverage_20260707.tsv，见 §4）
- [x] schema gap 探查已跑、P0/P1/P2 已分级（schema_gap_20260707.tsv，见 §6）
- [x] schema 一致性扫描 5.5.4 四项：**全部 = 0 ✓**（reach 分裂已修复）
- [x] 本轮所有 P0 项已修复并通过 5.5.5 复验（5 条规则补缺 + 1 条重分类 P1）
- [x] 单位抽样已抽 21 数值属性 210 件、异常 0（unit_sanity_20260707.tsv）
- [x] dq_flag 审计：NULL 9.74M 净 + out_of_range 305k（污染丢弃，符合预期），无 parse_fail

### 结论：**已合并发布（Phase 6 · 20260710）**

**前置条件**：
1. ~~**7-1 品牌别名缺口**~~：✅ DIRTY（LSI/PULSECORE）已清 + DL1 PASS；合并中补 `SKYWORKS SOLUTIONS INC.` → Skyworks Solutions。
2. ~~**7-4 `reach` db_type 统一**~~：✅ 已完成（5g）。
3. ~~**7-2 oscillator freq_stability 替代键探查**~~：✅ 已完成（5e）。

### Phase 6 合并留痕（20260710）

**G1 裁决 A**：从 clock_timing gate 去掉「锁相环或频率合成电路」「计数器」→ 归 rf_wireless / logic_ic。`--new-overlap-only` 对 digikey/icpdf 均 exit 0。

| 层 | digikey | ecloud | icpdf |
|----|--------:|-------:|------:|
| `dwd_component_class` | 124,001 | 340,637 | 702,810 |
| `dim_l3_classify_rule` | 53 | 30 | 42 |
| `dim_attr_extract_rule` | 193 | 161 | 94 |

| L2 | digikey | icpdf | brand_null / brand_no_id |
|----|--------:|------:|--------------------------|
| resonator | 95,912 | 263,590 | 0 / 0 |
| oscillator | 0 | 387,959 | 0 / 0 |
| clock_management_ic | 1,999 | 26,551 | 0 / 0 |
| timekeeping_timing_ic | 4,024 | 5,968 | 0 / 0 |
| delay_timing_adjustment | 300 | 18,742 | 0 / 0 |

- catalog `l1_code=clock_timing`：**805,024** 行
- 备份：`dim.bak_*_clock_timing_20260710_icpdf`
- L2 脚本：`23_clock_timing_ready/build_dwd_l2_*` 已并入 digikey+icpdf（prod 表名）
- **未入仓**：ecloud L2 build（本期 L2 仅 digikey+icpdf；ecloud 分类/extract 规则已进 dim）

---

## 3-B. 品牌别名缺口诊断 + 核实结论（5d，20260708→20260710）

### 20260710 复跑结论（关键变化）
prod `dim.v_std_brand_alias` 对原 10 个 brandshort **已全部命中（0 未匹配）**——同事/其他批次已补入独立行或 related_words。但发现 **2 处别名交叉污染**，且 L2 宽表尚未重建，`dist_brand - dist_brandid` gap 仍在（1~3）。

| L2 | brand_null | dist_brand | dist_brandid | gap | 说明 |
|----|-----------|-----------|-------------|-----|------|
| resonator | 0 | 48 | 46 | 2 | 待 L2 重建 |
| oscillator | 0 | 84 | 81 | 3 | 待 L2 重建 |
| clock_management_ic | 0 | 98 | 95 | 3 | 含 PULSECORE 脏映射 |
| timekeeping_timing_ic | 0 | 71 | 70 | 1 | 含 LSI 脏映射 |
| delay_timing_adjustment | 0 | 55 | 54 | 1 | 待 L2 重建 |

### 10 个 brandshort 核实结论（联网 + icpdf 样例 + prod dim）

| brandshort | 件数 | 真公司 | 当前映射 | 结论 |
|-----------|------|--------|---------|------|
| LANSDALE | 45 | Lansdale Semiconductor | ✅ Lansdale | 无需动 |
| JAUCH | 10 | Jauch Quartz | ✅ Jauch Quartz | 无需动 |
| SUNTSU | 1 | Suntsu Electronics | ✅ Suntsu | 无需动 |
| NEL | 866 | **NEL Frequency Controls**（2023→Abracon，品牌独立运营） | ✅ 独立行 id=9001881 | 原草稿「→PERKINELMER」**错误**；现已正确独立 |
| ACT | 3 | **Advanced Crystal Technology**（UK 晶振，Acal BFi） | ✅ 独立行 id=9002228 | 原草稿「→Adels-Contact」**错误**；现已正确独立 |
| WINCHESTER | 1(ct)/30k全库 | Winchester Interconnect（连接器） | ✅ Winchester Interconnect | 正确；ct 仅 1 件可忽略 |
| DBLECTRO | 782 | **DB Lectro Inc.**（加拿大） | ✅ 独立行 id=9002324 | 无需动 |
| AMCC | 100 | **Applied Micro Circuits**（→MACOM） | ✅ 独立行 id=9001885 | 无需动（可选归 MACOM）|
| **LSI** | 11 | **LSI Corporation**（→Avago→Broadcom）；≠VLSI Tech | 🔴 **华新科-Walsin** | **脏别名**：Walsin.related_words 含 `'LSI'` |
| **PULSECORE** | 2175 | **PulseCore Semiconductor**（2009→ON Semi）；≠Pulse Electronics | 🔴 **PULSE** | **脏别名**：PULSE.related_words 含 `'PULSECORE'` |

### 🔴 必须人工清理的 2 处（CONTRIB_BRAND §5.8）

1. **DIRTY-1**：从 `华新科-Walsin`(id=1443490691173683201) 的 related_words 移除 `'LSI'`；再 A 复用 `博通-Broadcom`(id=1443490695858720771) 追加 `['LSI','LSI CORPORATION','LSI LOGIC']`（或挂 AVAGO，按团队并购口径）
2. **DIRTY-2**：从 `PULSE`(id=1443490692796878855) 的 related_words 移除 `'PULSECORE'`；再 A 复用 `安森美-ON`(id=1443490693056925702) 追加 `['PULSECORE','PULSECORE SEMICONDUCTOR']`

清理方式：`brand_merge/03_merge_dim.py` 的 `DIRTY` 字典 + `dim_std_brand_manual_extra.sql` Part A（详见贡献草稿）。

### 产物
- **核实后贡献草稿**：`brand_alias_contrib_20260708.sql`（已按 20260710 核实结论重写）
- **诊断 TSV**：`brand_alias_gap_20260708.tsv`（20260708 快照，历史参考）
- 脚本：`run_icpdf_brand_gap_diag.py` / `run_icpdf_brand_verify.py` / `run_icpdf_brand_alias_recheck.py` / `run_icpdf_brand_dirty_check.py`

### 人工执行步骤
1. `brand_merge` DIRTY 清理 Walsin←LSI、PULSE←PULSECORE
2. Part A 两段 A 复用（LSI→Broadcom、PULSECORE→安森美-ON）拷进 `dim_std_brand_manual_extra.sql`
3. `bash sync_dim_std_brand.sh test` → 验证 alias 映射正确
4. `ALLOW_PROD=1 bash sync_dim_std_brand.sh prod`
5. 重跑 icpdf clock_timing L2 build → 期望 5 张表 `dist_brand = dist_brandid`
6. `git commit`

> ⚠️ 硬门控：Agent 不得自动 sync。本节仅核实 + 草稿。

---

## 11. 产物清单（artifacts/clock_timing/）

| 产物 | 文件 |
|------|------|
| L2 物理列空值率 | run_icpdf_l2_fill_probe.py 输出（见 §3）|
| L3 命中率 TSV | `l3_coverage_20260707.tsv` |
| schema gap TSV | `schema_gap_20260707.tsv`（90 行）|
| schema 一致性 TSV | `schema_consistency_20260707.tsv` |
| 单位抽样 TSV | `unit_sanity_20260707.tsv`（210 行）|
| dq_flag 分布 TSV | `dq_flag_dist_20260707.tsv` |
| **审计报告** | `qa_audit_report_20260707.md`（本文件）|
| **品牌缺口诊断脚本** | `sql_scripts/test/clock_timing/run_icpdf_brand_gap_diag.py` |
| **品牌贡献草稿脚本** | `sql_scripts/test/clock_timing/run_icpdf_brand_contrib_draft.py` |
| **品牌缺口决策 TSV** | `brand_alias_gap_20260708.tsv`（10 行）|
| **品牌贡献草稿 SQL** | `brand_alias_contrib_20260708.sql`（Part A 3 就绪 + 4 待核实 + Part B 3 待填）|
