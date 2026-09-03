# rf_coaxial_connector Phase 5.5 QA 审计报告

**日期**: 2026-06-24  
**宽表**: `test_dwd.dwd_l2_connector_rf_coaxial_connector`  
**Schema 版本**: v31（接 v29/v30 RF 样本驱动施工）

---

## 基本概况

| 指标 | 数值 |
|------|------|
| 总行数 | 28,444 |
| L3 | 单节点 `rf_coaxial_connector` |
| ext 覆盖率 | ~87.5% |
| 品牌门控 | PASS（豁免，brand_null=1,901） |
| Schema | 371 行 / 规则 436 条 |

---

## L2 物理列

18 列，最低填充率 reach ~39%，无 0% 灾难字段。**v31 无 L2 结构变更。**

---

## L3 ext 字段级审计（v31 后）

| 字段 | 填充率 | 决策 |
|------|--------|------|
| vswr_max / power_rating_w | 0% | **D**（DK 无 key，保留） |
| ip_rating | ~7% | **OK**（v31 新增） |
| kit_contents_raw | ~17% | **OK**（v31 新增） |
| mounting_feature_raw | ~25% | **OK**（v31 新增） |
| 材料/端接/锁紧/配接等 v29 字段 | 52–80% | **OK** |
| product_series_raw | ~37% | **OK**（v30） |

---

## 变更说明 v31

| 动作 | 说明 |
|------|------|
| 增 L3 `mounting_feature_raw` | 得捷「安装特性」 |
| 增 L3 `kit_contents_raw` | 得捷「包括」套件内容 |
| 增 L3 `ip_rating` | 得捷「侵入防护」RF scope |
| 修 `rohs_compliant` value_map | TRUE/FALSE 标准化 |
| 修 `port_count` unit_std | 去掉误标「次」 |

---

## P 级汇总

| 级别 | 状态 |
|------|------|
| P0 品牌门控 | 豁免 PASS |
| P1 | 无 |
| P2 v31 | ✅ 已施工 |
| D | vswr_max / power_rating_w 0% |

---

## 总体评估

RF schema **v31 后可进入 Phase 6**（品牌豁免前提下）。外部样本 PE44849 / 1059684-1 回归通过。
