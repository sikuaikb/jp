# 13_filter_ready · 滤波器属性标准化（多源 ICPDF + DigiKey）

L1 `filter`（l3_id 段 13xxxx），数据源：**DigiKey + ICPDF**。

| L2 | 宽表 | build 脚本 |
|----|------|------|
| `acoustic_resonator_filter` | `dwd.dwd_l2_filter_acoustic_resonator_filter` | `build_dwd_l2_filter_acoustic_resonator_filter.sql` |
| `analog_filter` | `dwd.dwd_l2_filter_analog_filter` | `build_dwd_l2_filter_analog_filter.sql` |
| `emi_suppression_filter` | `dwd.dwd_l2_filter_emi_suppression_filter` | `build_dwd_l2_filter_emi_suppression_filter.sql` |
| `dielectric_cavity_filter` | `dwd.dwd_l2_filter_dielectric_cavity_filter` | `build_dwd_l2_filter_dielectric_cavity_filter.sql` |

schema_version: `filter_schema_v1.5.30`；extract_rule_id 前缀 `fil_`。

## 多源说明

build 脚本采用 `WITH src_param AS (UNION ALL digikey + icpdf)` 多源模式：
- `src_param` 联合 `dwd.dwd_digikey_component_param` 与 `dwd.dwd_icpdf_component_param`，按 `data_source` 区分。
- 主查询 `JOIN src_param p ON p.data_source = c.data_source AND p.id = c.id`，`WHERE c.data_source IN ('icpdf','digikey')`，`GROUP BY` 含 `c.data_source`，一次跑出两源。
- `ext` CTE（ext_attributes JSON 透视）原本就未限定源端，跟随 `e.data_source` 聚合，天然支持多源，未改动。
- `DELETE ... WHERE data_source IN ('digikey','icpdf')` 早已就位，保证两源幂等刷新。
- 品牌沿用 `dim.v_std_brand_alias`（按 `brandshort` 关联），无 prajson 兜底逻辑（原脚本未使用，未新增）。

阶段 1 验收：`sql_scripts/test/filter/README.md`（`zl/digikey_filter` 分支）。
