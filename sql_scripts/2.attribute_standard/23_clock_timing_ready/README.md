# 23_clock_timing_ready · DigiKey 时钟与计时 L2 宽表

L1：`clock_timing`（`l3_id` 段 `23xxxx`）  
属性规则真源：`sql_scripts/test/clock_timing/seed/`  
阶段 1 沙盒：`sql_scripts/test/clock_timing/`

## 脚本

| 文件 | 产出表 |
|------|--------|
| `dwd_l2_clock_timing_resonator.sql` | `dwd.dwd_l2_clock_timing_resonator` |
| `build_dwd_l2_clock_timing_resonator.sql` | ↑ 装配（DigiKey） |
| `dwd_l2_clock_timing_oscillator.sql` | `dwd.dwd_l2_clock_timing_oscillator`（仓内 0 行，gate 预埋） |
| `build_dwd_l2_clock_timing_oscillator.sql` | ↑ |
| `dwd_l2_clock_timing_clock_management_ic.sql` | `dwd.dwd_l2_clock_timing_clock_management_ic` |
| `build_dwd_l2_clock_timing_clock_management_ic.sql` | ↑ |
| `dwd_l2_clock_timing_timekeeping_timing_ic.sql` | `dwd.dwd_l2_clock_timing_timekeeping_timing_ic` |
| `build_dwd_l2_clock_timing_timekeeping_timing_ic.sql` | ↑ |
| `dwd_l2_clock_timing_delay_timing_adjustment.sql` | `dwd.dwd_l2_clock_timing_delay_timing_adjustment` |
| `build_dwd_l2_clock_timing_delay_timing_adjustment.sql` | ↑ |

## 依赖（prod）

- `dim.dim_l3_classify` / `dim.dim_l3_classify_rule`（`run_classify_merge.py --allow-prod`）
- `dim.dim_attr_schema` / `dim.dim_attr_extract_rule`（`run_attr_merge.py --allow-prod`）
- `dwd.dwd_component_class`（分类合入后重跑 `dwd_component_class.sql`）
- `dwd.dwd_component_attr_std`（`build_dwd_component_attr_std_digikey.sql`）
- `dim.v_std_brand_alias`（`dim_std_brand_manual_extra.sql` clock_timing 节 + `apply_brand_patch_clock_timing.py`）

## 合 prod（非自动，需 ALLOW_PROD=1）

```bash
cd sql_scripts/test/clock_timing

# 1A 分类
python run_classify_merge.py                    # 预检
python run_classify_merge.py --allow-prod       # Step 4–7

# 1B 属性（须在分类合入之后）
python run_attr_merge.py                        # 预检
python run_attr_merge.py --allow-prod           # Step 4b–8
```

test 环境将 `dwd.` / `dim.` 替换为 `test_dwd.` / `test_dim.`（`run_attr_std.sh` 同等逻辑见 `run_attr_merge.py`）。

## 数据规模（沙盒基线 · 2026-06）

| 层 | DigiKey 行数 |
|----|-------------|
| 分类 gate | 124,001 |
| EAV 器件 | ~102,235 |
| L2 resonator | ~95,912 |
| L2 clock_management_ic | ~1,999 |
| L2 timekeeping_timing_ic | ~4,024 |
| L2 delay_timing_adjustment | ~300 |
| L2 oscillator | 0 |
