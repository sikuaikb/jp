# 17_acoustic_device_ready · 电声元件属性标准化（多源 ICPDF + DigiKey）

L1 code: `acoustic_device` · schema: `acoustic_device_schema_v1.1` · 数据源: DigiKey + ICPDF

## L2 宽表

| l2_code | 表名 | build 脚本 | prod 行数 (digikey，改造前) |
|---|---|---|---:|
| buzzer_and_piezo_actuator | `dwd.dwd_l2_acoustic_device_buzzer_and_piezo_actuator` | `build_dwd_l2_acoustic_device_buzzer_and_piezo_actuator.sql` | 5,066 |
| speaker | `dwd.dwd_l2_acoustic_device_speaker` | `build_dwd_l2_acoustic_device_speaker.sql` | 2,289 |
| receiver | `dwd.dwd_l2_acoustic_device_receiver` | `build_dwd_l2_acoustic_device_receiver.sql` | 495 |
| microphone | `dwd.dwd_l2_acoustic_device_microphone` | `build_dwd_l2_acoustic_device_microphone.sql` | 975 |

## 多源说明

build 脚本采用 `WITH src_param AS (UNION ALL digikey + icpdf)` 多源模式：
- `src_param` 联合 `dwd.dwd_digikey_component_param` 与 `dwd.dwd_icpdf_component_param`（仅取 `id`/`brandshort`/`brandid`，本 L1 不依赖 `partno`/`prajson`），按 `data_source` 区分。
- 主查询 `JOIN src_param p ON p.data_source = c.data_source AND p.id = c.id`，`WHERE c.data_source IN ('icpdf','digikey')`，`GROUP BY` 含 `c.data_source`，一次跑出两源。
- 原脚本没有前置 `DELETE`，本次改造统一补上 `DELETE ... WHERE data_source IN ('icpdf','digikey')`，保证两源幂等刷新（`dwd.dwd_l2_acoustic_device_*` 均为 `PRIMARY KEY(data_source, id)` 表）。
- 品牌沿用 `dim.v_std_brand_alias`（按 `brandshort` 关联）。
- `ext_attributes` 用 `json_object(...)` 直接构造，未按源端做特殊处理，天然支持多源。

## 运行

```bash
ALLOW_PROD=1 RES_ONLY=0 SOURCES="icpdf digikey" L1_LIST="acoustic_device" \
  bash sql_scripts/2.attribute_standard/run_attr_std.sh prod
```

## 已知缺口

909 条分类命中无 EAV（ODS `specs_json`/`product_info` 为空，param 仅 category 骨架），不影响其余 7,916 条 prod 数据。
