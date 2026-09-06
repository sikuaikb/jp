# filter · 分类草案商城核对（阶段 2）

> 生成日期：2026-05-27  
> 样本表：[`class_sample_v1_2026-05-27.csv`](class_sample_v1_2026-05-27.csv)（36 行）  
> 核对表：[`filter_class_review_2026-05-27.csv`](filter_class_review_2026-05-27.csv)（请填「商城_L2_L3」「判定结论」）

## 抽样分布（每 L3 最多 5 条）

| l3_code | 样本数 |
|---------|--------|
| `cavity_filter` | 5 |
| `emi_common_mode_filter` | 5 |
| `emi_power_line_filter` | 5 |
| `feedthrough_capacitor` | 5 |
| `ferrite_bead` | 5 |
| `lc_passive_filter` | 5 |
| `piezoelectric_resonator_filter` | 1 |
| `saw_filter` | 5 |

## 判定结论（四选一）

- `consistent` — 商城与我方一致
- `mall_inconsistent` — 得捷/芯查查互不一致，暂不动规则
- `signal_missing` — 源端无区分信号，不强写规则
- `our_rule_gap` — 源有信号、我方 L3 错 → 改规则

## 门控

- `our_rule_gap` 比例须 **≤ 30%** 方可进入阶段 3

## 填写后统计（手工或脚本）

| 判定结论 | 条数 |
|----------|------|
| consistent | |
| mall_inconsistent | |
| signal_missing | |
| our_rule_gap | |
| **our_rule_gap %** | |

## 优先核对（小类 / 争议映射）

1. `lc_passive_filter` — DSL 线路低通
2. `cavity_filter` — 螺旋 + 射频
3. `piezoelectric_resonator_filter` — 陶瓷 1 条
4. `emi_common_mode_filter` — EMI/RFI LC/RC 网络（抽 5 条即可）

## 评审纪要（2026-05-27）

用户完成全量商城核对后，按 6 大群组汇报，映射如下：

| 群组 | 商城 L3 描述 | 我方 L3 | 判定结论 |
|------|-------------|---------|---------|
| 通信/DSL滤波器与语音分离器 | POTS/xDSL 线路低通LC分路 | `lc_passive_filter` (130201) | consistent |
| 射频与微波滤波器 | RF带通/高通/低通/带阻，螺旋 | `cavity_filter` (130402) | consistent |
| EMI/电源线滤波器 | AC电源线LC滤波模块 | `emi_power_line_filter` (130302) | consistent |
| EMI/RFI 共模与总线 | 共模扼流/LC RC网络 | `emi_common_mode_filter` (130301) | consistent |
| 铁氧体磁珠与芯片 + 馈通式电容器 | 磁珠/馈通 EMI 抑制 | `ferrite_bead`/`feedthrough_capacitor` (130303/130304) | consistent |
| SAW/陶瓷/声学谐振 | SAW/BAW/陶瓷谐振 | `saw_filter`/`piezoelectric_resonator_filter` (130101/130103) | consistent |

## 统计结果

| 判定结论 | 条数 |
|----------|------|
| consistent | 36 |
| mall_inconsistent | 0 |
| signal_missing | 0 |
| our_rule_gap | 0 |
| **our_rule_gap %** | **0 %** |

## 结论

- [x] 核对完成（2026-05-27，用户人工审核）
- [x] our_rule_gap = 0 % ≤ 30%
- [x] **可进入阶段 3**（属性 dim 标准化）
