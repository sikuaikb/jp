# optoelectronics ICPDF Phase 5.5 QA 审计报告

日期：2026-07-08  |  数据源：icpdf  |  schema：`optoelectronics_schema_v1.5.09`

## 一、基本概况

### 分类结果（test_dwd.dwd_component_class_optoelectronics）

| L2 | L3 | 行数 |
|----|-----|------|
| light_emitter | led | 114,535 |
| photodetector | photodiode | 7,302 |
| light_emitter | laser_diode | 4,200 |

### 品牌门控（硬门控 DL1）

- **light_emitter** `test_dwd.dwd_l2_optoelectronics_light_emitter`：rows=118,735 brand_null=0 distinct_brand/brandid=104/104 → ✅ PASS
- **photodetector** `test_dwd.dwd_l2_optoelectronics_photodetector`：rows=7,302 brand_null=0 distinct_brand/brandid=94/94 → ✅ PASS

**门控结论**：通过，允许进入 Phase 6 品牌维度

## 二、L2 物理列空值率 · `light_emitter`

| 列 | 填充 | 填充率 | 决策 | 说明 |
|----|------|--------|------|------|
| `manufacturer` | 64,835/118,735 | 54.6% | OK |  |
| `rohs_compliant` | 82,291/118,735 | 69.3% | OK |  |
| `lifecycle_status` | 104,417/118,735 | 87.9% | OK |  |
| `reach` | 51,657/118,735 | 43.5% | OK |  |
| `eccn_code` | 8,803/118,735 | 7.4% | OK |  |
| `aec_q_level` | 0/118,735 | 0.0% | D |  |
| `lead_free` | 816/118,735 | 0.7% | P2 |  |
| `msl_level` | 22,419/118,735 | 18.9% | OK |  |
| `package_case` | 29,104/118,735 | 24.5% | OK |  |
| `pkg_length_mm` | 0/118,735 | 0.0% | D |  |
| `pkg_width_mm` | 0/118,735 | 0.0% | D |  |
| `pkg_height_mm` | 88,026/118,735 | 74.1% | OK |  |
| `temp_min_c` | 71,171/118,735 | 59.9% | OK |  |
| `temp_max_c` | 69,919/118,735 | 58.9% | OK |  |
| `peak_wavelength_nm` | 85,393/118,735 | 71.9% | OK |  |
| `forward_voltage_v` | 20,529/118,735 | 17.3% | OK |  |
| `forward_current_ma` | 80,559/118,735 | 67.8% | OK |  |
| `optical_power_mw` | 3,103/118,735 | 2.6% | P2 |  |
| `emission_color` | 95,758/118,735 | 80.6% | OK | 源有颜色仍空 0 行（R 探针） |

## 二、L2 物理列空值率 · `photodetector`

| 列 | 填充 | 填充率 | 决策 | 说明 |
|----|------|--------|------|------|
| `manufacturer` | 4,015/7,302 | 55.0% | OK |  |
| `rohs_compliant` | 3,018/7,302 | 41.3% | OK |  |
| `lifecycle_status` | 6,182/7,302 | 84.7% | OK |  |
| `reach` | 2,620/7,302 | 35.9% | OK |  |
| `eccn_code` | 130/7,302 | 1.8% | P2 |  |
| `aec_q_level` | 0/7,302 | 0.0% | D |  |
| `lead_free` | 133/7,302 | 1.8% | P2 |  |
| `msl_level` | 2,111/7,302 | 28.9% | OK |  |
| `package_case` | 1,508/7,302 | 20.7% | OK |  |
| `temp_min_c` | 3,080/7,302 | 42.2% | OK |  |
| `temp_max_c` | 2,151/7,302 | 29.5% | OK |  |
| `pkg_length_mm` | 0/7,302 | 0.0% | D |  |
| `pkg_width_mm` | 0/7,302 | 0.0% | D |  |
| `pkg_height_mm` | 76/7,302 | 1.0% | D |  |
| `peak_wavelength_nm` | 810/7,302 | 11.1% | OK |  |
| `spectral_range_min_nm` | 0/7,302 | 0.0% | D |  |
| `spectral_range_max_nm` | 0/7,302 | 0.0% | D |  |
| `responsivity_a_per_w` | 2/7,302 | 0.0% | D | ICPDF 几乎无响应度键（D） |
| `active_area_mm2` | 0/7,302 | 0.0% | D |  |
| `photodetector_type` | 7,273/7,302 | 99.6% | OK |  |
| `nep_w_per_sqrt_hz` | 0/7,302 | 0.0% | D |  |

## 三、L3 ext_attributes 整体覆盖率 · `light_emitter`

| L3 | 行数 | 有 ext | 覆盖率 |
|----|------|--------|--------|
| led | 114,535 | 95,165 | 83.1% |
| laser_diode | 4,200 | 4,011 | 95.5% |

## 三、L3 ext_attributes 整体覆盖率 · `photodetector`

| L3 | 行数 | 有 ext | 覆盖率 |
|----|------|--------|--------|
| photodiode | 7,302 | 1,435 | 19.7% |

## 四、L3 ext 字段级审计（EAV @ 目标 L3）

| L3 | 属性 | 填充 | 填充率 | 决策 |
|----|------|------|--------|------|
| laser_diode | `threshold_current_ma` | 2,320/4,200 | 55.2% | OK |
| laser_diode | `slope_efficiency_mw_per_ma` | 0/4,200 | 0.0% | D |
| laser_diode | `divergence_fast_axis_deg` | 0/4,200 | 0.0% | D |
| laser_diode | `divergence_slow_axis_deg` | 0/4,200 | 0.0% | D |
| laser_diode | `spectral_linewidth_nm` | 898/4,200 | 21.4% | OK |
| laser_diode | `laser_type` | 2,077/4,200 | 49.5% | OK |
| laser_diode | `operation_mode` | 248/4,200 | 5.9% | OK |
| led | `luminous_intensity_mcd` | 77,786/114,535 | 67.9% | OK |
| led | `viewing_angle_half_deg` | 70,774/114,535 | 61.8% | OK |
| led | `color_temperature_k` | 0/114,535 | 0.0% | D |
| led | `forward_current_max_ma` | 78,819/114,535 | 68.8% | OK |
| led | `thermal_resistance_j_b_k_per_w` | 0/114,535 | 0.0% | D |
| photodiode | `junction_capacitance_pf` | 0/7,302 | 0.0% | D |
| photodiode | `dark_current_na` | 1,373/7,302 | 18.8% | OK |
| photodiode | `breakdown_voltage_v` | 1,207/7,302 | 16.5% | OK |
| photodiode | `operation_mode` | 451/7,302 | 6.2% | OK |
| photodiode | `response_time_ns` | 0/7,302 | 0.0% | D |
| photodiode | `shunt_resistance_kohm` | 0/7,302 | 0.0% | D |

## 五、P 级问题汇总

| 级别 | 问题 | 建议 |
|------|------|------|
| P0 | 品牌门控 | 无 |
| P1 | 规则错误（源有键仍空） | 无 |
| — | emission_color 80.6% | **R 已修** value_map 长尾 + infer 补全，源有颜色 gap=0 |
| — | viewing_angle_half_deg 61.8% | **R 已修** regex 支持 deg |
| — | photodetector_type 99.6% | **R 已修** category2 兜底 |
| D | color_temperature_k / thermal_R | ICPDF 无 CCT/热阻键 |
| D | laser slope_eff / divergence | ICPDF laser 无对应键 |
| D | junction_cap / response_time / shunt | gap 探针 0 键 |
| D | photodiode ext 19.7% | dark/breakdown 源端稀疏 |
| P2 | optical_power_mw / lead_free / eccn | 源端稀疏或选型路径不同 |
| D | responsivity / spectral_range / nep / pkg_height | ICPDF photodiode 源端缺口 |
| INFO | 阶段 5 外部回路（external_convergence_20260707.md） | 分类 96.47%，参数 100.0%，已收敛 |

## 六、总体评估

- **品牌门控**：✅ 两张 L2 宽表均可发布（test 沙盒）。
- **L2 公共列**：peak_wavelength / forward_current / emission_color（80.6%，源有颜色 gap=0）填充合理；optical_power_mw、forward_voltage_v 高空值为 **D/P2 级**（源端+选型路径已文档化）。
- **photodetector L2**：spectral_range / responsivity / active_area / nep 全表近空 → **D 级**，非规则错误；待 digikey 源接入后复扫。
- **L3 ext**：led viewing_angle / emission_color 已修；photodiode dark/breakdown 受源端键稀疏限制（D 级）。
- **与阶段 5 关系**：外部回路 已收敛（external_convergence_20260707.md：分类 96.47% / 参数 100.0%）；本报告 P0/P1 无阻断项，**可进入 Phase 6 门控**（仍需人工授权，不写 prod）。

## 七、建议后续操作

1. Phase 6 门控：用户授权 + `phases/6_release_gate.md` 检查清单（仍禁止 Agent 自行 `ALLOW_PROD=1`）。
2. 遗留 D 级列（spectral_range/responsivity/nep 等）登记豁免或待 digikey 源复扫。
3. 6 行 class our_rule_gap（SSR/显示屏）与 1 行待判留业务裁决记录。
4. 合并 prod 前：test_dim→dim 按 merge skill 走备份替换流程。
