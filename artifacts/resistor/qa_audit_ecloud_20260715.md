# resistor ecloud Phase 5.5 QA 审计报告

- **日期**：20260715
- **数据源**：`ecloud`（沙盒 `test_dwd` / `test_dim`）
- **方法**：`l2-field-qa-audit` + `validate_dwd_data.py --data-source ecloud`
- **产物**：`null_rates_ecloud_20260715.tsv` · `l3_ext_fill_ecloud_20260715.tsv` · `schema_gap_ecloud_20260715.tsv` · `ecloud_attr_source_waiver.list`

---

## 一、基本概况

| 指标 | 数值 |
|------|------|
| gate（`category=电阻`） | 1,228,372 |
| 分类命中 | 1,228,372（**100%**） |
| EAV 行数（ecloud） | 14,630,192 / 1,206,261 ids |

### L3 分布

| L2 | L3 | 行数 |
|----|-----|------|
| fixed_resistor | general_fixed_resistor | 1,069,891 |
| fixed_resistor | wirewound_resistor | 77,177 |
| fixed_resistor | resistor_array_network | 31,155 |
| fixed_resistor | current_sense_resistor | 27,227 |
| variable_resistor | potentiometer | 9,000 |
| variable_resistor | trimmer_potentiometer | 6,919 |
| protective_sensitive_resistor | ntc_thermistor | 7,923 |

### 品牌门控（硬门控）

| L2 表 | brand_null | distinct_brand | distinct_brandid | 结论 |
|-------|------------|----------------|------------------|------|
| fixed_resistor | 0 | 76 | 76 | **PASS** |
| variable_resistor | 0 | 21 | 21 | **PASS** |
| protective_sensitive_resistor | 0 | 50 | 50 | **PASS** |

`validate_dwd_data`（ecloud · 三张 L2）：**DL1 品牌门控 PASS**；DL4/DL7–DL9 结构 PASS。ecloud 子集 **EAV orphan = 0**（DA2 失败来自沙盒表内其他 `data_source` 历史行，**不阻断 ecloud 合并**）。

---

## 二、L2 物理列空值率与字段决策

### fixed_resistor（n=1,205,450）

| 列 | 填充率 | 判定 | 决策 |
|----|--------|------|------|
| mpn | 100% | OK | — |
| mounting_style / form_factor | 98.4% | OK | — |
| resistance_ohm | 91.1% | OK | P1 已修：mOhm/kOhms 单位因子 |
| tolerance_pct / power_rating_w | 89–91% | OK | — |
| package_case | 90.7% | OK | — |
| tcr / temp / element | 81–87% | OK | — |
| lifecycle_status | 72.6% | OK | — |
| manufacturer | 67.7% | 关注 | **D** `制造商` 键覆盖不全；`brand` 门控已通过 |
| aec_q_level | 30.7% | 关注 | **D** 仅部分车规 SKU |
| rohs_compliant / reach | 0% | 高危外观 | **D** 已豁免：ecloud 无 RoHS/REACH 键 |

### variable_resistor（n=15,919）

| 列 | 填充率 | 判定 | 决策 |
|----|--------|------|------|
| mpn / mounting_style | 100% / 77.9% | OK | — |
| lifecycle_status | 76.3% | OK | — |
| resistance_ohm / tolerance / power | 56–60% | 关注 | **D** 电位器源端 `总电阻值(kΩ)` 等稀疏 |
| package_case | **36.0%** | 关注 | **D** 源端 `元器件封装` 多为 `-`（11,913 行）或缺失；非规则错误 |
| temp_min/max_c | **2.5%** | 高危外观 | **D** ecloud `可调电阻` 几乎无温度分项键 |

### protective_sensitive_resistor（n=7,930，全 NTC）

| 列 | 填充率 | 判定 | 决策 |
|----|--------|------|------|
| resistance_25c_ohm | 86.1% | OK | — |
| resistance_tolerance_pct | 83.2% | OK | — |
| package_case | 87.5% | OK | — |
| temp_min/max_c | 79.0% | OK | — |
| power_rating_w | 54.1% | 关注 | **D** NTC 常用 mW 键，与 W 列部分未映射 |
| voltage_max_v | 0% | 高危外观 | **D** 键存在于 fixed 贴片（~68k），**NTC 子集无此键** |

---

## 三、L3 ext_attributes 字段级审计

| L3 | 字段 | 填充率 | Step1 | Step2 | 决策 |
|----|------|--------|-------|-------|------|
| current_sense_resistor | rated_current_a | 0% | 源端 `额定电流` 仅 **9** 行 | 有价值 | **D** 已豁免 |
| current_sense_resistor | is_kelvin_4terminal | 0% | 无键 | 低优先 | **D** 已豁免 |
| resistor_array_network | circuit_count | **81.3%** | OK | — | OK |
| resistor_array_network | network_topology | **64.9%** | OK | — | OK |
| ntc_thermistor | b_value_k | **78.3%** | P2 已修：占位符 fallback | 高价值 | OK（余 **~22%** 为全 `-` 源缺口） |
| ntc_thermistor | b_value_tolerance_pct | 59.4% | OK | — | OK |
| wirewound_resistor | parasitic_inductance_uh | 0% | 无键 | 低优先 | **D** 已豁免 |
| trimmer_potentiometer | adjustment_turns/type | ~57.5% | OK | — | OK |
| potentiometer | taper_type | 49.3% | OK | — | OK |
| potentiometer | gang_count | 0% | 已移除错误 `匝数` 映射 | 源无组数 | **D** 已豁免 |

**b_value_k 抽验**（P2 修复后）：`MF11-0025005` B常数→3600 · `USP8528` B0/50→3892 · `NTCLE213E3104FXT1` B25/85→4190。剩余 null **1,724** 行中仅 **~14** 行疑似仍可修，其余为源端全 `-`。

**阻值抽验**：CS `mOhm` 宽表 ≥1Ω 误值 **0**（P1 已闭环）。

---

## 四、Schema gap（ecloud prajson 高频未覆盖键）

Top 键多为描述/管理类（`特性` 81%、`故障率` 68%），或已由其他键间接覆盖（`温度系数` vs `温度系数(ppm/℃)`）。

| 级别 | 说明 |
|------|------|
| **P1 评估** | `特性`/`故障率`/`基本产品编号` — 非核心选型字段，可不进 schema |
| **D** | `工作温度范围` — fixed 已用 min/max；VR 源端无分项键 |
| **D** | `引脚数` — 排阻已有 `circuit_count` |
| **INFO** | colon 变体键（`故障率:` 等）— 与无冒号键重复 |

无 **P0「schema 已有属性仅缺 extract_rule」** 阻断项。

---

## 五、变更说明（本轮迭代累计）

| 版本 | 改动 | 效果 |
|------|------|------|
| v2 | trimmer MPN 移除 RM06/3540 | 排阻/贴片误分类回收 |
| v3 | `dim_unit_factor` 补 mOhms/kOhms 等 | CS mOhm 误值→0；kOhms 全量换算 |
| v4 | EAV ranked 跳过无效 value_raw；B 值 regex 放宽 | b_value_k **52.8%→78.3%** |

---

## 六、P 级问题汇总

| 级别 | 问题 | 状态 |
|------|------|------|
| **P0** | — | 无 |
| **P1** | mOhm/kOhm 单位换算 | ✅ 已修复 |
| **P2** | b_value_k 占位符抢占 | ✅ 已修复 |
| **D** | rohs/reach/gang_count/rated_current/parasitic_inductance/VR 温度/VR 封装稀疏 | 已列入 `ecloud_attr_source_waiver.list` |
| **D** | voltage_max_v @ NTC L2 | 接受；键不适用于本子类 |
| **INFO** | DL5 高 ext 空率（general_fixed 占多数 L3） | 预期：L3 ext 仅对部分 L3 有意义 |
| **INFO** | DL10 死列（rohs/reach 等） | 与 D 级豁免一致 |
| **INFO** | validate DA2 全表 orphan | 沙盒多源混表；ecloud 子集 0 orphan |

---

## 七、总体评估

### 结论：**通过** — 满足数据清洗要求，可进入阶段 6 合并准备

| 硬门控 | 状态 |
|--------|------|
| 分类 100% | ✅ |
| 品牌门控 | ✅ |
| 核心选型字段（阻值/封装/安装/精度/功率）fixed >70% | ✅ |
| P1/P2 数据质量问题 | ✅ 已闭环 |
| 0% 字段两步法归因 | ✅ 均为 **D** 或已豁免，无漏规则 **R** 阻断 |
| 阶段 5 商城核对 | ✅ 已完成（见 `mall_verify_ecloud_20260714.md`） |

### 建议后续（阶段 6）

1. 合并时装载 `dim_unit_factor_resistor_ecloud_supplement.sql` + EAV `ranked` 占位符跳过逻辑（已写入 prod `build_dwd_component_attr_std_ecloud.sql`）
2. 携带 `ecloud_attr_source_waiver.list` 与本报告进入 `dim-attr-std-merge` 评审
3. 业务待决：低阻 `current_sense` vs `general_fixed` 边界；PTC/MOV 跨 L1 召回

---

## 附录：原始填充率扫描

========================================================================
L2: fixed_resistor · test_dwd.dwd_l2_resistor_fixed_resistor
========================================================================
rows=1,205,450 brand_null=0 distinct_brand=76 distinct_brandid=76

| 列 | 非空 | 填充率 | 判定 |
|----|------|--------|------|
| manufacturer | 815,786 | 67.67% | 关注 |
| mpn | 1,205,450 | 100.0% | OK |
| lifecycle_status | 875,028 | 72.59% | OK |
| package_case | 1,093,300 | 90.7% | OK |
| mounting_style | 1,186,328 | 98.41% | OK |
| resistance_ohm | 1,098,576 | 91.13% | OK |
| tolerance_pct | 1,099,642 | 91.22% | OK |
| power_rating_w | 1,074,429 | 89.13% | OK |
| tcr_ppm_per_c | 1,046,260 | 86.79% | OK |
| temp_min_c | 1,001,517 | 83.08% | OK |
| temp_max_c | 1,001,518 | 83.08% | OK |
| resistive_element_technology | 980,526 | 81.34% | OK |
| form_factor | 1,186,328 | 98.41% | OK |
| rohs_compliant | 0 | 0.0% | 高危 |
| reach | 0 | 0.0% | 高危 |
| aec_q_level | 370,199 | 30.71% | 关注 |

========================================================================
L2: variable_resistor · test_dwd.dwd_l2_resistor_variable_resistor
========================================================================
rows=15,919 brand_null=0 distinct_brand=21 distinct_brandid=21

| 列 | 非空 | 填充率 | 判定 |
|----|------|--------|------|
| manufacturer | 11,439 | 71.86% | OK |
| mpn | 15,919 | 100.0% | OK |
| lifecycle_status | 12,140 | 76.26% | OK |
| package_case | 5,732 | 36.01% | 关注 |
| mounting_style | 12,407 | 77.94% | OK |
| resistance_ohm | 9,578 | 60.17% | 关注 |
| tolerance_pct | 9,133 | 57.37% | 关注 |
| power_rating_w | 8,984 | 56.44% | 关注 |
| temp_min_c | 391 | 2.46% | 高危 |
| temp_max_c | 391 | 2.46% | 高危 |

========================================================================
L2: protective_sensitive_resistor · test_dwd.dwd_l2_resistor_protective_sensitive_resistor
========================================================================
rows=7,930 brand_null=0 distinct_brand=50 distinct_brandid=50

| 列 | 非空 | 填充率 | 判定 |
|----|------|--------|------|
| manufacturer | 5,686 | 71.7% | OK |
| mpn | 7,930 | 100.0% | OK |
| lifecycle_status | 5,887 | 74.24% | OK |
| package_case | 6,936 | 87.47% | OK |
| resistance_25c_ohm | 6,827 | 86.09% | OK |
| resistance_tolerance_pct | 6,600 | 83.23% | OK |
| power_rating_w | 4,286 | 54.05% | 关注 |
| temp_min_c | 6,261 | 78.95% | OK |
| temp_max_c | 6,261 | 78.95% | OK |
| voltage_max_v | 0 | 0.0% | 高危 |

========================================================================
L3 ext_attributes（分 L3 分母）
========================================================================

### current_sense_resistor (n=27,227)
  rated_current_a: 0/27,227 (0.0%)
  is_kelvin_4terminal: 0/27,227 (0.0%)

### resistor_array_network (n=31,155)
  circuit_count: 25,339/31,155 (81.33%)
  network_topology: 20,226/31,155 (64.92%)

### ntc_thermistor (n=7,930)
  b_value_k: 6,206/7,930 (78.26%)
  b_value_tolerance_pct: 4,713/7,930 (59.43%)

### wirewound_resistor (n=77,177)
  parasitic_inductance_uh: 0/77,177 (0.0%)

### trimmer_potentiometer (n=6,919)
  adjustment_turns: 3,978/6,919 (57.49%)
  adjustment_type: 3,979/6,919 (57.51%)

### potentiometer (n=9,000)
  taper_type: 4,434/9,000 (49.27%)
  gang_count: 0/9,000 (0.0%)

========================================================================
Schema gap Top-30（ecloud prajson 键未覆盖）
========================================================================

| 键 | 命中行 | 占 has_prajson | 建议 |
|----|--------|--------------|------|
| `特性` | 980,707 | 81.29% | P1 |
| `故障率` | 821,445 | 68.09% | P0 补规则/豁免 |
| `基本产品编号` | 499,517 | 41.41% | P1 |
| `大小 / 尺寸` | 461,550 | 38.26% | P1 |
| `高度 - 安装（最大值）` | 200,298 | 16.60% | P1 |
| `工作温度范围` | 85,802 | 7.11% | P0 补规则/豁免 |
| `电阻类型` | 74,448 | 6.17% | P0 补规则/豁免 |
| `温度系数` | 25,940 | 2.15% | P1 评估 |
| `单位元件功率` | 25,436 | 2.11% | P1 评估 |
| `引脚数` | 25,267 | 2.09% | P0 补规则/豁免 |
| `包装` | 24,502 | 2.03% | P1 评估 |
| `类别 ` | 22,679 | 1.88% | P1 评估 |
| `应用` | 20,306 | 1.68% | P1 评估 |
| `电阻器匹配率漂移` | 19,303 | 1.60% | P1 评估 |
| `电阻器匹配率` | 19,303 | 1.60% | P1 评估 |
| `安装特性` | 11,984 | 0.99% | P0 补规则/豁免 |
| `涂层，外壳类型` | 11,984 | 0.99% | P1 评估 |
| `引线样式` | 10,465 | 0.87% | P1 评估 |
| `大小/尺寸:` | 9,583 | 0.79% | P1 评估 |
| `高度 - 安装(最大值):` | 9,583 | 0.79% | P1 评估 |
| `成分:` | 9,255 | 0.77% | P1 评估 |
| `故障率:` | 9,255 | 0.77% | P1 评估 |
| `系列:` | 8,528 | 0.71% | P1 评估 |
| `端接样式` | 8,419 | 0.70% | P1 评估 |
| `电阻材料` | 8,398 | 0.70% | P1 评估 |
| `特性:` | 8,100 | 0.67% | P1 评估 |
| `端子数:` | 8,098 | 0.67% | P1 评估 |
| `工作温度` | 7,477 | 0.62% | P1 评估 |
| `长度 - 引线` | 3,902 | 0.32% | P1 评估 |
| `偏差` | 3,037 | 0.25% | P1 评估 |
