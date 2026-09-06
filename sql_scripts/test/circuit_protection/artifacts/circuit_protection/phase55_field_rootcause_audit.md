# circuit_protection · 字段根因审计（源端 vs 提取）

数据源：`icpdf` · 对比 prajson2 规则 key 命中率 vs EAV/L2 实际填充

判定：**D** 源端无数据 · **R** 规则/key/regex 错 · **R?** 部分可修 · **OK** 匹配

## overcurrent_overtemperature_protection

| 字段 | 范围 | 行数 | 源端key% | regex% | EAV% | L2% | 判定 | 说明 |
|------|------|------|----------|--------|------|-----|------|------|
| `actuator_type` | circuit_breaker | 5,097 | 36.1% | 36.1% | 36.1% | 36.1% | **OK** | 提取与源端基本一致（源端 key 36%） |
| | 规则key | | `执行器类型` 36% | | | | | |
| `pole_count` | circuit_breaker | 5,097 | 37.7% | 37.7% | 37.7% | 37.7% | **OK** | 提取与源端基本一致（源端 key 38%） |
| | 规则key | | `极数` 38% | | | | | |
| `trip_curve_type` | circuit_breaker | 5,097 | 99.7% | 99.7% | 99.7% | 99.7% | **OK** | 提取与源端基本一致（源端 key 100%） |
| | 规则key | | `电路保护类型` 100% | | | | | |
| `rated_function_temp_c` | thermal_cutoff | 937 | 28.6% | 28.6% | 28.5% | 28.5% | **OK** | 提取与源端基本一致（源端 key 29%） |
| | 规则key | | `最高工作温度` 29% | | | | | |
| `current_rating_a` | L2全体 | 36,432 | 75.3% | 75.3% | 75.3% | 75.3% | **OK** | 提取与源端基本一致（源端 key 75%） |
| | 规则key | | `额定电流` 75% | | | | | |
| `lead_free` | L2全体 | 36,432 | 30.6% | 30.6% | 30.6% | 0.0% | **OK** | 提取与源端基本一致（源端 key 31%） |
| | 规则key | | `是否无铅` 31% | | | | | |
| `lifecycle_status` | L2全体 | 36,432 | 94.9% | 94.9% | 76.0% | 76.0% | **R** | value_map 缺 Transferred(6318) 等 → 6884 行 raw 有值 std 空 |
| | 规则key | | `生命周期` 95% | | | | | |
| `manufacturer` | L2全体 | 36,432 | 47.5% | 47.5% | 47.5% | 47.5% | **OK** | 提取与源端基本一致（源端 key 47%） |
| | 规则key | | `IHS 制造商` 47% | | | | | |
| `mounting_type` | L2全体 | 36,432 | 72.1% | 72.1% | 27.4% | 27.4% | **R** | value_map 缺 INLINE/HOLDER(38%)·PANEL MOUNT 等；非 key 错 |
| | 规则key | | `安装特点` 72% | | | | | |
| `mpn` | L2全体 | 36,432 | 91.5% | 91.5% | 91.5% | 0.0% | **OK** | 提取与源端基本一致（源端 key 92%） |
| | 规则key | | `Base Number Matches` 92% | | | | | |
| `msl_level` | L2全体 | 36,432 | 32.0% | 32.0% | 32.0% | 0.0% | **OK** | 提取与源端基本一致（源端 key 32%） |
| | 规则key | | `JESD-609代码` 32% | | | | | |
| `package_case` | L2全体 | 36,432 | 0.3% | 0.3% | 0.3% | 0.3% | **D** | 源端 prajson2 几乎无对应 key；未配规则候选: `物理尺寸` 72% |
| | 规则key | | `封装形式` 0% | | | | | |
| `rohs_compliant` | L2全体 | 36,432 | 58.0% | 58.0% | 58.0% | 58.0% | **OK** | 提取与源端基本一致（源端 key 58%） |
| | 规则key | | `是否Rohs认证` 58% | | | | | |
| `temp_max_c` | L2全体 | 36,432 | 42.1% | 42.1% | 0.0% | 0.0% | **INFO** | schema 未定义 overcurrent L2 temp 列；源端有 key 但 EAV 不写 |
| | 规则key | | `最高工作温度` 42% | | | | | |
| `temp_min_c` | L2全体 | 36,432 | 41.8% | 41.8% | 0.0% | 0.0% | **INFO** | 同上 · schema 缺口非规则错 |
| | 规则key | | `最低工作温度` 42% | | | | | |
| `voltage_rating_v` | L2全体 | 36,432 | 65.3% | 65.3% | 65.3% | 65.3% | **OK** | 提取与源端基本一致（源端 key 65%） |
| | 规则key | | `额定电压（交流）` 65% | | | | | |

## passive_surge_diversion

| 字段 | 范围 | 行数 | 源端key% | regex% | EAV% | L2% | 判定 | 说明 |
|------|------|------|----------|--------|------|-----|------|------|
| `varistor_voltage_v` | mov | 40,795 | 59.9% | 60.2% | 59.9% | 59.9% | **OK** | 提取与源端基本一致（源端 key 60%） |
| | 规则key | | `电路直流最大电压` 51% + `额定（AC）电压（URac）` 10% | | | | | |
| `lead_free` | L2全体 | 41,153 | 54.4% | 54.4% | 54.4% | 0.0% | **OK** | 提取与源端基本一致（源端 key 54%） |
| | 规则key | | `是否无铅` 54% | | | | | |
| `lifecycle_status` | L2全体 | 41,153 | 95.6% | 95.6% | 82.9% | 82.9% | **R?** | 部分未提取：源端 96% vs 提取 83% |
| | 规则key | | `生命周期` 96% | | | | | |
| `manufacturer` | L2全体 | 41,153 | 47.5% | 47.5% | 47.5% | 47.5% | **OK** | 提取与源端基本一致（源端 key 47%） |
| | 规则key | | `IHS 制造商` 47% | | | | | |
| `max_continuous_voltage_v` | L2全体 | 41,153 | 59.0% | 59.4% | 59.0% | 59.0% | **OK** | 提取与源端基本一致（源端 key 59%） |
| | 规则key | | `额定（AC）电压（URac）` 10% + `电路RMS最大电压` 50% | | | | | |
| `mpn` | L2全体 | 41,153 | 87.7% | 87.7% | 87.7% | 0.0% | **OK** | 提取与源端基本一致（源端 key 88%） |
| | 规则key | | `Base Number Matches` 88% | | | | | |
| `msl_level` | L2全体 | 41,153 | 58.7% | 58.7% | 58.7% | 0.0% | **OK** | 提取与源端基本一致（源端 key 59%） |
| | 规则key | | `JESD-609代码` 59% | | | | | |
| `package_case` | L2全体 | 41,153 | 24.9% | 24.9% | 24.9% | 24.9% | **OK** | 提取与源端基本一致（源端 key 25%） |
| | 规则key | | `封装形式` 25% | | | | | |
| `rohs_compliant` | L2全体 | 41,153 | 79.3% | 79.3% | 79.3% | 0.0% | **OK** | 提取与源端基本一致（源端 key 79%） |
| | 规则key | | `是否Rohs认证` 79% | | | | | |
| `temp_max_c` | L2全体 | 41,153 | 76.6% | 76.6% | 67.7% | 67.7% | **R?** | 部分未提取：源端 77% vs 提取 68% |
| | 规则key | | `最高工作温度` 77% | | | | | |
| `temp_min_c` | L2全体 | 41,153 | 66.7% | 66.7% | 66.7% | 66.7% | **OK** | 提取与源端基本一致（源端 key 67%） |
| | 规则key | | `最低工作温度` 67% | | | | | |

## semiconductor_transient_suppression

| 字段 | 范围 | 行数 | 源端key% | regex% | EAV% | L2% | 判定 | 说明 |
|------|------|------|----------|--------|------|-----|------|------|
| `clamping_voltage_v` | tvs_diode | 24,127 | 36.7% | 36.7% | 36.7% | 36.7% | **OK** | 提取与源端基本一致（源端 key 37%） |
| | 规则key | | `最大钳位电压` 37% | | | | | |
| `junction_capacitance_pf` | tvs_diode | 24,127 | 0.0% | 0.0% | 0.0% | 0.0% | **D** | 源端 prajson2 几乎无对应 key；未配规则候选: `电容` 0% |
| | 规则key | | `结电容` 0% | | | | | |
| `peak_pulse_current_a` | tvs_diode | 24,127 | 17.0% | 32.3% | 17.0% | 17.0% | **OK** | 提取与源端基本一致（源端 key 17%） |
| | 规则key | | `最大非重复峰值正向电流` 15% + `最大输出电流` 17% | | | | | |
| `breakdown_voltage_v` | L2全体 | 34,044 | 29.7% | 29.7% | 29.7% | 29.7% | **OK** | 提取与源端基本一致（源端 key 30%） |
| | 规则key | | `最小击穿电压` 30% | | | | | |
| `lead_free` | L2全体 | 34,044 | 37.8% | 37.8% | 37.8% | 0.0% | **OK** | 提取与源端基本一致（源端 key 38%） |
| | 规则key | | `是否无铅` 38% | | | | | |
| `lifecycle_status` | L2全体 | 34,044 | 74.2% | 74.2% | 67.2% | 67.2% | **R?** | 部分未提取：源端 74% vs 提取 67% |
| | 规则key | | `生命周期` 74% | | | | | |
| `manufacturer` | L2全体 | 34,044 | 42.1% | 42.1% | 42.1% | 42.1% | **OK** | 提取与源端基本一致（源端 key 42%） |
| | 规则key | | `IHS 制造商` 42% | | | | | |
| `mpn` | L2全体 | 34,044 | 70.3% | 70.3% | 70.3% | 0.0% | **OK** | 提取与源端基本一致（源端 key 70%） |
| | 规则key | | `Base Number Matches` 70% | | | | | |
| `msl_level` | L2全体 | 34,044 | 55.2% | 55.2% | 55.2% | 0.0% | **OK** | 提取与源端基本一致（源端 key 55%） |
| | 规则key | | `JESD-609代码` 55% | | | | | |
| `package_case` | L2全体 | 34,044 | 67.4% | 67.4% | 67.4% | 67.4% | **OK** | 提取与源端基本一致（源端 key 67%） |
| | 规则key | | `封装形式` 67% | | | | | |
| `peak_pulse_power_w` | L2全体 | 34,044 | 29.6% | 29.6% | 29.6% | 29.6% | **OK** | 提取与源端基本一致（源端 key 30%） |
| | 规则key | | `最大非重复峰值反向功率耗散` 30% | | | | | |
| `rohs_compliant` | L2全体 | 34,044 | 62.9% | 62.9% | 62.9% | 0.0% | **OK** | 提取与源端基本一致（源端 key 63%） |
| | 规则key | | `是否Rohs认证` 63% | | | | | |
| `standoff_voltage_v` | L2全体 | 34,044 | 43.8% | 43.8% | 43.8% | 43.8% | **OK** | 提取与源端基本一致（源端 key 44%） |
| | 规则key | | `最大重复峰值反向电压` 44% | | | | | |
| `temp_max_c` | L2全体 | 34,044 | 53.0% | 53.0% | 53.0% | 53.0% | **OK** | 提取与源端基本一致（源端 key 53%） |
| | 规则key | | `最高工作温度` 53% | | | | | |
| `temp_min_c` | L2全体 | 34,044 | 47.8% | 47.8% | 47.8% | 47.8% | **OK** | 提取与源端基本一致（源端 key 48%） |
| | 规则key | | `最低工作温度` 48% | | | | | |

## 无 L3 schema 的 L3（ext=0 预期）

| L3 | 行数 | ext | 判定 |
|----|------|-----|------|
| fuse | 30,398 | 0% | **INFO** | xlsx 无 L3 ext 字段定义，非提取问题 |
| gdt | 358 | 0% | **INFO** | xlsx 无 L3 ext 字段定义，非提取问题 |
| tspd | 9,248 | 0% | **INFO** | xlsx 无 L3 ext 字段定义，非提取问题 |
| esd_suppressor | 669 | 0% | **INFO** | xlsx 无 L3 ext 字段定义，非提取问题 |

## 需修复项汇总 (R/R?)

- **R** `lifecycle_status` @ 全 L2：`Transferred`/`End Of Life`/`Contact Manufacturer` 等未入 value_map
- **R** `mounting_type` @ overcurrent：`INLINE/HOLDER`/`PANEL MOUNT` 等未入 value_map
- **R?** `lifecycle_status` @ passive/semi：同上 value_map 缺口（幅度较小）
- **R?** `temp_max_c` @ passive：源端 77% vs 提取 68%，部分 regex/单位清洗失败待查
- **INFO** `temp_*` @ overcurrent：schema 无 temp 列，源端 42% 有 key 故意不落库

## 详细根因说明

### manufacturer
IHS 制造商 仅 ~47% 行有值；`制造商` 亦稀少。ICPDF 元数据缺口，非规则错。

### package_case @ overcurrent
断路器/保险丝 ICPDF 几乎无 `封装形式`（0.3%）；`物理尺寸` 72% 有值但是外形尺寸非封装 enum，不宜直接映射。热熔断体 ~7% 有封装。**D 保留**。

### overcurrent temp（误报修正）
源端 42% 有 `最高/最低工作温度`，但 **xlsx schema 未定义 overcurrent L2 的 temp 列**，EAV build 按 schema 过滤故 0 写入。**非规则错，是 schema 设计**；若业务需要可扩 schema + L2 列。

### lifecycle_status（三张 L2 均有）
源端 key 95%/96%/74%，提取 76%/83%/67%。**R · value_map 缺口**：`Transferred`（6318 行）、`End Of Life`、`Contact Manufacturer`、`Not Recommended` 等未映射 → std 空。**修 value_map 可 +19%（overcurrent）**。

### mounting_type @ overcurrent
源端 `安装特点` 72% 有值，提取 27%。**R · value_map 缺口**：`INLINE/HOLDER`（13979）、`PANEL MOUNT`（1803）等未映射；`表面贴装` YES/NO 是独立布尔字段，不是安装类型。**扩 value_map 可至 ~72%**。

### max_continuous_voltage_v @ mov
已配 URac + RMS；59% 提取与源端一致。剩余 41%：**2895/3000 抽样完全无电压 key**；105 有 `电路直流最大电压` 但已映射 varistor ext。**D 为主**，非规则漏抽。

### rated_function_temp_c @ thermal_cutoff
ICPDF **无** `额定工作温度`/`额定动作温度`；仅有 `最高工作温度`（29%）、`最低工作温度`（27%）。规则用最高工作温度作弱代理，提取 28.5% 与源端一致。**D/语义偏差**：字段语义是动作温度，ICPDF 给的是工作温度上限。

### clamping / standoff / breakdown @ semi
源端与提取一致（37%/44%/30%）。tspd/esd 无 L3 clamp 规则且 xlsx 无字段。**D + INFO**。

### peak_pulse_current_a @ tvs
源端 17%，提取 17%。`最大非重复峰值正向电流` 15% + `最大输出电流` 17%（有重叠）。**OK · 源端稀疏**。

### junction_capacitance_pf
ICPDF 全品类无 pF 电容 key（MOV/TVS 均 0%）。**D 保留**。

### pole_count / actuator_type @ circuit_breaker
源端 38%，提取 38%。ICPDF 覆盖低于 DK 83% 是**源端稀疏**，非规则错。**OK**。

### fuse / gdt / tspd / esd ext 0%
xlsx 无 L3 ext 字段定义。**INFO**，非提取问题。
