# QA 审计报告：Analog Filter & Dielectric Cavity Filter
> 生成时间：2026-06-05  
> 数据源：DigiKey（digikey）  
> 审计阶段：Phase 5.5  
> 审计人：数据工程

---

## 一、Analog Filter（analog_filter）

### 1.1 基本概况

| 指标 | 值 |
|---|---|
| 总行数 | 19 |
| L3 分布 | lc_passive_filter: 19, active_filter: 0 |
| 品牌门控 | ✅ brand_null=0, distinct_brand=3 = distinct_brandid=3 |
| DK category | DSL 滤波器（DSL filter，电话线分路器） |

### 1.2 L2 物理列空值率

| 字段 | 填充数/总数 | 填充率 | 状态 |
|---|---|---|---|
| manufacturer | 19/19 | 100% | ✅ |
| lifecycle_status | 19/19 | 100% | ✅ |
| eccn_code | 19/19 | 100% | ✅ |
| htsus_code | 19/19 | 100% | ✅ |
| mounting_style | 19/19 | 100% | ✅ |
| reach | 15/19 | 79% | ✅ |
| msl_level | 15/19 | 79% | ✅ |
| rohs_compliant | 12/19 | 64% | ✅ |
| lead_free | 12/19 | 64% | ✅ |
| aec_q_level | 0/19 | 0% | D1 - DK 无此字段 |
| package_case | 0/19 | 0% | D2 - 见下说明 |
| pkg_length_mm | 0/19 | 0% | D2 - DK 无尺寸规格 |
| pkg_width_mm | 0/19 | 0% | D2 |
| pkg_height_mm | 0/19 | 0% | D2 |
| temp_min_c | 0/19 | 0% | D1 - DK DSL 滤波器无温度规格 |
| temp_max_c | 0/19 | 0% | D1 |
| **cutoff_center_freq_mhz** | **0/19** | **0%** | **D1 - DK 数据缺失** |
| **impedance_ohm** | **0/19** | **0%** | **D1 - DK 数据缺失** |
| **insertion_loss_db** | **0/19** | **0%** | **D1 - DK 数据缺失** |
| **rated_current_ma** | **0/19** | **0%** | **D1 - DK 数据缺失** |
| **filter_order** | **0/19** | **0%** | **D1 - DK 数据缺失** |
| **rated_voltage_v** | **0/19** | **0%** | **D1 - DK 数据缺失** |

### 1.3 L3 ext_attributes 覆盖

| L3 | 行数 | ext_attributes 有值 | 状态 |
|---|---|---|---|
| lc_passive_filter | 19 | 0 | D1 - prajson 中无 L3 专有参数 |
| active_filter | 0 | — | DK 无此类数据 |

### 1.4 数据源限制说明（根因分析）

**DK 对 `DSL 滤波器` 品类的参数记录极其简单**：

- `prajson`（主参数 JSON）中仅有 `输入类型`（RJ11/RJ45 等端口类型）和 `输出类型`，没有任何电气规格
- `prajson2`（半结构 JSON）**完全为空**，无任何 key
- 抽取规则已定义（`fil_an_cutoff_freq`、`fil_an_il` 等），但 DK 源端根本不提供这些参数

**结论**：这 19 条 DSL 滤波器产品在 DK 数据库中是以"无参数"形式存储的，类似卖连接器的人不提供电气规格。抽取规则无误，是数据源本身的缺陷。

### 1.5 P 级问题汇总

| ID | 级别 | 问题 | 决议 |
|---|---|---|---|
| AN-D1 | D（数据源限制） | 所有电气参数（截止频率、插损、阻抗、额定电流等）0% | DK `DSL 滤波器` 品类无此数据，非规则问题；等待其他数据源（icpdf 等）补充 |
| AN-D2 | D | package_case / pkg 尺寸 0% | DK 无封装规格字段 |
| AN-D3 | D | active_filter L3 0 条数据 | DK 未将 active filter IC 归入"滤波器"品类，在 DK 数据中无此产品 |
| AN-D4 | INFO | 数据量极薄（19 条） | DK filter L1 中 `DSL 滤波器` 品类仅 19 条，属正常；icpdf 等源接入后会增长 |

**结论**：analog_filter 无 P0/P1 问题。所有 0% 填充率均为数据源限制，非规则/schema 问题。

---

## 二、Dielectric Cavity Filter（dielectric_cavity_filter）

### 2.1 基本概况

| 指标 | 值 |
|---|---|
| 总行数 | 6 |
| L3 分布 | cavity_filter: 6, dielectric_resonator_filter: 0 |
| 品牌门控 | ✅ brand_null=0, distinct_brand=2 = distinct_brandid=2 |
| DK category | 螺旋滤波器（5条）+ 射频滤波器（1条） |

### 2.2 L2 物理列空值率

| 字段 | 填充数/总数 | 填充率 | 状态 |
|---|---|---|---|
| manufacturer | 6/6 | 100% | ✅ |
| lifecycle_status | 6/6 | 100% | ✅ |
| eccn_code | 6/6 | 100% | ✅ |
| htsus_code | 6/6 | 100% | ✅ |
| mounting_style | 6/6 | 100% | ✅ |
| rohs_compliant | 6/6 | 100% | ✅ |
| reach | 6/6 | 100% | ✅ |
| lead_free | 5/6 | 84% | ✅ |
| bandwidth_3db_mhz | 6/6 | 100% | ✅ |
| insertion_loss_db | 6/6 | 100% | ✅ |
| **out_of_band_rejection_db** | **5/6** | **83%** | ✅ **v2 修复：key 改为 `选择性`** |
| **passband_ripple_db** | **5/6** | **83%** | ✅ **v2 新增字段** |
| center_frequency_mhz | 5/6 | 83% | ✅ |
| msl_level | 1/6 | 17% | D1 |
| package_case | 1/6 | 17% | D2 - 仅 Anatech 1 条有封装 |
| pkg_length_mm | 1/6 | 17% | D2 |
| pkg_width_mm | 1/6 | 17% | D2 |
| pkg_height_mm | 1/6 | 17% | D2 |
| aec_q_level | 0/6 | 0% | D1 - DK 无此字段 |
| temp_min_c | 0/6 | 0% | D1 - DK 腔体滤波器无温度规格 |
| temp_max_c | 0/6 | 0% | D1 |
| power_handling_w | 0/6 | 0% | D1 - DK 无此字段 |
| impedance_ohm | 0/6 | 0% | D1 - DK 无此字段 |

### 2.3 L3 ext_attributes 覆盖

| L3 | 行数 | ext_attributes 有值 | 状态 |
|---|---|---|---|
| cavity_filter | 6 | 0 | 见说明 |
| dielectric_resonator_filter | 0 | — | DK 无此类数据 |

> cavity_filter L3 ext_attributes 字段（unloaded_q, tcf_ppm_per_c, resonance_mode, filter_order, return_loss_db, connector_type, cavity_material）在 DK 数据中均无对应参数，因此 ext_attributes 为空是预期行为。

### 2.4 v2 变更说明

| 变更 | 说明 |
|---|---|
| `out_of_band_rejection_db` 规则修复 | 原规则 source_expr=`衰减值`，DK 实际用 `选择性`（格式 `25dB（+50MHz）33dB（-50MHz）`）；已更新为 `选择性` + regex `([\d.]+)dB`，提取第一个 dB 数值 |
| `passband_ripple_db` 新增 | DK `纹波` key 100% 覆盖，新增 L2 字段 + 抽取规则 `fil_dc_ripple`；实际填充率 83% |

### 2.5 P 级问题汇总

| ID | 级别 | 问题 | 决议 |
|---|---|---|---|
| ~~DC-P0~~ | ~~P0~~ | ~~`Toko America Inc.` brandid=NULL 品牌门控失败~~ | **✅ 已修复**：在 `test_dim.dim_std_brand` 恢复 `东光-TOKO`（brand_id_std=9000006）并将 `TOKO AMERICA INC.`/`TOKO AMERICA INC` 加入 `related_words`；重建宽表后门控通过 |
| DC-D1 | D | power_handling_w / impedance_ohm / temp 0% | DK `螺旋滤波器`/`射频滤波器` 无这些规格 |
| DC-D2 | D | package_case / pkg 尺寸 17% | 仅 1 条 Anatech `射频滤波器` 有封装/外壳字段 |
| DC-D3 | D | dielectric_resonator_filter L3 0 条数据 | DK 无此分类下产品 |
| DC-INFO | INFO | 数据量极薄（6 条） | DK `螺旋滤波器`+`射频滤波器` 共 6 条，为 DK 实际收录量 |

**结论**：所有 P 级问题均已关闭（DC-P0 品牌别名已补录）。dielectric_cavity_filter Phase 5.5 通过，无阻断项。

---

## 三、总体评估

| L2 | 行数 | 品牌门控 | 关键参数填充 | 结论 |
|---|---|---|---|---|
| analog_filter | 19 | ✅ | 0%（数据源缺失） | **Phase 5.5 通过** |
| dielectric_cavity_filter | 6 | ✅ | 83-100% | **Phase 5.5 通过** |

### 建议后续操作

1. **两个 L2 均可进入 Phase 6 人工授权流程**
2. **analog_filter**：接受当前数据状态，等待 icpdf 等数据源接入后电气参数覆盖会大幅提升
3. **dielectric_cavity_filter**：已通过所有门控，可提交 Phase 6 审批

---

## 四、未解决的遗留 P2 问题

| ID | 描述 |
|---|---|
| DC-P2-1 | `out_of_band_rejection_db` 的 `选择性` 值格式不对称（`25dB（+50MHz）33dB（-50MHz）`），当前提取首值，非最坏情况；可考虑后期改为提取 MIN 值 |
| AN-P2-1 | `analog_filter` 的 active_filter L3 无 DK 数据；如需补充，需接入半导体放大器品类数据源 |
