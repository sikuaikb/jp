# logic_ic · DigiKey Gate v1.1

> 真源：[`seed/gate_config.py`](seed/gate_config.py)  
> dim 产出：`python seed/gen_rule_csv.py` → `seed/dim_l3_classify_rule_logic_ic.csv`  
> 基线：`python audit/probe_gate.py`

分类树：`foundation/dim_l3_classify_all.sql`（`22xxxx`，3 L2 · 13 L3）

## 1. 公式

```text
gate_pass = G1(category_in) − X2(category NOT LIKE)
```

- **G1**：dim `category_in`，按 L2 分 3 行 gate 规则，引擎 **OR** 连接
- **X2**：`NOT LIKE '%评估板%'`、`NOT LIKE '%开发套件%'`

## 2. G1 · category_in（v1.1）

| rule_id | L2 | categories | 探查 SKU |
|---------|-----|------------|--------:|
| `gate_logic_ic_digikey_combinational_v1` | `combinational_logic` | 门和反相器、门和反相器-多功能、比较器、**奇偶校验发生器和校验器**、信号开关…、专用逻辑器件 | ~10,075 |
| `gate_logic_ic_digikey_sequential_v1` | `sequential_logic` | 触发器、移位寄存器 | ~7,336 |
| `gate_logic_ic_digikey_buffer_v1` | `signal_buffer_driver` | 缓冲器，驱动器，接收器，收发器 | ~2,180 |

**gate_pass 基线（v1.1）**：**19,591** SKU（+163 奇偶校验）

**classify v1**：33 条 classify 规则，验收 **PASS**（见 [`CLASSIFY_DESIGN.md`](CLASSIFY_DESIGN.md)）

## 3. 明确不纳入

| category | 原因 |
|----------|------|
| `驱动器，接收器，收发器` | RS232/RS485/CAN → `interface_communication_ic` |
| `信号缓冲器、中继器、分离器` | 加速计缓冲/Retimer，非逻辑缓冲 IC |
| `FIFO 存储器` | `storage` |
| `多谐振荡器` | `clock_timing` |
| `通用总线功能` | 仅 4 SKU，本期不做 |
| `CPLD…` / `FPGA…` | `fpga_cpld` |
| `可编程定时器和振荡器` | `clock_timing` |
| `编码器，解码器，转换器` / `编码器 - 工业` | 工业编码器硬件，非数字编解码 IC |

## 4. classify 状态（v1 · PASS）

详见 [`CLASSIFY_DESIGN.md`](CLASSIFY_DESIGN.md)。L3 分布摘要：

| L3 | SKU |
|----|----:|
| `basic_logic_gate` | 9,045 |
| `flip_flop_latch` | 5,337 |
| `buffer_driver` | 2,186 |
| `shift_register` | 1,999 |
| `digital_comparator` | 364 |
| `encoder_decoder` | 279 |
| `bus_transceiver` | 206 |
| `mux_demux` | 70 |
| `bus_switch` | 62 |
| `alu_adder` | 31 |
| `register` | 11 |
| `counter_divider` | 1 |
| `level_translator` | 0（无 DK 叶子） |

## 5. 命令

```bash
cd sql_scripts/test/logic_ic
python seed/gen_rule_csv.py
python load_seed_logic_ic.py --db test_dim
python audit/probe_gate.py
python run_test_logic_ic.py
```
