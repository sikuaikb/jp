# inductor 分类合并验收 · 2026-06-12

## prod dim（Step 4 · tag=202606120938）

| 表 | 行数 |
|---|---|
| `dim.dim_l3_classify` (inductor) | 13 |
| `dim.dim_l3_classify_rule` (inductor 前缀) | 87 |

备份：`dim.bak_dim_l3_classify_inductor_202606120938`、`dim.bak_dim_l3_classify_rule_inductor_202606120938`

## prod DWD（Step 6-7）

| data_source | inductor 行数 |
|---|---|
| digikey | 134,265 |
| icpdf | 17,948 |

`dwd.dwd_component_class` 总行数：**5,019,336**

## 基线对比说明

| 源 | 阶段1 旧基线 | merge/prod | 结论 |
|---|---|---|---|
| digikey | 134,265 | 134,265 | ✅ 完全一致 |
| icpdf | 28,520 | 17,948 | ⚠️ 旧基线由 per-L1 build 生成，与主干 `dwd_component_class.sql` 不一致；以 prod 17,948 为准 |

## 脚本修复项

- Step 4 DELETE：改用 `l3_id IN (...)`（StarRocks 不支持多列 IN）
- `--allow-prod` 显式门控
- merge 表 `l2_code VARCHAR(64)`（与 prod 对齐，避免 circuit_protection 长 l2_code 被过滤）
- `dwd_component_class.sql` DDL：`l2_code` 32→64

## prod dim 属性（Step 5 · attr merge）

| 表 | 行数 |
|---|---|
| `dim.dim_attr_schema` (inductor) | 113 |
| `dim.dim_attr_extract_rule` (`inductor_` 前缀) | 101 |

备份：`dim.bak_dim_attr_schema_inductor_202606121105`、`dim.bak_dim_attr_extract_rule_inductor_202606121105`

另已同步：`dim_std_brand` supplement（inductor）、`dim_unit_factor`（kOhms）

## prod L2 宽表（Step 7-8 · tag=202606121129）

| L2 表 | digikey | icpdf | 合计 | brand 门控 |
|---|---:|---:|---:|---|
| `dwd_l2_inductor_power_inductor` | 101,400 | 8,942 | 110,342 | ✅ null=0, no_id=0 |
| `dwd_l2_inductor_hf_chip_inductor` | 16,751 | 6,446 | 23,197 | ✅ |
| `dwd_l2_inductor_emi_filter_inductor` | 15,956 | 2,560 | 18,516 | ✅ |
| **合计** | **134,219** | **17,948** | **152,167** | |

### 与 classify 行数差（品牌 supplement 后 · 2026-06-12）

| 口径 | digikey | icpdf | 合计 |
|---|---:|---:|---:|
| `dwd_component_class` (inductor) | 134,265 | 17,948 | 152,213 |
| L2 宽表（brand_id 门控后） | 134,219 | 17,948 | **152,167** |
| **缺口** | **46** | **0** | **46** |

缺口 = **~45** 行 digikey 源端/prajson 均无制造商 + **1** 行 `Weidmüller`（ü 边界）。**icpdf 100% 进 L2。**

**2026-06-12 补充**：157 行空 `brandshort` 中 **112 行** prajson 有 `Manufacturer`（foundation 只抽 `制造商`）。已在 L2 build `src_param` 做 COALESCE 回退 + 修正 `dwd_digikey_component_param.sql`（下次全量 foundation 重建生效）。L2 digikey **134,219** / classify **134,265**。

品牌补录已合入 `dim_std_brand_manual_extra.sql`（Part 1 别名 + inductor A/B 42 品牌），经 `run_brand_sync.py --prod` 全量 sync。

## 脚本修复项（attr）

- L2 build：`brand` 仅取 `canonical_name`；WHERE 增加 `brand_id_std IS NOT NULL`
- `run_attr_merge.py`：Python 执行 EAV/L2（Windows 无 mysql CLI）；`--l2-only` / `--eav-only` / `--skip-dim-replace`

## Step 6 test_dwd merge 验证（2026-06-12 · `run_attr_merge_step6.py --rebuild`）

**主验收**：正式脚本 → merge 表 vs **prod L2** — **完全一致** ✅

| L2 表 | prod | merge | diff |
|-------|-----:|------:|-----:|
| power_inductor | 110,427 | 110,427 | 0 |
| hf_chip_inductor | 23,216 | 23,216 | 0 |
| emi_filter_inductor | 18,524 | 18,524 | 0 |
| **合计** | **152,167** | **152,167** | **0** |

**EAV merge**（`test_dwd.dwd_component_attr_std_merge_inductor`）：

| 口径 | digikey 去重 id | icpdf 去重 id |
|------|---------------:|--------------:|
| merge | 134,220 | 16,765 |
| 阶段1 后缀表 | 134,220 | 16,765 |

→ **组件 id 覆盖与阶段1 一致**；EAV **行数**因 prod dim 101 条 rule vs 阶段1 旧 rule 有差（digikey +133k / icpdf -173k 行），属预期。

**阶段1 L2 后缀表**（旧 build、无 brand 门控/prajson 回退）：merge 行数更少，仅作参考。

```bash
python sql_scripts/test/inductor/run_attr_merge_step6.py --rebuild
```

## Step 9 cleanup（2026-06-12）

已 DROP **14** 张 test 沙盒 / merge 表（`run_step9_cleanup.py`）：

- `test_dim`: dim_attr_schema/rule、dim_l3_classify/rule `_inductor`
- `test_dwd`: class、class_merge、attr_std、attr_std_merge、L2×3（阶段1 + merge）

**保留**：`sql_scripts/test/inductor/` 合并脚本与 `MERGE_RESULT.md`（未 `git rm`）。

## Step 10 seed + commit + merge main（2026-06-10）

- [x] seed CSV 回写：`dump_to_seed.py` → classify 13/87、schema 113、extract 101
- [x] commit `677fb77` on `shs/inductor`
- [x] fast-forward merge → `main` 并已 push

## 待办

- [x] Step 6：test_dwd merge 表 vs prod / 阶段1
- [x] Step 9：DROP test 后缀表 + merge 表
- [x] Step 10：seed 回写 + git commit + merge main
