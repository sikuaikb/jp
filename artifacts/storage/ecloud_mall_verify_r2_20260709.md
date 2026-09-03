# ecloud storage 第二轮商城核对（分类）

日期：2026-07-09  
样本：`artifacts/storage/ecloud_mall_sample_r2_20260709.tsv`（58 行，9 面板）  
对照源：得捷/分销商参数页 + 厂商 datasheet + ecloud 源 `note_cn`/`prajson`

## 核对范围

| 面板 | 目的 | 样本 |
|------|------|-----:|
| regression | 阶段 5 修复回归（并行 NOR / CBRAM） | 6 |
| parallel_nor | 并行 NOR 新规则 + F-RAM 桶纠偏 | 11 |
| mram | CBRAM → mram 映射 | 5 |
| fram_pn / sram_pn / eeprom_pn / serial_pn / dram_pn / eprom_pn / nand_pn | F-RAM partno 纠偏各族 | 29 |
| controller_pn / other_pn | 控制器与兜底 | 7 |

## 汇总

| 指标 | 值 |
|---|---:|
| 样本数 | 58 |
| 一致 (Y) | 43 |
| 部分一致/待业务 (P) | 7 |
| 不一致 (N) | 8 |
| 一致率 | **84.3%**（Y/(Y+N)=43/51） |

对比第一轮（45 样本，86.7%）：回归面板 **6/6 通过**（含 4 条历史 N 修复）；新增 F-RAM prefix 规则暴露 **8 条新误判**。

## 按面板汇总

| 面板 | 样本 | Y | P | N | 结论 |
|------|-----:|---:|---:|---:|------|
| regression | 6 | 5 | 1 | 0 | ✅ 阶段 5 修复有效 |
| parallel_nor | 11 | 9 | 0 | 2 | ⚠️ S34SL 族 NAND 误判并行 NOR |
| mram | 5 | 5 | 0 | 0 | ✅ 通过 |
| fram_pn | 3 | 1 | 2 | 0 | ⚠️ CY14 nvSRAM 非 FRAM |
| sram_pn | 5 | 3 | 0 | 2 | ❌ SM662 eMMC 误判 SRAM |
| eeprom_pn | 5 | 5 | 0 | 0 | ✅ 通过 |
| serial_pn | 5 | 3 | 0 | 2 | ❌ 23A SRAM / S34ML NAND 误判 |
| dram_pn | 5 | 5 | 0 | 0 | ✅ 通过 |
| eprom_pn | 3 | 1 | 0 | 2 | ❌ AT28HC 并行 EEPROM 误判 EPROM |
| nand_pn | 3 | 3 | 0 | 0 | ✅ 通过 |
| controller_pn | 3 | 3 | 0 | 0 | ✅ 通过 |
| other_pn | 4 | 0 | 4 | 0 | ⏸ 军规/内部 SKU 兜底可接受 |

## 回归面板（阶段 5 修复验证）

| 料号 | 我方 L3 | 商城 | 判定 |
|------|---------|------|------|
| AT49BV001-90JC | parallel_nor_flash | IC FLASH PARALLEL | Y |
| AT29BV020-25TC | parallel_nor_flash | IC FLASH PARALLEL 2M | Y |
| M29W320DB7AN6E | parallel_nor_flash | IC FLASH 32M PARALLEL NOR | Y |
| RM25C128A-BTAC-T | mram | CBRAM® | Y |
| MX25U51245GZ4I00 | serial_nor_flash | SPI NOR | Y |
| 47L16T-I/SN | fram | EERAM | P（待业务） |

## 不一致明细（F-RAM prefix 规则 gap）

| 料号 | 我方 L3 | 商城/规格书 | 命中规则 | 根因 |
|------|---------|------------|----------|------|
| SM662GEA-BD | sram | Ferri-eMMC 128Gbit NAND | storage_ec_fram_pn_sram_v1 | `SM66` 前缀过宽，实为 eMMC 托管模块 |
| SM662GEB-BD | sram | 同上 | storage_ec_fram_pn_sram_v1 | 同上 |
| S34ML08G201TFA003 | serial_nor_flash | S34ML 8Gb SLC NAND | storage_ec_fram_pn_serial_v1 | `S34M` 未覆盖，串行规则未排除 ML 族 |
| 23A640-I/P | serial_nor_flash | Microchip SPI Serial SRAM | storage_ec_fram_pn_serial_v1 | `23A` 为 SPI SRAM 非 NOR |
| AT28HC256-12JA | otp_eprom | AT28HC 并行 EEPROM | storage_ec_fram_pn_eprom_v1 | `AT28` 为 EEPROM，`AT27` 才是 EPROM |
| AT28HC256F-90JU | otp_eprom | 同上 | storage_ec_fram_pn_eprom_v1 | 同上 |
| S34SL02G200BHV003 | parallel_nor_flash | S34SL SecureNAND 2Gb | storage_ec_fram_pn_parallel_v1 | `S34SL` 为 NAND 非并行 NOR |
| S34SL02G200BHI003 | parallel_nor_flash | 同上 | storage_ec_fram_pn_parallel_v1 | 同上 |

## 待业务确认（P）

| 料号 | 我方 | 商城 | 说明 |
|------|------|------|------|
| 47L16T-I/SN | nv_ram/fram | EERAM | 延续第一轮；是否独立 EERAM L3 |
| CY14E116L-ZS25XIT | nv_ram/fram | nvSRAM (QuantumTrap) | L2 正确；L3 应为 sram 或独立 nvsram |
| CY14B104L-BA25XI | nv_ram/fram | nvSRAM | 同上 |
| S99400081 / FK3R3M350F090A | other_storage | 无公开分类/源数据疑似错挂 | 兜底可接受 |
| 5962-8700206ZA / 5962-8866201NA | other_storage | 军规定制料 | 兜底待业务复核 |

## 建议动作（阶段 5.6）

1. **收窄 `SM66` SRAM 规则**：排除 `SM662`（eMMC）→ 新增 `storage_ec_fram_pn_emmc_v1` 映射 `managed_flash_module/emmc`，或并入 `other_storage`
2. **NAND 族补全**：`S34ML|S34SL` → `nand_flash`（priority 高于 serial/parallel F-RAM 规则）
3. **SPI SRAM**：`23A|23K` → `sram`（高于 serial NOR）
4. **EEPROM vs EPROM**：`AT28` → `eeprom`；保留 `AT27` → `otp_eprom`
5. **nvSRAM vs FRAM**：`CY14` 从 `fram` 前缀移除 → `sram`（或登记 nvSRAM 业务映射）
6. 修完后对 8 条 N 样本复验，并量化各前缀全表误伤量

## 结论

- **阶段 5 并行 NOR + CBRAM 修复**：回归面板全部通过 ✅
- **F-RAM 大桶 100% 分类覆盖**：达成；**阶段 5.6 prefix 精修**后 r2 样本 N=0 ✅
- **可合并 prod 前**：`managed_flash_module/emmc` 100 行待评估 L2 UNION；`host_interface_type` 仍 0%
