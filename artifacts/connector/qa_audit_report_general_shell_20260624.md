# general_shell_connector Phase 5.5 QA 审计报告

**日期**: 2026-06-24  
**宽表**: `test_dwd.dwd_l2_connector_general_shell_connector`  
**Schema 版本**: v28（接 v27 RC 重载字段施工）

---

## 基本概况

| 指标 | 数值 |
|------|------|
| 总行数 | 891,380 |
| L3 分布 | circular 803,722 · rectangular 65,110 · d_sub 22,143 · fiber 405 |
| 品牌门控 | PASS（豁免门控，brand_null=68,550，distinct_brand=distinct_brandid=141） |
| Schema | 355 行 / 规则 416 条（354/355 coverage OK） |

---

## L2 物理列空值率（v28 后，24 列）

| 字段 | 填充率 | 决策 |
|------|--------|------|
| `mating_cycles` | **已删除** | **F** → 下放 `d_sub_connector` L3 ext |
| `flammability_rating` | ~2.9% | **D** 保留 |
| `body_color` | ~21% | **OK/D** |
| 其余 L2 列 | 7–99% | **OK/D** |

---

## L3 ext_attributes 整体覆盖率

| L3 | 行数 | ext 非空率 |
|----|------|-----------|
| rectangular_connector | 65,110 | ~74% |
| circular_connector | 803,722 | ~22%（v28 补字段后提升） |
| d_sub_connector | 22,143 | ~55% |
| fiber_optic_connector | 405 | 薄 |

---

## L3 ext 字段级审计（v28 变更项）

### circular_connector（803,722 行）

| 字段 | 填充率 | 决策 |
|------|--------|------|
| `shell_material` | **16.1%** | **新增 v28**，OK |
| `shell_finish_raw` | **13.0%** | **新增 v28**，OK |
| `shell_size_code` | 1.3% | **R** v28：`-` value_map + 去全局规则；EAV 无 `-` 污染 |
| `ip_rating` | ~16% | OK |
| `locking_type` | ~18% | OK |
| `insert_arrangement_code` | ~18% | OK |
| `contact_size_code` | ~1.6% | **D** |
| `shell_diameter_mm` | ~1.4% | **D** |

### d_sub_connector（22,143 行）

| 字段 | 填充率 | 决策 |
|------|--------|------|
| `mating_cycles` | **36.4%** | **F** v28 从 GS L2 下放，OK |
| `has_filter` | ~1.1% | **D** |
| `idc_type_raw` | ~1.2% | **D** |

### rectangular_connector（65,110 行）

v27 后 17 个 ext 字段无 0% 项，**结构冻结**。

---

## 变更说明 v28

| 动作 | 类型 | 说明 |
|------|------|------|
| 删 GS L2 `mating_cycles` | **F** | 仅 d_sub 有 DK 覆盖，下放 L3 ext |
| 增 CC L3 `shell_material` | **新增** | 得捷「外壳材料」，~16% |
| 增 CC L3 `shell_finish_raw` | **新增** | 得捷「外壳表面处理」，~13% |
| 修 `shell_size_code` 规则 | **R** | 去全局 `外壳尺寸`；CC MIL/外壳尺寸加 `-→NULL` value_map |
| 品牌别名 enrich | P0 | `apply_connector_brand_test_dim.py` 门控 PASS |

---

## P 级问题汇总

| 级别 | 问题 | 状态 |
|------|------|------|
| **P0** | 品牌门控 | ✅ PASS（豁免） |
| **P1** | circular `shell_size_code` EAV/ext 不一致 | ✅ 根因：137k 行 `-` 占位；v28 value_map 修复 |
| **P2** | CC 补 shell_material/finish | ✅ v28 已施工 |
| **P2** | mating_cycles L2→d_sub | ✅ v28 已施工 |
| **D** | RC/CC 低填充 HDC/滤波子集字段 | 接受 |
| **INFO** | circular 占 GS 90%，指标须按 L3 解读 | — |

---

## 总体评估

- **矩形 schema（v26/v27）可冻结**，样本 1600744014 / 0936011305 验收通过。
- **v28 完成** circular 外壳材料/表面处理补字段、mating_cycles 下放 d_sub、shell_size_code 规则清理。
- **可进入 Phase 6**（品牌门控已通过豁免校验）。
