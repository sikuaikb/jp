# ecloud storage 阶段 5.6 · prefix 精修（商城 r2 反馈）

日期：2026-07-09  
触发：`ecloud_mall_verify_r2_20260709.md` 8 条 N + 2 条 CY14 P

## 规则变更（`seed/ecloud_classify_config.py`）

### 新增 4 条高优先级规则（priority 195–198）

| rule_id | 目标 L3 | partno | 说明 |
|---------|---------|--------|------|
| `storage_ec_fram_pn_emmc_v1` | emmc | `^SM66` | Ferri-eMMC 全族（非 SRAM） |
| `storage_ec_fram_pn_nand_cypress_v1` | nand_flash | `^(S34ML\|S34SL\|S34MS)` | Cypress/SkyHigh 并行 NAND |
| `storage_ec_fram_pn_spi_sram_v1` | sram | `^(23A\|23K\|23LC\|CY14)` | SPI SRAM / nvSRAM |
| `storage_ec_fram_pn_at28_eeprom_v1` | eeprom | `^AT28` | 并行 EEPROM（非 AT27 EPROM） |

### 收窄既有规则

| 规则 | 变更 |
|------|------|
| `storage_ec_fram_pn_fram_v1` | 移除 `CY14`（nvSRAM） |
| `storage_ec_fram_pn_sram_v1` | 移除 `SM66`（eMMC 误伤） |
| `storage_ec_fram_pn_eeprom_v1` | 移除 `23K` |
| `storage_ec_fram_pn_eprom_v1` | 移除 `AT28` |
| `storage_ec_fram_pn_nand_v1` | 补 `S34ML\|S34SL\|S34MS` |
| `storage_ec_fram_pn_parallel_v1` | 移除 `S34SL` |
| `storage_ec_fram_pn_serial_v1` | 移除 `S34M`、`23A`、`23LC`（防与 NAND/SRAM 冲突） |

规则子句：**75 → 83**

## 新规则命中量

| rule_id | 命中 |
|---------|-----:|
| storage_ec_fram_pn_emmc_v1 | 100 |
| storage_ec_fram_pn_nand_cypress_v1 | 230 |
| storage_ec_fram_pn_spi_sram_v1 | 65 |
| storage_ec_fram_pn_at28_eeprom_v1 | 102 |

## 商城 r2 误判复验（10/10 ✅）

| 料号 | 精修前 L3 | 精修后 L3 |
|------|-----------|-----------|
| SM662GEA-BD / SM662GEB-BD | sram | **emmc** |
| S34ML08G201TFA003 | serial_nor_flash | **nand_flash** |
| S34SL02G200×2 | parallel_nor_flash | **nand_flash** |
| 23A640-I/P | serial_nor_flash | **sram** |
| AT28HC256×2 | otp_eprom | **eeprom** |
| CY14E116L / CY14B104L | fram | **sram** |

## 分类回归

| 指标 | 精修前 | 精修后 |
|------|-------:|-------:|
| 分类命中 | 34,043 | **34,043** |
| 未分类 | 0 | **0** |
| managed_flash_module/emmc | 0 | **100**（L2 UNION ✅） |

L2 分布变化（ecloud 沙盒 5 表）：
- volatile_ram/sram：+65（spi_sram），−102（SM66 迁出）
- flash_memory/nand_flash：+187（cypress NAND）
- rewritable_rom/eeprom：+12（AT28）
- nv_ram/fram：−24（CY14 迁出）

## 商城一致率（r2 样本复算）

| 指标 | r2 修前 | r2 修后 |
|------|--------:|--------:|
| Y | 43 | **51** |
| N | 8 | **0** |
| P | 7 | **7** |
| 一致率 Y/(Y+N) | 84.3% | **100%** |

P 仍为：47L16T EERAM、军规/内部 SKU 兜底等，待业务裁决。

## 残留

- ~~`managed_flash_module/emmc` L2 UNION~~ → 已完成（见 `ecloud_emmc_l2_20260709.md`）
- ~~`capacity_gb` / `nand_cell_type` emmc 源稀疏~~ → 料号派生 100%（见 `ecloud_emmc_l2_20260709.md`）
- `host_interface_type` memory_controller 仍 0%（FIFO 豁免，见 `qa_audit_report_20260709.md`）

## 重跑

```bash
bash sql_scripts/test/storage/run_test.sh
```
