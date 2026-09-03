# 6 个 L1 逆向合仓执行清单

> **背景**：prod 已有分类 + 属性 + 20 张 L2 宽表，但 Git 仓库缺脚本与 seed。  
> **目标**：按 [`dim-l3-classify-merge`](.cursor/skills/dim-l3-classify-merge/SKILL.md) + [`dim-attr-std-merge`](.cursor/skills/dim-attr-std-merge/SKILL.md) 补齐「入仓 + runner 注册 + 可重跑 + 验收留痕」。  
> **不适用**：Step 4/6/8 的 prod dim 替换（prod 已有）；改为 **从 prod 导出 → 入仓 → test_dwd 对比验证**。

---

## 优先级与理由

| 序 | L1 | L2 表数 | prod 分类行数 | 优先理由 |
|---|---:|---:|---:|---|
| **P0** | rf_wireless | 5 | 39,263 | ✅ **Done**（A+B6+B7+B9+C1） |
| P1 | optoelectronics | 2 | 109,523 | ✅ **Done** |
| P1 | storage | 3 | 14,133 | ✅ **Done** |
| P2 | logic_ic | 3 | 19,591 | ✅ **Done** |
| P2 | system_module | 2 | 87,586 | ✅ **Done** |
| P3 | clock_timing | 5 | 124,001 | ✅ **Done** |

---

## 每个 L1 通用步骤（两 skill 串联）

复制本段，把 `<l1>` / `<LL_l1>` 替换后逐 L1 执行。

### A. 分类合仓（dim-l3-classify-merge 逆向版）

- [ ] **A0** 建 `sql_scripts/test/<l1>/README.md`：记录 prod 基线行数（见下文表格）
- [ ] **A1** 从 prod 导出 taxonomy + rules → `test/<l1>/seed/dim_l3_classify_<l1>.csv` + `dim_l3_classify_rule_<l1>.csv`
  ```sql
  SELECT * FROM dim.dim_l3_classify WHERE l1_code='<l1>' ORDER BY l3_id;
  SELECT r.* FROM dim.dim_l3_classify_rule r
  JOIN dim.dim_l3_classify d ON d.l3_id=r.l3_id AND d.schema_version=r.schema_version
  WHERE d.l1_code='<l1>' OR r.rule_id REGEXP '^<l1>_' OR r.rule_id REGEXP '^gate_<l1>_';
  ```
- [ ] **A2** PK 冲突预检（skill Step 1）：`l3_id` 六位段、`rule_id` 前缀不与其它 L1 撞
- [ ] **A3** 质量检查（skill Step 2）：snake_case、无 `_base` 后缀、gate 行存在
- [ ] **A4** `load_seed_<l1>.py` + 后缀表 DDL → 灌 `test_dim.dim_l3_classify_<l1>` / `rule_<l1>`
- [ ] **A5** 跑阶段 1 分类 → `test_dwd.dwd_component_class_<l1>`，行数 vs prod ±0.5%
- [ ] **A6** 对比 prod：L3 分布、最大 L3 占比 < 60%
- [ ] **A7** **入仓**：seed 合入 `sql_scripts/1.classify/seed/` 或 L1 独立 seed（团队约定）；**不重复写 prod**（已在线）
- [ ] **A8** git commit 分类 seed + test 脚本 + 验收行数

### B. 属性合仓（dim-attr-std-merge 逆向版）

- [ ] **B0** 前置：A 段完成，`dwd.dwd_component_class` 含该 L1
- [ ] **B1** 从 prod 导出 → `test/<l1>/seed/dim_attr_schema_<l1>.csv` + `dim_attr_extract_rule_<l1>.csv`
- [ ] **B2** PK / 质量检查（skill Step 1–2）：`extract_rule_id` 带 `<l1>_` 前缀
- [ ] **B3** 还原 L2 脚本（每张 L2 两个文件）→ `git mv sql_scripts/2.attribute_standard/<LL_l1>/ sql_scripts/2.attribute_standard/<LL_l1>_ready/`
  - `dwd_l2_<l1>_<l2>.sql`（DDL，`PK(data_source,id)` 首列）
  - `build_dwd_l2_<l1>_<l2>.sql`（多源 build：`src_param` + `v_std_brand_alias` + EAV）
  - 来源：同事分支 / prod `SHOW CREATE TABLE` + 对照已 merge 的 `11_resistor_ready` 模板
- [ ] **B4** 更新 `run_attr_std.sh`：
  - `l1_dir()` 增加 `<l1>) echo "<LL_l1>_ready" ;;`
  - `l2_files_for_l1()` 增加该 L1 全部 `<l1>_<l2>` 后缀
- [ ] **B5** test_dwd 验证：正式 EAV/L2 脚本输出 merge 表 vs 阶段 1 后缀表（skill Step 6–7）
- [ ] **B6** `ALLOW_PROD=1 run_attr_std.sh prod L1_LIST="<l1>"` 可重跑且行数与 prod 基线一致
- [ ] **B7** brand_null=0；关键字段空值率记录进 README
- [ ] **B8** git commit：`<LL_l1>_ready/` + `run_attr_std.sh` + prod 行数
- [ ] **B9** `ALLOW_PROD=1 run_component_catalog.sh prod INIT_DDL=0` 刷新分类目录

### C. 收尾

- [ ] **C1** DROP `test_dim.*_<l1>` / `test_dwd.*_<l1>` 后缀表
- [ ] **C2** 更新本文件对应 L1 行为 ✅

---

## P0 · rf_wireless（先做）

**目录**：`07_rf_wireless` → `07_rf_wireless_ready`  
**prod 基线**：分类 39,263 行 · taxonomy 21 · rules 19 · schema 215 · extract 64

| L2 表 | 说明 |
|---|---|
| `dwd_l2_rf_wireless_rf_antenna` | |
| `dwd_l2_rf_wireless_rf_passive_network` | |
| `dwd_l2_rf_wireless_rf_signal_control_detection` | |
| `dwd_l2_rf_wireless_rf_transceiver_ic` | |
| `dwd_l2_rf_wireless_rfid_nfc_frontend` | |

**已有材料（可直接用）**：
- `sql_scripts/test/rf_wireless/seed/dim_l3_classify_rf_wireless.csv`
- `sql_scripts/test/rf_wireless/seed/dim_l3_classify_rule_rf_wireless.csv`
- `sql_scripts/test/rf_wireless/dim_l3_classify_rf_wireless.sql`
- `sql_scripts/test/rf_wireless/dim_l3_classify_rule_rf_wireless.sql`
- `sql_scripts/test/rf_wireless/load_seed_rf_wireless.py`
- `sql_scripts/test/rf_wireless/run_classify_rf_wireless.py`

**rf_wireless 特办步骤**：
1. [x] 对比 prod `dim.dim_l3_classify WHERE l1_code='rf_wireless'` 与现有 CSV 是否一致；不一致则以 **prod 为准** 更新 seed
2. [x] 补 A4–A6：灌 test_dim → 跑 classify → 对比 prod 行数（39,263 PASS）
3. [x] attr schema/extract seed 已从 prod 导出；5 张 L2 DDL/build 已生成至 `07_rf_wireless_ready/`
4. [x] B6/B7：`brand_null=0`（`brand IS NULL`）；行数 39,263 与基线 0.00% 偏差
5. [x] B9 catalog 刷新；C1 test 后缀表已 DROP
6. [x] B8 git commit

---

## P1 · optoelectronics

**目录**：`26_optoelectronics_ready`  
**prod 基线**：109,523 · taxonomy 3 · rules 7 · schema 60 · extract 77

| L2 表 |
|---|
| `dwd_l2_optoelectronics_light_emitter` |
| `dwd_l2_optoelectronics_photodetector` |

- [x] 从零建 `sql_scripts/test/optoelectronics/` — A+B6+B9+C1 完成

---

## P1 · storage

**目录**：`20_storage_ready`  
**prod 基线**：14,133 · taxonomy 7 · rules 5 · schema 111 · extract 53

| L2 表 |
|---|
| `dwd_l2_storage_managed_flash_module` |
| `dwd_l2_storage_memory_controller` |
| `dwd_l2_storage_volatile_ram` |

- [x] 从零建 `sql_scripts/test/storage/` — Done

---

## P2 · logic_ic

**目录**：`22_logic_ic_ready`  
**prod 基线**：19,591 · taxonomy 13 · rules 37 · schema 93 · extract 66

| L2 表 |
|---|
| `dwd_l2_logic_ic_combinational_logic` |
| `dwd_l2_logic_ic_sequential_logic` |
| `dwd_l2_logic_ic_signal_buffer_driver` |

---

## P2 · system_module

**目录**：`18_system_module_ready`  
**prod 基线**：87,586 · taxonomy 12 · rules 71 · schema 163 · extract 49

| L2 表 |
|---|
| `dwd_l2_system_module_compute_som_module` |
| `dwd_l2_system_module_power_module` |

- [x] 从零建 `sql_scripts/test/system_module/` — A+B6+B9+C1 完成（classify 87,586 · L2 80,654）

---

## P3 · clock_timing

**目录**：`23_clock_timing_ready`  
**prod 基线**：124,001 · taxonomy 15 · rules 53 · schema 180 · extract 193  
**L2 合计**：124,001（B6 重建后与分类对齐；旧 resonator 95,912 已过期）

| L2 表 |
|---|
| `dwd_l2_clock_timing_clock_management_ic` |
| `dwd_l2_clock_timing_delay_timing_adjustment` |
| `dwd_l2_clock_timing_oscillator` |
| `dwd_l2_clock_timing_resonator` |
| `dwd_l2_clock_timing_timekeeping_timing_ic` |

- [x] 从零建 `sql_scripts/test/clock_timing/` — A+B6+B9+C1 完成（classify 124,001 · L2 124,001；B6 重建后 resonator 117,472 对齐分类，旧 prod L2 95,912 已过期）

---

## 验收门控（每个 L1 必须全绿）

| 检查项 | 门控 |
|---|---|
| `(data_source,id)` 在 catalog 中唯一 | 0 重复（`build_dwd_l2_component_catalog.py` 已验） |
| 分类行数 vs prod 基线 | ±0.5% |
| L2 行数 vs prod 基线 | ±0.5% |
| `brand_null` | 0 |
| Git 可重跑 | `run_attr_std.sh prod L1_LIST=<l1>` 成功 |
| 脚本入仓 | `<LL_l1>_ready/` 含全部 L2 DDL+build |
| runner 注册 | `run_attr_std.sh` 有两处映射 |

---

## 另线：仓库有脚本、prod 无表（mcu_mpu_dsp）

| 表 | 动作 |
|---|---|
| `dwd_l2_dsp_dsp` | 正向 merge 或废弃/合并到 `mcu_mpu_dsp_dsp` |
| `dwd_l2_mcu_mcu` | 确认是否废弃（prod 用 `mcu_mpu_dsp_mcu`） |
| `dwd_l2_mpu_mpu_soc` | 确认是否废弃（prod 用 `mcu_mpu_dsp_mpu_soc`） |

不走本清单逆向流程；单独评审后决定删脚本或补 prod build。

---

## 相关路径

| 用途 | 路径 |
|---|---|
| 分类合仓 skill | `.cursor/skills/dim-l3-classify-merge/SKILL.md` |
| 属性合仓 skill | `.cursor/skills/dim-attr-std-merge/SKILL.md` |
| 分类 SOP | `sql_scripts/1.classify/CONTRIB.md` |
| 属性 SOP | `sql_scripts/2.attribute_standard/CONTRIB.md` |
| L2 模板 | `sql_scripts/2.attribute_standard/11_resistor_ready/` |
| 分类目录构建 | `sql_scripts/2.attribute_standard/run_component_catalog.sh` |
