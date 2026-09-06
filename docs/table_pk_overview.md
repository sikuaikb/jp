# StarRocks 表主键总览

> 生成时间：2026-06-16  
> 覆盖库：`dim`（规则/字典）、`dwd`（加工结果）  
> 不含备份表（`bak_*`）和已废弃临时表

## 表模型说明

| 模型 | 含义 | INSERT 行为 |
|------|------|-------------|
| PRIMARY KEY | 有唯一主键 | upsert（同主键覆盖） |
| DUPLICATE KEY | 无唯一约束 | 追加（允许重复行） |

## 一、dim 库（规则/字典表）

| 表名 | 模型 | 主键列 | 行数 | 说明 |
|------|------|--------|-----:|------|
| `dim_attr_extract_rule` | PRIMARY KEY | `(`extract_rule_id`)` | 2,225 | 属性抽取规则 |
| `dim_attr_schema` | PRIMARY KEY | `(`schema_version`, `l1_code`, `scope_level`, `scope_code`, `std_attr_code`)` | 2,460 | 属性 schema（L1/L2/L3 属性定义） |
| `dim_icpdf_pdf` | PRIMARY KEY | `(`pdf_file_id`)` | 2,507,302 | ICPDF PDF 元数据 |
| `dim_l3_classify` | PRIMARY KEY | `(`l3_id`)` | 240 | L3 分类树（全 L1 合并） |
| `dim_l3_classify_all` | PRIMARY KEY | `(`l3_id`)` | 372 | 分类树全量快照（含历史版本） |
| `dim_l3_classify_rule` | PRIMARY KEY | `(`rule_id`, `clause_group_id`, `clause_ord`)` | 1,078 | L3 分类规则（gate + classify） |
| `dim_std_brand` | PRIMARY KEY | `(`brand_id_std`)` | 2,176 | 标准化品牌字典 |
| `dim_std_component_attr` | PRIMARY KEY | `(`schema_version`, `l1_code`, `l2_code`, `std_attr_code`)` | 4,457 | 标准属性码字典 |
| `dim_unit_factor` | PRIMARY KEY | `(`target_unit`, `unit_raw`)` | 312 | 单位换算因子 |
| `v_std_brand_alias` | VIEW | `—` | 9,393 | 品牌别名视图（JOIN 用） |

## 二、dwd 库（加工结果表）

### 2.1 核心流水线表

| 表名 | 模型 | 主键列 | 行数 | 说明 |
|------|------|--------|-----:|------|
| `dwd_component_attr_std` | PRIMARY KEY | `(`data_source`, `id`, `std_attr_code`)` | 61,062,173 | 属性标准化 EAV（全 L1 汇总） |
| `dwd_component_class` | PRIMARY KEY | `(`data_source`, `id`)` | 5,049,561 | L3 分类结果（全 L1 汇总） |
| `dwd_digikey_component_param` | PRIMARY KEY | `(`id`, `partno`)` | 7,710,013 | DigiKey 原始参数宽表 |
| `dwd_icpdf_component_attr_std` | PRIMARY KEY | `(`id`, `std_attr_code`)` | 29,057,884 | ICPDF 属性 EAV（旧版） |
| `dwd_icpdf_component_class` | PRIMARY KEY | `(`id`)` | 2,421,840 | ICPDF 分类结果（旧版） |
| `dwd_icpdf_component_detail` | PRIMARY KEY | `(`id`, `dt`)` | 30,495,943 | ICPDF 元件详情 |
| `dwd_icpdf_component_param` | PRIMARY KEY | `(`id`)` | 7,019,307 | ICPDF 参数宽表 |

### 2.2 正式 L2 宽表（`PRIMARY KEY(data_source, id)`）

> 全部使用 `PRIMARY KEY(\`data_source\`, \`id\`)` + `DISTRIBUTED BY HASH(\`id\`)`，INSERT 为 upsert。

| 表名 | L1 | L2 | 行数 |
|------|----|----|-----:|
| `dwd_l2_acoustic_device_buzzer_and_piezo_actuator` | `acoustic_device` | `buzzer_and_piezo_actuator` | 5,066 |
| `dwd_l2_acoustic_device_microphone` | `acoustic_device` | `microphone` | 975 |
| `dwd_l2_acoustic_device_receiver` | `acoustic_device` | `receiver` | 495 |
| `dwd_l2_acoustic_device_speaker` | `acoustic_device` | `speaker` | 2,289 |
| `dwd_l2_amplifier_audio_power_amplifier` | `amplifier` | `audio_power_amplifier` | 46 |
| `dwd_l2_amplifier_general_opamp_comparator` | `amplifier` | `general_opamp_comparator` | 353 |
| `dwd_l2_amplifier_precision_signal_conditioning_amp` | `amplifier` | `precision_signal_conditioning_amp` | 0 |
| `dwd_l2_amplifier_rf_if_amplifier` | `amplifier` | `rf_if_amplifier` | 4,905 |
| `dwd_l2_amplifier_transimpedance_transconductance_log_amp` | `amplifier` | `transimpedance_transconductance_log_amp` | 0 |
| `dwd_l2_amplifier_video_wideband_amp` | `amplifier` | `video_wideband_amp` | 1,382 |
| `dwd_l2_capacitor_non_polar_fixed_capacitor` | `capacitor` | `non_polar_fixed_capacitor` | 1,107,137 |
| `dwd_l2_capacitor_polar_electrolytic_capacitor` | `capacitor` | `polar_electrolytic_capacitor` | 439,275 |
| `dwd_l2_capacitor_supercapacitor` | `capacitor` | `supercapacitor` | 86 |
| `dwd_l2_capacitor_variable_capacitor` | `capacitor` | `variable_capacitor` | 1,933 |
| `dwd_l2_circuit_protection_overcurrent_overtemperature_protection` | `circuit_protection` | `overcurrent_overtemperature_protection` | 63,924 |
| `dwd_l2_circuit_protection_passive_surge_diversion` | `circuit_protection` | `passive_surge_diversion` | 6 |
| `dwd_l2_circuit_protection_semiconductor_transient_suppression` | `circuit_protection` | `semiconductor_transient_suppression` | 89,357 |
| `dwd_l2_data_converter_adc` | `data_converter` | `adc` | 1,794 |
| `dwd_l2_data_converter_dac` | `data_converter` | `dac` | 9,309 |
| `dwd_l2_diode_rectifier_switching_diode` | `diode` | `rectifier_switching_diode` | 235,497 |
| `dwd_l2_diode_rf_special_diode` | `diode` | `rf_special_diode` | 23,317 |
| `dwd_l2_diode_voltage_reg_protection_diode` | `diode` | `voltage_reg_protection_diode` | 329,234 |
| `dwd_l2_driver_ic_display_driver` | `driver_ic` | `display_driver` | 0 |
| `dwd_l2_driver_ic_gate_driver` | `driver_ic` | `gate_driver` | 38 |
| `dwd_l2_driver_ic_laser_driver` | `driver_ic` | `laser_driver` | 0 |
| `dwd_l2_driver_ic_led_lighting_driver` | `driver_ic` | `led_lighting_driver` | 4,907 |
| `dwd_l2_driver_ic_motor_driver` | `driver_ic` | `motor_driver` | 0 |
| `dwd_l2_filter_acoustic_resonator_filter` | `filter` | `acoustic_resonator_filter` | 1,842 |
| `dwd_l2_filter_analog_filter` | `filter` | `analog_filter` | 19 |
| `dwd_l2_filter_dielectric_cavity_filter` | `filter` | `dielectric_cavity_filter` | 6 |
| `dwd_l2_filter_emi_suppression_filter` | `filter` | `emi_suppression_filter` | 33,632 |
| `dwd_l2_inductor_emi_filter_inductor` | `inductor` | `emi_filter_inductor` | 18,524 |
| `dwd_l2_inductor_hf_chip_inductor` | `inductor` | `hf_chip_inductor` | 23,216 |
| `dwd_l2_inductor_power_inductor` | `inductor` | `power_inductor` | 110,427 |
| `dwd_l2_mcu_mpu_dsp_dsp` | `mcu_mpu_dsp` | `dsp` | 2,400 |
| `dwd_l2_mcu_mpu_dsp_mcu` | `mcu_mpu_dsp` | `mcu` | 76,683 |
| `dwd_l2_mcu_mpu_dsp_mpu_soc` | `mcu_mpu_dsp` | `mpu_soc` | 4,405 |
| `dwd_l2_pmic_battery_management` | `pmic` | `battery_management` | 3,797 |
| `dwd_l2_pmic_linear_regulator_reference` | `pmic` | `linear_regulator_reference` | 128,309 |
| `dwd_l2_pmic_power_distribution_switch` | `pmic` | `power_distribution_switch` | 3,522 |
| `dwd_l2_pmic_power_supervisor` | `pmic` | `power_supervisor` | 23,669 |
| `dwd_l2_pmic_protocol_power_controller` | `pmic` | `protocol_power_controller` | 0 |
| `dwd_l2_pmic_switching_controller` | `pmic` | `switching_controller` | 19,846 |
| `dwd_l2_pmic_switching_dcdc_converter` | `pmic` | `switching_dcdc_converter` | 366,718 |
| `dwd_l2_pmic_system_pmic` | `pmic` | `system_pmic` | 1,007 |
| `dwd_l2_relay_electromechanical_relay` | `relay` | `electromechanical_relay` | 76,961 |
| `dwd_l2_relay_solid_state_relay` | `relay` | `solid_state_relay` | 12,997 |
| `dwd_l2_resistor_fixed_resistor` | `resistor` | `fixed_resistor` | 612,406 |
| `dwd_l2_resistor_protective_sensitive_resistor` | `resistor` | `protective_sensitive_resistor` | 60,522 |
| `dwd_l2_resistor_variable_resistor` | `resistor` | `variable_resistor` | 692,088 |
| `dwd_l2_sensor_current_sensor_ic` | `sensor` | `current_sensor_ic` | 5,077 |
| `dwd_l2_sensor_environmental_sensor_ic` | `sensor` | `environmental_sensor_ic` | 4,078 |
| `dwd_l2_sensor_image_sensor` | `sensor` | `image_sensor` | 0 |
| `dwd_l2_sensor_inertial_mems_sensor` | `sensor` | `inertial_mems_sensor` | 519 |
| `dwd_l2_sensor_magnetic_sensor_ic` | `sensor` | `magnetic_sensor_ic` | 4,999 |
| `dwd_l2_sensor_pressure_sensor` | `sensor` | `pressure_sensor` | 10,958 |
| `dwd_l2_switch_magnetic_sensing_switch` | `switch` | `magnetic_sensing_switch` | 2,121 |
| `dwd_l2_switch_mechanical_actuated_switch` | `switch` | `mechanical_actuated_switch` | 120,303 |
| `dwd_l2_switch_mechanical_sensing_switch` | `switch` | `mechanical_sensing_switch` | 17,107 |
| `dwd_l2_transformer_signal_communication_transformer` | `transformer` | `signal_communication_transformer` | 5,809 |
| `dwd_l2_transformer_switching_drive_transformer` | `transformer` | `switching_drive_transformer` | 1,978 |
| `dwd_l2_transistor_bipolar_transistor` | `transistor` | `bipolar_transistor` | 118,610 |
| `dwd_l2_transistor_fet` | `transistor` | `fet` | 92,235 |
| `dwd_l2_transistor_igbt` | `transistor` | `igbt` | 16,752 |
| `dwd_l2_transistor_thyristor` | `transistor` | `thyristor` | 67,804 |

### 2.3 LLM 补全表（`DUPLICATE KEY`，无唯一主键）

> 用于存储 LLM 批量推理结果，以 `run_id` 区分批次，支持多批次历史保留。  
> **分桶键**：`(run_id, source_row_num)`，当前数据无重复行，可按需改为 PRIMARY KEY。

| 表名 | 类型 | 行数 | run_id 种数 |
|------|------|-----:|----------:|
| `dwd_l2_fixed_resistor_llm_completion` | `fixed` | `resistor_llm_completion` | 2 |
| `dwd_l2_fixed_resistor_llm_completion_audit` | `fixed` | `resistor_llm_completion_audit` | 5 |
| `dwd_l2_fixed_resistor_llm_completion_result` | `fixed` | `resistor_llm_completion_result` | 5 |
| `dwd_l2_non_polar_fixed_capacitor_audit` | `non` | `polar_fixed_capacitor_audit` | 1 |
| `dwd_l2_non_polar_fixed_capacitor_llm_completion_result` | `non` | `polar_fixed_capacitor_llm_completion_result` | 1 |
| `dwd_l2_polar_electrolytic_capacitor_audit` | `polar` | `electrolytic_capacitor_audit` | 1 |
| `dwd_l2_polar_electrolytic_capacitor_llm_completion_result` | `polar` | `electrolytic_capacitor_llm_completion_result` | 1 |
| `dwd_l2_protective_sensitive_resistor_llm_completion_audit` | `protective` | `sensitive_resistor_llm_completion_audit` | 1 |
| `dwd_l2_protective_sensitive_resistor_llm_completion_result` | `protective` | `sensitive_resistor_llm_completion_result` | 1 |
| `dwd_l2_rectifier_switching_diode_llm_completion_audit` | `rectifier` | `switching_diode_llm_completion_audit` | 1 |
| `dwd_l2_rectifier_switching_diode_llm_completion_result` | `rectifier` | `switching_diode_llm_completion_result` | 1 |
| `dwd_l2_rf_special_diode_llm_completion_audit` | `rf` | `special_diode_llm_completion_audit` | 1 |
| `dwd_l2_rf_special_diode_llm_completion_result` | `rf` | `special_diode_llm_completion_result` | 1 |
| `dwd_l2_supercapacitor_llm_completion_audit` | `supercapacitor` | `llm_completion_audit` | 1 |
| `dwd_l2_supercapacitor_llm_completion_result` | `supercapacitor` | `llm_completion_result` | 1 |
| `dwd_l2_variable_capacitor_llm_completion_audit` | `variable` | `capacitor_llm_completion_audit` | 1 |
| `dwd_l2_variable_capacitor_llm_completion_result` | `variable` | `capacitor_llm_completion_result` | 1 |
| `dwd_l2_variable_resistor_llm_completion_audit` | `variable` | `resistor_llm_completion_audit` | 1 |
| `dwd_l2_variable_resistor_llm_completion_result` | `variable` | `resistor_llm_completion_result` | 1 |
| `dwd_l2_voltage_reg_protection_diode_llm_completion_audit` | `voltage` | `reg_protection_diode_llm_completion_audit` | 1 |
| `dwd_l2_voltage_reg_protection_diode_llm_completion_result` | `voltage` | `reg_protection_diode_llm_completion_result` | 1 |

### 2.4 其他表

| 表名 | 模型 | 主键列 | 行数 | 说明 |
|------|------|--------|-----:|------|

---

## 三、备份表（`bak_*`）

> 合并操作时自动创建，命名规则：`bak_<原表名>_<L1>_<YYYYMMDDHHMM>`。
> 可按需清理，清理前确认对应 L1 在 prod 已验证正确。

| 表名 | 行数 |
|------|-----:|
| `dim.bak_dim_attr_extract_rule_20260611` | 1,823 |
| `dim.bak_dim_attr_extract_rule_acoustic_device_20260612` | 0 |
| `dim.bak_dim_attr_extract_rule_amplifier_202506160945` | 0 |
| `dim.bak_dim_attr_extract_rule_capacitor_dkcap_20260604` | 108 |
| `dim.bak_dim_attr_extract_rule_data_converter_202606121620` | 55 |
| `dim.bak_dim_attr_extract_rule_diode_20260612` | 258 |
| `dim.bak_dim_attr_extract_rule_driver_ic_202606121527` | 0 |
| `dim.bak_dim_attr_extract_rule_inductor_202606121105` | 53 |
| `dim.bak_dim_attr_extract_rule_mcu_mpu_dsp_202606101526` | 144 |
| `dim.bak_dim_attr_extract_rule_pmic_202606110937` | 63 |
| `dim.bak_dim_attr_extract_rule_sensor_202506151220` | 0 |
| `dim.bak_dim_attr_extract_rule_transistor_202606121823` | 115 |
| `dim.bak_dim_attr_extract_rule_transistor_202606121900` | 122 |
| `dim.bak_dim_attr_schema_20260611` | 1,614 |
| `dim.bak_dim_attr_schema_acoustic_device_20260612` | 0 |
| `dim.bak_dim_attr_schema_amplifier_202506160945` | 0 |
| `dim.bak_dim_attr_schema_capacitor_dkcap_20260604` | 79 |
| `dim.bak_dim_attr_schema_data_converter_202606121620` | 54 |
| `dim.bak_dim_attr_schema_diode_20260612` | 120 |
| `dim.bak_dim_attr_schema_driver_ic_202606121527` | 0 |
| `dim.bak_dim_attr_schema_inductor_202606121105` | 113 |
| `dim.bak_dim_attr_schema_mcu_mpu_dsp_202606101526` | 124 |
| `dim.bak_dim_attr_schema_pmic_202606110937` | 251 |
| `dim.bak_dim_attr_schema_sensor_202506151220` | 0 |
| `dim.bak_dim_attr_schema_transistor_202606121823` | 170 |
| `dim.bak_dim_attr_schema_transistor_202606121900` | 170 |
| `dim.bak_dim_l3_classify_acoustic_device_20260612` | 0 |
| `dim.bak_dim_l3_classify_amplifier_202506151700` | 0 |
| `dim.bak_dim_l3_classify_capacitor_dkcap_20260603` | 8 |
| `dim.bak_dim_l3_classify_circuit_protection_202606111616` | 4 |
| `dim.bak_dim_l3_classify_data_converter_202606121609` | 12 |
| `dim.bak_dim_l3_classify_diode_20260612b` | 13 |
| `dim.bak_dim_l3_classify_diode_20260612shs` | 16 |
| `dim.bak_dim_l3_classify_driver_ic_202606121501` | 0 |
| `dim.bak_dim_l3_classify_inductor_202606120938` | 13 |
| `dim.bak_dim_l3_classify_mcu_mpu_dsp_202606101446` | 12 |
| `dim.bak_dim_l3_classify_pmic_202606101740` | 18 |
| `dim.bak_dim_l3_classify_rule_acoustic_device_20260612` | 0 |
| `dim.bak_dim_l3_classify_rule_amplifier_202506151700` | 0 |
| `dim.bak_dim_l3_classify_rule_capacitor_dkcap_20260603` | 42 |
| `dim.bak_dim_l3_classify_rule_circuit_protection_202606111616` | 5 |
| `dim.bak_dim_l3_classify_rule_data_converter_202606121609` | 79 |
| `dim.bak_dim_l3_classify_rule_diode_20260612b` | 84 |
| `dim.bak_dim_l3_classify_rule_diode_20260612shs` | 45 |
| `dim.bak_dim_l3_classify_rule_driver_ic_202606121501` | 0 |
| `dim.bak_dim_l3_classify_rule_inductor_202606120938` | 56 |
| `dim.bak_dim_l3_classify_rule_mcu_mpu_dsp_202606101445` | 49 |
| `dim.bak_dim_l3_classify_rule_pmic_202606101740` | 48 |
| `dim.bak_dim_l3_classify_rule_sensor_202606151134` | 0 |
| `dim.bak_dim_l3_classify_rule_transistor_202606121811` | 104 |
| `dim.bak_dim_l3_classify_rule_transistor_202606121812` | 127 |
| `dim.bak_dim_l3_classify_sensor_202606151134` | 0 |
| `dim.bak_dim_l3_classify_transistor_202606121811` | 25 |
| `dim.bak_dim_l3_classify_transistor_202606121812` | 25 |

## 四、使用建议

| 场景 | 建议 |
|------|------|
| JOIN 正式宽表 | 放心 JOIN，PRIMARY KEY 保证一行一器件 |
| 重跑 ETL 脚本 | PRIMARY KEY 表 INSERT 是幂等 upsert，可重复执行 |
| 查询 LLM result 表 | 需加 `WHERE run_id = '<最新批次>'`，否则会返回所有批次数据 |
| 清理 LLM result 历史 | `DELETE FROM dwd.xxx WHERE run_id <> '<保留批次>'` |
| 新 L1 合并 | 参考 `.cursor/skills/dim-l3-classify-merge` / `dim-attr-std-merge` |