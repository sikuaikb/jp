# 20_storage_ready · 存储器（digikey + icpdf + ecloud）

> schema 与 extract_rule 以 prod `dim` 为准（2026-07-13 ecloud 合入后 rule=197）

## L2 宽表（6）

| L2 | 表名 | 典型行数（合入后） |
|---|---|---|
| `managed_flash_module` | `dwd.dwd_l2_storage_managed_flash_module` | digikey 11,346 + ecloud 100 |
| `volatile_ram` | `dwd.dwd_l2_storage_volatile_ram` | digikey 2,807 + icpdf 146,792 + ecloud 14,292 |
| `flash_memory` | `dwd.dwd_l2_storage_flash_memory` | digikey 219 + icpdf 51,534 + ecloud 7,573 |
| `rewritable_rom` | `dwd.dwd_l2_storage_rewritable_rom` | digikey 686 + icpdf 51,167 + ecloud 8,718 |
| `nv_ram` | `dwd.dwd_l2_storage_nv_ram` | digikey 3 + ecloud 330 |
| `memory_controller` | `dwd.dwd_l2_storage_memory_controller` | digikey 54 + icpdf 8,680 + ecloud 3,030 |

多源 build：`DELETE … IN ('digikey','icpdf','ecloud')` + `src_param` UNION；脚本由 `sql_scripts/test/storage/gen_l2_ready_multisource.py` 生成。

## 运行

```bash
set -a && source sql_scripts/local.env && set +a
SOURCES="digikey icpdf ecloud" RES_ONLY=0 L1_LIST=storage INIT_EAV_DDL=0 \
  bash sql_scripts/2.attribute_standard/run_attr_std.sh prod
```

Windows 无 mysql CLI 时用：

```bash
python sql_scripts/test/storage/run_attr_merge.py --allow-prod
```
