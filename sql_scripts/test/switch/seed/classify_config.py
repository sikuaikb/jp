"""switch ICPDF classify 规则真源（gate 见 gate_config.py）。

决选：phase DESC → rule_priority ASC → l3_code ASC
ICPDF 主路径 category2_eq（phase 2）；混合叶「快动/限位开关」phase 3 note 专规 + phase 2 fallback。
"""
from __future__ import annotations

SCHEMA_VERSION = "v1.5.28"
DATA_SOURCE = "icpdf"

# clauses: (field_code, match_value, match_values, match_map)
CLASSIFY_RULES: list[dict] = [
    # ── phase 2 · category2 同名 1:1（机械操作 + 磁簧）──
    {
        "rule_id": "switch_icpdf_pushbutton_c2_v1",
        "l3_id": "150102",
        "l3_cn": "按钮开关",
        "phase": 2,
        "rule_priority": 10,
        "clauses": [("category2_eq", "按钮开关", None, None)],
        "note": "mechanical_actuated · pushbutton",
    },
    {
        "rule_id": "switch_icpdf_rotary_c2_v1",
        "l3_id": "150105",
        "l3_cn": "旋转开关",
        "phase": 2,
        "rule_priority": 10,
        "clauses": [("category2_eq", "旋转开关", None, None)],
        "note": "mechanical_actuated · rotary",
    },
    {
        "rule_id": "switch_icpdf_toggle_c2_v1",
        "l3_id": "150103",
        "l3_cn": "拨动开关",
        "phase": 2,
        "rule_priority": 10,
        "clauses": [("category2_eq", "拨动开关", None, None)],
        "note": "mechanical_actuated · toggle",
    },
    {
        "rule_id": "switch_icpdf_rocker_c2_v1",
        "l3_id": "150106",
        "l3_cn": "船型开关",
        "phase": 2,
        "rule_priority": 10,
        "clauses": [("category2_eq", "翘板开关", None, None)],
        "note": "mechanical_actuated · rocker（icpdf 叶=翘板）",
    },
    {
        "rule_id": "switch_icpdf_dip_c2_v1",
        "l3_id": "150107",
        "l3_cn": "拨码开关",
        "phase": 2,
        "rule_priority": 10,
        "clauses": [("category2_eq", "拨码开关", None, None)],
        "note": "mechanical_actuated · dip",
    },
    {
        "rule_id": "switch_icpdf_slide_c2_v1",
        "l3_id": "150104",
        "l3_cn": "滑动开关",
        "phase": 2,
        "rule_priority": 10,
        "clauses": [("category2_eq", "滑动开关", None, None)],
        "note": "mechanical_actuated · slide",
    },
    {
        "rule_id": "switch_icpdf_keylock_c2_v1",
        "l3_id": "150108",
        "l3_cn": "钥匙开关",
        "phase": 2,
        "rule_priority": 10,
        "clauses": [("category2_eq", "键锁开关", None, None)],
        "note": "mechanical_actuated · keylock",
    },
    {
        "rule_id": "switch_icpdf_thumbwheel_c2_v1",
        "l3_id": "150111",
        "l3_cn": "指轮/滚轮开关",
        "phase": 2,
        "rule_priority": 10,
        "clauses": [("category2_eq", "指轮/按动滚轮开关", None, None)],
        "note": "mechanical_actuated · thumbwheel",
    },
    {
        "rule_id": "switch_icpdf_reed_c2_v1",
        "l3_id": "150301",
        "l3_cn": "磁簧开关",
        "phase": 2,
        "rule_priority": 10,
        "clauses": [("category2_eq", "磁簧开关", None, None)],
        "note": "magnetic_sensing · reed",
    },
    # ── phase 2 · category 补充（priority 6 轻触先于小键盘 c2）──
    {
        "rule_id": "switch_icpdf_tactile_cat_v1",
        "l3_id": "150101",
        "l3_cn": "轻触开关",
        "phase": 2,
        "rule_priority": 6,
        "clauses": [("category_eq", "轻触开关、轻推开关", None, None)],
        "note": "tactile · category 路径（含 327 行 c2=小键盘）",
    },
    {
        "rule_id": "switch_icpdf_mechanical_key_c2_v1",
        "l3_id": "150109",
        "l3_cn": "键盘开关",
        "phase": 2,
        "rule_priority": 10,
        "clauses": [("category2_eq", "小键盘开关", None, None)],
        "note": "mechanical_key · 小键盘叶",
    },
    {
        "rule_id": "switch_icpdf_slide_cat_v1",
        "l3_id": "150104",
        "l3_cn": "滑动开关",
        "phase": 2,
        "rule_priority": 10,
        "clauses": [("category_eq", "滑块开关", None, None)],
        "note": "slide · category-only",
    },
    {
        "rule_id": "switch_icpdf_pushbutton_cat_v1",
        "l3_id": "150102",
        "l3_cn": "按钮开关",
        "phase": 2,
        "rule_priority": 10,
        "clauses": [("category_eq", "按钮开关", None, None)],
        "note": "pushbutton · category-only",
    },
    {
        "rule_id": "switch_icpdf_toggle_cat_v1",
        "l3_id": "150103",
        "l3_cn": "拨动开关",
        "phase": 2,
        "rule_priority": 10,
        "clauses": [("category_eq", "拨动开关", None, None)],
        "note": "toggle · category-only",
    },
    {
        "rule_id": "switch_icpdf_rotary_cat_v1",
        "l3_id": "150105",
        "l3_cn": "旋转开关",
        "phase": 2,
        "rule_priority": 10,
        "clauses": [("category_eq", "旋转开关", None, None)],
        "note": "rotary · category-only",
    },
    # ── DIP/SIP 混合路径 ──
    {
        "rule_id": "switch_icpdf_dip_sip_rotary_v1",
        "l3_id": "150105",
        "l3_cn": "旋转开关",
        "phase": 3,
        "rule_priority": 8,
        "clauses": [
            ("category_eq", "DIP/SIP", None, None),
            ("category2_eq", "旋转开关", None, None),
        ],
        "note": "DIP/SIP 中旋转编码类 · 55 行",
    },
    {
        "rule_id": "switch_icpdf_dip_sip_slide_v1",
        "l3_id": "150104",
        "l3_cn": "滑动开关",
        "phase": 3,
        "rule_priority": 8,
        "clauses": [
            ("category_eq", "DIP/SIP", None, None),
            ("category2_eq", "滑动开关", None, None),
        ],
        "note": "DIP/SIP 中滑动类",
    },
    {
        "rule_id": "switch_icpdf_dip_sip_v1",
        "l3_id": "150107",
        "l3_cn": "拨码开关",
        "phase": 2,
        "rule_priority": 12,
        "clauses": [("category_eq", "DIP/SIP", None, None)],
        "note": "DIP/SIP 默认归 dip（678 行 c2=拨码已由 dip_c2 覆盖）",
    },
    # ── 快动/限位 · phase 3 note 专规 ──
    {
        "rule_id": "switch_icpdf_limit_note_v1",
        "l3_id": "150202",
        "l3_cn": "限位开关",
        "phase": 3,
        "rule_priority": 8,
        "clauses": [
            ("category2_eq", "快动/限位开关", None, None),
            ("note_cn_regexp", "限位|LIMIT|限制型", None, None),
        ],
        "note": "snap/limit 叶 · note 限位专规",
    },
    {
        "rule_id": "switch_icpdf_snap_note_v1",
        "l3_id": "150201",
        "l3_cn": "微动开关",
        "phase": 3,
        "rule_priority": 9,
        "clauses": [
            ("category2_eq", "快动/限位开关", None, None),
            ("note_cn_regexp", "微动|快动|速动|SNAP|Snap|基础型", None, None),
        ],
        "note": "snap/limit 叶 · note 微动/快动专规",
    },
    {
        "rule_id": "switch_icpdf_base_limit_note_v1",
        "l3_id": "150202",
        "l3_cn": "限位开关",
        "phase": 3,
        "rule_priority": 8,
        "clauses": [
            ("category_eq", "基础型/快动型/限制型", None, None),
            ("note_cn_regexp", "限位|LIMIT|限制型", None, None),
        ],
        "note": "基础型/快动型/限制型 · note 限制",
    },
    {
        "rule_id": "switch_icpdf_base_snap_note_v1",
        "l3_id": "150201",
        "l3_cn": "微动开关",
        "phase": 3,
        "rule_priority": 9,
        "clauses": [
            ("category_eq", "基础型/快动型/限制型", None, None),
            ("note_cn_regexp", "微动|快动|速动|SNAP|Snap|基础型", None, None),
        ],
        "note": "基础型/快动型/限制型 · note 快动",
    },
    # ── phase 2 fallback（混合叶 / 无 note）──
    {
        "rule_id": "switch_icpdf_snap_limit_fb_v1",
        "l3_id": "150202",
        "l3_cn": "限位开关",
        "phase": 2,
        "rule_priority": 20,
        "clauses": [("category2_eq", "快动/限位开关", None, None)],
        "note": "snap/limit 叶 fallback · prajson2 开关类型≈SNAP ACTING/LIMIT 无法拆；默认 limit（对齐 DK 限位主类）",
    },
    {
        "rule_id": "switch_icpdf_base_type_fb_v1",
        "l3_id": "150201",
        "l3_cn": "微动开关",
        "phase": 2,
        "rule_priority": 25,
        "clauses": [("category_eq", "基础型/快动型/限制型", None, None)],
        "note": "基础型/快动型/限制型 · c2=NULL 109 行 fallback → snap",
    },
]

# v1 Deferred（仓内 0 行或极低 · 待数据/专规）
DEFERRED_L3: list[dict] = [
    {
        "l3_id": "150302",
        "l3_code": "hall_effect_switch",
        "reason": "gate 内无霍尔叶；霍尔多归 sensor 类目",
    },
    {
        "l3_id": "150203",
        "l3_code": "interlock_safety_switch",
        "reason": "仓内互锁 note/category ≈0",
    },
    {
        "l3_id": "150110",
        "l3_code": "navigation_joystick_switch",
        "reason": "仓内导航/操纵杆 ≈0",
    },
]
