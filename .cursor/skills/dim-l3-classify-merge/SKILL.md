---
name: dim-l3-classify-merge
description: Merge a new L1 classification taxonomy and rules from test_dim/test_dwd suffixed tables into the shared StarRocks dim/dwd classification pipeline. Use when merging new L1 分类规则、处理 dim_l3_classify、dim_l3_classify_rule、dwd_component_class，或用户要求从同事分支合并分类阶段。
---

# dim-l3-classify-merge

把一个 L1 的分类规则（从测试库 `_<l1>` 后缀表）合并到共享 `dim.dim_l3_classify` / `dim.dim_l3_classify_rule`，并重建 `dwd.dwd_component_class`。

**前置**：阶段 1 已在测试库后缀表跑通，见 `sql_scripts/test/README.md`。本 skill 执行的是阶段 2（合并到主流程）。

操作 SOP 真相源：`sql_scripts/1.classify/CONTRIB.md` —— **先 Read 它**。

**合并原则**：新 L1 不拼接共享规则文件，也不要删除/改写 `test_dim` 主表。`test_dim.*_<l1>` 后缀表是合并数据来源；生产 `dim` 是替换目标。用户明确授权后，备份生产旧 L1、删除生产旧 L1，再从测试库后缀表写回生产。

**合并内容边界**：分类阶段只合并两张表的数据：
- `dim.dim_l3_classify` ← `test_dim.dim_l3_classify_<l1>`
- `dim.dim_l3_classify_rule` ← `test_dim.dim_l3_classify_rule_<l1>`

`sql_scripts/1.classify/dwd_component_class.sql` 以主干最新版本为准，只用于重跑和回归；同事分支里的 `build_dwd_component_class_<l1>.sql` 可能基于旧版本，只作为阶段 1 验证参考，不能覆盖主干引擎。发现引擎 bug 时单独修引擎。

> **catalog 刷新说明**：`dwd_l2_component_catalog`（L2 SKU 全局分类目录）的行来自 `dwd_l2_*` 宽表，分类阶段只改 `dim_l3_classify` / `dwd_component_class` 的标签、不改 L2 宽表行数，所以 catalog 刷新由 `dim-attr-std-merge` 的 Step 10 统一负责，**本 skill 不刷 catalog**。唯一例外：本次是单独调整已有 L1 的 L3 划分、且不打算接着跑 attr-merge，则需手动跑一次 `INIT_DDL=1 ALLOW_PROD=1 bash sql_scripts/2.attribute_standard/run_component_catalog.sh prod` 让 catalog 的 `l3_code/l3_cn/l3_id/confidence/rule_id` 字段跟上新标签。

`l3_id` 是 6 位数字，参考 `dim_l3_classify_all`：前两位是 L1 顺序，中间两位是 L2 顺序，后两位是 L3 在 L2 下的顺序。L1 前两位确定后原则上不改；L2/L3 后续可在同一 L1 段内调整。

`l2_code` / `l3_code` 统一使用 lowercase snake_case；`l2_code` 不保留 `_base` 后缀，参考文档中的 `xxx_base` 落表前改为 `xxx`。

## Quick checklist

```text
- [ ] 0. 阶段 1 已完成（test_dim.dim_l3_classify_<l1> / dim_l3_classify_rule_<l1> 验证通过）
- [ ] 1. PK 冲突预检（l3_id 六位段 / rule_id 前缀）
- [ ] 2. 质量检查（只合并 classify + classify_rule；校验 l1_code、rule_id、data_source、gate、schema_version）
- [ ] 3. 只读列出生产将删除的旧 key 和测试库将写入的新 key
- [ ] 4. 用户确认后，ALLOW_PROD=1：backup prod old L1 → delete prod old L1 → insert from test_dim 后缀表
- [ ] 5. 用主干 dwd_component_class.sql 输出到 test_dwd 临时表，和阶段 1 后缀表对比
- [ ] 6. 验证通过后，直接执行主干 dwd_component_class.sql 重建 prod DWD（不要跑会重建 dim 的 run_classify.sh prod）
- [ ] 7. 校验各 (data_source, l1) 行数
- [ ] 8. DROP test_dim/test_dwd 后缀表 + git rm sql_scripts/test/<l1>/
- [ ] 9. git commit 分支脚本 / 文档 / 验收记录（带 prod 行数）
```

## Prerequisites

- Working tree clean (`git status`); 从 `main` 切分支
- `MYSQL_HOST / MYSQL_PORT / MYSQL_USER / MYSQL_PASSWORD` 可用
- 测试库 `test_dim.dim_l3_classify_<l1>` 和 `dim_l3_classify_rule_<l1>` schema 与主表完全同构
- `rule_id` 带 L1 / 源前缀（`inductor_*`、`gate_<l1>_<source>_v1`）
- `l3_id` 按 `LLMMNN` 六位规则分配：`LL` 取自 `dim_l3_classify_all` / 当前主表规划的 L1 前缀，`MM` 是 L2 顺序，`NN` 是 L3 在 L2 下的顺序
- 该 L1 在测试库验证时已确认行数 / L3 分布合理

## Step-by-step

### 0. 确认阶段 1 已完成

读 `sql_scripts/test/<l1>/README.md`（或 owner 提供的 progress note），确认：
- test_dim 表行数稳定，git diff 显示新增规则已 review 过
- test_dwd.dwd_component_class_<l1> 行数 vs 上游 param 表合理（建议 70%-100%）
- L3 分布无单个吞噬全部（最大 L3 占比 < 60% 为佳）
- **已明确本 L1 接入哪些 `data_source`**（见 README「范围与前提」）。若仅单源（如 amplifier 仅 `digikey`），后续 Step 5/7 **只对比该源**，不得把 prod 引擎全源输出的 icpdf 行数当作阶段 1 对标基线。

### 0.1 单源 L1 额外门控（如 amplifier · 仅 digikey）

```sql
-- 规则表不得含范围外 data_source
SELECT data_source, COUNT(*) AS n
FROM test_dim.dim_l3_classify_rule_<l1>
GROUP BY 1;

-- 沙盒分类产出同理
SELECT data_source, COUNT(*) AS n
FROM test_dwd.dwd_component_class_<l1>
WHERE l1_code = '<l1>'
GROUP BY 1;
```

若 README 声明仅 `digikey`，则上表 **不得出现 `icpdf`**。出现则 stop，执行 `sql_scripts/test/<l1>/cleanup_icpdf_scope.sql`（若有）或让 owner 删规则/重跑阶段 1。

**禁止**保留 `test_dwd.dwd_component_class_merge_<l1>` 作为「完整合并结果」长期对照：Step 5 用 prod 多源引擎重跑时，即使本 L1 无 icpdf gate，历史上也可能因旧规则/旧仿真表产出 icpdf 行（amplifier 曾误读为 ~82k = icpdf 73k + digikey 8k）。单源 L1 合并前 **DROP** 该表；Step 5 对比时加 `AND data_source IN ('digikey')`（或 README 声明的源列表）。

### 0.2 跨 L1 gate category 重叠（机械门控 G1）

```bash
python3 .cursor/skills/component-etl-methodology/tools/validate_cross_l1_gate_overlap.py \
  --prod-schema dim \
  --sandbox-schema test_dim \
  --sandbox-l1 <l1> \
  --data-source digikey   # 单源 L1 只扫声明的源
```

非 0 → **stop**。修复：认 DK `category_info` path / taxonomy 边界，从一方 gate 移除重叠 category（见 LL-20260622-01）。prod 内其它 L1 之间的历史重叠需 owner 登记豁免或单独治理，但**待合并 L1 不得新增与 prod 的争用**。

### 1. PK 冲突预检

```sql
-- l3_id 必须 0；允许替换同一 L1 的旧 id，但不能撞到其他 L1
SELECT COUNT(*) FROM (
  SELECT l3_id FROM dim.dim_l3_classify WHERE l1_code <> '<l1>'
  UNION ALL SELECT l3_id FROM test_dim.dim_l3_classify_<l1>
) u GROUP BY l3_id HAVING COUNT(*)>1;

-- rule PK 必须 0；允许替换同一 L1 的旧 rule，但不能撞到其他 L1 / 其他前缀
WITH prod_keep_rule AS (
  SELECT r.rule_id, r.clause_group_id, r.clause_ord
  FROM dim.dim_l3_classify_rule r
  LEFT JOIN dim.dim_l3_classify d
    ON d.l3_id = r.l3_id AND d.schema_version = r.schema_version
  WHERE COALESCE(d.l1_code, '') <> '<l1>'
    AND r.rule_id NOT REGEXP '^<l1>_'
    AND r.rule_id NOT REGEXP '^gate_<l1>_'
)
SELECT COUNT(*) FROM (
  SELECT rule_id, clause_group_id, clause_ord FROM prod_keep_rule
  UNION ALL SELECT rule_id, clause_group_id, clause_ord FROM test_dim.dim_l3_classify_rule_<l1>
) u GROUP BY rule_id, clause_group_id, clause_ord HAVING COUNT(*)>1;
```

非 0 → **stop**，让 owner 改 l3_id 段位 / 加 rule_id 前缀，回阶段 1 重做。这里检查的是“撞到其他 L1/其他规则”，不是同 L1 替换。

### 2. 质量检查

```sql
SELECT l1_code, COUNT(*) FROM test_dim.dim_l3_classify_<l1> GROUP BY 1;
SELECT l3_id, l1_code, l2_code, l3_code
FROM test_dim.dim_l3_classify_<l1>
WHERE l3_id NOT REGEXP '^[0-9]{6}$'
   OR LEFT(l3_id, 2) <> '<l1_id_prefix>';
SELECT l2_code, l3_code, COUNT(*) AS rows_
FROM test_dim.dim_l3_classify_<l1>
WHERE l2_code REGEXP '_base$'
   OR l2_code NOT REGEXP '^[a-z0-9]+(_[a-z0-9]+)*$'
   OR l3_code NOT REGEXP '^[a-z0-9]+(_[a-z0-9]+)*$'
GROUP BY 1, 2;
SELECT rule_id, COUNT(*)
FROM test_dim.dim_l3_classify_rule_<l1>
WHERE rule_id NOT REGEXP '^<l1>_' AND rule_id NOT REGEXP '^gate_<l1>_'
GROUP BY 1;
SELECT data_source, COUNT(*) AS gate_rows
FROM test_dim.dim_l3_classify_rule_<l1>
WHERE enabled = 1 AND rule_kind = 'gate'
GROUP BY 1;
```

异常则 stop，让 owner 回分支修正并重跑阶段 1。

### 3. 只读确认生产替换范围

```sql
SELECT l3_id, schema_version, l1_code, l2_code, l3_code
FROM dim.dim_l3_classify
WHERE l1_code = '<l1>'
ORDER BY l3_id, schema_version;
SELECT r.rule_id, r.clause_group_id, r.clause_ord, r.data_source, r.l3_id, r.schema_version
FROM dim.dim_l3_classify_rule r
LEFT JOIN dim.dim_l3_classify d
  ON d.l3_id = r.l3_id AND d.schema_version = r.schema_version
WHERE d.l1_code = '<l1>' OR r.rule_id REGEXP '^<l1>_' OR r.rule_id REGEXP '^gate_<l1>_'
ORDER BY r.rule_id, r.clause_group_id, r.clause_ord;
SELECT 'new_taxonomy' AS t, COUNT(*) FROM test_dim.dim_l3_classify_<l1>
UNION ALL SELECT 'new_rule' AS t, COUNT(*) FROM test_dim.dim_l3_classify_rule_<l1>;
```

人工确认删除范围只覆盖该 L1，插入行数等于阶段 1 后缀表验收结果。

### 4. prod dim 替换发布

执行前把 `<merge_tag>` 替换成本次合并标识（建议 `YYYYMMDDHHMM` 或分支短名），不要复用旧备份表。

```sql
CREATE TABLE dim.bak_dim_l3_classify_<l1>_<merge_tag> AS
SELECT * FROM dim.dim_l3_classify WHERE l1_code = '<l1>';
CREATE TABLE dim.bak_dim_l3_classify_rule_<l1>_<merge_tag> AS
SELECT r.*
FROM dim.dim_l3_classify_rule r
LEFT JOIN dim.dim_l3_classify d
  ON d.l3_id = r.l3_id AND d.schema_version = r.schema_version
WHERE d.l1_code = '<l1>' OR r.rule_id REGEXP '^<l1>_' OR r.rule_id REGEXP '^gate_<l1>_';
DELETE FROM dim.dim_l3_classify_rule
WHERE rule_id REGEXP '^<l1>_'
   OR rule_id REGEXP '^gate_<l1>_'
   OR (l3_id, schema_version) IN (
        SELECT l3_id, schema_version FROM dim.dim_l3_classify WHERE l1_code = '<l1>'
      );
DELETE FROM dim.dim_l3_classify WHERE l1_code = '<l1>';
INSERT INTO dim.dim_l3_classify SELECT * FROM test_dim.dim_l3_classify_<l1>;
INSERT INTO dim.dim_l3_classify_rule SELECT * FROM test_dim.dim_l3_classify_rule_<l1>;
```

StarRocks 不支持多列 `IN` 时，用临时表保存待删 key 后分步删除。

只有用户明确确认后才执行。不要自动推断 prod 授权。

### 5. test_dwd 跑正式脚本验证

生产 dim 替换完成后，先用主干 `dwd_component_class.sql` 的正式逻辑输出到 `test_dwd` 临时表，对比阶段 1 的 `test_dwd.dwd_component_class_<l1>`。这里只替换输出表，不替换 `dim.` 和源 `dwd.dwd_<source>_component_param`。

```bash
python3 - <<'PY' > /tmp/dwd_component_class_to_test_dwd_<l1>.sql
from pathlib import Path

src = Path("sql_scripts/1.classify/dwd_component_class.sql").read_text(encoding="utf-8")
src = src.replace("dwd.dwd_component_class", "test_dwd.dwd_component_class_merge_<l1>")
Path("/tmp/dwd_component_class_to_test_dwd_<l1>.sql").write_text(src, encoding="utf-8")
PY

set -a
source sql_scripts/local.env
set +a
mysql -h "${MYSQL_HOST:-192.168.19.21}" -P "${MYSQL_PORT:-9030}" \
  -u "${MYSQL_USER:-root}" "-p${MYSQL_PASSWORD}" \
  --default-character-set=utf8mb4 \
  < /tmp/dwd_component_class_to_test_dwd_<l1>.sql
```

```sql
SELECT data_source, l1_code, COUNT(*) AS rows_
FROM test_dwd.dwd_component_class_merge_<l1>
WHERE l1_code = '<l1>'
  AND data_source IN (/* README 声明的源，如 'digikey' */)
GROUP BY 1, 2 ORDER BY 1, 2;

SELECT data_source, l1_code, COUNT(*) AS rows_
FROM test_dwd.dwd_component_class_<l1>
WHERE l1_code = '<l1>'
  AND data_source IN (/* 同上 */)
GROUP BY 1, 2 ORDER BY 1, 2;
```

行数和 L3 分布与阶段 1 基线不一致时，先排查规则，不要继续写 prod DWD。  
**单源 L1**：merge 表在 `data_source` 范围外的行数应为 0；若 >0，说明 dim 仍含范围外 gate/规则，或 merge 表为旧仿真残留，不得与沙盒 ~8k 行相加当作目标行数。

### 6. prod 重跑 classify

```bash
# 不要用 run_classify.sh prod；它会先重建 dim，覆盖本次从 test_dim 写入的生产 dim。
set -a
source sql_scripts/local.env
set +a
mysql -h "${MYSQL_HOST:-192.168.19.21}" -P "${MYSQL_PORT:-9030}" \
  -u "${MYSQL_USER:-root}" "-p${MYSQL_PASSWORD}" \
  --default-character-set=utf8mb4 \
  < sql_scripts/1.classify/dwd_component_class.sql
```

### 7. 校验

```sql
SELECT data_source, l1_code, COUNT(*) AS rows_
FROM dwd.dwd_component_class
WHERE l1_code = '<l1>'
GROUP BY 1, 2 ORDER BY 1, 2;
```

- 新 L1 出现且行数 ≈ 阶段 1 测试值（**按 README 声明的 `data_source` 分别对比**，单源 L1 勿把 icpdf 全库行数算入）
- 已有 L1 行数 ±0.5%
- 大于 1% → 排查同事是否改了规则未同步

### 8. cleanup

```sql
DROP TABLE IF EXISTS test_dim.dim_l3_classify_<l1>;
DROP TABLE IF EXISTS test_dim.dim_l3_classify_rule_<l1>;
DROP TABLE IF EXISTS test_dwd.dwd_component_class_<l1>;
DROP TABLE IF EXISTS test_dwd.dwd_component_class_merge_<l1>;
```

```bash
# 若 attribute_standard 阶段 2 也已完成，可一并删 test 目录
git rm -r sql_scripts/test/<l1>/
```

### 9. commit + push

```bash
git add sql_scripts/test/<l1>/
git commit -m "feat(classify): add <l1> taxonomy validation scripts

prod 行数（dwd.dwd_component_class，仅本 L1 接入的 data_source）：
- digikey.<l1>: NNN,NNN  (如 README 仅得捷)
- icpdf.<l1>: NNN,NNN  (仅当 README 声明含 icpdf 时填写；单源 L1 写 N/A 或省略)
"
# user 明确确认后 git push
```

## Failure modes

| 现象 | 处理 |
|------|------|
| Step 1 PK 冲突 | Stop. 让 owner 改 `l3_id` 段位 / `rule_id` 加 `<l1>_` 前缀，回阶段 1 |
| Step 2 质量检查失败 | Stop. 让 owner 统一 `rule_id`、`data_source`、`schema_version` 后重跑阶段 1 |
| Step 3 DELETE 范围不确定 | 先只查不删，列出将删除的 `rule_id` / `l3_id` 给人工确认；必要时建临时表 |
| Step 5 test_dwd 验证新 L1 行数 = 0 | 缺 `gate_<l1>_<source>_v1` 规则；确认规则表含 gate + classify 两类行 |
| Step 5 build crash `parjson_match_map` | `match_map` 不是合法 JSON 对象（单引号不行） |
| Step 6 不小心用了 `run_classify.sh prod` | 它会重建 dim，可能覆盖本次合并；立即检查 `dim.dim_l3_classify*` 该 L1 是否还在，必要时从 `test_dim.*_<l1>` 重新执行 Step 4 |
| Step 7 已有 L1 漂移 > 1% | 替换范围可能误删跨 L1 规则；用备份表恢复并逐条排查 |

## Reference files

- 操作 SOP（人读）：`sql_scripts/1.classify/CONTRIB.md`
- 引擎语义：`sql_scripts/1.classify/RULE_ENGINE.md`
- 阶段 1 测试库流程：`sql_scripts/test/README.md`
- multi-source cutover 历史：`sql_scripts/PROD_CUTOVER.md`
- DDL：`sql_scripts/1.classify/dim_l3_classify.sql`、`dim_l3_classify_rule.sql`
- Build：`sql_scripts/1.classify/dwd_component_class.sql`（多源单脚本 + DDL）
- Runner：`sql_scripts/1.classify/run_classify.sh`（当前会先重建 dim；新 L1 后缀表合并后不要直接用于 prod）
- 属性合并 skill：`.cursor/skills/dim-attr-std-merge/SKILL.md`

## Anti-patterns

- ❌ 恢复 `LEFT JOIN best`（写未分类污染下游）；保持 `INNER JOIN best`
- ❌ 在 `rules_classify` 加 `AND d.l1_code = '<l1>'`（破坏多 L1 共用）
- ❌ 加 `AND d.schema_version = 'v1.5.09'` 这类 hardcode（commit `0750d75` 已移除）
- ❌ 新 L1 合并时人工拼接共享规则文件；默认从 `test_dim` 后缀表按 L1 替换
- ❌ MAP/ARRAY 用 SQL `map(...)` / `[...]` 字面量；跨脚本导入时统一用 JSON
- ❌ commit `__pycache__` / `local.env` / `/tmp/` 临时文件
- ❌ 给已有 L1 小改动也走新 L1 合并流程；小改动应单独评审变更范围后直接改生产规则
- ❌ macOS sed `\b`（不支持）；用精确字面匹配或 python re.sub
