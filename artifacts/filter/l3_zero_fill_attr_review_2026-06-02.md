# EMI 宽表 L3 属性：0% 填充字段选型重要性评估

> 数据快照：`test_dwd.dwd_l2_filter_emi_suppression_filter`（2026-06-02，P0-G 后）  
> 目的：判断恒为 0% 的字段是否值得保留在 **试点 schema**；不重要则从 `dim_attr_schema_filter` 移除，重要则保留待二次数据源。

---

## 评估标准

| 等级 | 含义 | 建议 |
|------|------|------|
| ★★★★★ | 选型硬约束，缺了无法替代 | **保留 schema**，标注 `gap=no_data_in_source` |
| ★★★★ | 重要性能/合规指标，DK 常无 | **保留**，后续规格书/曲线解析 |
| ★★★ | 有用但可被其它字段部分替代 | 试点可 **保留或暂缓** |
| ★★ | 细分场景才用，DK 无且替代充分 | **试点移除** |
| ★ | 与本 L3 形态不匹配 | **试点移除** |

---

## 仍为 0% 的字段（12 个）

### emi_common_mode_filter（4 个 0%）

| 属性 | 填充率 | 重要性 | 结论 |
|------|--------|--------|------|
| `common_mode_impedance_ohm` | 0% | ★★★★★ | **保留**。共模扼流圈核心指标 @100MHz；DK 多为阻抗曲线无单点 KV，需规格书或曲线解析，不可删。 |
| `dcr_per_line_mohm` | 0% | ★★★★ | **保留**。单线直流电阻影响温升/压降；与 `channel_resistance_ohm`（54.7%）含义不同，不能互替。 |
| `diff_mode_impedance_ohm` | 0% | ★★ | **已移除**。差模阻抗多用于高端 CM 扼流圈对比；DK 无 key，且多数选型看共模阻抗+衰减即可。 |
| `coupling_coefficient` | 0% | ★ | **已移除**。耦合系数属变压器/耦合器语义，与典型 CM EMI 扼流圈选型无关。 |

### emi_power_line_filter（5 个 0%）

| 属性 | 填充率 | 重要性 | 结论 |
|------|--------|--------|------|
| `phase_count` | 0% | ★★★★★ | **保留**。单相/三相电源滤波器为 **结构型选型硬约束**；DK 无结构化 key，但必须留字段等二次源或类目推断。 |
| `insertion_loss_cm_150khz_db` | 0% | ★★★★ | **保留**。电源线滤波器 EMC 证书/传导骚扰频段关键指标。 |
| `insertion_loss_cm_30mhz_db` | 0% | ★★★★ | **保留**。同上（30MHz 共模损耗）。 |
| `leakage_current_ma` | 0% | ★★★★ | **保留**。安规（Y 电容/滤波器对地漏电流）筛选常用。 |
| `hipot_voltage_v` | 0% | ★★ | **已移除**。耐压 **测试** 条件，catalog 选型通常看 `rated_voltage_v`（78%）；与运营电压重复度高。 |

### ferrite_bead（2 个 0%）

| 属性 | 填充率 | 重要性 | 结论 |
|------|--------|--------|------|
| `self_resonant_freq_mhz` | 0% | ★★★★ | **保留**。磁珠自谐振频率决定有效频段上限；DK「频率 - 工作」在磁珠子集无填充，但 datasheet 高价值。 |
| `impedance_at_1ghz_ohm` | 0% | ★★ | **已移除**。已有 `impedance_at_100mhz_ohm`（93.8%）；1GHz 为高频细分，多数磁珠选型以 100MHz 为主，且需曲线拆频非别名。 |

### feedthrough_capacitor（1 个 0%）

| 属性 | 填充率 | 重要性 | 结论 |
|------|--------|--------|------|
| `mounting_hole_diameter_mm` | 0% | ★★★ | **保留**。面板安装/螺纹馈通机械配合尺寸；与 `thread_spec`（14.2%）互补（M4/M8 螺纹 ≠ 孔径）。 |

---

## 已从 schema 移除（试点，4 项）

| std_attr_code | L3 | 移除原因 |
|---------------|-----|----------|
| `coupling_coefficient` | emi_common_mode_filter | 与 CM 扼流圈选型语义不符 |
| `diff_mode_impedance_ohm` | emi_common_mode_filter | 低覆盖、可降级；共模侧字段已够 |
| `hipot_voltage_v` | emi_power_line_filter | 测试项非目录参数；`rated_voltage_v` 已覆盖 |
| `impedance_at_1ghz_ohm` | ferrite_bead | 与 100MHz 阻抗重复，需曲线解析且非别名 |

移除仅影响 **试点** `dim_attr_schema_filter` / 宽表 `ext_attributes` 键集合；合并 prod 前若正式 Excel 仍含这些列，需与硬件 schema 负责人对齐。

---

## 保留的 0% 字段（8 项）— 后续数据路线

| 属性 | 建议数据源 |
|------|------------|
| `common_mode_impedance_ohm` | 规格书 @100MHz；或解析 DK 阻抗曲线 JSON |
| `dcr_per_line_mohm` | 规格书 DCR；或新增 DK key 探测 |
| `phase_count` | 类目路径/描述 NLP；或规格书 |
| `insertion_loss_cm_*` | 规格书传导曲线；EMC 报告 |
| `leakage_current_ma` | 安规表；规格书 |
| `self_resonant_freq_mhz` | 规格书 SRF；磁珠类目 DK key 再探 |

---

## 非 0% 但曾误报为 0%（供对照）

| 属性 | 当前填充率 |
|------|------------|
| `inductance_mh` | **19.2%**（P0-G µH→mH） |
| `rated_voltage_v`（feedthrough） | **98.2%** |
| `rated_current_a`（feedthrough） | **84.4%** |
| `mounting_style`（feedthrough） | **83.1%** |
| `insertion_loss_at_100mhz_db` | **20.3%** |

---

*关联：`digikey_schema_gap_review`（电感 → `mapped_ok`）、`qa_audit_report_2026-06-02.md`*
