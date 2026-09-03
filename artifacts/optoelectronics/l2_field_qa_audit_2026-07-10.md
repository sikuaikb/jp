# optoelectronics L2 宽表字段质量审计（l2-field-qa-audit）

- **日期**：2026-07-10
- **数据源**：ecloud 沙盒（test_dwd）
- **技能**：l2-field-qa-audit Phase 5.5

## 1. 基本概况

- **总 SKU**：23,808（ecloud）

| L2 | L3 | SKU |
|---|---|---:|
| light_emitter | led | 21,772 |
| photodetector | photodiode | 2,036 |

## 2. 品牌门控（硬门控）

- **light_emitter**：brand_null=0, distinct_brand=98, distinct_brandid=98 → ✅ PASS
- **photodetector**：brand_null=0, distinct_brand=44, distinct_brandid=44 → ✅ PASS

## 3. L2 物理列空值率 + 字段决策

### light_emitter (21,772 SKU)

| 字段 | 中文 | 填充率 | 决策 | 说明 |
|---|---|---:|---|---|
| `aec_q_level` | 汽车级认证等级 | 0.0%  | **D** | ecloud 源无合规字段，已 A15 豁免；等 DigiKey/其他源 |
| `eccn_code` | 出口管制分类号 | 0.0%  | **D** | ecloud 源无合规字段，已 A15 豁免；等 DigiKey/其他源 |
| `lead_free` | 无铅标识 | 0.0%  | **D** | ecloud 源无合规字段，已 A15 豁免；等 DigiKey/其他源 |
| `msl_level` | 湿敏等级 | 0.0%  | **D** | ecloud 源无合规字段，已 A15 豁免；等 DigiKey/其他源 |
| `reach` | REACH合规 | 0.0%  | **D** | ecloud 源无合规字段，已 A15 豁免；等 DigiKey/其他源 |
| `rohs_compliant` | RoHS合规 | 0.0%  | **D** | ecloud 源无合规字段，已 A15 豁免；等 DigiKey/其他源 |
| `temp_max_c` | 最高工作温度 | 8.03% ⚠️ | **INFO** | 关注：填充率偏低，走空值四段式（多为源端缺口） |
| `temp_min_c` | 最低工作温度 | 8.03% ⚠️ | **INFO** | 关注：填充率偏低，走空值四段式（多为源端缺口） |
| `optical_power_mw` | 光输出功率 | 10.23%  | **D** | ecloud 源系统性无此键或仅激光/精密探测器有；保留 L2 合约 |
| `pkg_width_mm` | 封装体宽度 | 46.98%  | **OK** | 填充率正常 |
| `pkg_length_mm` | 封装体长度 | 47.46%  | **OK** | 填充率正常 |
| `pkg_height_mm` | 封装体高度 | 56.82%  | **OK** | 填充率正常 |
| `peak_wavelength_nm` | 峰值响应波长 | 61.62%  | **OK** | 填充率正常 |
| `manufacturer` | 制造商 | 64.98%  | **OK** | 填充率正常 |
| `forward_current_ma` | 额定正向电流 | 65.5%  | **OK** | 填充率正常 |
| `lifecycle_status` | 生命周期状态 | 70.79%  | **OK** | 填充率正常 |
| `emission_color` | 发光颜色 | 74.11%  | **OK** | 填充率正常 |
| `forward_voltage_v` | 正向电压 | 74.62%  | **OK** | 填充率正常 |
| `package_case` | 封装形式 | 82.75%  | **OK** | 填充率正常 |
| `mpn` | 制造商料号 | 100.0%  | **OK** | 填充率正常 |

### photodetector (2,036 SKU)

| 字段 | 中文 | 填充率 | 决策 | 说明 |
|---|---|---:|---|---|
| `aec_q_level` | 汽车级认证等级 | 0.0%  | **D** | ecloud 源无合规字段，已 A15 豁免；等 DigiKey/其他源 |
| `eccn_code` | 出口管制分类号 | 0.0%  | **D** | ecloud 源无合规字段，已 A15 豁免；等 DigiKey/其他源 |
| `lead_free` | 无铅标识 | 0.0%  | **D** | ecloud 源无合规字段，已 A15 豁免；等 DigiKey/其他源 |
| `msl_level` | 湿敏等级 | 0.0%  | **D** | ecloud 源无合规字段，已 A15 豁免；等 DigiKey/其他源 |
| `nep_w_per_sqrt_hz` | 噪声等效功率 | 0.0%  | **D** | ecloud 源系统性无此键或仅激光/精密探测器有；保留 L2 合约 |
| `reach` | REACH合规 | 0.0%  | **D** | ecloud 源无合规字段，已 A15 豁免；等 DigiKey/其他源 |
| `responsivity_a_per_w` | 响应度 | 0.0%  | **D** | ecloud 源系统性无此键或仅激光/精密探测器有；保留 L2 合约 |
| `rohs_compliant` | RoHS合规 | 0.0%  | **D** | ecloud 源无合规字段，已 A15 豁免；等 DigiKey/其他源 |
| `pkg_height_mm` | 封装体高度 | 4.86% ⚠️ | **INFO** | 关注：填充率偏低，走空值四段式（多为源端缺口） |
| `pkg_length_mm` | 封装体长度 | 4.86% ⚠️ | **INFO** | 关注：填充率偏低，走空值四段式（多为源端缺口） |
| `pkg_width_mm` | 封装体宽度 | 4.86% ⚠️ | **INFO** | 关注：填充率偏低，走空值四段式（多为源端缺口） |
| `active_area_mm2` | 有效感光面积 | 9.97% ⚠️ | **INFO** | 关注：填充率偏低，走空值四段式（多为源端缺口） |
| `photodetector_type` | 光电探测器亚类路由 | 11.84% ⚠️ | **INFO** | 关注：填充率偏低，走空值四段式（多为源端缺口） |
| `spectral_range_min_nm` | 光谱响应下限波长 | 14.64% ⚠️ | **INFO** | 关注：填充率偏低，走空值四段式（多为源端缺口） |
| `spectral_range_max_nm` | 光谱响应上限波长 | 14.69% ⚠️ | **INFO** | 关注：填充率偏低，走空值四段式（多为源端缺口） |
| `peak_wavelength_nm` | 峰值响应波长 | 16.9% ⚠️ | **INFO** | 关注：填充率偏低，走空值四段式（多为源端缺口） |
| `package_case` | 封装形式 | 18.32% ⚠️ | **INFO** | 关注：填充率偏低，走空值四段式（多为源端缺口） |
| `temp_max_c` | 最高工作温度 | 56.34%  | **OK** | 填充率正常 |
| `temp_min_c` | 最低工作温度 | 56.34%  | **OK** | 填充率正常 |
| `manufacturer` | 制造商 | 70.14%  | **OK** | 填充率正常 |
| `lifecycle_status` | 生命周期状态 | 73.72%  | **OK** | 填充率正常 |
| `mpn` | 制造商料号 | 100.0%  | **OK** | 填充率正常 |

## 4. L3 ext_attributes 整体覆盖率

| L2 宽表 | L3 | 行数 | 有 ext | 覆盖率 |
|---|---|---:|---:|---:|
| light_emitter | led | 21,772 | 17,459 | 80.2% |
| photodetector | photodiode | 2,036 | 1,479 | 72.6% |

## 5. L3 ext 字段级审计（按 L3 分母）

### led (分母 21,772)

| 字段 | 中文 | 填充率 | 决策 | 说明 |
|---|---|---:|---|---|
| `thermal_resistance_j_b_k_per_w` | 结到焊点热阻 | 0.0% 🟡 | **D** | ecloud 对该 L3 无源键，保留 ext 合约 |
| `color_temperature_k` | 色温 | 0.05% 🟡 | **OK** | 低覆盖但源端有键，规则已生效（窄场景属性） |
| `interface_type` | 接口类型 | 0.92% 🟡 | **OK** | 低覆盖但源端有键，规则已生效（窄场景属性） |
| `radiant_intensity_mw_per_sr` | 辐射强度 | 4.01% 🟡 | **OK** | 低覆盖但源端有键，规则已生效（窄场景属性） |
| `forward_current_max_ma` | 最大正向电流 | 5.82%  | **INFO** | 关注 |
| `mounting_orientation` | 安装朝向 | 6.53%  | **INFO** | 关注 |
| `digit_size` | 数字字母尺寸 | 9.02%  | **INFO** | 关注 |
| `display_type` | 显示类型 | 9.03%  | **INFO** | 关注 |
| `digit_count` | 字符数 | 9.94%  | **INFO** | 关注 |
| `common_pin_type` | 通用引脚类型 | 11.17%  | **OK** | 填充率正常 |
| `mount_type` | 安装类型 | 13.44%  | **OK** | 填充率正常 |
| `product_series` | 产品系列 | 21.72%  | **OK** | 填充率正常 |
| `lens_color` | 透镜颜色 | 48.23%  | **OK** | 填充率正常 |
| `lens_transparency` | 透镜透明度 | 50.27%  | **OK** | 填充率正常 |
| `lens_size` | 透镜尺寸 | 52.13%  | **OK** | 填充率正常 |
| `led_config` | LED配置 | 53.53%  | **OK** | 填充率正常 |
| `lens_style` | 透镜样式 | 55.4%  | **OK** | 填充率正常 |
| `viewing_angle_half_deg` | 半功率视角 | 59.14%  | **OK** | 填充率正常 |
| `luminous_intensity_mcd` | 发光强度 | 65.8%  | **OK** | 填充率正常 |

### photodiode (分母 2,036)

| 字段 | 中文 | 填充率 | 决策 | 说明 |
|---|---|---:|---|---|
| `junction_capacitance_pf` | 结电容 | 0.0% 🟡 | **D** | ecloud 对该 L3 无源键，保留 ext 合约 |
| `operation_mode` | 工作模式 | 0.0% 🟡 | **D** | laser_diode 未接入 ecloud，led/photodiode 桶内 NULL 正常 |
| `shunt_resistance_kohm` | 并联电阻 | 0.0% 🟡 | **D** | ecloud 对该 L3 无源键，保留 ext 合约 |
| `transmission_distance_cm` | 传输距离 | 3.88% 🟡 | **OK** | 低覆盖但源端有键，规则已生效（窄场景属性） |
| `min_receivable_power_dbm` | 可接收最小功率 | 5.26%  | **INFO** | 关注 |
| `response_time_ns` | 响应时间 | 9.87%  | **INFO** | 关注 |
| `dark_current_na` | 暗电流 | 11.15%  | **OK** | 填充率正常 |
| `supply_current_ma` | 供电电流 | 13.31%  | **OK** | 填充率正常 |
| `breakdown_voltage_v` | 反向击穿电压 | 15.96%  | **OK** | 填充率正常 |
| `data_rate` | 数据速率 | 16.94%  | **OK** | 填充率正常 |
| `detection_distance_m` | 感应距离 | 38.11%  | **OK** | 填充率正常 |
| `bandpass_center_freq_khz` | 带通中心频率 | 38.65%  | **OK** | 填充率正常 |
| `mounting_orientation` | 安装朝向 | 42.93%  | **OK** | 填充率正常 |
| `supply_voltage_max_v` | 最高供电电压 | 53.98%  | **OK** | 填充率正常 |
| `supply_voltage_min_v` | 最低供电电压 | 54.96%  | **OK** | 填充率正常 |


## 6. 0% 字段源端探针（Step 1 技术核查）

| 范围 | 字段 | source_expr | prajson命中/样本 | 有键 | 决策 |
|---|---|---|---:|---|---|
| L2 light_emitter | `aec_q_level` | (无规则) | 0/0 | 否 | **D** |
| L2 light_emitter | `eccn_code` | (无规则) | 0/0 | 否 | **D** |
| L2 light_emitter | `lead_free` | (无规则) | 0/0 | 否 | **D** |
| L2 light_emitter | `msl_level` | (无规则) | 0/0 | 否 | **D** |
| L2 light_emitter | `reach` | (无规则) | 0/0 | 否 | **D** |
| L2 light_emitter | `rohs_compliant` | (无规则) | 0/0 | 否 | **D** |
| L2 photodetector | `aec_q_level` | (无规则) | 0/0 | 否 | **D** |
| L2 photodetector | `eccn_code` | (无规则) | 0/0 | 否 | **D** |
| L2 photodetector | `lead_free` | (无规则) | 0/0 | 否 | **D** |
| L2 photodetector | `msl_level` | (无规则) | 0/0 | 否 | **D** |
| L2 photodetector | `nep_w_per_sqrt_hz` | (无规则) | 0/0 | 否 | **D** |
| L2 photodetector | `reach` | (无规则) | 0/0 | 否 | **D** |
| L2 photodetector | `responsivity_a_per_w` | (无规则) | 0/0 | 否 | **D** |
| L2 photodetector | `rohs_compliant` | (无规则) | 0/0 | 否 | **D** |
| L3 led | `thermal_resistance_j_b_k_per_w` | (无规则) | 0/0 | 否 | **D** |
| L3 photodiode | `junction_capacitance_pf` | (无规则) | 0/0 | 否 | **D** |
| L3 photodiode | `operation_mode` | 特性 | 0/500 | 否 | **D** |
| L3 photodiode | `shunt_resistance_kohm` | (无规则) | 0/0 | 否 | **D** |

## 7. 高填充字段抽样（§2.4.4）

| L2 | L3 | 字段 | MPN | 宽表值 |
|---|---|---|---|---|
| light_emitter | led | `luminous_intensity_mcd` | VAOL-5 | 5000 |
| light_emitter | led | `luminous_intensity_mcd` | LNJ*53 | 10 |
| light_emitter | led | `luminous_intensity_mcd` | LDD-E302NI-RA | 2.5 |
| light_emitter | led | `package_case` | LBA67C-P2S1-35-66J6-20-R33-Z | 2-SMD,Boomerang |
| light_emitter | led | `package_case` | D-060306B1 | 0603 |
| light_emitter | led | `package_case` | 157136S12701 | 10-DIP |
| light_emitter | led | `forward_voltage_v` | 7020X21 | 1.9 |
| light_emitter | led | `forward_voltage_v` | CLM1C-WKW-CWAXB233 | 3.2 |
| light_emitter | led | `forward_voltage_v` | SMLK18WBJAW | 3.9 |
| photodetector | photodiode | `supply_voltage_min_v` | TSOP39533 | 2.5 |
| photodetector | photodiode | `supply_voltage_min_v` | TSOP59338 | 2.5 |
| photodetector | photodiode | `supply_voltage_min_v` | TSOP59438 | 2.5 |
| photodetector | photodiode | `bandpass_center_freq_khz` | TSOP4830 | 30 |
| photodetector | photodiode | `bandpass_center_freq_khz` | TSOP75236 | 36 |
| photodetector | photodiode | `bandpass_center_freq_khz` | TSOP32130 | 30 |

## 8. 变更说明 v12

- v9–v12 内部 P0 补缺：新增 Ie/BPF/供电/毫烛光/色温/接口/协议等 13 组规则
- 修复 `电流-供电` 同键 regex 竞争 → 单条无 regex 规则
- schema 86 行 / rule 239 行（ecloud）
- 外部参数核对 iter1：60/60 consistent

## 9. P 级问题汇总

| 级别 | 数量 | 明细 |
|---|---:|---|
| **P0** | 0 | 无 |
| **P1** | 0 | 无 |
| **P2** | 0 | 无 |
| **D** | 19 | ecloud 源缺口/合规豁免/子集属性 |
| **INFO** | 18 | 填充率 30% 以下关注项 |

## 10. 总体评估

### ✅ **符合 l2-field-qa-audit 要求，可进入 Phase 6 授权门控**

判定依据：
- 品牌门控通过（brand_null=0，distinct_brand=distinct_brandid）
- 无 P0 阻断项
- 无 R（规则错误）待修项：0% 字段均为 D（源缺口）或 OK
- L3 ext 低覆盖字段已按两步法归为 D，非规则 bug
- 外部参数核对 iter1：consistent 60/60

建议后续（不阻塞）：
- DigiKey 合仓后复跑 L2 合规列填充率
- `junction_capacitance_pf` / `operation_mode` 待 DigiKey 源或规格书补规则
- 商城元数据键（类别/包装）业务签字豁免

## 11. 产物

- `l2_field_decisions_2026-07-10.tsv`
- `qa_audit_report_2026-07-10.md`
- `optoelectronics_attr_review_iter_1.tsv`