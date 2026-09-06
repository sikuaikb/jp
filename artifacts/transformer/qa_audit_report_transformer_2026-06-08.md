# Transformer QA Audit Report — 2026-06-08

**L1**: transformer | **Schema version**: transformer_schema_v1.6.08
**审计范围**: DigiKey 数据源，Phase 5.5 完整审计 + P0/P1/P2 全量修复
**最后更新**: 2026-06-09 v1.6（新增 L3 ext_attributes 字段级审计，全部通过）

---

## 修复变更日志

| 版次 | 变更内容 |
|---|---|
| v1.0 | Phase 5 初次审计 |
| v1.1 | Phase 5.5 审计，识别 P0/P1/P2 问题 |
| v1.2 | P0 品牌门控修复 + P1 字段下放，宽表重建 |
| v1.3 | P2 regex 修复：freq_max_khz (+29.8 pp)、primary_voltage_max_v (+4.7 pp)；temp_max_c 误报确认为合法值 |
| v1.4 | 撤销品牌空行过滤：原始无品牌数据保留 NULL 而非丢弃，360 条数据回归宽表 |
| v1.5 | 用三问法复审 P1 下放决策，5 个字段撤回 L2 公共列（D 级）：isolation_voltage_v、insertion_loss_raw、return_loss_raw、dcr_primary_raw、dcr_secondary_raw |
| v1.6（当前）| 新增 L3 ext_attributes 字段级审计（§2.4）：8 个 ext 字段全部通过，certification_body 登记 D 级 |

---

## P1 字段下放记录（schema 变更）

原 L2 公共列下放为 L3 `ext_attributes`，`dim_attr_schema` `scope_level` 由 `l2` → `l3`：

| 下放目标 L3 | 字段名 | 下放理由 | v1.5 复审结论 |
|---|---|---|---|
| `audio_transformer` | `freq_range_raw` | 仅 audio 有数据（88% null overall） | ✅ 维持下放（audio 专属频率特性，pulse 无意义） |
| `audio_transformer` | `termination_style` | audio 专属封装属性 | ✅ 维持下放 |
| `audio_transformer` | `impedance_primary_raw` | audio 专属阻抗参数 | ✅ 维持下放（阻抗匹配是 audio 电路特有） |
| `audio_transformer` | `impedance_secondary_raw` | audio 专属阻抗参数 | ✅ 维持下放 |
| `audio_transformer` | `frequency_response_raw` | audio 专属频响 | ✅ 维持下放 |
| `audio_transformer` | `power_level_raw` | audio 专属功率等级 | ✅ 维持下放 |
| `audio_transformer` | `certification_body` | audio 专属认证机构 | ✅ 维持下放 |
| `pulse_transformer` | `volt_time_product_vus` | pulse 专属伏秒积 | ✅ 维持下放 |

> ⚠️ **v1.5 撤销 5 个错误下放字段**（经三问法复审，应为 D 级）：

| 字段名 | 错误下放理由 | 撤销依据（三问法） | v1.5 决策 |
|---|---|---|---|
| `isolation_voltage_v` | signal_comm 整体仅 6.7% | LAN / pulse 变压器均有隔离电压要求，DK 对 pulse 未提供 = 数据源缺口 | **D 级，回归 L2 公共列** |
| `insertion_loss_raw` | audio 73.5%，pulse 0% | IEEE 802.3 对 pulse/LAN 变压器同样有插入损耗规格，DK 数据未填 = 数据源缺口 | **D 级，回归 L2 公共列** |
| `return_loss_raw` | audio 74.5%，pulse 0% | 同上，IEEE 802.3 回波损耗对整个 signal_communication L2 均有意义 | **D 级，回归 L2 公共列** |
| `dcr_primary_raw` | audio 76%，pulse 0% | 绕组 DCR 是 L2 通用可靠性参数，非 audio 专属；pulse 规格书同样标注 DCR | **D 级，回归 L2 公共列** |
| `dcr_secondary_raw` | audio 76%，pulse 0% | 同上 | **D 级，回归 L2 公共列** |

---

## P0 品牌门控修复记录

**问题**：修复前 `signal_communication` 363 行 brand=NULL，`switching_drive` 1 行。

**根因（3 层）**：
1. `brandshort = NULL` → brand alias 无法匹配
2. `brandshort = ''`（空字符串）→ `COALESCE` 选了 `''` → `NULLIF(TRIM(''), '')` 置 NULL（漏洞）
3. EAV `manufacturer` 内联 `MAX()` 在 StarRocks COALESCE 中未生效

**修复方案**：
- build SQL 新增 `mfr_agg` CTE 预聚合 EAV manufacturer
- `COALESCE(canonical_name, NULLIF(TRIM(brandshort),''), mfr_name)` 三路兜底
- 359 条三路全空的行 **保留在宽表中，brand 为 NULL**（v1.4 回滚过滤策略：原始没有就不应丢弃数据）

---

## P2 regex 修复记录

| 字段 | 问题 | 旧 regex | 新 regex | 效果 |
|---|---|---|---|---|
| `freq_max_khz` | 只匹配范围格式（需 `~`），单值条目 NULL | `~\s*(\d+...)\s*kHz` | `(\d+...)\s*kHz\s*$` | 24.2% → **54.0%** |
| `primary_voltage_max_v` | 同上 | `~\s*(\d+...)\s*V` | `(\d+...)\s*V\s*$` | 39.5% → **44.2%** |
| `temp_max_c` out_of_range | 审计脚本硬编码 150°C 上界误报 | — | — | 155°C 为合法变压器规格，schema `value_domain=70~200` 已覆盖，无需改 |

---

## SECTION 1：宽表字段空值率（全量修复后最终状态）

### signal_communication_transformer

> 总行数：**5,809**（含 359 条 brand=NULL 器件，原始数据无品牌来源，保留不丢）
> parse_fail：**0** ✅ | out_of_range（关键字段）：**0** ✅

| 字段 | null 数 | 填充率 | 状态 |
|---|---|---|---|
| brand | 359 | 93.8% | D：DigiKey 未填写 brandshort，已做三路兜底 |
| manufacturer | 0 | 100.0% | ✅ |
| lifecycle_status | 0 | 100.0% | ✅ |
| transformer_type_raw | ~921 | ~83.1% | D：DK 部分器件未标注 |
| turns_ratio | ~878 | ~83.9% | D |
| inductance_raw | ~1,295 | ~76.2% | pulse 专属；audio 无此属性 |
| mounting_style | ~841 | ~84.6% | D |
| temp_min_c | ~1,784 | ~67.3% | D |
| temp_max_c | ~1,784 | ~67.3% | D；max=155°C 合法 |
| rohs_compliant | ~624 | ~88.5% | D |
| lead_free | ~626 | ~88.5% | D |
| **isolation_voltage_v** | ~5,420 | **6.7%** | **D（v1.5 回归）**：audio 43.8%；pulse 0%（DK 数据源未填） |
| **insertion_loss_raw** | ~5,156 | **11.2%** | **D（v1.5 回归）**：audio 73.5%；pulse 0%（DK 数据源未填） |
| **return_loss_raw** | ~5,147 | **11.4%** | **D（v1.5 回归）**：audio 74.5%；pulse 0%（DK 数据源未填） |
| **dcr_primary_raw** | ~5,133 | **11.6%** | **D（v1.5 回归）**：audio 76.0%；pulse 0%（DK 数据源未填） |
| **dcr_secondary_raw** | ~5,133 | **11.6%** | **D（v1.5 回归）**：audio 76.0%；pulse 0%（DK 数据源未填） |

L3 ext_attributes 下放字段（维持下放，7 个真正专属字段）：

| L3 | 行数 | ext_attributes 覆盖率 |
|---|---|---|
| audio_transformer | 889 | ~671/889 = 75.5%（freq_range / termination / impedance / freq_resp / power_level / certification） |
| pulse_transformer | 4,920 | 554/4,920 = 11.3%（仅 volt_time_product_vus） |

### §2.4 L3 ext_attributes 字段级审计（v1.6 新增）

> 对每个 L3 专属字段，在其目标 L3 内统计 EAV 填充率，判断是规则错误(R)、数据源缺口(D)还是应删除(X)。

**audio_transformer（889 行）**

| 字段 | 填充率 | 状态 | 决策 |
|---|---|---|---|
| `termination_style` | 664/889 (74.7%) | ✅ 正常 | 保留，样本值 `wire_lead` / `pc_pin` 正确 |
| `freq_range_raw` | 605/889 (68.1%) | ✅ 正常 | 保留，样本值 `150Hz 15kHz` / `20Hz 20kHz` 正确 |
| `impedance_secondary_raw` | 593/889 (66.7%) | ✅ 正常 | 保留，样本值 `1kCT` / `1kCT` 正确 |
| `impedance_primary_raw` | 585/889 (65.8%) | ✅ 正常 | 保留，样本值 `2kCT` / `600CT` 正确 |
| `frequency_response_raw` | 548/889 (61.6%) | ✅ 正常 | 保留，样本值 `1dB` 正确（±dB 频响偏差） |
| `power_level_raw` | 509/889 (57.3%) | ✅ 正常 | 保留，样本含 `100W` / `200mW` / `−45dBm 7dB` 格式多样但合理 |
| `certification_body` | 58/889 (6.5%) | 🔶 偏低 | **D 级**：DK 对 audio 变压器认证机构标注率低，字段选型有意义（UL/CE 有区别），保留等数据补充 |

**pulse_transformer（4,920 行）**

| 字段 | 填充率 | 状态 | 决策 |
|---|---|---|---|
| `volt_time_product_vus` | 554/4920 (11.3%) | ✅ 正常 | 保留，pulse 专属伏秒积，DK 仅对部分脉冲变压器标注（正常） |

> ✅ L3 ext 字段审计结论：**无需删除、无规则错误**。唯一偏低字段 `certification_body`（6.5%）登记为 D 级，不影响 Phase 6 准入。

---

### switching_drive_transformer

> 总行数：**1,978**（含 1 条 brand=NULL 器件，原始数据无品牌来源，保留不丢）
> parse_fail：**0** ✅ | out_of_range：**0** ✅

| 字段 | null 数 | 填充率 | 状态（修复后） |
|---|---|---|---|
| brand | 1 | 99.9% | D：DigiKey 未填写 brandshort，已做三路兜底 |
| manufacturer | 0 | 100.0% | ✅ |
| lifecycle_status | 0 | 100.0% | ✅ |
| topology_type | ~716 | ~63.8% | D：DK 拓扑填充率偏低 |
| primary_voltage_min_v | ~1,097 | ~44.5% | D |
| primary_voltage_max_v | ~1,103 | **~44.2%** | ✅ P2 已修（39.5%→44.2%） |
| freq_min_khz | ~904 | ~54.3% | D：单值频率无法区分 min |
| freq_max_khz | ~910 | **~54.0%** | ✅ P2 已修（24.2%→54.0%） |
| isolation_voltage_v | ~413 | ~79.1% | D |
| temp_min_c | ~421 | ~78.7% | D |
| temp_max_c | ~421 | ~78.7% | D |
| rohs_compliant | ~21 | ~98.9% | ✅ |
| lead_free | ~21 | ~98.9% | ✅ |

---

## SECTION 2：EAV 抽取质量（最终）

> EAV 总行数：**145,312** | distinct_ids：**7,427**（v1.5：5 字段 apply_scope 扩至 L2，EAV +1,619）
> has_value_dbl：**34,972** | has_value_str：**97,201**
> parse_fail：**0** ✅ | out_of_range：**0** ✅

---

## SECTION 3：抽样验收（P2 后）

`freq_max_khz` 改进验证：

| L3 | 修前 freq_max 有值 | 修后 | 说明 |
|---|---|---|---|
| smps_transformer | 478/1,978 (24.2%) | **1,067/1,977 (54.0%)** | 单值频率也被捕获 |

---

## SECTION 4：数值列合理性（最终）

### signal_communication_transformer

| 字段 | min | max | above_150 | 结论 |
|---|---|---|---|---|
| temp_max_c | 55.0°C | 155.0°C | 1 | ✅ 合法（变压器高温规格） |

### switching_drive_transformer

| 字段 | min | max | out_of_range | 结论 |
|---|---|---|---|---|
| primary_voltage_min_v | 2.0 V | 400.0 V | 0 | ✅ |
| primary_voltage_max_v | 3.6 V | 820.0 V | 0 | ✅ |
| freq_min_khz | 1.0 kHz | 600.0 kHz | 0 | ✅ |
| freq_max_khz | 69.0 kHz | 700.0 kHz | 0 | ✅ |
| temp_min_c | -55.0°C | -25.0°C | 0 | ✅ |
| temp_max_c | 85.0°C | 165.0°C | 0 | ✅ |

---

## 问题汇总（全量处理后）

| 级别 | 问题 | 状态 |
|---|---|---|
| **P0** | signal_comm brand_null=363 | ✅ **已修复**（v1.2） |
| **P0** | switching_drive brand_null=1 | ✅ **已修复**（v1.2） |
| **P1** | 13 个 audio/pulse 字段占 L2 列 | ✅ **已处理**（v1.2 下放 13 个；v1.5 复审撤回 5 个→D 级） |
| **P2** | freq_max_khz 填充率 24.2% | ✅ **已修复** → 54.0%（v1.3） |
| **P2** | primary_voltage_max_v 填充率 39.5% | ✅ **已修复** → 44.2%（v1.3） |
| **P2** | temp_max_c out_of_range=4 | ✅ **已确认为合法值**，误报（v1.3） |
| **D** | 359+1 条无品牌来源器件 | 保留在宽表，brand=NULL，已做三路兜底（D 级：DK 源头未填） |
| **D** | mounting_style / temp / rohs 部分 null | 可接受，DK 数据源本身未填 |
| **D** | aec_qualified 极低覆盖 | 工业/汽车级标注缺失，DK 未区分 |
| **D** | isolation_voltage_v / insertion_loss_raw / return_loss_raw / dcr_primary_raw / dcr_secondary_raw — pulse 0% | v1.5 回归 L2 公共列；pulse 在 DK 未填属数据源缺口，非字段设计错误 |
| **D** | `certification_body`（audio ext）— 6.5% 填充 | v1.6 L3 ext 审计：DK 对 audio 变压器认证机构标注率低，字段保留，等数据源补充 |

---

## Phase 6 准入状态（最终）

| 检查项 | signal_communication | switching_drive |
|---|---|---|
| brand 三路兜底已做 | ✅ | ✅ |
| brand_null 来自 DK 数据源本身（D 级） | 359/5,809 (6.2%) | 1/1,978 (0.05%) |
| parse_fail = 0 | ✅ | ✅ |
| out_of_range = 0 | ✅ | ✅ |
| P0 全部清除 | ✅ | ✅ |
| P1 全部处理 | ✅ | ✅ |
| P2 全部处理 | ✅ | ✅ |
| **Phase 6 准入** | **✅ 通过** | **✅ 通过** |

> D 级 brand_null（DK 源头未填 brandshort）不阻塞 Phase 6，已保留原始数据不过滤。
