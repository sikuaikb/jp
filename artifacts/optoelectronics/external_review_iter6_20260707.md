# optoelectronics 阶段 5 · iter6 迭代纪要

日期：2026-07-07

## 内部回路（dim 规则）

| 改动 | 依据 | 效果 |
|------|------|------|
| `note_cn_regexp` → led（其他光电器件） | 探针 623 SKU note 含 LED/点阵/数码 | +738 note 规则命中 |
| `prajson2.子类别=Visible LED%` → led | gap 探针 1081 SKU 误用 `光电设备类型` 键 | +1279 subcat visible |
| `prajson2.子类别=Display%` → led | 84 Displays + 39 LED Displays | +subcat display |
| `prajson2.子类别=Photo Diode%` → photodiode | 88 SKU 确认 | +subcat photo diode |
| `category2=光耦合器` + note 光电二极管/传感器 → photodiode | OPT101P 误落 IR发射器 | 传感器类纠正 |
| SEVEN SEGMENT / PIN / APD 规则（iter6 前半） | 外部 gap 样本 | 保留 |

**分类分布变化（ICPDF 全量）**

| L3 | iter5 | iter6 |
|----|-------|-------|
| led | 113,351 | **114,539** |
| photodiode | 8,486 | **7,298** |
| other_opto fallback | ~7,803 | **5,827** |

## 外部回路（工具链）

| 改动 | 说明 |
|------|------|
| `export_review_samples.py` | 分类 rule/我方L2/L3 变化时自动作废旧判定 |
| `verify_external_class_from_digikey_db.py` | `our_rule_gap` 行刷新后重跑 DK |
| `prefill_external_class_icpdf_prajson2.py` | 增加 `prajson2.子类别` 信号 |
| `prefill_external_attr_review.py` | 扩展 `upstream_missing` 稀疏属性集 |
| `merge_other_opto_manual_review.py` | 人工 TSV → 主 class TSV 回写 |

## 收敛指标（对比 iter5）

| 指标 | iter5 | iter6 | 目标 |
|------|-------|-------|------|
| 分类 consistent | 74.3% | **79.7%** | ≥95% |
| our_rule_gap | 1.3% | **1.2%** | ≤2% ✓ |
| 参数可接受率 | 2.6% | **13.7%** | ≥90% |
| 分类已判 | 76.8% | **82.2%** | — |

## 未收口项

1. **分类 consistent 仍差 ~15pp**：101 行待判 + 7 行 CML panel_indicator 业务裁决 + 8 行 gap
2. **参数 86% 待判**：需继续 attr 四段式预填或人工填 TSV
3. **other_opto 人工 TSV** 89 行待填 → `merge_other_opto_manual_review.py` 回写
4. **taxonomy 边界**：光耦/SSR/槽型开关/面板指示灯 — 需业务裁决，不可纯规则硬凑

## 下一步（iter7 建议）

1. 人工填 `optoelectronics_other_opto_manual_review_20260707.tsv`（89 行）
2. 对 pending 143 行跑 DK 批量（修复 verify 对 pending 0 命中 — 多为 norm 或商城无货）
3. attr：`src Y + our N` 32 行 our_rule_gap 逐条补 dim 规则
4. 连续两轮 consistent≥95% 后再写「通过，可进入 5.5」
