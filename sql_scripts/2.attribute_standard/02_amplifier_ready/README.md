# 02_amplifier_ready · 放大器 L1 属性标准化（多源 ICPDF + DigiKey）

L1：`amplifier`
属性规则真源：`dim.dim_attr_schema` / `dim.dim_attr_extract_rule`（`l1_code=amplifier`）

## L2 宽表

| L2 | DDL 脚本 | build 脚本（多源 icpdf + digikey） |
|----|------|------|
| `general_opamp_comparator` | `dwd_l2_amplifier_general_opamp_comparator.sql` | `build_dwd_l2_amplifier_general_opamp_comparator.sql` |
| `audio_power_amplifier` | `dwd_l2_amplifier_audio_power_amplifier.sql` | `build_dwd_l2_amplifier_audio_power_amplifier.sql` |
| `precision_signal_conditioning_amp` | `dwd_l2_amplifier_precision_signal_conditioning_amp.sql` | `build_dwd_l2_amplifier_precision_signal_conditioning_amp.sql` |
| `rf_if_amplifier` | `dwd_l2_amplifier_rf_if_amplifier.sql` | `build_dwd_l2_amplifier_rf_if_amplifier.sql` |
| `transimpedance_transconductance_log_amp` | `dwd_l2_amplifier_transimpedance_transconductance_log_amp.sql` | `build_dwd_l2_amplifier_transimpedance_transconductance_log_amp.sql` |
| `video_wideband_amp` | `dwd_l2_amplifier_video_wideband_amp.sql` | `build_dwd_l2_amplifier_video_wideband_amp.sql` |

## 多源说明

build 脚本采用 `WITH src_param AS (UNION ALL digikey + icpdf)` 多源模式：
- `src_param` 联合 `dwd.dwd_digikey_component_param` 与 `dwd.dwd_icpdf_component_param`，按 `data_source` 区分。
- 主查询 `JOIN src_param p ON p.data_source = c.data_source AND p.id = c.id`，`WHERE c.data_source IN ('icpdf','digikey')`，`GROUP BY` 含 `c.data_source`，一次跑出两源。
- `ext` CTE（ext_attributes JSON 透视）原本额外限定 `c.data_source = 'digikey'`，已放开为不限定源，跟随 `e.data_source` 聚合，天然支持多源。
- 品牌沿用 `dim.v_std_brand_alias`（按 `brandshort` 关联），无 digikey `prajson."制造商"` 兜底逻辑（原脚本未使用，未新增）。
- 注意：目前 build 脚本没有前置 `DELETE`，`dwd.dwd_l2_amplifier_*` 为 `PRIMARY KEY(data_source, id)` 表，重跑按主键 upsert，不会产生重复行；但若某条记录不再满足 `WHERE` 条件（如被重新分类），旧行不会被自动清理，如需幂等清库可在 build 前手动 `DELETE ... WHERE data_source IN ('icpdf','digikey')`。

## 运行

```bash
ALLOW_PROD=1 SOURCES="icpdf digikey" RES_ONLY=0 L1_LIST="amplifier" \
  bash sql_scripts/2.attribute_standard/run_attr_std.sh prod
```
