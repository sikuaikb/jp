# optoelectronics iter8 分类外部回路纪要

日期：2026-07-07

## 收敛结果（阶段 5 出口）

| 维度 | 指标 | 目标 | 状态 |
|------|------|------|------|
| 分类 consistent | **96.47%** (547/567) | ≥95% | ✅ |
| 分类 our_rule_gap | 1.06% (6/567) | ≤2% | ✅ |
| 参数可接受率 | **100%** (2280/2280) | ≥90% | ✅ |
| **整体** | — | — | **可进入 5.5** |

## 本轮改动

### 1. 分类 dim（`seed/classify_config.py`）

- `光耦合器 category2 → photodiode`（修复 ACPL 等误落 led）
- `子类别 Optocoupler / Photo ICs → photodiode` 确认规则

### 2. 外部回路新脚本

- `prefill_external_class_icpdf_verify.py`：无 DK/ecloud 命中时，用 ICPDF 子类别 + other_opto fallback 无反证 → consistent；SSR/gateway_leak → gap/mall_inconsistent
- 接入 `run_external_review_pipeline.py`

### 3. 属性 extract

- `category2=光耦合器` / `子类别 Optocoupler` → `photodetector_type`（修复 ACPL-214 attr gap）

### 4. 修复

- `export_other_opto_manual_review.py`：无待判料号时不导出全量 5534 行

## 遗留（不阻塞 5.5）

- **1 行 class 待判**：需人工或商城补核
- **6 行 class our_rule_gap**：SSR/槽型开关/LTA070 显示屏 → 业务 taxonomy 裁决或下轮 classify
- **10 行 mall_inconsistent**：CML 白炽/霓虹 + gateway_leak 非光电器件

## 下一步（阶段 5.5）

```bash
cd sql_scripts/test/optoelectronics/audit
../../../.venv/bin/python run_l2_qa_audit.py
```

按 `phases/5_5_qa_audit.md` 跑空值率 / gap 探针并更新 QA 报告。
