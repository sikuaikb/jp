# switch · ICPDF 分类试点

Schema：`seed/switch_schema_v1.5.28.xlsx`（`switch_schema_v1.5.28`）

> **约束**：阶段 1 只写 `test_dim` / `test_dwd`；`dwd.dwd_icpdf_component_param` 只读；**不写** `dim.*`、`dwd.dwd_component_class`。

## 进度

| 阶段 | 状态 |
|------|------|
| Gate 设计 | ✅ [GATE_DESIGN.md](GATE_DESIGN.md) |
| Classify 规则 | ✅ [CLASSIFY_DESIGN.md](CLASSIFY_DESIGN.md) |
| 阶段 1 test 验证 | ✅ `run_test_switch.py` |
| 属性标准化（ICPDF EAV） | ✅ `run_test_switch_attr.py` |
| 属性按 L3 校验 | ✅ `audit/audit_attr_by_l3.py` |
| 品牌标准化 + L2 宽表 | ✅ `run_brand_sync.py` · `run_test_switch_l2.py` |
| merge prod | ⏳ 验收通过后 `--allow-prod` |

DigiKey switch 已在 prod；本目录仅 **ICPDF** 试点。

## 目录

```text
seed/
├── gate_config.py / classify_config.py   # ICPDF 真源
├── digikey_classify_rules.csv            # DigiKey prod 快照（16 行）
├── export_digikey_rules_from_prod.py     # 从 prod 刷新快照
├── gen_rule_csv.py                       # 合并 icpdf + digikey → dim_l3_classify_rule_switch.csv
dim_l3_classify_switch.sql              # test_dim DDL
dim_l3_classify_rule_switch.sql
dwd_component_class_switch.sql            # test_dwd 结果表 DDL
gen_build_classify_sql.py                 # 从 prod 引擎生成 build SQL
build_dwd_icpdf_component_class_switch.sql
load_seed_switch.py
run_test_switch.py
audit/probe_gate.py · probe_classify.py   # 只读 prod param 探针
audit/audit_attr_by_l3.py                 # 按 L3 属性 EAV 覆盖率校验
seed/dim_attr_schema_switch.csv           # 属性 schema（v1.5.28）
seed/dim_attr_extract_rule_switch.csv     # 抽取规则（digikey + icpdf）
gen_attr_extract_rule_icpdf_switch.py     # 从 DK 规则派生 ICPDF prajson2 映射
load_attr_seed_switch.py
run_test_switch_attr.py                   # dim → ICPDF EAV
build_dwd_icpdf_component_attr_std_switch.sql
build_dwd_digikey_component_attr_std_switch.sql
gen_l2_wide_switch.py                     # 从 15_switch_ready 生成 test L2 SQL
dwd_l2_switch_*.sql                       # L2 DDL（test_dwd）
build_dwd_l2_switch_*.sql                 # L2 build（icpdf + digikey + brand）
run_brand_sync.py                         # test_dim 品牌字典（已有时跳过）
run_test_switch_l2.py                     # 品牌扫描 + L2 宽表
audit/brand_scan_switch.py                # 未映射 brandshort 报告
```

## 阶段 1（test only）

```bash
cd sql_scripts/test/switch
python run_test_switch_full.py   # 分类 → EAV → L2 → 审计 → merge 快照
# 或分步：
python run_test_switch.py
python run_test_switch_attr.py
python run_test_switch_l2.py
python export_merge_staging.py   # → merge_staging/
```

**查规则请用 `test_dim` 库**。本表含 **icpdf（新）+ digikey（prod 快照）** 两套规则；`load_seed_switch.py` 会 DROP 重建整表，CSV 必须同时含两源。

```sql
SELECT data_source, rule_kind, COUNT(*) cnt, COUNT(DISTINCT rule_id) rules
FROM test_dim.dim_l3_classify_rule_switch
GROUP BY data_source, rule_kind;
-- 期望：icpdf gate=2 classify=30；digikey gate=1 classify=15
```

易混淆：`test_dim.dim_attr_extract_rule_switch` 是**属性**抽取规则，不是 L3 分类规则。

## 属性校验（按 L3）

```bash
python audit/audit_attr_by_l3.py --data-source icpdf
# 完整报告 → artifacts/switch/attr_by_l3_icpdf.txt
```

判定规则：`PASS` / `WARN(l3_zero)` / `FAIL(no_eav)`；L2 关键字段覆盖率阈值 30%，EAV 覆盖 SKU ≥95%。

## L2 宽表 + 品牌（合 prod 前期）

```bash
python run_test_switch_attr.py    # 先跑 EAV
python run_test_switch_l2.py      # 品牌扫描 + 3 张 L2 宽表
python audit/brand_scan_switch.py # 未映射 brandshort → artifacts/switch/brand_unmapped_icpdf.json
```

L2 表：`test_dwd.dwd_l2_switch_{mechanical_actuated,mechanical_sensing,magnetic_sensing}_switch`  
品牌：`test_dim.v_std_brand_alias`；`brand/brandid` 来自 param.`brandshort`；`manufacturer` 仅 EAV。  
未映射补录（test）：`../brand_supplement/apply_brand_supplement_switch.py`

## 合 prod 前期清单（尚未执行 prod）

| 项 | test 状态 | merge 时动作 |
|----|-----------|--------------|
| 分类 dim + class | ✅ | `load_seed` → prod dim + 重跑 class build |
| 属性 dim + EAV | ✅ | `load_attr_seed` → prod；**ICPDF build 已补 value_map**（`build_dwd_component_attr_std_icpdf.sql`） |
| L2 宽表 3 张 | ✅ test_dwd | 脚本已在 `15_switch_ready/` 补 ICPDF 双源 |
| 品牌字典 | ✅ test 100% 映射 | **`dim_std_brand_manual_extra.sql` 已加 switch 节** |
| merge 快照 | ✅ `export_merge_staging.py` | CSV 在 `merge_staging/` |
| DigiKey switch | prod 已有 | ICPDF 为增量数据源 |

## 表映射

| prod | 试点 |
|------|------|
| `dim.dim_l3_classify` | `test_dim.dim_l3_classify_switch` |
| `dim.dim_l3_classify_rule` | `test_dim.dim_l3_classify_rule_switch` |
| `dwd.dwd_component_class` | `test_dwd.dwd_component_class_switch` |

参考：[`../test/README.md`](../test/README.md)
