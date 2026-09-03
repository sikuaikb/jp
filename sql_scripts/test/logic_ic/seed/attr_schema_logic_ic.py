"""logic_ic 属性 schema 草案（无 xlsx 时真源；后续可对齐 Logic_IC_schema.xlsx）。"""
from __future__ import annotations

SCHEMA_VERSION = "logic_ic_schema_v1.4.30"
L1_CODE = "logic_ic"

L2_CODES = [
    "combinational_logic",
    "sequential_logic",
    "signal_buffer_driver",
]

# L3 专规属性（scope_level=l3）
L3_ATTRS: dict[str, list[dict]] = {
    "basic_logic_gate": [
        {"code": "logic_type", "cn": "逻辑类型", "db_type": "VARCHAR", "ord": 505},
        {"code": "input_count", "cn": "输入数", "db_type": "INT", "ord": 510},
        {"code": "circuit_count", "cn": "电路数", "db_type": "INT", "ord": 515},
        {"code": "output_type_gate", "cn": "输出类型", "db_type": "VARCHAR", "ord": 520},
        {"code": "schmitt_trigger_input", "cn": "施密特触发器输入", "db_type": "VARCHAR", "ord": 525},
    ],
    "mux_demux": [
        {"code": "independent_circuits", "cn": "独立电路", "db_type": "INT", "ord": 505},
        {"code": "circuit_config", "cn": "开关电路配置", "db_type": "VARCHAR", "ord": 510},
        {"code": "supply_voltage_type", "cn": "供电电压源", "db_type": "VARCHAR", "ord": 515},
    ],
    "encoder_decoder": [
        {"code": "independent_circuits", "cn": "独立电路", "db_type": "INT", "ord": 505},
        {"code": "circuit_config", "cn": "电路配置", "db_type": "VARCHAR", "ord": 510},
        {"code": "supply_voltage_type", "cn": "供电电压源", "db_type": "VARCHAR", "ord": 515},
    ],
    "digital_comparator": [
        {"code": "bit_width", "cn": "位数", "db_type": "INT", "ord": 505},
        {"code": "comparator_type", "cn": "比较器类型", "db_type": "VARCHAR", "ord": 510},
        {"code": "output_function", "cn": "输出功能", "db_type": "VARCHAR", "ord": 515},
        {"code": "comparator_output", "cn": "比较器输出", "db_type": "VARCHAR", "ord": 520},
    ],
    "alu_adder": [
        {"code": "bit_width", "cn": "位数", "db_type": "INT", "ord": 505},
        {"code": "logic_type", "cn": "逻辑类型", "db_type": "VARCHAR", "ord": 510},
    ],
    "flip_flop_latch": [
        {"code": "element_count", "cn": "元件数", "db_type": "INT", "ord": 505},
        {"code": "bits_per_element", "cn": "每个元件位数", "db_type": "INT", "ord": 510},
        {"code": "output_type_ff", "cn": "输出类型", "db_type": "VARCHAR", "ord": 515},
        {"code": "input_capacitance_pf", "cn": "输入电容", "db_type": "VARCHAR", "ord": 520},
    ],
    "register": [
        {"code": "bit_width", "cn": "位数", "db_type": "INT", "ord": 505},
        {"code": "logic_type", "cn": "逻辑类型", "db_type": "VARCHAR", "ord": 510},
    ],
    "shift_register": [
        {"code": "shift_function", "cn": "移位功能", "db_type": "VARCHAR", "ord": 505},
        {"code": "element_count", "cn": "元件数", "db_type": "INT", "ord": 510},
        {"code": "bits_per_element", "cn": "每个元件位数", "db_type": "INT", "ord": 515},
        {"code": "output_type_sr", "cn": "输出类型", "db_type": "VARCHAR", "ord": 520},
    ],
    "counter_divider": [
        {"code": "bit_width", "cn": "位数", "db_type": "INT", "ord": 505},
        {"code": "logic_type", "cn": "逻辑类型", "db_type": "VARCHAR", "ord": 510},
    ],
    "buffer_driver": [
        {"code": "bit_width", "cn": "位数", "db_type": "INT", "ord": 505},
        {"code": "logic_type", "cn": "逻辑类型", "db_type": "VARCHAR", "ord": 510},
        {"code": "element_count", "cn": "元件数", "db_type": "INT", "ord": 515},
        {"code": "bits_per_element", "cn": "每个元件位数", "db_type": "INT", "ord": 520},
        {"code": "input_type", "cn": "输入类型", "db_type": "VARCHAR", "ord": 525},
        {"code": "output_type_buf", "cn": "输出类型", "db_type": "VARCHAR", "ord": 530},
    ],
    "bus_transceiver": [
        {"code": "element_count", "cn": "元件数", "db_type": "INT", "ord": 505},
        {"code": "bits_per_element", "cn": "每个元件位数", "db_type": "INT", "ord": 510},
        {"code": "input_type", "cn": "输入类型", "db_type": "VARCHAR", "ord": 515},
        {"code": "output_type_xcvr", "cn": "输出类型", "db_type": "VARCHAR", "ord": 520},
    ],
    "bus_switch": [
        {"code": "circuit_config", "cn": "开关电路配置", "db_type": "VARCHAR", "ord": 505},
        {"code": "switch_type", "cn": "开关类型", "db_type": "VARCHAR", "ord": 510},
        {"code": "supply_voltage_type", "cn": "供电电压源", "db_type": "VARCHAR", "ord": 515},
    ],
}

# L2 公共（三个 L2 Base 共用字段集）
L2_COMMON: list[dict] = [
    {"code": "manufacturer", "cn": "制造商", "db_type": "VARCHAR", "cat": "tech_specs", "ord": 5},
    {"code": "mpn", "cn": "制造商料号", "db_type": "VARCHAR", "cat": "tech_specs", "ord": 10},
    {"code": "lifecycle_status", "cn": "生命周期状态", "db_type": "ENUM", "cat": "purchasing_attributes", "ord": 20},
    {"code": "rohs_compliant", "cn": "RoHS合规", "db_type": "VARCHAR", "cat": "regulatory_attributes", "ord": 15},
    {"code": "lead_free", "cn": "无铅", "db_type": "VARCHAR", "cat": "regulatory_attributes", "ord": 40},
    {"code": "reach", "cn": "REACH合规", "db_type": "VARCHAR", "cat": "regulatory_attributes", "ord": 25},
    {"code": "eccn_code", "cn": "ECCN", "db_type": "VARCHAR", "cat": "purchasing_attributes", "ord": 30},
    {"code": "msl_level", "cn": "湿敏等级", "db_type": "ENUM", "cat": "regulatory_attributes", "ord": 45},
    {"code": "package_case", "cn": "封装形式", "db_type": "VARCHAR", "cat": "package_attributes", "ord": 50},
    {"code": "mount_type", "cn": "安装类型", "db_type": "VARCHAR", "cat": "package_attributes", "ord": 55},
    {"code": "temp_min_c", "cn": "最低工作温度", "db_type": "DOUBLE", "cat": "tech_specs", "ord": 60},
    {"code": "temp_max_c", "cn": "最高工作温度", "db_type": "DOUBLE", "cat": "tech_specs", "ord": 65},
    {"code": "supply_voltage_min_v", "cn": "供电电压最小值", "db_type": "DOUBLE", "cat": "tech_specs", "ord": 70},
    {"code": "supply_voltage_max_v", "cn": "供电电压最大值", "db_type": "DOUBLE", "cat": "tech_specs", "ord": 75},
    {"code": "propagation_delay_ns", "cn": "传播延迟", "db_type": "DOUBLE", "cat": "tech_specs", "ord": 80},
    {"code": "output_current_high_low", "cn": "输出高低电流", "db_type": "VARCHAR", "cat": "tech_specs", "ord": 85},
    {"code": "logic_series", "cn": "逻辑系列", "db_type": "VARCHAR", "cat": "tech_specs", "ord": 90},
]

CAT_CN = {
    "tech_specs": "技术参数",
    "regulatory_attributes": "合规参数",
    "purchasing_attributes": "交易参数",
    "package_attributes": "封装参数",
}
