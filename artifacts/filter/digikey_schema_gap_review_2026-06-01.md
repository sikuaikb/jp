# 得捷 prajson ↔ filter schema 缺口评审表

> 生成：`sql_scripts/test/filter/gen_digikey_schema_gap.py`  
> 数据：`digikey_prajson_keys_2026-05-26.tsv`（滤波器 L1，27,213 行）  
> 对照：`seed/dim_attr_schema_filter.csv`（149 字段）、`seed/dim_attr_extract_rule_filter.csv`（47 条规则）

## 文件

| 文件 | 说明 |
|------|------|
| [`digikey_schema_gap_review_2026-06-01.csv`](digikey_schema_gap_review_2026-06-01.csv) | 全量 116 个得捷 key，含分类与建议动作 |

## 列说明

| 列 | 含义 |
|----|------|
| `digikey_prajson_key` | 得捷 prajson 顶层中文 key |
| `hit_cnt` / `hit_rate_pct` | 在滤波器 L1 中的出现次数与占比 |
| `has_extract_rule` | 是否已写 `dim_attr_extract_rule_filter` |
| `schema_hint_std_attr` | 建议对齐的标准属性 code（若有） |
| `gap_category` | 缺口类型（见下） |
| `recommended_action` | 建议：`add_extract_rule` / `consider_schema` / `ignore` / `defer` / `manual_review` |

## gap_category 统计（116 keys）

| gap_category | 条数 | 含义 |
|--------------|------|------|
| `mapped_ok` | 28 | 已写抽取规则 |
| `meta_purchasing_doc` | 61 | 商城/采购/文档，刻意不入技术 schema |
| `schema_has_no_rule` | 7 | **schema 有字段，应补 extract_rule** |
| `no_schema_trade` | 4 | 得捷有，schema 无（HTSUS/系列/应用/电感） |
| `no_schema_tech` | 15 | 技术向但 schema 未定义，需评审 |
| `schema_partial` | 1 | 端接样式等，schema 无独立字段 |

## 2026-06-01 排查结论（filter_order / 衰减值 填充为 0）

**根因不是 regex 或 build SQL**，而是 **得捷 key 与分类 scope 错位**：

| 得捷 key | 有值器件数 | 实际 L3 分布 | 原规则 scope | 原 schema |
|----------|------------|--------------|--------------|-----------|
| 滤波器阶数 | 1,724 | **100%** `emi_common_mode_filter` | `analog_filter` / cavity / dielectric | 无 EMI L3 字段 |
| 衰减值 | 1,176 | **100%** `emi_common_mode_filter` | acoustic / LC / dielectric_cavity | 无 EMI L3 字段 |

`matches` 阶段因 **schema INNER JOIN** 全部被丢弃，EAV 为 0 行。regex 在 StarRocks 侧对 `3rd`→`3`、`39dB @ 100MHz`→`39` 验证正常。

**test 试点修复**（待白皮书评审是否并入 `filter_schema.json` EMI L3）：

- `dim_attr_schema_filter` 为 `emi_common_mode_filter` 追加 `filter_order`、`stopband_attenuation_min_db`
- 规则 `fil_cm_order`、`fil_cm_stopband`（`gen_attr_seed_filter.py` → `PILOT_DK_SCHEMA_EXTRAS`）
- 重跑 EAV 后：`filter_order` **1,793** 件，`stopband_attenuation_min_db` **1,807** 件（≈6.6%）

`容差` / `温度系数` 的 scope 错位详情见 **[tolerance_tcf_scope_2026-06-01.md](tolerance_tcf_scope_2026-06-01.md)**（非 EMI，而是 **100% `feedthrough_capacitor`**）。

| 得捷 key | 有值 | 实际 L3 | 语义 | 试点处理 |
|----------|------|---------|------|----------|
| 容差 | 3,802 | feedthrough | 电容 ±%（非 LC 截止频率容差） | `capacitance_tolerance_pct` |
| 温度系数 | 3,376 | feedthrough | X7R/C0G 等介质代号（非 ppm） | `dielectric_material` (VARCHAR) |

勿绑 `lc_passive_filter.cutoff_freq_tolerance_pct` 或 `tcf_ppm_per_c`。

---

## 优先补规则（`add_extract_rule`，按 hit_cnt）

| hit_cnt | 得捷 key | 建议 std_attr |
|---------|----------|---------------|
| 4,164 | 容差 | `cutoff_freq_tolerance_pct` |
| 4,163 | 温度系数 | `tcf_ppm_per_c` |
| 3,397 | 电压 - 额定 AC（相对地/中性线） | `rated_voltage_v` |
| 1,807 | 衰减值 | `stopband_*` |
| 1,793 | 滤波器阶数 | `filter_order`（勿再用「配置」） |
| 1,619 | 带宽 | `bandwidth_mhz` / `bandwidth_3db_mhz` |
| 1,138 | 电压 - 额定 AC（相对相） | `rated_voltage_v` |

## 优先评审扩 schema（`no_schema_trade`）

- ~~**HTSUS**（82.8%）~~ — **已加** `htsus_code` + `fil_p_htsus`（2026-06-02）；EAV/EMI 宽表填充 ~82.4%
- **系列**（96.5%）— 可选 `product_series`
- **应用**（50.3%）— 一般保留描述，不入 EAV
- **电感**（36.4%）— EMI/LC 网络场景，是否加 `inductance_*`

## 2026-06-01 已补规则（试点）

已在 `dim_attr_extract_rule_filter.csv` 增加 16 条规则（共 63 条），含 regex：

| 得捷 key | std_attr | 试点填充（约） | 备注 |
|----------|----------|----------------|------|
| 带宽 | `bandwidth_mhz` | **1,613**（5.9%） | SAW/声学 L2，已生效 |
| 带宽 | `bandwidth_3db_mhz` | 6 | 介质腔体 L2 |
| 滤波器阶数 | `filter_order` | 待提升 | 原始值 `1st/3rd`，已加 `(\d+)` regex |
| 衰减值 | `stopband_*` | 待提升 | 原始值 `39dB @ 100MHz` 类，已加 dB regex |
| 容差 | `capacitance_tolerance_pct` | 馈通试点 | 见 `fil_ft_tol`；勿用 LC `cutoff_freq_tolerance_pct` |
| 温度系数 | `dielectric_material` | 馈通试点 | 见 `fil_ft_dielectric`；勿写入 `tcf_ppm_per_c` |
| 截止频率容差 | `cutoff_freq_tolerance_pct` | 极低 | 得捷几乎无 LC 对应 key |
| 频率 TCF | `tcf_ppm_per_c` | 极低 | SAW 上「温度系数」常为空，需另扫 key |

`滤波器阶数` 已改用正式 key（priority 5），原「配置」兜底规则已 **enabled=0**。

---

## Phase 5 迭代发现（2026-06-02）

### D1  `inductance_mh`（emi_power_line_filter）— **已闭环（P0-G）**

| 项 | 说明 |
|---|---|
| 现象 | 曾仅 **13.1%**（只解析 `mH` 后缀） |
| 修复 | `fil_pl_inductance` 整段进 numunit + `dim_unit_factor` mH←µH；DK key **`电感`** → `mapped_ok` |
| 结果 | **19.2%**（2,214/11,506）= DK 有「电感」件数上限；非别名问题 |

### D2  `thread_spec` 脏值（feedthrough_capacitor）— **已修复**

| 项 | 说明 |
|---|---|
| 现象 | `ext_attributes` 中 `thread_spec` 值含 `"-"` 占位符 |
| 修复 | 在 `build_dwd_l2_filter_emi_suppression_filter.sql` 的 `ext` CTE 中增加 `WHERE NULLIF(TRIM(value_std_varchar), '') IS NOT NULL AND value_std_varchar <> '-' AND value_std_varchar <> '--'` |
| 验证 | `_verify_d2_fix.py` 确认脏值计数 = 0 ✓ |

### D3  `common_mode_impedance_ohm`（emi_common_mode_filter）— 数据源限制

| 项 | 说明 |
|---|---|
| 现象 | 共模阻抗字段在宽表中全为 NULL |
| 根因 | DK prajson2 无「共模阻抗」key；该参数通常以频率曲线形式出现在器件规格书，DK 不以结构化 key 提供 |
| 结论 | 属于数据源结构性缺口，当前无法自动填充 |
| 建议 | 标记为 `gap_category=no_data_in_source`，defer 到有二次数据源时再处理 |

### 品牌字典补录（2026-06-02）

| 项 | 说明 |
|---|---|
| 现象 | `test_dwd.dwd_l2_filter_emi_suppression_filter` 中 `distinct_brand=89, distinct_brandid=62`，27 个品牌无 brandid |
| 根因 | EMI 滤波器品牌（Astrodyne TDI、TE Connectivity Schaffner、Cosel 等）未入 `test_dim.dim_std_brand` |
| 操作 | `_brand_fix.py` 向 `test_dim.dim_std_brand` 新增 26 个品牌条目（source=`filter_phase5_fix`） |
| 验证 | `v_std_brand_alias` 实时刷新，`dict_gap=0`，`distinct_brand=distinct_brandid=88` ✓ |
| 附注 | 剩余 `brand_source_null=972（3.8%）`：DK brandshort 为空，属源端数据缺失，非字典缺口 |

### L3 填充率汇总（Phase 5 结束时）

| l3_code | 行数 | rated_i% | dcr% | mfr% | ext% | 备注 |
|---------|------|----------|------|------|------|------|
| emi_power_line_filter | 11,506 | ~85–89% | 0% | ~90–94% | ~87–92% | dcr/imp_z DK 无此 key |
| feedthrough_capacitor | 4,236 | ~80–88% | ~7–11% | ~99–100% | ~95–99% | |
| emi_common_mode_filter | 1,925 | ~45–61% | 0% | ~98–100% | ~91–97% | rated_i 偏低=D1 prajson2 覆盖限制 |

---

## 刷新命令

```powershell
cd E:\Hardware_Data_ETL\sql_scripts\test\filter
python gen_digikey_schema_gap.py
```
