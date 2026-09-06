# circuit_protection · ICPDF Phase 5.5 审计报告（skill 完整版）

数据源：`icpdf` · 表：`test_dwd.dwd_l2_circuit_protection_*`
Schema：`v1.16.01` · 迭代 2（MOV/TVS key + 电信 fallback）

## 一、基本概况与品牌门控

- **overcurrent_overtemperature_protection**：36,438 行 · brand_null=0 · distinct_brand=31 / brandid=31 · ✅
- **passive_surge_diversion**：6,247 行 · brand_null=0 · distinct_brand=20 / brandid=20 · ✅
- **semiconductor_transient_suppression**：33,855 行 · brand_null=0 · distinct_brand=72 / brandid=72 · ✅

**品牌门控**：✅ 通过（可进 Phase 6 讨论）

**L3 分类分布**：

| L3 | 行数 |
|----|------|
| fuse | 29,904 |
| tvs_diode | 24,148 |
| tspd | 9,202 |
| mov | 5,889 |
| circuit_breaker | 5,097 |
| pptc_resettable_fuse | 867 |
| thermal_cutoff | 570 |
| esd_suppressor | 505 |
| gdt | 358 |
| spd_module | 19 |

## 二、L2 物理列空值率

### overcurrent_overtemperature_protection（36,438 行）

| 字段 | 填充 | 占比 | 标注 |
|------|------|------|------|
| `manufacturer` | 17,292 | 47.5% | OK |
| `lifecycle_status` | 34,585 | 94.9% | OK |
| `rohs_compliant` | 21,140 | 58.0% | OK |
| `package_case` | 103 | 0.3% | D? |
| `mounting_type` | 26,267 | 72.1% | OK |
| `current_rating_a` | 27,450 | 75.3% | OK |
| `voltage_rating_v` | 23,796 | 65.3% | OK |

### passive_surge_diversion（6,247 行）

| 字段 | 填充 | 占比 | 标注 |
|------|------|------|------|
| `manufacturer` | 2,051 | 32.8% | OK |
| `lifecycle_status` | 4,432 | 70.9% | OK |
| `package_case` | 3,331 | 53.3% | OK |
| `max_continuous_voltage_v` | 3,967 | 63.5% | OK |
| `temp_min_c` | 4,184 | 67.0% | OK |
| `temp_max_c` | 4,197 | 67.2% | OK |

### semiconductor_transient_suppression（33,855 行）

| 字段 | 填充 | 占比 | 标注 |
|------|------|------|------|
| `manufacturer` | 14,231 | 42.0% | OK |
| `lifecycle_status` | 25,076 | 74.1% | OK |
| `package_case` | 22,768 | 67.3% | OK |
| `standoff_voltage_v` | 14,903 | 44.0% | OK |
| `breakdown_voltage_v` | 10,125 | 29.9% | OK |
| `peak_pulse_power_w` | 10,081 | 29.8% | OK |
| `temp_min_c` | 16,140 | 47.7% | OK |
| `temp_max_c` | 17,899 | 52.9% | OK |

### L2×L3 交叉（低填充字段）

**overcurrent_overtemperature_protection · `package_case`**
- fuse: 7/29,904 (0.0%)
- circuit_breaker: 0/5,097 (0.0%)
- pptc_resettable_fuse: 96/867 (11.1%)
- thermal_cutoff: 0/570 (0.0%)

**overcurrent_overtemperature_protection · `voltage_rating_v`**
- fuse: 21,865/29,904 (73.1%)
- circuit_breaker: 1,923/5,097 (37.7%)
- pptc_resettable_fuse: 1/867 (0.1%)
- thermal_cutoff: 7/570 (1.2%)

**passive_surge_diversion · `max_continuous_voltage_v`**
- mov: 3,967/5,889 (67.4%)
- gdt: 0/358 (0.0%)

## 三、L3 ext 字段级审计（§2.4 两步法）

| L3 | 字段 | EAV 填充 | 占该 L3 | 决策 | 说明 |
|----|------|----------|---------|------|------|
| circuit_breaker | `actuator_type` | 1,840 | 36.1% | **OK** |  |
| circuit_breaker | `pole_count` | 1,922 | 37.7% | **OK** |  |
| circuit_breaker | `trip_curve_type` | 5,084 | 99.7% | **OK** |  |
| mov | `junction_capacitance_pf` | 0 | 0.0% | **D** | ICPDF 无 pF key；选型有价值，等他源/手册 |
| mov | `varistor_voltage_v` | 3,954 | 67.1% | **OK** | 59% ext 覆盖 |
| thermal_cutoff | `rated_function_temp_c` | 8 | 1.4% | **R?** | 最高工作温度映射 rated_function_temp |
| tvs_diode | `clamping_voltage_v` | 8,845 | 36.6% | **OK** | 迭代2 已修 最大钳位电压 |
| tvs_diode | `junction_capacitance_pf` | 0 | 0.0% | **D** | ICPDF 无 pF key；选型有价值，等他源/手册 |
| tvs_diode | `peak_pulse_current_a` | 4,096 | 17.0% | **OK** | ICPDF 仅部分 TVS 有 Ipp key |

## 四、L3 ext 整体覆盖率

### overcurrent_overtemperature_protection

- fuse: 25,319/29,904 (84.7%)
- circuit_breaker: 5,084/5,097 (99.7%)
- pptc_resettable_fuse: 840/867 (96.9%)
- thermal_cutoff: 8/570 (1.4%)

### passive_surge_diversion

- mov: 5,100/5,889 (86.6%)
- gdt: 127/358 (35.5%)

### semiconductor_transient_suppression

- tvs_diode: 15,001/24,148 (62.1%)
- tspd: 4,860/9,202 (52.8%)
- esd_suppressor: 470/505 (93.1%)

## 五、P 级问题汇总

| 级别 | 项 | 行动 |
|------|-----|------|
| **P0** | — | 无（品牌门控通过） |
| **P1** | `trip_curve_type` @ circuit_breaker | **已修复** 迭代3 · 电路保护类型 → 99.7% |
| **P1** | `package_case` @ overcurrent 0.3% | **D** 保留；断路器 ICPDF 无封装 key（DK 亦 0%） |
| **P2** | tspd/esd/gdt ext 0% | **INFO** xlsx 无 L3 schema；非规则问题 |
| **P2** | `junction_capacitance_pf` TVS/MOV 0% | **D** ICPDF 无 pF 源 |
| **P2** | 分类未覆盖 16 行 | INFO · 非宽表阻断项 |
| **D** | manufacturer ~47% | ICPDF `IHS 制造商` 覆盖；接受 |
| **D** | fuse L3 ext 0% | xlsx 无 fuse L3 字段 |
| **INFO** | 迭代2 MOV 59% / TVS clamp 54% | 已修复，进入监控 |

## 六、总体评估

**可进入 Phase 6 预备**：品牌门控硬门槛已通过；核心 L2 电气列（current/voltage/standoff/breakdown）
填充率在 ICPDF 源上达到可用水平（29%–75%）。

**不建议本轮再改 schema**：tspd/esd/gdt 无 L3 字段是 xlsx 设计问题，非 ICPDF 单源能解。

**建议下一轮双回路**：
1. circuit_breaker `pole_count` / `actuator_type` — 按 L3 抽 5 条 MPN 对照 icpdf 页面
2. MOV `max_continuous_voltage_v` 剩余 41% 空 — 探针是否还有未映射 key
3. merge prod 前：DK classify 进 test L2 UNION（当前仅 ICPDF）
