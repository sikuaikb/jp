---
name: component-etl-methodology
description: 元器件数据清洗方法论。面向「拿到一批源端杂乱的元器件参数，要打分类标签 + 抽出标准化参数 + 给下游业务消费」的工程。覆盖分类规则、属性 dim、宽表透视、双回路迭代、数据质量审计、人工授权门控。Use when starting a new L1 component category cleanup (capacitor, resistor, inductor, transistor, connector, PMIC, MCU, MPU, DSP, sensor, etc.), planning data cleansing roadmap, or asked about classification rules / attribute standardization / null-rate auditing / dim merging methodology for electronic components.
---

# 元器件数据清洗方法论

适用：任何一个新元器件 L1 大类从零到上线的完整数据清洗流程；不限品类。

---

## 一、核心思想

**一句话**：分类与清洗是两件互相依赖的事；都不要一次性写死，而是用**双回路迭代**逼近正确：

```
内部回路：探针 SQL → 量化问题 → 改 dim → 重跑 → 对比基线
外部回路：抽可疑样本 → 得捷 + 芯查查核对 → 反推规则错在哪 → 改 dim → 再核对
```

四条总原则：

1. **规则在 dim 字典里，引擎用通用 SQL**。规则反复改、字典数据热更，引擎逻辑很少动。
2. **窄表是真相层，宽表是消费层**。所有标准化数据先落"物料 × 属性"窄表，再透视成业务宽表。
3. **改规则前先有探针证明问题，改规则后先有探针 + 外部样本证明效果**。
4. **试错期用并列沙盒表，跑稳之后再合并回通用表**。

---

## 二、分层模型与前置假设

任何元器件清洗工程都可以拆成下面六层，各层之间只有数据流依赖，没有逻辑耦合：

| 层 | 形态 | 谁来定义 | 谁来消费 |
|----|------|---------|----------|
| **源层** | 原始抽取结果（散乱字段 + 半结构 JSON + 文本备注） | 上游采集 | 探查 / 分类 / 清洗 |
| **分类 dim** | L1/L2/L3 树 + 分类规则字典 | 业务专家 + 数据工程 | 分类引擎 |
| **分类结果层** | 物料 → L1/L2/L3 + 命中规则 + 置信度 | 分类引擎 | 清洗 / 业务下游 |
| **属性 dim** | 标准属性 schema + 抽取规则 + 单位换算 | 业务专家 + 数据工程 | 清洗引擎 |
| **清洗窄表** | 物料 × 标准属性 → 标准值 + 单位 + 数值 + 命中路径 | 清洗引擎 | 宽表 / 业务下游 |
| **业务宽表** | 一行一物料、按 L2 拆表 | 透视脚本 | 应用 / 前端 |

所有「人为定义」收敛在两套 dim 里，引擎层保持纯计算。**加新品类只需要往 dim 里加规则，引擎不动**。

---

## 二-A、源适配层与多源接入（方法论的通用前提）

> **核心断言**：本方法论 **与具体数据源解耦**。任何新源（icpdf、digikey、mouser、ecloud、自建爬虫、合作伙伴推送…）接入后，**只需在 dim 字典里补充该源的规则行 + 落一张源参数表**，分类引擎、EAV 引擎、宽表 build、探针 SQL 全部**不动**。

### A. 源适配层的三件事

| 件 | 形态 | 单源做法 | 多源做法（项目当前约定） |
|---|---|---|---|
| **A1. 源参数表** | 该源原始字段落 DWD 的一张表 | `dwd_<source>_component_param` | 每个源各一张：`dwd_icpdf_component_param`、`dwd_digikey_component_param`、`dwd_<新源>_component_param` …… |
| **A2. 分类规则路由** | 规则按源命中字段 | rule 行直接写表名 | `dim.dim_l3_classify_rule` / `dim.dim_attr_extract_rule` 用 `data_source` 列区分该规则来自哪个源；`source_kind` 标识该源的字段访问方式 |
| **A3. 多源合并表** | 分类结果 / EAV 窄表 | 单表单源 | **不**按源拆表，统一表 `dwd.dwd_component_class` / `dwd.dwd_component_attr_std`，每行带 `data_source` 列；下游通过 `WHERE data_source = '<src>'` 隔离查询 |

### B. 各源的字段访问方式（source_kind）按源端形态选择

不同源的"源端结构"决定 `source_kind` 怎么写：

| 源端结构示例 | 对应 source_kind 命名约定 |
|---|---|
| 半结构 JSON（顶层键-值，如 icpdf `prajson2`） | `prajson2_key_eq` / `prajson2_key_contains` |
| 数组型 JSON（每元素含 `cn` / `sqlname`，如 icpdf `prajson`） | `prajson_cn_eq` / `prajson_sqlname_eq` |
| 分类字段（icpdf `category` / `category2`） | `param_category_eq` / `param_category2_eq` |
| 数组标签（icpdf `taginfo`） | `param_taginfo_eq` |
| **平铺 KV**（digikey 的参数表，每行 (id, key, value)） | `digikey_param_kv_eq` |
| **物理列**（任何源的标量列） | `direct_column` |
| 文本提取（描述/备注里的正则） | `<source>_text_regex` |

**命名规则**：`<源前缀>_<访问方式>_<匹配语义>`。新源接入时**只追加新的 `source_kind` 取值** + 在窄表装配 SQL 中加一段 CASE 分支即可，dim_attr_schema 不动、宽表 DDL 不动。

### C. 接入一个新源的最小步骤

```
1) 落源参数表：dwd.dwd_<source>_component_param
   - 至少包含 (id, brandshort/brandid, 该源的原始字段)
   - 字段命名沿用源端原始命名，不做标准化
2) 规则落到 test_dim 后缀表：
   - 写入 test_dim.dim_l3_classify_rule_<l1> / test_dim.dim_attr_extract_rule_<l1>
   - data_source='<source>'，rule_id/extract_rule_id 带源前缀
   - source_kind 选用 §B 表中既有取值，或定义新取值
3) 如有新 source_kind：
   - 在 build_dwd_component_class.sql 加一段 CASE 分支
   - 在 build_dwd_component_attr_std_<source>.sql 加一段 CASE 分支
4) test_dim 后缀表跑 classify/EAV/L2 → 5+5.5 双回路 → 6 人工授权 → 7 发布
   ↑ 所有步骤都用现有引擎 SQL，无需为新源新建宽表，新源数据直接 UNION 进既有 L2 宽表
```

> **合并范式**：`test_dim.*_<l1>` 后缀表是合并数据来源，prod `dim` 是替换目标。
> 合并 = 用户授权后「备份 prod 旧 L1 → 删 prod 旧 L1 → 从 test_dim 后缀表 insert」。施工细则见 §七 两个 merge skill。

### D. 占位符约定（贯穿全文档）

后续 phases 文档中遇到以下占位符，按下表替换为本次接入的源端实际值：

| 占位符 | 含义 | icpdf 示例 | digikey 示例 |
|---|---|---|---|
| `<SOURCE>` | 数据源标识，与 `dim_*.data_source` / `dwd_component_*.data_source` 列值一致 | `icpdf` | `digikey` |
| `<SRC_PARAM_TABLE>` | 该源的源参数表（schema.table） | `dwd.dwd_icpdf_component_param` | `dwd.dwd_digikey_component_param` |
| `<SRC_SEMI_JSON>` | 该源的"半结构 JSON 主字段"（如有） | `prajson2` | （无；digikey 是平铺 KV） |
| `<SRC_KEY_EXPR>` | 取该源某个键的 SQL 表达式 | `get_json_string(prajson2, '$.<key>')` | `<在 (id, key, value) 平铺表上 WHERE key='<key>' 取 value>` |
| `<SRC_KIND_KEY_EQ>` | 该源的"键名精确匹配"`source_kind` 值 | `prajson2_key_eq` | `digikey_param_kv_eq` |

**当一个 phase 文档中给出 icpdf 的具体 SQL 时，digikey/其他源等价做法 = 把上表的占位符替换一遍即可**，方法论本身不变。

---

## 三、7+1 阶段导航表

> 按阶段编号一一对应一份文档。点击编号进入阶段细节。

| 阶段 | 一句话目标 | 占工期 | 文档 |
|------|----------|--------|------|
| **1** | 源层摸底：看清源数据，**不写一行清洗规则** | 10% | [phases/1_source_probe.md](phases/1_source_probe.md) |
| **2** | 分类规则草案：最小规则集 + **第一次商城核对** | 15% | [phases/2_classify_draft.md](phases/2_classify_draft.md) |
| **3** | 属性 dim：三张字典 + DDL/dim/规格三方一致性 | 18% | [phases/3_attr_dim.md](phases/3_attr_dim.md) |
| **4** | 宽表透视：按 L2 拆 + 品牌门控 + EAV 接线验证 | 5% | [phases/4_wide_table.md](phases/4_wide_table.md) |
| **5** | 双回路试错迭代：内部探针 + 外部商城 | 35% | [phases/5_iterate.md](phases/5_iterate.md) |
| **5.5** | **数据质量审计**：空值率 + gap + 单位 + P0 补缺 | 10% | [phases/5_5_qa_audit.md](phases/5_5_qa_audit.md) |
| **6** | **人工授权门控** + 合并发布检查清单 | 7% | [phases/6_release_gate.md](phases/6_release_gate.md) |
| **7** | 五维验收 + 发布留痕 | （含 6） | [phases/7_acceptance.md](phases/7_acceptance.md) |

**工期错配警告**：试错迭代（阶段 5）经常被低估到 5-10%，实际经常 50%+。把 5+5.5 显式预留 45% 是更现实的姿态。

---

## 四、横向参考文档（跨阶段共用）

| 文档 | 内容 |
|------|------|
| [pipeline_and_validation.md](pipeline_and_validation.md) | **整套清洗端到端梳理**：六层产物格式（以电阻为基准）+ 每层机械校验规则（C/A/W 总表）+ 统一校验入口 |
| [widetable_conventions.md](widetable_conventions.md) | **L2 宽表建表权威规范**：§六-A2 封装参数（`package_case`/`mounting_style`）+ §六-B Schema 命名 / 脚本目录 / 公共列（头 8 + 尾 7）/ `ext_attributes` 存储约定 |
| [probes.md](probes.md) | **三个通用探针 SQL 模板**：§8.1 空值率扫描 / §8.2 分层抽样 / §8.3 源-schema gap，占位符替换后直接执行 |
| [decision_guides.md](decision_guides.md) | **分类核对三段式**、**空值核对四段式**判定流程 + 两份外部对照 TSV 模板 |
| [anti_patterns.md](anti_patterns.md) | 通用反模式表 + 外部验证反模式 + 配套工程基础设施清单 |
| [lessons_learned.md](lessons_learned.md) | **已经踩过的坑**：场景 / 错误 / 后果 / 纠正与防御。Agent 收到用户纠正时**必须**追加新条目（见 §零） |

---

## 零、Agent 自我修订规则（被用户纠正时强制执行）

> **触发条件**：用户在对话中指出 Agent 做错了什么、判断错了什么、违反了哪条不成文约定，或要求"以后不要再这样"。

收到纠正后，**必须**按以下顺序完成（不许跳步）：

1. **承认错误**：用一句话复述用户纠正的核心点，确认理解一致。
2. **写入 `lessons_learned.md`**：在顶部追加一条 `LL-YYYYMMDD-NN` 条目，**必带**：日期 / 场景 / 错误行为 / 后果 / 根因 / 纠正与防御。
3. **升级硬约束**：若纠正产生**新的不可妥协规则**，同步更新：
   - 本文件第六节"硬门控"列表（追加一条）
   - `anti_patterns.md` 通用反模式表（追加一行）
4. **修整流程脚本 / 现有产物**：若错误已经污染了 sandbox / 脚本 / 代码，给出修复方案；用户确认后再执行。
5. **报告变更**：在回复结尾用清单列出本次变更的文件，便于用户审阅。

**禁止行为**：

- ❌ 嘴上答应"以后注意"，但不更新 skills
- ❌ 只改一处（如只改脚本）不补 lessons_learned
- ❌ 在 lessons_learned 里只写"错了"，不写根因与防御
- ❌ 把同类错误反复犯而不升级硬门控

---

## 五、九项可复用判定原则

遇到拿不准的设计选择，套这几条原则通常能给出答案：

1. **规则字典 vs 引擎代码**：能放 dim 字典就不写进引擎。
2. **多条窄规则 vs 一条宽规则**：永远选多条窄规则，每条只做一件事。
3. **NULL vs 默认值**：源端没有就是 NULL，不要拍脑袋填默认值。
4. **修字典 vs 修引擎**：能改字典就不要碰引擎，引擎一动就是全表回归。
5. **新建并列表 vs 改通用表**：试错期一律新建沙盒，合并是最后一步。
6. **加规则 vs 改规则**：能加新规则解决就不要改老规则，保留可追溯性。
7. **内部统计 vs 外部商城**：内部证明"自洽"，外部（得捷 + 芯查查）证明"正确"，缺一不可；**分类和参数都要去商城核对**。
8. **L2 和 L3 覆盖率必须分开统计**：L3 属性分母是对应 L3 子类行数，混用全量会假警报。
9. **rule_id 用 `<l1>_` 文字前缀，l3_id 用六位数字段**：`extract_rule_id` 必须带 L1 文字前缀（如 `rs1509_*`、`cap_*`、`i1509_*`）；`l3_id` 用六位纯数字按 L1 分段分配（如 `05xxxx`=diode、`09xxxx`=transistor、`10xxxx`=resistor），两种机制各防各层的 PK 冲突，开发期就要规划好数字段，合并阶段无法重命名。

---

## 六、七条硬门控（不要妥协）

- **品牌标准化是宽表发布门控**：每张 L2 宽表必须 `brand_null = 0` 且 `COUNT(DISTINCT brand) = COUNT(DISTINCT brandid)`，两条都不过不允许发布。已升级为机械门控 `validate_dwd_data.py` DL1（连库）。
- **品牌字典「一家公司一个 id」是字典级硬门控**：`dim_std_brand` 内同一家公司只能一行——判重看**归一化键**（大写 + 去 INC/LTD/CORP/SEMICONDUCTOR/TECHNOLOGY/ELECTRONICS… 公司后缀 + 去非字母数字），范围是**整张表（jp_brand 段 + manual_extra 段，跨源）**，不是只查 jp_brand、也不是 `name` 字面相等。注意宽表门控 DL1（`distinct brand = distinct brandid`）对「同一公司两个 id、两个 brand 文本都非空」是**盲的**（2=2 仍相等），故必须另设字典级查重。机械门控：`validate_brand_dim_dup.py`（归一化聚合，同 key 落 >1 个 `brand_id_std` 即 FAIL；伪重复=缩写撞车的不同公司用白名单/`--waiver`/env `BRAND_DUP_WAIVER` 登记留痕），已接进 `sync_dim_std_brand.sh` 末尾 fail-fast。已发现重复用 `sql_scripts/brand_merge/`（merge_map + soft-delete + dwd_l2 brandid 回填）统一收口。**踩坑详情**：[lessons_learned.md#LL-20260625-01](lessons_learned.md)。
- **品牌字典 `dim_std_brand` / `v_std_brand_alias` 是只读基础设施**：所有 L1 试点 / 沙盒 / `run_test.sh` / `e2e.sh` 只能 `SELECT`，**禁止**调用 `sync_dim_std_brand.sh`、**禁止** DROP/CREATE/INSERT。字典维护由有 ods 读权限的人离线进行，见 `CONTRIB_BRAND.md`。Agent 遇到字典为空或缺别名时，**报告用户**而不是自动同步。**踩坑详情**：[lessons_learned.md#LL-20260528-01](lessons_learned.md)。
- **prod 写操作需人工授权**：测试通过 ≠ 自动发 prod；Agent / SOP 不得跨越 test → prod 边界；`ALLOW_PROD=1` 不应由 Agent 自行设置。详见 [phases/6_release_gate.md](phases/6_release_gate.md)。
- **DigiKey 源端文案不得单独判定 MCU L3**：`category` + `prajson.类型/架构` 中的 `MCU`、`TxRx + MCU`、`基于 MCU` 等是商城结构描述，不等于业务 taxonomy 的 MCU/无线MCU/计量MCU；首批 classify 须先过商城核对样本。**踩坑详情**：[lessons_learned.md#LL-20260528-03](lessons_learned.md)。
- **`dim_l3_classify_all.sql` 只对 L1 维度权威**：该表只用于锁定「合法 L1 集合 + 每个 L1 的 `l3_id` 段（前2位，一对一，如 `pmic=01`/`capacitor=10`/`mcu_mpu_dsp=19`）」；**L2/L3 一律以各品类的 Excel schema 为准**（如 `tmp/mcu_mpu_dsp_schema_v5.20.xlsx`），该表里的 L2/L3 仅供参考、可能过时，**不得当作 L2/L3 权威**。协作者不一定持有 Excel，故机械门控**只校验「l1_code 是否为合法 L1 + l3_id 段归属是否正确」，绝不比对 L2/L3**。机械校验：`validate_classify_dim.py` C1。**踩坑详情**：[lessons_learned.md#LL-20260529-16](lessons_learned.md)。
- **MCU/MPU/DSP 是单一 L1**：`l1_code=mcu_mpu_dsp` 且 `l3_id` 用 `19xxxx` 段，以 `foundation/dim_l3_classify_all.sql` 的 L1 维度为准；`mcu`/`mpu_soc`/`dsp` 三个 L2 及其下 L3 以 `mcu_mpu_dsp` Excel schema 为准。禁止把三者拆成三个 L1 或误用 icpdf 历史的 `20xxxx/21xxxx/22xxxx` 段。**踩坑详情**：[lessons_learned.md#LL-20260528-04](lessons_learned.md)。
- **DSP 的 L3 只有 `general_programmable_dsp` + `audio_dsp` 两个节点**（以 Excel `DSP_Base` sheet 为准）：禁止出现 `fixed_point_dsp`/`floating_point_dsp`/`multicore_dsp`——定点/浮点/核心数是**属性维度**（`arithmetic_type`/`has_floating_point`/`dsp_core_count`），不是分类维度，一律走属性字段。**踩坑详情**：[lessons_learned.md#LL-20260529-15](lessons_learned.md)。
- **L2 编码 `l2_code` 不得带 `_base` 后缀**：L2 是业务 taxonomy 节点（如 `mcu`/`mpu_soc`/`dsp`），不是实现层"基类"，禁止 `mcu_base`/`dsp_base` 这类占位命名；分类层 `l2_code`、属性层 `scope_code(l2)`、宽表 `l2_code` 三处必须一致且无 base。机械校验：`validate_classify_dim.py` C7 / `validate_attr_dim.py` A12。**踩坑详情**：[lessons_learned.md#LL-20260529-07](lessons_learned.md)。
- **L2/L3 的 l3_id 体系必须自洽且连续**：编号结构 `<L1 2位><L2 2位><L3 2位>`，同一 (l1_code, l2_code) 内 L3 序号从 `01` 连续递增、无跳号（剔除 `*_unclassified`）；删/合并 L3 节点后**必须补齐重排**，不允许 `190301+190304` 这种空洞。机械校验：`validate_classify_dim.py` C8。**踩坑详情**：[lessons_learned.md#LL-20260529-17](lessons_learned.md)。
- **分类 L3 必须被属性 schema 的 L3 覆盖**：每个 L1，`dwd_component_class.l3_code`（剔除 `%_unclassified`）的 DISTINCT 集合，必须全部出现在 `dim_attr_schema` 的 `scope_level='l3'` `scope_code` 里；未覆盖的 L3 注定 `ext_attributes` 恒空，判 ERROR。build SQL 里 `parse_json('{}')` 写死 ext_attributes = "阶段 3 未完成"标记，禁止进入阶段 6。机械门控接 `validate_dwd_data.py`（连库 C×A 交叉）。**踩坑详情**：[lessons_learned.md#LL-20260529-12](lessons_learned.md)。
- **接入新源/新品类前必须先全项目盘点既有通路，禁止凭沙盒目录缺文件就新建脚本**：先 glob `sql_scripts/**/*<品类>*` 与 `**/build_dwd_*<源>*`，区分**正式层**（`1.classify/`、`2.attribute_standard/`，写 `dwd`/`dim`）与**沙盒试点**（`test/<l1>/`，写 `test_dwd`/`test_dim`）；判断「某源是否已接入」以正式层 `build_dwd_l2_*` 的 `src_param`/源 UNION 为权威依据，不是沙盒是否有同名文件。**用户连续 ≥2 次纠正同一认知 → 立即停手，全量重盘 + AskQuestion 对齐，禁止再凭猜测改文件**。**踩坑详情**：[lessons_learned.md#LL-20260529-14](lessons_learned.md)。
- **skills/ 下的校验器必须零外部文件依赖、可独立运行**：`tools/*.py` 只允许 import 标准库 + 已声明的 pip 包（如 pymysql），**禁止** `sys.path` 外挂 skills 目录外路径、**禁止**读取 skills 目录外的文件；连接串 / schema / 表名 / L1 等一律经 CLI 参数或 env 传入，缺参数/缺表/缺字典优雅降级 WARN。门控校验器与具体沙盒 `run_test.sh` 解耦，**方法论侧默认不接**，是否接由该沙盒自行决定。**踩坑详情**：[lessons_learned.md#LL-20260529-13](lessons_learned.md)。
- **可机械判定的硬门控必须配可执行校验器**：凡能用代码判定的不变式（L1 对齐（只锁 l1_code+id段，不锁 L2/L3）、单一 L1、l3_id 唯一不撞段、l3_id 段内连续无跳号、l1/l2/l3_code 必须 lower_snake_case、rule_id 前缀、schema PK、orphan 规则、宽表对齐电阻基准、`,,` 语法错误等），**不得只写 prompt 条款**，必须同时提供 `tools/` 下的校验脚本并接进沙盒 `run_test.sh`（`set -e` fail-fast）。**三层静态校验器 + 统一入口 + 数据校验器**：分类 [`validate_classify_dim.py`](tools/validate_classify_dim.py)、属性 [`validate_attr_dim.py`](tools/validate_attr_dim.py)、宽表 DDL [`validate_l2_widetable.py`](tools/validate_l2_widetable.py)、全链路静态入口 [`validate_pipeline.py`](tools/validate_pipeline.py)、**结果表数据+线上结构（连库）** [`validate_dwd_data.py`](tools/validate_dwd_data.py)；完整规则总表与「结构×数据」覆盖矩阵见 [pipeline_and_validation.md](pipeline_and_validation.md)。**校验器提示规约**（受众是无上下文会话）：每条提示 = 规则号 + 对象（表/文件/列/行）+ 错因 + 期望值/修复方向；期望值不得从脏数据反推；缺列/缺字典/缺参数一律降级为 WARN 跳过，禁止裸 SQL 报错或栈回溯。**踩坑详情**：[lessons_learned.md#LL-20260528-05](lessons_learned.md)、[#LL-20260529-08](lessons_learned.md)、[#LL-20260529-09](lessons_learned.md)。
- **Gateway 过滤必须显式处理 NULL**：用 `NOT (col = 'x' AND key_col IN (...))` 过滤非目标品类时，若 `key_col` 可能为 NULL，必须加 `AND key_col IS NOT NULL`，否则 `NOT NULL = NULL`，在 WHERE 里等价于 FALSE，会把所有 key_col IS NULL 的行意外过滤掉。正确写法：
  ```sql
  AND NOT (
      category2 = '电源管理电路'
      AND category IS NOT NULL            -- 必须显式排除 NULL 的误伤
      AND category IN ('放大器、缓冲器', '接口芯片', ...)
  )
  ```
- **`schema_version` 必须对齐品类 Excel schema 版本，禁止当规则迭代号**：分类 `dim_l3_classify` + `dim_l3_classify_rule` 的 `schema_version` 统一为 Excel 文件名版本（如 `mcu_mpu_dsp_schema_v5.20.xlsx` → `v1.5.20`，文件名省略前缀 `1.`）；属性 `dim_attr_schema` 用 `{l1}_schema_v1.5.20`（与电阻 `resistor_schema_v1.5.20` 同模式）。同一 L1 不得混用 v1.0.00/v1.1.00 等多版本；规则与分类树 version 不一致会导致 classify 引擎 JOIN 零产出。机械校验：`validate_classify_dim.py` C10。**踩坑详情**：[lessons_learned.md#LL-20260601-01](lessons_learned.md)。
- **新 L1 / 新源合并 = 按 L1 从 test_dim 后缀表替换 prod dim**：规则源是 `test_dim.dim_l3_classify(_rule)_<l1>` / `test_dim.dim_attr_schema_<l1>` / `dim_attr_extract_rule_<l1>` 后缀表；流程「PK 预检（**只锁撞其他 L1**，允许替换同 L1）→ 质量检查 → 只读列出删除/写入范围 → 用户授权后 `dim.bak_*_<l1>_<merge_tag>` 备份 → 删 prod 旧 L1 → 从 test_dim insert」。规则 dim 只接受这条通道；`dim_unit_factor` 只追加缺失单位、不按 L1 删；回滚从 `bak_*_<merge_tag>` 恢复，不全量 DROP 主表。classify 重建用主干 `dwd_component_class.sql`，**禁止** `run_classify.sh prod`（它会重建 dim 覆盖刚写入的）。共享引擎脚本（`dwd_component_class.sql` / `build_dwd_component_attr_std_*.sql`）以主干为准；分支里 `build_dwd_<source>_*_<l1>.sql` 只作阶段 1 验证参考。施工细则见 §七 两个 merge skill。**踩坑详情**：[lessons_learned.md#LL-20260603-01](lessons_learned.md)。
- **L2 脚本必须收纳进 `<NN>_<l1>_ready/` 子目录，禁止平铺/双目录并存**：正式层 `2.attribute_standard/` 下 L1 的 `dwd_l2_*.sql` + `build_dwd_l2_*.sql` 放进 `<NN>_<l1>_ready/`（`NN`=该 L1 的 l3_id 前两位段，`_ready`=已梳理状态）；占位目录跑通后 `git mv` 改名加 `_ready`，**禁止** `<NN>_<l1>/` 与 `<NN>_<l1>_ready/` 同时存在；入仓须同步更新 `run_attr_std.sh` 的 `l1_dir()` / `l2_files_for_l1()`。详见 [widetable_conventions.md §六-B](widetable_conventions.md)。**踩坑详情**：[lessons_learned.md#LL-20260603-01](lessons_learned.md)。
- **调整 skills 必须写当前态权威文档，禁止打补丁式 / changelog 式措辞**：skill 正文（SKILL.md / phases / pipeline / anti_patterns）只陈述「当前规则是什么、禁止做什么」，**禁止**出现 `自 X 起` / `已废弃` / `翻转为` / `替代旧 X` / `范式变更` / `不再是…` 这类描述「从前怎样、现在改成怎样」的迁移叙事；版本迁移历史只写进 `lessons_learned.md`。**踩坑详情**：[lessons_learned.md#LL-20260603-02](lessons_learned.md)。
- **禁止改通用引擎与同源沙盒 build SQL**：`sql_scripts/2.attribute_standard/` 下 classify/EAV/L2 主干，以及从主干复制到 `sql_scripts/test/<l1>/` 的沙盒 build 脚本（含 `build_dwd_*_component_attr_std_*`），试错期**不得**为 P0 补缺而改；规则与源隔离只落在 `test_dim` 的 `dim_attr_extract_rule_<l1>`（`data_source` / `source_kind` / 正则 / `value_map` / `priority`）。沙盒只跑既有脚本；全源 EAV 用正式层 `build_dwd_component_attr_std_{icpdf,digikey}.sql` + 合并后的 `dim`。**踩坑详情**：[lessons_learned.md#LL-20260603-03](lessons_learned.md)。
- **沙盒产出在库表，禁止 test 目录落 CSV；试错期改规则直接改 test_dim 表**：试错期改规则**直接对 `test_dim.dim_*_<l1>` 表 `UPDATE`/`INSERT`/`DELETE`**；重跑 `build_*.sql` 写入 `test_dwd`（分类/EAV/L2 宽表）；**禁止**在 `sql_scripts/test/<l1>/` 下写 `dump/` 或任何校验用 CSV；`validate_pipeline` 用 **`--dim-schema test_dim --dim-l1-suffix <l1>` 连库**；每沙盒须有 **`run_test.sh`**（静态校验→刷 test_dwd→`validate_dwd_data`）。合并 prod 只走 test_dim→dim（见上条）。**踩坑详情**：[lessons_learned.md#LL-20260603-04](lessons_learned.md)、[#LL-20260604-01](lessons_learned.md)。
- **多源接入必须按 `data_source` 校规则覆盖对称性，单源漏建整层规则不得静默通过**：一个 L1 接入 ≥2 个源（icpdf/digikey/…）时，「某源对某属性、或对整层 L3 属性 0 规则」是漏建高发区，**禁止**仅凭「另一源已覆盖」或「沙盒影子 EAV 有值」就判定该源已覆盖——L1 专用沙盒 build 可能漏源隔离、被他源规则越界顶替（见 LL-20260603-03），阶段 1 影子 EAV 行数**一律以主干源隔离 `build_dwd_component_attr_std_{icpdf,digikey}.sql` 为准**。机械门控（三道，缺一不可）：
  1. `validate_attr_dim.py` **A15 [FAIL]**：按 `data_source` 聚合，某属性被该 L1 部分源覆盖、另一些源 0 规则 → **FAIL 阻断**。每个非对称属性必须二选一：**补该源规则** 或 用豁免 `--attr-source-waiver L1:SOURCE:STD_ATTR_CODE`（env `ATTR_SOURCE_WAIVER` 等价）显式登记「该源确无此属性」——机器无法区分「漏建 bug」与「该源真无此属性」，故豁免须人工登记、留痕；未补又未豁免一律 FAIL。
  2. `validate_attr_dim.py` **A16 [WARN]**：schema→rule 反向覆盖，某 `std_attr_code` schema 有定义但**所有源**都 0 规则（A15 盲区：全源皆缺无不对称可言）→ 提醒确认是否漏建。
  3. `validate_build_source_isolation.py` **B1/B2 [FAIL]**：单源 build 脚本 join 规则表（`dim_attr_extract_rule*` / `dim_l3_classify_rule*`）必须带 `<alias>.data_source = '<source>'`；缺源隔离谓词（B1）或过滤成别的源（B2）→ FAIL。专治「掩盖器」：漏源隔离会让他源规则越界把缺口凑满。
  
  每个非对称属性补/豁免后方可进入阶段 2 合并，并按源跑 [probes.md §8.3](probes.md) gap 探针互补核对。**踩坑详情**：[lessons_learned.md#LL-20260603-05](lessons_learned.md)、[#LL-20260604-03](lessons_learned.md)。

---

## 六-A2 / 六-B、宽表工程约定（封装参数 + 建表规范）

> 已独立成册，避免本索引过长。完整规范见 **[widetable_conventions.md](widetable_conventions.md)**：
> - **§六-A2 封装参数标准化**：`package_case` vs `mounting_style` 概念区分、推导优先级、列声明规范。
> - **§六-B 建表规范**：Schema 命名 / L2 脚本目录 `<NN>_<l1>_ready/` / L2 表命名 / 公共列（头 8 + 尾 7）/ `ext_attributes` 存储约定。
>
> 机械校验：`tools/validate_l2_widetable.py`（对齐电阻基准 `dwd_l2_resistor_fixed_resistor`）。

---

## 七、配套 SKILL（施工细则）

| SKILL / 工具 | 用途 |
|-------|------|
| `.cursor/skills/dim-l3-classify-merge/SKILL.md` | 分类合并施工细则（PK 预检"只锁其他 L1" / 质量检查 / 只读列出删除范围 / **按 L1 从 test_dim 后缀表替换 prod dim** / 主干 `dwd_component_class.sql` 重建，**禁 `run_classify.sh prod`**） |
| `.cursor/skills/dim-attr-std-merge/SKILL.md` | 属性标准化合并施工细则（同上替换范式 + L2 脚本入 `<NN>_<l1>_ready/` 目录 + 更新 `run_attr_std.sh` 映射；`dim_unit_factor` 只追加缺失单位） |
| `tools/validate_pipeline.py` | **全链路统一校验入口**：串起分类/属性/宽表三层，缺输入自动 SKIP，任意层 FAIL 退 1；沙盒 `run_test.sh` 用 **`--dim-schema test_dim --dim-l1-suffix <l1>` 连库**（非 CSV） |
| `tools/extract_attr_enum_draft.py` | **Excel→枚举草案抽取器**：从原始 Excel schema 的「值域约束」列抽枚举/布尔词表草案 + 自动标注冲突（同属性多套词表），供人工裁决后落 `test_dim.tmp_attr_enum`（只读、禁同步 prod）。步骤见 [phases/3_attr_dim.md §3.0](phases/3_attr_dim.md) |
| `tools/validate_classify_dim.py` | **分类规则/类目校验器**（读 `test_dim` 连库）：L1 对齐（只锁 l1_code 合法 + l3_id 段归属，**不锁 L2/L3**，L2/L3 以 Excel 为准）/ 单一 L1 / l3_id 唯一不撞段 / L2 内 l3_id 连续无跳号(C8) / l1/l2/l3_code 必须 lower_snake_case(C9) / **schema_version 对齐 Excel 且规则与分类树一致(C10)** / rule_id 前缀 / MCU 文案预警 |
| `tools/validate_attr_dim.py` | **属性 schema/规则校验器**（读 `test_dim` 连库）：snake_case / schema PK / 单一 schema_version / extract_rule 全局唯一 / orphan 规则 / unit 换算 / 数值属性区间覆盖审计（A13 缺 max_bound、A14 界写在 value_domain 却未落 min/max_bound，按 L1 聚合 WARN）/ **A15 [FAIL] 多源覆盖对称性（≥2 源时某源相对同 L1 其他源缺规则的属性 → FAIL；用 `--attr-source-waiver L1:SOURCE:CODE` / env `ATTR_SOURCE_WAIVER` 显式豁免「该源确无此属性」）** / **A16 [WARN] schema→rule 反向覆盖（属性全源皆 0 规则）** |
| `tools/validate_build_source_isolation.py` | **单源 build SQL 源隔离 linter**（静态读文件）：B1/B2 [FAIL] —— 单源 build（`build_dwd_<source>_*`）join 规则表（`dim_attr_extract_rule*`/`dim_l3_classify_rule*`）必须带 `<alias>.data_source='<source>'`，缺谓词或过滤成别的源即 FAIL；专防「漏源隔离→他源规则越界凑数」掩盖缺规则。`--build-sql <file>`（可重复）+ `--expect-source <src>` |
| `tools/validate_l2_widetable.py` | **L2 宽表 DDL 校验器**：对齐电阻基准（头/尾公共列 + 类型 + PK + 物理列对账 schema + 双逗号/废弃列拦截 + 表名无 `_base`） |
| `tools/validate_dwd_data.py` | **结果表数据 + 线上结构校验器（连库）**：分类结果 / EAV 窄表 / L2 宽表 三张产出表的 PK 唯一、taxonomy 对齐、orphan、品牌门控、未分类泄漏、`_base`、线上公共列**及顺序/类型/封装列名(DL7-9)**、低置信度(DC5)、死列(DL10)、dq/语义空列(DL11)、数值列越界残留(DL12，按 dim min_bound/max_bound 复扫)；缺列/缺字典优雅降级为 WARN 不崩；构建后跑 |
| `tools/validate_brand_dim_dup.py` | **品牌字典查重校验器（连库）**：BD1 [FAIL] —— 按**归一化品牌名**（大写+去公司后缀+去非字母数字）聚合 `dim_std_brand`(state=1)，同 key 落 >1 个 `brand_id_std` 即「同一公司多行」真重复；补宽表门控 DL1（distinct brand=distinct brandid）的盲区。伪重复（缩写撞车的不同公司）用 BUILTIN_WAIVER / `--waiver` / env `BRAND_DUP_WAIVER` 登记。已接进 `sync_dim_std_brand.sh` 末尾 fail-fast。`--dim-schema dim|test_dim` |

---

## 八、配套通用探针（SQL 模板）

> 三个可复用 SQL 探针模板已独立成册：**[probes.md](probes.md)**（占位符替换后直接在 StarRocks 客户端执行）。
> - **§8.1 空值率扫描** — L2 物理列空值率 + 品牌门控验收（阶段 5.5.1 / 5 / 7）
> - **§8.2 分层抽样** — 按品牌分层抽样人工审阅源端杂乱度（阶段 1 / 5.2 / 7）
> - **§8.3 源-schema gap 探针** — 本源高频键 vs 抽取规则覆盖缺口（阶段 5.5.2）

---

## 九、一句话总结

> **把所有「人为定义」收敛到 dim 字典，把所有「数据加工」收敛到通用引擎，把所有「正确性证明」收敛到「内部探针 + 外部商城核对 + 基线 CSV」三件套，把所有「prod 写操作」收敛到「人工授权」一个门控。四者解耦之后，元器件清洗就是一个可重复、可审计、可演进的工程。**
