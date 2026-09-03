# MOV / PPTC 分类核对（gate 收窄后）

生成时间：2026-07-02 13:49

## 1. test CP 沙盒（`dwd_component_class_circuit_protection`）

| L3 | 行数 | 期望 |
|----|------|------|
| **mov** | **0** | **0**（已迁出 CP） |
| **pptc_resettable_fuse** | **867** | ~867 真 PPTC |

## 2. prod 全局 · 源端 `压敏电阻` / `非线性电阻器` 实际 L1/L3

（gate 收窄后这些 id **不应再进 test CP**；prod 上应由 **resistor** 承接）

| l1 | l3 | n |
| --- | --- | --- |
| resistor | varistor_mov | 25237 |
| resistor | ptc_thermistor | 11122 |
| resistor | ntc_thermistor | 3860 |
| resistor | general_fixed_resistor | 4 |
| diode | zener_diode | 2 |
| resistor | other_sensitive_resistor | 1 |

## 3. 泄漏检查（test CP 是否仍含 MOV/非线性源端）

| 检查 | 行数 | 通过 |
|------|------|------|
| test CP · l3=mov | 0 | ✅ |
| test CP · 源端压敏/非线性（任意 L3） | 763 | ⚠️ 见下表 |

**说明**：这些行 **不是 mov gate 泄漏**（mov=0），而是源端同时带 `category2=非线性电阻器` 等标签，但另有 **CP 合法入口**（如 `taginfo=电路保护`、`category=保险丝/热熔断`、`prajson2 PTC RESETTABLE`）进入 CP。

| l3 | category | category2 | n |
| --- | --- | --- | --- |
| pptc_resettable_fuse | 保险丝 | 非线性电阻器 | 384 |
| pptc_resettable_fuse | 热熔断路器/开关/保险丝 | 非线性电阻器 | 323 |
| fuse | 保险丝 | 非线性电阻器 | 53 |
| tvs_diode | TVS二极管 | 非线性电阻器 | 1 |
| esd_suppressor | 热熔断路器/开关/保险丝 | 非线性电阻器 | 1 |
| esd_suppressor | TVS二极管 | 非线性电阻器 | 1 |

## 4. test CP · pptc 分类规则分布

| rule_id | n |
| --- | --- |
| cp_icpdf_pptc_note_en_v1 | 649 |
| cp_icpdf_prajson2_pptc_type_v1 | 121 |
| cp_icpdf_pptc_partno_v1 | 97 |

## 5. pptc 行 prajson2「电阻器类型」分布（抽样 ≤5000）

| 电阻器类型 | n |
| --- | --- |
| PTC RESETTABLE FUSE | 603 |
| (空) | 256 |
| PTC THERMISTOR | 8 |

- 其中 **VARISTOR 误入 pptc**：**0** ✅

## 6. prod · category2=非线性电阻器 → resistor（MOV/NTC/PTC 已归类）

非线性 → resistor（varistor_mov/ntc/ptc 等）：**36,395** 行

| l3 | n |
| --- | --- |
| varistor_mov | 21413 |
| ptc_thermistor | 11122 |
| ntc_thermistor | 3860 |
| general_fixed_resistor | 4 |
| other_sensitive_resistor | 1 |

## 7. DigiKey prod 对照

**circuit_protection**：

| l3 | n |
| --- | --- |
| mov | 6 |

**resistor · varistor**：

| l3 | n |
| --- | --- |
| — | 0 |


DK：`TVS 二极管` 89,357 行在 CP · `压敏电阻，MOV` 6 行在 CP mov（体量极小）。

## 8. test L2 · pptc 清洗结果

| 指标 | 值 |
|------|-----|
| pptc L2 行 | 867 |
| ext 覆盖 | 840 (96.9%) |

## 9. 结论

| 项 | 状态 | 说明 |
|----|------|------|
| **MOV 已迁出 CP** | ✅ | test CP mov=0 · l3=mov 泄漏=0 |
| **MOV 在 prod → resistor** | ✅ | varistor_mov 等已承接非线性/压敏主体 |
| **PPTC 真专规** | ✅ | 867 行 · VARISTOR误入=0 · ext=96.9% |
| **源端带非线性标签仍在 CP** | ⚠️ 763 | 双标签 + tag/保险丝/PPTC 专规，非 MOV gate |
| **TVS 仍在 CP** | ✅ | tvs_diode=24,127 |

**总结**：gate 收窄 + 删 MOV classify 规则后，**ICPDF MOV 已从 CP 清干净**；**PPTC 从 1.09 万误归收敛到 ~867 真 PPTC**（note/prajson2 专规）。
压敏/非线性主体在 **prod resistor**（`varistor_mov` / `ntc_thermistor` / `ptc_thermistor`），与 taxonomy 一致。
