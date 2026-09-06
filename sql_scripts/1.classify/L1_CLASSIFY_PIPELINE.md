# L1 分类清洗 · 端到端总览

适用：新接入或重做某个 **L1 大类**（如 `data_converter`、`inductor`）的 **gate + classify** 规则，在 test 库验证后合入 prod。

| 相关文档 | 说明 |
|---|---|
| [`../L1_STD_PIPELINE.md`](../L1_STD_PIPELINE.md) | 分类 + 属性完整总图 |
| [`CONTRIB.md`](CONTRIB.md) | 阶段 2 合并 SOP（逐步 SQL） |
| [`RULE_ENGINE.md`](RULE_ENGINE.md) | gate / classify 谓词与决选语义 |
| [`../test/README.md`](../test/README.md) | test 库后缀表命名与三阶段约定 |

---

## 1. 三阶段总图

```mermaid
flowchart TB
  subgraph phase1 [阶段 1 · test 库后缀隔离]
    direction TB
    S1["1.1 探查类目 / gate 口径<br/>discover_*.sql · audit"]
    S2["1.2 规则真源<br/>seed/gen_rule_csv.py"]
    S3["1.3 装载 test_dim<br/>dim_l3_classify_&lt;l1&gt;<br/>dim_l3_classify_rule_&lt;l1&gt;"]
    S4["1.4 沙盒 build<br/>build_dwd_*_component_class_&lt;l1&gt;.sql"]
    S5["1.5 验收<br/>gate 行数 / L3 分布 / 孤儿 / 抽样"]
    S1 --> S2 --> S3 --> S4 --> S5
  end

  subgraph phase2 [阶段 2 · 合 prod dim + 回归 DWD]
    direction TB
    P1["2.1 PK / l3_id / rule_id 预检"]
    P2["2.2 备份 → 按 L1 替换 prod dim"]
    P3["2.3 主干引擎 → test_dwd merge 表<br/>run_classify_merge.py --step 5"]
    P4["2.4 ALLOW_PROD=1 重跑 prod DWD<br/>--step 6"]
    P1 --> P2 --> P3 --> P4
  end

  subgraph phase3 [阶段 3 · 清理]
    C1["DROP test_dim / test_dwd 分类后缀表"]
    C2["git rm sql_scripts/test/&lt;l1&gt;/"]
  end

  phase1 -->|"阶段 1 PASS"| phase2
  phase2 --> phase3
```

**合并边界**：只合并 `dim_l3_classify` + `dim_l3_classify_rule`；`dwd_component_class.sql` 以主干最新引擎为准，不用沙盒 build 覆盖。

---

## 2. 阶段 1 详图

目录：`sql_scripts/test/<l1>/`

```mermaid
flowchart LR
  subgraph inputs [输入 · prod 只读]
    ALL["foundation/dim_l3_classify_all.sql<br/>L3 段位规划"]
    PARAM["dwd.dwd_&lt;source&gt;_component_param"]
  end
  subgraph sandbox [test 库后缀表]
    TC["test_dim.dim_l3_classify_&lt;l1&gt;"]
    TR["test_dim.dim_l3_classify_rule_&lt;l1&gt;"]
    TD["test_dwd.dwd_component_class_&lt;l1&gt;"]
  end
  subgraph artifacts [脚本与验收]
    SEED["seed/gen_rule_csv.py"]
    LOAD["seed/load_rules_from_csv.py"]
    BUILD["build_dwd_*_&lt;l1&gt;.sql"]
    AUDIT["audit/validate_classify_rules.py<br/>run_test_python.py"]
  end
  ALL --> TC
  SEED --> LOAD --> TR
  LOAD --> TC
  TR --> BUILD
  PARAM --> BUILD
  BUILD --> TD
  TD --> AUDIT
```

| 步骤 | 动作 | 典型产物 |
|---|---|---|
| 1.1 | 探查 gate 口径（`category` / `note_cn` / `category2`） | `audit/discover_*.sql` |
| 1.2 | 编写 gate（include + exclude）与 classify 规则 | `seed/gen_rule_csv.py` |
| 1.3 | 装载 `test_dim` 后缀表 | `seed/load_rules_from_csv.py` |
| 1.4 | 沙盒跑分类（简化 build 或复制引擎逻辑） | `build_dwd_*_component_class_<l1>.sql` |
| 1.5 | 离线 + DB 验收 | `audit/validate_classify_rules.py`、`run_classify_merge.py --step 5`（合 prod 前） |

**验收硬指标**

- gate 放行行数稳定，且与业务口径一致
- gate 内 classify 覆盖率 **100%**（无孤儿 SKU）
- L3 分布合理（无单 L3 吞噬全部行）
- 阶段 1 基线与主干引擎 merge 表偏差 **≤ ±0.5%**

---

## 3. 阶段 2 详图（合 prod）

```mermaid
flowchart LR
  subgraph src [来源 · 阶段 1]
    TT["test_dim.dim_l3_classify_&lt;l1&gt;"]
    TR["test_dim.dim_l3_classify_rule_&lt;l1&gt;"]
    BASE["test_dwd.dwd_component_class_&lt;l1&gt;<br/>基线"]
  end
  subgraph prod_dim [prod dim]
    DT["dim.dim_l3_classify"]
    DR["dim.dim_l3_classify_rule"]
  end
  subgraph verify [验证与写 prod]
    MERGE["test_dwd.dwd_component_class_merge_&lt;l1&gt;<br/>--step 5"]
    PROD["dwd.dwd_component_class<br/>--step 6"]
  end
  TT -->|"按 L1 替换"| DT
  TR -->|"按 L1 替换"| DR
  DR --> MERGE
  BASE -.->|"±0.5%"| MERGE
  MERGE -->|"ALLOW_PROD=1"| PROD
```

| 步骤 | 动作 | 入口 |
|---|---|---|
| 2.1 | PK / `l3_id` / `rule_id` 预检 | [`CONTRIB.md`](CONTRIB.md) Step 1 |
| 2.2 | 备份 → 删除 prod 旧 L1 dim → 插入 test_dim | skill `dim-l3-classify-merge` 或 CONTRIB Step 4 |
| 2.3 | 主干 `dwd_component_class.sql` → merge 表 | `test/<l1>/audit/run_classify_merge.py --step 5` |
| 2.4 | 重跑 prod `dwd.dwd_component_class` | `--step 6`（需 `ALLOW_PROD=1`） |

**注意**

- **不要**用 `run_classify.sh prod`（会重建 dim）；直接跑 [`dwd_component_class.sql`](dwd_component_class.sql)。
- 合 prod 后校验各 `(data_source, l1)` 行数、L3 分布，确认其他 L1 无漂移。

---

## 4. 运行时引擎（每次重跑 DWD）

谓词与决选细节见 [`RULE_ENGINE.md`](RULE_ENGINE.md)。

```mermaid
flowchart LR
  subgraph dim [dim 维表]
    T[dim_l3_classify]
    R[dim_l3_classify_rule]
  end
  subgraph param [各源 param]
    P1[dwd_icpdf_component_param]
    P2[dwd_digikey_component_param]
  end
  subgraph engine [dwd_component_class.sql]
    G["Gate<br/>include − exclude"]
    E[classify_clause_eval]
    AG["clause_group AND"]
    H[rule 命中 OR]
    RK["phase ↓ priority ↑ l3_code"]
  end
  O[dwd_component_class]
  T --- R
  P1 --> G
  P2 --> G
  R --> G
  G --> E
  R --> E
  E --> AG --> H --> RK --> O
```

### 4.1 Gate

**公式**：`gate_pass = gate_include − gate_exclude`（按 `data_source + id + l1_code`）。

| `field_code` | 角色 |
|---|---|
| `category_in` | include：`category ∈ match_values` |
| `category2_in` | include：`category2 ∈ match_values` |
| `gate_exclude_note_cn` | exclude：`category = match_value` 且 `note_cn` LIKE 任一模式 |
| `gate_exclude_null_note_cn` | exclude：`category = match_value` 且 `note_cn IS NULL` |

**`rule_id` 命名**

- gate：`gate_<l1>_<source>_…`（exclude 行亦须含 `_<source>_` 锚点，引擎据此解析 `l1_code`）
- classify：`<l1>_…_vN`（`data_converter` 存量 classify 可用 `dcv_` 前缀，gate 不可用缩写）

### 4.2 Classify 决选

1. 组内 **AND**（`clause_ord`）
2. 组间 **OR**（`clause_group_id`）
3. 命中多规则时：`phase DESC` → `rule_priority ASC` → `l3_code ASC`
4. 仅 gate 通过且命中 classify 的 SKU 写入 DWD（`INNER JOIN best`）

---

## 5. 阶段 3 清理

```sql
DROP TABLE IF EXISTS test_dim.dim_l3_classify_<l1>;
DROP TABLE IF EXISTS test_dim.dim_l3_classify_rule_<l1>;
DROP TABLE IF EXISTS test_dwd.dwd_component_class_<l1>;
DROP TABLE IF EXISTS test_dwd.dwd_component_class_merge_<l1>;
```

```bash
git rm -r sql_scripts/test/<l1>/
```

属性相关后缀表与 `test/<l1>/` 中属性脚本，在属性阶段合 prod 后再清理，见 [`../L1_STD_PIPELINE.md`](../L1_STD_PIPELINE.md)。

---

## 6. 脚本与 Skill 索引

| 路径 | 说明 |
|---|---|
| [`dwd_component_class.sql`](dwd_component_class.sql) | 共享分类引擎（唯一真源） |
| [`dim_l3_classify.sql`](dim_l3_classify.sql) / [`dim_l3_classify_rule.sql`](dim_l3_classify_rule.sql) | dim DDL |
| [`CONTRIB.md`](CONTRIB.md) | 阶段 2 逐步 SOP |
| `.cursor/skills/dim-l3-classify-merge/SKILL.md` | Cursor skill：分类合 prod |
| `sql_scripts/test/<l1>/audit/run_classify_merge.py` | Step 5/6 验收辅助 |
| `sql_scripts/test/data_converter/` | DigiKey ADC/DAC 参考试点 |

---

## 7. 参考数字（data_converter · DigiKey）

| 口径 | 行数 |
|---|---:|
| 四门 `category_in` include | 11,276 |
| combo `note_cn` exclude | 173 |
| **gate_pass / prod 分类** | **11,103** |

gate dim 规则（prod）：

- `gate_data_converter_digikey_v2` — `category_in`
- `gate_data_converter_digikey_exclude_combo_amp_v1` — `gate_exclude_note_cn`
- `gate_data_converter_digikey_exclude_combo_null_v1` — `gate_exclude_null_note_cn`
