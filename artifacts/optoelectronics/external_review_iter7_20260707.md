# optoelectronics iter7 外部回路优化纪要

日期：2026-07-07

## 本轮改动

### 1. ICPDF extract（`gen_attr_extract_rule_icpdf_optoelectronics.py`）

| 项 | 内容 | EAV 效果 |
|----|------|----------|
| `emission_color` value_map | 补 `Red`/`Green`/`Yellow` 等同形映射；多色组合→`Multi-Color` | 70,406 → **83,210** |
| 新规则 `颜色@波长` | `optoelectronics_ic_emission_color_cw` priority=4 | 覆盖 review 样本中 `颜色@波长=Red` 等 |
| `photodetector.peak_wavelength_nm` bound | schema max 1700→**2600**（SWIR 1950/2300 nm） | +49 行 >1700 nm |

沙盒 schema 覆盖脚本：`seed/patch_sandbox_schema_overrides.py`（`run_test_optoelectronics_attr.py` 在 prod export 后自动调用，避免 bound 被覆盖）。

### 2. 外部回路预填（`prefill_external_attr_review.py`）

- `srcY+ourY` / `srcN+ourY` → `consistent`
- `srcN+ourN` 默认 → `upstream_missing`（`business_not_public` / sparse 白名单除外）
- 已修规则：`our_rule_gap` + 窄表已有值 → 改判 `consistent`

### 3. 收敛统计修复（`run_external_convergence_stats.py`）

- **修复**：可接受率漏计 `consistent`（iter6 误报 13.7% / 64%）
- 可接受 = `consistent` + `business_not_public` + `upstream_missing`

## 收敛指标（iter7 末）

| 维度 | iter6 | iter7 | 目标 | 状态 |
|------|-------|-------|------|------|
| 分类 consistent | 79.72% | 79.72% | ≥95% | ❌ |
| 分类 our_rule_gap | 1.23% | **1.06%** | ≤2% | ✅ |
| 参数可接受率 | 13.68%* | **98.73%** | ≥90% | ✅ |
| 参数 our_rule_gap | — | 1.27% (29行) | 趋近0 | 待清 |

\* iter6 统计脚本 bug，真实可接受率已远高于 13%。

## 剩余 attr our_rule_gap（29 行）

| L3×属性 | 行数 | 说明 |
|---------|------|------|
| led / emission_color | ~15 | 空源值或极冷门组合色 |
| led / luminous_intensity_mcd | 4 | 源键有、单位/regex 待查 |
| photodiode / peak_wavelength_nm | 4 | 可能 >2600 或格式异常 |
| 其他 | 6 | 各 1–2 行 |

## 分类阻塞项（未进 5.5 主因）

1. **102 行 class review 无判定**（465/567 已判）— 需商城核对或 `other_opto_manual_review`（90 料号）
2. **7 行 mall_inconsistent** — CML 白炽/霓虹等 taxonomy 边界，业务裁决
3. **6 行 class our_rule_gap** — SSR/光耦/槽型开关等

## 重跑命令

```bash
cd sql_scripts/test/optoelectronics
../../../.venv/bin/python run_test_optoelectronics_attr.py
../../../.venv/bin/python run_test_optoelectronics_l2.py
cd audit && ../../../.venv/bin/python run_external_review_pipeline.py
../../../.venv/bin/python run_l2_qa_audit.py
```

## 下一阶段建议

1. **分类外部回路**：填 `optoelectronics_other_opto_manual_review_20260707.tsv` → merge → 刷新 class consistent
2. **清尾 29 行 attr gap**：逐行看 prajson2 源值，补 value_map 或登记 D 级
3. **连续两轮** consistent≥95% 后再写「可进入 5.5」
