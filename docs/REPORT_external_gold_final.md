# L3 分类器最终评估报告（外部权威金标版）

**日期**：2026-04-28（v4 完全版，外部金标 302 → **800 条全量**）
**样本**：800 条，8 个 L3 × 100 条  
**金标等级**：
- **Tier 1（最高置信）：800 条 = 100% 全量外部权威验证**（TI/Infineon/IR/ST/Maxim/Allegro/Renesas/Microchip/ON Semi/NJRC/Fairchild/Linear/Vishay/Intersil/Sanken/Mitsubishi/Diodes-Zetex/TE-MACOM/Recom/Sipex/Ricoh/ADI/Supertex/NEC/Philips/AUK/Impala/CalMicro/Maxwell 等 30+ 厂家官网 + 数据手册）
- Tier 2 / Tier 3 降级：**所有 800 条已进入 Tier 1**，无需再借助 LLM 共识降级

**100% 外部权威独立验证**，完全独立于 ICPDF 内部数据源

---

## 一、核心结论（800 条全量外部金标）

### 全量外部权威金标下的准确率（最终定稿）

| 排名 | 分类器 | 准确率（**800 条全量外部金标**） | 错分数 | 相对 SQL |
|:-:|---|---:|---:|---:|
| 🥇 | **DeepSeek V3.2** | **97.0%** | 24 | +5.0 |
| 🥈 | Qwen3.5-Plus | 96.8% | 26 | +4.8 |
| 🥉 | Gemini 3 Flash | 96.4% | 29 | +4.4 |
| 4 | SQL 规则 | **92.0%** | **64** | — |

### 金标规模演进（方法论可追溯性）

| 金标规模 | SQL | Gemini | Qwen | DeepSeek | DeepSeek - SQL |
|---:|---:|---:|---:|---:|---:|
| 118 条 | 60.2% | 87.3% | 88.1% | 89.0% | +28.8 |
| 198 条 | 72.7% | 87.9% | 88.9% | 89.4% | +16.7 |
| 302 条 | 82.1% | 91.4% | 92.1% | 92.4% | +10.3 |
| 374 条 | 82.9% | 92.2% | 93.0% | 93.6% | +10.7 |
| 502 条 | 87.3% | 94.2% | 94.8% | 95.2% | +7.9 |
| **800 条（全量）** | **92.0%** | **96.4%** | **96.8%** | **97.0%** | **+5.0** |

**关键趋势**：
- SQL 准确率随外部金标样本增加从 60.2% 稳步升至 **92.0%**（规模越大越收敛到真实水平）
- LLM 准确率从 89% 升到 97%（微幅增长，天花板效应）
- 两者差距从 29 pp 收窄到 5 pp，**但 LLM 始终领先，DeepSeek 始终第一**
- **LLM 比 SQL 高 4.4-5.0 个百分点**，相当于**每 100 条多对 5 条**；在 700 万全量上意味着 **LLM 比 SQL 多正确分类约 35 万条**

---

## 二、各分类器 per-L3 准确率（800 条全量外部金标）

| gold_l3 | n | SQL | Gemini | Qwen | DeepSeek |
|---|---:|---:|---:|---:|---:|
| battery_charger | 86 | 98.8% | 89.5% | 89.5% | **97.7%** |
| dcdc_switching | 110 | 89.1% | 94.5% | 95.5% | **99.1%** |
| gate_driver | 86 | 97.7% | 98.8% | 97.7% | **100.0%** |
| ldo_regulator | 108 | 88.9% | **98.1%** | 97.2% | 94.4% |
| led_driver | 86 | **100.0%** | **100.0%** | **100.0%** | **100.0%** |
| motor_driver | 98 | 94.9% | 95.9% | 98.0% | 98.0% |
| **out_of_scope** | **27** | **0.0%** | 77.8% | **85.2%** | 51.9% |
| supervisor_reset | 100 | 99.0% | 99.0% | 99.0% | **100.0%** |
| voltage_ref | 99 | 96.0% | **100.0%** | **100.0%** | **100.0%** |

**核心洞察**：
- `out_of_scope` 仍是 SQL **最大短板（0%）**；LLM 里 Qwen 表现最好（85.2%），DeepSeek 反而最弱（51.9%）→ DeepSeek 倾向强推类别而非 out_of_scope
- `led_driver`/`voltage_ref`/`gate_driver`/`supervisor_reset` 经典类别 DeepSeek 近满分
- `battery_charger` 上 Gemini/Qwen 较弱（89.5%）——把 gas gauge / battery protection / battery monitor 误归到 out_of_scope 或其他类（DeepSeek 更懂业界 "BMS 都归 battery_charger 广义" 的实务共识）

---

## 三、SQL 规则的系统性问题（清洗策略前提）

### L3 分布偏差（以 800 条全量外部金标为真）

| class | gold | sql | 偏差 | 问题 |
|---|---:|---:|---:|---|
| **out_of_scope** | **27** | **0** | **-27** | SQL **完全没有 out_of_scope 能力**（100% 漏判） |
| led_driver | 86 | 100 | **+14** | SQL 把 LDO/光耦/MOSFET/LCD gate driver 误归 LED driver |
| gate_driver | 86 | 100 | **+14** | SQL 把 load switch/current sensor/LCD gate driver 误归 gate_driver |
| battery_charger | 86 | 100 | **+14** | SQL 把 hot swap/load switch/音频 DAC/MOSFET controller 误归此 |
| dcdc_switching | 110 | 100 | -10 | SQL 漏判：DC-DC 模块/charge pump/PWM 控制器变体等被归到其他 |
| ldo_regulator | 108 | 100 | -8 | SQL 漏判：TLE4276/LT10xx/LM340 等经典系列 |
| motor_driver | 98 | 100 | +2 | 基本准确（Allegro A-系列覆盖好）|
| supervisor_reset | 100 | 100 | 0 | 准确（MAX/ICL/TPS/FM8xx 等系列稳定）|
| voltage_ref | 99 | 100 | +1 | 准确（LM4xxx/REF02/TL431 等系列稳定）|

### 五大根因

**1. icpdf `category_info`/`taginfo` 匹配过宽**
- `led_driver` L2 表里误收 TLE4276（LDO）、ILD621（光耦）、LightMOS（MOSFET 器件）、LM3224（通用 DC-DC）
- `battery_charger` L2 表里误收 TPS2491（hot swap）、MAX5043（dual SMPS IC）、AT73C213（音频 DAC！）

**2. 完全无 `out_of_scope` 通道**
- 智能 high-side switch（BTS728L2/VND830/ST890）
- 热插拔控制器（TPS2491/MAX5043）
- 光耦（ILD/ILQ621GB）、光电晶体管
- 电流传感器 IC（IR2175/IR22771）
- Alternator / piezoelectric / ultrasound driver 等

**3. H-bridge 边界不清**
- 带集成 power stage 的 H-bridge（L6201/L6205/L9997/SI9978）→ motor_driver
- 只驱动外部 MOSFET 的 MOSFET controller（A3935/A3946）→ gate_driver
- SQL 对两者不区分

**4. 精密参考 vs LDO 混淆**
- LM4132 系列 "precision voltage reference" 被 SQL 错归 ldo_regulator（4 条）
- uA723 系列同时具备 reference + regulator，业界归 linear regulator，SQL 混淆归 voltage_ref

**5. `partno` 前缀兜底未启用**
- `dim_l3_classify.icpdf_match_partno_prefix` 预留列全为 NULL
- 典型前缀（LM317 / TPS62xx / TL431 / IR21xx / BQ24xxx / DRV8xxx）能作为最可靠信号但从未用

---

## 四、模型性价比（最终版，800 条全量外部金标）

| 模型 | 全量外部准确率 | 耗时/800 | Token in/out | $/800 batch | 预估 $/700万全量 |
|---|---:|---:|---:|---:|---:|
| **DeepSeek V3.2** | **97.0%** | 6.8 min | 49k / 52k | **$0.018** | **$157** |
| Qwen3.5-Plus | 96.8% | 17.6 min | 55k / **223k** | $0.489 | $4,281 |
| Gemini 3 Flash | 96.4% | **3.9 min** | 56k / 46k | $0.132 | $1,152 |
| SQL 规则 | 92.0% | 秒级 | — | $0 | $0（但多错 35 万条）|

**综合最优：DeepSeek V3.2**
- 准确率领先（全量外部 97.0%）
- 最低成本（$0.018/800，$157/7M）
- token 输出最精简（65 token/条 vs Qwen 的 279）
- 速度中等（6.8 min）

**次选：Qwen3.5-Plus**
- out_of_scope 识别能力最强（85.2% vs DeepSeek 51.9%）
- 如果业务特别重视 out_of_scope 精度，可用 Qwen 做 **仲裁层**（DeepSeek 主判 + Qwen 对 out_of_scope 边界二次校验）

---

## 五、三句话总结（最终定稿）

1. **800 条 100% 外部权威金标下**（30+ 厂家官网 + 数据手册交叉验证），SQL 规则准确率 **92.0%**，DeepSeek V3.2 **97.0%** 领先 5 pp；SQL 真实错分 64 条（主要来自 27 条 out_of_scope 全错 + 42 条类别边界错判）。
2. **DeepSeek V3.2 综合最优**：$157 可处理 700 万全量，全量外部金标准确率 97.0%，是 Gemini 的 1/7 成本、Qwen 的 1/27 成本；Qwen 在 out_of_scope 上最强，可做仲裁层。
3. **行动建议**：立即跑 DeepSeek 全量 + 引入 `out_of_scope` L3 + 修 3 类 SQL 过匹配（battery_charger/led_driver/gate_driver）+ 启用 `partno` 前缀兜底；**固化本次 800 条全量外部金标为永久回归测试集**（独立于任何内部数据源，可无偏评估任何新分类器）。
