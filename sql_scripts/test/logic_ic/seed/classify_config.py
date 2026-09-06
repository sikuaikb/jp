"""logic_ic DigiKey classify 规则真源（gate 见 gate_config.py）。"""
from __future__ import annotations

SCHEMA_VERSION = "v1.4.30"
DATA_SOURCE = "digikey"

# 决选：phase DESC → rule_priority ASC → l3_code ASC
CLASSIFY_RULES: list[dict] = [
    # ── 组合逻辑 · 1:1 category_eq（phase 2）──
    {
        "rule_id": "logic_ic_dk_gate_v1",
        "l3_id": "220101",
        "l3_cn": "基本逻辑门",
        "phase": 2,
        "rule_priority": 10,
        "clauses": [("category_eq", "门和反相器", None, None)],
        "note": "basic gate",
    },
    {
        "rule_id": "logic_ic_dk_config_gate_v1",
        "l3_id": "220101",
        "l3_cn": "基本逻辑门",
        "phase": 2,
        "rule_priority": 10,
        "clauses": [("category_eq", "门和反相器 - 多功能，可配置", None, None)],
        "note": "configurable gate",
    },
    {
        "rule_id": "logic_ic_dk_comparator_v1",
        "l3_id": "220104",
        "l3_cn": "数字比较器",
        "phase": 2,
        "rule_priority": 10,
        "clauses": [("category_eq", "比较器", None, None)],
        "note": "comparator leaf",
    },
    {
        "rule_id": "logic_ic_dk_parity_v1",
        "l3_id": "220103",
        "l3_cn": "编码器/解码器",
        "phase": 2,
        "rule_priority": 10,
        "clauses": [("category_eq", "奇偶校验发生器和校验器", None, None)],
        "note": "parity gen/check",
    },
    # ── 时序逻辑 · 1:1 ──
    {
        "rule_id": "logic_ic_dk_flip_flop_v1",
        "l3_id": "220201",
        "l3_cn": "触发器/锁存器",
        "phase": 2,
        "rule_priority": 10,
        "clauses": [("category_eq", "触发器", None, None)],
        "note": "flip-flop leaf",
    },
    {
        "rule_id": "logic_ic_dk_shift_register_v1",
        "l3_id": "220203",
        "l3_cn": "移位寄存器",
        "phase": 2,
        "rule_priority": 10,
        "clauses": [("category_eq", "移位寄存器", None, None)],
        "note": "shift register leaf",
    },
    # ── 信号开关叶 · note 专规（phase 3）──
    {
        "rule_id": "logic_ic_dk_bus_switch_v1",
        "l3_id": "220304",
        "l3_cn": "总线开关",
        "phase": 3,
        "rule_priority": 8,
        "clauses": [
            ("category_eq", "信号开关，多路复用器，解码器", None, None),
            ("note_cn_regexp", "总线开关|交点开关", None, None),
        ],
        "note": "mux leaf · bus switch",
    },
    {
        "rule_id": "logic_ic_dk_decoder_v1",
        "l3_id": "220103",
        "l3_cn": "编码器/解码器",
        "phase": 3,
        "rule_priority": 9,
        "clauses": [
            ("category_eq", "信号开关，多路复用器，解码器", None, None),
            ("note_cn_regexp", "解码器|多路分解|Demultiplex", None, None),
        ],
        "note": "mux leaf · decoder/demux",
    },
    {
        "rule_id": "logic_ic_dk_mux_encoder_v1",
        "l3_id": "220103",
        "l3_cn": "编码器/解码器",
        "phase": 3,
        "rule_priority": 8,
        "clauses": [
            ("category_eq", "信号开关，多路复用器，解码器", None, None),
            ("note_cn_regexp", "优先顺序编码器|Priority Encoder", None, None),
        ],
        "note": "mux leaf · priority encoder",
    },
    {
        "rule_id": "logic_ic_dk_mux_v1",
        "l3_id": "220102",
        "l3_cn": "多路复用器/解复用器",
        "phase": 3,
        "rule_priority": 10,
        "clauses": [
            ("category_eq", "信号开关，多路复用器，解码器", None, None),
            ("note_cn_regexp", "多路复用|数据选择器|Multiplex", None, None),
        ],
        "note": "mux leaf · multiplexer",
    },
    {
        "rule_id": "logic_ic_dk_mux_fb_v1",
        "l3_id": "220102",
        "l3_cn": "多路复用器/解复用器",
        "phase": 1,
        "rule_priority": 99,
        "clauses": [("category_eq", "信号开关，多路复用器，解码器", None, None)],
        "note": "mux leaf fallback",
    },
    # ── 专用逻辑器件 · note 专规 ──
    {
        "rule_id": "logic_ic_dk_special_counter_v1",
        "l3_id": "220204",
        "l3_cn": "计数器/分频器",
        "phase": 3,
        "rule_priority": 8,
        "clauses": [
            ("category_eq", "专用逻辑器件", None, None),
            ("note_cn_regexp", "计数器|分频|Counter", None, None),
        ],
        "note": "specialty counter",
    },
    {
        "rule_id": "logic_ic_dk_special_adder_v1",
        "l3_id": "220105",
        "l3_cn": "算术逻辑单元/加法器",
        "phase": 3,
        "rule_priority": 9,
        "clauses": [
            ("category_eq", "专用逻辑器件", None, None),
            ("note_cn_regexp", "加法器|全加|算术逻辑单元|ALU|Adder", None, None),
        ],
        "note": "specialty adder/alu",
    },
    {
        "rule_id": "logic_ic_dk_special_regbuf_v1",
        "l3_id": "220301",
        "l3_cn": "缓冲器/线驱动器",
        "phase": 3,
        "rule_priority": 10,
        "clauses": [
            ("category_eq", "专用逻辑器件", None, None),
            ("note_cn_regexp", "寄存缓冲器|Register Buffer|DDR", None, None),
        ],
        "note": "specialty register buffer → buffer_driver",
    },
    {
        "rule_id": "logic_ic_dk_special_flipflop_v1",
        "l3_id": "220201",
        "l3_cn": "触发器/锁存器",
        "phase": 3,
        "rule_priority": 11,
        "clauses": [
            ("category_eq", "专用逻辑器件", None, None),
            ("note_cn_regexp", "触发器|锁存|Flip[ -]?Flop|Latch", None, None),
        ],
        "note": "specialty flip-flop/latch",
    },
    {
        "rule_id": "logic_ic_dk_special_register_v1",
        "l3_id": "220202",
        "l3_cn": "寄存器",
        "phase": 3,
        "rule_priority": 12,
        "clauses": [
            ("category_eq", "专用逻辑器件", None, None),
            ("note_cn_regexp", "寄存器|Register", None, None),
        ],
        "note": "specialty register",
    },
    {
        "rule_id": "logic_ic_dk_special_comparator_v1",
        "l3_id": "220104",
        "l3_cn": "数字比较器",
        "phase": 3,
        "rule_priority": 13,
        "clauses": [
            ("category_eq", "专用逻辑器件", None, None),
            ("note_cn_regexp", "比较器|Comparator", None, None),
        ],
        "note": "specialty comparator",
    },
    {
        "rule_id": "logic_ic_dk_special_transceiver_v1",
        "l3_id": "220302",
        "l3_cn": "总线收发器",
        "phase": 3,
        "rule_priority": 14,
        "clauses": [
            ("category_eq", "专用逻辑器件", None, None),
            ("note_cn_regexp", "收发器|Transceiver", None, None),
        ],
        "note": "specialty transceiver",
    },
    {
        "rule_id": "logic_ic_dk_special_buffer_v1",
        "l3_id": "220301",
        "l3_cn": "缓冲器/线驱动器",
        "phase": 3,
        "rule_priority": 15,
        "clauses": [
            ("category_eq", "专用逻辑器件", None, None),
            ("note_cn_regexp", "缓冲器|Buffer|驱动器|Driver|接收器", None, None),
        ],
        "note": "specialty buffer/driver",
    },
    {
        "rule_id": "logic_ic_dk_special_fb_v1",
        "l3_id": "220301",
        "l3_cn": "缓冲器/线驱动器",
        "phase": 1,
        "rule_priority": 99,
        "clauses": [("category_eq", "专用逻辑器件", None, None)],
        "note": "specialty fallback",
    },
    # ── 缓冲/收发叶 · note 专规 ──
    {
        "rule_id": "logic_ic_dk_buffer_transceiver_v1",
        "l3_id": "220302",
        "l3_cn": "总线收发器",
        "phase": 3,
        "rule_priority": 10,
        "clauses": [
            ("category_eq", "缓冲器，驱动器，接收器，收发器", None, None),
            ("note_cn_regexp", "收发器|Transceiver", None, None),
        ],
        "note": "buffer leaf · transceiver",
    },
    {
        "rule_id": "logic_ic_dk_buffer_driver_v1",
        "l3_id": "220301",
        "l3_cn": "缓冲器/线驱动器",
        "phase": 3,
        "rule_priority": 11,
        "clauses": [
            ("category_eq", "缓冲器，驱动器，接收器，收发器", None, None),
            ("note_cn_regexp", "缓冲器|Buffer|线路驱动|驱动器", None, None),
        ],
        "note": "buffer leaf · buffer/line driver",
    },
    {
        "rule_id": "logic_ic_dk_buffer_fb_v1",
        "l3_id": "220301",
        "l3_cn": "缓冲器/线驱动器",
        "phase": 1,
        "rule_priority": 99,
        "clauses": [("category_eq", "缓冲器，驱动器，接收器，收发器", None, None)],
        "note": "buffer leaf fallback · note 空",
    },
]

CLASSIFY_DEFERRED_L3: list[tuple[str, str, str]] = [
    ("220303", "level_translator", "DK 无独立电平转换叶子；缓冲叶 note 未命中"),
]
