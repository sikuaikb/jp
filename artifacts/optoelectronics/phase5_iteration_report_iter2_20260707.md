# optoelectronics ICPDF 阶段 5 · 第二轮迭代报告

日期：2026-07-07

## 1. 本轮 dim 修正

### 分类
- 4 条 `rule_priority=8` 规则：将 `category2=其他光电器件` 中 LED 显示类经 `parjson2_match_map` 重定向到 **led**

### 属性
- `dark_current_na` ← `最大暗电源`（photodiode L3）
- `photodetector_type` English value_map（去掉 `_default` 清空）
- `responsivity_a_per_w` ← `响应度`（源端极少）

## 2. 分类分布变化

| L2/L3 | iter1 | iter2 | Δ |
|-------|-------|-------|---|
| light_emitter/led | 112,347 | 112,702 | +355 |
| photodetector/photodiode | 9,490 | 9,135 | -355 |

## 3. L2 关键列空值率（null %，越低越好）

| L2 | 属性 | iter1 | iter2 | Δ |
|----|------|-------|-------|---|
| light_emitter | `emission_color` | 31.6% | 31.81% | -0.21pp |
| light_emitter | `forward_current_ma` | 31.86% | 32.07% | -0.21pp |
| light_emitter | `peak_wavelength_nm` | 28.14% | 28.09% | +0.05pp |
| light_emitter | `optical_power_mw` | 97.34% | 97.35% | -0.01pp |
| photodetector | `photodetector_type` | 19.5% | 20.26% | -0.76pp |
| photodetector | `peak_wavelength_nm` | 74.71% | 77.08% | -2.37pp |
| photodetector | `responsivity_a_per_w` | 100.0% | 99.98% | +0.02pp |

## 4. EAV 关键属性填充率（fill %，越高越好）

| 属性 | iter1 | iter2 | Δ | 备注 |
|------|-------|-------|---|------|
| `dark_current_na` | 0.0% | 1.09% | +1.09pp | photodiode 源端仅 1,376 SKU 有键，已 100% 抽取 |
| `optical_power_mw` | 2.46% | 2.46% | +0.00pp | LED 侧 business_not_public，看 luminous_intensity_mcd |
| `photodetector_type` | 6.06% | 5.78% | -0.28pp | L3 fill 79.7%；余量来自源端无 `光电设备类型` |

## 5. 仍待收敛

| 项 | 判定 |
|----|------|
| CML 白炽/霓虹指示灯 ~152 SKU | `mall_inconsistent`，taxonomy 无 panel_indicator L3 |
| 外部 TSV 大部分行未填 | 分类 3/602，参数 0/834 已判 |
| 收敛目标（5.8） | 分类一致率 ≥95%、our_rule_gap ≤2% — **未达标，继续外部回路** |

## 6. 下一步

1. 人工填完 class/attr review TSV
2. 对 `mall_inconsistent` 走业务裁决（CML 指示灯）
3. 外部指标连续两轮达标后 → 阶段 5.5 全列空值率审计
