# optoelectronics ICPDF 阶段 5 迭代报告

日期：2026-07-07

## 1. 本轮 dim 修正

| 问题 | 根因 | 处理 |
|------|------|------|
| `emission_color` 宽表 100% NULL | ICPDF `颜色` 为英文枚举，value_map 仅中文 | 扩充 English value_map |
| `forward_current_ma` 100% NULL | 源端 `0.03 A` 格式，regex 仅匹配 mA | 清空 regex，走 A→mA unit_factor |
| `threshold_current_ma` laser 0% | 误映射 `最大正向电流`，应为 `最大阈值电流` | source_expr 覆盖 |

## 2. L2 关键列空值率变化（null %，越低越好）

| L2 | 属性 | 迭代前 | 迭代后 | Δ |
|----|------|--------|--------|---|
| light_emitter | `emission_color` | 100.0% | 31.6% | +68.40pp |
| light_emitter | `forward_current_ma` | 100.0% | 31.86% | +68.14pp |
| light_emitter | `peak_wavelength_nm` | 28.14% | 28.14% | +-0.00pp |
| light_emitter | `forward_voltage_v` | 83.89% | 83.89% | +-0.00pp |
| light_emitter | `lifecycle_status` | 11.45% | 11.45% | +-0.00pp |
| photodetector | `photodetector_type` | 19.5% | 19.5% | +-0.00pp |
| photodetector | `peak_wavelength_nm` | 74.71% | 74.71% | +-0.00pp |

## 3. EAV 关键属性填充率变化（fill %，越高越好）

| 属性 | 迭代前 | 迭代后 | Δ |
|------|--------|--------|---|
| `emission_color` | 0.0% | 63.25% | +63.25pp |
| `forward_current_ma` | 0.0% | 63.01% | +63.01pp |
| `forward_current_max_ma` | 0.0% | 61.63% | +61.63pp |
| `luminous_intensity_mcd` | 61.71% | 61.71% | +0.00pp |
| `optical_power_mw` | 2.46% | 2.46% | +0.00pp |
| `peak_wavelength_nm` | 68.36% | 68.36% | +0.00pp |
| `photodetector_type` | 6.06% | 6.06% | +0.00pp |
| `threshold_current_ma` | 0.0% | 1.84% | +1.84pp |

## 4. 外部回路抽样结论（首轮）

| 料号 | 品牌 | 源端 category2 | 我方 L3 | 商城核对 | 判定 | 备注 |
|------|------|----------------|---------|----------|------|------|
| C-13-001-PB-SSTM/K-G5 | SOURCE | 激光二极管 | laser_diode | 得捷/规格书：1310nm Laser Diode | Y | consistent | Source Photonics 激光二极管 |
| 1090A6-28V | CML | 可见光 LED | led | 得捷：Panel Indicators, Incandescent | N | mall_inconsistent | ICPDF 标 LED，商城为白炽指示灯；taxonomy 边界 |

## 5. 待下一轮处理（P1/P2）

- `optical_power_mw` 仍 ~97% NULL：ICPDF 多数 LED 无功率字段，走 `luminous_intensity_mcd`（61%）更符合业务
- `photodetector_type` 仅 6%：需核对 `光电设备类型` value_map（英文枚举）
- `responsivity_a_per_w` / `dark_current_na`：gap 探针有源端键但未建规则，待商城核对是否公开
- gap 探针 Top 键（风险等级/功能数量/形状…）为 P2 元数据，暂不建 schema

## 6. 下一步

1. 人工填完 `optoelectronics_class_review_*.tsv` / `attr_review_*.tsv` 剩余行
2. 对 `mall_inconsistent` / `our_rule_gap` 开 dim 修正工单
3. 收敛后进入阶段 5.5 全列空值率审计
