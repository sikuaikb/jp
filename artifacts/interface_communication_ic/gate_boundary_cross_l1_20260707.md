# interface_communication_ic · icpdf 跨 L1 gate 边界（20260707）

## 重跑结果（去争用后）

| 指标 | v3（争用） | v4（本次） |
|------|-----------|-----------|
| 沙盒 classify SKU | 47,706 | **44,271** |
| gate 内未分类 | — | **0 / 44,271** |
| EAV / L2 行数 | 47,706 | **44,271** |
| Step 0.2 新增争用（vs logic/isolator） | 4 处 BLOCKER | **0 处** |

`validate_cross_l1_gate_overlap.py` 仍报 prod 内 **15 处历史重叠**（mcu/mpu/dsp、resistor/circuit_protection 等），与 ific 无关；**ific 不再新增争用**。

---

## 一、ific 侧已删除（gate + classify）

### Gate（`gate_config.py` → `gate_interface_communication_ic_icpdf_v1`）

| 删除项 | 原归属 L1 | 说明 |
|--------|----------|------|
| G1 `category2_in` · `电平转换器` | **logic_ic** | prod 83% → `level_translator` |
| G1 `category2_in` · `隔离放大器` | **isolator** | prod 100% → `isolated_amplifier` |
| G2 `category_in` · `接口隔离器` | **isolator** | prod 99.9% → isolator 各 L3 |
| G2 `category_in` · `隔离放大器` | **isolator** | 同上 |
| G2 `category_in` · `电压电平转换器` | **logic_ic** | prod 47% → `level_translator` |

**保留的 ific icpdf gate：**

- G1：`线路驱动器或接收器`、`串行 IO/通信控制器`、`网络接口`、`光纤收发器`、`光纤发送器`、`调制解调器`、`其他接口集成电路`
- G2：`以太网控制器`、`以太网接口芯片`、`USB收发器`

### Classify（`classify_config.py` · 已从 CSV 移除 5 条 rule）

| rule_id | 命中键 | 删除原因 |
|---------|--------|----------|
| `interface_communication_ic_icpdf_isol_cat_v1` | `category=接口隔离器` | isolator 专叶 |
| `interface_communication_ic_icpdf_isol_amp_c2_v1` | `category2=隔离放大器` | isolator 专叶 |
| `interface_communication_ic_icpdf_isol_amp_cat_v1` | `category=隔离放大器` | isolator 专叶 |
| `interface_communication_ic_icpdf_level_cat_v1` | `category=电压电平转换器` | logic_ic 专叶 |
| `interface_communication_ic_icpdf_level_c2_v1` | `category2=电平转换器` | logic_ic 专叶 |

**保留的跨边界 note 专规（不争 gate 叶）：**

| rule_id | 说明 |
|---------|------|
| `interface_communication_ic_icpdf_isol_bus_note_v1` | note 命中隔离总线 → `isolated_bus_transceiver`（79 SKU） |
| `interface_communication_ic_icpdf_i2c_note_v1` | note I2C/SMBus → `i2c_buffer_repeater`（319 SKU） |

---

## 二、其他 L1：**不需要去掉任何 gate 规则**

合并 blocker 来自 **ific 新增争用**，不是 logic/isolator 多占。以下 **保持 prod 现状**：

### logic_ic · `gate_logic_ic_icpdf_v1`

| field | 保留 category | ific 不得再收 |
|-------|--------------|-------------|
| `category_in` | 含 **`电压电平转换器`** | ✓ 已从 ific G2 删除 |
| `category2_in` | 含 **`电平转换器`** | ✓ 已从 ific G1 删除 |

相关 classify（prod 已有，**勿删**）：`logic_ic_icpdf_p2_level_v1`、`logic_ic_icpdf_p2e_level_v1` 等 → `level_translator`。

### isolator · `gate_isolator_icpdf_v1`

| field | 保留 category | ific 不得再收 |
|-------|--------------|-------------|
| `category_in` | **`接口隔离器`、`隔离放大器`**、光耦 | ✓ 已从 ific G2 删除 |
| `category2_in` | **`隔离放大器`**、光耦合器 | ✓ 已从 ific G1 删除 |

相关 classify（prod 已有，**勿删**）：`isolator_amp_cat_v1`、`isolator_dig_*` 等。

---

## 三、L3 分布变化（v4 沙盒）

| L2 | 主要 L3 | SKU |
|----|---------|-----:|
| serial_bus | rs485_rs422 | 15,428 |
| bus_switch | other_serial | 15,328 |
| serial_bus | rs232 | 4,163 |
| bus_switch | bus_switch_mux | 3,946 |
| ethernet | ethernet_phy | 2,835 |
| highspeed | lvds_serdes | 1,081 |
| level_shifter | **i2c_buffer_repeater** | **319**（原 bulk level_shifter 1,406 已不在 gate） |
| digital_isolation | **isolated_bus_transceiver** | **79**（原 bulk digital_isolator 1,524 已不在 gate） |

`digital_isolator` / `level_shifter` 物理列在 L2 宽表中仍存在，但 icpdf 不再有 bulk gate 路径填充。

---

## 四、合并预演预期

- Step 0.2：ific overlay 后 **不再**与 logic_ic / isolator 争用上述 4 category。
- Step 5 仿真：ific icpdf 行数应接近 **44,271**（与沙盒 gate 一致），而非旧版 47,706。
- **无需** logic_ic / isolator owner 改 gate；仅需合并 ific 分类/属性 dim。

---

## 五、DigiKey `专用` · connector 争用（20260707 追加）

### 问题

`validate_cross_l1_gate_overlap.py` G1：`category_in` · `专用` 同时出现在

- `connector` · `gate_connector_digikey_backplane_v1`
- `interface_communication_ic` · `gate_interface_communication_ic_digikey_v1`

### prod 全局决选（digikey · category=专用 · n=41,749 · category2 100% NULL）

| 归属 L1 | SKU | 典型 rule |
|---------|-----:|-----------|
| **connector** | 38,983 | `connector_dk_dedicated_backplane_v1` · phase 2 |
| **interface_communication_ic** | 2,766 | `interface_communication_ic_dk_*` · phase 3 专规（PCIe/I2C/SPI/USB…） |

决选靠 **全局 classify phase**（ific phase 3 > connector phase 2），不是 gate 单 L1 隔离。

### ific 修复（不改 connector）

| 动作 | 说明 |
|------|------|
| 从 `gate_interface_communication_ic_digikey_v1` **`category_in` 移除 `专用`** | 消除 G1 静态重叠 |
| 新增 `gate_interface_communication_ic_digikey_spec_null_c2_v1` | `category_with_null_category2_in` · `["专用"]` · 承接 gate 入口 |
| 保留既有 `gate_exclude_note_cn` 专规 | 排除 `%连接器%`、接线板、智能卡等非 IC |

**connector 侧：不需要删 `专用`**（背板 taxonomy 专叶 · `dedicated_backplane_connector`）。
