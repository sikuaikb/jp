# DWD L2 宽表 · 27 大类数据量明细

> 统计日期：**2026-07-17** 全量连库；**2026-07-20** 局部刷新 `resistor`（ecloud classify+attr 合入 prod）
> 数据源：`dwd.dwd_l2_*` 业务宽表（prod）
> 排除：`dwd_l2_component_catalog`、任何含 `_llm_` / `_audit` / `_sample` / `_result` 的辅助表
> 行数按 `data_source` 字段汇总（`digikey` / `icpdf` / **`ecloud`**）；distinct 按 `mpn` 字段去重

## ⚠️ 覆盖率口径说明

"清洗完成度"有三个口径，**只有 distinct partno 覆盖率才是真实完成度**：

| 口径 | digikey | icpdf | **ecloud** | 含义 |
|---|---:|---:|---:|---|
| 大类完成率（有 L2 行的 L1） | 27/27 = 100% | **27/27 = 100%** | **8/27 = 30%** | 建了 L2 且该源有数据的 L1 数（易误导）|
| 行数清洗率 | 74.39% | **72.58%** | **70.00%** | L2 行数 / param 层总行数 |
| **distinct partno 覆盖率** | **74.39%** | **61.94%** | **68.20%** | 进 L2 的 distinct 型号 / 源端 distinct 型号（ecloud distinct 为各 L1 相加，略高估）|
| 未覆盖 distinct partno | **1,976,539** | **2,580,239** | **1,123,401** | 源端有但没进任何 L2 的型号 |

**ecloud** param 层 3,559,619 行 / distinct 3,532,255；L2 已合入 **8/27** L1（+**resistor**），合计 **2,491,833** 行 / distinct 约 **2,408,854**。

> 注：覆盖率分母为 `dwd_*_component_param`。icpdf 源端明细 `dwd_icpdf_component_detail` 口径下真实清洗率更低，见 [`JULY_2026_GOALS.md`](JULY_2026_GOALS.md)。

## 与上一版差异（7-17 → **7-20 resistor ecloud**）

**7-17**：全表扫描 ecloud 已入 7 个 L1。  
**7-20**：`caixj/ecloud_resistor` classify+attr 合入 prod；resistor ecloud **+1,228,372** 行。

| 指标 | 7-17 | **7-20** | Δ |
|---|---:|---:|---:|
| 总行数 | 12,106,804 | **13,327,517** | +1,220,713 |
| digikey | 5,740,798 | **5,740,792** | -6 |
| icpdf | 5,102,503 | **5,094,850** | -7,653 |
| **ecloud** | 1,263,461 | **2,491,833** | **+1,228,372** |
| other | 42 | **42** | 0 |

ecloud 已入 L1 明细（含 7-20 resistor）：

| L1 | ecloud 行数 | ecloud distinct |
|---|---:|---:|
| capacitor | 677,713 | 673,878 |
| **resistor** | **1,228,372** | **1,227,570** |
| clock_timing | 340,637 | 293,158 |
| diode | 98,105 | 90,753 |
| inductor | 61,783 | 61,551 |
| storage | 34,043 | 16,784 |
| relay | 27,372 | 27,327 |
| optoelectronics | 23,808 | 17,833 |
| **合计（行）** | **2,491,833** | — |

## 汇总

| 指标 | 数值 |
|------|------|
| L1 大类数 | 27 |
| L2 宽表数 | 112 |
| 总行数 | **13,327,517** |
| digikey | **5,740,792（43.1%）** |
| icpdf | **5,094,850（38.2%）** |
| **ecloud** | **2,491,833（18.7%）** |
| other | **42** |

## 27 大类汇总

| L1 | 表数 | digikey | icpdf | ecloud | 合计 | dk distinct | ic distinct | ec distinct |
|----|------|---------|-------|--------|------|-------------|-------------|-------------|
| connector | 6 | 2,429,986 | 1,037,565 | 0 | 3,467,551 | 2,429,985 | 1,036,510 | 0 |
| resistor | 3 | 768,022 | 589,335 | **1,228,372** | **2,585,729** | 768,022 | 588,393 | **1,227,570** |
| capacitor | 4 | 1,164,556 | 383,842 | 677,713 | 2,226,111 | 1,164,556 | 380,494 | 673,878 |
| clock_timing | 5 | 102,235 | 702,810 | 340,637 | 1,145,682 | 102,235 | 342,965 | 293,158 |
| diode | 3 | 121,415 | 460,647 | 98,105 | 680,167 | 121,415 | 415,760 | 90,753 |
| pmic | 8 | 112,367 | 434,499 | 0 | 546,866 | 112,367 | 426,360 | 0 |
| storage | 6 | 15,115 | 258,173 | 34,043 | 307,331 | 15,115 | 246,199 | 16,784 |
| transistor | 4 | 30,115 | 265,286 | 0 | 295,401 | 30,115 | 239,502 | 0 |
| switch | 3 | 139,531 | 144,273 | 0 | 283,804 | 139,531 | 16,207 | 0 |
| optoelectronics | 2 | 109,523 | 125,996 | 23,808 | 259,327 | 109,523 | 9,789 | 17,833 |
| circuit_protection | 4 | 153,287 | 76,559 | 0 | 229,846 | 153,287 | 14,863 | 0 |
| inductor | 3 | 134,265 | 18,653 | 61,783 | 214,701 | 134,265 | 18,605 | 61,551 |
| sensor | 6 | 165,937 | 20,904 | 0 | 186,841 | 165,937 | 4,749 | 0 |
| logic_ic | 3 | 19,591 | 133,194 | 0 | 152,785 | 19,591 | 122,623 | 0 |
| relay | 2 | 48,175 | 41,769 | 27,372 | 117,316 | 48,175 | 41,536 | 27,327 |
| mcu_mpu_dsp | 3 | 11,137 | 82,142 | 0 | 93,320 | 11,137 | 79,058 | 0 |
| system_module | 4 | 87,586 | 646 | 0 | 88,232 | 87,586 | 646 | 0 |
| rf_wireless | 6 | 39,263 | 41,324 | 0 | 80,587 | 39,263 | 40,251 | 0 |
| filter | 4 | 19,534 | 59,796 | 0 | 79,330 | 19,534 | 28,751 | 0 |
| amplifier | 6 | 6,686 | 72,272 | 0 | 78,958 | 6,686 | 66,498 | 0 |
| interface_communication_ic | 6 | 11,240 | 43,772 | 0 | 55,012 | 11,240 | 2,018 | 0 |
| data_converter | 2 | 11,103 | 34,971 | 0 | 46,074 | 11,103 | 33,102 | 0 |
| isolator | 4 | 13,206 | 31,391 | 0 | 44,597 | 13,206 | 28,267 | 0 |
| transformer | 4 | 9,482 | 19,270 | 0 | 28,752 | 9,482 | 880 | 0 |
| driver_ic | 5 | 4,945 | 8,765 | 0 | 13,710 | 4,945 | 8,475 | 0 |
| fpga_cpld | 2 | 3,665 | 6,777 | 0 | 10,442 | 3,665 | 6,763 | 0 |
| acoustic_device | 4 | 8,825 | 219 | 0 | 9,044 | 8,825 | 219 | 0 |
| **合计** | **112** | **5,740,792** | **5,094,850** | **2,491,833** | **13,327,517** | **5,740,791** | **4,198,906** | **2,408,854** |

> 注：icpdf 部分 L1 行数远大于 distinct（switch / circuit_protection / sensor / transformer / interface_communication_ic / clock_timing / **optoelectronics**），**行数清洗率会高估真实覆盖**。digikey / ecloud 多数品类行数 ≈ distinct。

## 各大类明细

### connector

合计 **3,467,551** 行（digikey 2,429,986 + icpdf 1,037,565），6 张表。

| 表名 | digikey | icpdf | ecloud | 合计 |
|------|---------|-------|--------|------|
| `dwd_l2_connector_backplane_ic_socket_connector` | 699,524 | 9,774 | 0 | 709,298 |
| `dwd_l2_connector_board_wire_interconnect_connector` | 725,459 | 535,066 | 0 | 1,260,525 |
| `dwd_l2_connector_general_shell_connector` | 891,380 | 318,426 | 0 | 1,209,806 |
| `dwd_l2_connector_power_terminal_connector` | 68,154 | 142,655 | 0 | 210,809 |
| `dwd_l2_connector_rf_coaxial_connector` | 28,444 | 6,777 | 0 | 35,221 |
| `dwd_l2_connector_standard_interface_socket_connector` | 17,025 | 24,867 | 0 | 41,892 |

### capacitor

合计 **2,226,111** 行（digikey 1,164,556 + icpdf 383,842 + ecloud **677,713**），4 张表。
> 含 ecloud：**677,713** 行 / distinct **673,878**。

| 表名 | digikey | icpdf | ecloud | 合计 |
|------|---------|-------|--------|------|
| `dwd_l2_capacitor_non_polar_fixed_capacitor` | 916,349 | 190,755 | 528,691 | 1,635,795 |
| `dwd_l2_capacitor_polar_electrolytic_capacitor` | 246,626 | 192,649 | 146,956 | 586,231 |
| `dwd_l2_capacitor_supercapacitor` | 0 | 86 | 1,741 | 1,827 |
| `dwd_l2_capacitor_variable_capacitor` | 1,581 | 352 | 325 | 2,258 |

### resistor

合计 **2,585,729** 行（digikey 768,022 + icpdf 589,335 + ecloud **1,228,372**），3 张表。  
> 2026-07-20 合入 ecloud；含 ecloud：**1,228,372** 行 / distinct **1,227,570**。

| 表名 | digikey | icpdf | ecloud | 合计 |
|------|---------|-------|--------|------|
| `dwd_l2_resistor_fixed_resistor` | 72,988 | 539,414 | 1,205,450 | 1,817,852 |
| `dwd_l2_resistor_protective_sensitive_resistor` | 14,620 | 39,291 | 7,923 | 61,834 |
| `dwd_l2_resistor_variable_resistor` | 680,414 | 10,630 | 14,999 | 706,043 |

### clock_timing

合计 **1,145,682** 行（digikey 102,235 + icpdf 702,810 + ecloud **340,637**），5 张表。
> 含 ecloud：**340,637** 行 / distinct **293,158**。

| 表名 | digikey | icpdf | ecloud | 合计 |
|------|---------|-------|--------|------|
| `dwd_l2_clock_timing_clock_management_ic` | 1,999 | 26,551 | 21,081 | 49,631 |
| `dwd_l2_clock_timing_delay_timing_adjustment` | 300 | 18,742 | 267,378 | 286,420 |
| `dwd_l2_clock_timing_oscillator` | 0 | 387,959 | 5,304 | 393,263 |
| `dwd_l2_clock_timing_resonator` | 95,912 | 263,590 | 46,173 | 405,675 |
| `dwd_l2_clock_timing_timekeeping_timing_ic` | 4,024 | 5,968 | 701 | 10,693 |

### diode

合计 **680,167** 行（digikey 121,415 + icpdf 460,647 + ecloud **98,105**），3 张表。
> 含 ecloud：**98,105** 行 / distinct **90,753**。

| 表名 | digikey | icpdf | ecloud | 合计 |
|------|---------|-------|--------|------|
| `dwd_l2_diode_rectifier_switching_diode` | 53,839 | 177,483 | 44,526 | 275,848 |
| `dwd_l2_diode_rf_special_diode` | 1,301 | 22,010 | 2,068 | 25,379 |
| `dwd_l2_diode_voltage_reg_protection_diode` | 66,275 | 261,154 | 51,511 | 378,940 |

### pmic

合计 **546,866** 行（digikey 112,367 + icpdf 434,499），8 张表。

| 表名 | digikey | icpdf | ecloud | 合计 |
|------|---------|-------|--------|------|
| `dwd_l2_pmic_battery_management` | 1,626 | 2,171 | 0 | 3,797 |
| `dwd_l2_pmic_linear_regulator_reference` | 737 | 127,570 | 0 | 128,307 |
| `dwd_l2_pmic_power_distribution_switch` | 2,180 | 1,342 | 0 | 3,522 |
| `dwd_l2_pmic_power_supervisor` | 34 | 23,635 | 0 | 23,669 |
| `dwd_l2_pmic_protocol_power_controller` | 0 | 0 | 0 | 0 |
| `dwd_l2_pmic_switching_controller` | 0 | 19,846 | 0 | 19,846 |
| `dwd_l2_pmic_switching_dcdc_converter` | 106,792 | 259,926 | 0 | 366,718 |
| `dwd_l2_pmic_system_pmic` | 998 | 9 | 0 | 1,007 |

### storage

合计 **307,331** 行（digikey 15,115 + icpdf 258,173 + ecloud **34,043**），6 张表。
> 含 ecloud：**34,043** 行 / distinct **16,784**。

| 表名 | digikey | icpdf | ecloud | 合计 |
|------|---------|-------|--------|------|
| `dwd_l2_storage_flash_memory` | 219 | 51,534 | 7,573 | 59,326 |
| `dwd_l2_storage_managed_flash_module` | 11,346 | 0 | 100 | 11,446 |
| `dwd_l2_storage_memory_controller` | 54 | 8,680 | 3,030 | 11,764 |
| `dwd_l2_storage_nv_ram` | 3 | 0 | 330 | 333 |
| `dwd_l2_storage_rewritable_rom` | 686 | 51,167 | 8,718 | 60,571 |
| `dwd_l2_storage_volatile_ram` | 2,807 | 146,792 | 14,292 | 163,891 |

### transistor

合计 **295,401** 行（digikey 30,115 + icpdf 265,286），4 张表。

| 表名 | digikey | icpdf | ecloud | 合计 |
|------|---------|-------|--------|------|
| `dwd_l2_transistor_bipolar_transistor` | 6,854 | 111,756 | 0 | 118,610 |
| `dwd_l2_transistor_fet` | 10,257 | 81,978 | 0 | 92,235 |
| `dwd_l2_transistor_igbt` | 6,556 | 10,196 | 0 | 16,752 |
| `dwd_l2_transistor_thyristor` | 6,448 | 61,356 | 0 | 67,804 |

### switch

合计 **283,804** 行（digikey 139,531 + icpdf 144,273），3 张表。

| 表名 | digikey | icpdf | ecloud | 合计 |
|------|---------|-------|--------|------|
| `dwd_l2_switch_magnetic_sensing_switch` | 2,121 | 166 | 0 | 2,287 |
| `dwd_l2_switch_mechanical_actuated_switch` | 120,303 | 117,944 | 0 | 238,247 |
| `dwd_l2_switch_mechanical_sensing_switch` | 17,107 | 26,163 | 0 | 43,270 |

### optoelectronics

合计 **259,327** 行（digikey 109,523 + icpdf 125,996 + ecloud **23,808**），2 张表。
> icpdf 行数 ≫ distinct（light_emitter ic distinct 9,129），多版本料号。
> 含 ecloud：**23,808** 行 / distinct **17,833**。

| 表名 | digikey | icpdf | ecloud | 合计 |
|------|---------|-------|--------|------|
| `dwd_l2_optoelectronics_light_emitter` | 108,775 | 118,717 | 21,772 | 249,264 |
| `dwd_l2_optoelectronics_photodetector` | 748 | 7,279 | 2,036 | 10,063 |

### circuit_protection

合计 **229,846** 行（digikey 153,287 + icpdf 76,559），4 张表。

| 表名 | digikey | icpdf | ecloud | 合计 |
|------|---------|-------|--------|------|
| `dwd_l2_circuit_protection_overcurrent_overtemperature_protection` | 63,924 | 36,438 | 0 | 100,362 |
| `dwd_l2_circuit_protection_passive_surge_diversion` | 6 | 6,247 | 0 | 6,253 |
| `dwd_l2_circuit_protection_semiconductor_transient_suppression` | 89,357 | 33,855 | 0 | 123,212 |
| `dwd_l2_circuit_protection_surge_protection_module` | 0 | 19 | 0 | 19 |

### inductor

合计 **214,701** 行（digikey 134,265 + icpdf 18,653 + ecloud **61,783**），3 张表。
> 含 ecloud：**61,783** 行 / distinct **61,551**。

| 表名 | digikey | icpdf | ecloud | 合计 |
|------|---------|-------|--------|------|
| `dwd_l2_inductor_emi_filter_inductor` | 15,965 | 1,275 | 12,150 | 29,390 |
| `dwd_l2_inductor_hf_chip_inductor` | 16,777 | 6,936 | 13,056 | 36,769 |
| `dwd_l2_inductor_power_inductor` | 101,523 | 10,442 | 36,577 | 148,542 |

### sensor

合计 **186,841** 行（digikey 165,937 + icpdf 20,904），6 张表。

| 表名 | digikey | icpdf | ecloud | 合计 |
|------|---------|-------|--------|------|
| `dwd_l2_sensor_current_sensor_ic` | 5,077 | 22 | 0 | 5,099 |
| `dwd_l2_sensor_environmental_sensor_ic` | 4,078 | 4,361 | 0 | 8,439 |
| `dwd_l2_sensor_image_sensor` | 0 | 1,525 | 0 | 1,525 |
| `dwd_l2_sensor_inertial_mems_sensor` | 519 | 269 | 0 | 788 |
| `dwd_l2_sensor_magnetic_sensor_ic` | 4,999 | 2,924 | 0 | 7,923 |
| `dwd_l2_sensor_pressure_sensor` | 151,264 | 11,803 | 0 | 163,067 |

### logic_ic

合计 **152,785** 行（digikey 19,591 + icpdf 133,194），3 张表。

| 表名 | digikey | icpdf | ecloud | 合计 |
|------|---------|-------|--------|------|
| `dwd_l2_logic_ic_combinational_logic` | 9,789 | 51,358 | 0 | 61,147 |
| `dwd_l2_logic_ic_sequential_logic` | 7,352 | 36,506 | 0 | 43,858 |
| `dwd_l2_logic_ic_signal_buffer_driver` | 2,450 | 45,330 | 0 | 47,780 |

### relay

合计 **117,316** 行（digikey 48,175 + icpdf 41,769 + ecloud **27,372**），2 张表。
> 含 ecloud：**27,372** 行 / distinct **27,327**。

| 表名 | digikey | icpdf | ecloud | 合计 |
|------|---------|-------|--------|------|
| `dwd_l2_relay_electromechanical_relay` | 47,346 | 29,615 | 21,182 | 98,143 |
| `dwd_l2_relay_solid_state_relay` | 829 | 12,154 | 6,190 | 19,173 |

### mcu_mpu_dsp

合计 **93,320** 行（digikey 11,137 + icpdf 82,142 + other 41），3 张表。

| 表名 | digikey | icpdf | ecloud | 合计 |
|------|---------|-------|--------|------|
| `dwd_l2_mcu_mpu_dsp_dsp` | 0 | 2,400 | 0 | 2,400 |
| `dwd_l2_mcu_mpu_dsp_mcu` | 9,820 | 76,654 | 0 | 86,492 |
| `dwd_l2_mcu_mpu_dsp_mpu_soc` | 1,317 | 3,088 | 0 | 4,428 |

### system_module

合计 **88,232** 行（digikey 87,586 + icpdf 646），4 张表。

| 表名 | digikey | icpdf | ecloud | 合计 |
|------|---------|-------|--------|------|
| `dwd_l2_system_module_compute_som_module` | 4,993 | 33 | 0 | 5,026 |
| `dwd_l2_system_module_power_module` | 75,661 | 317 | 0 | 75,978 |
| `dwd_l2_system_module_wired_comm_module` | 5,869 | 296 | 0 | 6,165 |
| `dwd_l2_system_module_wireless_comm_module` | 1,063 | 0 | 0 | 1,063 |

### rf_wireless

合计 **80,587** 行（digikey 39,263 + icpdf 41,324），6 张表。

| 表名 | digikey | icpdf | ecloud | 合计 |
|------|---------|-------|--------|------|
| `dwd_l2_rf_wireless_rf_antenna` | 17,350 | 1,743 | 0 | 19,093 |
| `dwd_l2_rf_wireless_rf_frequency_synthesis` | 0 | 7,779 | 0 | 7,779 |
| `dwd_l2_rf_wireless_rf_passive_network` | 2,308 | 6,977 | 0 | 9,285 |
| `dwd_l2_rf_wireless_rf_signal_control_detection` | 11,444 | 23,017 | 0 | 34,461 |
| `dwd_l2_rf_wireless_rf_transceiver_ic` | 6,668 | 1,808 | 0 | 8,476 |
| `dwd_l2_rf_wireless_rfid_nfc_frontend` | 1,493 | 0 | 0 | 1,493 |

### filter

合计 **79,330** 行（digikey 19,534 + icpdf 59,796），4 张表。

| 表名 | digikey | icpdf | ecloud | 合计 |
|------|---------|-------|--------|------|
| `dwd_l2_filter_acoustic_resonator_filter` | 1,842 | 9,253 | 0 | 11,095 |
| `dwd_l2_filter_analog_filter` | 19 | 4,901 | 0 | 4,920 |
| `dwd_l2_filter_dielectric_cavity_filter` | 6 | 609 | 0 | 615 |
| `dwd_l2_filter_emi_suppression_filter` | 17,667 | 45,033 | 0 | 62,700 |

### amplifier

合计 **78,958** 行（digikey 6,686 + icpdf 72,272），6 张表。

| 表名 | digikey | icpdf | ecloud | 合计 |
|------|---------|-------|--------|------|
| `dwd_l2_amplifier_audio_power_amplifier` | 46 | 6,872 | 0 | 6,918 |
| `dwd_l2_amplifier_general_opamp_comparator` | 353 | 46,649 | 0 | 47,002 |
| `dwd_l2_amplifier_precision_signal_conditioning_amp` | 0 | 2,453 | 0 | 2,453 |
| `dwd_l2_amplifier_rf_if_amplifier` | 4,905 | 13,286 | 0 | 18,191 |
| `dwd_l2_amplifier_transimpedance_transconductance_log_amp` | 0 | 180 | 0 | 180 |
| `dwd_l2_amplifier_video_wideband_amp` | 1,382 | 2,832 | 0 | 4,214 |

### interface_communication_ic

合计 **55,012** 行（digikey 11,240 + icpdf 43,772），6 张表。

| 表名 | digikey | icpdf | ecloud | 合计 |
|------|---------|-------|--------|------|
| `dwd_l2_interface_communication_ic_bus_switch_mux` | 3,628 | 19,096 | 0 | 22,724 |
| `dwd_l2_interface_communication_ic_digital_isolation_interface` | 33 | 79 | 0 | 112 |
| `dwd_l2_interface_communication_ic_ethernet_interface` | 1,056 | 2,896 | 0 | 3,952 |
| `dwd_l2_interface_communication_ic_highspeed_serial_interface` | 4,284 | 1,332 | 0 | 5,616 |
| `dwd_l2_interface_communication_ic_level_shifter_signal_conditioning` | 788 | 319 | 0 | 1,107 |
| `dwd_l2_interface_communication_ic_serial_bus_transceiver` | 1,451 | 20,050 | 0 | 21,501 |

### data_converter

合计 **46,074** 行（digikey 11,103 + icpdf 34,971），2 张表。

| 表名 | digikey | icpdf | ecloud | 合计 |
|------|---------|-------|--------|------|
| `dwd_l2_data_converter_adc` | 1,794 | 16,085 | 0 | 17,879 |
| `dwd_l2_data_converter_dac` | 9,309 | 18,886 | 0 | 28,195 |

### isolator

合计 **44,597** 行（digikey 13,206 + icpdf 31,391），4 张表。

| 表名 | digikey | icpdf | ecloud | 合计 |
|------|---------|-------|--------|------|
| `dwd_l2_isolator_digital_isolator` | 6 | 1,625 | 0 | 1,631 |
| `dwd_l2_isolator_isolated_analog_amplifier` | 0 | 236 | 0 | 236 |
| `dwd_l2_isolator_optocoupler` | 13,200 | 28,780 | 0 | 41,980 |
| `dwd_l2_isolator_rf_isolator_circulator` | 0 | 750 | 0 | 750 |

### transformer

合计 **28,752** 行（digikey 9,482 + icpdf 19,270），4 张表。

| 表名 | digikey | icpdf | ecloud | 合计 |
|------|---------|-------|--------|------|
| `dwd_l2_transformer_instrument_transformer` | 1,695 | 643 | 0 | 2,338 |
| `dwd_l2_transformer_power_transformer` | 0 | 6,982 | 0 | 6,982 |
| `dwd_l2_transformer_signal_communication_transformer` | 5,809 | 9,949 | 0 | 15,758 |
| `dwd_l2_transformer_switching_drive_transformer` | 1,978 | 1,696 | 0 | 3,674 |

### driver_ic

合计 **13,710** 行（digikey 4,945 + icpdf 8,765），5 张表。

| 表名 | digikey | icpdf | ecloud | 合计 |
|------|---------|-------|--------|------|
| `dwd_l2_driver_ic_display_driver` | 0 | 3,309 | 0 | 3,309 |
| `dwd_l2_driver_ic_gate_driver` | 38 | 3,918 | 0 | 3,956 |
| `dwd_l2_driver_ic_laser_driver` | 0 | 0 | 0 | 0 |
| `dwd_l2_driver_ic_led_lighting_driver` | 4,907 | 101 | 0 | 5,008 |
| `dwd_l2_driver_ic_motor_driver` | 0 | 1,437 | 0 | 1,437 |

### fpga_cpld

合计 **10,442** 行（digikey 3,665 + icpdf 6,777），2 张表。

| 表名 | digikey | icpdf | ecloud | 合计 |
|------|---------|-------|--------|------|
| `dwd_l2_fpga_cpld_cpld` | 3,612 | 2,158 | 0 | 5,770 |
| `dwd_l2_fpga_cpld_fpga` | 53 | 4,619 | 0 | 4,672 |

### acoustic_device

合计 **9,044** 行（digikey 8,825 + icpdf 219），4 张表。

| 表名 | digikey | icpdf | ecloud | 合计 |
|------|---------|-------|--------|------|
| `dwd_l2_acoustic_device_buzzer_and_piezo_actuator` | 5,066 | 199 | 0 | 5,265 |
| `dwd_l2_acoustic_device_microphone` | 975 | 18 | 0 | 993 |
| `dwd_l2_acoustic_device_receiver` | 495 | 0 | 0 | 495 |
| `dwd_l2_acoustic_device_speaker` | 2,289 | 2 | 0 | 2,291 |

## distinct partno 覆盖率（真实清洗完成度）

| 源 | param 行数 | param distinct | L2 行数 | L2 distinct | **distinct 覆盖率** | 未覆盖 distinct |
|----|----------:|---------------:|--------:|------------:|-------------------:|----------------:|
| digikey | 7,717,330 | 7,717,330 | 5,740,792 | 5,740,791 | **74.39%** | 1,976,539 |
| icpdf | 7,019,307 | 6,779,145 | 5,094,850 | 4,198,906 | **61.94%** | 2,580,239 |
| **ecloud** | 3,559,619 | 3,532,255 | 2,491,833 | 2,408,854 | **68.20%** | 1,123,401 |

- digikey **27/27** L1 有宽表数据，distinct 覆盖约 **74%**
- icpdf **27/27** L1 有宽表数据，distinct 覆盖约 **62%**；部分品类行多 distinct 少
- **ecloud 已入 8/27 L1**（+resistor），distinct 覆盖约 **68%**（各 L1 distinct 相加）；剩余约 **1,123,401** 型号待其它 L1 合入

## 备注

- 统计脚本：`sql_scripts/test/_probe_l2_full_stats.py`（逐表 `GROUP BY data_source`）。
- 原始扫描导出：`exports/_l2_full_stats_20260717.txt`；7-20 resistor 局部刷新。
- ecloud resistor 合入：`caixj/ecloud_resistor` → classify + attr（2026-07-20）；沙盒 `test_dim/test_dwd.*_resistor` 已 DROP。
