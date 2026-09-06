# optoelectronics ICPDF 外部回路 · iter4（2026-07-07）

## 本轮动作

1. **DigiKey 源表批量核对**（`verify_external_class_from_digikey_db.py`）
   - 用 `dwd.dwd_digikey_component_param.category` 与我方 L3 对照
   - 本轮 DK 命中填判 **76** 行

2. **category2 强信号预填**（`prefill_external_class_signal.py`）
   - phase2 的 category2 1:1 规则 + iter2 显示类 reroute
   - 本轮 **+348** 行 → consistent

3. **CML 白炽/霓虹规则** → mall_inconsistent **+4**

4. **attr TSV 扩样**（LEFT JOIN EAV，含窄表 NULL）
   - 901 → **2408** 行（每 SKU × 4 重点属性全覆盖）

5. **一键流水线** `run_external_review_pipeline.py`

## 收敛指标（external_convergence_20260707.md）

| 维度 | 指标 | 当前 | 目标 |
|------|------|------|------|
| 分类 | consistent 率 | **71.1%** (426/599) | ≥ 95% |
| 分类 | our_rule_gap 率 | **0.5%** (3/599) | ≤ 2% ✅ |
| 分类 | 已判定 | **72.8%** (436/599) | — |
| 参数 | 可接受率 | **2.6%** (62/2408) | ≥ 90% |

判定分布：
- class：consistent 426 · mall_inconsistent 7 · our_rule_gap 3 · **待判 163**
- attr：our_rule_gap 20 · business_not_public 42 · upstream_missing 0

## 待判 163 行画像（分类）

- **146** 行：`category2=其他光电器件` + `other_opto` fallback → photodiode（DK 几乎无命中，需芯查查/人工）
- **12** 行：led + category 规则（无 category2）
- **5** 行：photodiode_cat 等 category 规则

## 下一步

1. **163 行 other_opto/photodiode**：优先芯查查核对（国内/冷门料号）
2. **2346 行 attr 待判**：源端无键 1500 行可批量标 `upstream_missing` / `business_not_public`（需按属性细分）
3. 业务裁决 **7** 行 mall_inconsistent（CML 指示灯 + DK 不一致）
4. 连续两轮达标后写 `iter_convergence_<date>.md` → 进 5.5
