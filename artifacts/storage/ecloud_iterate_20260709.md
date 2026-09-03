# ecloud storage 阶段 5 内部回路 · 迭代记录 20260709

## 触发

第一次商城核对（`ecloud_mall_verify_20260709.md`）发现：
- 3 条并行 NOR 误落 `serial_nor_flash`（`our_rule_gap`）
- 1 条 CBRAM 误落 `fram`（`our_rule_gap`）

## 规则变更（`seed/ecloud_classify_config.py`）

| 动作 | rule_id | 说明 |
|---|---|---|
| **新增** | `storage_ec_c2_flash_parallel_v1` | phase2：category2=FLASH + note Parallel |
| **新增** | `storage_ec_c2_flash_parallel_pn_v1` | phase2：category2=FLASH + partno 并行 NOR 族 |
| **新增** | `storage_ec_kv_flash_parallel_note_v1` | phase3：fmt=闪存 + note Parallel |
| **新增** | `storage_ec_kv_flash_parallel_pn_v1` | phase3：fmt=闪存 + partno `^(M29W\|M29L\|AT49BV\|AT29BV\|AT29LV\|S29GL\|MX29L)` |
| **修改** | `storage_ec_kv_cbram_v1` | L3 `fram` → `mram`（l3_id 200402） |

规则子句：35 → **43**

## 分类回归对比

| 指标 | 迭代前 | 迭代后 | Δ |
|---|---:|---:|---:|
| 分类命中 | 29,420 | 29,420 | 0 |
| `serial_nor_flash` | 6,050 | 4,991 | −1,059 |
| `parallel_nor_flash` | 0 | **1,059** | +1,059 |
| `nv_ram/mram` (CBRAM) | 0 | **56** | +56 |
| `nv_ram/fram` | 300 | 244 | −56 |
| 未分类 | 4,623 | 4,623 | 0 |

flash_memory L2 总量不变：**6,094**

## 商城样本复验（4 条 N/P）

| 料号 | 迭代前 L3 | 迭代后 L3 | 状态 |
|---|---|---|---|
| AT49BV001-90JC | serial_nor_flash | **parallel_nor_flash** | ✅ 已修复 |
| AT29BV020-25TC | serial_nor_flash | **parallel_nor_flash** | ✅ 已修复 |
| M29W320DB7AN6E | serial_nor_flash | **parallel_nor_flash** | ✅ 已修复 |
| RM25C128A-BTAC-T | fram | **mram** | ✅ 已修复 |
| MX25U51245GZ4I00 | serial_nor_flash | serial_nor_flash | ✅ 保持 |
| 47L16T-I/SN | fram (EERAM) | fram (EERAM) | ⏸ 待业务确认 |

商城一致率（Y/(Y+N)）：86.7% → **100%**（排除 1 条 EERAM 待确认）

## 下游重跑

- EAV：236,522 行 / 29,303 物料（不变）
- L2 宽表：5 表行数与分类表 100% 对齐，brand_null=0

## 残留缺口（下一轮）

1. **4,623 行** F-RAM 桶 + prajson 稀疏仍未分类
2. **`capacity_mb` / `capacity_kbit`** L2 列 0% — 需 §8.3 gap 探针补 extract 规则
3. **`host_interface_type`** memory_controller 0%
4. **EERAM → fram L3** 是否独立节点（业务裁决）
5. **serial_nor 兜底** `storage_ec_kv_flash_fb_v1` 仍承载 ~4,267 行，需抽样评估是否还有并行漏网

## 重跑命令

```bash
source sql_scripts/local.env
bash sql_scripts/test/storage/run_test.sh
```
