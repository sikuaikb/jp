# 06_transformer_ready · 变压器属性标准化

L1: `transformer` | Schema: `transformer_schema_v1.6.08` | 数据源: **digikey + icpdf**

## L2 宽表

| l2_code | 表名 | 说明 |
|---------|------|------|
| `signal_communication_transformer` | `dwd.dwd_l2_transformer_signal_communication_transformer` | prod DK ~5.8k；icpdf ~9.9k |
| `switching_drive_transformer` | `dwd.dwd_l2_transformer_switching_drive_transformer` | prod DK ~2k；icpdf ~1.7k |
| `power_transformer` | `dwd.dwd_l2_transformer_power_transformer` | **新增** · icpdf ~7k |
| `instrument_transformer` | `dwd.dwd_l2_transformer_instrument_transformer` | **新增** · icpdf ~643 |

## 脚本生成

```bash
cd sql_scripts/test/transformer
python gen_l2_wide_transformer.py --ready   # 写入本目录
```

## merge 流程

```bash
cd sql_scripts/test/transformer
python run_attr_merge.py              # 预检（不写 prod）
python run_attr_merge.py --allow-prod # 人工授权后：dim 替换 + EAV + L2
```

merge 完成后刷新 catalog：

```bash
INIT_DDL=1 ALLOW_PROD=1 bash sql_scripts/2.attribute_standard/run_component_catalog.sh prod
```

## 合并记录

- 分类合并（DK）：2026-06-10
- 属性合并（DK）：2026-06-10
- **icpdf + DK 双源增量**：2026-06-30（classify + attr + catalog + Phase 5.5 QA）
- DK instrument CT 规则：2026-06-30（`apply_dk_instrument_rules_prod.py`）
