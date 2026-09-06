# 08_connector_ready · 连接器属性标准化（icpdf + digikey）

schema: `connector_schema_v1.4.30` · L1: `connector` · 6 张 L2 宽表 · 双源

| L2 | 表名 | prod 行数 (20260702) |
|----|------|----------------------|
| board_wire_interconnect_connector | `dwd.dwd_l2_connector_board_wire_interconnect_connector` | 1,260,525 |
| general_shell_connector | `dwd.dwd_l2_connector_general_shell_connector` | 1,209,806 |
| standard_interface_socket_connector | `dwd.dwd_l2_connector_standard_interface_socket_connector` | 41,892 |
| backplane_ic_socket_connector | `dwd.dwd_l2_connector_backplane_ic_socket_connector` | 709,298 |
| power_terminal_connector | `dwd.dwd_l2_connector_power_terminal_connector` | 210,913 |
| rf_coaxial_connector | `dwd.dwd_l2_connector_rf_coaxial_connector` | 35,221 |

EAV connector: icpdf 1,036,645 id · digikey 2,280,017 id

Runner: `run_attr_std.sh` · `l1_dir connector -> 08_connector_ready` · `SOURCES="icpdf digikey"`
