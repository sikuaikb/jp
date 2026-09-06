# optoelectronics ICPDF 阶段 5 · 第三轮迭代（2026-07-07）

## 1. 本轮变更

### 属性（iter3）

| 属性 | 变更 | photodiode L3 fill |
|------|------|-------------------|
| `breakdown_voltage_v` | 新增 `最大反向电压` + `最小反向击穿电压` | **24.3%**（2,220/9,135，原 0%） |

### 外部回路工具

| 脚本 | 作用 |
|------|------|
| `prefill_external_attr_review.py` | 从 prajson2 回填「源数据是否有/源端字段路径」，机器判定 `our_rule_gap` |
| `run_external_convergence_stats.py` | 汇总 class/attr TSV → `external_convergence_*.md` |
| `export_review_samples.py` | attr TSV 重导出时保留已填判定列 |

## 2. 外部回路进度

| TSV | 已判定 | 分布 |
|-----|--------|------|
| class（599 行） | 8 | consistent×5, mall_inconsistent×3 |
| attr（901 行） | 20 | our_rule_gap×20 |

收敛目标（5.8）：分类 consistent ≥95%、our_rule_gap ≤2% — **未达标，需人工商城核对**

## 3. 重跑命令

```bash
cd sql_scripts/test/optoelectronics
../../.venv/bin/python gen_attr_extract_rule_icpdf_optoelectronics.py
../../.venv/bin/python run_test_optoelectronics_attr.py
../../.venv/bin/python run_test_optoelectronics_l2.py
cd audit
../../.venv/bin/python export_review_samples.py
../../.venv/bin/python prefill_external_class_review.py
../../.venv/bin/python prefill_external_attr_review.py
../../.venv/bin/python run_external_convergence_stats.py
```
