# 21_data_converter_ready · 数据转换器 L2 宽表（多源 ICPDF + DigiKey）

L1：`data_converter`（ADC + DAC）
属性规则真源：`dim.dim_attr_schema` / `dim.dim_attr_extract_rule`（`l1_code=data_converter`）

## 脚本

| 文件 | 产出表 |
|---|---|
| `dwd_l2_data_converter_adc.sql` | `dwd.dwd_l2_data_converter_adc` |
| `build_dwd_l2_data_converter_adc.sql` | ↑ 装配（多源 ICPDF + DigiKey） |
| `dwd_l2_data_converter_dac.sql` | `dwd.dwd_l2_data_converter_dac` |
| `build_dwd_l2_data_converter_dac.sql` | ↑ 装配（多源 ICPDF + DigiKey） |

## 依赖（prod）

- `dim.dim_attr_schema` / `dim.dim_attr_extract_rule`（`l1_code=data_converter`，dim-attr-std-merge 后：schema 58 / rule 105）
- `dwd.dwd_component_class`（`l1_code=data_converter`，已合入）
- `dwd.dwd_component_attr_std`（`build_dwd_component_attr_std_{icpdf,digikey}.sql`）
- `dim.v_std_brand_alias`（合入前需 `sync_dim_std_brand.sh prod`）

## 跑数

```bash
L1_LIST=data_converter SOURCES="icpdf digikey" RES_ONLY=0 INIT_EAV_DDL=1 \
  ALLOW_PROD=1 bash sql_scripts/2.attribute_standard/run_attr_std.sh prod
```

test 环境将 `dwd.` / `dim.` 自动替换为 `test_dwd.` / `test_dim.`。

## 多源说明

build 脚本采用 `WITH src_param AS (UNION ALL icpdf + digikey)` 多源模式，`WHERE` 仅按 `l1_code`/`l2_code` 过滤，`GROUP BY` 含 `c.data_source`，一次跑出 ICPDF + DigiKey 两源数据。`DELETE ... WHERE data_source IN ('icpdf','digikey')` 保证两源幂等刷新。

## 命名约定

- `extract_rule_id` 沿用历史 `dcv_` 前缀（`dcv_icpdf_*` / `dcv_digikey_*`），已在 prod 长期存在，PK 预检确认不撞其它 L1。
- `schema_version` = `data_converter_schema_v1.0.0`。
