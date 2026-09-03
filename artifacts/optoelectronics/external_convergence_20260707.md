# optoelectronics ICPDF 外部回路收敛指标

日期：2026-07-07

## 分类核对

| 指标 | 值 | 目标 |
|------|-----|------|
| 总行数 | 567 | — |
| 已判定 | 566 (99.82%) | — |
| consistent 率 | **96.47%** (547/567) | ≥ 95.0% |
| our_rule_gap 率 | **1.06%** (6/567) | ≤ 2.0% |
| 判定分布 | {'consistent': 547, 'mall_inconsistent': 13, 'our_rule_gap': 6} | — |

## 参数核对

| 指标 | 值 | 目标 |
|------|-----|------|
| 总行数 | 2280 | — |
| 已判定 | 2280 (100.0%) | — |
| 可接受结论率 | **100.0%** (2280/2280) | ≥ 90.0% |
| our_rule_gap 率 | **0.0%** (0/2280) | 趋近 0 |
| 判定分布 | {'upstream_missing': 1352, 'consistent': 897, 'business_not_public': 31} | — |

## 收敛判定

- 分类指标：✅ PASS
- 参数指标：✅ PASS
- **整体：可进入 5.5**

## 说明

- 可接受 = `consistent` + `business_not_public` + `upstream_missing`
- `our_rule_gap` 未修前不计入可接受，需补规则后改判或消除
- 分类 TSV 待判行需商城核对或 other_opto 人工 TSV
