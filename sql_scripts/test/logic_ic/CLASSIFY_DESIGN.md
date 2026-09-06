# logic_ic · classify v1 规则说明

真源：[`seed/classify_config.py`](seed/classify_config.py)（**35 条 rule_id**）

**命名（CONTRIB Step 2）**：classify → `logic_ic_dk_*`；gate → `gate_logic_ic_*`（对齐 `amplifier_dk_*`）。

## 决选

`phase DESC` → `rule_priority ASC` → `l3_code ASC`

## 规则分层

### 1:1 叶子（phase 2 · priority 10）

| rule_id | DK category | L3 |
|---------|-------------|-----|
| `logic_ic_dk_gate_v1` | 门和反相器 | `basic_logic_gate` |
| `logic_ic_dk_config_gate_v1` | 门和反相器 - 多功能，可配置 | `basic_logic_gate` |
| `logic_ic_dk_comparator_v1` | 比较器 | `digital_comparator` |
| `logic_ic_dk_parity_v1` | 奇偶校验发生器和校验器 | `encoder_decoder` |
| `logic_ic_dk_flip_flop_v1` | 触发器 | `flip_flop_latch` |
| `logic_ic_dk_shift_register_v1` | 移位寄存器 | `shift_register` |

### 信号开关叶 · note 专规（phase 3）

| priority | rule_id | note 信号 | L3 |
|--------:|---------|-----------|-----|
| 8 | `logic_ic_dk_bus_switch_v1` | 总线开关/交点开关 | `bus_switch` |
| 9 | `logic_ic_dk_decoder_v1` | 解码器/多路分解 | `encoder_decoder` |
| 8 | `logic_ic_dk_mux_encoder_v1` | 优先顺序编码器 | `encoder_decoder` |
| 10 | `logic_ic_dk_mux_v1` | 多路复用/数据选择器 | `mux_demux` |
| 99 | `logic_ic_dk_mux_fb_v1` | fallback | `mux_demux` |

### 专用逻辑器件 · note 专规

| priority | rule_id | note 信号 | L3 |
|--------:|---------|-----------|-----|
| 8 | `logic_ic_dk_special_counter_v1` | 计数器/分频 | `counter_divider` |
| 9 | `logic_ic_dk_special_adder_v1` | 加法器/ALU | `alu_adder` |
| 10 | `logic_ic_dk_special_regbuf_v1` | 寄存缓冲/DDR | `buffer_driver` |
| 11 | `logic_ic_dk_special_flipflop_v1` | 触发器/锁存 | `flip_flop_latch` |
| 12 | `logic_ic_dk_special_register_v1` | 寄存器 | `register` |
| 13 | `logic_ic_dk_special_comparator_v1` | 比较器 | `digital_comparator` |
| 14 | `logic_ic_dk_special_transceiver_v1` | 收发器 | `bus_transceiver` |
| 15 | `logic_ic_dk_special_buffer_v1` | 缓冲/驱动/接收 | `buffer_driver` |
| 99 | `logic_ic_dk_special_fb_v1` | fallback | `buffer_driver` |

### 缓冲/收发叶 · note 专规

| priority | rule_id | note 信号 | L3 |
|--------:|---------|-----------|-----|
| 10 | `logic_ic_dk_buffer_transceiver_v1` | 收发器 | `bus_transceiver` |
| 11 | `logic_ic_dk_buffer_driver_v1` | 缓冲器/线路驱动 | `buffer_driver` |
| 99 | `logic_ic_dk_buffer_fb_v1` | fallback（含 note 空） | `buffer_driver` |

## 零命中 L3

| l3_id | l3_code | 说明 |
|-------|---------|------|
| 220303 | `level_translator` | DK 无独立叶子 |

## 验收

```bash
python run_test_logic_ic.py
```
