# inductor · 阶段 2 分类合并

阶段 1 验收表（只读参考，合并数据来源）：

- `test_dim.dim_l3_classify_inductor`
- `test_dim.dim_l3_classify_rule_inductor`
- `test_dwd.dwd_component_class_inductor`

## 合并脚本

```bash
# 只读预检 Step 0-3
python sql_scripts/test/inductor/run_classify_merge.py

# 执行 prod 合并 Step 4-7（禁止 run_classify.sh prod）
python sql_scripts/test/inductor/run_classify_merge.py --allow-prod
```

## 基线（阶段 1）

| data_source | 阶段1 旧基线 | prod 验收（2026-06-12） |
|-------------|-------------|------------------------|
| digikey     | 134,265     | **134,265** ✅          |
| icpdf       | 28,520（旧 build，已弃用） | **17,948**（主干引擎） |

详见 `MERGE_RESULT.md`。

## 注意

- prod dim 按 L1 从 `test_dim.*_inductor` 替换，不是 `load_seed.sh prod`
- 重建 DWD 用主干 `sql_scripts/1.classify/dwd_component_class.sql`
## 属性合并

```bash
# 只读预检
python sql_scripts/test/inductor/run_attr_merge.py

# prod dim + EAV + L2（首次）
python sql_scripts/test/inductor/run_attr_merge.py --allow-prod

# 续跑：仅 L2（dim/EAV 已完成）
python sql_scripts/test/inductor/run_attr_merge.py --allow-prod --l2-only

# Step 6：merge 表验证（正式脚本 → test_dwd，对比 prod）
python sql_scripts/test/inductor/run_attr_merge_step6.py --rebuild

# Step 9：清理 test 沙盒表（prod 已验收后）
# ALLOW_PROD=1 python sql_scripts/test/inductor/run_step9_cleanup.py
```

验收见 `MERGE_RESULT.md`（L2 合计 137,544 行，brand 门控通过）。
