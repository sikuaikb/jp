# 阶段 3 · 属性标准化 dim（三张字典 + 三方一致性）

> **本阶段一句话**：定义参数本身的标准形态。三张 dim 字典 + 一次 DDL/dim/规格三方一致性强制校验。
> 占工期：约 18%。前置：阶段 2 草案通过商城核对。

---

## 3.0 从原始 Excel 提取 schema 与枚举草案（属性 dim 的上游输入）

> **权威源原则**：属性的标准形态（code / 类型 / 单位 / 值域 / 枚举词表）的**唯一权威源是业务方提供的原始 Excel schema**（每个 L1 一份，如 `tmp/pmic_schema.xlsx`），**不是**库里的脏数据、也不是 dim 里已落的 `value_domain`（后者本就从 Excel 来）。新增任何"对照/白名单/词表"类校验前，先回答三问：值的权威源是谁？是否独立于被校验数据？源自身是否一致？——三问不过则不做。详见 [lessons_learned.md#LL-20260529-11](../lessons_learned.md)。

### 3.0.1 Excel schema 的 11 列布局（约定）

| 列 | 含义 | 落到 dim |
|----|------|---------|
| 分类等级 | `L2` / `L3` | `scope_level`（小写） |
| 分类名称 | 中文名 | `std_attr_cn` / 分类中文 |
| 分类英文名 | L2 行带 `_Base` 后缀；L3 行为 L3 code | `scope_code`（**去 `_base` 并小写**） |
| 模块分类 | tech/regulatory/purchasing/package | `attr_category_*` |
| 核心属性中文名称 | | `std_attr_cn` |
| 核心属性英文名称 | snake_case code | `std_attr_code`（小写） |
| 属性描述 | 兼作 LLM Prompt | `note` |
| 类型 | VARCHAR/DOUBLE/INT/BOOLEAN… | `db_type` |
| 小数点精度 | | `precision` |
| 基准单位 | | `unit_std` |
| **值域约束** | 自由文本：`> 0` / `-65 ~ 0` / `A / B / C` / `TRUE / FALSE` / `非空字符串` | `value_domain`（原样）+ 解析出 `min_bound/max_bound` + 枚举词表草案 |

> Excel 里 L2 节点带 `_Base` 是规格书惯例；**落 dim/宽表时必须去掉**（硬门控：`l2_code` 不得带 `_base`，见 SKILL §六）。

### 3.0.2 `值域约束` 三类去向

| `值域约束` 形态 | 判定 | 去向 |
|----|----|----|
| `> 0` / `≥ 1` / `-65 ~ 0` 等含界符或区间 | 数值界 | 转写进 `min_bound/max_bound`（机器列；引擎读这两列，不读 value_domain 文本）；覆盖审计见 `validate_attr_dim.py` A13/A14 |
| `A / B / C`、`TRUE / FALSE` 等离散集 | 枚举 | 抽成**枚举词表草案** → 人工裁决 → 落 **test_dim 只读临时表 `tmp_attr_enum`** |
| `非空字符串`、`NOT NULL`、`符合JEDEC/IPC规范`、`如 EAR99 / 3A001.a` | 格式/自由文本 | 不进枚举（注意：这里的 `/` 是"规范名/示例"不是枚举分隔符） |

### 3.0.3 枚举草案抽取（工具）

```bash
python3 tools/extract_attr_enum_draft.py \
  --xlsx tmp/<l1>_schema.xlsx --l1 <l1> \
  --out  sql_scripts/test/<l1>_attr_enum_draft.csv
```

产物 CSV 列：`l1_code, scope_level, scope_code, std_attr_code, db_type, raw_value_domain, kind, parsed_enum_values, conflict, decision`。

- `kind` ∈ `enum/bool/range/bound/format/freetext`，工具自动归类。
- `parsed_enum_values` 仅 `enum/bool` 给候选，**仅供参考**。
- `conflict=yes`：**同 `std_attr_code` 在多处给出不同词表**（如 pmic 的 `lifecycle_status` 有 6 套、`reach` 有 TRUE/FALSE vs Compliant/Non-Compliant），机器无法替你选，`decision` 列**必须人工裁决**填最终词表。

### 3.0.4 人工裁决 → 落 test-only 临时表（硬约束：禁止同步 prod）

裁决后把 `decision` 列定稿，导入 **`test_dim.tmp_attr_enum`**（只读对照表，**永不同步到 prod dim**，不污染生产 schema）：

```sql
CREATE TABLE IF NOT EXISTS test_dim.tmp_attr_enum (
  l1_code       VARCHAR(32)  NOT NULL,
  scope_level   VARCHAR(8)   NOT NULL,   -- l2 / l3
  scope_code    VARCHAR(64)  NOT NULL,
  std_attr_code VARCHAR(64)  NOT NULL,
  enum_values   JSON         NOT NULL,   -- 人工裁决后的最终受控词表
  source_note   VARCHAR(512) NULL,       -- 溯源：来自哪份 Excel / 裁决理由
  create_at     DATETIME     NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=OLAP PRIMARY KEY(`l1_code`,`scope_level`,`scope_code`,`std_attr_code`)
  DISTRIBUTED BY HASH(`l1_code`) BUCKETS 4;
```

> **现状（勿过度宣称）**：`validate_dwd_data.py` **尚未**实现读 `tmp_attr_enum` 的枚举校验（截至本版本，pipeline §7 无对应规则 ID）。这是**规划项**：落地时按「存在才校验、缺失降级 WARN 跳过」范式（与 DL12 同），读 `test_dim.tmp_attr_enum`、**绝不依赖 prod**。先把临时表建好、人工裁决词表填好，再补该校验规则。

> **0 当缺失**：不单独建规则。严格正量（Excel `值域约束` 为 `> 0`）的 `0` 即越界，由 `min_bound` + `validate_dwd_data.py` DL12 兜住；真正二义的（`0` 既合法又当占位，如 `temp_min_c` 的 Excel 上界就是 `0`）机器无法判定，**不校验**。详见 [lessons_learned.md#LL-20260529-11](../lessons_learned.md)。

---

## 3.1 三张字典是什么

| 字典 | 作用 | 主键 |
|------|------|------|
| `dim_attr_schema` | 定义标准属性的形态（code、目标单位、数据类型、值域上下界） | `(schema_version, l1_code, scope_level, scope_code, std_attr_code)` |
| `dim_attr_extract_rule` | 定义"源端 → 标准属性"的抽取路径，每条带 priority | `extract_rule_id` |
| `dim_unit_factor` | 单位换算字典（源单位 → 目标单位 × 乘子） | `(target_unit, unit_raw)`（`值_std = 值_raw × factor`） |

**核心原则**：

1. 标准属性 code **只增不改**。改名会破坏下游所有引用。
2. 抽取规则只做"找原始值"，**不做"数值合不合理"判断**（后者交给 schema 值域）。
3. 单位字典必须收齐**源端真实出现过的所有写法**（含全角符号、大小写、空格、拼写错误变体）。

---

## 3.2 `dim_attr_schema` 设计

### 3.2.1 字段含义（按 prod 真实 schema）

| 字段 | 必填 | 说明 |
|------|------|------|
| `schema_version` | Y | dim 字典版本号（如 `v1`）；同一 L1 同一 std_attr_code 只能有一个 enabled 版本 |
| `l1_code` | Y | 所属 L1 大类 |
| `scope_level` | Y | `l2` 或 `l3`，决定该属性是宽表物理列还是 ext_attributes 槽 |
| `scope_code` | Y | scope_level=l2 时填 L2 code；scope_level=l3 时填 L3 code |
| `std_attr_code` | Y | 标准属性 snake_case 英文 code，全局唯一，**只增不改** |
| `std_attr_cn` | N | 中文显示名 |
| `db_type` | Y | `DOUBLE` / `INT` / `BIGINT` / `VARCHAR` / `BOOLEAN` / `JSON`（**大写**，与 DDL 对齐） |
| `precision` | N | 小数位 / VARCHAR 长度（视 `db_type` 而定） |
| `unit_std` | N | 目标单位（如 `F`、`Ω`、`Hz`、`V`） |
| `value_domain` | N | **Excel「值域约束」列原文（人读自由文本）**，如 `> 0` / `-65 ~ 0` / `A / B / C` / `非空字符串`。**不是**机器可读枚举数组，引擎**不读**此列。数值界须转写进 `min_bound/max_bound`；机器可读枚举词表见 §3.0.4 的 `test_dim.tmp_attr_enum`（**prod `dim_attr_schema` 不存枚举值**） |
| `min_bound` / `max_bound` | N | 数值上下界（机器列，引擎只读这两列）；超界由清洗引擎在 EAV 标 `dq_flag=out_of_range` 或置 NULL，宽表残留由 `validate_dwd_data.py` DL12 复扫 WARN |
| `is_l2_common` | Y | 0/1；冗余字段，1 等价于 `scope_level='l2'` |
| `display_ord` | N | 宽表列展示顺序 |
| `attr_category_cn` / `attr_category_en` | N | 属性分组（用于规格 Excel 与 UI 分区） |
| `note` | N | 备注 / 设计意图 |

> 注意：之前文档里出现的 `data_type` / `enum_values` / `value_min` 等是旧名，**真实字段以本表为准**。改名会破坏所有引用，**别再用旧名**。特别地，`enum_values` **禁止**出现在 `dim_attr_schema`（prod 不存枚举值）；它**只允许**作为 `test_dim.tmp_attr_enum` 的列存在（见 §3.0.4）。

### 3.2.2 命名约定（强制硬约束）

#### snake_case 规范

- **全小写英文 + 下划线**，**禁止任何大写字符**
- **禁止连字符 `-`、空格、点号**
- 包含单位后缀（避免歧义）：`capacitance_f`、`resistance_ohm`、`frequency_hz`、`voltage_max_v`
- 复合属性带前缀：`temp_min_c`、`temp_max_c`、`current_continuous_a`、`current_pulse_a`
- 枚举类不带单位后缀：`package_type`、`mounting_style`、`tolerance_class`

#### 正则校验

每条新增 `std_attr_code` 必须通过正则 `^[a-z][a-z0-9_]*$`。例：

| 合规 | 不合规 | 原因 |
|------|--------|------|
| `lead_free` | `Lead_Free` | 大写 |
| `rohs_compliant` | `RoHS_Compliant` | 大写 |
| `aec_q_level` | `AEC_Q_Level` | 大写 |
| `package_case` | `Package_Case` / `package-case` | 大写 / 连字符 |
| `eccn_code` | `ECCN_Code` | 大写 |

#### 宽表物理列名 = std_attr_code（强约束）

L2 宽表的 DDL 列名**必须与 `std_attr_code` 完全一致**（含大小写），不允许任何二次"美化"：

```sql
-- ✅ 正确：列名 = std_attr_code
CREATE TABLE dwd_l2_resistor_fixed_resistor (
  ...
  reach           BOOLEAN,
  lead_free       BOOLEAN,
  rohs_compliant  BOOLEAN,
  ...
);

-- ❌ 反例：列名是 PascalCase（即使语义对应也不允许）
CREATE TABLE dwd_l2_resistor_fixed_resistor_llm_completion (
  ...
  Reach           TINYINT(1),
  Lead_Free       TINYINT(1),
  RoHS_Compliant  TINYINT(1),
  ...
);
```

违反的后果：下游 SQL / BI 工具大小写敏感时查询失败、跨表 JOIN 时列名对不上、ext_attributes JSON key 与物理列大小写不统一造成消费方混乱。

#### 校验脚本（合并前必跑）

```sql
-- dim_attr_schema 中所有违规 std_attr_code
SELECT l1_code, scope_level, scope_code, std_attr_code
FROM dim.dim_attr_schema
WHERE std_attr_code REGEXP '[A-Z]'
   OR std_attr_code REGEXP '[^a-z0-9_]'
   OR std_attr_code NOT REGEXP '^[a-z]';
-- 应返回 0 行

-- 所有 L2 宽表违规列名
SELECT table_schema, table_name, column_name
FROM information_schema.columns
WHERE table_schema IN ('dwd','test_dwd')
  AND table_name LIKE 'dwd_l2_%'
  AND (column_name REGEXP '[A-Z]' OR column_name REGEXP '[^a-z0-9_]');
-- 应返回 0 行
```

### 3.2.3 同名 std_attr_code 跨 L1/scope 类型一致性（强约束）

**一个 std_attr_code 在任何 L1 / scope 下出现，`db_type` 必须完全相同**。

这是最容易踩、却又最难发现的反模式：

- `reach` 在固定电阻是 `BOOLEAN`、在敏感电阻是 `VARCHAR`
- `lead_free` 在二极管是 `BOOLEAN`、在 MCU 是 `VARCHAR`
- `temp_max_c` 大多数 L2 是 `DOUBLE`，唯独某个 L2（如 `fet`）误用了 `INT`

**这种分裂的后果**：

1. 下游消费方写跨 L1 的 SQL 时类型不兼容（`UNION ALL` 直接报错或隐式转换出错）
2. ext_attributes JSON 值的解析逻辑要分支处理（"这个 L2 是 bool，那个 L2 是 string"）
3. LLM 补全 / 业务规则代码的判定条件无法跨 L1 复用
4. 数据仓库的 schema 治理失效，难以维护

#### 统一规则

| 语义 | 强制 db_type | 不允许 |
|------|---------------|--------|
| 合规标志（reach / rohs_compliant / lead_free / aec_q_level 等是否合规） | `BOOLEAN` | VARCHAR、INT、ENUM |
| 温度上下界 | `DOUBLE`（即使源数据多为整数） | INT |
| 容差百分比 / 任何百分比类数值 | `DOUBLE` | VARCHAR |
| 容量 / 电阻 / 电感 / 电压 / 电流 等连续物理量 | `DOUBLE` | INT、VARCHAR |
| 包装数量 / pin 数 / 内存大小（字节）等天然整型 | `BIGINT`（统一用 BIGINT 而非 INT，防溢出） | DOUBLE、VARCHAR |
| 封装类型 / 安装方式 等离散有限集 | `VARCHAR`（枚举受控词表落 `test_dim.tmp_attr_enum`，见 §3.0.4；`value_domain` 仅存 Excel 原文） | INT |
| 数组类（多值标签 / 协议列表） | `JSON` 或 `VARCHAR`（需文档说明 separator） | 多列拆分 |

#### 类型升级路径

如果发现历史数据已经用了错的类型，统一升级方向：

```
VARCHAR(枚举只有 Y/N) → BOOLEAN
INT(实际能有小数)     → DOUBLE
VARCHAR(纯数字写法)   → DOUBLE 或 BIGINT
枚举类 VARCHAR 缺受控词表 → 走 §3.0 抽取 + 人工裁决 → 导入 test_dim.tmp_attr_enum（保持 VARCHAR；不往 value_domain 塞枚举数组）
```

**绝不允许**：发现分裂后保留两种类型 + 在 SQL 里 `CASE WHEN l1_code='...' THEN cast(...) ELSE ...`。这是把分裂从 schema 推给消费方，雪上加霜。

#### 校验脚本（合并前必跑）

```sql
-- 同 std_attr_code 跨 scope 出现多种 db_type
SELECT std_attr_code,
       COUNT(DISTINCT db_type) AS dt_kinds,
       GROUP_CONCAT(DISTINCT db_type) AS db_types,
       GROUP_CONCAT(DISTINCT CONCAT(l1_code,'/',scope_code,'->',db_type)) AS detail
FROM dim.dim_attr_schema
GROUP BY std_attr_code
HAVING COUNT(DISTINCT db_type) > 1;
-- 应返回 0 行
```

### 3.2.4 L2 / L3 分层判断

| 维度 | 物理列（L2 公共属性） | `ext_attributes` 槽（L3 专有属性） |
|------|---------------------|----------------------------------|
| 适用范围 | 该 L2 下**所有 L3 子类共同关注** | 仅某个 L3 子类才需要 |
| NULL 含义 | 源数据没有该参数，正常 | 物料不属于该 L3 子类，正常 |
| dim 配置 | `scope_level='l2'`，`scope_code=<L2 code>` | `scope_level='l3'`，`scope_code=<L3 code>` |
| 宽表落点 | DDL 物理列 | `ext_attributes` JSON 一列 |

**L3 属性的合约登记原则**：即使当前源数据中**完全没有**对应字段，也应在 `dim_attr_schema` 里完整登记。这是「数据合约」而非「已实现的填充」。

判断起手式（拿不准时用这一条）：

> 「我把这个属性做成 L2 物理列后，该 L2 下**另一个 L3 子类**的物料会不会让这一列永远是 NULL？」
>
> - 会 → 改成 L3 ext_attributes
> - 不会 → 是 L2

例：电容的 `dielectric_material` 应该是 L2（所有电容 L3 都关心），但 `polymer_type` 是 L3（只有铝聚合物/钽聚合物关心）。

---

## 3.3 `dim_attr_extract_rule` 设计

### 3.3.1 多路径抽取（跨源 + 跨字段）

同一标准属性几乎一定有多个源端候选——既包括**同源内的多个字段路径**，也包括**多源各自的字段路径**。每条路径**独立一行**，独立打 priority，并通过 `data_source` 列标识规则来自哪个源。

**不要在引擎里写 if/else，也不要在一条规则里塞两个源**。

| extract_rule_id | data_source | std_attr_code | source_kind | source_expr | priority | scope |
|---|---|---|---|---|---|---|
| `t1509_bjt_hfe_cn_p10`    | `icpdf`   | `dc_current_gain_hfe` | `prajson_cn_eq`         | `直流电流增益(hFE)`     | 10 | l3/bjt |
| `t1509_bjt_hfe_en_p20`    | `icpdf`   | `dc_current_gain_hfe` | `prajson_cn_eq`         | `DC Current Gain (hFE)` | 20 | l3/bjt |
| `t1509_bjt_hfe_kv_p30`    | `icpdf`   | `dc_current_gain_hfe` | `prajson2_key_eq`       | `hFE`                   | 30 | l3/bjt |
| `dk1520_bjt_hfe_p10`      | `digikey` | `dc_current_gain_hfe` | `digikey_param_kv_eq`   | `hFE (Min) @ Ic, Vce`   | 10 | l3/bjt |

**priority 数字越小越优先**，同 `(data_source, id, std_attr_code)` 下 priority 最小者胜出；不同 `data_source` 互不影响，因为合并 EAV 时按源拆 build 装配。

### 3.3.2 source_kind 类型（按源端形态分组）

`source_kind` 的命名遵循 `<源前缀>_<访问方式>_<匹配语义>`（见 [SKILL.md §二-A.B](../SKILL.md#二a源适配层与多源接入方法论的通用前提)）。下表列出当前项目已使用的取值；**新源接入时只追加新行，不改既有行的语义**。

**A. 跨源通用**：

| source_kind | 含义 |
|---|---|
| `direct_column` | 源表的某个物理列名（任意源） |
| `<source>_text_regex` | 在源端某个文本列上跑 source_expr 正则 |

**B. icpdf 源端 4 字段（prajson / prajson2 / taginfo / category*）**：

| source_kind | 含义 |
|---|---|
| `prajson_cn_eq`         | prajson 数组元素 `cn` 字段精确匹配 source_expr |
| `prajson_cn_contains`   | prajson 数组元素 `cn` 字段包含 source_expr |
| `prajson_sqlname_eq`    | prajson 数组元素 `sqlname` 字段精确匹配 source_expr |
| `prajson2_key_eq`       | prajson2 顶层键名 = source_expr |
| `prajson2_key_contains` | prajson2 顶层键名 包含 source_expr |
| `param_taginfo_eq`      | taginfo 数组元素精确匹配（常配 `literal_std_value` 做枚举归一） |
| `param_category_eq`     | category 字段精确匹配 |
| `param_category2_eq`    | category2 字段精确匹配 |
| `param_category_info_eq`| category_info 数组元素匹配 |

**C. digikey 源端**（平铺参数 KV / 直接分类列）：

| source_kind | 含义 |
|---|---|
| `digikey_param_kv_eq`   | digikey 参数表（id, param_name, param_value）按 param_name 精确匹配 |
| `digikey_param_kv_contains` | 按 param_name 包含匹配 |
| `digikey_category_eq`   | digikey category 列精确匹配 |
| `digikey_family_eq`     | digikey family/subfamily 列精确匹配 |

**D. 新源接入**：照 §二-A.C 的步骤追加，例如新源 `mouser` 可定义 `mouser_attribute_kv_eq` 等取值；定义后须同步实现 `build_dwd_component_attr_std_<source>.sql` 中对应的 CASE 分支。

### 3.3.3 ID 前缀约定（强制）

**`extract_rule_id` 必须带 L1 前缀**：

```
<l1 缩写><三位数序号>_<scope code 简写>_<描述>_p<priority>
```

例：

- `t1509_bjt_hfe_cn_p10`（transistor 的 1509 系列）
- `mcu110c_cn_flash`（mcu 的 110 系列）
- `cap201_alpoly_esr_kv_p20`（capacitor 的 201 系列）

**违反 ID 前缀的后果**：合并到通用 dim 时 PK 冲突，StarRocks 的 REPLACE 语义会**静默覆盖**旧数据。

### 3.3.4 priority 赋值的实战经验

不要凭直觉拍 priority。应该**先探查各路径在源端的实际非空率**（每个源各跑一遍，priority 只在同一 `data_source` 内可比）：

```sql
-- 通用模式：统计某 source_kind + source_expr 在本源里的非空命中数
-- 替换 <SRC_PARAM_TABLE>、<SRC_KEY_EXPR>（按 SKILL §二-A 占位符约定填写）
-- icpdf 示例：
--   路径 A：SELECT COUNT(*) FROM dwd.dwd_icpdf_component_param
--           WHERE get_json_string(prajson2, '$.容量') IS NOT NULL;
--   路径 B：SELECT COUNT(*) FROM dwd.dwd_icpdf_component_param p
--           WHERE EXISTS (... prajson 数组中 cn='电容值' AND val IS NOT NULL ...);
-- digikey 示例：
--   路径 C：SELECT COUNT(DISTINCT id) FROM dwd.dwd_digikey_component_param
--           WHERE param_name = '容值' AND param_value IS NOT NULL;
SELECT COUNT(*) AS hit
FROM <SRC_PARAM_TABLE>
WHERE <SRC_KEY_EXPR> IS NOT NULL;
```

**非空率高且写法标准的路径 → 赋小 priority 数（高优先级）**。
**非空率低或写法杂乱的路径 → 赋大 priority 数（兜底）**。

priority 排错时的典型 bug：高 priority 数的"垃圾路径"压制了低 priority 数的"高质量路径" → 阶段 5.5 复验时会看到该属性空值率反而上升。

---

## 3.4 `dim_unit_factor` 设计

### 3.4.1 必须收齐源端真实写法

**反模式**：只覆盖"标准写法"（`uF`、`nF`、`pF`），源端实际有 20 种变体。**多源场景下，每个源的单位变体集合通常不重合**——必须逐源穷举。

正确做法：先从该源的所有候选字段（icpdf：`prajson` 值 / `prajson2` 值 / `taginfo`；digikey：`param_value`；其他源等价字段）里**穷举**所有出现过的单位写法：

```sql
-- 通用：假设单位都跟在数字后面，用正则把"数字+空格+单位"抓出来
-- 替换 <SRC_PARAM_TABLE>、<SRC_KEY_EXPR>（按 SKILL §二-A.D 占位符约定）
-- icpdf 示例：<SRC_KEY_EXPR> = TRIM(get_json_string(prajson2, '$.容量'))
-- digikey 示例：<SRC_KEY_EXPR> = (SELECT param_value FROM dwd.dwd_digikey_component_param d
--                                  WHERE d.id = t.id AND d.param_name = '容值' LIMIT 1)
SELECT
  REGEXP_EXTRACT(val, '\\d+\\.?\\d*\\s*([a-zA-Zμ微]+)', 1) AS unit_raw,
  COUNT(*) AS n
FROM (
  SELECT <SRC_KEY_EXPR> AS val
  FROM <SRC_PARAM_TABLE>
) t
WHERE val IS NOT NULL
GROUP BY 1
ORDER BY n DESC LIMIT 100;
```

把结果作为单位字典（`test_dim.dim_unit_factor`）的输入，逐个映射到目标单位。

### 3.4.2 常见漏洞清单

预先准备的"必查变体"清单：

| 类型 | 标准 | 必须额外覆盖的变体 |
|------|------|---------------------|
| 微（μ） | `μF` | `uF`, `UF`, `μＦ`（全角）, `μＦ`（全角 F）, `Μf`, `MicroF`, `microF`, `微法`, `μ法` |
| 千（k） | `kΩ` | `KΩ`, `KOhm`, `kohm`, `K欧`, `千欧`, `KOHM` |
| 兆（M） | `MΩ` | `Mohm`, `MOhm`, `MOHM`, `兆欧`, `M欧` |
| 纳（n） | `nF` | `NF`, `Nf`, `nf`, `纳法` |
| 字节 | `B` 或 `KB` | **`字节`、`Byte`、`bytes`、`B`、`字节数`** — 容易被识别成 KB |
| 千字节 | `KB` | `KByte`, `KB`, `K字节`, `K bytes` |
| 安培 | `A` | `安`, `Amps`, `amp`, `安培` |
| 毫安 | `mA` | `MA`, `ma`, `毫安` |

**坑王**：内存/存储参数的"字节" vs "KB"。源端写 `RAM: 1024字节` 如果单位字典识别不出 `字节` 就 fall-through 当成 KB，**数据偏差 1000 倍**且机器检查不出来。这是阶段 5.5.3 单位抽样的核心目标。

### 3.4.3 字典结构

```csv
target_unit,unit_raw,factor,std_attr_code_filter,notes
F,uF,1e-6,,
F,UF,1e-6,,大小写变体
F,微法,1e-6,,中文
F,μF,1e-6,,
F,μＦ,1e-6,,全角F
B,字节,1,ram_size_b,显式 std_attr_code 限定避免误伤
B,Byte,1,ram_size_b,
B,KB,1024,ram_size_b,
```

> 列名以 prod 真实 schema 为准：**PK = `(target_unit, unit_raw)`**（`target_unit`=标准目标单位，`unit_raw`=源端写法），`factor` 满足 `值_std = 值_raw × factor`。校验器 `validate_attr_dim.py` A9 即按此 PK + factor 数值性检查。`std_attr_code_filter` 用于"该单位只在某个标准属性下生效"，防止跨属性误伤。

---

## 3.5 三方一致性强制校验（本阶段最容易漏的一步）

完成属性 dim 初稿后，**强制做一次三方比对**：

| 文档 | 应包含什么 |
|------|-----------|
| 规格文档（Excel / 白皮书） | L2 公共列定义 + L3 专有属性定义 |
| DDL（宽表建表语句） | 物理列与 L2 规格一一对应 |
| `dim_attr_schema` | 每个 L2 + L3 属性均有对应行 |

### 3.5.1 比对脚本（示例）

把三份各导出为 TSV：

```bash
# 1) 规格 Excel 导出为 spec.tsv（人工或脚本）
# 2) DDL 物理列：
mysql -B -N -e "
  SELECT column_name FROM information_schema.columns
  WHERE table_schema='test_dwd' AND table_name='dwd_l2_<l1>_<l2_code>'
" > ddl_cols.tsv

# 3) dim_attr_schema 已登记列：
mysql -B -N -e "
  SELECT std_attr_code FROM test_dim.dim_attr_schema
  WHERE l1_code='<l1>' AND scope_level='l2' AND scope_code='<l2_code>' AND enabled=1
" > dim_cols.tsv

# 三方 diff
diff <(sort spec.tsv) <(sort ddl_cols.tsv)
diff <(sort ddl_cols.tsv) <(sort dim_cols.tsv)
```

### 3.5.2 常见的三类不一致

| 类型 | 现象 | 后果 |
|------|------|------|
| 规格有、DDL 缺 | 宽表列不存在 | 引擎不报错，数据永远丢，下游消费方查不到 |
| DDL 有、dim 缺 | 列存在但永远 NULL | 无法追溯原因，工程师反复怀疑源数据 |
| dim 有、DDL 缺（L2） | EAV 有数据但宽表落不下来 | 数据回流失败 |
| dim 有、DDL 缺（L3） | 正常（应该走 ext_attributes） | 需确认是有意为之 |

### 3.5.3 强制门控

```
☐ spec ↔ DDL 列级 diff = 0
☐ DDL ↔ dim L2 列级 diff = 0
☐ dim 中所有 L3 属性都在某个 L3 code 范围内（不存在孤儿）
```

不通过不允许进入阶段 4。

---

## 3.6 产物清单

| 产物 | 落到哪里 |
|------|---------|
| L2 宽表 DDL | `sql_scripts/2.attribute_standard/dwd_l2_<l1>_<l2_code>.sql` |
| `dim_attr_schema` 新增行 | `test_dim.dim_attr_schema_<l1>` 后缀表（INSERT） |
| `dim_attr_extract_rule` 新增行 | `test_dim.dim_attr_extract_rule_<l1>` 后缀表（INSERT） |
| `dim_unit_factor` 新增行 | `test_dim.dim_unit_factor`（只追加缺失单位） |
| 单位变体探查 TSV | `artifacts/<l1>/unit_variants_<date>.tsv` |
| 三方一致性 diff 报告 | `artifacts/<l1>/dim_ddl_spec_diff_<date>.md` |

---

## 3.7 反模式

| 反模式 | 后果 |
|--------|------|
| std_attr_code 起完了又改名 | 破坏所有下游引用、EAV 历史数据失联 |
| **std_attr_code 用 PascalCase / 含大写** | 跨工具大小写敏感时查询失败、与下游 JSON key 不一致 |
| **L2 宽表列名 ≠ std_attr_code（任意大小写差异）** | EAV 透视 → 物理列的映射错乱，BI 工具 case-sensitive 时无法查询 |
| **同名 std_attr_code 跨 L1 类型分裂** | 跨 L1 SQL UNION 报错、消费方代码分支处理、schema 治理失效 |
| 发现类型分裂后保留两种类型 + 消费方 CAST 兼容 | 把分裂从 schema 推给消费方，雪上加霜 |
| 抽取规则只写"标准写法"，不收变体 | 源端写法稍微不同就漏抽 |
| 单位字典只覆盖小写写法 | 大写 / 全角 / 中文变体全部 fall-through，数据严重偏差 |
| 同属性用 IF/CASE 选源 | 不可维护，无法局部调整 |
| L3 专有属性塞进 L2 物理列 | 该 L2 下其它 L3 永远 NULL，污染空值率统计 |
| 三方一致性不查就进阶段 4 | DDL 漏列 / dim 漏行的问题，要到 5.5 才被发现，返工成本最高 |
| 不带 L1 前缀的 extract_rule_id | 合并时 PK 冲突，被迫返工 |

---

## 3.8 完成判定

```
☐ 三张 dim 字典都有 git diff 入仓
☐ 单位变体探查 TSV 已产出，单位字典已收齐
☐ 三方一致性 diff 报告显示三方完全对齐
☐ 所有 extract_rule_id 带 L1 前缀
☐ 所有 L3 属性都登记到 dim_attr_schema（合约登记原则）
☐ 所有 std_attr_code 通过 snake_case 正则校验（^[a-z][a-z0-9_]*$）
☐ 所有 L2 宽表 DDL 列名 = std_attr_code（含大小写）
☐ 跨 L1/scope 同名 std_attr_code 的 db_type 一致性扫描结果 = 0 行
```
