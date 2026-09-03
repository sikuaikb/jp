# circuit_protection · ICPDF 试点

Schema：`circuit_protection_schema.xlsx` → `v1.16.01`（对齐 `16_circuit_protection_ready/`）

> **约束**：只写 `test_dim` / `test_dwd`；`dwd.dwd_icpdf_component_param` 只读；**不写** prod `dim.*` / `dwd.dwd_component_*`。

DigiKey circuit_protection 已在 prod（3 张 L2 宽表 + 29 条 DK extract rule）；本目录 **ICPDF** 双回路试点。

## 进度

| 阶段 | 状态 |
|------|------|
| Gate + Classify | ✅ **76,559** ICPDF CP 行（TVS/TSPD/MOV 回 CP · 未分类 16） |
| 属性 dim | ✅ **xlsx gen** 131 schema（10 L3 · 54 专属字段）+ prod DK rule 合并 |
| ICPDF extract rule | ✅ DK 31 + ICPDF 27 + **A–F 阶段规则** → ~110 条 |
| EAV 窄表 | ✅ **592,412** 行 · **65,387** id 有值 |
| L2 宽表（4 张） | ✅ **76,559** 行 · 品牌门控通过 |
| Phase 5.5 QA | ✅ **迭代 13** · 4 张 L2 · 见 `artifacts/circuit_protection/phase55_audit_full.md` |
| merge prod | ✅ Step 5 **PASS**（sandbox=merge **76,559**）· 待人工授权 merge |

## ICPDF 路由边界（与得捷对齐）

| 器件 | ICPDF 归属 | 说明 |
|------|-----------|------|
| TVS / 瞬态抑制 | **circuit_protection** · `tvs_diode` | `gate_diode_icpdf_v1` 不含 TVS 字面 |
| TSPD / 电信浪涌 | **circuit_protection** · `tspd` | schema/L2 在 CP · 非 transistor |
| MOV | **circuit_protection** · `mov` | 仅 `压敏电阻` gate · **不含** `非线性电阻器` 宽桶 |
| 保险丝/PPTC/断路器/GDT/ESD | **circuit_protection** | 本分支 ICPDF 范围 |

DigiKey prod 仍保留 CP 下 `tvs_diode` / MOV 双 gate（与 resistor 重叠为 prod 既有模式）。

## merge 协调（dim-l3-classify-merge Step 0.2 / Step 5）

**G1 + Step 5 全局引擎对齐**（ICPDF TVS/电信保护/保险丝 归 **circuit_protection**）：

1. `patch_icpdf_tvs_to_cp_diode_gate.py --write` → 从 `gate_diode_icpdf_v1` 移除 TVS 字面
2. `patch_icpdf_cp_gate_coordination.py --write` → seed（rival gate exclude · 与 CP 规则一并 merge）
2. merge 时执行 `dim_l3_classify_rule_icpdf_cp_coordination_apply.sql`（prod dim · 与 CP 规则一并生效）
3. CP classify **phase2→3**（`classify_config.py`）避免被 rival L1 phase3 全局决选抢走
4. 引擎 `gate_exclude_category2_in`（`dwd_component_class.sql`）

**G1**（仅 fail **新增**争用）：

```bash
python .cursor/skills/component-etl-methodology/tools/validate_cross_l1_gate_overlap.py \
  --prod-schema dim --sandbox-schema test_dim --sandbox-l1 circuit_protection \
  --data-source icpdf --new-overlap-only \
  --classify-seed-csv sql_scripts/1.classify/seed/dim_l3_classify_rule.csv \
  --coordination-gate-rule-ids gate_diode_icpdf_v1
```

**Step 5**（prod dim 已 merge CP + coordination 后）：

```bash
python audit/_run_step5_merge_engine.py
python audit/run_step5_merge_compare.py   # 目标 ±0.5%
```

**classify rule_id 前缀**：ICPDF 规则已统一为 `circuit_protection_icpdf_*`（skill Step 2）。

## 命令

```bash
cd sql_scripts/test/circuit_protection
python run_test_circuit_protection_full.py   # 分类 → EAV → L2 → QA
# 或分步：
python run_test_circuit_protection.py
python run_test_circuit_protection_attr.py
python run_test_circuit_protection_l2.py
python audit/run_phase55_audit.py
python audit/run_xlsx_schema_gap_audit.py
python audit/run_merge_precheck.py                  # dim-l3-classify-merge 预检
python audit/run_attr_merge_precheck.py             # dim-attr-std-merge 预检
python gen_attr_seed_circuit_protection.py          # xlsx → dim_attr_schema seed
python append_stage_a_extract_rules.py              # 阶段 A（须在 gen_icpdf 之后）
python append_stage_c_gdt_esd_rules.py              # 阶段 C gdt/esd
python append_stage_d_pptc_spd_rules.py             # 阶段 D pptc/spd
python append_stage_e_tco_rules.py                  # 阶段 E thermal_cutoff
python append_stage_f_pptc_rules.py                 # 阶段 F pptc hold/trip/resistance
python export_prod_attr.py                          # 从 prod 刷新 DK rule seed（可选）
```

## 表映射

| prod | 试点 |
|------|------|
| `dim.dim_l3_classify` | `test_dim.dim_l3_classify_circuit_protection` |
| `dim.dim_l3_classify_rule` | `test_dim.dim_l3_classify_rule_circuit_protection` |
| `dim.dim_attr_schema` | `test_dim.dim_attr_schema_circuit_protection` |
| `dim.dim_attr_extract_rule` | `test_dim.dim_attr_extract_rule_circuit_protection` |
| `dwd.dwd_component_class` | `test_dwd.dwd_component_class_circuit_protection` |
| `dwd.dwd_component_attr_std` | `test_dwd.dwd_component_attr_std_circuit_protection` |
| `dwd.dwd_l2_circuit_protection_*` | `test_dwd.dwd_l2_circuit_protection_*` |

## Phase 5.5 摘要（迭代 12 · gate 收窄）

**阶段 G（gate 收窄）**：ICPDF gate 去掉 `压敏电阻` / `非线性电阻器` → 归 **resistor L1**；删除 4 条 `cp_icpdf_mov_*` classify 规则。

| 指标 | 收窄前 | 收窄后 |
|------|--------|--------|
| CP 分类行数 | 111,629 | **70,623** |
| mov | 30,765 | **0**（仅 gdt 358 行留 passive_surge） |
| pptc | 10,920（ext 86%） | **867（ext 96.9%）** · 释放 ~10k 误归 |
| tvs_diode | 24,127 | **24,127**（不变） |

详见 `artifacts/circuit_protection/gate_mov_resistor_impact.md`。

## Phase 5.5 摘要（迭代 11 · 阶段 E/F 存档）

**阶段 E（thermal_cutoff）**：PPTC 污染迁出 · 规则 key 从 `最高工作温度` 改为 `额定工作温度/额定动作温度` · EYP partno supplement。

**阶段 F（pptc）**：`prajson2.电阻` → resistance · hold/trip 空 regex + **mA→A** unit_factor · MF-R/RHEF partno 解码。

| L3 | 分类行数 | ext 覆盖 | 迭代 11 关键字段 |
|----|---------|---------|-----------------|
| **pptc_resettable_fuse** | **10,920** | **86.0%** | `resistance_max_initial_ohm` **81%** · hold/trip **~19%**（源端 cn 上限） |
| **thermal_cutoff** | **598** | **6.0%** | `rated_function_temp_c` 36 id · D 级源端稀疏 |
| **spd_module** | **19** | **0%** | 第 4 张 L2 已建 · 规则 disabled · 低优 |
| mov（对比） | 30,765 ↓ | 83.9% | 阶段 E 迁出误归 PPTC |

xlsx 差距审计：**23/54 OK** · dim_miss=0 · 剩余 GAP 多为源端稀疏或低优可选字段。

## Phase 5.5 摘要（迭代 8 · 阶段 D 存档）

**阶段 D 分类**：`prajson2.电阻器类型=PTC RESETTABLE FUSE` · note `(PPTC|自恢复|PolySwitch)` → pptc；note `(线路浪涌保护模块|浪涌保护模块)` → spd。

| L3 | 分类行数 | ext 覆盖 | 阶段 D 关键字段 |
|----|---------|---------|----------------|
| pptc_resettable_fuse | 2,991 | 48.7% | hold/trip 48% · resistance 38% |
| spd_module | 19 | 0% | L2 已建 · 无 enabled 规则 |

## Phase 5.5 摘要（迭代 7 · 阶段 C 存档）

**阶段 C 规则**：gdt 绝缘电阻/击穿/极数 · esd 钳位/结电容/通道数（prajson cn 为主）。

| L3 | ext 覆盖（阶段 B→C） | 阶段 C 关键字段 |
|----|---------------------|----------------|
| **esd_suppressor** | 0% → **77.3%** | `clamping_voltage_v` 61% · `junction_capacitance_pf` 56% · `channel_count` 41% |
| **gdt** | 0% → **35.5%** | `insulation_resistance_gohm` 28% · `dc_sparkover_voltage_v` 6% · `pole_count` 10% |

xlsx 差距审计：**20/54 OK**（+4）· GDT 冲击击穿/弧光/续流 · ESD IEC/动态电阻 · pptc/spd 仍待。

## Phase 5.5 摘要（迭代 6 · 阶段 B 存档）

**阶段 B 规则**：mov 容差/钳位 · tvs 反向漏电流/击穿容差 · breaker Icn；`dim_unit_factor` 补 **kA←A**。

| L3 | ext 覆盖（阶段 A→B） | 阶段 B 关键字段 |
|----|---------------------|----------------|
| mov | 59.9% → **82.7%** | `varistor_voltage_tolerance_pct` 25% · `clamping_voltage_max_v` 9%（prajson cn） |
| fuse | 74.6% → **83.6%** | `voltage_type` **78%**（修复 regex→value_map `_default`） |
| tvs_diode | 62.1% → **62.2%** | `reverse_leakage_current_ua` 5% · `breakdown_voltage_tolerance_pct` 0.2% |
| circuit_breaker | 99.7% | `rated_short_circuit_capacity_ka` **14.5%** · `instantaneous_trip` ICPDF 无源 |

xlsx 差距审计：**16/54 OK**（+3）· MOV 漏电流/浪涌寿命 · breaker 瞬时脱扣 · gdt/esd/pptc 仍待补。

## Phase 5.5 摘要（迭代 5 · 阶段 A 存档）

**xlsx→dim 落地**：`gen_attr_seed_circuit_protection.py` 从 xlsx 生成 131 行 schema（10 L3 · 54 专属字段）；`append_stage_a_extract_rules.py` 追加 fuse/tspd/tvs 共 12 条 ICPDF 规则（**须在** `gen_attr_extract_rule_icpdf` **之后**执行，否则会被覆盖）。

| L3 | ext 覆盖（迭代 4→5） | 阶段 A 关键字段 |
|----|---------------------|----------------|
| fuse | 0% → **74.6%** | `fusing_speed_class` 64% · `melting_i2t_a2s` 35% |
| tspd | 0% → **52.6%** | `trigger_voltage_v` 40% · `surge_current_8_20us_a` 50% |
| tvs_diode | 53.6% → **62.1%** | `polarity_type` 45% |

xlsx 差距审计：**dim_miss=0** · 13/54 字段 **OK** · 其余待阶段 B 或源端缺失。

**仍待迭代（阶段 A 存档 · 部分已在 B/C 完成）**：
- ~~`voltage_type`~~ ✅ 阶段 B 修复
- ~~gdt / esd~~ ✅ 阶段 C
- ~~**pptc / spd_module**~~ ✅ 阶段 D · pptc 2991 行 · spd 19 行
- 剩余 **16** 未分类

## Phase 5.5 摘要（迭代 2 存档）

**品牌门控**：3 张 L2 均 `brand_null=0` ✅ · **未分类 16**（电信 fallback 后 102→16）

| 指标 | 迭代前 | 迭代后 |
|------|--------|--------|
| MOV `max_continuous_voltage_v` (L2) | 9.6% | **59.0%** |
| MOV `varistor_voltage_v` (ext) | 50.5% | **59.9%** |
| TVS `clamping_voltage_v` (ext) | 0% | **53.6%** |
| TVS `peak_pulse_current_a` (EAV) | 0 | **4,096 id** |
| 电信 fallback → tspd | — | **+86 行** |

**本轮规则变更**：
- MOV：`额定（AC）电压（URac）` / `电路RMS最大电压` · 宽松数值 regex
- TVS L3：`最大钳位电压`（非 tspd 的 `最大转折电压`）· `最大非重复峰值正向电流`
- Classify：`cp_icpdf_telecom_c2_fallback_v1` · c2=电信保护电路 → tspd

**仍待迭代**：
- `junction_capacitance_pf` ICPDF 无 pF 源（TVS/MOV 均 0%）
- tspd/esd/gdt 无 schema L3 字段 → ext 0% 属预期
- 剩余 **16** 未分类：11 无 c2 · 4 c2=瞬态抑制器 · 1 PMIC 误挂

## Phase 5.5 摘要（迭代 1 存档）

**品牌门控**：3 张 L2 均 `brand_null=0` ✅

| L2 | 行数 | 关键 L2 列 | ext 覆盖 |
|----|------|-----------|---------|
| overcurrent_overtemperature_protection | 36,432 | current 75% · voltage 65% | breaker 38% · thermal 29% |
| passive_surge_diversion | 41,153 | max_cont_V **10%** ⚠ | mov varistor **51%** |
| semiconductor_transient_suppression | 33,958 | standoff 44% · breakdown 30% | tvs/tspd L3 ext **0%** ⚠ |

**待迭代（Phase 5.5 双回路）** — 部分已在迭代 2 完成：
1. ~~MOV `max_continuous_voltage_v`~~ ✅ 59%
2. ~~TVS L3 ext~~ ✅ clamp 54% · ipp 4k id
3. ~~电信 fallback~~ ✅ 未分类 16
4. ~~fuse L3 ext 0%~~ ✅ 阶段 A · xlsx 有 fuse 4 字段，已从 prod 不完整 dim 补齐

## 踩坑

- `schema_version` prod 为 `circuit_protection_schema_v1.16.01`（35 字符）→ test 统一 **`v1.16.01`**
- EAV `l2_code` 须 **VARCHAR(96)**（最长 L2 名 35 字符）
- L2 build 模板默认 `data_source='digikey'` → `gen_l2_wide_circuit_protection.py` 须改 icpdf+digikey
- `mfr_agg` 须指向 test EAV 表，非 prod `dwd.dwd_component_attr_std`
- `gen_attr_extract_rule_icpdf` **会重写** CSV → `run_test` 已在其后自动调用 `append_stage_a/b/c/d/e/f`
- spd classify **勿用**宽泛 `(?i)SPD`（会吃到 TSPD note）· pptc classify 须在 fuse 电熔丝规则之前
- pptc/TCO classify 用 `note_regexp` · partno 规则须限 `category=热熔断路器/开关/保险丝` 以免误伤 MOV
- pptc hold/trip：**勿用只捕获数字的 regex** · 须空 regex + `dim_unit_factor` mA→A（否则 500 mA→500A）
- thermal_cutoff 规则 **勿用** `最高工作温度`（运行上限）作动作温度
- **spd_module** L2 宽表 `test_dwd.dwd_l2_circuit_protection_surge_protection_module` · 仅已分类 spd_module 入表（~19 行）
- `voltage_type` 等 value_map `_default` 规则须 **留空** `source_value_regex`（`.+` 无捕获组会导致 value_raw 为空）

参考：[`../switch/README.md`](../switch/README.md)
