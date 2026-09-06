-- ADS 元器件选型域：按 L2 拆分，每日全量刷新。
-- 仅创建/覆盖 ads.ads_sel_<l2_code>_df，不修改源表或其他 schema。

-- acoustic_resonator_filter
CREATE TABLE IF NOT EXISTS ads.ads_sel_acoustic_resonator_filter_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_acoustic_resonator_filter_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'acoustic_resonator_filter';

-- adc
CREATE TABLE IF NOT EXISTS ads.ads_sel_adc_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_adc_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'adc';

-- analog_filter
CREATE TABLE IF NOT EXISTS ads.ads_sel_analog_filter_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_analog_filter_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'analog_filter';

-- audio_power_amplifier
CREATE TABLE IF NOT EXISTS ads.ads_sel_audio_power_amplifier_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_audio_power_amplifier_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'audio_power_amplifier';

-- backplane_ic_socket_connector
CREATE TABLE IF NOT EXISTS ads.ads_sel_backplane_ic_socket_connector_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_backplane_ic_socket_connector_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'backplane_ic_socket_connector';

-- battery_management
CREATE TABLE IF NOT EXISTS ads.ads_sel_battery_management_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_battery_management_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'battery_management';

-- bipolar_transistor
CREATE TABLE IF NOT EXISTS ads.ads_sel_bipolar_transistor_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_bipolar_transistor_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'bipolar_transistor';

-- board_wire_interconnect_connector
CREATE TABLE IF NOT EXISTS ads.ads_sel_board_wire_interconnect_connector_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_board_wire_interconnect_connector_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'board_wire_interconnect_connector';

-- bus_switch_mux
CREATE TABLE IF NOT EXISTS ads.ads_sel_bus_switch_mux_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_bus_switch_mux_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'bus_switch_mux';

-- buzzer_and_piezo_actuator
CREATE TABLE IF NOT EXISTS ads.ads_sel_buzzer_and_piezo_actuator_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_buzzer_and_piezo_actuator_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'buzzer_and_piezo_actuator';

-- clock_management_ic
CREATE TABLE IF NOT EXISTS ads.ads_sel_clock_management_ic_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_clock_management_ic_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'clock_management_ic';

-- combinational_logic
CREATE TABLE IF NOT EXISTS ads.ads_sel_combinational_logic_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_combinational_logic_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'combinational_logic';

-- compute_som_module
CREATE TABLE IF NOT EXISTS ads.ads_sel_compute_som_module_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_compute_som_module_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'compute_som_module';

-- cpld
CREATE TABLE IF NOT EXISTS ads.ads_sel_cpld_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_cpld_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'cpld';

-- current_sensor_ic
CREATE TABLE IF NOT EXISTS ads.ads_sel_current_sensor_ic_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_current_sensor_ic_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'current_sensor_ic';

-- dac
CREATE TABLE IF NOT EXISTS ads.ads_sel_dac_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_dac_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'dac';

-- delay_timing_adjustment
CREATE TABLE IF NOT EXISTS ads.ads_sel_delay_timing_adjustment_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_delay_timing_adjustment_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'delay_timing_adjustment';

-- dielectric_cavity_filter
CREATE TABLE IF NOT EXISTS ads.ads_sel_dielectric_cavity_filter_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_dielectric_cavity_filter_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'dielectric_cavity_filter';

-- digital_isolation_interface
CREATE TABLE IF NOT EXISTS ads.ads_sel_digital_isolation_interface_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_digital_isolation_interface_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'digital_isolation_interface';

-- digital_isolator
CREATE TABLE IF NOT EXISTS ads.ads_sel_digital_isolator_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_digital_isolator_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'digital_isolator';

-- display_driver
CREATE TABLE IF NOT EXISTS ads.ads_sel_display_driver_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_display_driver_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'display_driver';

-- dsp
CREATE TABLE IF NOT EXISTS ads.ads_sel_dsp_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_dsp_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'dsp';

-- electromechanical_relay
CREATE TABLE IF NOT EXISTS ads.ads_sel_electromechanical_relay_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_electromechanical_relay_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'electromechanical_relay';

-- emi_filter_inductor
CREATE TABLE IF NOT EXISTS ads.ads_sel_emi_filter_inductor_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_emi_filter_inductor_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'emi_filter_inductor';

-- emi_suppression_filter
CREATE TABLE IF NOT EXISTS ads.ads_sel_emi_suppression_filter_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_emi_suppression_filter_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'emi_suppression_filter';

-- environmental_sensor_ic
CREATE TABLE IF NOT EXISTS ads.ads_sel_environmental_sensor_ic_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_environmental_sensor_ic_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'environmental_sensor_ic';

-- ethernet_interface
CREATE TABLE IF NOT EXISTS ads.ads_sel_ethernet_interface_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_ethernet_interface_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'ethernet_interface';

-- fet
CREATE TABLE IF NOT EXISTS ads.ads_sel_fet_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_fet_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'fet';

-- fixed_resistor
CREATE TABLE IF NOT EXISTS ads.ads_sel_fixed_resistor_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_fixed_resistor_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'fixed_resistor';

-- flash_memory
CREATE TABLE IF NOT EXISTS ads.ads_sel_flash_memory_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_flash_memory_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'flash_memory';

-- fpga
CREATE TABLE IF NOT EXISTS ads.ads_sel_fpga_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_fpga_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'fpga';

-- gate_driver
CREATE TABLE IF NOT EXISTS ads.ads_sel_gate_driver_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_gate_driver_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'gate_driver';

-- general_opamp_comparator
CREATE TABLE IF NOT EXISTS ads.ads_sel_general_opamp_comparator_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_general_opamp_comparator_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'general_opamp_comparator';

-- general_shell_connector
CREATE TABLE IF NOT EXISTS ads.ads_sel_general_shell_connector_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_general_shell_connector_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'general_shell_connector';

-- hf_chip_inductor
CREATE TABLE IF NOT EXISTS ads.ads_sel_hf_chip_inductor_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_hf_chip_inductor_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'hf_chip_inductor';

-- highspeed_serial_interface
CREATE TABLE IF NOT EXISTS ads.ads_sel_highspeed_serial_interface_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_highspeed_serial_interface_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'highspeed_serial_interface';

-- igbt
CREATE TABLE IF NOT EXISTS ads.ads_sel_igbt_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_igbt_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'igbt';

-- image_sensor
CREATE TABLE IF NOT EXISTS ads.ads_sel_image_sensor_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_image_sensor_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'image_sensor';

-- inertial_mems_sensor
CREATE TABLE IF NOT EXISTS ads.ads_sel_inertial_mems_sensor_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_inertial_mems_sensor_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'inertial_mems_sensor';

-- instrument_transformer
CREATE TABLE IF NOT EXISTS ads.ads_sel_instrument_transformer_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_instrument_transformer_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'instrument_transformer';

-- isolated_analog_amplifier
CREATE TABLE IF NOT EXISTS ads.ads_sel_isolated_analog_amplifier_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_isolated_analog_amplifier_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'isolated_analog_amplifier';

-- laser_driver
CREATE TABLE IF NOT EXISTS ads.ads_sel_laser_driver_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_laser_driver_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'laser_driver';

-- led_lighting_driver
CREATE TABLE IF NOT EXISTS ads.ads_sel_led_lighting_driver_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_led_lighting_driver_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'led_lighting_driver';

-- level_shifter_signal_conditioning
CREATE TABLE IF NOT EXISTS ads.ads_sel_level_shifter_signal_conditioning_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_level_shifter_signal_conditioning_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'level_shifter_signal_conditioning';

-- light_emitter
CREATE TABLE IF NOT EXISTS ads.ads_sel_light_emitter_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_light_emitter_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'light_emitter';

-- linear_regulator_reference
CREATE TABLE IF NOT EXISTS ads.ads_sel_linear_regulator_reference_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_linear_regulator_reference_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'linear_regulator_reference';

-- magnetic_sensing_switch
CREATE TABLE IF NOT EXISTS ads.ads_sel_magnetic_sensing_switch_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_magnetic_sensing_switch_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'magnetic_sensing_switch';

-- magnetic_sensor_ic
CREATE TABLE IF NOT EXISTS ads.ads_sel_magnetic_sensor_ic_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_magnetic_sensor_ic_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'magnetic_sensor_ic';

-- managed_flash_module
CREATE TABLE IF NOT EXISTS ads.ads_sel_managed_flash_module_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_managed_flash_module_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'managed_flash_module';

-- mcu
CREATE TABLE IF NOT EXISTS ads.ads_sel_mcu_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_mcu_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'mcu';

-- mechanical_actuated_switch
CREATE TABLE IF NOT EXISTS ads.ads_sel_mechanical_actuated_switch_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_mechanical_actuated_switch_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'mechanical_actuated_switch';

-- mechanical_sensing_switch
CREATE TABLE IF NOT EXISTS ads.ads_sel_mechanical_sensing_switch_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_mechanical_sensing_switch_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'mechanical_sensing_switch';

-- memory_controller
CREATE TABLE IF NOT EXISTS ads.ads_sel_memory_controller_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_memory_controller_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'memory_controller';

-- microphone
CREATE TABLE IF NOT EXISTS ads.ads_sel_microphone_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_microphone_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'microphone';

-- motor_driver
CREATE TABLE IF NOT EXISTS ads.ads_sel_motor_driver_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_motor_driver_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'motor_driver';

-- mpu_soc
CREATE TABLE IF NOT EXISTS ads.ads_sel_mpu_soc_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_mpu_soc_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'mpu_soc';

-- non_polar_fixed_capacitor
CREATE TABLE IF NOT EXISTS ads.ads_sel_non_polar_fixed_capacitor_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_non_polar_fixed_capacitor_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'non_polar_fixed_capacitor';

-- nv_ram
CREATE TABLE IF NOT EXISTS ads.ads_sel_nv_ram_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_nv_ram_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'nv_ram';

-- optocoupler
CREATE TABLE IF NOT EXISTS ads.ads_sel_optocoupler_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_optocoupler_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'optocoupler';

-- oscillator
CREATE TABLE IF NOT EXISTS ads.ads_sel_oscillator_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_oscillator_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'oscillator';

-- overcurrent_overtemperature_protection
CREATE TABLE IF NOT EXISTS ads.ads_sel_overcurrent_overtemperature_protection_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_overcurrent_overtemperature_protection_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'overcurrent_overtemperature_protection';

-- passive_surge_diversion
CREATE TABLE IF NOT EXISTS ads.ads_sel_passive_surge_diversion_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_passive_surge_diversion_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'passive_surge_diversion';

-- photodetector
CREATE TABLE IF NOT EXISTS ads.ads_sel_photodetector_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_photodetector_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'photodetector';

-- polar_electrolytic_capacitor
CREATE TABLE IF NOT EXISTS ads.ads_sel_polar_electrolytic_capacitor_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_polar_electrolytic_capacitor_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'polar_electrolytic_capacitor';

-- position_sensor
CREATE TABLE IF NOT EXISTS ads.ads_sel_position_sensor_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_position_sensor_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'position_sensor';

-- power_distribution_switch
CREATE TABLE IF NOT EXISTS ads.ads_sel_power_distribution_switch_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_power_distribution_switch_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'power_distribution_switch';

-- power_inductor
CREATE TABLE IF NOT EXISTS ads.ads_sel_power_inductor_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_power_inductor_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'power_inductor';

-- power_module
CREATE TABLE IF NOT EXISTS ads.ads_sel_power_module_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_power_module_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'power_module';

-- power_supervisor
CREATE TABLE IF NOT EXISTS ads.ads_sel_power_supervisor_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_power_supervisor_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'power_supervisor';

-- power_terminal_connector
CREATE TABLE IF NOT EXISTS ads.ads_sel_power_terminal_connector_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_power_terminal_connector_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'power_terminal_connector';

-- power_transformer
CREATE TABLE IF NOT EXISTS ads.ads_sel_power_transformer_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_power_transformer_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'power_transformer';

-- precision_signal_conditioning_amp
CREATE TABLE IF NOT EXISTS ads.ads_sel_precision_signal_conditioning_amp_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_precision_signal_conditioning_amp_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'precision_signal_conditioning_amp';

-- pressure_sensor
CREATE TABLE IF NOT EXISTS ads.ads_sel_pressure_sensor_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_pressure_sensor_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'pressure_sensor';

-- protective_sensitive_resistor
CREATE TABLE IF NOT EXISTS ads.ads_sel_protective_sensitive_resistor_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_protective_sensitive_resistor_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'protective_sensitive_resistor';

-- receiver
CREATE TABLE IF NOT EXISTS ads.ads_sel_receiver_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_receiver_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'receiver';

-- rectifier_switching_diode
CREATE TABLE IF NOT EXISTS ads.ads_sel_rectifier_switching_diode_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_rectifier_switching_diode_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'rectifier_switching_diode';

-- resonator
CREATE TABLE IF NOT EXISTS ads.ads_sel_resonator_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_resonator_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'resonator';

-- rewritable_rom
CREATE TABLE IF NOT EXISTS ads.ads_sel_rewritable_rom_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_rewritable_rom_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'rewritable_rom';

-- rf_antenna
CREATE TABLE IF NOT EXISTS ads.ads_sel_rf_antenna_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_rf_antenna_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'rf_antenna';

-- rf_coaxial_connector
CREATE TABLE IF NOT EXISTS ads.ads_sel_rf_coaxial_connector_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_rf_coaxial_connector_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'rf_coaxial_connector';

-- rf_frequency_synthesis
CREATE TABLE IF NOT EXISTS ads.ads_sel_rf_frequency_synthesis_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_rf_frequency_synthesis_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'rf_frequency_synthesis';

-- rf_if_amplifier
CREATE TABLE IF NOT EXISTS ads.ads_sel_rf_if_amplifier_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_rf_if_amplifier_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'rf_if_amplifier';

-- rf_passive_network
CREATE TABLE IF NOT EXISTS ads.ads_sel_rf_passive_network_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_rf_passive_network_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'rf_passive_network';

-- rf_signal_control_detection
CREATE TABLE IF NOT EXISTS ads.ads_sel_rf_signal_control_detection_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_rf_signal_control_detection_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'rf_signal_control_detection';

-- rf_special_diode
CREATE TABLE IF NOT EXISTS ads.ads_sel_rf_special_diode_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_rf_special_diode_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'rf_special_diode';

-- rf_transceiver_ic
CREATE TABLE IF NOT EXISTS ads.ads_sel_rf_transceiver_ic_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_rf_transceiver_ic_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'rf_transceiver_ic';

-- rfid_nfc_frontend
CREATE TABLE IF NOT EXISTS ads.ads_sel_rfid_nfc_frontend_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_rfid_nfc_frontend_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'rfid_nfc_frontend';

-- semiconductor_transient_suppression
CREATE TABLE IF NOT EXISTS ads.ads_sel_semiconductor_transient_suppression_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_semiconductor_transient_suppression_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'semiconductor_transient_suppression';

-- sequential_logic
CREATE TABLE IF NOT EXISTS ads.ads_sel_sequential_logic_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_sequential_logic_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'sequential_logic';

-- serial_bus_transceiver
CREATE TABLE IF NOT EXISTS ads.ads_sel_serial_bus_transceiver_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_serial_bus_transceiver_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'serial_bus_transceiver';

-- signal_buffer_driver
CREATE TABLE IF NOT EXISTS ads.ads_sel_signal_buffer_driver_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_signal_buffer_driver_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'signal_buffer_driver';

-- signal_communication_transformer
CREATE TABLE IF NOT EXISTS ads.ads_sel_signal_communication_transformer_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_signal_communication_transformer_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'signal_communication_transformer';

-- solid_state_relay
CREATE TABLE IF NOT EXISTS ads.ads_sel_solid_state_relay_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_solid_state_relay_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'solid_state_relay';

-- speaker
CREATE TABLE IF NOT EXISTS ads.ads_sel_speaker_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_speaker_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'speaker';

-- specialty_sensor_ic
CREATE TABLE IF NOT EXISTS ads.ads_sel_specialty_sensor_ic_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_specialty_sensor_ic_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'specialty_sensor_ic';

-- standard_interface_socket_connector
CREATE TABLE IF NOT EXISTS ads.ads_sel_standard_interface_socket_connector_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_standard_interface_socket_connector_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'standard_interface_socket_connector';

-- supercapacitor
CREATE TABLE IF NOT EXISTS ads.ads_sel_supercapacitor_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_supercapacitor_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'supercapacitor';

-- surge_protection_module
CREATE TABLE IF NOT EXISTS ads.ads_sel_surge_protection_module_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_surge_protection_module_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'surge_protection_module';

-- switching_controller
CREATE TABLE IF NOT EXISTS ads.ads_sel_switching_controller_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_switching_controller_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'switching_controller';

-- switching_dcdc_converter
CREATE TABLE IF NOT EXISTS ads.ads_sel_switching_dcdc_converter_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_switching_dcdc_converter_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'switching_dcdc_converter';

-- switching_drive_transformer
CREATE TABLE IF NOT EXISTS ads.ads_sel_switching_drive_transformer_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_switching_drive_transformer_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'switching_drive_transformer';

-- system_pmic
CREATE TABLE IF NOT EXISTS ads.ads_sel_system_pmic_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_system_pmic_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'system_pmic';

-- thyristor
CREATE TABLE IF NOT EXISTS ads.ads_sel_thyristor_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_thyristor_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'thyristor';

-- timekeeping_timing_ic
CREATE TABLE IF NOT EXISTS ads.ads_sel_timekeeping_timing_ic_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_timekeeping_timing_ic_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'timekeeping_timing_ic';

-- transimpedance_transconductance_log_amp
CREATE TABLE IF NOT EXISTS ads.ads_sel_transimpedance_transconductance_log_amp_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_transimpedance_transconductance_log_amp_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'transimpedance_transconductance_log_amp';

-- variable_capacitor
CREATE TABLE IF NOT EXISTS ads.ads_sel_variable_capacitor_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_variable_capacitor_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'variable_capacitor';

-- variable_resistor
CREATE TABLE IF NOT EXISTS ads.ads_sel_variable_resistor_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_variable_resistor_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'variable_resistor';

-- video_wideband_amp
CREATE TABLE IF NOT EXISTS ads.ads_sel_video_wideband_amp_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_video_wideband_amp_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'video_wideband_amp';

-- voltage_reg_protection_diode
CREATE TABLE IF NOT EXISTS ads.ads_sel_voltage_reg_protection_diode_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_voltage_reg_protection_diode_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'voltage_reg_protection_diode';

-- wired_comm_module
CREATE TABLE IF NOT EXISTS ads.ads_sel_wired_comm_module_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_wired_comm_module_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'wired_comm_module';

-- wireless_comm_module
CREATE TABLE IF NOT EXISTS ads.ads_sel_wireless_comm_module_df
LIKE dws.dws_component_fused;

INSERT OVERWRITE ads.ads_sel_wireless_comm_module_df
SELECT *
FROM dws.dws_component_fused
WHERE l2_code = 'wireless_comm_module';
