# filter L1 数据质量审计报告（2026-06-02）

> 审计阶段：Phase 5.5 → Phase 6 门控前  
> 环境：`test_dwd` / `test_dim`  
> 审计人：AI Agent（Cursor）  
> 状态：**✅ 机器校验与业务确认已完成；待提交 GitLab，由仓库 Owner 合并主分支**

---

## 1. 总览

| 项目 | 值 |
|---|---|
| L1 | `filter`（滤波器） |
| 发布范围 | **路径 A**：仅 `emi_suppression_filter` 宽表试点 |
| 涉及 L3 子类 | `emi_power_line_filter`、`emi_common_mode_filter`、`feedthrough_capacitor`、`ferrite_bead` |
| 宽表行数 | **25,279**（`test_dwd.dwd_l2_filter_emi_suppression_filter`） |
| 数据来源 | DigiKey（`data_source='digikey'`） |
| 分类行数 | 27,146（`test_dwd.dwd_component_class_filter`） |
| schema seed | `dim_attr_schema_filter` **155 行** / `dim_attr_extract_rule_filter` **78 条** |
| 审计日期 | 2026-06-02（末次复验含 P0-G + schema 裁剪） |

---

## 2. 品牌门控

| 指标 | 值 | 状态 |
|---|---|---|
| `dict_gap`（brand 有值但 brandid NULL） | 0 | ✅ PASS |
| `distinct_brand` / `distinct_brandid` | 88 / 88 | ✅ dt = di |
| `brand_source_null`（DK 源端无 brandshort） | 972（3.8%） | ✅ **业务已接受** |

**说明**：972 行 `brand=NULL` 为 DK 源端缺失，非字典缺口。本轮曾向 `test_dim.dim_std_brand` 补录 26 个 EMI 特有品牌。

---

## 3. L2 物理列空值率（摘要）

> 产物：`null_rates_emi_suppression_2026-06-02.tsv`

| 列 | 填充情况 | 说明 |
|---|---|---|
| `lifecycle_status` | **96.5%** | P0-D ENUM 修复后 |
| `lead_free` | **~91%** | P0-E 补 rule + P0-F NBSP 修复 |
| `msl_level` | **71.3%** | P0-D；「不适用」映射为空为预期 |
| `htsus_code` | **~82%** | 试点补 schema + `fil_p_htsus` |
| `impedance_100mhz_ohm` / `dcr_mohm` | ~28% 填充 | L3 子集结构正常，无换算 bug |
| `aec_q_level` | ~6.6% 宽表 | 仅车规器件，符合预期 |

---

## 4. L3 ext_attributes 命中率（末次复验）

> 产物：`l3_coverage_emi_suppression_2026-06-03.tsv`（`phase55_audit.py`）

### 4.1 emi_power_line_filter（11,506 行）

| 属性 | 填充率 | 状态 |
|---|---|---|
| `termination_style` | 88.8% | ✅ |
| `rated_voltage_v` | 78.0% | ✅ |
| `inductance_mh` | **19.2%** | ✅ P0-G：µH→mH；= DK「电感」有值上限 |
| `insertion_loss_cm_*` / `leakage_current_ma` / `phase_count` | 0% | ⏸ 保留 schema，DK 无 key，defer |

> `hipot_voltage_v` 已从试点 schema **移除**（见 §11）。

### 4.2 emi_common_mode_filter（1,925 行）

| 属性 | 填充率 | 状态 |
|---|---|---|
| `esd_protection` / `filter_order` / `line_count` | 89–92% | ✅ |
| `stopband_attenuation_min_db` / `rated_voltage_v` / `channel_resistance_ohm` | 55–61% | ✅ |
| `common_mode_impedance_ohm` / `dcr_per_line_mohm` | 0% | ⏸ 选型重要，保留，待二次数据源 |
| `coupling_coefficient` / `diff_mode_impedance_ohm` | — | 🗑 已从 schema 移除 |

### 4.3 feedthrough_capacitor（4,236 行）

| 属性 | 填充率 | 状态 |
|---|---|---|
| `capacitance_pf` / `rated_voltage_v` / `rated_current_a` | 84–98% | ✅ P0-G 别名修复 |
| `mounting_style` / `insertion_loss_at_100mhz_db` | 83% / 20.3% | ✅ |
| `thread_spec` | 14.2% | ✅ 稀疏但可用 |
| `mounting_hole_diameter_mm` | 0% | ⏸ 保留，defer |

### 4.4 ferrite_bead（7,612 行）

| 属性 | 填充率 | 状态 |
|---|---|---|
| `impedance_at_100mhz_ohm` / `dc_bias_saturation_ma` | 94% / 90% | ✅ |
| `self_resonant_freq_mhz` | 0% | ⏸ 保留，defer |
| `impedance_at_1ghz_ohm` | — | 🗑 已从 schema 移除（100MHz 已覆盖主场景） |

---

## 5. 本轮 P0 修复（A–G）

| ID | 内容 | 结果 |
|---|---|---|
| **P0-A** | `kOhms` → Ω 换算 | ✅ 888/888 正确 |
| **P0-B** | `pkg_height_mm` 括号内 mm 提取 | ✅ 消除英寸误提取 |
| **P0-C** | `impedance_ohm` 统一 DOUBLE | ✅ schema 一致性 |
| **P0-D** | EAV `ENUM` 类型分支 | ✅ lifecycle 96.5%、msl 71.3% |
| **P0-E** | `lead_free` extract rule | ✅ ~91% |
| **P0-F** | value_map U+00A0 规范化 | ✅ |
| **P0-G** | 电感 µH→mH；feedthrough 电压/电流/插损别名 | ✅ 见 §4 |

---

## 6. 已知 gap（未阻断试点发布）

| 项 | 处理 |
|---|---|
| `common_mode_impedance_ohm`、EMI 曲线类插入损耗、安规漏电流、相数、磁珠 SRF、安装孔径 | **保留 schema**，DK 无结构化 key 或需曲线解析 |
| 已从 schema 删除的 4 字段 | 不再出现在宽表 `ext_attributes`；见 §11 |
| `brand_source_null` 3.8% | 已接受 |

---

## 7. 单位换算抽样

> 产物：`unit_sanity_emi_suppression_2026-06-02.tsv`

`rated_current_ma`、`rated_voltage_v`、`dcr_mohm`、`impedance_100mhz_ohm`（含 kOhm）、`pkg_height_mm`、`inductance_mh`（µH→mH）均无隐性量级错误。✅

---

## 8. schema 一致性（5.5.4）

| 检查项 | 结果 |
|---|---|
| snake_case / 宽表列名 / 类型分裂 / schema↔DDL | ✅ 全部通过 |

---

## 9. 机器侧静态校验（Phase 6）

| 命令 | 结果 |
|---|---|
| `run_test_filter.py` | ✅ 分类 27,146 |
| `run_test_filter_attr.py` | ✅ EAV 验收通过 |
| `run_test_wide_emi.py` | ✅ 25,279 行，`dict_gap=0` |
| `validate_pipeline.py` | ✅ classify / attr / widetable **全 PASS** |

---

## 10. 业务确认项

| # | 项 | 结论 |
|---|---|---|
| 1 | `brand_source_null` 3.8% | ✅ 已接受 |
| 2 | `inductance_mh` 19.2% | ✅ 已接受；**字段名不改**（标准单位 mH） |
| 3 | 原 0% 字段 | ✅ 可修别名已修；低价值 4 字段已删；其余 defer |

---

## 11. Schema 三处同步（2026-06-02）

| 文件 | 变更 |
|---|---|
| `hardware_schema/.../filter_schema.json` | 删除 4 个 L3 字段 |
| `hardware_schema/.../filter_schema.xlsx` | **同 JSON 删除 4 行** |
| `sql_scripts/test/filter/seed/dim_attr_schema_filter.csv` | 155 行；`gen_attr_seed_filter.py` 含 `PILOT_SCHEMA_DROP` |
| 留痕 | `artifacts/filter/pilot_schema_deferred_2026-06-02.json` |

**已删除（试点不再产出）：**

| std_attr_code | L3 |
|---|---|
| `coupling_coefficient` | emi_common_mode_filter |
| `diff_mode_impedance_ohm` | emi_common_mode_filter |
| `hipot_voltage_v` | emi_power_line_filter |
| `impedance_at_1ghz_ohm` | ferrite_bead |

DK `电感` → `inductance_mh`：**mapped_ok**（`digikey_schema_gap_review_2026-06-01.csv`）。

---

## 12. 结论与后续动作

### 审计结论

> **filter DigiKey 试点（路径 A）在 test 环境已达到发布门控标准。**  
> 合并生产库与主分支需仓库 **Owner** 执行；本团队无 prod 写权限。

### 建议下一步（GitLab）

1. **本地 commit**（建议分支名如 `feature/filter-digikey-pilot`）  
   - `sql_scripts/test/filter/**`  
   - `artifacts/filter/**`  
   - `sql_scripts/2.attribute_standard/seed/dim_unit_factor.csv`（mH 换算）  
   - 通用 EAV 脚本 P0-D/F（若尚未在远程）  
   - **勿提交** `fetch_data/*.exe`、`.cursor/skills` 除非团队约定要入库  

2. **Push 到 GitLab**，提 MR 给 Owner，说明：  
   - 范围：filter 试点 test 脚本 + 审计产物  
   - **不包含** prod `dim`/`dwd` 合并（Owner 按 `dim-*-merge` skill 操作）  
   - 依赖：合并前需 `pull main` 并解决与 switch 分支的 `build_dwd_component_attr_std_digikey.sql` 冲突  

3. **Owner 侧**（本仓库无权限项）：  
   - `git pull` 审阅 MR → 合并 `main`  
   - 按 skill 将 `test_dim`/`test_dwd` 后缀表并入 prod  
   - 正式 `filter_schema.xlsx` 白皮书若仍含已删 4 字段，需硬件 schema 负责人确认  

4. **合并 prod 前勿**由 Agent 设置 `ALLOW_PROD=1`。

---

## 13. 审计产物索引

| 文件 | 说明 |
|---|---|
| `null_rates_emi_suppression_2026-06-02.tsv` | L2 空值率 |
| `l3_coverage_emi_suppression_2026-06-03.tsv` | L3 ext 命中率（最新） |
| `unit_sanity_emi_suppression_2026-06-02.tsv` | 单位抽样 |
| `digikey_schema_gap_review_2026-06-01.md` / `.csv` | DK key 对照 |
| `l3_zero_fill_attr_review_2026-06-02.md` | 0% 字段选型评估 |
| `pilot_schema_deferred_2026-06-02.json` | 删除字段留痕 |
