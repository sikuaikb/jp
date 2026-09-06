# switch · ICPDF classify v1 设计

真源：[`seed/classify_config.py`](seed/classify_config.py) · Gate：[`GATE_DESIGN.md`](GATE_DESIGN.md)

**命名**：classify → `switch_icpdf_*`；gate → `gate_switch_icpdf_v1`。

## 规则分层

| 层级 | phase | 说明 |
|------|------:|------|
| **类目 1:1** | 2 | `category2_eq` 9 叶 + `category_eq` 5 补充 |
| **混合叶专规** | 3 | 快动/限位、DIP/SIP、基础型 note 双字句 |
| **Fallback** | 2 | 快动/限位叶 → limit；基础型 c2=NULL → snap |

## phase 2 · category2 直接映射

| category2 | L3 | rule_id |
|-----------|-----|---------|
| 按钮开关 | 150102 pushbutton | `switch_icpdf_pushbutton_c2_v1` |
| 旋转开关 | 150105 rotary | `switch_icpdf_rotary_c2_v1` |
| 拨动开关 | 150103 toggle | `switch_icpdf_toggle_c2_v1` |
| 翘板开关 | 150106 rocker | `switch_icpdf_rocker_c2_v1` |
| 拨码开关 | 150107 dip | `switch_icpdf_dip_c2_v1` |
| 滑动开关 | 150104 slide | `switch_icpdf_slide_c2_v1` |
| 键锁开关 | 150108 keylock | `switch_icpdf_keylock_c2_v1` |
| 指轮/按动滚轮开关 | 150111 thumbwheel | `switch_icpdf_thumbwheel_c2_v1` |
| 磁簧开关 | 150301 reed | `switch_icpdf_reed_c2_v1` |
| 小键盘开关 | 150109 mechanical_key | `switch_icpdf_mechanical_key_c2_v1` |

## phase 2 · category 补充

| category | L3 | 要点 |
|----------|-----|------|
| 轻触开关、轻推开关 | 150101 tactile | **priority 6**，先于小键盘 c2，解决 327 行重叠 |
| 滑块开关 | 150104 slide | category-only |
| 按钮/拨动/旋转开关 | 同名 L3 | c2=NULL 存量 |
| DIP/SIP | 150107 dip | 默认；旋转/滑动见 phase 3 |

## phase 3 · 混合叶

### 快动/限位开关（26,056 行）

- prajson2 `开关类型` ≈ `SNAP ACTING/LIMIT SWITCH`（~99%），**无法在 JSON 层拆分**
- note 专规：limit（~174）/ snap（~355）
- **fallback** `switch_icpdf_snap_limit_fb_v1` → **150202 limit**（对齐 DK「限位开关」主类策略）

### 基础型/快动型/限制型（524 行）

- 410 行 c2=快动/限位 → 由 snap/limit 规则覆盖
- 109 行 c2=NULL → `switch_icpdf_base_type_fb_v1` → snap

### DIP/SIP（1,039 行）

| 条件 | L3 |
|------|-----|
| DIP/SIP + c2=旋转开关 | rotary（55） |
| DIP/SIP + c2=滑动开关 | slide（8） |
| DIP/SIP 其余 | dip |

## v1 Deferred（无规则 · 仓内≈0）

| L3 | 原因 |
|----|------|
| 150302 hall_effect_switch | 霍尔多在 sensor 类目 |
| 150203 interlock_safety_switch | 互锁 note/category ≈0 |
| 150110 navigation_joystick_switch | 导航/操纵杆 ≈0 |

## 决选

`phase DESC` → `rule_priority ASC` → `l3_code ASC`（与 `dwd_component_class.sql` 一致）。

## 命令

```bash
cd sql_scripts/test/switch
python run_test_switch.py          # 阶段 1：仅 test_dim / test_dwd
python audit/probe_classify.py     # 可选：只读 prod param 模拟
```

## v1 验收（test_dwd · 2026-06-09）

| 指标 | 值 |
|------|---:|
| gate_pass | 144,273 |
| classified | 144,273（100%） |
| deferred L3 | hall / interlock / navigation（0 行） |

## 已知边界

- gate 内 ~19 行 `category2=特殊开关/其他开关` 且 category=NULL → v1 可能无 classify 产出
- `category=旋转开关` + `c2=光学位置编码器`（5 行）→ 误归 rotary，待专规
- `紧急停止板/盖子` + `c2=小键盘`（18 行）→ 归 mechanical_key（配件，非蘑菇头本体）
