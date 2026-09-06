# ecloud storage F-RAM 分类缺口迭代（2026-07-09）

## 背景

ecloud `category='存储器'` gate 共 **34,043** 行。阶段 2 后仍有 **4,623** 行未分类，**全部为 `category2='F-RAM'`** 误挂大桶：

- 82.5% 无 prajson
- `存储器格式` / `构架` 几乎全空
- `note_cn` 空 96.5%

无法依赖 phase 3 prajson 规则，需 **双字句** `category2_eq='F-RAM'` + `partno_regexp` 按料号族纠偏。

## 变更

文件：`sql_scripts/test/storage/seed/ecloud_classify_config.py`

### 新增 phase 2 规则（13 条）

| rule_id | 目标 L3 | 策略 |
|---------|---------|------|
| `storage_ec_fram_pn_fram_v1` | nv_ram/fram | 真 FRAM 料号族 |
| `storage_ec_fram_pn_fifo_v1` | other_storage | FIFO |
| `storage_ec_fram_pn_psram_v1` | psram | PSRAM |
| `storage_ec_fram_pn_sram_v1` | sram | SRAM + IDT FIFO-SRAM 前缀 |
| `storage_ec_fram_pn_dram_v1` | dram_sdram | Micron/ISSI DRAM 族 |
| `storage_ec_fram_pn_eeprom_v1` | eeprom | 24/93/BR/CAV 等 EEPROM 族 |
| `storage_ec_fram_pn_eprom_v1` | otp_eprom | EPROM |
| `storage_ec_fram_pn_nand_v1` | nand_flash | NAND |
| `storage_ec_fram_pn_parallel_v1` | parallel_nor_flash | 并行 NOR |
| `storage_ec_fram_pn_serial_v1` | serial_nor_flash | 串行 NOR |
| `storage_ec_fram_pn_nv_other_v1` | other_storage | Dallas NV |
| `storage_ec_fram_pn_controller_v1` | memory_controller_bridge | SM671/S99 控制器 |
| `storage_ec_fram_pn_military_v1` | other_storage | 5962- 军规料（待业务复核） |

### 新增 phase 3 规则（2 条）

| rule_id | 目标 L3 | 说明 |
|---------|---------|------|
| `storage_ec_kv_pcm_v1` | mram | `存储器格式=PCM(PRAM)` ×5 |
| `storage_ec_kv_fram_fuzzy_v1` | fram | `存储器格式` 含 `%FRAM%`（含尾随空格） |

规则子句：**43 → 71**

## 回归结果

| 指标 | 迭代前 | 迭代后 | Δ |
|------|-------:|-------:|--:|
| 分类命中 | 29,420 | **33,594** | +4,174 |
| 未分类 | 4,623 | **449** | −4,174 |
| 命中率 | 86.4% | **98.7%** | +12.3pp |

### F-RAM 桶纠偏分布（新规则贡献）

| L3 | 新规则命中 |
|----|----------:|
| sram | 974 |
| eeprom | 736 |
| serial_nor_flash | 704 |
| dram_sdram | 615 |
| parallel_nor_flash | 468 |
| otp_eprom | 238 |
| nand_flash | 190 |
| fram | 83 |
| other_storage (Dallas) | 70 |
| memory_controller_bridge | 50 |
| other_storage (军规) | 34 |
| fifo | 4 |
| psram | 2 |

### 下游

- EAV：**268,265** 行 / **30,017** 物料（+807 物料）
- L2 五族行数与分类表 **100% 对齐**，`brand_null=0`

## 剩余 449 行（业务边界）

仍为 `category2='F-RAM'`，料号前缀分散、无 prajson/note 信号：

- `M10162`、`QMP29G`、`MX29GL`、`M29F16`、`11LC04`、`34AA02` 等
- 多为低频前缀（每族 ≤4 行），需第二轮 prefix 扩展或上游 category2 修正

**建议**：登记为「ecloud 上游 F-RAM 误挂 + 无结构化信号」边界，不强行兜底 `other_storage`。

## 验收

```bash
bash sql_scripts/test/storage/run_test.sh   # 或分步 run_ecloud_classify/attr/l2
```

- 分类：PASS（未分类 449 < 阈值）
- EAV：PASS
- L2：PASS

---

# 第二轮 prefix 扩展（2026-07-09 续）

## 目标

将第一轮后剩余 **449** 行 F-RAM 误挂料号继续按 partno 族纠偏。

## 变更

在既有 13 条 `storage_ec_fram_pn_*` 规则上 **扩展 partno_regexp**，并新增 2 条：

| rule_id | 目标 L3 | 说明 |
|---------|---------|------|
| `storage_ec_fram_pn_desc_v1` | other_storage | ICDRAM/ICFLASH 等描述性料号、内部 SKU |
| `storage_ec_fram_pn_numeric_v1` | other_storage | 纯数字内部料号 |

主要扩展族（增量覆盖）：

- **SRAM**：`IS65/IS63W/7142/71256/7006-7034/STK15/R1WV/S71K/AK64` 等
- **EEPROM**：`BR25/CG7x/CG8x/11LC/34AA/M95/23K/NV24/AT21CS` 等
- **串行 NOR**：`S26K/S29JL/S70FL/IS49F/MT25T/23LC` 等
- **并行 NOR**：`MX29G/M58BW/JR28F/SST49L/M29F4` 等
- **DRAM**：`EDB4x/IS41C/IS46D/N01L/MT42L/EDF` 等
- **EPROM**：`M27C/M27V/M87C/FM27C` 等
- **NAND**：`NAND1/NAND12/THGAF` 等

规则子句：**71 → 75**

## 回归结果

| 指标 | 第一轮后 | 第二轮后 | Δ |
|------|--------:|--------:|--:|
| 分类命中 | 33,594 | **34,043** | +449 |
| 未分类 | 449 | **0** | −449 |
| 命中率 | 98.7% | **100%** | +1.3pp |

### F-RAM 桶第二轮增量（`storage_ec_fram_pn_*` 规则）

| L3 | 第一轮后 | 第二轮后 | Δ |
|----|--------:|--------:|--:|
| sram | 974 | 1,074 | +100 |
| eeprom | 736 | 860 | +124 |
| serial_nor_flash | 704 | 758 | +54 |
| dram_sdram | 615 | 647 | +32 |
| parallel_nor_flash | 468 | 524 | +56 |
| otp_eprom | 238 | 254 | +16 |
| nand_flash | 190 | 201 | +11 |
| other_storage | 104 | 151 | +47 |
| memory_controller_bridge | 50 | 58 | +8 |
| fram | 83 | 84 | +1 |

### 下游

- EAV：**268,556** 行 / **30,109** 物料
- L2 五族 **100% 对齐**

## 最终状态

ecloud storage gate **34,043** 行全部完成 L3 分类，F-RAM 误挂大桶清零。
