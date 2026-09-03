---
name: l2-field-qa-audit
description: 电子元器件 L2 宽表字段质量审计与 schema 调整。覆盖源端摸底（prajson key 频率）、填充率扫描（L2 物理列空值率 + 品牌门控 + ext_attributes 覆盖）、0% 字段根因判断（数据源缺失 / 规则错误 / L2→L3 下放 / 删除）、L3 专属字段审计（ext_attributes 每个 L3 专属字段的填充率 + 两步判断：规则错误 or 字段应删除）、抽取规则修复、schema 调整（dim_attr_schema + dim_attr_extract_rule）、EAV + 宽表重建，以及审计报告生成。Use when starting Phase 5.5 QA audit, analyzing null rates on a new L2 wide table, deciding whether to demote L2 fields to L3, auditing L3-specific ext_attributes fields for 0% fill rate, fixing extraction rules for 0% fields, or writing a QA audit report for any L1 component category.
---

# L2 宽表字段质量审计（Phase 5.5）

## 适用场景

- 新 L2 宽表 build 完成后做质量审计
- 发现 0% 填充率字段需要决策
- 需要把某些 L2 字段下放到 L3 ext_attributes
- 规则 `source_expr`（key 名）写错导致抽取失败
- 品牌门控失败（`distinct_brand ≠ distinct_brandid`）

详细决策指南见 [decision-guide.md](decision-guide.md)。

---

## 一、Phase 1 源端摸底

在写规则或做审计之前，先用探针确认源端实际数据。

### 1.1 查 L2 分类结果行数

```sql
SELECT l3_code, COUNT(*) AS cnt
FROM test_dwd.dwd_component_class_filter
WHERE l2_code = '<L2>'
GROUP BY l3_code ORDER BY cnt DESC;
```

若总行数极低（< 100），先确认是 DK category 覆盖少，还是分类规则遗漏。

### 1.2 prajson key 频率探针

用 Python 对 `prajson` 做 key 频率统计（取样 200-500 条），排除管理字段后，剩余 key 即为可提取的参数来源：

```python
# 管理字段（不含电气参数）
admin_keys = {'DigiKey 零件编号','ECCN','HTSUS','category','category_path',
              '制造商','制造商产品编号','制造商标准包装','描述','类别','系列',
              '详细描述','零件状态','Part Number Alias','包装','安装类型',
              '湿气敏感性等级 (MSL)','REACH 状态','环保信息','特色产品',
              'RoHS 状态','PCN 产品变更/停产','报价表','计价货币','库存数量'}
```

**同时检查 `prajson2`**（半结构 JSON），两者互补。

### 1.3 与现有 extract rule 对比（gap 探针）

```sql
SELECT source_expr FROM test_dim.dim_attr_extract_rule_filter
WHERE apply_scope_code = '<L2>'
  AND data_source = 'digikey' AND enabled = 1;
```

将 prajson 实际 key 与已配规则的 `source_expr` 对比，找出「有 key 无规则」的 gap。

---

## 二、Phase 5.5 QA 审计

### 2.1 品牌门控（硬门控，阻断 Phase 6）

```sql
SELECT
    SUM(CASE WHEN brand IS NULL THEN 1 ELSE 0 END)  AS brand_null,
    COUNT(DISTINCT brand)                             AS distinct_brand,
    COUNT(DISTINCT brandid)                           AS distinct_brandid
FROM test_dwd.<wide_table>;
```

**通过条件**：`brand_null = 0` AND `distinct_brand = distinct_brandid`。

失败时查出具体品牌：
```sql
SELECT brand, brandid, COUNT(*) AS cnt
FROM test_dwd.<wide_table>
WHERE brandid IS NULL GROUP BY brand, brandid;
```

品牌修复见 [decision-guide.md §品牌别名修复](decision-guide.md#brand-alias)。

### 2.2 L2 物理列空值率

对每个非元数据列统计填充数：
```sql
SELECT
    SUM(CASE WHEN <col> IS NOT NULL THEN 1 ELSE 0 END) AS has_val,
    COUNT(*) AS total
FROM test_dwd.<wide_table>;
```

对 0% 字段分级：→ 见 §三 字段决策四象限。

### 2.3 L3 ext_attributes 整体覆盖率

```sql
SELECT l3_code, COUNT(*) AS rows,
       SUM(CASE WHEN ext_attributes IS NOT NULL THEN 1 ELSE 0 END) AS has_ext
FROM test_dwd.<wide_table>
GROUP BY l3_code;
```

ext=0 通常意味着 L3 专有规则缺失，或 DK 源无此 L3 参数。

### 2.4 L3 ext_attributes 字段级审计

**必须做！** 覆盖率整体看起来正常，不代表每个 L3 专属字段都提取正确。对每个放入 ext_attributes 的字段，必须按 L3 拆开看填充率，否则可能漏掉规则错误或不该保留的字段。

#### 2.4.1 获取当前 ext 字段列表

```sql
SELECT std_attr_code, scope_code, scope_level, note
FROM test_dim.dim_attr_schema_<l1>
WHERE scope_level = 'l3'
ORDER BY scope_code, std_attr_code;
```

#### 2.4.2 按 L3 分组统计 EAV 中每个 ext 字段的填充率

```python
# 对每个 L3 专属字段，只统计其目标 L3 内的填充率
for attr_code, target_l3 in l3_field_map.items():
    cur.execute(f"""
        SELECT COUNT(*) AS total,
               SUM(CASE WHEN e.value_std_double IS NOT NULL
                           OR (e.value_std_varchar IS NOT NULL
                               AND TRIM(e.value_std_varchar) <> '')
                        THEN 1 ELSE 0 END) AS filled
        FROM test_dwd.dwd_component_class_<l1> c
        LEFT JOIN test_dwd.dwd_component_attr_std_<l1> e
               ON e.id = c.id AND e.data_source = c.data_source
              AND e.std_attr_code = '{attr_code}'
        WHERE c.l3_code = '{target_l3}'
    """)
    row = cur.fetchone()
    pct = row['filled'] / row['total'] * 100 if row['total'] else 0
    print(f"  {attr_code} @ {target_l3}: {row['filled']}/{row['total']} ({pct:.1f}%)")
```

#### 2.4.3 结果判断（两步法）

对 **目标 L3 内填充率 = 0% 或极低（< 5%）** 的 ext 字段，走两步判断：

```
Step 1【技术核查】
  prajson 里有没有该字段的 key？apply_scope_code 是否正确？
  ├─ key 存在但 0% → apply_scope_code 写错 / source_expr 错 / regex 不匹配
  │    → R（规则错误）→ 修 extract rule，重跑 EAV
  └─ 确认无 key → Step 2

Step 2【业务核查】
  这个字段对该 L3 的选型有没有意义？
  ├─ 无意义（该 L3 根本没有这个参数，或选型时不关注）
  │    → X（删除）→ 从 dim_attr_schema + dim_attr_extract_rule 删除
  │    例：为 audio_transformer 放了 frequency_response_raw，
  │        但该 L3 的 DK 产品没有此参数且买家不用它选型
  └─ 有意义但 DK 对该 L3 未填
       → D（数据源缺口）→ 保留字段，在审计报告标注
       例：某 L3 的 certification_body 字段，DK 未填，
           但选型时确实有认证机构区别
```

#### 2.4.4 填充率正常（> 10%）也要抽样验证

低填充率不一定是规则错误，高填充率也不一定是正确提取——需要抽几条 MPN，人工对比 DK 页面与宽表值是否一致：

```python
cur.execute(f"""
    SELECT w.mpn, w.l3_code,
           JSON_EXTRACT(w.ext_attributes, '$.{attr_code}') AS ext_val,
           e.value_std_varchar, e.value_std_double
    FROM test_dwd.<wide_table> w
    LEFT JOIN test_dwd.dwd_component_attr_std_<l1> e
           ON e.id = w.id AND e.std_attr_code = '{attr_code}'
    WHERE w.l3_code = '{target_l3}'
      AND JSON_EXTRACT(w.ext_attributes, '$.{attr_code}') IS NOT NULL
    LIMIT 5
""")
```

---

## 三、字段决策——两步法

> **核心原则**：字段去留以**选型价值**为第一判据，不以数据是否存在为准。"DK 没有数据"不是保留字段的理由，只有"选型有价值"才是。
>
> **适用范围**：本节决策逻辑同时适用于 **L2 公共字段**（§2.2 的 0% 字段）和 **L3 专属字段**（§2.4 的 ext 字段）。区别仅在决策结果：L2 字段的结果是"留 L2 / 下放 L3 / 删除"，L3 专属字段的结果是"留 ext（含 D 级）/ 删除（X）/ 修规则（R）"。

### 第一步：是否抽取错误？（技术核查）

```
prajson / prajson2 里有没有对应的 key？
  │
  ├─ 有 key，但填充率 = 0%
  │     └─ source_expr 写错 / \xa0 / 正则未匹配 → R（规则错误）→ 修 source_expr（→ §四.1）
  │
  └─ 确认无 key → 进入第二步
```

### 第二步：对选型有没有价值？（业务核查）

**判断标准**：该字段是否是买家在选型时用来筛选、比较、排除产品的重要参数？

| 有价值的信号 | 无价值的信号 |
|---|---|
| 选型表/规格书必标 | 仅出现在特殊认证文件 |
| 买家常用来过滤（如频率、阻抗、损耗） | 对该品类器件意义不大（如 LC 滤波器的 AEC 等级） |
| 不同产品间差异大，影响选型 | 同品类几乎固定（如腔体滤波器阻抗默认 50Ω） |
| 竞品规格书均标注 | DK/mouser 均无、icpdf 也极少标注 |

```
对选型有价值？
  │
  ├─ 否 → X（删除）→ 从 schema + DDL + build SQL 移除（→ §四.3）
  │           无论 DK 有无数据，无价值字段一律删除
  │
  └─ 是 → 看数据分布
            │
            ├─ 只在某个 L3 有值（其他 L3 ≈ 0%）
            │    │
            │    │  ⚠️ 不能直接下放！先问：
            │    │  「这个字段在 schema 设计上是否是 L2 下各 L3 都应有的属性？」
            │    │  （从物理/业务含义出发，而不仅从 DK 数据覆盖出发）
            │    │
            │    ├─ 是（L2 级通用属性，各 L3 原则上都应有，只是 DK 对其他 L3 未标注）
            │    │    → D（数据源覆盖不足）→ 保留 L2 字段，标注"DK 对 <其他L3> 未填"
            │    │    例：isolation_voltage_v 对所有变压器都有物理意义，
            │    │        DK 只对 audio_transformer 填写，不代表 pulse_transformer 没有隔离电压
            │    │
            │    └─ 否（字段本质上是该 L3 特有参数，对 L2 下其他 L3 无意义）
            │         → F（下放 L3）→ 移到对应 L3 ext_attributes（→ §四.2）
            │         例：freq_range_raw（频率范围）是 audio_transformer 的独有选型参数，
            │             pulse_transformer 虽然也有频率特性但用其他字段表达（如带宽、匝数比）
            │
            └─ L2 所有子类都没数据 → D（数据源缺失）→ 接受并标注
                    仅当确认选型有价值时，才保留字段等待其他源补充

```

> **判断"是否 L2 通用属性"的三个参考问题**（基于品类知识，不依赖其他数据库）：
> 1. **选型意义**：该字段对 L2 下**所有 L3 子类**的选型决策是否都有意义？
>    （选型意义 = 买家在比较/筛选该类器件时会用到；物理上有意义但选型无用不算）
> 2. **品类知识**：根据器件手册惯例和行业标准，L2 下其他 L3 子类的器件**应该具备**这个参数吗？
>    （不需要查其他数据库；从领域知识判断——例如"所有变压器都有隔离电压规格"）
> 3. **空值归因**：其他 L3 子类在当前数据源中该字段为空，是「数据源本身未填写」还是「该类器件本来就没有这个参数」？
>    - 数据源未填 → 保留 L2（D 级，等数据源补充）
>    - 器件本来就没有 → 下放 L3（F 级）
>
> 三个问题中有两个以上支持"L2 通用" → 保留 L2（D 级），否则 → 下放 L3（F 级）。

### 决策结果速查表

| 代码 | 含义 | 触发条件 | 行动 |
|---|---|---|---|
| **R** | 规则错误 | prajson 有 key 但提取失败 | 修复 source_expr / regex |
| **X** | 删除 | 对选型无价值（无论有无数据） | 删 schema + DDL + build SQL |
| **F** | 下放 L3 | 有价值，且字段本质上是某 L3 特有参数（其他 L3 无此概念） | 移到 L3 ext_attributes |
| **D** | 数据源缺失 | 有价值，字段 L2 级通用但 DK 对部分/全部 L3 未填 | 保留字段，标注"等其他源/DK 未覆盖" |

---

## 四、Schema 调整操作

### 4.1 修复 source_expr（规则 key 写错）

1. 用 prajson 探针确认真实 key 名（注意非断空格 `\xa0`）
2. 在 `test_dim.dim_attr_extract_rule_filter` 中 INSERT 覆盖（StarRocks 不支持 UPDATE）：

```python
cur.execute("""
    INSERT INTO test_dim.dim_attr_extract_rule_filter
    (extract_rule_id, l1_code, data_source, schema_version,
     apply_scope_level, apply_scope_code, std_attr_code,
     source_kind, source_expr, source_value_regex, priority, enabled, note)
    VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
""", (rule_id, l1, ds, sv, scope_level, scope_code, attr_code,
      source_kind, NEW_EXPR, regex, priority, 1, note))
```

> ⚠️ regex 中的 `\d` 必须用 `r'([\d.]+)'`（raw string）传入，否则被 pymysql 转义丢失反斜杠。

3. 同步更新 seed CSV `dim_attr_extract_rule_filter.csv`。

### 4.2 L2 字段下放到 L3 ext_attributes

1. **删除 L2 schema 行**：从 `test_dim.dim_attr_schema_filter` 中删除 `scope_level='l2'` 的行（INSERT 空值覆盖，或直接在 seed CSV 删行后重载）
2. **新增 L3 schema 行**：INSERT `scope_level='l3', scope_code='<l3_code>'`
3. **删除 L2 extract rule**：从 `dim_attr_extract_rule_filter` 删除旧 L2 规则
4. **新增 L3 extract rule**：`apply_scope_level='l3', apply_scope_code='<l3_code>'`
5. **更新 DDL**：从 `dwd_l2_filter_<L2>.sql` 删除该物理列
6. **更新 build SQL**：从 `INSERT` 列表和 `MAX(CASE WHEN ...)` 中删除该字段

### 4.3 删除字段（L2 + L3 均无保留价值）

同 4.2，但不新增 L3，直接删 schema + rule + DDL 列 + build SQL 引用。

### 4.4 新增字段（探查发现 DK 有有价值参数）

1. 在 seed CSV 新增 `dim_attr_schema_filter` 行（或 INSERT 到 test_dim 表）
2. 新增 `dim_attr_extract_rule_filter` 行（注意 `extract_rule_id` 命名规则：`fil_<l2_abbr>_<attr_abbr>`）
3. 在 DDL 新增物理列（若 L2 级）或在 build SQL ext_attributes 段里会自动包含（若 L3 级）
4. 重建管道验证

---

## 五、管道重建顺序

```
1. 修改 test_dim 规则/schema 表（或 seed CSV 重载）
2. 删除对应 L2 的旧 EAV 行：
   DELETE FROM test_dwd.dwd_component_attr_std_filter
   WHERE id IN (SELECT id FROM test_dwd.dwd_component_class_filter WHERE l2_code='<L2>')
   AND data_source = 'digikey';
3. 重跑 EAV build：build_dwd_component_attr_std_filter.sql
4. 重建宽表 DDL（DROP + CREATE）
5. 重跑 build SQL（INSERT）
6. 重跑品牌门控 + 填充率验收查询
```

> 品牌门控通过（brand_null=0 AND distinct_brand=distinct_brandid）才允许进入 Phase 6。

---

## 六、审计报告格式

参见 `artifacts/filter/qa_audit_report_<l2>_<date>.md`，报告应包含：

```
## 基本概况（行数、L3 分布、品牌门控）
## L2 物理列空值率（填充率表格 + 状态标注）
## L3 ext_attributes 整体覆盖率（按 L3 分组）
## L3 ext_attributes 字段级审计（每个 ext 字段在目标 L3 的填充率 + R/D/X 决策）
## 变更说明 vN（记录本次 schema 变更）
## P 级问题汇总（P0/P1/P2/D/INFO）
## 总体评估与建议后续操作
```

P 级定义：
- **P0**：阻断 Phase 6（品牌门控失败、DDL 缺列）
- **P1**：重要数据质量问题，需本次迭代修复
- **P2**：已知遗留，可下次迭代处理
- **D**：数据源固有缺失，非规则问题，接受并标注
- **INFO**：数据量极薄或其他参考信息

---

## 七、常见坑（from lessons_learned）

| 坑 | 防御 |
|---|---|
| `\xa0`（非断空格）混入 source_expr | 用 `repr()` 打印 key 名确认；插入时用 `\xa0` 字面量 |
| StarRocks 不支持 UPDATE | 用 INSERT 同主键覆盖 |
| pymysql regex 反斜杠丢失 | 用 raw string `r'([\d.]+)'` 传参 |
| 品牌 INSERT 覆盖原有行 | `dim_std_brand` 是 PRIMARY KEY 表，同 brand_id_std 只能有一行；加别名用 `related_words` 数组 |
| `v_std_brand_alias` 生成 key 机制 | VIEW 从 `name`→key, `abbr`→key, `related_words[]`→key 三路 UNION；加新别名只需插/更新 related_words |
| prajson key 探针漏检 prajson2 | 两个字段都要扫，DK 有时只填其中一个 |
| L2 scope 字段被当作 L3 规则写 | `apply_scope_level` 一定要和 `apply_scope_code` 对应 |
