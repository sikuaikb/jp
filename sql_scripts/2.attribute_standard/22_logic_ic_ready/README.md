# 22_logic_ic_ready · 逻辑芯片 L1 属性标准化

分类树真源：`foundation/dim_l3_classify_all.sql`（`22xxxx`）

L2 build 脚本由 `sql_scripts/test/logic_ic/gen_l2_ready_scripts.py` 生成（多源 `src_param`：icpdf + digikey）。

## L2 宽表（prod 基线）

| L2 | digikey | icpdf |
|----|--------:|------:|
| `combinational_logic` | 9,789 | 51,358 |
| `sequential_logic` | 7,352 | 36,506 |
| `signal_buffer_driver` | 2,450 | 45,330 |

合计 **152,785** 行（19,591 + 133,194）。

## EAV

| data_source | 器件数 | EAV 行数 |
|-------------|-------:|---------:|
| digikey | 17,928 | 324,660 |
| icpdf | 133,194 | 1,598,114 |

## 运行

```bash
ALLOW_PROD=1 SOURCES="icpdf digikey" RES_ONLY=0 L1_LIST="logic_ic" \
  bash sql_scripts/2.attribute_standard/run_attr_std.sh prod
```

阶段 1 验证：`sql_scripts/test/logic_ic/`
