# optoelectronics 分类 + 属性标准化 prod 合并验收 · 2026-06-22

DigiKey-only L1 `optoelectronics`，l3_id 段 **26xxxx**（led / laser_diode / photodiode）。

## prod dim · 分类

| 表 | 行数 |
|---|---|
| `dim.dim_l3_classify` (optoelectronics) | 3 |
| `dim.dim_l3_classify_rule` (optoelectronics) | 8 |

备份：`dim.bak_dim_l3_classify_optoelectronics_20260622_opto_classify`、`dim.bak_dim_l3_classify_rule_optoelectronics_20260622_opto_classify`

Step 5 merge 表 vs 阶段 1 后缀表：**0% drift**（109,523 digikey）。

## prod dim · 属性标准化

| 表 | 行数 |
|---|---|
| `dim.dim_attr_schema` (optoelectronics) | 60 |
| `dim.dim_attr_extract_rule` (optoelectronics) | 77 |

品牌补缺：`dim_std_brand_manual_extra_optoelectronics.sql`（prod 已执行）。

## prod DWD · 分类

| data_source | optoelectronics 行数 |
|---|---|
| digikey | 109,523 |

## prod DWD · EAV（optoelectronics 子集 · digikey）

| 指标 | 值 |
|---|---|
| distinct ids | 109,485 |
| EAV 行数 | 1,824,545 |

classify vs EAV id gap：**38**（0.03%，源端 prajson 稀疏，非 PK 阻塞）。

Step 7：主干 `build_dwd_component_attr_std_digikey.sql` → merge 表 vs prod **0% drift**（ids + rows）。

## prod DWD · L2 宽表（digikey）

| L2 | 行数 | brand_null |
|---|---|---|
| `dwd_l2_optoelectronics_light_emitter` | 108,775 | 0 |
| `dwd_l2_optoelectronics_photodetector` | 748 | 0 |

## 品牌门控修复

23 行 `brandshort`/prajson「制造商」均为空，但 `source_product_url` 含厂商 slug。已在 `26_optoelectronics_ready/build_dwd_l2_*` 增加 URL slug → `dim.v_std_brand_alias` 回退 join，重建后 **brand_null=0**。

## 脚本入仓

- `sql_scripts/2.attribute_standard/26_optoelectronics_ready/`（DDL + build）
- `sql_scripts/2.attribute_standard/run_attr_std.sh` 注册 `optoelectronics`
- `sql_scripts/2.attribute_standard/dim_std_brand_manual_extra_optoelectronics.sql`

## cleanup

- test_dim / test_dwd `_*_optoelectronics` 后缀表已 DROP（2026-06-22）
- `sql_scripts/test/optoelectronics/` 已 git rm（阶段 2 完成）
