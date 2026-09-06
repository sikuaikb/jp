#!/usr/bin/env bash
# 【属性标准化·多源版】统一 dim → EAV dwd_component_attr_std → L2 宽表
#
# 流程：
#   1) [可选] DDL 重建 dwd.dwd_component_attr_std（首次 / 字段变更时由 INIT_EAV_DDL=1 触发）
#   2) build_dwd_component_attr_std_icpdf.sql / _digikey.sql / _ecloud.sql （写同一表，按 data_source 删插）
#   3) 各 L2 DDL + build SQL （多 L1 多 L2，从通用 EAV + class 表 + 各源 param 表 UNION）
#
# 用法：
#   bash run_attr_std.sh test                                      # 默认 RES_ONLY=1 仅跑 3 张电阻 L2
#   ALLOW_PROD=1 bash run_attr_std.sh prod                         # 写 prod
#   SOURCES="icpdf digikey" L1_LIST="resistor capacitor diode" \
#       INIT_EAV_DDL=1 bash run_attr_std.sh test                   # 全量重建
#   AUTO_REFRESH_CATALOG=0 ALLOW_PROD=1 bash run_attr_std.sh prod  # 跳过 catalog 刷新
#
# 依赖：仓库 sql_scripts/local.env（MYSQL_*）；外层 shell 已 export MYSQL_*。
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=/dev/null
[[ -f "$ROOT/local.env" ]] && set -a && source "$ROOT/local.env" && set +a

ENV_NAME="${1:-prod}"
case "$ENV_NAME" in
  test) DIM_DB="test_dim"; DWD_DB="test_dwd" ;;
  prod)
    if [[ "${ALLOW_PROD:-0}" != "1" ]]; then
      echo "需要 ALLOW_PROD=1 才能写 prod。" >&2
      exit 1
    fi
    DIM_DB="dim"; DWD_DB="dwd" ;;
  *) echo "usage: $0 test|prod" >&2; exit 2 ;;
esac

if [[ -z "${MYSQL_PASSWORD:-}" ]]; then
  echo "请设置 MYSQL_PASSWORD 或创建 $ROOT/local.env。" >&2
  exit 1
fi

HOST="${MYSQL_HOST:-192.168.19.21}"
PORT="${MYSQL_PORT:-9030}"
USER="${MYSQL_USER:-root}"
MYSQL_CMD=(mysql -h "$HOST" -P "$PORT" -u "$USER" "-p${MYSQL_PASSWORD}" --default-character-set=utf8mb4)

SOURCES="${SOURCES:-icpdf digikey}"
INIT_EAV_DDL="${INIT_EAV_DDL:-0}"
RES_ONLY="${RES_ONLY:-1}"
if [[ -z "${L1_LIST:-}" ]]; then
  if [[ "$RES_ONLY" == "1" ]]; then L1_LIST="resistor"; else L1_LIST="resistor capacitor diode"; fi
fi

# l1 → 脚本目录（带 dim_l3_classify_all 的 L1 编号前缀；_ready = 属性规则已梳理）
l1_dir() {
  case "$1" in
    pmic)        echo "01_pmic_ready" ;;
    diode)       echo "05_diode_ready" ;;
    transistor)  echo "09_transistor_ready" ;;
    capacitor)   echo "10_capacitor_ready" ;;
    resistor)    echo "11_resistor_ready" ;;
    inductor)    echo "12_inductor_ready" ;;
    filter)      echo "13_filter_ready" ;;
    relay)       echo "14_relay_ready" ;;
    switch)      echo "15_switch_ready" ;;
    mcu_mpu_dsp) echo "19_mcu_mpu_dsp_ready" ;;
    transformer) echo "06_transformer_ready" ;;
    data_converter) echo "21_data_converter_ready" ;;
    circuit_protection) echo "16_circuit_protection_ready" ;;
    driver_ic)   echo "27_driver_ic_ready" ;;
    acoustic_device) echo "17_acoustic_device_ready" ;;
    sensor)      echo "24_sensor_ready" ;;
    amplifier)   echo "02_amplifier_ready" ;;
    isolator)    echo "04_isolator_ready" ;;
    logic_ic)    echo "22_logic_ic_ready" ;;
    fpga_cpld)   echo "25_fpga_cpld_ready" ;;
    rf_wireless) echo "07_rf_wireless_ready" ;;
    storage)     echo "20_storage_ready" ;;
    clock_timing) echo "23_clock_timing_ready" ;;
    optoelectronics) echo "26_optoelectronics_ready" ;;
    system_module) echo "18_system_module_ready" ;;
    connector)   echo "08_connector_ready" ;;
    interface_communication_ic) echo "03_interface_communication_ic_ready" ;;
    *) echo "$1" ;;
  esac
}

# l1 → 该 l1 的 l2 列表（即 dwd_l2_{l1}_{l2}.sql 后缀）
l2_files_for_l1() {
  local l1="$1"
  case "$l1" in
    resistor)
      echo "resistor_fixed_resistor resistor_variable_resistor resistor_protective_sensitive_resistor" ;;
    capacitor)
      echo "capacitor_non_polar_fixed_capacitor capacitor_polar_electrolytic_capacitor capacitor_supercapacitor capacitor_variable_capacitor" ;;
    diode)
      echo "diode_rectifier_switching_diode diode_voltage_reg_protection_diode diode_rf_special_diode" ;;
    transistor)
      echo "transistor_bipolar_transistor transistor_fet transistor_igbt transistor_thyristor" ;;
    inductor)
      echo "inductor_power_inductor inductor_hf_chip_inductor inductor_emi_filter_inductor" ;;
    filter)
      echo "filter_acoustic_resonator_filter filter_analog_filter filter_emi_suppression_filter filter_dielectric_cavity_filter" ;;
    relay)
      echo "relay_electromechanical_relay relay_solid_state_relay" ;;
    pmic)
      echo "pmic_switching_dcdc_converter pmic_switching_controller pmic_linear_regulator_reference pmic_battery_management pmic_system_pmic pmic_power_supervisor pmic_power_distribution_switch pmic_protocol_power_controller" ;;
    switch)
      echo "switch_mechanical_actuated_switch switch_mechanical_sensing_switch switch_magnetic_sensing_switch" ;;
    mcu_mpu_dsp)
      echo "mcu_mpu_dsp_mcu mcu_mpu_dsp_mpu_soc mcu_mpu_dsp_dsp" ;;
    transformer)
      echo "transformer_signal_communication_transformer transformer_switching_drive_transformer" ;;
    data_converter)
      echo "data_converter_adc data_converter_dac" ;;
    circuit_protection)
      echo "circuit_protection_semiconductor_transient_suppression circuit_protection_overcurrent_overtemperature_protection circuit_protection_passive_surge_diversion circuit_protection_surge_protection_module" ;;
    driver_ic)
      echo "driver_ic_gate_driver driver_ic_led_lighting_driver driver_ic_motor_driver driver_ic_display_driver driver_ic_laser_driver" ;;
    acoustic_device)
      echo "acoustic_device_buzzer_and_piezo_actuator acoustic_device_speaker acoustic_device_receiver acoustic_device_microphone" ;;
    sensor)
      echo "sensor_current_sensor_ic sensor_environmental_sensor_ic sensor_image_sensor sensor_inertial_mems_sensor sensor_magnetic_sensor_ic sensor_pressure_sensor" ;;
    amplifier)
      echo "amplifier_audio_power_amplifier amplifier_general_opamp_comparator amplifier_precision_signal_conditioning_amp amplifier_rf_if_amplifier amplifier_transimpedance_transconductance_log_amp amplifier_video_wideband_amp" ;;
    isolator)
      echo "isolator_digital_isolator isolator_optocoupler isolator_isolated_analog_amplifier isolator_rf_isolator_circulator" ;;
    logic_ic)
      echo "logic_ic_combinational_logic logic_ic_sequential_logic logic_ic_signal_buffer_driver" ;;
    fpga_cpld)
      echo "fpga_cpld_fpga fpga_cpld_cpld" ;;
    rf_wireless)
      echo "rf_wireless_rf_antenna rf_wireless_rf_passive_network rf_wireless_rf_signal_control_detection rf_wireless_rf_transceiver_ic rf_wireless_rf_frequency_synthesis rf_wireless_rfid_nfc_frontend" ;;
    storage)
      echo "storage_managed_flash_module storage_volatile_ram storage_flash_memory storage_rewritable_rom storage_nv_ram storage_memory_controller" ;;
    clock_timing)
      echo "clock_timing_resonator clock_timing_oscillator clock_timing_clock_management_ic clock_timing_timekeeping_timing_ic clock_timing_delay_timing_adjustment" ;;
    optoelectronics)
      echo "optoelectronics_light_emitter optoelectronics_photodetector" ;;
    system_module)
      echo "system_module_compute_som_module system_module_power_module system_module_wired_comm_module system_module_wireless_comm_module" ;;
    connector)
      echo "connector_board_wire_interconnect_connector connector_general_shell_connector connector_standard_interface_socket_connector connector_backplane_ic_socket_connector connector_power_terminal_connector connector_rf_coaxial_connector" ;;
    interface_communication_ic)
      echo "interface_communication_ic_serial_bus_transceiver interface_communication_ic_ethernet_interface interface_communication_ic_highspeed_serial_interface interface_communication_ic_digital_isolation_interface interface_communication_ic_level_shifter_signal_conditioning interface_communication_ic_bus_switch_mux" ;;
    *) echo "" ;;
  esac
}

l2_sql_base() {
  local l1="$1"
  local sub
  sub="$(l1_dir "$l1")"
  if [[ -n "$sub" && "$sub" != "$l1" ]]; then
    echo "$SCRIPT_DIR/$sub"
  else
    echo "$SCRIPT_DIR"
  fi
}

render_to_target() {
  local f="$1"
  if [[ "$ENV_NAME" == "prod" ]]; then
    cat "$f"
  else
    # 产出写 test_dwd / test_dim；源参数表保持 prod dwd 只读（见 sql_scripts/test/README.md）
    sed -e "s/\bdwd\./${DWD_DB}./g" -e "s/\bdim\./${DIM_DB}./g" "$f" \
      | sed -e "s/${DWD_DB}\.dwd_icpdf_component_param/dwd.dwd_icpdf_component_param/g" \
            -e "s/${DWD_DB}\.dwd_digikey_component_param/dwd.dwd_digikey_component_param/g" \
            -e "s/${DWD_DB}\.dwd_ecloud_component_param/dwd.dwd_ecloud_component_param/g" \
      | if [[ "${USE_TEST_DIM_BRAND:-0}" == "1" ]]; then
          sed -e "s/${DIM_DB}\.v_std_brand_alias/test_dim.v_std_brand_alias/g"
        else
          cat
        fi
  fi
}

if [[ "$INIT_EAV_DDL" == "1" ]]; then
  echo "==> [INIT] $DWD_DB.dwd_component_attr_std DDL（DROP+CREATE）"
  render_to_target "$SCRIPT_DIR/dwd_component_attr_std.sql" | "${MYSQL_CMD[@]}"
fi

for src in $SOURCES; do
  case "$src" in
    icpdf)
      echo "==> EAV ← icpdf"
      render_to_target "$SCRIPT_DIR/build_dwd_component_attr_std_icpdf.sql" | "${MYSQL_CMD[@]}"
      ;;
    digikey)
      echo "==> EAV ← digikey"
      render_to_target "$SCRIPT_DIR/build_dwd_component_attr_std_digikey.sql" | "${MYSQL_CMD[@]}"
      ;;
    ecloud)
      echo "==> EAV ← ecloud"
      render_to_target "$SCRIPT_DIR/build_dwd_component_attr_std_ecloud.sql" | "${MYSQL_CMD[@]}"
      ;;
    *) echo "  WARN: 未知 source: $src" >&2 ;;
  esac
done

for l1 in $L1_LIST; do
  base="$(l2_sql_base "$l1")"
  for sfx in $(l2_files_for_l1 "$l1"); do
    echo "==> $DWD_DB.dwd_l2_${sfx} DDL"
    render_to_target "$base/dwd_l2_${sfx}.sql" | "${MYSQL_CMD[@]}"
    echo "==> build dwd_l2_${sfx}"
    render_to_target "$base/build_dwd_l2_${sfx}.sql" | "${MYSQL_CMD[@]}"
  done
done

# L2 宽表重建后刷新 dwd_l2_component_catalog（L2 SKU 全局分类目录）
# catalog 行直接来自 dwd_l2_* 宽表，L2 变了 catalog 必须跟上。
# 仅 prod 默认开启；test 环境不刷。用 AUTO_REFRESH_CATALOG=0 关闭。
if [[ "$ENV_NAME" == "prod" && "${AUTO_REFRESH_CATALOG:-1}" == "1" ]]; then
  echo "==> refresh $DWD_DB.dwd_l2_component_catalog"
  INIT_DDL="${INIT_DDL:-1}" python3 "$SCRIPT_DIR/build_dwd_l2_component_catalog.py" prod
fi

echo "Done."
