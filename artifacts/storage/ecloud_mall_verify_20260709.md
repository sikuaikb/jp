# ecloud storage 第一次商城核对（分类）

日期：2026-07-09  
样本：`artifacts/storage/ecloud_mall_sample_20260709.tsv`（9 L3 × 5 = 45 行）  
对照源：得捷/分销商参数页 + 立创商城（芯查查同类）+ ecloud 源 `prajson.存储器格式` + icpdf 交叉（18/45 命中）

## 汇总

| 指标 | 值 |
|---|---:|
| 样本数 | 45 |
| 一致 (Y) | 39 |
| 部分一致/待业务 (P) | 2 |
| 不一致 (N) | 4 |
| 一致率 | 86.7%（Y/(Y+N)） |

## 按 L3 汇总

| L3 | 样本 | Y | P | N | 结论 |
|---|---:|---:|---:|---:|---|
| dram_sdram | 5 | 5 | 0 | 0 | ✅ 通过 |
| eeprom | 5 | 5 | 0 | 0 | ✅ 通过 |
| fram | 5 | 3 | 1 | 1 | ⚠️ CBRAM 误归 FRAM；EERAM 待确认 |
| nand_flash | 5 | 5 | 0 | 0 | ✅ 通过 |
| other_storage (FIFO) | 5 | 5 | 0 | 0 | ✅ 通过（taxonomy 映射） |
| otp_eprom | 5 | 5 | 0 | 0 | ✅ 通过 |
| psram | 5 | 5 | 0 | 0 | ✅ 通过 |
| serial_nor_flash | 5 | 2 | 0 | 3 | ❌ 并行 NOR 被兜底规则误判 |
| sram | 5 | 5 | 0 | 0 | ✅ 通过 |

## 不一致明细（需改规则）

### 1. 并行 NOR → 误落 `serial_nor_flash`（3 条，our_rule_gap）

| 料号 | 我方 L3 | 商城/规格书 | 源信号 | 命中规则 | 根因 |
|---|---|---|---|---|---|
| AT49BV001-90JC | serial_nor_flash | IC FLASH **PARALLEL** 32PLCC | fmt=闪存，note_cn 无 NOR/SPI | storage_ec_kv_flash_fb_v1 | 闪存兜底规则过宽 |
| M29W320DB7AN6E | serial_nor_flash | IC FLASH 32M **PARALLEL** 48TSOP | 同上 | storage_ec_kv_flash_fb_v1 | 同上 |
| AT29BV020-25TC | serial_nor_flash | IC FLASH 2M **PARALLEL** 32TSOP | 同上 | storage_ec_kv_flash_fb_v1 | 同上 |

**建议动作（阶段 5）**：
- 在 `ecloud_classify_config.py` 增加 phase=3 规则：note_cn 含 `Parallel` / `并行`，或 partno 前缀 `M29W`/`AT49BV`/`AT29BV` → `parallel_nor_flash`（priority 低于 NAND，高于 flash_fb 兜底）
- 或利用 note_cn `接口类型:SPI` 已有键（如 MX25U51245GZ4I00）强化 serial 分支

### 2. CBRAM® → 误归 `fram`（1 条，our_rule_gap）

| 料号 | 我方 L3 | 商城 | 源信号 | 命中规则 |
|---|---|---|---|---|
| RM25C128A-BTAC-T | fram | CBRAM®（Adesto 阻变存储） | fmt=CBRAM® | storage_ec_kv_cbram_v1 → l3_id=200401 fram |

**建议动作**：CBRAM 映射至 `nv_ram/mram`（若业务认可），或保留 `fram` 但登记豁免；当前规则将 CBRAM 硬绑 FRAM 节点。

## 待业务确认（P）

| 料号 | 我方 | 商城 | 说明 |
|---|---|---|---|
| 47L16T-I/SN | nv_ram/fram | EERAM（得捷 Memory/EERAM） | L2=nv_ram 正确；L3=fram 为规则 `storage_ec_kv_eeram_v1` 有意映射。是否需独立 EERAM L3？ |

## 一致但需备注

- **FIFO 5 条**：得捷分类「FIFO 存储器」/「Logic-FIFOs Memory」；我方 `memory_controller/other_storage` 为 taxonomy 兜底节点，**接受**。
- **AT17C128-10PI**：得捷「Configuration PROM / Serial EEPROM」；我方 `otp_eprom`（category2=PROM）**接受**。
- **XC17S40PD8C**：得捷 `otp_eprom` 与 icpdf 一致。

## 下一步（阶段 5 内部回路）

1. 补并行 NOR 分类规则 → 重跑 `run_ecloud_classify_storage.py`
2. 评审 CBRAM / EERAM 的 L3 映射
3. 用 §8.3 gap 探针评估 flash 兜底规则 (`storage_ec_kv_flash_fb_v1`) 全表误伤量
4. 规则稳定后做第二轮商城核对（重点抽改过的 L3）
