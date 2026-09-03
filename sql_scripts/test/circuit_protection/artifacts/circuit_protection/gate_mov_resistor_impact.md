# CP gate 收窄影响评估 · 移除压敏电阻 / 非线性电阻器

生成时间：2026-07-02 11:56 · **只读模拟，未改 gate**

## 1. 变更定义

从 **CP icpdf gate** 删除：
- `category`：`压敏电阻`
- `category2`：`压敏电阻`、`非线性电阻器`

**保留** TVS/保险丝/断路器/taginfo=电路保护 等现有 CP 入口。

## 2. 沙盒 CP 总量影响

| 指标 | 行数 | 占当前 CP |
|------|------|-----------|
| 当前 test CP 分类 | **111,629** | 100% |
| **仅因压敏/非线性 gate 进入 CP** | **40,967** | **36.7%** |
| 收窄 gate 后仍留 CP（估算） | **70,662** | **63.3%** |

### 2.1 迁出 CP 行 · 当前沙盒 L3 分布

| cp_l3 | n | pct |
| --- | --- | --- |
| mov | 30727 | 75.0% |
| pptc_resettable_fuse | 10001 | 24.4% |
| esd_suppressor | 211 | 0.5% |
| thermal_cutoff | 28 | 0.1% |


**重点误归（迁出后可由 resistor/其它 L1 重分）：**
- `pptc_resettable_fuse`：**10,001** 行（占迁出 **24.4%**）
- `mov`：**30,727** 行（占迁出 **75.0%**）

### 2.2 迁出后 · 能否进 resistor gate

| 指标 | 行数 |
|------|------|
| 迁出行满足 **resistor icpdf gate** | **40,967** (100.0%) |
| 迁出行在 **prod 已是 resistor** | **39,520** (96.5%) |

迁出行 · prod 当前 L1/L3（Top）：

| prod | n |
| --- | --- |
| (无 prod 分类) | 1445 |
| diode/zener_diode | 2 |


### 2.3 迁出行 prajson2「电阻器类型」（解释 pptc 误归）

| 电阻器类型 | n |
| --- | --- |
| VARISTOR | 23397 |
| PTC THERMISTOR | 8199 |
| (空) | 3285 |
| NTC THERMISTOR | 3259 |
| PTC RESETTABLE FUSE | 2222 |
| NTC RESISTOR | 598 |
| FIXED RESISTOR | 4 |
| NTC RESISTOR NETWORK | 3 |


其中 **当前误归 pptc** 的电阻器类型：

| 电阻器类型 | n |
| --- | --- |
| PTC THERMISTOR | 7364 |
| PTC RESETTABLE FUSE | 2194 |
| (空) | 439 |
| FIXED RESISTOR | 4 |


## 3. category2=非线性电阻器 · 全 ICPDF 交叉表（沙盒 CP vs prod）

| cp_l3 | prod_l1 | prod_l3 | n |
| --- | --- | --- | --- |
| mov | resistor | varistor_mov | 21219 |
| pptc_resettable_fuse | resistor | ptc_thermistor | 10168 |
| mov | resistor | ntc_thermistor | 3860 |
| mov | — | — | 1001 |
| mov | resistor | ptc_thermistor | 872 |
| pptc_resettable_fuse | — | — | 537 |
| esd_suppressor | resistor | varistor_mov | 193 |
| fuse | resistor | ptc_thermistor | 53 |
| thermal_cutoff | resistor | ptc_thermistor | 28 |
| esd_suppressor | — | — | 5 |
| pptc_resettable_fuse | resistor | general_fixed_resistor | 4 |
| esd_suppressor | resistor | ptc_thermistor | 1 |
| tvs_diode | resistor | varistor_mov | 1 |
| mov | resistor | other_sensitive_resistor | 1 |


**prod 上 category2=非线性电阻器 已在 resistor 的 L3：**

| prod_l3 | n |
| --- | --- |
| varistor_mov | 21413 |
| ptc_thermistor | 11122 |
| ntc_thermistor | 3860 |
| general_fixed_resistor | 4 |
| other_sensitive_resistor | 1 |


## 4. category=压敏电阻 · 交叉表

| cp_l3 | prod_l1 | prod_l3 | n |
| --- | --- | --- | --- |
| mov | resistor | varistor_mov | 3897 |
| esd_suppressor | resistor | varistor_mov | 47 |
| mov | diode | zener_diode | 2 |


## 5. 沙盒 CP 当前 L3 分布（对照）

| l3_code | n |
| --- | --- |
| mov | 30765 |
| fuse | 29853 |
| tvs_diode | 24127 |
| pptc_resettable_fuse | 10920 |
| tspd | 9223 |
| circuit_breaker | 5097 |
| esd_suppressor | 669 |
| thermal_cutoff | 598 |
| gdt | 358 |
| spd_module | 19 |


## 6. 结论与建议

1. **收窄 gate 约迁出 40,967 行（36.7%）**，CP 从 111,629 → ~70,662。
2. **pptc 误归可释放 ~10,001 行**（非线性电阻器宽叶 + MOV fallback 造成，不应留在 CP）。
3. **mov ~30,727 行** 应交由 **resistor `varistor_mov`（115009）**；与 prod resistor 规则一致。
4. 迁出行 **100.0%** 可进 resistor gate；prod 已有 **39,520** 行在同 id 上归 resistor。
5. **TVS 不受影响**（gate 保留 `TVS二极管`；DK prod 89k 已在 CP）。
6. merge 前建议：改 `gate_config.py` + 删/降级 `cp_icpdf_mov_*` 规则 → 重跑沙盒 → 再审计 CP 行数与 pptc/mov。
