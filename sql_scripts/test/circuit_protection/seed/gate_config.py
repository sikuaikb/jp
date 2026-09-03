"""circuit_protection ICPDF gate v1 真源配置。

Schema：circuit_protection_schema.xlsx → v1.16.01
ICPDF 无 category2=「电路保护」叶；主锚点为 taginfo「电路保护」+ category/category2 器件叶。

路由（ICPDF 与得捷对齐）：
  · TVS二极管 → CP · tvs_diode（gate_diode 不含 TVS 字面）
  · TSPD / 电信浪涌 → CP · tspd
  · MOV → CP · mov（仅精确「压敏电阻」；不含 category2=非线性电阻器 宽桶）
禁止 category2=「瞬态抑制器」宽 gate（~17 万行且与 tag 几乎无交集，多为非 CP 误挂）。
"""
from __future__ import annotations

SCHEMA_VERSION = "v1.16.01"
DATA_SOURCE = "icpdf"
L1_CODE = "circuit_protection"

# G0 · taginfo 主锚（~29k，保险丝/断路器为主）
TAGINFO_INCLUDE: list[str] = ["电路保护"]

# G1 · category 器件叶（压敏电阻 · 学得捷精确 gate，不含非线性宽桶）
CATEGORY_INCLUDE: list[str] = [
    "TVS二极管",
    "压敏电阻",
    "保险丝",
    "热熔断路器/开关/保险丝",
    "电路保护器件",
    "硅浪涌保护器",
]

# G2 · category2 器件叶（不含「瞬态抑制器」；MOV 仅精确压敏电阻）
CATEGORY2_INCLUDE: list[str] = [
    "电熔丝",
    "断路器",
    "压敏电阻",
    "硅浪涌保护器",
    "电信保护电路",
    # 不含「非线性电阻器」→ resistor icpdf gate（NTC / PTC 等宽桶）
    # 不含「熔断电阻器」→ 归 resistor L1（115010 fusible_resistor）
]

CATEGORY2_INCLUDE_GROUPS: list[dict] = [
    {
        "l2_code": "overcurrent_overtemperature_protection",
        "categories": ["电熔丝", "断路器"],
        "note": "1601xx 过流/过温",
    },
    {
        "l2_code": "passive_surge_diversion",
        "categories": ["压敏电阻"],
        "note": "1603xx MOV · 精确 gate",
    },
    {
        "l2_code": "semiconductor_transient_suppression",
        "categories": ["硅浪涌保护器", "电信保护电路"],
        "note": "1602xx TSPD/GDT；电信叶内 GDT 子集 classify → gdt",
    },
]

# 明确不纳入 gate（文档）
CATEGORY2_EXPLICIT_OUT: list[dict] = [
    {
        "category2": "瞬态抑制器",
        "cnt": 171065,
        "reason": "icpdf 宽叶；与 tag=电路保护 交集≈0；TVS 用 category=TVS二极管 精确 gate",
    },
    {
        "category2": "非线性电阻器",
        "reason": "宽桶 · 归 resistor L1 · CP 仅收精确压敏电阻",
    },
    {"category2": "保险丝座", "reason": "配件 · 对齐 DK gate 排除"},
]

GATE_BASELINE = {
    "distinct_ids": 76_575,
    "category_rows": 35_000,
    "category2_rows": 52_000,
    "note": "probe 2026-07-02 · TVS/TSPD/MOV 统一路由 · ~76,575 gate id",
}
