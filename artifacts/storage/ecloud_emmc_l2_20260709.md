# ecloud storage managed_flash_module L2 UNION

日期：2026-07-09  
触发：阶段 5.6 新增 100 行 `emmc` 分类，需纳入 ecloud L2 沙盒

## 变更

| 文件 | 说明 |
|------|------|
| `gen_l2_wide_storage_ecloud.py` | `L2_CODES` 增加 `managed_flash_module`；`host_interface_type` 按 L3 派生；**`capacity_gb` / `nand_cell_type` 按 Ferri-eMMC 料号派生** |
| `run_ecloud_l2_storage.py` | 验收六族；`L2_EXTRA_ATTR` 增加 `capacity_gb`、`nand_cell_type` |

### L3 → host_interface_type 派生（build SQL）

| l3_code | 值 |
|---------|-----|
| emmc | eMMC |
| ufs | UFS |
| memory_card | microSD |
| usb_flash_drive | USB |

### Ferri-eMMC（SM66x）料号 → capacity_gb / nand_cell_type

交叉验证来源：Findchips / Digi-Electronics 分销商规格（SM661GE4、SM662GEA-BD、SM662GEB-BD、SM662GEC-BD、SM662GED-BD、SM662GEE-BD、SM667GE2、SM668GE8、SM662QEC、SM668QEB 等）。

**容量码**：`substr(partno, 8, 1)`，匹配 `^SM66[0-9][A-Z]{2}[0-9A-E]`

| 码 | capacity_gb |
|----|------------:|
| 2 | 2 |
| 4 | 4 |
| 8 | 8 |
| A | 16 |
| B | 32 |
| C | 64 |
| D | 128 |
| E | 256 |

**颗粒类型**（`nand_cell_type`）：

| 料号前缀 / 容量码 | 值 |
|------------------|-----|
| `^SM661` | MLC |
| `^SM662Q` | MLC |
| `^SM662` + 码 `4`/`8` | MLC |
| `^SM662` + 码 `A`–`E` | TLC |
| `^SM66[78]` | pSLC（SLC mode 产品线） |

> 派生在 L2 build 层通过 `p.partno` 完成（源 prajson 无容量键）；EAV 有值时 COALESCE 优先。

## 回归

| 指标 | 值 |
|------|-----|
| classify (managed_flash_module) | 100 |
| L2 宽表行数 | **100**（delta=0） |
| brand_null | **0** |

### P0 覆盖率（ecloud emmc 100 行）

| 属性 | 覆盖率 |
|------|-------:|
| mpn | 100% |
| manufacturer | 84% |
| lifecycle_status | 84% |
| host_interface_type | **100%**（L3 派生） |
| capacity_gb | **100%**（料号派生） |
| nand_cell_type | **100%**（料号派生） |
| temp/vcc | 0%（源稀疏） |

### capacity_gb 分布

| GB | 行数 |
|---:|-----:|
| 2 | 4 |
| 4 | 15 |
| 8 | 20 |
| 16 | 16 |
| 32 | 20 |
| 64 | 13 |
| 128 | 8 |
| 256 | 4 |

## 重跑

```bash
.venv_probe/bin/python sql_scripts/test/storage/run_ecloud_l2_storage.py
```

## 残留

- ~~源端 `mpn` EAV 截断~~ → build 优先 `p.partno`，100 行均为完整料号
- `temp_min_c` / `temp_max_c` / `vcc_*` 源稀疏 = 0%
- ecloud 现 **6** 张 L2 沙盒表（+managed_flash_module）
