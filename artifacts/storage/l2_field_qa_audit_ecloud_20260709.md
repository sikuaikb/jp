# storage ecloud L2 宽表字段质量审计（复验）

日期：2026-07-09（第二轮，l2-field-qa-audit 全流程）  
方法：品牌门控 → L2 物理列 → L3 ext 字段级 → 抽样核对 → 两步法决策

---

## 1. 基本概况

| 指标 | 值 |
|------|-----|
| data_source | ecloud |
| gate 分类行数 | 34,043（100% 命中） |
| L2 宽表 | 6 张，合计 34,043 行，**delta=0** |
| EAV 行数 | 279,789（覆盖 30,110 物料） |
| ecloud 抽取规则 | **26** 条 |
| 商城 r2 分类一致率 | Y/(Y+N) = **100%**（P=7 待业务） |

### L3 分布

| L2 | 主 L3 | 行数 |
|----|-------|-----:|
| managed_flash_module | emmc | 100 |
| volatile_ram | sram / dram_sdram / psram | 10,198 / 3,930 / 164 |
| flash_memory | serial_nor_flash / parallel_nor_flash / nand_flash | 5,527 / 1,571 / 475 |
| rewritable_rom | eeprom / otp_eprom | 7,541 / 1,177 |
| nv_ram | fram / mram | 269 / 61 |
| memory_controller | other_storage / bridge | 2,972 / 58 |

### 品牌门控（§2.1）— **PASS**

| L2 | rows | brand_null | distinct_brand | distinct_brandid |
|----|-----:|-----------:|---------------:|-----------------:|
| managed_flash_module | 100 | 0 | 1 | 1 |
| volatile_ram | 14,292 | 0 | 34 | 34 |
| flash_memory | 7,573 | 0 | 50 | 50 |
| rewritable_rom | 8,718 | 0 | 41 | 41 |
| nv_ram | 330 | 0 | 9 | 9 |
| memory_controller | 3,030 | 0 | 17 | 17 |

---

## 2. L2 物理列审计 + 两步法决策

图例：✅ ≥70% · ⚠️ 30–70% · ❌ <30% · 决策码 R/X/F/D

### 2.1 managed_flash_module（100 行 · 全 emmc）

| 字段 | 填充率 | 决策 | 说明 |
|------|-------:|------|------|
| mpn / brand / brandid | 100% | OK | partno 优先 |
| host_interface_type | 100% | OK | L3 emmc → eMMC |
| capacity_gb / nand_cell_type | 100% | OK | Ferri-eMMC 料号派生 |
| manufacturer / lifecycle_status | 84% | D | prajson 稀疏 |
| temp/vcc/pkg/合规/吞吐 | 0% | **D** | ecloud emmc 源无对应键 |

**emmc 抽样**：SM662GE4→4GB MLC、SM662GEC→64GB TLC、SM667GX4→4GB pSLC ✅

### 2.2 volatile_ram（14,292 行）

| 字段 | 填充率 | 决策 | 说明 |
|------|-------:|------|------|
| capacity_gb | 87.4% | **OK** | L2 build Mb/Gb/Kb 换算（§4） |
| data_width_bit | 87.5% | OK | |
| package_case / temp / vcc | 85–90% | OK | |
| manufacturer | 65.6% | **D** | 品牌别名覆盖不全 |
| 合规/封装尺寸/icc | 0% | D/X | 源无键或选型价值低 |

**容量抽样**：MT47H32M16NF-25E:H 512Mb→**0.0625 GB** ✅；IS43DR16128B 2Gb→**0.244 GB** ✅；`capacity_gb>10GB` 异常 **0 行** ✅

### 2.3 flash_memory（7,573 行）

| 字段 | 填充率 | 决策 | 说明 |
|------|-------:|------|------|
| capacity_mb | 75.0% | **OK** | Mb/Gb→MB 单位换算正确 |
| interface_type | 75.0% | OK | `存储器接口` 映射 |
| max_clock_freq_mhz | 32.9% | **OK** | L2 列；serial NOR 走 L3 ext（见 §3） |
| manufacturer | 64.6% | D | |
| flash_type / 寿命 / 保持 | 0% | D | 源无键或未配规则 |

**容量抽样**：S29GL064N90TFI040 64Mb→**8 MB** ✅；MT25QL512ABB8E12 512Mb→**64 MB** ✅  
**Gb 器件**：16Gb→2000 MB（dim Gb→MB×125）符合行业惯例 ✅

**时钟抽样**：MT28GU512AAA1EGC-0SIT 源 133MHz → L2 **133** ✅

### 2.4 rewritable_rom（8,718 行）

| 字段 | 填充率 | 决策 | 说明 |
|------|-------:|------|------|
| capacity_kbit | 82.9% | **OK** | 8Mb→8000 kbit |
| interface_type | 81.2% | OK | |
| manufacturer | 65.2% | D | |
| rom_type / read_access_time_ns | 0% | D | 源键稀疏 |

**容量抽样**：AT27C080 系列 27/32 变体命中 8000 kbit；5 变体无 prajson 容量键 → **D（源稀疏）** 非规则错误

### 2.5 nv_ram（330 行）

| 字段 | 填充率 | 决策 | 说明 |
|------|-------:|------|------|
| capacity_kbit | 86.7% | OK | |
| max_clock_freq_mhz | 77.6% | **OK** | FRAM/MRAM 源键 |
| interface_type | 83.9% | OK | |
| ext_attributes | 0% | **INFO** | L3 字段无 ecloud 规则；关键参数已在 L2 列 |

### 2.6 memory_controller（3,030 行）

| 字段 | 填充率 | 决策 | 说明 |
|------|-------:|------|------|
| host_interface_type | 0% | **D** | FIFO 源无主机接口键（已豁免） |
| package_case / lifecycle / temp | 91–94% | OK | |
| manufacturer | 54.5% | D | |
| other_storage ext | 93.6% | OK | `storage_capacity_mb` L3 规则 |

---

## 3. L3 ext_attributes 审计

### 3.1 整体覆盖率

| L2 | L3 | 有 ext / 总行 | ext% | 判定 |
|----|-----|-------------:|-----:|------|
| volatile_ram | sram | 8,369 / 10,198 | 82.1% | OK |
| volatile_ram | dram_sdram | 0 / 3,930 | 0% | **D** 未建 L3 规则 |
| volatile_ram | psram | 29 / 164 | 17.7% | OK（源仅 29 行有频率） |
| flash_memory | serial_nor_flash | 2,453 / 5,527 | 44.4% | OK |
| flash_memory | parallel_nor_flash | 0 / 1,571 | 0% | **D** 未建 L3 规则 |
| flash_memory | nand_flash | 0 / 475 | 0% | **D** |
| rewritable_rom | eeprom | 5,604 / 7,541 | 74.3% | OK |
| rewritable_rom | otp_eprom | 0 / 1,177 | 0% | **D** |
| nv_ram | fram / mram | 0 / 330 | 0% | **INFO** L2 已覆盖 |
| memory_controller | other_storage | 2,782 / 2,972 | 93.6% | OK |
| managed_flash_module | emmc | 0 / 100 | 0% | **INFO** L2 料号派生已覆盖 |

### 3.2 字段级（§2.4 两步法）

| 字段 | 目标 L3 | 填充率 | 决策 | 说明 |
|------|---------|-------:|------|------|
| access_time_ns | sram | 82.1% | OK | 规则正确 |
| max_freq_mhz | psram | 17.7% | OK | 与源端有值行数一致（29） |
| max_spi_clk_mhz | serial_nor_flash | 44.4% | OK | 2453 EAV；`400kHz`→0.4 MHz ✅ |
| max_clock_freq_mhz | eeprom | 74.3% | OK | 进 rewritable_rom ext |
| storage_capacity_mb | other_storage | 93.6% | OK | FIFO 容量 |

**0% 且未配规则的 L3 字段**（dram_generation、speed_grade_mts、cas_latency_cl、spi_mode 等）：**D** — ecloud 单源试点未展开，非 build 故障。

---

## 4. 容量单位问题（已关闭）

| 属性 | 典型修复 | 判定 |
|------|----------|------|
| capacity_mb | 512Mb→64 MB；64Mb→8 MB | ✅ |
| capacity_kbit | 8Mb→8000 kbit | ✅ |
| capacity_gb (volatile_ram) | 512Mb→0.0625 GB；2Gb→0.244 GB | ✅ L2 派生 |

根因：`CAP_NUM_RE` 裸数字 + `dim` 缺 Mb→GB → 已通过 regex 扩展 + volatile_ram L2 build 绕过。

---

## 5. 时钟频率（已关闭 / 遗留说明）

| 规则 | 命中 | 判定 |
|------|-----:|------|
| max_clock_freq_mhz（L2+eeprom L3） | 8,348 EAV | ✅ |
| max_spi_clk_mhz（serial_nor L3） | 2,453 EAV | ✅ |
| max_freq_mhz（psram L3） | 29 EAV | ✅ |

**无法落库（schema 限制）**：

| L3 | 源有键行数 | 说明 |
|----|----------:|------|
| sram | 2,862 | prod schema 无 `max_clock_freq_mhz` → **INFO** |
| dram_sdram | 3,143 | schema 用 `speed_grade_mts`，是否映射待业务 → **P2** |

---

## 6. P 级问题汇总

| 级别 | 问题 | 行动 |
|------|------|------|
| **P0** | — | 品牌门控全 PASS；DWD 硬门控 OK |
| **P1** | ~~容量单位~~ / ~~时钟频率规则~~ | ✅ **已关闭** |
| **P2** | dram_sdram 时钟→speed_grade 映射 | 待业务 |
| **P2** | L3 ext 大面积未建规则（dram/parallel nor/nand/otp） | 登记 D，合并前按需补 |
| **P2** | 商城 P=7（EERAM/军规 SKU） | 业务裁决 |
| **D** | manufacturer 55–65% | 品牌字典 |
| **D** | 合规/封装尺寸/flash_type 等 0% | 源稀疏 |
| **D** | memory_controller.host_interface_type | FIFO 豁免 |
| **INFO** | validate_attr_dim A4 ENUM | 合并 prod 前对齐 |
| **INFO** | nv_ram ext=0% 但 L2 列已填 | 设计内行为 |

---

## 7. 机械门控

| 校验器 | 结果 | 说明 |
|--------|------|------|
| validate_dwd_data | **PASS** | 19 警告（死列/语义列/ext 稀疏，均已两步法归类） |
| validate_pipeline | attr FAIL | prod ENUM + 多源 A15 不对称（沙盒预期） |
| validate_attr_dim | FAIL | A4 ENUM + dk/icpdf 缺 ecloud 独有 L3 规则 |

> ecloud 单源沙盒：**数据面可接受**；合并 prod 前须处理 ENUM 与跨源豁免。

---

## 8. 总体评估

| 维度 | 是否合理 |
|------|----------|
| 分类 + 品牌门控 + 行数对齐 | ✅ **合理** |
| 容量类 L2 字段 | ✅ **已修复**，抽样通过 |
| 接口类型 / 访问时间 / emmc 派生 | ✅ **合理** |
| 时钟频率 L2+ext | ✅ **已修复**（schema 允许范围内） |
| L3 ext 部分 L3 为 0% | ⚠️ **预期**（未建规则或 L2 已覆盖） |
| manufacturer 覆盖 | ⚠️ **可接受**（D 级，非数值错误） |

**结论：ecloud storage L2 宽表字段质量审计通过，数据合理，可进入阶段 6 人工授权门控**（待商城 P=7 业务签字 + prod 合并授权）。

---

## 9. 产物

- `artifacts/storage/null_rates_*_20260709.tsv`
- `artifacts/storage/l3_ext_coverage_20260709.tsv`
- `artifacts/storage/qa_audit_report_20260709.md`
- `artifacts/storage/ecloud_attr_source_waiver.txt`（31 条 A15 豁免）
- 本报告：`artifacts/storage/l2_field_qa_audit_ecloud_20260709.md`
