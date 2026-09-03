# test_dwd 数据债务修复清单（按表分级）

> 数据来源：`validate_dwd_data.py` 连库全量扫描 `test_dwd`（dim 用 `test_dim`）。
> 扫描结果：**39 个 FAIL（硬门控）+ 22 个 DL5 WARN**。
> 复跑命令：
> ```bash
> set -a && source sql_scripts/local.env && set +a
> python3 .cursor/skills/component-etl-methodology/tools/validate_dwd_data.py \
>     --dwd-schema test_dwd --dim-schema test_dim
> ```
> 三类问题口径：
> - **品牌门控**（DL1）：`distinct_brand ≠ distinct_brandid` 或 `brand_null>0`，违反宽表发布门控。
> - **旧表名**（DL3）：表名与数据 `l1/l2` 不符 / 带沙盒后缀 / 缺 L1 前缀。
> - **`_base`**（DC3 / DA3 / DL6）：`l2_code` 以 `_base` 结尾，违反「L2 名不要带 base」硬约束。
>
> ⚠️ 全部修复均为 **test_dwd** 范围；任何写操作（DROP / 重建 / 改 seed）在执行前需人工授权。
> 品牌字典 `dim_std_brand` / `v_std_brand_alias` 是**只读基础设施**，Agent 不得改，只能报告维护方。

---

## 一、总览矩阵（每张表 × 三类问题）

| 表 | 品牌门控 | 旧表名 | `_base` | 处置 | 优先级 |
|----|:--:|:--:|:--:|------|:--:|
| `dwd_component_class`（分类结果） | | | ✅ 105007 行 | 重建（先修 seed） | **P0** |
| `dwd_component_attr_std`（EAV 窄表） | | | ✅ 3704893 行 | 重建（先修 seed） | **P0** |
| `dwd_l2_resistor_fixed_resistor` ⭐ | ✅ 57≠51 | | | 修品牌 | **P0** |
| `dwd_l2_resistor_variable_resistor` ⭐ | ✅ 41≠35 | | | 修品牌 | **P0** |
| `dwd_l2_resistor_protective_sensitive_resistor` ⭐ | ✅ 94≠77 | | | 修品牌 | **P0** |
| `dwd_l2_capacitor_non_polar_fixed_capacitor` ⭐ | ✅ 53≠52 | | | 修品牌 | **P0** |
| `dwd_l2_capacitor_polar_electrolytic_capacitor` ⭐ | ✅ 37≠36 | | | 修品牌 | **P0** |
| `dwd_l2_switch_magnetic_sensing_switch_switch` ⭐ | ✅ 37≠25 | （冗余 `_switch`） | | 修品牌 | **P0** |
| `dwd_l2_switch_mechanical_actuated_switch_switch` ⭐ | ✅ 93≠55 | （冗余 `_switch`） | | 修品牌 | **P0** |
| `dwd_l2_switch_mechanical_sensing_switch_switch` ⭐ | ✅ 52≠30 | （冗余 `_switch`） | | 修品牌 | **P0** |
| `dwd_l2_emi_filter_inductor_inductor` | ✅ 121≠44 | ✅→`dwd_l2_inductor_emi_filter_inductor` | ✅ `emi_filter_inductor_base` | 重命名+去base+修品牌 | **P0** |
| `dwd_l2_hf_chip_inductor_inductor` | ✅ 58≠21 | ✅→`dwd_l2_inductor_hf_chip_inductor` | ✅ `hf_chip_inductor_base` | 重命名+去base+修品牌 | **P0** |
| `dwd_l2_power_inductor_inductor` | ✅ 127≠52 | ✅→`dwd_l2_inductor_power_inductor` | ✅ `power_inductor_base` | 重命名+去base+修品牌 | **P0** |
| `dwd_l2_mcu` | | ✅ l1 错拆+→`dwd_l2_mcu_mpu_dsp_mcu` | ✅ `mcu_base` | 重建（mcu_mpu_dsp 沙盒） | **P0** |
| `dwd_l2_mpu_soc` | | ✅ l1 错拆+→`dwd_l2_mcu_mpu_dsp_mpu_soc` | ✅ `mpu_soc_base` | 重建（mcu_mpu_dsp 沙盒） | **P0** |
| `dwd_l2_dsp` | | ✅ l1 错拆+→`dwd_l2_mcu_mpu_dsp_dsp` | ✅ `dsp_base` | 重建（mcu_mpu_dsp 沙盒） | **P0** |
| `dwd_l2_fixed_resistor` | | ✅ 缺 L1 前缀 | | DROP（被 ⭐ 超集覆盖） | **P1** |
| `dwd_l2_variable_resistor` | | ✅ 缺 L1 前缀 | | DROP（被 ⭐ 超集覆盖） | **P1** |
| `dwd_l2_protective_sensitive_resistor` | | ✅ 缺 L1 前缀 | | DROP（被 ⭐ 超集覆盖） | **P1** |
| `dwd_l2_fixed_resistor_digikey` | ✅ 35≠29 | ✅ 沙盒后缀 | | DROP（实验表） | **P1** |
| `dwd_l2_fixed_resistor_digikey_resistor` | ✅ 35≠29 | ✅ 沙盒后缀 | | DROP（实验表） | **P1** |
| `dwd_l2_variable_resistor_digikey` | ✅ 30≠24 | ✅ 沙盒后缀 | | DROP（实验表） | **P1** |
| `dwd_l2_variable_resistor_digikey_resistor` | ✅ 30≠24 | ✅ 沙盒后缀 | | DROP（实验表） | **P1** |
| `dwd_l2_protective_sensitive_resistor_digikey` | ✅ 59≠41 | ✅ 沙盒后缀 | | DROP（实验表） | **P1** |
| `dwd_l2_resistor_fixed_resistor_digikey_sample_1000_pdf_extract_v1` | ✅ 22≠13 | ✅ 实验样本表 | | DROP（PDF 抽取实验） | **P1** |

> ⭐ = 表名规范、数据为权威合并版的「保留表」（keeper），只需修品牌门控。

---

## 二、P0 阻断类（不修不能发布）

### A. `_base` 污染（根因在 seed，需先修字典再重建）

**根因**：分类 seed `dim_l3_classify.csv` 的 `l2_code` 与属性 seed `dim_attr_schema.csv` 的 `scope_code(l2)` 用了 `xxx_base` 占位命名，沿数据流污染到分类结果表 → EAV 窄表 → L2 宽表。现已被 `validate_classify_seed.py` C7 / `validate_attr_seed.py` A12 机械拦截，但存量数据仍在。

**污染分布（按家族）**：

| 表 | 受污染 `l2_code` 家族 | 行数 |
|----|----------------------|------|
| `dwd_component_class` | `mcu_base`(89055) · `mpu_soc_base`(11919) · `dsp_base`(4033) | **105007** |
| `dwd_component_attr_std` | `mcu_base`(1264869) · `bipolar_transistor_base`(1044945) · `fet_base`(744855) · `thyristor_base`(394153) · `mpu_soc_base`(133972) · `igbt_base`(81258) · `dsp_base`(40841) | **3704893** |
| `dwd_l2_*`（6 张宽表） | `emi_filter_inductor_base` · `hf_chip_inductor_base` · `power_inductor_base` · `mcu_base` · `mpu_soc_base` · `dsp_base` | 见下表 |

> ⚠️ **两处血缘不一致，需人工确认**：
> 1. EAV 窄表含**晶体管家族** `_base`（bipolar_transistor / fet / thyristor / igbt），但**分类结果表里没有**——说明 EAV 与 class 不同源/不同批次，或 class 已重清而 EAV 未重建。
> 2. inductor 三张宽表带 `*_inductor_base`，但 class / EAV 表里**都没有** inductor `_base` 行——说明 inductor 宽表的 `l2_code` 是在宽表 build 阶段单独写入（或来自更早的 build），并非来自当前 class/EAV。

**修复步骤（DAG，自上而下）**：
1. 改 seed：`dim_l3_classify.csv`、`dim_attr_schema.csv` 中所有 `*_base` 的 `l2_code`/`scope_code` 去掉 `_base`（沿用真实业务 L2 编码：`mcu`/`mpu_soc`/`dsp`/`bipolar_transistor`/`fet`/`thyristor`/`igbt`/`emi_filter_inductor`/`hf_chip_inductor`/`power_inductor`）。
2. 过 `validate_pipeline.py`（C7/A12 必须 PASS）后 sync 到 `test_dim`。
3. 重建 `dwd_component_class` → `dwd_component_attr_std` → 受影响 L2 宽表。
4. 复跑 `validate_dwd_data.py`，DC3 / DA3 / DL6 必须归零。

### B. 品牌门控失败（DL1，17 张表）

**根因**：`distinct_brand ≠ distinct_brandid`，即同一 `brandid` 对应了多个 `brand` 字符串（别名未归一），或个别 `brandid` 缺失。属于品牌字典 `v_std_brand_alias` 覆盖不全。

**Agent 不可直接修**：品牌字典是只读基础设施。处置 = ①把下表缺口报告给字典维护方（有 ods 读权限者按 `CONTRIB_BRAND.md` 离线补别名）；②字典补全后重建宽表 brand/brandid 两列；③复跑 DL1 归零。

| 保留表（修完即合规） | distinct_brand | distinct_brandid |
|----|:--:|:--:|
| `dwd_l2_resistor_fixed_resistor` | 57 | 51 |
| `dwd_l2_resistor_variable_resistor` | 41 | 35 |
| `dwd_l2_resistor_protective_sensitive_resistor` | 94 | 77 |
| `dwd_l2_capacitor_non_polar_fixed_capacitor` | 53 | 52 |
| `dwd_l2_capacitor_polar_electrolytic_capacitor` | 37 | 36 |
| `dwd_l2_switch_magnetic_sensing_switch_switch` | 37 | 25 |
| `dwd_l2_switch_mechanical_actuated_switch_switch` | 93 | 55 |
| `dwd_l2_switch_mechanical_sensing_switch_switch` | 52 | 30 |
| `dwd_l2_emi_filter_inductor_inductor`（重命名后） | 121 | 44 |
| `dwd_l2_hf_chip_inductor_inductor`（重命名后） | 58 | 21 |
| `dwd_l2_power_inductor_inductor`（重命名后） | 127 | 52 |

> 其余带品牌门控失败的表（`*_digikey` / `*_digikey_resistor` / `*_sample_*`）见 P1，直接 DROP，无需修品牌。

---

## 三、P1 命名治理（DROP / 重命名 / 重建）

### C-1. 直接 DROP —— 与权威表重复（子集）的旧表

行数核对已确认下列旧表是规范表（⭐）的**真子集**，DROP 零数据损失：

| 待 DROP 旧表 | 行数 / 源 | 被哪张权威表覆盖 |
|----|----|----|
| `dwd_l2_fixed_resistor` | 539408 / icpdf | `dwd_l2_resistor_fixed_resistor`（612396 = icpdf 539408 + digikey 72988）|
| `dwd_l2_variable_resistor` | 11674 / icpdf | `dwd_l2_resistor_variable_resistor`（692088 = digikey 680414 + icpdf 11674）|
| `dwd_l2_protective_sensitive_resistor` | 45892 / icpdf | `dwd_l2_resistor_protective_sensitive_resistor`（60517 = icpdf 45892 + digikey 14625）|

### C-2. 直接 DROP —— 沙盒 / 实验表

| 待 DROP 沙盒表 | 行数 | 说明 |
|----|----|----|
| `dwd_l2_fixed_resistor_digikey` | 72988 | digikey 接入实验表 |
| `dwd_l2_fixed_resistor_digikey_resistor` | 72988 | 同上，重复实验 |
| `dwd_l2_variable_resistor_digikey` | 680414 | digikey 接入实验表 |
| `dwd_l2_variable_resistor_digikey_resistor` | 680414 | 同上，重复实验 |
| `dwd_l2_protective_sensitive_resistor_digikey` | 14627 | digikey 接入实验表 |
| `dwd_l2_resistor_fixed_resistor_digikey_sample_1000_pdf_extract_v1` | 803 | PDF 抽取 1000 样本实验 |

> DROP 前最后确认：上述沙盒表的数据是否都已并入对应 ⭐ 权威表（resistor 三表已含 icpdf+digikey 合并版）。

### C-3. 重命名（数据为权威合并版，仅表名违规）—— 与 P0 去base/品牌一并处理

| 现表名 | 目标表名 | 行数 / 源 |
|----|----|----|
| `dwd_l2_emi_filter_inductor_inductor` | `dwd_l2_inductor_emi_filter_inductor` | 23706（digikey 15965 + icpdf 7741）|
| `dwd_l2_hf_chip_inductor_inductor` | `dwd_l2_inductor_hf_chip_inductor` | 25318（digikey 16777 + icpdf 8541）|
| `dwd_l2_power_inductor_inductor` | `dwd_l2_inductor_power_inductor` | 126310（digikey 101523 + icpdf 24787）|

### C-4. 重建（L1 拆错 + `_base`，不能只改名）—— 走 mcu_mpu_dsp 沙盒

| 现表名 | 现状 | 目标 |
|----|----|----|
| `dwd_l2_mcu` | l1=`mcu`（错，应单一 L1 `mcu_mpu_dsp`）、l2=`mcu_base` | `dwd_l2_mcu_mpu_dsp_mcu` |
| `dwd_l2_mpu_soc` | l1=`mpu`、l2=`mpu_soc_base` | `dwd_l2_mcu_mpu_dsp_mpu_soc` |
| `dwd_l2_dsp` | l1=`dsp`、l2=`dsp_base` | `dwd_l2_mcu_mpu_dsp_dsp` |

> 这三张是 `mcu_mpu_dsp` 单一 L1 被错拆成三个 L1 的历史产物（详见 `lessons_learned.md#LL-20260528-04`）。
> 正确做法是按 `sql_scripts/test/mcu_mpu_dsp/` 沙盒重建，而非简单 rename（DL3 给的 `dwd_l2_mcu_mcu` 期望名只去了 base，**未修正错拆的 L1**，不能照搬）。

### C-5. 命名冗余（软提示，未触发 DL3）

`dwd_l2_switch_*_switch_switch` 三张 switch 表表名末尾有冗余 `_switch`（DL3 因 `startswith` 放行）。确认 `l2_code` 是否应为不含尾缀 `switch` 的编码；若是，归入重命名批次一并处理。

---

## 四、附：P2 数据完整性（DL5，本次范围外，仅记录）

22 张表存在 `l3_code` 非空但 `ext_attributes` 为空（L3 参数缺失率），最高 100%（`dwd_l2_mpu_soc` / `dwd_l2_dsp` 的 digikey 版等）。属 L3 属性抽取覆盖不足，归入数据质量审计（方法论阶段 5.5），不阻断发布门控，本清单不展开。

---

## 五、建议执行顺序与授权门控

```
P0-A 修 seed 去 _base ─┐
                       ├─→ sync test_dim ─→ 重建 class → EAV → 受影响 L2 宽表 ─→ DC3/DA3/DL6 归零
P1-C4 mcu_mpu_dsp 重建 ─┘                                                         （含 inductor 去base/重命名）
P0-B 品牌字典补别名（维护方离线）─→ 重建宽表 brand 列 ─→ DL1 归零
P1-C1/C2 DROP 重复/沙盒表（确认被超集覆盖后）─→ DL3 大幅收敛
最终：validate_dwd_data.py 全绿（0 FAIL）
```

**待授权事项（Agent 不自行执行）**：
1. 改生产/沙盒 seed（`dim_l3_classify.csv` / `dim_attr_schema.csv`）去 `_base`。
2. DROP 上述 9 张重复/沙盒表。
3. 重命名 3 张 inductor 宽表、重建 3 张 mcu_mpu_dsp 宽表。
4. 重建 `dwd_component_class` / `dwd_component_attr_std`。
5. 品牌字典补别名（须由有 ods 读权限者按 `CONTRIB_BRAND.md` 处理）。
