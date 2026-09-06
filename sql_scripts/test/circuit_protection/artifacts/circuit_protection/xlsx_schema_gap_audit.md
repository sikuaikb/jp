# circuit_protection · xlsx schema 差距审计

真源：`e:\hardware_schema\schema_result\schemas_patched\xlsx\circuit_protection_schema.xlsx`
对比：`test_dim.dim_attr_schema_circuit_protection` + `dim_attr_extract_rule` + ICPDF EAV

状态：**DIM**=dim有无 · **RULE**=extract_rule · **EAV**=已提取 · **SRC**=ICPDF prajson 有无可映射 key

## fuse (Fuse)

- L2 表：`overcurrent_overtemperature_protection` · ICPDF 分类行数：**29,904**

| xlsx 字段 | attr_code | dim | rule | EAV填充 | 占L3 | SRC 探针 | 判定 |
|-----------|-----------|-----|------|---------|------|----------|------|
| 熔断积分 | `melting_i2t_a2s` | ✅ | ✅ic | 10,614 (35.5%) | `焦耳积分标称` 35% | **OK** |
| 熔断速度等级 | `fusing_speed_class` | ✅ | ✅ic | 19,503 (65.2%) | `熔断特性` 68% | **OK** |
| 冷态电阻 | `cold_resistance_mohm` | ✅ | ✅ic | 384 (1.3%) | `电阻` 1% | **R?** |
| 电压类型 | `voltage_type` | ✅ | ✅ic | 23,641 (79.1%) | `额定电压（交流）` 73%; `额定电压（直流）` 42% | **OK** |

## tvs_diode (TVS_Diode)

- L2 表：`semiconductor_transient_suppression` · ICPDF 分类行数：**24,148**

| xlsx 字段 | attr_code | dim | rule | EAV填充 | 占L3 | SRC 探针 | 判定 |
|-----------|-----------|-----|------|---------|------|----------|------|
| 极性类型 | `polarity_type` | ✅ | ✅ic | 10,879 (45.1%) | `极性` 45% | **OK** |
| 钳位电压 | `clamping_voltage_v` | ✅ | ✅ic | 8,845 (36.6%) | `最大钳位电压` 37% | **OK** |
| 峰值脉冲电流 | `peak_pulse_current_a` | ✅ | ✅ic | 4,096 (17.0%) | `最大非重复峰值正向电流` 15%; `最大输出电流` 17% | **OK** |
| 结电容 | `junction_capacitance_pf` | ✅ | ✅ic | 0 (0.0%) | 规则 key 0% | **GAP-EXTRACT** |
| 反向漏电流 | `reverse_leakage_current_ua` | ✅ | ✅ic | 1,156 (4.8%) | `最大反向电流` 5% | **R?** |
| 击穿电压容差 | `breakdown_voltage_tolerance_pct` | ✅ | ✅ic | 55 (0.2%) | `最大电压容差` 0% | **D** |

## tspd (TSPD)

- L2 表：`semiconductor_transient_suppression` · ICPDF 分类行数：**9,202**

| xlsx 字段 | attr_code | dim | rule | EAV填充 | 占L3 | SRC 探针 | 判定 |
|-----------|-----------|-----|------|---------|------|----------|------|
| 触发电压 | `trigger_voltage_v` | ✅ | ✅ic | 3,710 (40.3%) | `最大转折电压` 40% | **OK** |
| 维持电流 | `holding_current_ma` | ✅ | ✅ic | 1,835 (19.9%) | `最大维持电流` 20% | **OK** |
| 导通压降 | `on_state_voltage_v` | ✅ | ✅ic | 72 (0.8%) | `最大通态电压` 1% | **R?** |
| 浪涌通流量（8/20µs） | `surge_current_8_20us_a` | ✅ | ✅ic | 4,603 (50.0%) | `通态非重复峰值电流` 50% | **OK** |
| dv/dt耐量 | `dv_dt_withstand_v_us` | ✅ | ✅ic | 0 (0.0%) | 规则 key 0% | **GAP-EXTRACT** |

## mov (MOV)

- L2 表：`passive_surge_diversion` · ICPDF 分类行数：**5,889**

| xlsx 字段 | attr_code | dim | rule | EAV填充 | 占L3 | SRC 探针 | 判定 |
|-----------|-----------|-----|------|---------|------|----------|------|
| 压敏电压 | `varistor_voltage_v` | ✅ | ✅ic | 3,954 (67.1%) | `额定（AC）电压（URac）` 1%; `电路直流最大电压` 67% | **OK** |
| 压敏电压公差 | `varistor_voltage_tolerance_pct` | ✅ | ✅ic | 139 (2.4%) | `容差` 2% | **R?** |
| 最大钳位电压 | `clamping_voltage_max_v` | ✅ | ✅ic | 2,708 (46.0%) | 规则 key 0% | **OK** |
| 结电容 | `junction_capacitance_pf` | ✅ | ✅dk | 0 (0.0%) | 未探针到相近 key | **GAP-RULE** |
| 最大漏电流 | `leakage_current_max_ua` | ✅ | ❌ | 0 (0.0%) | 未探针到相近 key | **GAP-DIM+RULE** |
| 浪涌寿命次数 | `surge_life_cycles` | ✅ | ❌ | 0 (0.0%) | 未探针到相近 key | **GAP-DIM+RULE** |

## circuit_breaker (Circuit_Breaker)

- L2 表：`overcurrent_overtemperature_protection` · ICPDF 分类行数：**5,097**

| xlsx 字段 | attr_code | dim | rule | EAV填充 | 占L3 | SRC 探针 | 判定 |
|-----------|-----------|-----|------|---------|------|----------|------|
| 脱扣特性曲线类型 | `trip_curve_type` | ✅ | ✅ic | 5,084 (99.7%) | `电路保护类型` 100% | **OK** |
| 极数 | `pole_count` | ✅ | ✅ic | 1,922 (37.7%) | `极数` 38% | **OK** |
| 瞬时脱扣电流倍数下限 | `instantaneous_trip_current_min_x` | ✅ | ❌ | 0 (0.0%) | 候选: `额定电流` 38% | **GAP-DIM+RULE** |
| 额定短路分断能力(Icn) | `rated_short_circuit_capacity_ka` | ✅ | ✅ic | 739 (14.5%) | `额定分断能力` 14% | **OK** |
| 操作机构类型 | `actuator_type` | ✅ | ✅ic | 1,840 (36.1%) | `执行器类型` 36% | **OK** |

## pptc_resettable_fuse (PPTC_Resettable_Fuse)

- L2 表：`overcurrent_overtemperature_protection` · ICPDF 分类行数：**867**

| xlsx 字段 | attr_code | dim | rule | EAV填充 | 占L3 | SRC 探针 | 判定 |
|-----------|-----------|-----|------|---------|------|----------|------|
| 保持电流 | `hold_current_a` | ✅ | ✅ic | 820 (94.6%) | 规则 key 0% | **OK** |
| 触发电流 | `trip_current_a` | ✅ | ✅ic | 817 (94.2%) | 规则 key 0% | **OK** |
| 初始最大电阻 | `resistance_max_initial_ohm` | ✅ | ✅ic | 649 (74.9%) | `电阻` 18%; `电阻` 18% | **OK** |
| 触发后最大电阻 | `resistance_max_tripped_ohm` | ✅ | ❌ | 0 (0.0%) | 候选: `电阻器类型` 70%, `热敏电阻器应用` 66%, `电阻` 18% | **GAP-DIM+RULE** |
| 复位时间 | `reset_time_s` | ✅ | ❌ | 0 (0.0%) | 未探针到相近 key | **GAP-DIM+RULE** |

## thermal_cutoff (Thermal_Cutoff)

- L2 表：`overcurrent_overtemperature_protection` · ICPDF 分类行数：**570**

| xlsx 字段 | attr_code | dim | rule | EAV填充 | 占L3 | SRC 探针 | 判定 |
|-----------|-----------|-----|------|---------|------|----------|------|
| 额定动作温度 | `rated_function_temp_c` | ✅ | ✅ic | 8 (1.4%) | `最高工作温度` 1% | **R?** |
| 动作温度容差 | `function_temp_tolerance_c` | ✅ | ❌ | 0 (0.0%) | 候选: `最高工作温度` 1% | **GAP-DIM+RULE** |

## esd_suppressor (ESD_Suppressor)

- L2 表：`semiconductor_transient_suppression` · ICPDF 分类行数：**505**

| xlsx 字段 | attr_code | dim | rule | EAV填充 | 占L3 | SRC 探针 | 判定 |
|-----------|-----------|-----|------|---------|------|----------|------|
| 结电容 | `junction_capacitance_pf` | ✅ | ✅ic | 341 (67.5%) | `最小二极管电容` 1%; `电容` 0% | **OK** |
| IEC 61000-4-2接触放电等级 | `iec_61000_4_2_contact_kv` | ✅ | ❌ | 0 (0.0%) | 未探针到相近 key | **GAP-DIM+RULE** |
| IEC 61000-4-2空气放电等级 | `iec_61000_4_2_air_kv` | ✅ | ❌ | 0 (0.0%) | 未探针到相近 key | **GAP-DIM+RULE** |
| 动态导通电阻 | `dynamic_on_resistance_ohm` | ✅ | ❌ | 0 (0.0%) | 候选: `电阻器类型` 7% | **GAP-DIM+RULE** |
| 保护通道数 | `channel_count` | ✅ | ✅ic | 238 (47.1%) | 规则 key 0% | **OK** |
| 钳位电压 | `clamping_voltage_v` | ✅ | ✅ic | 378 (74.9%) | `最大钳位电压` 46% | **OK** |

## gdt (GDT)

- L2 表：`passive_surge_diversion` · ICPDF 分类行数：**358**

| xlsx 字段 | attr_code | dim | rule | EAV填充 | 占L3 | SRC 探针 | 判定 |
|-----------|-----------|-----|------|---------|------|----------|------|
| 直流击穿电压 | `dc_sparkover_voltage_v` | ✅ | ✅ic | 21 (5.9%) | 规则 key 0% | **D** |
| 冲击击穿电压 | `impulse_sparkover_voltage_v` | ✅ | ❌ | 0 (0.0%) | 未探针到相近 key | **GAP-DIM+RULE** |
| 弧光维持电压 | `arc_voltage_v` | ✅ | ❌ | 0 (0.0%) | 未探针到相近 key | **GAP-DIM+RULE** |
| 续流遮断电流 | `follow_current_interrupt_a` | ✅ | ❌ | 0 (0.0%) | 未探针到相近 key | **GAP-DIM+RULE** |
| 绝缘电阻 | `insulation_resistance_gohm` | ✅ | ✅ic | 99 (27.7%) | 规则 key 0% | **OK** |
| 极数 | `pole_count` | ✅ | ✅ic | 34 (9.5%) | 规则 key 0% | **D** |

## spd_module (SPD_Module)

- L2 表：`surge_protection_module` · ICPDF 分类行数：**19**

| xlsx 字段 | attr_code | dim | rule | EAV填充 | 占L3 | SRC 探针 | 判定 |
|-----------|-----------|-----|------|---------|------|----------|------|
| SPD分类等级 | `spd_class` | ✅ | ❌ | 0 (0.0%) | 未探针到相近 key | **GAP-DIM+RULE** |
| 保护模式 | `protection_mode` | ✅ | ❌ | 0 (0.0%) | 未探针到相近 key | **GAP-DIM+RULE** |
| 冲击电流（T1专用） | `iimp_ka` | ✅ | ❌ | 0 (0.0%) | 未探针到相近 key | **GAP-DIM+RULE** |
| 短路电流耐受能力 | `iscc_ka` | ✅ | ❌ | 0 (0.0%) | 未探针到相近 key | **GAP-DIM+RULE** |
| 暂态过电压耐受类别 | `tov_category` | ✅ | ❌ | 0 (0.0%) | 未探针到相近 key | **GAP-DIM+RULE** |
| 插拔式结构 | `is_pluggable` | ✅ | ❌ | 0 (0.0%) | 未探针到相近 key | **GAP-DIM+RULE** |
| 遥信触点输出 | `has_remote_signaling` | ✅ | ❌ | 0 (0.0%) | 未探针到相近 key | **GAP-DIM+RULE** |
| 劣化指示方式 | `degradation_indicator` | ✅ | ❌ | 0 (0.0%) | 未探针到相近 key | **GAP-DIM+RULE** |
| 模块安装宽度 | `pkg_width_mm` | ✅ | ❌ | 0 (0.0%) | 未探针到相近 key | **GAP-DIM+RULE** |

## 汇总

| 指标 | 数量 |
|------|------|
| xlsx L3 专属字段总数 | 54 |
| dim 缺失 | 0 |
| extract_rule 缺失（含 icpdf） | 21 |
| 有分类但 EAV=0 | 24 |
| 已可用 (EAV≥10%) | 22 |

## 结论

1. **xlsx 定义 10 个 L3、共 54 个专属字段**；test dim **全覆盖**（dim_miss=0）。
2. **22/54 字段 EAV≥10% 可用**；21 字段仍无 extract_rule；24 字段有分类但 EAV=0。
3. **阶段 A–G 已落地** fuse/tspd/esd/gdt/pptc/breaker/tvs 主字段；**mov 已迁出 CP gate**（ICPDF 0 行）；剩余 GAP 多为 **源端稀疏**（thermal_cutoff、gdt）或 **低优可选字段**（spd 9 字段）。
4. **pptc** gate 收窄后 **867 行 · ext 96.9% · hold/trip ~95%**（误归 MOV 释放后纯度提升）；**spd_module** 19 行 + L2 已建，规则 intentionally disabled。
5. **merge prod 预备**：品牌门控通过 · 详见 `phase55_audit_full.md` 迭代 12 · `merge_precheck.md`。

## 建议落地顺序（剩余 GAP · 非 merge 阻断）

| 优先级 | L3 | 行数 | 待补字段 | OK 字段 | 说明 |
|--------|-----|------|---------|---------|------|
| P2 | pptc_resettable_fuse | 867 | 2 | 3 | 可选字段 |
| P2 | thermal_cutoff | 570 | 1 | 0 | 源端稀疏 |
| P1 | circuit_breaker | 5,097 | 1 | 4 | 可选字段 |
| P1 | tvs_diode | 24,148 | 1 | 3 | 可选字段 |
| P2 | esd_suppressor | 505 | 3 | 3 | 可选字段 |
| P1 | tspd | 9,202 | 1 | 3 | 可选字段 |
| P1 | mov | 5,889 | 3 | 2 | 可选字段 |
| P2 | gdt | 358 | 3 | 1 | 源端稀疏 |
| P3 | spd_module | 19 | 9 | 0 | 样本极少 |