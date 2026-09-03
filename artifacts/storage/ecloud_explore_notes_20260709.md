# ecloud storage 阶段 1 摸底笔记

- **源表**：`dwd.dwd_ecloud_component_param`（`data_source='ecloud'`）
- **L1**：`storage`（prod taxonomy v1.5.30，18 个 L3）
- **探查日期**：2026-07-09

## 1. 规模与 gate 候选

| 指标 | 值 |
|------|-----|
| ecloud 全表行数 | 3,559,619 |
| 一级类 `存储器` 行数 | 34,043（0.96%） |
| prajson 覆盖率（存储子集） | 88.45% |
| 与 DigiKey storage 重叠 | 0（产品域不同：IC 级 vs 模块/卡级） |
| 与 icpdf partno 重叠 | ~18,933 型号 |

**Gate 白名单**：`category_in = ['存储器']`

## 2. 邻近品类边界

- ecloud `存储器` 是 **IC 级存储芯片**（SRAM/EEPROM/FLASH/FIFO），不是 DigiKey 的 SSD/eMMC/存储卡模块。
- `category2='F-RAM'` 是**大桶误标**（85% 行），真实类型需看 prajson `存储器格式`。
- FIFO（2,821 行）归入 `memory_controller/other_storage`。
- 勿与 `逻辑器件/FIFO` 混淆——ecloud 已在存储器一级类下。

## 3. 源端坑

1. **F-RAM 桶**：29,091 行中仅 ~186 行 `存储器格式=FRAM`。
2. **prajson 缺失**：F-RAM 桶内 3,816 行无 prajson，无法做 KV 分类（占未命中主体）。
3. **键名双轨**：除 `存储器格式` 外，稀疏行有 `存储器构架(格式)`（~300 行可补救）。
4. **占位符**：value 为 `-` / 空 / `null` 仍常见，EAV 阶段需过滤。
5. **闪存子类**：NOR/NAND 需 `note_cn` 或 `技术` 字段辅助，单靠 `存储器格式=闪存` 不够。

## 4. 候选标准属性映射（阶段 3 输入）

| prajson 中文键 | 候选 std_attr_code |
|----------------|-------------------|
| 存储容量 / 存储容量(Mb) | capacity_gb / memory_size_mb |
| 存储器格式 | （分类信号，非直接属性） |
| 内存数据长度(bit) | data_width_bit |
| 访问时间 / 最大存取时间(ns) | access_time_ns |
| 电压-供电 / 最大/最小工作电压(V) | vcc_max_v / vcc_min_v |
| 工作温度 | temp_min_c / temp_max_c |
| 最大时钟频率(MHz) | max_clock_freq_mhz |
| 元器件封装 / 封装/外壳 | package_case |

## 5. 数据健康度

- 无分区断档（全量表）。
- 存储子集 brandshort 100% 非空。
- datasheet 88.47% 有值。

## 6. 与已接入源差异

| 维度 | DigiKey | icpdf | ecloud |
|------|---------|-------|--------|
| 主形态 | 模块/卡 + 部分 IC | IC 为主 | IC 为主 |
| 分类字段 | 英文 category | category/category2 | **中文** category/category2 |
| 参数 KV | prajson 英文 | prajson2 中英混排 | prajson **中文键** |
| source_kind | prajson2_key_eq | prajson2_key_eq / prajson_cn_eq | prajson2_key_eq（prajson 别名） |

## 7. 阶段 2 结论（2026-07-09 沙盒跑通）

- 规则落 `test_dim.dim_l3_classify_rule_storage`（35 条 ecloud 子句）。
- 分类命中 **29,420 / 34,043（86.4%）**；未命中 4,623 行均为 F-RAM 桶且 prajson 稀疏。
- 验收脚本：`sql_scripts/test/storage/run_ecloud_classify_storage.py`

## 8. 阶段 3 结论（2026-07-09 EAV 沙盒）

- `test_dim.dim_attr_schema_storage`：220 行（sync prod）
- `test_dim.dim_attr_extract_rule_storage`：171（dk+icpdf）+ **17（ecloud）**
- EAV：`test_dwd.dwd_component_attr_std_storage` **236,522 行 / 29,303 物料**

| P0 属性 | 覆盖率 |
|---------|--------|
| package_case | 99.6% |
| lifecycle_status | 93.0% |
| temp_min/max_c | 94.2% |
| vcc_min/max_v | 85.3% |
| manufacturer | 72.1% |
| mpn | 66.1% |
| data_width_bit | 42.5% |

商城核对抽样：`artifacts/storage/ecloud_mall_sample_20260709.tsv`（9 L3 × 5 条）

**下一步**：商城核对填 TSV → 补容量单位换算（Mb→GB）→ L2 宽表 ecloud UNION 沙盒试跑。
