"""logic_ic DigiKey gate v1 真源配置。

- G1：dim `category_in`（按 L2 分组多行 OR）
- X2：SQL 补充 `category NOT LIKE`（评估板/开发套件）
- classify 阶段再按 DK 叶子 → 13 L3；gate 只收 IC 叶子

probe_gate.py / gen_rule_csv.py 均读取本文件。
"""
from __future__ import annotations

SCHEMA_VERSION = "v1.4.30"
DATA_SOURCE = "digikey"
L1_CODE = "logic_ic"

# G1 · category_in 白名单（2026-06 DigiKey 探查）
CATEGORY_INCLUDE_GROUPS: list[dict] = [
    {
        "rule_id": "gate_logic_ic_digikey_combinational_v1",
        "l2_code": "combinational_logic",
        "categories": [
            "门和反相器",
            "门和反相器 - 多功能，可配置",
            "比较器",
            "奇偶校验发生器和校验器",
            "信号开关，多路复用器，解码器",
            "专用逻辑器件",
        ],
        "note": "组合逻辑 · 220101–220105；含奇偶校验叶 → encoder_decoder",
    },
    {
        "rule_id": "gate_logic_ic_digikey_sequential_v1",
        "l2_code": "sequential_logic",
        "categories": [
            "触发器",
            "移位寄存器",
        ],
        "note": "时序逻辑 · 220201–220204；寄存器/计数器多在触发器叶子内 classify",
    },
    {
        "rule_id": "gate_logic_ic_digikey_buffer_v1",
        "l2_code": "signal_buffer_driver",
        "categories": [
            "缓冲器，驱动器，接收器，收发器",
        ],
        "note": "缓冲/总线收发 · 220301–220304；不含 RS485/CAN 接口收发叶子",
    },
]

CATEGORY_INCLUDE: list[str] = [
    cat for g in CATEGORY_INCLUDE_GROUPS for cat in g["categories"]
]

EXCLUDE_CATEGORY_NOT_LIKE: list[str] = [
    "%评估板%",
    "%开发套件%",
]

# 邻近 DK 类目：prod 有 SKU 但本期 deliberately 不收
CATEGORY_EXPLICIT_OUT: list[dict] = [
    {
        "category": "驱动器，接收器，收发器",
        "reason": "RS232/RS485/CAN 等接口收发 → interface_communication_ic，非 logic 总线收发",
    },
    {
        "category": "信号缓冲器、中继器、分离器",
        "reason": "加速计缓冲/Retimer 等专用缓冲，非 220301 buffer_driver",
    },
    {
        "category": "FIFO 存储器",
        "reason": "存储器 L1（storage），非 logic_ic",
    },
    {
        "category": "CPLD（复杂可编程逻辑器件）",
        "reason": "fpga_cpld L1",
    },
    {
        "category": "FPGA（现场可编程门阵列）",
        "reason": "fpga_cpld L1",
    },
    {
        "category": "带单片机的 FPGA（现场可编程门阵列）",
        "reason": "fpga_cpld / mcu 边界",
    },
    {
        "category": "可编程定时器和振荡器",
        "reason": "clock_timing L1",
    },
    {
        "category": "编码器，解码器，转换器",
        "reason": "工业编码器/转换器混合路径，非数字逻辑编解码 IC",
    },
    {
        "category": "编码器 - 工业",
        "reason": "工业旋转编码器硬件，非 logic encoder_decoder",
    },
]

CATEGORY_L3_HINT: dict[str, list[str]] = {
    "门和反相器": ["220101 basic_logic_gate"],
    "门和反相器 - 多功能，可配置": ["220101 basic_logic_gate"],
    "比较器": ["220104 digital_comparator"],
    "奇偶校验发生器和校验器": ["220103 encoder_decoder"],
    "信号开关，多路复用器，解码器": [
        "220102 mux_demux",
        "220103 encoder_decoder",
        "220304 bus_switch",
    ],
    "专用逻辑器件": [
        "220105 alu_adder",
        "220201 flip_flop_latch",
        "220202 register",
        "220204 counter_divider",
        "220104 digital_comparator",
        "220301 buffer_driver",
        "220302 bus_transceiver",
    ],
    "触发器": ["220201 flip_flop_latch", "220202 register", "220204 counter_divider"],
    "移位寄存器": ["220203 shift_register"],
    "缓冲器，驱动器，接收器，收发器": [
        "220301 buffer_driver",
        "220302 bus_transceiver",
        "220303 level_translator",
    ],
}
