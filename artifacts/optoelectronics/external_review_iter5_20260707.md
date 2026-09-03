# optoelectronics ICPDF 外部回路 · iter5（2026-07-07）

## 本轮新增

| 脚本 | 作用 |
|------|------|
| `external_class_mall_map.py` | DK / ecloud 共用 category→L3 映射与判定 |
| `verify_external_class_from_ecloud_db.py` | **芯查查侧**：`dwd_ecloud_component_detail`（捷配生态，按 `name` 对 MPN） |
| `prefill_external_class_icpdf_prajson2.py` | `other_opto` 用 `prajson2.光电设备类型` 非泛化值预填 |
| `export_other_opto_manual_review.py` | **other_opto 待判专项 TSV**（130 行，含机器建议） |

> 说明：仓库无独立 `dwd_xcc_*` 表；ecloud 即 ods_jp 清洗后的国内商城分类，方法论上作为芯查查侧对照源。

## 收敛指标变化

| 指标 | iter4 | iter5 | 目标 |
|------|-------|-------|------|
| 分类已判定 | 436 (72.8%) | **460 (76.8%)** | — |
| consistent 率 | 71.1% | **74.3%** | ≥ 95% |
| our_rule_gap 率 | 0.5% | **1.3%** (8) | ≤ 2% ✅ |
| 参数可接受率 | 2.6% | 2.6% | ≥ 90% |

本轮分类 +24 行判定来源：
- ecloud 命中 **+16**
- prajson2 光电设备类型 **+8**（SEVEN SEGMENT / SSR / PIN 等）

## 待人工

| 产物 | 行数 | 说明 |
|------|------|------|
| `optoelectronics_class_review_20260707.tsv` | **139 待判** | 主 TSV |
| `optoelectronics_other_opto_manual_review_20260707.tsv` | **130** | other_opto 专项；128 行机器建议 `signal_missing` |

## 重跑

```bash
cd sql_scripts/test/optoelectronics/audit
../../.venv/bin/python run_external_review_pipeline.py
```
