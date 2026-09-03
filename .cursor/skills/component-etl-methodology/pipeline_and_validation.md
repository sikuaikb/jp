# 整套清洗全链路 + 机械校验规则（端到端梳理）

> 本文把「一个元器件 L1 从源端到上线」的完整链路一步一步串起来，**每一步的产物格式以电阻
> （`l1_code=resistor`）为黄金基准**，并把每一步「可机械判定的硬规则」落成 `tools/` 下的
> 可执行校验器。配合 [SKILL.md](SKILL.md) 的 7+1 阶段使用：阶段讲「怎么迭代」，本文讲
> 「每层长什么样 + 怎么自动卡住错误」。

---

## 0. 一张图看懂全链路

```
源层                分类层(dim)          分类结果           属性层(dim)              清洗窄表            业务宽表
─────              ───────────          ────────           ──────────              ────────            ────────
dwd_<src>_      →  dim_l3_classify   →  dwd_component   →  dim_attr_schema     →  dwd_component   →  dwd_l2_<l1>_<l2>
 component_param    dim_l3_classify_     _class             dim_attr_extract_rule   _attr_std          （电阻基准格式）
 (平铺KV/半结构)     rule                (data_source,id)   dim_unit_factor        (id,std_attr_code)
                    ↑通用引擎SQL                            ↑通用引擎SQL            ↑EAV窄表          ↑按L2透视

      ╲___ validate_classify_dim.py ___╱        ╲___ validate_attr_dim.py ___╱   ╲_ validate_l2_widetable.py _╱
                          └──────────── validate_pipeline.py（构建前·连库 test_dim + 校 DDL，fail-fast）──────────┘
      ╲________________ validate_dwd_data.py（构建后·连库校三张结果表的真实结构+数据）________________╱
```

四条贯穿原则（详见 SKILL §一/§五）：规则进 dim、引擎纯计算；窄表是真相、宽表是消费；
改规则先有探针证明；试错期用沙盒并列表。**本文新增第五条：可机械判定的硬规则必须配校验器，
进沙盒 `run_test.sh` 的 step 0 fail-fast。**

> **沙盒 dim 校验（连库）**：`validate_pipeline --dim-schema test_dim --dim-l1-suffix <l1>` 直接读后缀表，
> **禁止**在 `sql_scripts/test/<l1>/` 落 CSV/dump。历史 `--*-csv` 入参仅用于离线/合并前导出，不是沙盒常规路径。

---

## 1. 源层（source）

| 项 | 内容 |
|----|------|
| 表 | 每源一张 `dwd.dwd_<source>_component_param`（如 `dwd_icpdf_component_param` / `dwd_digikey_component_param`） |
| 形态 | 字段命名沿用源端原始命名，**不做标准化**；通用列 `category/category2/taginfo/category_info/note_cn/prajson/prajson2`（icpdf 半结构）或平铺 KV（digikey） |
| 这一步只做 | 阶段 1「源层摸底」：分层抽样人眼看杂乱度，**不写一行清洗规则** |
| 校验 | 暂无独立校验器（源表是上游产物）；用 probes.md §8.2 分层抽样模板做人工探查 |

---

## 2. 分类层 dim（taxonomy + 规则）

### 2.1 产物格式（以电阻为基准）

**分类树 `dim_l3_classify`**（`sql_scripts/foundation/dim_l3_classify_all.sql` **只对 L1 维度权威**：合法 L1 集合 + 每个 L1 的 l3_id 段；L2/L3 以各品类 Excel schema 为准，该表 L2/L3 仅供参考）：

| 列 | 含义 |
|----|------|
| `l3_id` | **六位纯数字 PK**，按 L1 分段（`10xxxx`=resistor、`19xxxx`=mcu_mpu_dsp …） |
| `l1_code/l1_cn/l2_code/l2_cn/l3_code/l3_cn` | 三级编码 + 中文名 |
| `schema_version` | 版本号 |

**分类规则 `dim_l3_classify_rule`**：`rule_id`（带 `<l1>_` 文字前缀）、`clause_group_id/clause_ord`
（组内 AND、组间 OR）、`data_source`（多源隔离）、`rule_kind`（gate/classify）、`l3_id`、`phase`、
`rule_priority`、`enabled`、`confidence_weight`、`field_code`（`category_in`/`note_cn_regexp`/`parjson_match_map`…）、
`match_value(s)`/`match_map`。

引擎：`dwd_component_class.sql`（PK `data_source,id`），gate → 子句求值 → 组 AND → 规则 OR →
phase/priority tie-break 决出每 id 唯一一行。

### 2.2 机械校验：`tools/validate_classify_dim.py`

| ID | 级别 | 规则 |
|----|------|------|
| C1 | FAIL | **只锁 L1**：`l1_code` 必须是合法 L1 + `l3_id` 前2位段必须归属该 L1（拦截撞段/未知 L1）；**不比对 L2/L3**（L2/L3 以 Excel 为准） |
| C2 | FAIL | 沙盒分类树单一 `l1_code`（拦截把 MCU/MPU/DSP 拆三个 L1） |
| C3 | FAIL | 每条 `enabled=1` 的 classify 规则 `l3_id` 必须在分类树 CSV 中 |
| C4 | FAIL | 每个 `rule_id` 带 L1 文字前缀（`<l1>_*` / `gate_<l1>_*`） |
| C5 | FAIL | `l3_id` 六位数字且 CSV 内唯一（PK 预检） |
| C6 | WARN | 路由到 L2=mcu 仅凭 category/prajson 文案（无 `note_cn_regexp`）→ 提示需商城核对 |
| C7 | FAIL | `l2_code` 不得以 `_base` 结尾（L2 名不要带 base，如 `mcu_base`） |
| C8 | FAIL | 同一 `(l1_code,l2_code)` 内 `l3_id` 连续无跳号（剔除 `*_unclassified`）；删节点后补齐重排 |
| C9 | FAIL | `l1_code` / `l2_code` / `l3_code` 必须 lower_snake_case（`^[a-z][a-z0-9_]*$`）；拦截 PascalCase/大写/连字符（Excel 英文名落库须转 snake_case） |

```bash
python3 tools/validate_classify_dim.py \
  --classify-csv <dim_l3_classify_*.csv> --rule-csv <dim_l3_classify_rule_*.csv> \
  --taxonomy sql_scripts/foundation/dim_l3_classify_all.sql --expect-l1 <l1>
```

---

## 3. 属性层 dim（schema + 抽取规则 + 单位）

### 3.1 三张字典格式（以电阻为基准）

| 表 | PK | 关键列 |
|----|----|-------|
| `dim_attr_schema` | `(schema_version,l1_code,scope_level,scope_code,std_attr_code)` | `scope_level`(l2/l3)、`scope_code`(=l2_code 或 l3_code)、`std_attr_code`(snake_case=宽表列名)、`unit_std`、`db_type`、`min/max_bound`、`display_ord` |
| `dim_attr_extract_rule` | `extract_rule_id`（**全局唯一**，带 L1 前缀） | `data_source`、`l1_code`、`apply_scope_*`、`std_attr_code`、`source_kind`、`source_expr`、`priority`、`enabled`、`value_map` |
| `dim_unit_factor` | `(target_unit,unit_raw)` | `factor`（`值_std = 值_raw × factor`） |

**约束（README §5/§6）**：同一 `(l1_code,l2_code)` 仅一个 `schema_version`（窄表取 `MAX`）；
`unit_std` 须能在 `dim_unit_factor.target_unit` 找到（否则走裸数值）。

### 3.2 机械校验：`tools/validate_attr_dim.py`

| ID | 级别 | 规则 |
|----|------|------|
| A1 | FAIL | `std_attr_code` lower_snake_case（宽表物理列名直接取此） |
| A2 | FAIL | schema PK 唯一 |
| A3 | FAIL | `scope_level ∈ {l2,l3}` |
| A4 | FAIL | `db_type ∈ {VARCHAR,DOUBLE,BOOLEAN,INT,BIGINT,DATETIME,JSON,TINYINT}` |
| A5 | FAIL | 同一 `(l1_code,l2_code)` 单一 `schema_version` |
| A6 | FAIL | `extract_rule_id` 全局唯一 |
| A7 | FAIL | 抽取规则引用的 `(schema_version,l1_code,std_attr_code)` 必须在 schema 存在（拦截 orphan 规则） |
| A8 | WARN | 非空 `unit_std` 建议在 `dim_unit_factor.target_unit` 有换算（找不到走裸数值 passthrough，故 WARN） |
| A9 | FAIL | `dim_unit_factor` PK 唯一、`factor` 数值 |
| A10 | FAIL | 规则 `enabled/priority` 为整数 |
| A11 | WARN | `DOUBLE` 属性无 `unit_std`（裸数值，确认无需换算） |
| A12 | FAIL | `scope_level=l2` 的 `scope_code`（=l2_code）不得以 `_base` 结尾 |
| A13 | WARN | 数值属性（DOUBLE/INT/BIGINT）缺 `max_bound`（上界）；按 L1 聚合输出。无上界则异常高值无法被引擎标 `out_of_range` |
| A14 | WARN | `value_domain` 文本声明了取值范围但 `min_bound/max_bound` 均空（界没落机器列，引擎读不到）；按 L1 聚合输出 |

```bash
python3 tools/validate_attr_dim.py \
  --schema-csv .../dim_attr_schema.csv --rule-csv .../dim_attr_extract_rule.csv \
  --unit-csv .../dim_unit_factor.csv [--l1 resistor]
```

> 已在 prod 实测：resistor/capacitor/inductor/diode/transistor 全部硬门控通过；**pmic 被 A7 抓出
> orphan 规则**（`pm23_l206_thr` 引用了 schema 不存在的 `threshold_v`）——证明该校验器能发现真实漂移。

---

## 4. 清洗窄表（EAV，真相层）

| 项 | 内容 |
|----|------|
| 表 | `dwd.dwd_component_attr_std`（多源共表），PK `(data_source,id,std_attr_code,l2_code)` |
| 装配 | `build_dwd_component_attr_std_<source>.sql`：按 `dim_attr_schema` 拉对应 L2 的 `std_attr_code`，按 `dim_attr_extract_rule`（priority 升序、rule_id 升序 tie-break）取 raw，再按 `dim_unit_factor` 换算 |
| 关键列 | `value_raw`、`value_std_varchar`/`value_std_double`、`dq_flag`（`out_of_range`/`parse_fail`/NULL） |
| 结构+数据校验 | `tools/validate_dwd_data.py`（连库）DA1 PK 唯一 · DA2 `(attr_schema_version,std_attr_code)` 无 orphan · DA3 `l2_code` 无 `_base` · DA4 `dq_flag` 取值越界（WARN）；迭代仍配 probes.md §8.1/§8.3 探针 |

> 分类结果表 `dwd_component_class`（PK `data_source,id`）同样由 `validate_dwd_data.py` 覆盖：
> DC1 PK 唯一 · DC2 `(l1,l2,l3_code,l3_id)` 对齐分类树 · DC3 `l2_code` 无 `_base` · DC4 未分类 NULL 行（WARN）· DC5 低置信度 `confidence<0.6` 占比（WARN）。

---

## 5. 业务宽表（L2，消费层）—— **最终产出，电阻基准**

### 5.1 基准格式 `dwd_l2_resistor_fixed_resistor`

所有 L2 宽表必须与它一致（widetable_conventions.md §六-B）：

```
标准头部(顺序固定)：data_source(VARCHAR32,NOTNULL) · id(BIGINT,NOTNULL) · mpn(VARCHAR) ·
                    brand(VARCHAR256) · brandid(BIGINT) · l1_code/l2_code(VARCHAR,NOTNULL) · l3_code(VARCHAR)
L2 专有属性       ：来自 dim_attr_schema(scope_level=l2,scope_code=l2_code) → 物理列(列名=std_attr_code)
标准尾部(顺序固定)：ext_attributes(JSON,L3专有属性) · semantic_tags(JSON) · dq_score(DOUBLE) ·
                    dq_flags(JSON) · source_id(BIGINT) · create_at/update_at(DATETIME)
表结构            ：ENGINE=OLAP PRIMARY KEY(data_source,id) DISTRIBUTED BY HASH(id) BUCKETS 16
表名              ：dwd_l2_{l1_code}_{l2_code}（test/prod 仅 schema 不同，禁止沙盒后缀）
```

透视规则（`build_dwd_l2_*.sql`）：`scope_level=l2` → 物理列；`scope_level=l3 & scope_code=l3_code`
→ `ext_attributes` JSON；`brand/brandid` 走 `v_std_brand_alias` 标准化。

### 5.2 机械校验：`tools/validate_l2_widetable.py`

| ID | 级别 | 规则 |
|----|------|------|
| W1 | FAIL | 标准头部 8 列齐全且顺序正确 |
| W2 | FAIL | 标准尾部 7 列齐全且类型正确 |
| W3 | FAIL | 头部列类型对齐基准（含 NOT NULL） |
| W4 | FAIL | `PRIMARY KEY(data_source,id)` 且 `DISTRIBUTED BY HASH(id)` |
| W5 | FAIL | 所有列名 lower_snake_case |
| W6 | FAIL | 无重复列名；**无 `,,` 双逗号语法错误** |
| W7 | FAIL | （需 `--schema-csv`）每个 L2 物理列是 schema 中 `(l1,scope_level=l2,scope_code=l2)` 的 `std_attr_code`，且 db_type 家族一致（拦截 BOOLEAN→VARCHAR 漂移） |
| W8 | FAIL | 不得出现废弃旧列 `component_id/l2_type/created_at/updated_at` |
| W9 | FAIL | （需 `--l1/--l2`）表名 `dwd_l2_{l1}_{l2}`（无沙盒后缀） |
| W10 | WARN | L2 列与头部 `mpn/brand/brandid` 重名 |
| W11 | FAIL | 表名不得以 `_base` 结尾（L2 名不要带 base，与分类层 `l2_code` 约束一致） |

```bash
# 单表深度对账
python3 tools/validate_l2_widetable.py --ddl .../dwd_l2_resistor_fixed_resistor.sql \
  --schema-csv .../dim_attr_schema.csv --l1 resistor --l2 fixed_resistor
# 批量结构体检（仅 W1-W6,W8）
python3 tools/validate_l2_widetable.py --ddl 'sql_scripts/2.attribute_standard/dwd_l2_*.sql'
```

> 已在 prod 实测：resistor/capacitor/inductor/diode/transistor 全部宽表通过；**mcu/mpu/dsp +
> 10 张 pmic 宽表被 W6 抓出 `,,` 双逗号语法错误**（DDL 根本无法执行）；legacy `dwd_l2_mcu_mcu` 还
> 被 W7 抓出物理列与 schema 不对齐——证明该校验器能发现真实存量债务。

### 5.3 线上结构 + 数据校验：`tools/validate_dwd_data.py`（连库）

`validate_l2_widetable.py` 校的是 **DDL 文件**；本工具校的是 **库里真实表结构 + 数据**：

| ID | 级别 | 规则 |
|----|------|------|
| DL1 | FAIL | 品牌门控：`brand_null=0` 且 `distinct_brand=distinct_brandid` |
| DL2 | FAIL | `l3_code` 无 `*_unclassified` 泄漏进宽表 |
| DL3 | FAIL | `l1_code/l2_code` 为常量且与表名 `dwd_l2_{l1}_{l2}` 一致（期望名按「去 _base」推导，不把脏后缀带进建议值） |
| DL4 | FAIL | 线上表结构含全部标准头部(8)+尾部(7)公共列 |
| DL5 | WARN | `l3_code` 非空但 `ext_attributes` 为空的比例（L3 参数缺失率） |
| DL6 | FAIL | 数据里的 `l1_code/l2_code` 不得以 `_base` 结尾（L2 名不要带 base） |
| DL7 | FAIL | 线上头部前 8 列顺序 = 标准头部，且 `data_source` NOT NULL（不得错位/可空） |
| DL8 | FAIL | 头部 8 列类型对齐基准（`data_source/mpn/brand/l*_code`=VARCHAR · `id/brandid`=BIGINT） |
| DL9 | FAIL | 安装方式列必须命名 `mounting_style`，不得用 `mounting_type` |
| DL10 | WARN | L2 物理列 100% 空（死列：schema 定义却从未填充，建议补抽取规则或删列） |
| DL11 | WARN | `dq_flags/dq_score/semantic_tags` 100% 空（EAV dq 标记未透传 / 语义标签未实现） |
| DL12 | WARN | 数值物理列越界残留：按 `dim_attr_schema` 的 `min_bound/max_bound`（同列多 scope 取最宽区间）复扫，宽表里仍存 `<min` 或 `>max` 的值；缺 dim 表/界列则降级跳过 |

> DL7-DL9 是「线上结构」硬门控（读 `information_schema`），与 DDL 静态校验 `validate_l2_widetable.py` 的 W1/W3 互补——后者校 DDL 文件，前者校真正建出来的表。

```bash
# 连接经 env 传入（MYSQL_HOST/PORT/USER/PASSWORD），与具体 loader 脚本解耦
python3 tools/validate_dwd_data.py --dwd-schema test_dwd --dim-schema test_dim --l1 resistor
```

> 已连库实测 `test_dwd`：自动发现全部 `dwd_l2_*` 并抓出真实数据债务——多张 L2 宽表品牌门控未过
> （`distinct_brand≠distinct_brandid`，brand 回退 raw 未标准化）、legacy 表名缺 L1 前缀
> （`dwd_l2_fixed_resistor` ↔ 应为 `dwd_l2_resistor_fixed_resistor`）、`l2_code=*_base` 数据
> （EAV 370 万行）。沙盒分类结果表 `dwd_component_class_mcu_mpu_dsp` 全绿。

---

## 6. 统一入口：`tools/validate_pipeline.py`

把三层串成一次 fail-fast 调用，**每层仅在其输入齐全时运行，缺输入自动 SKIP**，适合放进沙盒
`run_test.sh` step 0（`set -e`）：

```bash
python3 tools/validate_pipeline.py \
  --expect-l1 <l1> \
  --classify-csv ... --classify-rule-csv ... [--taxonomy ...] \
  --attr-schema-csv ... --attr-rule-csv ... --unit-csv ... \
  --widetable-ddl dwd_l2_a.sql dwd_l2_b.sql [--l2 <l2>]
```

新 L1 上线节奏：阶段 2 分类规则落到 `test_dim.dim_l3_classify(_rule)_<l1>` 后缀表、dump 成 CSV 后只喂
`--classify-*`（attr/widetable 自动 SKIP）；阶段 3 属性 dim 落后缀表后 dump 补 `--attr-*`；阶段 4 落宽表 DDL
后补 `--widetable-ddl`。**任意一层 FAIL → 退出码 1**。

**两段式校验模型**：
- **构建前**：`validate_pipeline.py`（连库校 `test_dim` 后缀表 + DDL 文件）——沙盒 `run_test.sh` step 0。
- **构建后·数据**：`validate_dwd_data.py`（连库，校真实表结构 + 数据）——产出落库后跑。

---

## 7. 完整校验规则总表（C/A/W/D 一览）

| 层 | 工具 | 连库 | FAIL 硬门控 | WARN 建议项 |
|----|------|:--:|-------------|-------------|
| 分类 dim | validate_classify_dim.py | 是 | C1 L1对齐(只锁l1_code+id段,不锁L2/L3) · C2 单一L1 · C3 规则l3_id存在 · C4 rule_id前缀 · C5 l3_id六位唯一 · C7 l2_code无_base · C8 l3_id连续无跳号 · C9 l1/l2/l3_code snake_case | C6 MCU文案预警 |
| 属性 dim | validate_attr_dim.py | 是 | A1 snake_case · A2 schemaPK · A3 scope枚举 · A4 db_type枚举 · A5 单一version · A6 rule_id全局唯一 · A7 orphan规则 · A9 unitPK/factor · A10 整数列 · A12 scope_code无_base · **A15 多源覆盖对称(未补未豁免即FAIL；豁免`--attr-source-waiver L1:SOURCE:CODE`)** | A8 unit缺换算 · A11 DOUBLE无单位 · A13 缺max_bound · A14 界未落机器列 · **A16 schema→rule反向(属性全源0规则)** |
| 单源 build 源隔离 | validate_build_source_isolation.py | 否 | **B1 join规则表缺`<alias>.data_source=`谓词 · B2 过滤成别的源**（防他源规则越界顶替凑数） | — |
| 宽表 DDL | validate_l2_widetable.py | 否 | W1 头部 · W2 尾部 · W3 头部类型 · W4 PK/分布 · W5 snake_case · W6 重复/双逗号 · W7 物理列对账 · W8 废弃列 · W9 表名 · W11 表名无_base | W10 头部列重名 |
| **结果表数据** | **validate_dwd_data.py** | **是** | DC1-3 分类结果 · DA1-3 EAV窄表 · DL1-4/DL6-9 L2宽表（品牌门控/未分类泄漏/表名一致/线上公共列+顺序+类型+封装列名/数据无_base） | DC4 未分类NULL · DC5 低置信度 · DA4 dq_flag越界 · DL5 L3缺失率 · DL10 死列 · DL11 dq/语义空列 · DL12 数值列越界残留 |
| 全链路（静态） | validate_pipeline.py | 否 | 任意子层 FAIL | 透传各层 WARN |

### 7.1 每张结果表「结构 × 数据」覆盖矩阵

| 结果表 | 结构校验 | 数据校验 |
|--------|---------|---------|
| `dwd_component_class`（分类结果） | dim 侧 `validate_classify_dim`（C1/C5）+ 数据侧 `validate_dwd_data` DC2 对齐分类树 | ✅ `validate_dwd_data` DC1-DC5 |
| `dwd_component_attr_std`（EAV 窄表） | `validate_dwd_data` DA2 std_attr_code 对账 schema | ✅ `validate_dwd_data` DA1-DA4 |
| `dwd_l2_*`（L2 宽表） | DDL 侧 `validate_l2_widetable`（W1-W11）+ 线上结构 `validate_dwd_data` DL4/DL7-DL9 | ✅ `validate_dwd_data` DL1-DL12 |
| `dwd_<source>_component_param`（源表） | 上游产物，不归本方法论校验 | 用 §8.2 抽样人工探查 |

> 品牌门控（`brand_null=0 且 distinct_brand=distinct_brandid`）已从「手工 SQL 探针」升级为
> `validate_dwd_data` DL1 机械门控；prod 写操作人工授权、Gateway 过滤显式处理 NULL 仍是独立门控。
