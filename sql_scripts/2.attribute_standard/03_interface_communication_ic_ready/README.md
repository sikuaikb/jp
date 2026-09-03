# 03_interface_communication_ic_ready · ICPDF + DigiKey 双源

L1 编号 `03`（`interface_communication_ic` / `interface_communication_ic_schema_v1.5.09`）。

| L2 | 说明 |
|----|------|
| `serial_bus_transceiver` | RS232/485/CAN/LIN 等串行总线收发器 |
| `ethernet_interface` | 以太网 PHY / 交换 |
| `highspeed_serial_interface` | USB/PCIe/LVDS/HDMI 等高速串行 |
| `digital_isolation_interface` | 隔离总线接口 |
| `level_shifter_signal_conditioning` | 电平转换 / I2C 缓冲 |
| `bus_switch_mux` | 总线开关 / 模拟开关（接口 path） |

沙盒验收：`python3 sql_scripts/test/interface_communication_ic/run_test_interface_communication_ic.py`  
合并 SOP：`.cursor/skills/dim-attr-std-merge/SKILL.md`（须先完成分类 merge）。
