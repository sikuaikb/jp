# ecloud storage 阶段 5.5 属性 gap 迭代（20260709）

## 根因（§8.3 + 空值四段式 §2-4）

| 问题 | 根因 | 修复 |
|---|---|---|
| `capacity_mb` / `capacity_kbit` L2 列 0% | 规则写入 `capacity_gb`，schema 按 L2 隔离（flash→mb，rom→kbit） | 拆分为正确 `std_attr_code` + `dim_unit_factor` 换算 |
| `interface_type` 0% | `存储器接口` 误映射 `host_interface_type`；FIFO 无此 L2 列 | 改映射 `interface_type` + `IFACE_MAP` |
| `host_interface_type` 0% | ecloud FIFO 源无主机接口键 | **源端缺失**，登记豁免；容量落 L3 `storage_capacity_mb`→ext |

## 规则变更（17 → 23 条）

新增/修改于 `seed/ecloud_attr_extract_config.py`：

- `capacity_mb` ← `存储容量(Mb)` / `存储容量(Mbit)`
- `capacity_kbit` ← `存储容量(Mb)` / `存储容量`
- `capacity_gb` ← 保留给 `volatile_ram`（原错误命名已修正）
- `interface_type` ← `存储器接口`（主）/ `接口类型`（备）
- `storage_capacity_mb` ← FIFO `other_storage` L3（ext_attributes）

## L2 宽表 P0 对比

| L2 | 指标 | 迭代前 | 迭代后 |
|---|---|---:|---:|
| flash_memory | capacity_mb | 0% | **93.2%** |
| flash_memory | interface_type | 0% | **93.2%** |
| rewritable_rom | capacity_kbit | 0% | **94.9%** |
| rewritable_rom | interface_type | 0% | **93.1%** |
| nv_ram | capacity_kbit | 0% | **90.3%** |
| nv_ram | interface_type | 0% | **90.3%** |
| memory_controller | host_interface_type | 0% | 0%（FIFO 豁免） |
| memory_controller | ext storage_capacity_mb | — | **98.6%** |

EAV 总行：236,522 → **265,646**（+29,124）

## 残留 gap（下轮）

§8.3 探针未覆盖高频键（`probe_ecloud_attr_gap.py`）：

| 键 | 命中 | 建议 |
|---|---:|---|
| 最大时钟频率(MHz) | 14,719 | P1：`max_clock_freq_mhz`（PSRAM/FRAM L3） |
| 写周期时间-字，页 | 17,298 | P2：EPROM 族 L3 |
| 数据速率 / 总线方向 | 2,781 | FIFO L3 ext 补强 |
| 4,623 未分类 F-RAM | — | 分类规则迭代 |

## 探针命令

```bash
source sql_scripts/local.env
python sql_scripts/test/storage/audit/probe_ecloud_attr_gap.py
```
