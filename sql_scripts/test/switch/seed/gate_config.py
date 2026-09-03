"""switch ICPDF gate v1 真源配置。

对齐 switch_schema_v1.5.28.xlsx 三 L2 Base（15xxxx）。
ICPDF 主字段为 category2；category 作补充（大量 category IS NULL）。

probe_gate.py / gen_rule_csv.py 均读取本文件。
"""
from __future__ import annotations

SCHEMA_VERSION = "v1.5.28"
DATA_SOURCE = "icpdf"
L1_CODE = "switch"

# G1 · category2_in 白名单（机械/磁感应开关叶类目，正向枚举）
# 按 L2 分组仅作文档；引擎侧合并为 gate_switch_icpdf_v1 group0 OR group1。
CATEGORY2_INCLUDE_GROUPS: list[dict] = [
    {
        "l2_code": "mechanical_actuated_switch",
        "categories": [
            "按钮开关",
            "旋转开关",
            "拨动开关",
            "翘板开关",
            "拨码开关",
            "小键盘开关",
            "滑动开关",
            "键锁开关",
            "指轮/按动滚轮开关",
        ],
        "note": "机械操作开关 · 150101–150111",
    },
    {
        "l2_code": "mechanical_sensing_switch",
        "categories": [
            "快动/限位开关",
        ],
        "note": "机械检测开关 · 150201–150203；快动/限位叶类目 classify 再拆 snap vs limit",
    },
    {
        "l2_code": "magnetic_sensing_switch",
        "categories": [
            "磁簧开关",
        ],
        "note": "磁感应开关 · 150301–150302；霍尔/导航无独立 category2 叶，走 classify",
    },
]

CATEGORY2_INCLUDE: list[str] = [
    cat for g in CATEGORY2_INCLUDE_GROUPS for cat in g["categories"]
]

# G2 · category_in 补充（category 非空、category2 为空或不在 G1 的存量路径）
CATEGORY_INCLUDE: list[str] = [
    "轻触开关、轻推开关",
    "基础型/快动型/限制型",
    "DIP/SIP",
    "滑块开关",
    "按钮开关",
    "拨动开关",
    "旋转开关",
]

# 明确不纳入 gate（白名单外即排除；此处仅文档）
CATEGORY2_EXPLICIT_OUT: list[dict] = [
    {"category2": "开关式稳压器或控制器", "cnt": 69518, "reason": "PMIC · 非机械开关"},
    {"category2": "复用器或开关", "cnt": 15708, "reason": "模拟/逻辑 mux · 非机械开关"},
    {"category2": "射频/微波开关", "cnt": 2042, "reason": "RF IC · 归 rf_wireless"},
    {"category2": "插槽式开关", "cnt": 1744, "reason": "仓内多为光敏/光电传感器误挂叶；schema 无 Slot_Switch"},
    {"category2": "特殊开关", "cnt": 1100, "reason": "语义过宽 · v1 不 gate；后续 note/prajson classify 兜底"},
    {"category2": "其他开关", "cnt": 498, "reason": "v1.5.28 已移除 other_switch L3"},
    {"category2": "光纤开关", "cnt": 359, "reason": "schema 无对应 L3"},
    {"category2": "可控硅开关", "cnt": 11, "reason": "晶闸管 · 归 transistor"},
]

CATEGORY_EXPLICIT_OUT: list[dict] = [
    {"category": "开关配件", "cnt": 98, "reason": "配件/帽/触头块 · 对齐 DK gate 排除配件类"},
    {"category": "模拟开关芯片", "cnt": 614, "reason": "模拟 mux IC · 非机械开关"},
    {"category": "开关控制器", "reason": "PMIC 控制器"},
    {"category": "开关电源", "reason": "电源模块"},
    {"category": "热熔断路器/开关/保险丝", "reason": "电路保护"},
    {"category": "紧急停止板/盖子", "reason": "E-Stop 配件 · 非蘑菇头本体"},
]

# category2 → schema L3 hint（classify 设计参考）
CATEGORY2_L3_HINT: dict[str, list[str]] = {
    "按钮开关": ["150102 pushbutton_switch"],
    "旋转开关": ["150105 rotary_switch"],
    "拨动开关": ["150103 toggle_switch"],
    "翘板开关": ["150106 rocker_switch"],
    "拨码开关": ["150107 dip_switch"],
    "小键盘开关": ["150109 mechanical_key_switch"],
    "滑动开关": ["150104 slide_switch"],
    "键锁开关": ["150108 keylock_switch"],
    "指轮/按动滚轮开关": ["150111 thumbwheel_switch"],
    "快动/限位开关": ["150201 snap_action_switch", "150202 limit_switch"],
    "磁簧开关": ["150301 reed_switch"],
}

CATEGORY_L3_HINT: dict[str, list[str]] = {
    "轻触开关、轻推开关": ["150101 tactile_switch"],
    "基础型/快动型/限制型": ["150201 snap_action_switch", "150202 limit_switch"],
    "DIP/SIP": ["150107 dip_switch"],
    "滑块开关": ["150104 slide_switch"],
}

# prod 探针基线（2026-06-09 · enable_local_shuffle_agg=false）
GATE_BASELINE = {
    "distinct_ids": 144_273,
    "rows_category2_in": 143_225,
    "rows_category_in_supplement_only": 1_048,
}
