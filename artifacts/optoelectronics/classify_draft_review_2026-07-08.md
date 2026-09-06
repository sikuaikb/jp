# optoelectronics ecloud 分类草案评审纪要

- **阶段**：2（分类规则草案 + 商城核对）
- **数据源**：ecloud（`dwd.dwd_ecloud_component_param`）
- **评审时间**：2026-07-08
- **规则版本**：`test_dim.dim_l3_classify_rule_optoelectronics` v1.5.09

---

## 1. 结论

**阶段 2 内部门控 + 商城核对门控：✅ 通过，可进入阶段 3。**

| 门控项 | 结果 |
|--------|------|
| 内部分类行数 | ✅ 23,808（预期 23,808，0% 偏差） |
| gate 泄漏 | ✅ 0 行 |
| gate 内未分类 | ✅ 0 行 |
| 商城核对 `our_rule_gap` | ✅ **0 / 27 = 0.0%**（≤ 30%） |
| `consistent` | 22 / 27 |
| `signal_missing` | 5 / 27（无商城交叉，源端 category2 为唯一强信号） |
| `mall_inconsistent` | 0 |
| DigiKey prod 漂移 | ✅ 109,523 行 0% 偏差 |

---

## 2. 范围判定（自主裁决）

| 裁决 | category2 | 行数 |
|------|-----------|------|
| ✅ optoelectronics | 发光/红外/LED显示/光纤/光电探测/IrDA 等 9 类 | 23,808 |
| ❌ isolator | 三类光耦 | 12,684 |
| ❌ 排除 | 显示屏模块（TFT） | 2,001 |
| ❌ transistor | 光电三极管 | 690 |

---

## 3. 分类分布（ecloud）

| L3 | 行数 | 主要 category2 |
|----|------|----------------|
| led | 21,772 | 发光二极管(16,750)、LED数码管(2,451)、红外发射管(1,807)… |
| photodiode | 2,036 | 红外遥控接收头(1,116)、光电二极管(421)、光纤接收器(362)… |
| laser_diode | 0 | ecloud 无对应二级类 |

---

## 4. 商城核对方法

27 条分层样本（每 category2 × 3），三路交叉：

1. **DigiKey 本地交叉**：`dwd_digikey_component_param` + `dwd_component_class` 同 partno
2. **DigiKey 公开类目**：分销商/规格书披露的 category 文本
3. **边缘样本补强**：IRM-3638、HDSP-316G、HFBR-1414TZ 等公开资料核对

产物：`artifacts/optoelectronics/optoelectronics_class_review_2026-07-08.tsv`

### 边缘样本核对摘要

| 料号 | ecloud category2 | 我方 L3 | 商城证据 | 结论 |
|------|------------------|---------|----------|------|
| HDSP-316G | LED数码管 | led | DigiKey「LED 字符与数字」 | consistent |
| IR11-21C/TR8 | 红外发射管 | led | prod DigiKey → led | consistent |
| IRM-3638 | 红外遥控接收头 | photodiode | Photo Detectors - Remote Receiver | consistent |
| HFBR-1414TZ | 光纤发射器 | led | Fiber Optic Transmitters - Discrete | consistent |
| HFBR-2526Z | 光纤接收器 | photodiode | DigiKey「光纤接收器」 | consistent |
| PD638B | 光电二极管 | photodiode | 规格书 PIN Photodiode | consistent |

### signal_missing（5 条，可接受）

无 DigiKey 本地交叉、公开资料不足的料号，源端 `category2` 已是唯一强信号，不写规则强猜：

- IrDA：TFBS5700-TR3、TFBS4711-TR1（RPM841 已人工核对 consistent）
- 光电二极管：PD15-22B/TR8、PD70-01B/TR10
- 光纤发射器：HFBR-1521ETZ

---

## 5. 规则清单（ecloud 新增 11 条）

| rule_id | 类型 | 说明 |
|---------|------|------|
| gate_optoelectronics_ecloud_v1 | gate | category_in 白名单 |
| gate_optoelectronics_ecloud_excl_v1 | gate | 排除光耦/显示屏/光电三极管 |
| optoelectronics_ec_cat2_* (×9) | classify | category2 直映射 led/photodiode |

---

## 6. 产物索引

| 产物 | 路径 |
|------|------|
| 源层摸底 | `ecloud_explore_notes_2026-07-08.md` |
| 分类抽样（27 条） | `class_sample_v1_2026-07-08.tsv` |
| 商城核对 | `optoelectronics_class_review_2026-07-08.tsv` |
| 沙盒分类结果 | `test_dwd.dwd_component_class_optoelectronics` |

---

## 7. 下一步（阶段 3）

1. 建 `build_dwd_component_attr_std_ecloud.sql`
2. 补 `test_dim.dim_attr_extract_rule_optoelectronics` 的 `data_source=ecloud` 规则
3. A15 多源对称性校验（digikey vs ecloud）
