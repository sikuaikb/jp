# circuit_protection · merge prod 预检报告

生成时间：2026-07-02 20:49 · **只读，未写 prod**

## 0. 阶段 1 门控

| 检查项 | 值 | 通过 |
|--------|-----|------|
| dim_l3_classify | 10 | ✅ |
| dim_l3_classify_rule | 49 | ✅ |
| dim_attr_schema | 131 | ✅ |
| dim_attr_extract_rule | 110 | ✅ |
| dwd_class icpdf | 76,559（基线 ~76,575） | ✅ |
| dwd_class digikey | 0 | ✅ |

**L2 品牌门控（test_dwd）**

| l2 | rows | brand_null | ok |
| --- | --- | --- | --- |
| overcurrent_overtemperature_protection | 36438 | 0 | True |
| passive_surge_diversion | 6247 | 0 | True |
| semiconductor_transient_suppression | 33855 | 0 | True |
| surge_protection_module | 19 | 0 | True |


## 1. 分类 PK 冲突预检

- **l3_id 跨 L1 冲突**：0 个 ✅
- **classify_rule PK 跨 L1 冲突**：0 组 ✅
- **classify rule_id 前缀（^circuit_protection_ / gate_circuit_protection_）**：✅

## 2. 属性 PK 冲突预检

- **attr_schema PK 跨 L1 冲突**：0 组 ✅
- **extract_rule_id 跨 L1 冲突**：0 个 ✅
- **extract_rule 孤儿 std_attr**：0 个 ✅
- **extract_rule_id 缺 circuit_protection_ 前缀**：10 个 ⚠️
| extract_rule_id | n |
| --- | --- |
| cp_dk_oc_temp_min | 1 |
| cp_dk_mov_cap_pf | 1 |
| cp_dk_rohs | 1 |
| cp_ic_cb_trip_type | 1 |
| cp_dk_tvs_cap_pf | 1 |
| cp_ic_cb_voltage_v | 1 |
| cp_ic_fuse_i2t | 1 |
| cp_dk_tvs_temp_min | 1 |
| cp_dk_msl | 1 |
| cp_dk_cb_inst_trip | 1 |


## 3. prod ↔ test 只读 diff（将删除 / 将写入）

### 3.1 dim_l3_classify

| 侧 | 行数 |
|----|------|
| prod | 10 |
| test | 10 |
| prod 独有 l3_id | 0 |
| test 新增 l3_id | 0 |

### 3.2 dim_l3_classify_rule（按 data_source）

**prod**
| data_source | n | rules |
| --- | --- | --- |
| digikey | 4 | 4 |
| icpdf | 42 | 33 |

**test**
| data_source | n | rules |
| --- | --- | --- |
| digikey | 5 | 5 |
| icpdf | 44 | 34 |

- test 新增 rule_id：**2** · prod 将删除 rule_id：**0**

新增 rule_id 样例（前 15）：
- `gate_circuit_protection_digikey_v1`
- `gate_circuit_protection_icpdf_v1`

### 3.3 dim_attr_schema / extract_rule

- prod schema 行：**41** · test schema 行：**131**

**prod extract_rule**
| data_source | n |
| --- | --- |
| digikey | 29 |

**test extract_rule**
| data_source | n |
| --- | --- |
| digikey | 31 |
| icpdf | 79 |

- test 新增 extract_rule_id：**110**（其中疑似 ICPDF：**0**）


## 4. prod 现状 vs test 增量

| 项 | prod | test 沙盒 | 备注 |
|----|------|-----------|------|
| classify data_source | digikey | icpdf + digikey | 双源替换 |
| L2 宽表脚本 | **3** 张 | **4** 张 | ✅ spd L2 已入仓 |
| icpdf 分类行 | 0（预期） | 76,559 | merge 后新增 |
| spd_module L2 行 | 无表 | 19 | merge 后 run_attr_std 建表 |

### 4.1 prod dwd_component_class 现状

- digikey：**153,287** 行
- icpdf：**70,622** 行

### 4.2 test icpdf L3 分布（merge 后应对齐）

| l3_code | n |
| --- | --- |
| fuse | 29904 |
| tvs_diode | 24148 |
| tspd | 9202 |
| mov | 5889 |
| circuit_breaker | 5097 |
| pptc_resettable_fuse | 867 |
| thermal_cutoff | 570 |
| esd_suppressor | 505 |
| gdt | 358 |
| spd_module | 19 |


## 5. 跨 L1 gate category 重叠（G1）

### 5.1 digikey

| 指标 | prod 基线 | merge 后 overlay |
|------|-----------|------------------|
| 全局重叠处数 | 9 | 9 |
| **含 circuit_protection** | **2** | **2** |
| cp **新增**重叠 | — | **0** |

**circuit_protection 相关重叠（merge 后）**

| category | l1s | new |
| --- | --- | --- |
| TVS 二极管 | circuit_protection, diode | 既有 |
| 压敏电阻，MOV | circuit_protection, resistor | 既有 |


### 5.2 icpdf

| 指标 | prod 基线 | merge 后 overlay |
|------|-----------|------------------|
| 全局重叠处数 | 15 | 14 |
| **含 circuit_protection** | **3** | **2** |
| cp **新增**重叠 | — | **0** |

**circuit_protection 相关重叠（merge 后）**

| category | l1s | new |
| --- | --- | --- |
| 压敏电阻 | circuit_protection, resistor | 既有 |
| 压敏电阻 | circuit_protection, resistor | 既有 |


> G1 工具全量扫描仍可能 FAIL（prod 历史重叠 mcu/mpu、filter/inductor 等），**circuit_protection merge 未新增 cp 相关 gate 争用**。


## 6. unit_factor supplement

- supplement 文件：`dim_unit_factor_circuit_protection_supplement.sql`
- 声明 unit 对：**13** · prod 缺失：**8**

**merge 前须追加的 unit_factor**

| target_unit | unit_raw |
| --- | --- |
| kA | A |
| kA | a |
| kA | kA |
| kA | KA |
| A | ma |
| Ω | Ohm |
| Ω | ohm |
| Ω | mOhm |



## 7. 预检结论

**✅ PK / 孤儿规则 / cp gate 争用门控通过，可进入人工授权后的 merge。**

**⚠️ 注意事项（非阻断）：**
- unit_factor 须 merge 时追加 8 行（supplement SQL 已备）
- extract_rule_id 使用 cp_* 前缀（10 条）· 与 prod 既有 DK 命名一致，非阻断
- test 沙盒 dwd_class 仅 icpdf（digikey=0）· merge 后须对 prod digikey 153k 行做 Step 5 回归

**merge 前仍须完成的仓库侧工作（非 DB）：**
1. ✅ 第 4 张 L2 `surge_protection_module` 已入仓 `16_circuit_protection_ready/`
2. ✅ `run_attr_std.sh` 已含 circuit_protection 4 张 L2
3. 从 `main` 切分支 · working tree 干净
4. classify-merge 后再 attr-merge · 最后刷 catalog · merge 时跑 unit_factor supplement
