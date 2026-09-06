# switch · ICPDF gate v1 设计

真源：[`seed/gate_config.py`](seed/gate_config.py) · Schema：[`seed/switch_schema_v1.5.28.xlsx`](seed/switch_schema_v1.5.28.xlsx)

DigiKey switch 分类已在 prod 完成（`gate_switch_digikey_v1` + 15 条 classify）。本设计针对 **ICPDF** 数据源，对齐 `switch_schema_v1.5.28` 共 **16 个 L3**（`15xxxx`）。

---

## 1. 与 DigiKey gate 的差异

| 维度 | DigiKey | ICPDF |
|------|---------|-------|
| 主类目字段 | `category`（11 个 DK 叶） | **`category2`**（11 个 icpdf 叶 + 补充） |
| 宽匹配 | 不适用（白名单足够） | **禁止** `LIKE '%开关%'`（PMIC ~69k 误收） |
| 霍尔/导航 | DK 有独立 category | ICPDF **无** `霍尔效应开关` / `导航` 叶类目 → 靠 classify |
| 配件 | 文档排除触头/帽/套件 | `开关配件` 不进 category 补充名单 |

---

## 2. 规则结构

单条 gate 规则 **`gate_switch_icpdf_v1`**，两组 **OR**（与 `gate_resistor_icpdf_v1` / `gate_capacitor_icpdf_v1` 同模式）：

```text
gate_switch_icpdf_v1
├── group 0 · category2_in   ← 主路径（~143k 行）
└── group 1 · category_in    ← 补充路径（~1k 行，category 非空）
```

引擎：`dwd_component_class.sql` → `gate_pass = gate_include − gate_exclude`。v1 **不设 exclude 行**（正向白名单已避开 PMIC/模拟 mux）；若后续漏入再加 `gate_exclude_*`。

---

## 3. G1 · category2_in 白名单（11 叶）

| category2 | 行数 | 主要 L3 |
|-----------|-----:|---------|
| 按钮开关 | 30,590 | 150102 pushbutton |
| 旋转开关 | 29,924 | 150105 rotary |
| 快动/限位开关 | 26,056 | 150201 snap / 150202 limit |
| 拨动开关 | 24,031 | 150103 toggle |
| 翘板开关 | 22,390 | 150106 rocker |
| 拨码开关 | 3,308 | 150107 dip |
| 小键盘开关 | 3,296 | 150109 mechanical_key |
| 滑动开关 | 1,492 | 150104 slide |
| 键锁开关 | 949 | 150108 keylock |
| 指轮/按动滚轮开关 | 1,023 | 150111 thumbwheel |
| 磁簧开关 | 166 | 150301 reed |

**合计**：143,225 行（`category2_in` 命中）

---

## 4. G2 · category_in 补充（7 字面）

覆盖 `category` 非空、`category2` 为空或未命中 G1 的存量：

| category | 行数 | 说明 |
|----------|-----:|------|
| DIP/SIP | 1,039 | 678 行已有 c2=拨码开关（G1 已覆盖）；297 行 c2=NULL 靠本组 |
| 轻触开关、轻推开关 | 608 | → 150101 tactile |
| 基础型/快动型/限制型 | 524 | → snap/limit，classify 再拆 |
| 拨动开关 | 338 | 205 行 c2=NULL |
| 按钮开关 | 280 | 119 行 c2=NULL |
| 滑块开关 | 22 | c2 无对应叶，仅 category |
| 旋转开关 | 51 | 17 行 c2=NULL |

**不含**：`开关配件`、`模拟开关芯片`、`开关控制器`、`热熔断路器/开关/保险丝`、`紧急停止板/盖子`。

---

## 5. 明确不纳入（v1 文档 · 不进白名单）

| 类目 | 行数 | 原因 |
|------|-----:|------|
| 开关式稳压器或控制器 | 69,518 | PMIC |
| 复用器或开关 | 15,708 | 模拟/逻辑 mux |
| 射频/微波开关 | 2,042 | RF IC |
| 插槽式开关 | 1,744 | 多为光敏/光电传感器；schema 无 Slot |
| 特殊开关 | 1,100 | 语义过宽 |
| 其他开关 | 498 | v1.5.28 无 other_switch L3 |
| 光纤开关 | 359 | schema 无 L3 |

---

## 6. 基线指标（prod 探针 · 2026-06-09）

| 指标 | 值 |
|------|---:|
| gate_pass（distinct id） | **144,273** |
| G1 category2 行 | 143,225 |
| G2 纯补充增量 | ~1,048 |

探针需 `SET enable_local_shuffle_agg=false`（StarRocks 4.0.2 GROUP BY 规避）。

---

## 7. classify 阶段

详见 [CLASSIFY_DESIGN.md](CLASSIFY_DESIGN.md)（`switch_icpdf_*` · 24 条 classify 规则）。

---

## 8. 命令

```bash
cd sql_scripts/test/switch
python seed/gen_rule_csv.py
python audit/probe_gate.py   # 待建
```

CSV 产出：[`seed/dim_l3_classify_rule_switch.csv`](seed/dim_l3_classify_rule_switch.csv)（当前仅 gate 2 行）。
