# Filter L1 · acoustic_resonator_filter 数据质量审计报告 (2026-06-03 rev.2)

## 1. 总览


| 项目    | 值                                                       |
| ----- | ------------------------------------------------------- |
| L1    | filter                                                  |
| L2 宽表 | `dwd_l2_filter_acoustic_resonator_filter`               |
| L3 子类 | `saw_filter`（1,841）、`piezoelectric_resonator_filter`（1） |
| 总物料数  | 1,842                                                   |
| 数据源   | DigiKey（digikey）                                        |
| 本轮迭代  | acoustic 宽表首轮                                           |
| 审计日期  | 2026-06-03                                              |


---

## 2. 宽表指标


| 指标                                | 值       | 判定                   |
| --------------------------------- | ------- | -------------------- |
| total_rows                        | 1,842   | ✓                    |
| brand_source_null                 | 0 (0%)  | ✓ 源端全有品牌             |
| dict_gap                          | 0       | ✓ PASS（补入 7 个品牌）     |
| distinct_brand = distinct_brandid | 20 = 20 | ✓ PASS               |
| ext_attributes is not null        | 0       | ℹ️ 源端无 L3 专有参数（见 §7） |


---

## 3. L2 物理列空值率

（详见 `null_rates_acoustic_resonator_filter_2026-06-03.tsv`）

### 正常列（0 ~ 30%）


| 列                              | 空值率                                  |
| ------------------------------ | ------------------------------------ |
| mpn, brand, brandid, l3_code   | 0.0%                                 |
| manufacturer, lifecycle_status | 0.0%                                 |
| rohs_compliant                 | 1.7%                                 |
| lead_free                      | 1.8%                                 |
| msl_level                      | 5.6%                                 |
| mounting_style                 | 9.2%                                 |
| package_case                   | 9.3%                                 |
| pkg_length_mm / width / height | 9.9 ~ 10.8%                          |
| eccn_code                      | 13.0%                                |
| **htsus_code**                 | **12.7%** ← rev.2 修复（原 100%，见 §10.1） |
| nominal_frequency_mhz          | 14.8%                                |
| insertion_loss_db              | 12.4%                                |
| bandwidth_mhz                  | 29.5%                                |


### 关注列（30 ~ 70%）


| 列       | 空值率   | 原因                       | 处置        |
| ------- | ----- | ------------------------ | --------- |
| `reach` | 32.0% | DK 部分 SAW 器件未录入 REACH 合规 | 源端数据空洞，接受 |


### 高危列（≥ 70%）


| 列                           | 空值率        | 原因分类                                            | 处置结论                                                                                                                    |
| --------------------------- | ---------- | ----------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| ~~`htsus_code`~~            | ~~100.0%~~ | ~~原误判为源端缺失~~                                    | **rev.2 已修复**：根因为 `dim_attr_schema_filter` 缺少 acoustic scope 行，导致 EAV 未提取；已补行并重建，当前 12.7% 空（87.3% 填充）✓                  |
| `aec_q_level`               | 80.2%      | 消费级 SAW 滤波器无车规认证                                | 合理；值域核查：全部为 `AEC-Q200`（365 件），其余为「-」（不适用）→ 宽表 NULL 正确                                                                   |
| `temp_min_c` / `temp_max_c` | 100.0%     | DK prajson 声学件无工作温度参数 key（已探查全部 45 个 key 无温度字段） | P2 源端缺失；EMI 件有温度是因为 DK 对 EMI 品类录入该参数，SAW 品类不录                                                                           |
| ~~`filter_type`~~           | ~~99.9%~~  | ~~原误判为源端缺失~~                                    | **rev.2 已修复**：`filter_type` 不应走 EAV 提取，应直接取 `c.l3_code`（分类结果）；build SQL 已改为 `c.l3_code AS filter_type`，当前填充率 **100%** ✓ |
| `stopband_rejection_db`     | 100.0%     | DK 声学件无「衰减值」参数 key（已探查确认 0 命中）                  | P2 源端缺失，规则预留                                                                                                            |
| `impedance_ohm`             | 100.0%     | DK「不同频率时阻抗」为曲线型字段，不出单值（已探查确认 0 命中）              | P2 不适合 ETL 为单值                                                                                                          |
| `return_loss_db`            | 100.0%     | DK「回波损耗」声学件无此字段（已探查确认 0 命中）                     | P2 源端缺失，规则预留                                                                                                            |


> **P0 项：0 个**。`htsus_code` schema 缺口已修复；其余高危列经原始数据探查确认为真实源端空洞，非别名/规则错误。

---

## 4. L3 ext_attributes 命中率

（详见 `l3_coverage_acoustic_resonator_filter_2026-06-03.tsv`）


| L3                               | total | ext_pct | 原因                                                                                                |
| -------------------------------- | ----- | ------- | ------------------------------------------------------------------------------------------------- |
| `saw_filter`                     | 1,841 | 0.0%    | DK 源端 SAW L3 专有参数（`saw_topology_type`、`tcf_ppm_per_c` 等）在 prajson（DK 实际数据列）中未录入；相关 key 探查命中率均为 0% |
| `piezoelectric_resonator_filter` | 1     | 0.0%    | 仅 1 条，L3 专有参数无对应 DK 字段                                                                            |


**定性：源端数据空洞，非 schema 覆盖缺口**。L3 schema 已完整定义，extract_rule 已覆盖对应 DK keys，但 DK 对声学件的 L3 专有属性不录入。

---

## 5. 本轮补缺规则清单


| rule_id                  | 补的字段             | 涉及 L2             | 说明                  |
| ------------------------ | ---------------- | ----------------- | ------------------- |
| `fil_ac_imp_z`           | `impedance_ohm`  | acoustic          | 预留；源端为曲线型 fill≈0%   |
| `fil_ac_return_loss`     | `return_loss_db` | acoustic          | 预留；源端无此 key fill≈0% |
| `fil_ac_return_loss_min` | `return_loss_db` | acoustic          | 兜底 key              |
| `fil_ac_mount`           | `mounting_style` | acoustic          | DK 安装类型 fill=91%    |
| `fil_an_mount`           | `mounting_style` | analog            | 同                   |
| `fil_emi_mount`          | `mounting_style` | emi_suppression   | 同                   |
| `fil_dc_mount`           | `mounting_style` | dielectric_cavity | 同                   |


新增字段 `mounting_style`（全 L2）、`filter_type`（acoustic L2），schema 160 行，rules 85 条。

---

## 6. 已发现但未处理的 P1/P2 gap


| source_key        | 情况                   | 级别  | 处置                    |
| ----------------- | -------------------- | --- | --------------------- |
| `滤波器类型`（acoustic） | DK 声学件不填充此字段         | P2  | rule 预留，数据补充依赖 DK 源更新 |
| `温度参数`（acoustic）  | DK prajson2 无声学件温度参数 | P2  | 接受                    |
| `回波损耗`/`不同频率时阻抗`  | DK 声学件不提供单值          | P2  | 接受                    |


---

## 7. 已发现但无法修复的源端问题


| 现象                                      | 涉及行数  | 推断原因                                                                                                       | 处置                                         |
| --------------------------------------- | ----- | ---------------------------------------------------------------------------------------------------------- | ------------------------------------------ |
| `ext_attributes` 全为 NULL                | 1,842 | DK 对 SAW/piezoelectric L3 专有参数不填充（`saw_topology_type`、`tcf_ppm_per_c`、`max_input_power_dbm` 等 key 均 0% 命中） | 记录为已知源端空洞；L3 schema 已就位，待 DK 或其他源补充数据后自动填入 |
| `temp_min_c/max_c` 全 NULL               | 1,842 | DK 声学件 prajson 无温度参数字段（所有 45 个 key 均无温度条目）                                                                 | 接受；EMI 等其他 L2 有温度是因为 DK 对其品类录入该参数          |
| ~~`filter_type` 基本全 NULL~~              | —     | rev.2 已修复：`filter_type` 改为直接取 `c.l3_code`，当前 100% 填充                                                       | —                                          |
| `stopband/impedance/return_loss` 全 NULL | 1,842 | DK SAW 品类不提供这三类单值参数（已原始数据级确认 0 命中）                                                                         | 接受；规则预留                                    |


---

## 8. 单位换算抽样结果

（详见 `unit_sanity_acoustic_resonator_filter_2026-06-03.tsv`）


| std_attr_code           | 抽样数 | ok  | 异常                  |
| ----------------------- | --- | --- | ------------------- |
| `nominal_frequency_mhz` | 20  | 20  | 0（GHz 自动换算为 MHz 正常） |
| `bandwidth_mhz`         | 20  | 20  | 0                   |
| `insertion_loss_db`     | 20  | 20  | 0                   |
| `stopband_rejection_db` | 0   | -   | 源端无数值，跳过            |


> 注：`bandwidth_mhz` 中出现 `4MHz，34.47MHz` 形式（范围值）→ 提取了首个值（4MHz）；属于 `regex_clip` 范畴，量级正确，可接受。

---

## 9. schema 一致性扫描结果（5.5.4）


| 扫描项                       | 结果                                                                                 |
| ------------------------- | ---------------------------------------------------------------------------------- |
| snake_case 违规（5.5.4.1）    | 0 行 ✓                                                                              |
| 类型分裂（5.5.4.3）             | 0 行 ✓（本轮修复：`impedance_ohm` INT→DOUBLE，`filter_type`/`mounting_style` ENUM→VARCHAR） |
| schema↔DDL 类型不对齐（5.5.4.4） | 0 行 ✓                                                                              |


---

## 10. 审计结论

### 10.1  rev.2 修复说明（2026-06-03）

用户提出疑问后对所有 100% 空列做了原始数据级探查（`dwd.dwd_digikey_component_param.prajson`），发现：

- `**htsus_code**`：根因为 `dim_attr_schema_filter` 缺少 `acoustic_resonator_filter` scope 行，导致 EAV build 跳过该属性。已补 schema 行并对 `analog_filter`、`dielectric_cavity_filter` 同步补齐，重建 EAV + 宽表后填充率 **87.3%**（1608/1842）✓。
- `**filter_type**`：build SQL 设计错误——原通过 EAV pivot 从 `滤波器类型` prajson key 提取（该 key 在声学件中仅 0.1% 命中）。正确做法是直接取分类结果 `c.l3_code`（L3 分类映射已完成），已改 build SQL 为 `c.l3_code AS filter_type`，填充率 **100%** ✓（saw_filter 1841 件，piezoelectric_resonator_filter 1 件）。
- **其余 0% 列**（`temp_min_c`/`temp_max_c`/`stopband_rejection_db`/`impedance_ohm`/`return_loss_db`）：经探查 acoustic prajson 全量 key 列表（45 个），确认均不存在对应 key，为真实源端空洞，非别名/规则问题。另：报告前文"prajson2 中未填充"措辞有误，DK 实际数据在 `prajson` 列（build SQL 将其 alias 为 prajson2 供内部复用，物理 prajson2 列全为 NULL）。

**P0 项：0 个**（含 rev.2 修复后）。

**品牌门控**：dict_gap = 0 ✓，distinct_brand = distinct_brandid = 20 ✓。

**schema 一致性**：5.5.4 三项全 0 ✓（本轮同步修复了跨 L2 的类型分裂问题 + htsus_code schema 缺口）。

**单位换算**：抽样 60 条，全部 ok ✓。

**待签字发布 checklist**：

- P0 项 = 0，宽表数据质量已满足发布标准
- 品牌门控通过（dict_gap=0，dt=di）
- schema 一致性 5.5.4 全部 = 0 行
- 单位换算抽样无异常
- htsus_code 100% NULL 疑问已排查并修复（schema 缺行）
- filter_type 设计错误已修复（改为直接取 l3_code，100% 填充）
- 其余高危列（温度/stopband/impedance/return_loss）经原始数据探查确认为真实源端空洞
- **业务方 / 数据负责人审阅本报告并书面确认"可发 prod"**
- 下游消费方已知会（新增 `acoustic_resonator_filter` L2 宽表 + `mounting_style` 列变更）

> 外部商城核对（Phase 5 外部回路）已跳过本轮；需在 prod 发布后补做，或在下一迭代中执行。

