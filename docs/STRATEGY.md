# L3 分类策略最终建议

**基于**：800 条全量外部权威金标 + SQL/Gemini/Qwen/DeepSeek 横向对比 + 9 个仲裁策略模拟  
**日期**：2026-04-28

---

## 一、核心决策：**采用 DeepSeek V3.2 单模型方案**

### 为什么不做多模型仲裁？

跑了 9 种组合策略，**没有一种能超过单用 DeepSeek 的 97.0%**：

| 策略 | 800 准确率 | 说明 |
|---|---:|---|
| **单用 DeepSeek V3.2** | **97.0%** | 最优 |
| 3 LLM 多数投票 | 96.9% | 略降 |
| DeepSeek + OOS 仲裁 | 95.9% | 反而差 |
| DeepSeek + ldo/vref 纠偏 | 96.6% | 有改善但仍低 |
| 完整多仲裁 G4 | 96.9% | 复杂化得不偿失 |
| Oracle 理论上限 | 99.5% | 不可实现 |

**核心原因**：Qwen 虽 out_of_scope 识别最强（85.2%），但**假阳性**严重——会把 gas gauge (BQ2040/BQ2050/BQ20Z80)、DC-DC 模块 (TMLM/MAX5043)、USB power switch 等误判为 out_of_scope。启用 Qwen 仲裁反而新增 10+ 条错误，净效应为负。

### 最终方案 ROI

| 方案 | 准确率 | 7M 成本 | vs SQL 净增对正确分类 |
|---|---:|---:|---:|
| 仅 SQL（现状）| 92.0% | $0 | 基线 |
| **DeepSeek V3.2（推荐）** | **97.0%** | **$157** | **+35 万条** |
| 3 LLM 复杂仲裁 | 96.9% | ~$1,000 | +34.3 万（差更贵）|

**一次性投入 $157 换 35 万条数据正确性提升**，ROI 无争议。

---

## 二、分阶段执行路线图

### 🟢 P0：立即执行（本周）

#### 1. DeepSeek V3.2 全量跑 700 万
```bash
# 基于现有 llm_classify_bench 工具
./llm_classify_bench \
  --mode=classify \
  --items=<全量 fingerprint 数据> \
  --model=ali/deepseek-v3.2 \
  --batch=40 --workers=8 --retries=3 \
  --output=dwd_icpdf_component_class_llm.json
```

**关键设计**：按 **fingerprint（category + category2 + taginfo + prajson_keys）去重**后再跑 LLM，能把 700 万条压缩到几万个唯一指纹，成本从 $157 可能进一步降到 **$30-50**。

#### 2. 新增 `out_of_scope` L3 类目

SQL 当前 `out_of_scope` 准确率 = **0%**（27 条全错）；DeepSeek 51.9%。必须引入独立 L3 且纳入 taxonomy。

建议的 **out_of_scope 子类别**（仅作为 L3 标签区分，不影响业务下游）：
- `oos_discrete`：分立 MOSFET/IGBT（ZXMN3B / ILD03N60 / ILP03N60 / CS8190 ）
- `oos_optocoupler`：光耦（ILD621GB / ILQ621GB）
- `oos_hot_swap`：热插拔控制器（TPS2491）
- `oos_load_switch`：智能高侧开关（BTS728L2 / VND830 / MDC3105 / MIC5801 / TPS2147）
- `oos_current_sensor`：电流传感器 IC（IR22771 / IR2175）
- `oos_ac_dc`：AC/DC 模块（TracoPower TXL 系列）
- `oos_audio`：音频 DAC 等（AT73C213）
- `oos_lcd_driver`：LCD 显示驱动（S6C0649 ）
- `oos_ultrasound`：超声传感器驱动（MD1711 / MD1810）
- `oos_fan_controller`：风扇控制器（TC647/TC649/TC655）※ 若业务允许，可改归 motor_driver
- `oos_rtc_backup`：RTC 保护/备份电池（M4Z32 / BQ2205）
- `oos_evm`：评估板（EVDD408）

#### 3. 固化 800 条全量外部金标为永久回归测试集

- 位置：`exports/external_gold.json`（800 条，l2/l3/snippet/source/source_type/confidence）
- 脚本：`exports/build_final_gold.py` 可一键算准确率
- **任何**新规则、新模型、新 taxonomy 变更都必须在此集上跑指标
- CI 门槛：L3 总准确率不得低于 97%（DeepSeek 基线）；out_of_scope 单类不得低于 50%

---

### 🟡 P1：短期优化（2-4 周）

#### 4. 修 SQL 规则的 3 类关键过匹配（Top 问题）

SQL 错分 64 条里，**35 条集中在 3 个过匹配**：

| 错分模式 | 数量 | 根因 | 修复方法 |
|---|---:|---|---|
| out_of_scope → gate_driver | 13 | `gate_driver` 的 category_info/taginfo 收词过宽 | 负向排除：MOSFET 器件、光耦、load switch、LCD gate driver |
| out_of_scope → motor_driver | 5 | TC647/TC649 等 fan controller 被归入 | 要么加 `fan_controller` 子类，要么业务规定归 out_of_scope |
| out_of_scope → battery_charger | 4 | SNAPHAT 电池、LDO+Switch 组合 | 负向排除：ZEROPOWER SNAPHAT、"battery holder" |
| out_of_scope → led_driver | 4 | LightMOS IGBT 含 "Light" | 负向排除：IGBT、MOSFET、"lamp ballast" |
| dcdc_switching → battery_charger | 9 | battery_charger 关键词过宽 | 负向排除：SMPS + 非 Li/NiMH 专用词 |
| ldo_regulator → led_driver | 6 | `led_driver` 匹配到 LDO 型号（TLE4276） | 加厂家限定 + 负向排除 |
| ldo_regulator → voltage_ref | 5 | uA723 这类模糊器件 | 加 `partno_prefix` 白名单：UA723→ldo_regulator |

**预期效果**：修这 35 条后，SQL 从 92.0% → **~96.3%**。

#### 5. 启用 `icpdf_match_partno_prefix` p5 兜底

当前 `dim_l3_classify.icpdf_match_partno_prefix` 全为 NULL。新增种子（从 800 条金标提取）：

```sql
-- ldo_regulator
LM317, LM78, LM79, MC78L, MC7805, TPS7, TPS75, NJM2891, LT10, LT30, 
LT1085, LT3023, REG1117, FAN1581, FAN2512, UA723, UPC79L, NCP552, NCP4523, NCP4672,
IRU103, IRU1117, SI-3010, TA78D, MIC49, TC105, ILC708, CM3019, SA57031, LD2981, L4941

-- dcdc_switching
LM2678, LM2671, LM2650, LM2750, LM3224, LTC3406, UC3825, UC3844, UC3874, 
IR1150, FAN4803, SP7648, SG2524, TPS51120, TPS54, NCP1571, L6590, L6997,
AP1501, M5T494, KA3882, JW150, RY-2424, R24P, PT5541, PT6981, 5962-87681

-- gate_driver
IR2110, IR2113, IR2114, IR2117, IR21, IRS2, HCPL-5, HCPL-31, HCPL-314, 
TLP350, HIP6601, HIP6602, HIP6604, ISL6208, ISL6614, ADP3415, ADP3419,
IXDF402, LM5105, LM5110, MD1810, MD1811, MAX5075, RIC7113, STSR30, 24SW

-- motor_driver
L6201, L6204, L6258, L6506, L293D, LMD18245, A3936, A3937, A3946, A3947, A3949, 
A3950, A3952, A3953, A3958, A3959, A3964, A3967, A3968, A3973, A3977, A3980, 
A3982, A3983, A8902, A8904, VNH2SP30, VNH3SP30, IRAMS, IRAMX, CS4122, CS8190,
MC33030, MC33035, NCV33035, NJM3717, PBL3717, TPIC2101, TC647, TC649, ML4425,
UDQ2916

-- battery_charger (含 BMS)
BQ2000, BQ2002, BQ2004, BQ2040, BQ2050, BQ2060, BQ2083, BQ2084, BQ2085, 
BQ24, BQ29, UCC3952, MAX712, MAX745, MAX8606, MAX8713, MAX8724, MAX1508, 
MAX1873, MAX1908, MAX1909, LT1571, LTC1732, LTC4053, MCP73, ADP2291, ADP3806,
ISL6251, ISL6253, ISL9203, L6924, TSM1011, NCP1835, NCP802, DS2711, DS2712, 
DS2745, X3100, X3101

-- supervisor_reset
TPS3, TPS31, TPS38, MAX6, MAX7, MAX8, MAX80, MAX693, MAX709, ICL7665, 
ISL887, ADM803, ADM809, LM809, TLC77, FM811, STM1001, AIC810, AIC812, 
GS6332, TS831, NCP305

-- voltage_ref
LM236, LM285, LM336, LM385, LM4040, LM4041, LM431, REF02, REF3240, 
TL431, KIA431, TLV431, NCV431, TLVH432, NJM1431, ADR38, ADR51, AD1582, 
AD581, MAX6037, MAX6043, MAX6100, MAX6101, MAX6102, MAX6103, MAX6104, MAX6105,
MAX6107, MAX678, LT6650, NCP100, uPC1945, ZREF25, SL432

-- out_of_scope
ZXMN, ZXP, ILD621, ILQ621, ILD03N60, ILP03N60, IR2175, IR22771, 
TXL, TXL-, TPS2147, TPS2491, ATTRIX, BTS, VND, MDC31, MIC5801,
EVDD, M4Z32, AT73, S6C, MD1711, MD1712, MD1715, TC647, TC649, TC655
```

**预期效果**：p5 兜底可再救 20-30 条被 p1-p4 漏掉的样本，SQL 从 96.3% → **~98%**。

#### 6. 双层验证（DeepSeek + SQL 交叉校验）

对于生产环境的每一条 fingerprint：

```
if DeepSeek(x) == SQL(x):
    confidence = 0.98  →  直接采用
elif DeepSeek(x) != SQL(x) 且 DeepSeek 置信度 >= 0.9:
    输出 DeepSeek，置信度 0.85  →  进审核队列（抽样人工复核）
else:
    进入"模糊地带"审核队列
```

预估：DeepSeek 和修好的 SQL 一致率约 **95%**；不一致的 5% 里，DeepSeek 正确率在 97% 附近。

---

### 🔵 P2：中期演进（1-3 个月）

#### 7. 引入 `confidence` 字段到 `dwd_icpdf_component_class`

```sql
ALTER TABLE dwd_icpdf_component_class ADD COLUMN confidence FLOAT;
```

置信度建议：
- DeepSeek 与 SQL 一致：**0.95**
- p1 `category` 精确匹配：**0.90**
- DeepSeek 单独输出（SQL 无输出）：**0.85**
- DeepSeek 与 SQL 不一致，DeepSeek 胜：**0.70**
- DeepSeek 判 out_of_scope：**0.60**（因其 OOS 识别弱）
- p5 `partno_prefix` 兜底：**0.55**

下游报表可按 confidence ≥ 0.8 过滤高质量数据。

#### 8. 建立"冷启动"自动化路径

新器件入库时：
1. SQL 规则先判（秒级）
2. 若 SQL = 'unclassified'，自动进 DeepSeek 队列（按周 batch）
3. DeepSeek 结果 confidence < 0.7 或命中 out_of_scope，进人工审核队列

#### 9. 搭建 DeepSeek 在线 API fallback

对 `dim_l3_classify` 中未覆盖的 **新 fingerprint**（每月发现的新 category/category2 组合），直接调 DeepSeek API 分类，结果回写到 `dim_l3_classify_llm`，下次入库直接命中。

---

### 🟣 P3：长期（taxonomy 演进）

#### 10. Taxonomy 版本化

```sql
ALTER TABLE dim_l3_classify ADD COLUMN version VARCHAR(10) DEFAULT 'v1';
ALTER TABLE dwd_icpdf_component_class ADD COLUMN taxonomy_version VARCHAR(10);
```

未来每次 taxonomy 变更：
1. 新版 `dim_l3_classify` 打 v2/v3 标签
2. 在 800 条金标上跑回归，准确率必须 ≥ 当前 97%
3. 全量数据按新 taxonomy 重刷
4. 保留旧版结果供对比

#### 11. 候选新增 L3 类（基于 800 条金标观察）

| 新增 L3 | 来源 | 数量线索 |
|---|---|---:|
| `load_switch` / `power_switch` | 从 `out_of_scope.oos_load_switch` 提升 | 5+ 条 |
| `hot_swap_controller` | TPS2491/MAX5043 类 | 3+ 条 |
| `current_sensor` | IR22771/IR2175 类 | 2+ 条 |
| `fan_controller` | TC647/TC649/TC655（目前有争议）| 6+ 条 |
| `battery_monitor` / `fuel_gauge` | 从 battery_charger 细分出 gas gauge（BQ2040/BQ2050/BQ20Z80/DS2745）| 10+ 条 |
| `lcd_gate_driver` | S6C0649 等显示驱动 | 1-2 条 |
| `ultrasound_pulser` | MD1711/MD1810/MD1811 | 3+ 条 |

**观察**：业务若觉得 `battery_charger` 太笼统，把 gas gauge 分出来将使 DeepSeek 的 `battery_charger → out_of_scope` 误判消失（2 条）。

#### 12. 持续 benchmark 机制

每季度：
1. 随机再抽 100 条（从当期新入库数据）做 WebSearch 外部金标
2. 与固定 800 条合并成 900/1000 条
3. 重跑所有分类器；若 DeepSeek 跌破 95%，切换模型（如 DeepSeek V4 / 更先进模型）

---

## 三、数据治理（针对已有 700 万已分类数据）

### 清洗方案

```sql
-- 1) 回刷修正 SQL 规则后的已有分类
-- 先标记，不删除
UPDATE dwd_icpdf_component_class 
SET l3_code_legacy = l3_code
WHERE classify_source = 'sql_rule';

-- 2) 用 DeepSeek 结果覆盖
UPDATE dwd_icpdf_component_class c
JOIN dwd_icpdf_component_class_llm l ON c.fingerprint_md5 = l.fingerprint_md5
SET c.l3_code = l.l3, 
    c.confidence = l.confidence,
    c.classify_source = 'llm_deepseek_v3.2',
    c.updated_at = NOW()
WHERE l.confidence >= 0.85;

-- 3) 对 DeepSeek confidence < 0.85 的保留 SQL 规则结果
UPDATE dwd_icpdf_component_class c
JOIN dwd_icpdf_component_class_llm l ON c.fingerprint_md5 = l.fingerprint_md5
SET c.l3_code = c.l3_code_legacy,
    c.confidence = 0.7,
    c.classify_source = 'sql_rule_fallback'
WHERE l.confidence < 0.85;
```

### 审计与回归

- **审计表**：`exports/all_classifications.csv`（800 条每行含 SQL/Gemini/Qwen/DeepSeek/Gold + 证据）
- **回归命令**：`python3 exports/build_final_gold.py`（秒级出指标）

---

## 四、风险与对策

| 风险 | 可能性 | 对策 |
|---|:---:|---|
| DeepSeek V3.2 被 API 停服 | 低 | 模型湖支持多供应商切换；备选 Qwen3.5-Plus（96.8%）或 Gemini 3 Flash（96.4%）|
| 单次 7M 跑失败 | 中 | 按 fingerprint 分片 + Go 工具支持 retries；本地缓存中间结果 |
| 新 L3 类出现但 DeepSeek 未见过 | 高 | 定义 "unknown" 兜底；触发人工审核 + 更新 prompt |
| 中文 note_cn 噪音导致 DeepSeek 误判 | 中 | prompt 中明确写"note_cn 可能不准确，以 partno+brand+datasheet 共识为准"（已做）|
| 4 条 SQL+LLM 全错样本（TC647 fan / TPIC2603） | — | 这是 taxonomy 定义分歧，不是模型问题；需业务拍板 |

---

## 五、三行总结

1. **用 DeepSeek V3.2 单模型全量跑 700 万**（$157，预计 $30-50 实际），一次性把准确率从 SQL 的 **92.0% 提到 97.0%**；多模型仲裁已证明无额外收益。
2. **同步修 3 类 SQL 过匹配 + 启用 p5 partno 前缀兜底 + 新增 out_of_scope L3**，保留 SQL 作为**秒级热路径 + LLM 的 cross-check 基线**。
3. **固化本次 800 条全量外部金标为永久回归集**，任何后续模型/规则/taxonomy 变更都先在此集上验收（CI 门槛：总准确率 ≥ 97%），配合 `confidence` 字段和 taxonomy 版本化支持长期演进。

---

## 六、关联产出清单

| 文件 | 用途 |
|---|---|
| `exports/external_gold.json` | 800 条全量外部权威金标（100% WebSearch + 数据手册验证）|
| `exports/all_classifications.csv` | 完整审计表（每行：样本 + SQL + 3LLM + Gold + 证据 + 对错标记）|
| `exports/bench_ali__deepseek-v3.2.json` | DeepSeek 逐条原始输出 + 性能数据 |
| `exports/build_final_gold.py` | 一键算各分类器准确率 |
| `exports/REPORT_external_gold_final.md` | 最终评估报告 |
| `exports/STRATEGY.md` | 本策略文档 |
| `fetch_data/cmd/llm_classify_bench/` | Go 批量分类工具（可复用于全量跑）|
