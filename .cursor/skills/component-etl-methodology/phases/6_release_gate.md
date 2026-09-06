# 阶段 6 · 人工授权门控 + 合并发布检查清单

> **本阶段一句话**：测试机器指标通过 ≠ 自动发 prod；test → prod 边界每次都需要独立的人工放行。
> 占工期：约 7%（人工等待 + 机器自动校验）。
>
> ⚠️ **本阶段的关键不是"做什么"，而是"什么时候 Agent 必须停下来等人"**。

---

## 6.0 双层门控总览

**从 test 到 prod 必须同时满足两侧门控**：

```
┌──────────────────────────┬──────────────────────────┐
│ 机器侧（必要不充分）       │ 人工侧（必须显式确认）     │
│                          │                          │
│ ☐ PK 冲突预检 = 0         │ ☐ 5.5 审计报告已审阅      │
│   （只锁撞其他 L1）        │                          │
│ ☐ test_dim 质量检查 OK    │ ☐ 业务方书面确认"可发"     │
│   + prod 删除范围确认      │                          │
│ ☐ brand_null = 0         │ ☐ ALLOW_PROD=1 由人设      │
│ ☐ dt = di                │ ☐ 下游消费方已知会         │
│ ☐ 行数变化在 ±1%          │                          │
│ ☐ 5.5 审计 P0 全部修复    │                          │
│ ☐ 品牌查重 BD1=0          │                          │
│   （动过 dim_std_brand 时）│                          │
└──────────────────────────┴──────────────────────────┘
```

**只过机器侧不过人工侧 = 不能发布**。
**机器侧任何一项不过 = 不能发布**。

---

## 6.1 Agent / 自动化脚本的硬约束

| 约束 | 含义 | 后果 |
|------|------|------|
| 测试通过 ≠ 自动进入 prod | Agent 不得在未获人工确认时自动执行任何 prod 写操作 | 越权发布、无追溯人 |
| SOP / SKILL 列出"下一步是 prod" ≠ 授权 | 步骤清单只是流程示意，每跨越 test → prod 边界都需独立的人工放行 | 把流程图当成"自动驾驶清单" |
| `ALLOW_PROD=1` 不应由 Agent 自行设置 | 该环境变量是"双手开车"机制，物理上阻止 Agent 单独完成发布 | 安全机制失效 |
| 已发现但未告知人的问题不得跳过 | 5.5 审计发现的 P0 没修就发布 = 明知有 bug 还上线 | 业务方失去信任 |

### Agent 行为模式（强制）

进入阶段 6 时，Agent 必须做：

1. **明确告知用户**：「现在处于 test → prod 边界，需要您显式授权才能继续。」
2. **列出机器侧已通过的项**，证明前置条件已 OK
3. **列出待人工确认的项**（含 5.5 审计报告的链接）
4. **停下来等用户回答**「确认通过，可以发」或者「不通过，需要修 XX」

**Agent 绝不能做的**：

- ❌ 不能"顺势"跑 prod 命令（即使 SOP 写了下一步是 prod）
- ❌ 不能自己 `export ALLOW_PROD=1`
- ❌ 不能用"测试通过了所以应该可以发了吧" 这种话术诱导用户
- ❌ 不能在 5.5 审计 P0 未修的情况下声称"基本上没问题，可以发"

---

## 6.2 机器侧自动校验清单

### 6.2.1 PK 冲突预检（合并前必跑，只锁"撞其他 L1"）

> 替换范式下要检查的是「test_dim 后缀表是否撞到**其他 L1**」，而不是撞同 L1 的旧行（同 L1 旧行会被 DELETE 后替换）。故 prod 侧须 `WHERE l1_code <> '<l1>'`（+ 排除本 L1 rule_id 前缀），后缀表用 `test_dim.*_<l1>`。

**分类 dim**：

```sql
SELECT COUNT(*) FROM (
  SELECT l3_id FROM dim.dim_l3_classify WHERE l1_code <> '<l1>'
  UNION ALL SELECT l3_id FROM test_dim.dim_l3_classify_<l1>
) u GROUP BY l3_id HAVING COUNT(*) > 1;

SELECT COUNT(*) FROM (
  SELECT r.rule_id FROM dim.dim_l3_classify_rule r
  LEFT JOIN dim.dim_l3_classify d ON d.l3_id=r.l3_id AND d.schema_version=r.schema_version
  WHERE COALESCE(d.l1_code,'') <> '<l1>'
    AND r.rule_id NOT REGEXP '^<l1>_' AND r.rule_id NOT REGEXP '^gate_<l1>_'
  UNION ALL SELECT rule_id FROM test_dim.dim_l3_classify_rule_<l1>
) u GROUP BY rule_id HAVING COUNT(*) > 1;
```

**属性 dim**：

```sql
SELECT COUNT(*) FROM (
  SELECT schema_version, l1_code, scope_level, scope_code, std_attr_code
  FROM dim.dim_attr_schema WHERE l1_code <> '<l1>'
  UNION ALL SELECT schema_version, l1_code, scope_level, scope_code, std_attr_code
  FROM test_dim.dim_attr_schema_<l1>
) u GROUP BY 1,2,3,4,5 HAVING COUNT(*) > 1;

SELECT COUNT(*) FROM (
  SELECT extract_rule_id FROM dim.dim_attr_extract_rule
  WHERE l1_code <> '<l1>' AND extract_rule_id NOT REGEXP '^<l1>_'
  UNION ALL SELECT extract_rule_id FROM test_dim.dim_attr_extract_rule_<l1>
) u GROUP BY extract_rule_id HAVING COUNT(*) > 1;
```

**所有结果必须为 0 行**。如有冲突：停止合并，与提交者协商重命名（带 L1 前缀）。

### 6.2.2 质量检查 + 只读列出替换范围

> 合并源是 `test_dim.*_<l1>` 后缀表：对后缀表做质量检查（单一 l1、snake_case、rule_id 前缀、gate 行、schema_version），并只读列出生产将删除/写入的范围供人工确认。

```sql
-- 质量检查：l1_code 单一、snake_case、rule_id 前缀、gate 行存在、schema_version 对齐
SELECT l1_code, COUNT(*) FROM test_dim.dim_l3_classify_<l1> GROUP BY 1;        -- 应只有 1 个 l1
SELECT rule_id FROM test_dim.dim_l3_classify_rule_<l1>
WHERE rule_id NOT REGEXP '^<l1>_' AND rule_id NOT REGEXP '^gate_<l1>_';        -- 应 0 行
SELECT extract_rule_id FROM test_dim.dim_attr_extract_rule_<l1>
WHERE extract_rule_id NOT REGEXP '^<l1>_';                                     -- 应 0 行

-- 只读列出生产将删除的旧 L1 key（不执行删除，先给人工确认）
SELECT l3_id, l1_code, l2_code, l3_code FROM dim.dim_l3_classify WHERE l1_code='<l1>';
SELECT extract_rule_id FROM dim.dim_attr_extract_rule
WHERE l1_code='<l1>' OR extract_rule_id REGEXP '^<l1>_';
```

异常 → 停止合并，让 owner 回分支修正并重跑阶段 1。删除范围必须只覆盖该 L1。

### 6.2.3 行数漂移验收

```sql
-- 上次基线行数（如有）
SELECT l1_code, COUNT(*) FROM dwd.dwd_component_class GROUP BY l1_code;

-- 与本次比较
-- 已有 L1 行数变化应在 ±1% 以内
```

超过 ±1% → 检查 gate 规则是否足够严格、是否有跨 L1 误判。

### 6.2.4 test_dim 后缀表 PK 完整性

```sql
-- 后缀表自身 PK 去重检查（应全部 0 行）
SELECT l3_id, COUNT(*) FROM test_dim.dim_l3_classify_<l1> GROUP BY 1 HAVING COUNT(*)>1;
SELECT rule_id, clause_group_id, clause_ord, COUNT(*)
FROM test_dim.dim_l3_classify_rule_<l1> GROUP BY 1,2,3 HAVING COUNT(*)>1;
SELECT schema_version, l1_code, scope_level, scope_code, std_attr_code, COUNT(*)
FROM test_dim.dim_attr_schema_<l1> GROUP BY 1,2,3,4,5 HAVING COUNT(*)>1;
SELECT extract_rule_id, COUNT(*) FROM test_dim.dim_attr_extract_rule_<l1> GROUP BY 1 HAVING COUNT(*)>1;
```

**StarRocks 的 REPLACE 语义**：PRIMARY KEY 表里若有重复 PK 会被静默吞掉（DB 行数 < 预期），合并前后缀表必须先去重。

### 6.2.5 品牌字典查重（动过 `dim_std_brand` 时必跑）

> 仅当本次发布**新增/修改了品牌字典**（`dim_std_brand_manual_extra.sql` 或 jp_brand 重写丰富）才触发。`sync_dim_std_brand.sh` 末尾已自动跑；此处是发布门控的显式复核。品牌字典是跨 L1 共享基础设施，一条脏行会污染所有 L1 的 `brandid`。

```bash
python .cursor/skills/component-etl-methodology/tools/validate_brand_dim_dup.py --dim-schema dim
# 退出码 0 = 无未豁免重复；非零 = 有「同公司多 id」未登记
```

按**归一化品牌名**（大写+去公司后缀+去非字母数字）聚合 `dim_std_brand`(state=1)，同 key 落 >1 个 `brand_id_std` 即 BD1 FAIL。补宽表门控 DL1（`distinct brand=distinct brandid`）抓不到「一公司多 id」的盲区。处理：

- 真重复（同一公司）→ 走 `CONTRIB_BRAND.md` A 类复用既有 id，或用 `sql_scripts/brand_merge/` 统一收口（merge_map + soft-delete + dwd_l2 回填）。
- 伪重复（缩写撞车的不同公司）→ 登记 `validate_brand_dim_dup.py` 白名单 / `--waiver` / env `BRAND_DUP_WAIVER`，留痕。

**BD1 必须 = 0 才放行**。详见 [lessons_learned.md#LL-20260625-01](../lessons_learned.md)。

---

## 6.3 人工侧确认清单

### 6.3.1 必须发生的对话

**Agent 发起**：

> 「<L1> 数据清洗已完成 test 环境验证：
> - PK 冲突预检（只锁撞其他 L1）：0 行 ✅
> - test_dim 后缀表质量检查 + prod 删除范围只读确认：通过 ✅
> - 每张 L2 brand_null=0，dt=di ✅
> - 5.5 数据质量审计报告：[链接到 `artifacts/<l1>/qa_audit_report_<date>.md`]
> - 本轮 P0 项 N 条已全部修复并通过复验 ✅
> - 待您审阅审计报告并显式授权。请回复 ”确认通过，可发 prod“ 或具体修改要求。」

**用户回复**：必须是显式的 ”确认“ 或 ”不通过“，含糊回复（如 "好的"、"看着办"）不算授权。

### 6.3.2 ALLOW_PROD=1 由人设置

```bash
# 用户自己执行（Agent 不能代劳）
export ALLOW_PROD=1
# Agent 可以提示"请运行 export ALLOW_PROD=1 后告诉我可以继续"
```

合并脚本应在最外层做检查：

```bash
if [[ "${ALLOW_PROD:-0}" != "1" ]]; then
    echo "ALLOW_PROD 未设置为 1，拒绝执行 prod 合并。" >&2
    exit 1
fi
```

### 6.3.3 下游消费方知会

发布前 24 小时通知下游消费方：

- 哪些表会变（新增 L2 / 已有 L2 行数变化）
- 哪些列会变（新增列 / 列宽变化）
- 回滚预案（如何快速恢复到本次发布前的状态）

---

## 6.4 合并执行步骤（人工授权后）

### 6.4.1 顺序

```
1. 跑 PK 冲突预检（合并前最后一次，只锁撞其他 L1）
2. 备份 prod 旧 L1：CREATE dim.bak_*_<l1>_<merge_tag>，INSERT 该 L1 现有行
3. 按 L1 替换 prod dim：DELETE prod 旧 L1 → INSERT FROM test_dim.*_<l1> 后缀表
   （dim_l3_classify, dim_l3_classify_rule, dim_attr_schema, dim_attr_extract_rule；
    dim_unit_factor 只追加缺失单位，不按 L1 删）
4. 重跑 prod 分类引擎：直接执行主干 dwd_component_class.sql
   禁止 run_classify.sh prod —— 它会重建 dim、覆盖刚写入的 prod dim
5. 重跑 prod EAV 引擎（基于替换后的 prod dim）
6. 重跑所有 L2 build（不只是新 L1 的，所有 L1 的）
7. DROP test_dim/test_dwd 后缀表 + git rm sql_scripts/test/<l1>/
8. 重跑验收探针
```

> prod dim 的唯一写入来源是 test_dim 后缀表。

### 6.4.2 重跑所有 L2 build 的必要性

新 L1 EAV 数据合并进统一 `dwd_component_attr_std` 后，**已有 L1 的 L2 宽表用的是合并前的 EAV 快照**。如果不重跑：

- 已有 L1 的 L2 宽表是过时数据
- 跨 L1 的时间层漂移（新 L1 是 T+0，旧 L1 是 T-1）

必须重跑所有 L2 build（幂等操作，重跑无副作用）。

### 6.4.3 全库扫描沙盒表引用（合并后）

```bash
# 必须没有遗留
rg 'test_dwd\.' sql_scripts/   # 应为空（除了 README 中的示例）
rg 'test_dim\.' sql_scripts/   # 应为空（除了 README 中的示例）

# 通用引擎里不能有硬编码 L1（每个源各有一份 build_dwd_component_attr_std_<source>.sql）
rg "WHERE l1_code\s*=\s*'" sql_scripts/2.attribute_standard/build_dwd_component_attr_std_*.sql
# 应该没有命中
```

---

## 6.5 误触 prod 后的补救（万一发生）

> 这一节存在的意义不是鼓励冒险，而是承认人会犯错，需要预先准备好补救路径。

### 6.5.1 发现误触的迹象

- 发布日志显示有 prod 表的 `INSERT` / `REPLACE` / `DROP` / `ALTER` 操作
- prod 表行数突然变化、列结构发生改变
- 下游消费方报告数据异常

### 6.5.2 立即停损

1. **立即停止后续操作**。不再跑任何 prod 命令，包括"想修复的命令"。
2. **快速评估影响范围**：
   ```sql
   -- 哪些表的行数 / schema 变了？
   SELECT table_schema, table_name, table_rows, update_time
   FROM information_schema.tables
   WHERE table_schema IN ('dim', 'dwd') AND update_time > '<事故时间>';
   ```
3. **通知数据负责人 + 下游消费方**：即使还没确认影响范围，也要立刻告知。

### 6.5.3 回滚路径

| 误触类型 | 回滚 |
|---------|------|
| dim 该 L1 被错误替换/删除 | 从本次 `dim.bak_*_<l1>_<merge_tag>` 备份表恢复该 L1，**不要全量 DROP 主表** |
| 误删跨 L1 规则（替换范围越界） | 从 `bak_*_<merge_tag>` 恢复后逐条排查 DELETE 条件 |
| 误跑 `run_classify.sh prod` 重建 dim | 检查 `dim.dim_l3_classify*` 该 L1 是否还在；缺失则从 `test_dim.*_<l1>` 重新执行替换步骤。重建结果表只用主干 `dwd_component_class.sql` |
| DDL 被改 | 用上次发布的 DDL 重建表，从最近一次 backup / 上游重灌数据 |
| EAV 数据被污染 | DELETE 受影响的 l1_code 后重跑 EAV 引擎 |

**通用纪律**：

- **prod dim 的真相源是 test_dim 后缀表 + 本次 `bak_*_<merge_tag>` 备份**：替换前必须先备份该 L1，回滚从备份表恢复
- **EAV 是窄表**：可以重跑，重跑是幂等
- **L2 宽表**：可以从 EAV 重建，重跑是幂等
- **最难恢复的是 DDL 变更和 source 数据**：一旦 ALTER / DROP 真实物理表，需要从 backup / 上游恢复

### 6.5.4 事后复盘

事故必须出 RCA（root cause analysis）：

1. 误触发生的具体动作链
2. 为什么没被 6.0 / 6.1 拦下
3. 影响范围（哪些表 / 行 / 下游）
4. 修复动作
5. 预防措施（增加什么自动检查、修改哪些 SOP）

**事故 RCA 入仓**：`artifacts/incidents/<date>_<incident_name>.md`。

---

## 6.6 产物清单

| 产物 | 落到哪里 |
|------|---------|
| PK 冲突预检结果 | `artifacts/<l1>/pk_collision_<date>.tsv` |
| verify hash 报告 | 命令行输出留痕 |
| 行数漂移报告 | `artifacts/<l1>/rowcount_drift_<date>.tsv` |
| **业务方授权留痕** | PR 评论 / Ticket / 聊天截图，归档到 `artifacts/<l1>/auth_<date>.md` |
| 合并日志 | `artifacts/<l1>/merge_log_<date>.log` |
| 重跑所有 L2 build 的结果 | `artifacts/<l1>/post_merge_rebuild_<date>.log` |

---

## 6.7 反模式

| 反模式 | 后果 |
|--------|------|
| 测试通过就连着跑 prod | 跨越 test → prod 边界没有独立人工放行 |
| SOP 排到 prod 就连着跑 | 把流程图当自动驾驶 |
| Agent 自己 `export ALLOW_PROD=1` | 安全机制失效 |
| 业务方含糊回复 "好的" 就算授权 | 没有明确的"通过 / 不通过"留痕 |
| 5.5 审计 P0 没修就声称"基本可发" | 已知有 bug 还上线 |
| 合并后只重跑新 L1 的 L2 build | 已有 L1 的 L2 宽表是过时数据 |
| 误触 prod 后"想办法修复"而不是先停损 | 把小事故扩大成大事故 |
| 事故后不做 RCA | 同样的错误下次还会犯 |

---

## 6.8 完成判定

```
机器侧（自动校验）
☐ PK 冲突预检 = 0（只锁撞其他 L1，分类 dim + 属性 dim）
☐ test_dim 后缀表质量检查通过（单一 l1、snake_case、rule_id 前缀、gate 行、schema_version）
☐ 只读列出的 prod 删除范围只覆盖该 L1，已人工确认
☐ test 宽表 brand_null = 0 / dt = di
☐ 5.5 审计报告已产出，本轮 P0 项全部修复并通过复验
☐ test 宽表行数与上一基线差异在 ±1% 以内
☐ 动过品牌字典时：validate_brand_dim_dup.py BD1 = 0（无未豁免「同公司多 id」）

人工侧（必须显式确认）
☐ 业务方 / 数据负责人审阅过 5.5 审计报告
☐ 明确给出"通过，可发 prod"的书面或聊天确认（留痕到 PR / Ticket）
☐ ALLOW_PROD=1 由具备发布权限的人手动设置
☐ 发布窗口、回滚预案已知会下游消费方

合并执行（人工授权后）
☐ prod 旧 L1 已备份到 dim.bak_*_<l1>_<merge_tag>
☐ 按 L1 替换 prod dim 完成（DELETE 旧 L1 → INSERT FROM test_dim 后缀表）
☐ prod 分类引擎重跑（只用主干 dwd_component_class.sql；禁 run_classify.sh prod）
☐ prod EAV 引擎已重跑
☐ 所有 L2 build 已重跑（不止新 L1）
☐ test_dim/test_dwd 后缀表已 DROP + git rm sql_scripts/test/<l1>/
☐ 全库扫描确认无 test_dwd / test_dim 引用残留
☐ 通用引擎 SQL 无硬编码 L1 过滤
```

所有满足后，进入 [`7_acceptance.md`](7_acceptance.md) 五维验收。
