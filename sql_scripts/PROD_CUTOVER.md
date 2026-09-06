# 多源 ETL 架构 cutover · prod 发布清单

> 目标：把 ICPDF 单源结构（`dwd_icpdf_component_*`、`dwd_l2_{l2}`）切换为多源结构
> （`dwd_component_*` 加 `data_source` 列、`dwd_l2_{l1}_{l2}` 重命名），并接入 DigiKey 源。
>
> 前提：所有改动已在 test_dwd 跑过 `sql_scripts/test/run_test_dwd_e2e.sh`
> 验证（行数 / 关键空值率与 prod 老表对齐）。

## 0. 前置确认

- [ ] dim 三张维表已通过 `pull_seed_drift.py --reconcile` 与 prod 对齐
      （`dim_attr_schema` / `dim_attr_extract_rule` / `dim_l3_classify(_rule)`）
- [ ] `seed/` CSV 已 commit
- [ ] `local.env` 中 `ALLOW_PROD=1` 才允许执行 prod 写入

## 1. 装载 DigiKey ODS adapter（新增 prod 表）

```bash
mysql … -D dwd < sql_scripts/foundation/dwd_digikey_component_param.sql
```

校验：

```sql
SELECT COUNT(*) FROM dwd.dwd_digikey_component_param;        -- 期望 = ods 行数
SELECT COUNT(*) FROM dwd.dwd_digikey_component_param WHERE prajson IS NOT NULL;
```

## 2. 新建 `dwd.dwd_component_class`，回灌 ICPDF 现有数据

> 设计：新表与旧 `dwd_icpdf_component_class` 并存。先把旧表数据 INSERT 到新表标 `data_source='icpdf'`，
> 再跑 DigiKey classify 装入。验证后 DROP 旧表。

```sql
-- 2.1 建新表（含 data_source 列、PK=(data_source, id)）
SOURCE sql_scripts/1.classify/dwd_component_class.sql;  -- 该文件已含 DDL；首执行后会 DELETE WHERE data_source='icpdf' + INSERT
-- 注意：第一次跑前请把同事新加的 transistor/mcu/mpu/dsp 等 L1 也确保在 dim_l3_classify(_rule) 中（reconcile 后已是）
```

校验：

```sql
SELECT data_source, l1_code, COUNT(*) FROM dwd.dwd_component_class GROUP BY 1,2 ORDER BY 1,2;
SELECT l1_code, COUNT(*) FROM dwd.dwd_icpdf_component_class GROUP BY 1 ORDER BY 1;
-- ICPDF 段两者每行应基本一致（差异来自 reconcile 后 dim 规则新增）
```

## 3. DigiKey classify 入新表

```bash
ALLOW_PROD=1 SOURCES=digikey bash sql_scripts/1.classify/run_classify.sh prod
```

校验：

```sql
SELECT l1_code, l2_code, COUNT(*) FROM dwd.dwd_component_class
WHERE data_source='digikey' GROUP BY 1,2 ORDER BY COUNT(*) DESC LIMIT 20;
```

## 4. 新建 `dwd.dwd_component_attr_std`，回灌 ICPDF + DigiKey

```bash
ALLOW_PROD=1 INIT_EAV_DDL=1 SOURCES="icpdf digikey" L1_LIST="" RES_ONLY=0 \
  bash sql_scripts/2.attribute_standard/run_attr_std.sh prod
```

> 该命令会：DROP+CREATE `dwd.dwd_component_attr_std` → 两源装载 → 10 张 L2 DDL+build 全部重跑。
>
> 想分批跑可拆为：
>
> ```bash
> # 4a EAV
> ALLOW_PROD=1 INIT_EAV_DDL=1 SOURCES="icpdf digikey" L1_LIST=" " \
>   bash sql_scripts/2.attribute_standard/run_attr_std.sh prod
> # 4b 仅电阻 3 张 L2 先试
> ALLOW_PROD=1 INIT_EAV_DDL=0 SOURCES="" L1_LIST="resistor" \
>   bash sql_scripts/2.attribute_standard/run_attr_std.sh prod
> # 4c 全 L1
> ALLOW_PROD=1 INIT_EAV_DDL=0 SOURCES="" L1_LIST="resistor capacitor diode" \
>   bash sql_scripts/2.attribute_standard/run_attr_std.sh prod
> ```

校验（重点对比 ICPDF 段是否与老表差距很小）：

```sql
-- EAV
SELECT data_source, l2_code, COUNT(*) FROM dwd.dwd_component_attr_std GROUP BY 1,2 ORDER BY 1,2;
SELECT l2_code, COUNT(*) FROM dwd.dwd_icpdf_component_attr_std GROUP BY 1 ORDER BY 1;

-- L2（每张表 ICPDF 段 vs 老表 dwd.dwd_l2_{l2}）
SELECT data_source, COUNT(*) FROM dwd.dwd_l2_resistor_fixed_resistor GROUP BY 1;
SELECT COUNT(*) FROM dwd.dwd_l2_fixed_resistor;   -- 老表
```

## 5. RENAME 10 张老 L2（如同事下游消费方都已切到新表）

> ⚠️ 这一步会把旧名指向不存在的表 → 必须事先通知同事并切换其消费 SQL。

```sql
-- 老 L2 不再被消费后才能 drop（新 L2 已经在 run_attr_std.sh prod 中以 DROP+CREATE 方式建好）
DROP TABLE IF EXISTS dwd.dwd_l2_fixed_resistor;
DROP TABLE IF EXISTS dwd.dwd_l2_variable_resistor;
DROP TABLE IF EXISTS dwd.dwd_l2_protective_sensitive_resistor;
DROP TABLE IF EXISTS dwd.dwd_l2_non_polar_fixed_capacitor;
DROP TABLE IF EXISTS dwd.dwd_l2_polar_electrolytic_capacitor;
DROP TABLE IF EXISTS dwd.dwd_l2_supercapacitor;
DROP TABLE IF EXISTS dwd.dwd_l2_variable_capacitor;
DROP TABLE IF EXISTS dwd.dwd_l2_rectifier_switching_diode;
DROP TABLE IF EXISTS dwd.dwd_l2_voltage_reg_protection_diode;
DROP TABLE IF EXISTS dwd.dwd_l2_rf_special_diode;
```

## 6. 退役旧表

> ⚠️ 同上：通知同事，确认消费方都已切到 `dwd.dwd_component_class` / `dwd.dwd_component_attr_std`。

```sql
DROP TABLE IF EXISTS dwd.dwd_icpdf_component_class;
DROP TABLE IF EXISTS dwd.dwd_icpdf_component_attr_std;
```

## 7. 清理仓库

```bash
git rm -r sql_scripts/test/digikey_resistor/
git rm sql_scripts/1.classify/run_resistor_classify.sh       # 已由 run_classify.sh 替代
git rm sql_scripts/2.attribute_standard/run_resistor_std_attr.sh   # 由 run_attr_std.sh 替代
```

## 8. 回退路径（任何一步失败）

| 失败步骤 | 回退动作 |
|---|---|
| Step 1（DigiKey param）| `DROP TABLE dwd.dwd_digikey_component_param` + 同事侧无依赖 |
| Step 2（新 class 表）| `DROP TABLE dwd.dwd_component_class`；老表 `dwd_icpdf_component_class` 仍有效 |
| Step 3（DigiKey classify）| `DELETE FROM dwd.dwd_component_class WHERE data_source='digikey'` |
| Step 4（EAV / L2）| 重跑 `INIT_EAV_DDL=1` 把 EAV 表清空；老 L2 表（仍未 DROP）依旧可用 |
| Step 5 (DROP 老 L2) | 重跑老版 `build_dwd_l2_{l2}.sql`（git 历史中有）回灌 |
| Step 6 (DROP 老 class/eav) | 同上，从 git 历史回滚老 SQL |

---

## 文件清单

### 已删除 / 重命名

| 旧 | 新 |
|---|---|
| `1.classify/dwd_icpdf_component_class.sql` | `1.classify/dwd_component_class.sql` |
| `2.attribute_standard/build_dwd_icpdf_component_attr_std.sql` | `2.attribute_standard/build_dwd_component_attr_std_icpdf.sql` |
| `2.attribute_standard/dwd_l2_{fixed_resistor,…}.sql` ×10 | `2.attribute_standard/dwd_l2_{l1}_{l2}.sql` ×10 |
| `2.attribute_standard/build_dwd_l2_{l2}.sql` ×10 | `2.attribute_standard/build_dwd_l2_{l1}_{l2}.sql` ×10 |

### 新增

| 文件 | 用途 |
|---|---|
| `1.classify/dwd_digikey_component_class.sql` | DigiKey classify（写入统一 class 表 `data_source='digikey'`） |
| `2.attribute_standard/dwd_component_attr_std.sql` | 统一 EAV DDL（`(data_source, id, std_attr_code)` PK） |
| `2.attribute_standard/build_dwd_component_attr_std_digikey.sql` | DigiKey EAV |
| `2.attribute_standard/run_attr_std.sh` | 通用 EAV+L2 runner（多源 / 多 L1 参数化） |
| `1.classify/run_classify.sh` | 通用 classify runner（多源参数化） |
| `foundation/dwd_digikey_component_param.sql` | DigiKey ODS adapter |
| `test/run_test_dwd_e2e.sh` | 一键 test_dwd 端到端验证 |
| `PROD_CUTOVER.md` | 本文件 |
