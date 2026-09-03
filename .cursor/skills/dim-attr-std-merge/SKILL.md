---
name: dim-attr-std-merge
description: Merge a new L1 attribute standardization schema, extraction rules, EAV, and L2 wide-table scripts from test_dim/test_dwd suffixed tables into the shared StarRocks attribute pipeline. Use when merging new L1 属性标准化、处理 dim_attr_schema、dim_attr_extract_rule、dwd_component_attr_std、L2 宽表，或用户要求从同事分支合并属性阶段。
---

# dim-attr-std-merge

把一个 L1 的属性标准化（从测试库 `_<l1>` 后缀表和 `sql_scripts/test/<l1>/` 脚本）合并到 prod 主流程：

- `dim.dim_attr_schema` / `dim.dim_attr_extract_rule` ← 从 `test_dim` 后缀表按 L1 替换
- `dim.dim_unit_factor` ← 仅从 supplement 追加缺失单位，不按 L1 删除
- 重建 prod EAV `dwd.dwd_component_attr_std`
- 入仓 `sql_scripts/2.attribute_standard/<LL_l1>_ready/dwd_l2_{l1}_{l2}.sql` + `build_dwd_l2_{l1}_{l2}.sql`（把原 `<LL_l1>/` 目录改名加 `_ready`，不要保留占位目录再新建 sibling）
- 更新 `run_attr_std.sh` 的 `l1_dir()` / `l2_files_for_l1()` 映射
- DROP 测试库后缀表

**前置**：阶段 1 已在测试库后缀表跑通，见 `sql_scripts/test/README.md`。本 skill 执行的是阶段 2。

操作 SOP 真相源：`sql_scripts/2.attribute_standard/CONTRIB.md` —— **先 Read 它**。

**合并原则**：新 L1 不拼接共享规则文件，也不要删除/改写 `test_dim` 主表。`test_dim.*_<l1>` 后缀表是合并数据来源；生产 `dim` 是替换目标。用户明确授权后，备份生产旧 L1、删除生产旧 L1，再从测试库后缀表写回生产。共享 EAV build 脚本以主干最新版本为准；分支里的 L1 专用 EAV/build 脚本只作阶段 1 验证参考，除非本次明确是新增 `source_kind`/引擎能力。

**命名约定**：`scope_code` / `std_attr_code` / L2 宽表业务列名统一使用 lowercase snake_case。L2 表名固定为 `dwd_l2_{l1}_{l2}`，即使在 `test_dwd` 中也不额外追加 `_<l1>`；参考 schema 中的 `xxx_base` 落表前改为 `xxx`。

## Quick checklist

```text
- [ ] 0. 阶段 1 已完成（test_dim.dim_attr_schema_<l1>+rule_<l1>、test_dwd.dwd_component_attr_std_<l1>、test_dwd.dwd_l2_<l1>_<l2> 验证通过）
- [ ] 1. PK 冲突预检（schema / extract_rule / unit_factor 三表）
- [ ] 2. 质量检查（l1_code、extract_rule_id、scope、data_source、schema_version）
- [ ] 3. 只读列出生产将删除的旧 key 和测试库将写入的新 key
- [ ] 4. 入仓 `<LL_l1>_ready/dwd_l2_{l1}_{l2}.sql` + `build_dwd_l2_{l1}_{l2}.sql`（原 `<LL_l1>/` 目录 `git mv` 加 `_ready`，不要新增并保留两个目录）
- [ ] 5. 更新 `run_attr_std.sh` 的 `l1_dir()` 和 `l2_files_for_l1()`
- [ ] 6. 用户确认后，ALLOW_PROD=1：backup prod old L1 → delete prod old L1 → insert from test_dim 后缀表；unit_factor 只追加缺失单位
- [ ] 6.5. 若阶段 1 往 `dim_std_brand` 补过 `manual_extra`（含产地 `dim_brand_origin_extra`）：按 `CONTRIB_BRAND.md` 跑 `sync_dim_std_brand.sh` 同步字典（品牌 + 产地一并回写）后跑 `validate_brand_dim_dup.py`，**BD1=0（无未豁免「同公司多 id」）才继续**
- [ ] 7. 用主干正式脚本输出到 test_dwd merge 临时表，和阶段 1 后缀表对比
- [ ] 8. 验证通过后，ALLOW_PROD=1 run_attr_std.sh prod L1_LIST 含 <l1>
- [ ] 9. DROP test_dim/test_dwd _<l1> 后缀表 + git rm sql_scripts/test/<l1>/
- [ ] 10. git commit（含 prod 行数）+ push
- [ ] 11. ALLOW_PROD=1 刷新 dwd_l2_component_catalog（L2 宽表变了，catalog 必须跟上）
```

## Prerequisites

- 工作树干净；从 `main` 切分支
- `MYSQL_HOST / MYSQL_PORT / MYSQL_USER / MYSQL_PASSWORD` 可用
- 该 L1 已在 `dwd.dwd_component_class` 里（先做完 `.cursor/skills/dim-l3-classify-merge`）
- `dim.dim_std_brand` + `dim.v_std_brand_alias` 已上线
- 已确定 prod 脚本目录名：`sql_scripts/2.attribute_standard/<LL_l1>_ready/`，例如 `15_switch_ready`；若已有 `15_switch/` 占位目录，应 `git mv 15_switch 15_switch_ready`，不是另建 sibling 后留下旧目录
- 阶段 1 已完成（参考 `sql_scripts/test/README.md`）

## Step-by-step

### 0. 阶段 1 已完成验证

读 `sql_scripts/test/<l1>/README.md` / progress 笔记。硬指标：
- `test_dwd.dwd_l2_<l1>_<l2>` 中 `brand_null = 0`、`distinct_brand = distinct_brandid`
- 关键字段空值率 < 30%（视品类）
- 行数与同事预期对齐
- **已明确本 L1 接入哪些 `data_source`**；单源 L1（如 amplifier 仅 digikey）时 `test_dim.dim_attr_extract_rule_<l1>` 与沙盒 EAV/宽表 **不得含 icpdf**

### 0.1 单源 L1（如 amplifier · 仅 digikey）

```sql
SELECT data_source, COUNT(*) FROM test_dim.dim_attr_extract_rule_<l1> GROUP BY 1;
SELECT data_source, COUNT(*) FROM test_dwd.dwd_component_attr_std_<l1> GROUP BY 1;
```

范围外源出现 → stop，执行 `cleanup_icpdf_scope.sql`（若有）并重跑阶段 1。

### 1. PK 冲突预检

```sql
-- schema PK 必须 0；允许替换同一 L1 的旧 schema，但不能撞到其他 L1
SELECT COUNT(*) FROM (
  SELECT schema_version, l1_code, scope_level, scope_code, std_attr_code, COUNT(*) c FROM (
    SELECT schema_version, l1_code, scope_level, scope_code, std_attr_code
    FROM dim.dim_attr_schema
    WHERE l1_code <> '<l1>'
    UNION ALL SELECT schema_version, l1_code, scope_level, scope_code, std_attr_code FROM test_dim.dim_attr_schema_<l1>
  ) u GROUP BY 1,2,3,4,5 HAVING COUNT(*)>1
) x;

-- extract_rule PK 必须 0；允许替换同一 L1 / 同前缀旧规则，但不能撞到其他 L1
SELECT COUNT(*) FROM (
  SELECT extract_rule_id, COUNT(*) c FROM (
    SELECT extract_rule_id
    FROM dim.dim_attr_extract_rule
    WHERE l1_code <> '<l1>'
      AND extract_rule_id NOT REGEXP '^<l1>_'
    UNION ALL SELECT extract_rule_id FROM test_dim.dim_attr_extract_rule_<l1>
  ) u GROUP BY extract_rule_id HAVING COUNT(*)>1
) x;
```

非 0 → **stop**，让 owner 加 `<l1>_` 前缀重做阶段 1。

### 2. 质量检查

```sql
SELECT l1_code, scope_level, COUNT(*)
FROM test_dim.dim_attr_schema_<l1>
GROUP BY 1, 2;
SELECT extract_rule_id, COUNT(*)
FROM test_dim.dim_attr_extract_rule_<l1>
WHERE extract_rule_id NOT REGEXP '^<l1>_'
GROUP BY 1;
SELECT r.std_attr_code, COUNT(*) AS rows_
FROM test_dim.dim_attr_extract_rule_<l1> r
LEFT JOIN test_dim.dim_attr_schema_<l1> s
  ON s.schema_version = r.schema_version
 AND s.l1_code = '<l1>'
 AND s.std_attr_code = r.std_attr_code
WHERE s.std_attr_code IS NULL
GROUP BY 1;
SELECT scope_level, scope_code, std_attr_code, COUNT(*) AS rows_
FROM test_dim.dim_attr_schema_<l1>
WHERE std_attr_code NOT REGEXP '^[a-z0-9]+(_[a-z0-9]+)*$'
   OR scope_code NOT REGEXP '^[a-z0-9]+(_[a-z0-9]+)*$'
   OR (scope_level = 'L2' AND scope_code REGEXP '_base$')
GROUP BY 1, 2, 3;
```

异常则 stop，让 owner 回分支修正并重跑阶段 1。

### 3. 只读确认生产替换范围

```sql
SELECT schema_version, l1_code, scope_level, scope_code, std_attr_code
FROM dim.dim_attr_schema
WHERE l1_code = '<l1>'
ORDER BY schema_version, scope_level, scope_code, std_attr_code;
SELECT extract_rule_id, data_source, schema_version, std_attr_code, source_kind
FROM dim.dim_attr_extract_rule
WHERE l1_code = '<l1>' OR extract_rule_id REGEXP '^<l1>_'
ORDER BY extract_rule_id;
SELECT 'new_schema' AS t, COUNT(*) FROM test_dim.dim_attr_schema_<l1>
UNION ALL SELECT 'new_rule' AS t, COUNT(*) FROM test_dim.dim_attr_extract_rule_<l1>;
```

人工确认删除范围只覆盖该 L1，插入行数等于阶段 1 后缀表验收结果。

### 4. 入仓 L1 目录脚本

将阶段 1 通过验证的 L2 DDL/build 脚本迁移到该 L1 的正式目录。目录规则是**原目录加 `_ready` 后缀**：

- 若已有占位目录 `sql_scripts/2.attribute_standard/<LL_l1>/`（如 `15_switch/`），用 `git mv` 重命名为 `sql_scripts/2.attribute_standard/<LL_l1>_ready/`（如 `15_switch_ready/`），保留原 README 历史后再替换/更新内容。
- 若没有占位目录，才创建 `sql_scripts/2.attribute_standard/<LL_l1>_ready/`。
- 禁止同时保留 `<LL_l1>/` 和 `<LL_l1>_ready/` 两个目录；这会让 runner 映射和 reviewer 误判状态。

```text
sql_scripts/2.attribute_standard/<LL_l1>_ready/
├── dwd_l2_<l1>_<l2>.sql
└── build_dwd_l2_<l1>_<l2>.sql
```

要求：
- 正式表名固定 `dwd.dwd_l2_{l1}_{l2}`，test/prod 都不额外追加 `_<l1>`
- DDL 含 `data_source` 首列、PK `(data_source, id)`、`brand VARCHAR(256)`
- build SQL 使用主干多源模式：`src_param` CTE、`dim.v_std_brand_alias`、`dwd.dwd_component_attr_std`、`dim.dim_attr_schema`
- `manufacturer` 保持 EAV-only，禁止 COALESCE 到品牌
- 过滤 `_unclassified`

同时更新 `run_attr_std.sh`：
- `l1_dir()` 增加 `<l1>) echo "<LL_l1>_ready" ;;`
- `l2_files_for_l1()` 增加该 L1 的所有 `<l1>_<l2>` 后缀

### 5. prod dim 替换发布

执行前把 `<merge_tag>` 替换成本次合并标识（建议 `YYYYMMDDHHMM` 或分支短名），不要复用旧备份表。

```sql
CREATE TABLE dim.bak_dim_attr_schema_<l1>_<merge_tag> LIKE dim.dim_attr_schema;
CREATE TABLE dim.bak_dim_attr_extract_rule_<l1>_<merge_tag> LIKE dim.dim_attr_extract_rule;

INSERT INTO dim.bak_dim_attr_schema_<l1>_<merge_tag>
SELECT * FROM dim.dim_attr_schema WHERE l1_code = '<l1>';

INSERT INTO dim.bak_dim_attr_extract_rule_<l1>_<merge_tag>
SELECT *
FROM dim.dim_attr_extract_rule
WHERE l1_code = '<l1>' OR extract_rule_id REGEXP '^<l1>_';

DELETE FROM dim.dim_attr_extract_rule
WHERE l1_code = '<l1>' OR extract_rule_id REGEXP '^<l1>_';

DELETE FROM dim.dim_attr_schema WHERE l1_code = '<l1>';
INSERT INTO dim.dim_attr_schema SELECT * FROM test_dim.dim_attr_schema_<l1>;
INSERT INTO dim.dim_attr_extract_rule SELECT * FROM test_dim.dim_attr_extract_rule_<l1>;
```

`dim_unit_factor` 只追加缺失单位；不要按 L1 删除共享单位。若存在 `test_dim.dim_unit_factor_<l1>_supplement`：

```sql
INSERT INTO dim.dim_unit_factor
SELECT s.*
FROM test_dim.dim_unit_factor_<l1>_supplement s
LEFT JOIN dim.dim_unit_factor d
  ON d.target_unit = s.target_unit AND d.unit_raw = s.unit_raw
WHERE d.target_unit IS NULL;
```

只有用户明确确认后才执行。不要自动推断 prod 授权。

> **品牌字典查重（本次阶段 1 补过 `dim_std_brand` 时必做）**：本 skill 替换的是 `dim_attr_schema`/`dim_attr_extract_rule`，**不含品牌字典**；但阶段 1 若为补 `brand_null` 往 `dim_std_brand_manual_extra.sql` 新增/重写过品牌（见 Step 7 故障处理），必须先按 `CONTRIB_BRAND.md` 同步字典——跑 `sync_dim_std_brand.sh prod`（品牌 + 产地一并回写：`manual_extra.sql` 写品牌、`dim_brand_origin_extra.sql` 写产地、`brand_origin_backfill.sql` JOIN 回写产地列），末尾会自动跑查重校验器，也可手动复核：
>
> ```bash
> bash sql_scripts/2.attribute_standard/sync_dim_std_brand.sh prod
> # sync 末尾自动跑 validate_brand_dim_dup.py；或手动复核：
> python .cursor/skills/component-etl-methodology/tools/validate_brand_dim_dup.py --dim-schema dim
> # 退出码 0 = 无未豁免「同公司多 id」；非零 = 有未登记重复，按 CONTRIB_BRAND.md 走 A 类复用 / 登记白名单 / brand_merge 收口
> ```
>
> 注意宽表门控 `dt = di`（distinct brand = distinct brandid）**抓不到「同一公司两个 id」**（2=2 仍相等），字典级查重必须另跑 BD1。BD1 未过禁止重跑 prod EAV/L2。

### 6. test_dwd 跑正式脚本验证

生产 dim 替换和 L1 目录脚本入仓后，先用主干正式脚本输出到 test_dwd merge 临时表，对比阶段 1 后缀表。原则：

- 读取生产 `dim.dim_attr_schema` / `dim.dim_attr_extract_rule`
- 读取生产 `dwd.dwd_component_class` 和源 param 表
- EAV 输出到 `test_dwd.dwd_component_attr_std_merge_<l1>`
- L2 输出到 `test_dwd.dwd_l2_<l1>_<l2>_merge`
- 不替换生产 `dim`，不写生产 `dwd`

验证查询：

```sql
SELECT data_source, COUNT(DISTINCT id) AS ids, COUNT(*) AS rows_
FROM test_dwd.dwd_component_attr_std_merge_<l1>
GROUP BY 1;

SELECT data_source, COUNT(*) AS rows_
FROM test_dwd.dwd_l2_<l1>_<l2>_merge
GROUP BY 1;
```

行数、brand 覆盖、关键字段空值率与阶段 1 后缀表差异超出预期时，不继续写 prod。

### 7. prod EAV + L2 重跑

```bash
# 含 <l1>；INIT_EAV_DDL=1 仅在首次 / 字段变更时用
# SOURCES 必须与 sql_scripts/test/<l1>/README.md 声明一致（单源 L1 勿写 icpdf）
ALLOW_PROD=1 INIT_EAV_DDL=1 SOURCES="digikey" \
  RES_ONLY=0 L1_LIST="resistor capacitor diode <l1>" \
  bash sql_scripts/2.attribute_standard/run_attr_std.sh prod
```

示例：`amplifier` 仅得捷 → `SOURCES="digikey"`；电容/resistor 等双源 L1 → `SOURCES="icpdf digikey"`。

校验：
```sql
SELECT data_source, COUNT(*) FROM dwd.dwd_component_attr_std GROUP BY 1;
SELECT data_source, l1_code, COUNT(*) FROM dwd.dwd_component_class GROUP BY 1,2 ORDER BY 1,2;
SELECT data_source, COUNT(*) FROM dwd.dwd_l2_<l1>_<l2> GROUP BY 1;
```

### 8. cleanup

```sql
DROP TABLE IF EXISTS test_dim.dim_attr_schema_<l1>;
DROP TABLE IF EXISTS test_dim.dim_attr_extract_rule_<l1>;
DROP TABLE IF EXISTS test_dwd.dwd_component_class_<l1>;
DROP TABLE IF EXISTS test_dwd.dwd_component_attr_std_<l1>;
DROP TABLE IF EXISTS test_dwd.dwd_component_attr_std_merge_<l1>;
-- 每张 L2
DROP TABLE IF EXISTS test_dwd.dwd_l2_<l1>_<l2>;
DROP TABLE IF EXISTS test_dwd.dwd_l2_<l1>_<l2>_merge;
```

```bash
git rm -r sql_scripts/test/<l1>/
```

### 9. commit + push

```bash
git add sql_scripts/test/<l1>/ \
        sql_scripts/2.attribute_standard/<LL_l1>_ready/ \
        sql_scripts/2.attribute_standard/run_attr_std.sh
git commit -m "feat(attribute_standard): add <l1> attr standardization scripts

prod 行数：
- EAV <l1>: NNN,NNN
- L2 <l1>_<l2_a>: NNN,NNN
- L2 <l1>_<l2_b>: NNN,NNN
"
# user 明确确认后 git push
```

### 10. 刷新 dwd_l2_component_catalog

L2 宽表是 `dwd_l2_component_catalog`（L2 SKU 全局分类目录）的数据来源。本 skill 的 Step 7 重建了 prod L2 宽表，catalog 必须在 commit 之后、合并到 main 之前刷新一次，否则新 L1 的 SKU 不会出现在 catalog 里（Agent 按分类路由会漏掉）。

分类阶段（`.cursor/skills/dim-l3-classify-merge`）只改 `dim_l3_classify` 和 `dwd_component_class` 的分类标签，**不改 L2 宽表行数**，所以 catalog 刷新只在 attr-merge 这里做一次即可，不要在分类 skill 里重复跑。

```bash
INIT_DDL=1 ALLOW_PROD=1 \
  bash sql_scripts/2.attribute_standard/run_component_catalog.sh prod
```

- `INIT_DDL=1` 会 DROP + CREATE 后全量 UNION 所有业务 L2 宽表（自动发现 `dwd_l2_*`，排除 `_audit/_result/_llm_completion/_sample/_demo/component_catalog` 自身）
- 只纳入含 `data_source/id/mpn/brand/brandid/l1_code/l2_code/l3_code` 全部必需列的表
- 过滤 `mpn IS NULL OR mpn = ''` 的 SKU，因此 catalog 行数可能略小于 L2 宽表合计

验收门控（脚本退出码非 0 即失败）：

```sql
-- 1. (data_source, id) 重复组必须 0
SELECT COUNT(*) FROM (
  SELECT data_source, id FROM dwd.dwd_l2_component_catalog
  GROUP BY 1, 2 HAVING COUNT(*) > 1
) d;

-- 2. 新 L1 的每张 L2 表都出现在 l2_table 列
SELECT l2_table, COUNT(*) FROM dwd.dwd_l2_component_catalog
WHERE l1_code = '<l1>'
GROUP BY 1 ORDER BY 1;

-- 3. catalog 总行数 ≈ ∑ 业务 L2 宽表行数（减去 mpn 为空的）
SELECT COUNT(*) FROM dwd.dwd_l2_component_catalog;
```

> 若 `run_attr_std.sh` 末尾已开启 `AUTO_REFRESH_CATALOG=1`（见 runner 文档），则 Step 7 跑完后已自动刷新，本步可跳过——只需跑上面三条验收 SQL 确认。

## Failure modes

| 现象 | 处理 |
|------|------|
| Step 1 PK 冲突 | Stop, 让 owner 加 `<l1>_` 前缀重做阶段 1 |
| Step 2 质量检查失败 | Stop. 让 owner 统一 `l1_code`、`extract_rule_id`、`scope_code`、`data_source` 后重跑阶段 1 |
| Step 3 DELETE 范围不确定 | 先只查不删，列出将删除的 `extract_rule_id` / schema key 给人工确认；必要时建临时表 |
| Step 5 写入生产后 schema/rule 行数异常 | 对比本次 `dim.bak_*_<l1>_<merge_tag>`、`test_dim.dim_attr_*_<l1>` 与生产主表，检查列序、NOT NULL、schema_version 是否一致 |
| Step 6 test_dwd 验证异常 | 先排查 dim 规则、L1 目录脚本、runner 映射和源数据差异，不要继续写 prod |
| Step 7 `brand_null > 0` | brandshort 不在 `dim_std_brand`；按 `CONTRIB_BRAND.md` 补 `dim_std_brand_manual_extra` 再 sync |
| Step 7 `dt ≠ di` | `v_std_brand_alias` 视图 jp_canonical 二级映射出问题（同名跨 manual_extra/jp_brand 未统一） |
| 补 `manual_extra` 后 `validate_brand_dim_dup.py` BD1 FAIL | 新增品牌与既有行归一化撞车：真重复 → 走 `CONTRIB_BRAND.md` A 类复用既有 `brand_id_std` / `brand_merge` 收口；伪重复（不同公司缩写撞车）→ 登记校验器白名单。**注意 `dt=di` 盲区抓不到这个，必须靠 BD1** |
| Step 7 行数远多于阶段 1 | 漏 `_unclassified` 过滤 |
| Step 7 误写 prod | 优先从本次 `dim.bak_*_<l1>_<merge_tag>` 恢复该 L1，不要全量 DROP 主表 |
| Step 7 prod 行数与阶段 1 偏差 > 5% | 排查源 param 表是否有 ods 增量；或 dim 规则被同事改 |

## Anti-patterns (硬约束)

- ❌ `manufacturer` 加 COALESCE 兜底到 `a.canonical_name`（同品牌可能多制造商）
- ❌ `brand` 列用 `VARCHAR(128)`（截断"威世-VISHAY"）
- ❌ `extract_rule_id` 不带 L1 前缀
- ❌ `_unclassified` L3 写入 L2 宽表
- ❌ `excluded_*` L2 加入 build WHERE（已由 dim_attr_schema 不收录该 scope 自然过滤）
- ❌ BSD `sed \b`（macOS 不支持）；用精确字面匹配或 python re.sub
- ❌ 给已有 L1 小改动也走新 L1 合并流程；小改动应单独评审变更范围后直接改生产规则
- ❌ 新 L1 合并时人工拼接共享规则文件；默认从 `test_dim` 后缀表按 L1 替换
- ❌ commit `__pycache__` / `local.env` / `/tmp/` 临时文件

## Reference files

- 操作 SOP（人读）：`sql_scripts/2.attribute_standard/CONTRIB.md`
- 阶段 1 测试库流程：`sql_scripts/test/README.md`
- 分类合并 skill：`.cursor/skills/dim-l3-classify-merge/SKILL.md`
- 品牌字典 SOP：`sql_scripts/2.attribute_standard/CONTRIB_BRAND.md`（含 §6.5 产地维度维护）
- 品牌字典一键同步：`sql_scripts/2.attribute_standard/sync_dim_std_brand.sh`（品牌 + 产地一并回写：manual_extra → dim_brand_origin_extra → brand_origin_backfill → v_std_brand_alias → 查重校验）
- 品牌产地维度：`sql_scripts/2.attribute_standard/dim_brand_origin.sql`（独立表 DDL）+ `dim_brand_origin_extra.sql`（手工补录产地）+ `brand_origin_backfill.sql`（sync 后 JOIN 回写）
- 品牌字典查重校验器：`.cursor/skills/component-etl-methodology/tools/validate_brand_dim_dup.py`（归一化「同公司多 id」硬门控 BD1，补 `dt=di` 盲区；已接进 `sync_dim_std_brand.sh`）
- multi-source cutover 历史：`sql_scripts/PROD_CUTOVER.md`
- dim DDL：`sql_scripts/2.attribute_standard/dim_attr_schema.sql` 等 3 张
- EAV：`sql_scripts/2.attribute_standard/dwd_component_attr_std.sql`（DDL）+ `build_dwd_component_attr_std_{icpdf,digikey}.sql`
- L1 脚本目录：`sql_scripts/2.attribute_standard/<LL_l1>_ready/`（已有 `<LL_l1>/` 占位时用 `git mv` 加后缀）
- L2 模板：`sql_scripts/2.attribute_standard/11_resistor_ready/build_dwd_l2_resistor_fixed_resistor.sql`（最完整）
- Runner：`sql_scripts/2.attribute_standard/run_attr_std.sh`
- 分类目录：`sql_scripts/2.attribute_standard/dwd_l2_component_catalog.sql`（DDL）+ `build_dwd_l2_component_catalog.py`（全量重建）+ `run_component_catalog.sh`（runner）

