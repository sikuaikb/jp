# 18_system_module_ready

逆向合仓自 prod（`MERGE_BACKLOG_6L1.md` P0）。

## prod 基线（2026-06-24）

| 指标 | 值 |
|---|---:|
| 分类行数 (digikey) | 87,586 |
| dim_l3_classify | 21 |
| dim_l3_classify_rule | 20 |
| dim_attr_schema | 215 |
| dim_attr_extract_rule | 64 |

| L2 表 | 行数 |
|---|---:|
| compute_som_module | 4,993 |
| power_module | 75,661 |

## 验收

- 分类 A4-A6：`test/system_module/run_classify_system_module.py` → 87,586 行 PASS
- 属性 B6：`ALLOW_PROD=1 run_attr_std.sh prod L1_LIST=system_module`
