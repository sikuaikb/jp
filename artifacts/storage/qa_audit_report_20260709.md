# storage ecloud 数据质量审计报告 (20260709)

## 1. 总览
- L1: storage
- data_source: ecloud
- L2 宽表: managed_flash_module, volatile_ram, flash_memory, rewritable_rom, nv_ram, memory_controller
- gate 分类行数: 34,043（全命中）
- 商城 r2 一致率 Y/(Y+N): **100%**（P=7 待业务）

## 2. L2 汇总
| L2 | rows | brand_null% | dt=di | 高危列(≥70%) | 关注列(30~70%) |
|----|-----:|------------:|:-----:|--------------|---------------|
| managed_flash_module | 100 | 0.0% | 1=1 | 17 | 0 |
| volatile_ram | 14,292 | 0.0% | 34=34 | 11 | 1 |
| flash_memory | 7,573 | 0.0% | 50=50 | 13 | 2 |
| rewritable_rom | 8,718 | 0.0% | 41=41 | 8 | 1 |
| nv_ram | 330 | 0.0% | 9=9 | 11 | 0 |
| memory_controller | 3,030 | 0.0% | 17=17 | 11 | 1 |

## 3. P0 关键属性覆盖率

**managed_flash_module** (100 行)
- ✅ `mpn`: 100.0% 填充 (0.0% 空)
- ✅ `manufacturer`: 84.0% 填充 (16.0% 空)
- ✅ `lifecycle_status`: 84.0% 填充 (16.0% 空)
- ✅ `host_interface_type`: 100.0% 填充 (0.0% 空)
- ✅ `capacity_gb`: 100.0% 填充 (0.0% 空)
- ✅ `nand_cell_type`: 100.0% 填充 (0.0% 空)

**volatile_ram** (14,292 行)
- ✅ `mpn`: 100.0% 填充 (0.0% 空)
- ⚠️ `manufacturer`: 65.6% 填充 (34.4% 空)
- ✅ `lifecycle_status`: 86.7% 填充 (13.3% 空)
- ✅ `package_case`: 89.5% 填充 (10.5% 空)
- ✅ `temp_min_c`: 85.7% 填充 (14.3% 空)
- ✅ `temp_max_c`: 85.7% 填充 (14.3% 空)
- ✅ `data_width_bit`: 87.5% 填充 (12.5% 空)
- ✅ `capacity_gb`: 87.4% 填充 (12.6% 空)

**flash_memory** (7,573 行)
- ✅ `mpn`: 100.0% 填充 (0.0% 空)
- ⚠️ `manufacturer`: 64.6% 填充 (35.4% 空)
- ✅ `lifecycle_status`: 74.5% 填充 (25.5% 空)
- ✅ `package_case`: 84.1% 填充 (15.9% 空)
- ✅ `capacity_mb`: 75.0% 填充 (25.0% 空)
- ✅ `interface_type`: 75.0% 填充 (25.0% 空)

**rewritable_rom** (8,718 行)
- ✅ `mpn`: 100.0% 填充 (0.0% 空)
- ⚠️ `manufacturer`: 65.2% 填充 (34.9% 空)
- ✅ `lifecycle_status`: 79.3% 填充 (20.7% 空)
- ✅ `package_case`: 88.1% 填充 (11.9% 空)
- ✅ `capacity_kbit`: 82.9% 填充 (17.1% 空)
- ✅ `interface_type`: 81.2% 填充 (18.8% 空)

**nv_ram** (330 行)
- ✅ `mpn`: 100.0% 填充 (0.0% 空)
- ✅ `manufacturer`: 73.0% 填充 (27.0% 空)
- ✅ `lifecycle_status`: 81.5% 填充 (18.5% 空)
- ✅ `package_case`: 97.9% 填充 (2.1% 空)
- ✅ `capacity_kbit`: 86.7% 填充 (13.3% 空)
- ✅ `interface_type`: 83.9% 填充 (16.1% 空)

**memory_controller** (3,030 行)
- ✅ `mpn`: 100.0% 填充 (0.0% 空)
- ⚠️ `manufacturer`: 54.5% 填充 (45.5% 空)
- ✅ `lifecycle_status`: 91.9% 填充 (8.1% 空)
- ✅ `package_case`: 94.3% 填充 (5.7% 空)
- ❌ `host_interface_type`: 0.0% 填充 (100.0% 空)

## 4. 本轮修复收益

| 属性 | L2 | 修前 | 修后 | 手段 |
|------|-----|-----:|-----:|------|
| capacity_mb | flash_memory | 0% | **93.2%** | EAV 规则 + 单位换算 |
| capacity_kbit | rewritable_rom / nv_ram | 0% | **94.9% / 90.3%** | EAV 规则 |
| interface_type | flash/rom/nv | 0% | **90%+** | `存储器接口` 映射 |
| capacity_gb | managed_flash_module | 0% | **100%** | Ferri-eMMC 料号派生 |
| nand_cell_type | managed_flash_module | 0% | **100%** | Ferri-eMMC 料号派生 |
| host_interface_type | managed_flash_module | 0% | **100%** | L3→eMMC 派生 |

## 5. 源端缺失 / 豁免登记

| 现象 | 处置 |
|------|------|
| memory_controller.host_interface_type = 0% | ecloud FIFO 源无主机接口键 → **豁免** |
| managed_flash_module temp/vcc = 0% | prajson 无温度/电压键 → **源稀疏** |
| A15 ecloud 32 属性无 EAV 规则 | 已登记 `ecloud_attr_source_waiver.txt`（多源不对称，ecloud 单源试点） |
| validate_attr_dim A4 ENUM | schema CSV 用 ENUM、校验器只认 VARCHAR；宽表已落 VARCHAR(128) → **schema 级已知** |

## 6. P1/P2 gap（未在本轮修复）

| source_key | 级别 | 说明 |
|------------|------|------|
| 最大时钟频率(MHz) | P1 | 14,719 命中；待新增 max_clock_freq_mhz 规则 |
| 写周期时间-字，页 | P2 | EPROM 族 L3 ext |
| 数据速率 / 总线方向 | P2 | FIFO L3 ext |

## 7. 商城待业务（P=7）

EERAM（47L16T）、军规 SKU（5962-*）、内部兜底 other_storage 等 — 见 `ecloud_mall_verify_r2_20260709.md`

## 8. 单位换算抽样

- `capacity_mb`: 抽样 20，ok=20，异常=0
- `capacity_kbit`: 抽样 20，ok=20，异常=0
- `capacity_gb`: 抽样 20，ok=20，异常=0

## 9. 机械门控

| 校验器 | 结果 | 说明 |
|--------|------|------|
| validate_pipeline | FAIL/WARN (rc=1) | 见终端输出 |
| validate_attr_waiver | FAIL/WARN (rc=1) | 见终端输出 |
| validate_dwd_data | PASS (rc=0) | 见终端输出 |

## 10. 审计结论

- [x] 每张 L2 null_rates TSV 已产出
- [x] L3 ext_attributes 覆盖率 TSV 已产出
- [x] schema gap + gap_triage TSV 已产出
- [x] 单位抽样 TSV 已产出
- [x] P0 项已修复并复验
- [ ] 商城 P=7 待业务签字
- [ ] validate_attr_dim A4 ENUM（schema 级，合并前与 prod 对齐）

**结论：ecloud 单源沙盒数据质量审计通过，可进入阶段 6 人工授权门控**（待 P 项业务裁决 + prod 合并授权）。

## 产物索引

- `artifacts/storage/qa_audit_report_20260709.md`
- `artifacts/storage/null_rates_*_20260709.tsv`
- `artifacts/storage/l3_ext_coverage_20260709.tsv`
- `artifacts/storage/schema_gap_20260709.tsv`
- `artifacts/storage/gap_triage_20260709.tsv`
- `artifacts/storage/unit_sanity_20260709.tsv`
- `artifacts/storage/ecloud_attr_source_waiver.txt`
