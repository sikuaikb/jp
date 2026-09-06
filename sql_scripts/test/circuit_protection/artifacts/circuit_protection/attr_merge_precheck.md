# circuit_protection · dim-attr-std-merge 预检报告

生成时间：2026-07-03 16:17 · **只读，未写 prod**
Skill：`.cursor/skills/dim-attr-std-merge/SKILL.md`

## 0. 阶段 1 门控（test 后缀表）

| 表 | 行数 | 通过 |
| --- | --- | --- |
| dim_attr_schema_circuit_protection | 131 | ✅ |
| dim_attr_extract_rule_circuit_protection | 110 | ✅ |
| dwd_component_attr_std_circuit_protection | 592,412 | ✅ |

**extract_rule data_source**

| data_source | n |
| --- | --- |
| icpdf | 79 |
| digikey | 31 |

**EAV data_source**

| data_source | n |
| --- | --- |
| icpdf | 592412 |

**L2 品牌门控（test_dwd）**

| l2 | rows | brand_null | brandid_null | db=di | ok |
| --- | --- | --- | --- | --- | --- |
| overcurrent_overtemperature_protection | 36438 | 0 | 0 | 31=31 | True |
| passive_surge_diversion | 6247 | 0 | 0 | 20=20 | True |
| semiconductor_transient_suppression | 33855 | 0 | 0 | 72=72 | True |
| surge_protection_module | 19 | 0 | 0 | 1=1 | True |


### 0.1 classify 前置

| 侧 | data_source | n |
|----|-------------|---|
| prod | digikey | 153,287 |
| prod | icpdf | 76,559 |
| test | icpdf | 76,559 |

## 1. PK 冲突预检

- **attr_schema PK 跨 L1 冲突**：0 组 ✅
- **extract_rule_id PK 跨 L1 冲突**：0 个 ✅

## 2. 质量检查

- l1_code 非 `circuit_protection`：**0** ✅
- schema_version 非 `v1.16.01`：**0** ✅
- extract_rule 孤儿 std_attr：**0** ✅
- extract_rule_id 前缀（`cp_` / `circuit_protection_`）：✅
- scope/std_attr snake_case 命名：✅

**schema scope 分布**

| scope_level | n |
| --- | --- |
| l2 | 77 |
| l3 | 54 |


## 3. prod ↔ test 只读 diff

| 表 | prod 现况 | test 沙盒 | merge 动作 |
|----|-----------|-----------|------------|
| dim_attr_schema | 41 | 131 | DELETE prod L1 → INSERT test |
| dim_attr_extract_rule | 29 | 110 | DELETE prod L1/cp_* → INSERT test |

**prod extract_rule by data_source**

| data_source | n |
| --- | --- |
| digikey | 29 |

**test extract_rule by data_source**

| data_source | n |
| --- | --- |
| icpdf | 79 |
| digikey | 31 |

- test **新增** extract_rule_id：**110**

新增 rule_id 样例（前 20）：
- `cp_dk_cb_actuator`
- `cp_dk_cb_inst_trip`
- `cp_dk_cb_pole_count`
- `cp_dk_cb_trip_type`
- `cp_dk_cb_voltage_v`
- `cp_dk_fuse_speed`
- `cp_dk_lead_free`
- `cp_dk_lifecycle`
- `cp_dk_manufacturer`
- `cp_dk_mov_cap_pf`
- `cp_dk_mov_max_vac`
- `cp_dk_mov_temp_max`
- `cp_dk_mov_temp_min`
- `cp_dk_mov_varistor_v`
- `cp_dk_mpn`
- `cp_dk_msl`
- `cp_dk_oc_current_a`
- `cp_dk_oc_mounting`
- `cp_dk_oc_temp_max`
- `cp_dk_oc_temp_min`

### 3.1 prod L2 宽表现况

| l2 | rows | brand_null | by_ds | prod表 |
| --- | --- | --- | --- | --- |
| overcurrent_overtemperature_protection | 63924 | 3 | digikey=63,924 | ✅ |
| passive_surge_diversion | 6 | 0 | digikey=6 | ✅ |
| semiconductor_transient_suppression | 89357 | 603 | digikey=89,357 | ✅ |
| surge_protection_module | — | — | 表不存在 | ❌ 待建 |


- test L2 合计：**76,559**（icpdf）· prod L2 合计：**153,287**（digikey）
- merge 后 prod L2 预期：icpdf **76,559** + digikey **~153k**（Step 7 回归）

### 3.2 EAV

**prod EAV（circuit_protection 分类 id）**

| data_source | rows_ | ids |
| --- | --- | --- |
| digikey | 1941449 | 152681 |

**test EAV**

| data_source | rows_ | ids |
| --- | --- | --- |
| icpdf | 592412 | 65387 |


## 4. 入仓脚本 & run_attr_std.sh

| l2 | DDL | build | _unclassified过滤 |
| --- | --- | --- | --- |
| overcurrent_overtemperature_protection | ✅ | ✅ | ✅ |
| passive_surge_diversion | ✅ | ✅ | ✅ |
| semiconductor_transient_suppression | ✅ | ✅ | ✅ |
| surge_protection_module | ✅ | ✅ | ✅ |


- `run_attr_std.sh` · `l1_dir` → `16_circuit_protection_ready`：✅
- `l2_files_for_l1` 4 张 L2：✅

## 5. unit_factor supplement

- 文件：`dim_unit_factor_circuit_protection_supplement.sql`
- 声明 **13** 对 · prod 缺失 **8**

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


## 6. 预检结论

**✅ dim-attr-std-merge 预检通过，可进入人工授权后的 merge。**

**⚠️ 注意事项（非阻断）：**
- prod spd L2 表尚未创建（merge 后 run_attr_std 首次 DDL）
- merge Step 5 须追加 unit_factor 8 行

**推荐 merge 顺序：**
1. `dim-l3-classify-merge`（prod 写入 icpdf 分类 ~70,623 行）
2. **本 skill** Step 5：backup → DELETE prod L1 dim → INSERT test_dim 后缀表 + unit_factor supplement
3. Step 6（可选）：test_dwd merge 临时表对比阶段 1 后缀表
4. Step 7：`ALLOW_PROD=1 SOURCES="icpdf digikey" L1_LIST="... circuit_protection" run_attr_std.sh prod`
5. Step 10：`run_component_catalog.sh prod` 刷新 catalog
