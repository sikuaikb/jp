# 阶段 1 · 源层摸底

> **本阶段一句话**：看清源数据本身长什么样，**不写一行清洗规则**。
> 占工期：约 10%。配套探针模板见 [SKILL.md §八](../probes.md)。

> **源无关性声明**：本阶段是**对单个数据源做一次摸底**。如果本次清洗要接入多个源（如 icpdf + digikey），**每个源都要独立做一次本阶段**——它们的字段命名、JSON 形态、空值习惯通常完全不同，必须分别看清。下方所有 SQL 用占位符 `<SRC_PARAM_TABLE>` / `<SRC_SEMI_JSON>` / `<SOURCE>` 给出，替换时参考 [SKILL.md §二-A 占位符约定](../SKILL.md#二a源适配层与多源接入方法论的通用前提)。

---

## 1.1 必要前置

- 已确认本轮要摸底哪个源 `<SOURCE>`（icpdf / digikey / mouser / ecloud / ……）。
- 已知该源的源参数表 `<SRC_PARAM_TABLE>`，例如 icpdf=`dwd.dwd_icpdf_component_param`、digikey=`dwd.dwd_digikey_component_param`。
- 已知本次清洗的 L1 大类是什么（例如 `transistor`、`capacitor`、`mcu_mpu_dsp`、`pmic`）。注意 `mcu`/`mpu_soc`/`dsp` 是 L2 而非 L1，L1 是 `mcu_mpu_dsp`（见 SKILL §六）。
- 已知数据有哪些分区粒度（日 / 月 / 全量）。

> **如果是多源**：阶段 1 跑完 N 次后，把"哪些字段在源 A 命中但源 B 没有"、"同一标准属性在 A/B 的源端键名差异"列成跨源对照表，作为阶段 3 设计 `dim_attr_extract_rule` 时按 `data_source` 拆规则行的依据。

## 1.2 要做的四件事

### 1.2.1 量级与分区

```sql
-- 整张源表的行数与分区分布
-- 替换 <SRC_PARAM_TABLE>：icpdf=dwd.dwd_icpdf_component_param、digikey=dwd.dwd_digikey_component_param
-- partition_dt 名称按本源实际分区列名替换；若无分区列，此查询可改为 SELECT COUNT(*)
SELECT partition_dt, COUNT(*) AS n
FROM <SRC_PARAM_TABLE>
GROUP BY partition_dt ORDER BY partition_dt;
```

判断点：

- 有没有断档分区？
- 最新分区的行数是否合理（同比/环比）？
- 是否有过大的"超级分区"导致后续抽样被碾压？

### 1.2.2 字段覆盖率（含 JSON 顶层键 / KV 键）

每个字段在「整张源表 + 本品类相关分区」中出现的物料比例。**逐源各跑一次**，因为字段名各源不同。

**通用列覆盖率（按本源实际列名替换 CASE WHEN 条件）**：

```sql
-- icpdf 示例：源参数表有 brandshort / prajson / prajson2 / taginfo / category2
-- digikey 示例：列名按 digikey 源参数表的实际命名替换
SELECT
  COUNT(*) AS total,
  SUM(CASE WHEN brandshort IS NOT NULL THEN 1 ELSE 0 END) AS has_brand,
  -- ↓ 按本源实际"半结构 / 分类 / 标签"字段续写
  SUM(CASE WHEN <SRC_SEMI_JSON> IS NOT NULL THEN 1 ELSE 0 END) AS has_semi_json
FROM <SRC_PARAM_TABLE>;
```

**JSON 顶层键覆盖率**（仅当源端有半结构 JSON 字段时跑；如 digikey 是平铺 KV，跳过本步，改用 §1.2.2 末尾的 KV 范式）：

```sql
-- 替换 <SRC_PARAM_TABLE> 与 <SRC_SEMI_JSON>（icpdf=prajson2）
WITH base AS (
  SELECT id, <SRC_SEMI_JSON> AS j FROM <SRC_PARAM_TABLE>
  WHERE <SRC_SEMI_JSON> IS NOT NULL
),
keys_exploded AS (
  SELECT b.id, k
  FROM base b,
       UNNEST(CAST(json_keys(b.j) AS ARRAY<VARCHAR(256)>)) AS u(k)
)
SELECT k, COUNT(DISTINCT id) AS hit, COUNT(*) AS occur
FROM keys_exploded
GROUP BY k
ORDER BY hit DESC
LIMIT 100;
```

**KV 范式**（digikey 这种 `(id, param_name, param_value)` 形态）：

```sql
SELECT param_name, COUNT(DISTINCT id) AS hit, COUNT(*) AS occur
FROM <SRC_PARAM_TABLE>
WHERE param_name IS NOT NULL
GROUP BY param_name
ORDER BY hit DESC
LIMIT 100;
```

判断点（两种范式一致）：

- 覆盖率 **>50%** 的字段值得做规则、做 schema 物理列
- 覆盖率 **1% ~ 50%** 的字段记录下来，可能是 L3 专有属性
- 覆盖率 **<1%** 的字段先记下、后面阶段 5.5 再判定是否值得做

### 1.2.3 典型值分层抽样

直接 `LIMIT 100` 看到的几乎都是大厂家的"标准写法"，会**严重低估源端的杂乱程度**。必须分层抽样：

```sql
-- 分层抽样（StarRocks，源无关）：按 brandshort 分层，每品牌最多 5 条全字段
-- 替换 <SRC_PARAM_TABLE>、<FILTER_COND>
-- icpdf 示例：FROM dwd.dwd_icpdf_component_param WHERE category2 LIKE '%transistor%' AND prajson2 IS NOT NULL
-- digikey 示例：FROM dwd.dwd_digikey_component_param WHERE category LIKE '%transistor%'
WITH ranked AS (
  SELECT *,
    ROW_NUMBER() OVER (PARTITION BY brandshort ORDER BY id) AS rn
  FROM <SRC_PARAM_TABLE>
  WHERE <FILTER_COND>
)
SELECT * FROM ranked
WHERE rn <= 5
ORDER BY brandshort, id;
```

将结果导出为 TSV（mysql 客户端加 `-B` 参数），保存到 `artifacts/<l1>/<source>_source_sample_<date>.tsv`。

人眼审阅这份 TSV，重点看：

- 同一参数有多少种写法（"电容值"、"容量"、"capacitance"、"CAP"、...）
- 单位前后缀的所有变体（"μF"、"uF"、"UF"、"微法"、全角"μＦ"、...）
- 是否有乱码、HTML 实体、转义残留
- 是否有"复合字段"（一个键同时塞了值 + 单位 + 容差，比如 `"100uF±20% 16V"`）

**重点抽**：大厂家（Vishay / Murata / Panasonic / TDK / KEMET / 三星 / 国巨 / 风华 / 顺络）+ 小众品牌各占一半。

### 1.2.4 关键词词频

源端的显式分类字段（icpdf：`category` / `category2` / `taginfo`；digikey：`category` / `family`；其他源等价字段）做聚合排序，作为下一阶段 L1 gate 白名单的种子：

```sql
-- 替换 <SRC_PARAM_TABLE>、<CATEGORY_COL>（按本源实际命名替换）
SELECT <CATEGORY_COL>, COUNT(*) AS n
FROM <SRC_PARAM_TABLE>
GROUP BY <CATEGORY_COL>
ORDER BY n DESC
LIMIT 200;
```

判断点：

- Top-N 词频里**一眼能识别的本品类关键词** → gate 白名单
- 跨品类容易混淆的词（如"电容笔"会带"电容"字样）→ 标注为"需在 gate 里加 NOT 排除"
- 中英文混杂、空格、大小写差异 → 在 gate 规则里统一规范化

---

## 1.3 产物清单（强制）

> 多源场景下，下列产物**每个源各产一份**，文件名前缀加 `<source>_`。

| 产物 | 落到哪里 | 格式 |
|------|---------|------|
| 字段覆盖率表 | `artifacts/<l1>/<source>_field_coverage_<date>.tsv` | TSV |
| 顶层键/KV 键 Top100 | `artifacts/<l1>/<source>_keys_<date>.tsv` | TSV |
| 分层抽样原文 | `artifacts/<l1>/<source>_source_sample_<date>.tsv` | TSV |
| 关键词词频 Top200 | `artifacts/<l1>/<source>_keyword_freq_<date>.tsv` | TSV |
| 摸底笔记 | `artifacts/<l1>/<source>_explore_notes_<date>.md` | Markdown，写给阶段 2 的"已观察事实清单" |
| **跨源对照表（仅多源）** | `artifacts/<l1>/cross_source_keymap_<date>.md` | 同一标准属性在各源端的键名/取值差异表 |

**摸底笔记必须包含**：

1. 本品类与哪些"邻近品类"容易混淆（叙述清楚边界）
2. 源端有几条容易掉的坑（乱码 / 复合字段 / 拼写错误 / 多语言混杂）
3. 哪些源端键应该映射到标准属性，候选名单（这是阶段 3 属性 dim 的输入）
4. 数据量是否健康（是否有断档、突增、突降）
5. **本源与其他已接入源相比的差异点**（如有）

---

## 1.4 反模式

| 反模式 | 后果 |
|--------|------|
| 用 `LIMIT 100` 而不是分层抽样 | 看到的全是大厂标准写法，低估源端杂乱度 |
| 跳过阶段 1 直接写 gate | gate 命中率随机，后期返工 |
| 字段覆盖率不分 JSON 顶层键 / KV 键 | 把整列半结构 JSON 算"100% 有"就完事，看不到 key 级别的稀疏度 |
| **多源时只摸底一个源** | 用一个源的字段名/键空间去推断其他源，规则必然在另一个源上大面积漏命中 |
| **跨源直接复用 extract_rule_id** | dim 表 PK 冲突，合并阶段无解 |
| 摸底笔记不入仓库 | 后人 / 下一品类施工者无法复用观察结果 |

---

## 1.5 完成判定

只有同时满足以下条件，才能进入阶段 2：

```
☐ 每个待接入源都独立完成下列 4 项：
   ☐ 字段覆盖率表已产出
   ☐ 顶层键 / KV 键 Top100 已产出
   ☐ 分层抽样 TSV 已产出且人眼浏览过
   ☐ 摸底笔记已写完并入仓
☐ 若为多源场景：跨源对照表已产出（同一标准属性在各源的键名差异）
```

**不要在没有产出阶段 1 笔记的情况下凭直觉写 gate**。每个品类的源端长尾都不同，凭直觉的 gate 命中率 < 50%。
