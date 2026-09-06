# 阶段 4 · 宽表透视 + 品牌门控 + EAV 接线验证

> **本阶段一句话**：按 L2 拆宽表，把 EAV 窄表透视成业务可消费的形态，品牌标准化做硬门控。
> 占工期：约 5%（**短但密集**，是连接 dim 与下游消费的关键一步）。

---

## 4.1 宽表设计原则

### 4.1.1 一个 L2 一张宽表

- **不要**按 L1 做一张超大表 → 列太多、稀疏度高、查询性能差
- **不要**按 L3 做多张表 → 表太多，下游消费要 UNION
- **正确**：按 L2 拆，每张表的物理列 = 该 L2 公共属性集合

### 4.1.2 列结构（权威基准见 widetable_conventions.md §六-B）

> **唯一权威**：宽表的标准头部 8 列 + 标准尾部 7 列、PK、类型约束全部以 **`widetable_conventions.md §六-B「公共列规范」`** 为准（基准表 `dwd_l2_resistor_fixed_resistor`）。本节只给"一张 L2 宽表 = 三段"的骨架，**不重复列定义**，避免与基准漂移。

| 段 | 内容 | 来源 |
|----|------|------|
| **标准头部（8 列，顺序固定）** | `data_source, id, mpn, brand, brandid, l1_code, l2_code, l3_code` | widetable_conventions.md §六-B |
| **L2 公共物理列** | 该 L2 的所有 `std_attr_code`（`scope_level=l2`），含封装区块 `package_case` / `mounting_style` / `pkg_*_mm`（见 widetable_conventions.md §六-A2） | `dim_attr_schema` |
| **标准尾部（7 列，顺序固定）** | `ext_attributes, semantic_tags, dq_score, dq_flags, source_id, create_at, update_at` | widetable_conventions.md §六-B |

**注意（与旧约定的差异）**：

- `brandshort`、`mpncodes`、`l3_id` **不是宽表物理列**——`brandshort` 只在 build SQL 的源表 JOIN 时用于品牌标准化，不落表；分类信息物理列只有 `l1_code/l2_code/l3_code`（无 `l3_id`）。
- `manufacturer` 若为该 L2 的 std_attr_code 则作 L2 物理列，**仅来自 EAV，不 COALESCE 兜底**。

### 4.1.3 列类型与列宽（强制）

> 头/尾公共列类型见 widetable_conventions.md §六-B；下表只列 L2 专有属性列的取型原则。

| 列 | 必须的类型 / 宽度 | 理由 |
|----|--------------------|------|
| 数值型属性 | `DOUBLE`，**不要用 DECIMAL** | DECIMAL 精度限制可能导致精度截断 |
| 枚举型属性 | `VARCHAR(64)` | 足够容纳所有枚举值（受控词表见 `tmp_attr_enum`，不写进 DDL） |

---

## 4.2 build SQL 编写规则

### 4.2.1 数据来源

- **行**：`dwd.dwd_component_class` 的本 L2 物料（按 `data_source` 区分多源）
- **列**：从 `dwd.dwd_component_attr_std`（EAV 窄表）按 `std_attr_code` 透视

### 4.2.2 透视方式（多源 = 每源一段 SELECT，UNION 进同一张 L2 宽表）

```sql
-- 模板：按本源参数表 <SRC_PARAM_TABLE> JOIN，写出一段 SELECT
-- 多源时，对每个 <SOURCE> 各写一段，最后 INSERT INTO <L2 宽表> ... SELECT ... UNION ALL SELECT ...
-- 占位符替换见 SKILL.md §二-A.D
SELECT
  -- 标准头部 8 列（顺序固定，见 widetable_conventions.md §六-B）；brandshort 只用于 JOIN，不作输出列
  c.data_source, c.id, c.mpn,
  COALESCE(a.canonical_name, p.brandshort) AS brand,   -- 品牌标准化
  a.canonical_id                           AS brandid,
  c.l1_code, c.l2_code, c.l3_code,
  -- L2 物理列（按 std_attr_code 透视）；manufacturer 若是本 L2 属性也在此，仅来自 EAV
  MAX(CASE WHEN s.std_attr_code='capacitance_f'    THEN s.value_std_double  END) AS capacitance_f,
  MAX(CASE WHEN s.std_attr_code='voltage_rated_v'  THEN s.value_std_double  END) AS voltage_rated_v,
  MAX(CASE WHEN s.std_attr_code='package_case'     THEN s.value_std_varchar END) AS package_case,
  MAX(CASE WHEN s.std_attr_code='mounting_style'   THEN s.value_std_varchar END) AS mounting_style,
  -- ... 其它 L2 列
  MAX(CASE WHEN s.std_attr_code='manufacturer'     THEN s.value_std_varchar END) AS manufacturer,
  -- 标准尾部 7 列（顺序固定，见 widetable_conventions.md §六-B）
  json_object_agg(                                     -- ext_attributes：L3 专有聚合成 JSON
    CASE WHEN s.scope_level='l3' THEN s.std_attr_code END,
    CASE WHEN s.scope_level='l3' THEN COALESCE(s.value_std_varchar, CAST(s.value_std_double AS VARCHAR)) END
  ) AS ext_attributes,
  CAST(NULL AS JSON)   AS semantic_tags,
  CAST(NULL AS DOUBLE) AS dq_score,
  CAST(NULL AS JSON)   AS dq_flags,
  c.id                 AS source_id,
  NOW()                AS create_at,
  NOW()                AS update_at
FROM dwd.dwd_component_class c
JOIN <SRC_PARAM_TABLE> p
     ON p.id = c.id AND c.data_source = '<SOURCE>'   -- ← 多源关键：JOIN 时按源隔离
LEFT JOIN dwd.dwd_component_attr_std s
     ON s.id = c.id AND s.data_source = c.data_source
LEFT JOIN dim.v_std_brand_alias a ON a.alias = p.brandshort
WHERE c.l1_code = '<l1>' AND c.l2_code = '<l2_code>'
  AND c.data_source = '<SOURCE>'
  AND c.l3_code NOT LIKE '%_unclassified'    -- ★ 强制过滤
GROUP BY c.data_source, c.id, c.mpn, c.l1_code, c.l2_code, c.l3_code,
         a.canonical_name, a.canonical_id;
```

> **icpdf 示例**：`<SRC_PARAM_TABLE>` = `dwd.dwd_icpdf_component_param`，`<SOURCE>` = `'icpdf'`。
> **digikey 示例**：`<SRC_PARAM_TABLE>` = `dwd.dwd_digikey_component_param`，`<SOURCE>` = `'digikey'`。
> 实际项目里这两段拼在同一份 `build_dwd_l2_<l1>_<l2>.sql` 里，靠 UNION ALL 串起来；新接入一个源就追加一段。

### 4.2.3 强制约束

| 约束 | 体现在 SQL 哪 | 违反后果 |
|------|---------------|---------|
| 过滤 `_unclassified` | `WHERE c.l3_code NOT LIKE '%_unclassified'` | 分类未定的物料污染业务宽表 |
| 品牌标准化 | `COALESCE(a.canonical_name, p.brandshort) AS brand` | brand_null > 0，门控失败 |
| `manufacturer` 不 COALESCE | `MAX(CASE ... 'manufacturer')` 单独取 | 同品牌多制造商会被错误合并 |
| 数值列用 `MAX(CASE ...)` 而非 `SUM` | 透视聚合函数 | SUM 会把多源择优搞成相加 |

---

## 4.3 品牌标准化硬门控

### 4.3.1 两条门控指标

| 指标 | 要求 | 含义 |
|------|------|------|
| `brand_null = 0` | 无一行品牌为空 | `brand` 列对所有有 `brandshort` 的物料都必须有标准化后的品牌名 |
| `COUNT(DISTINCT brand) = COUNT(DISTINCT brandid)` | 品牌名与品牌 ID 一一对应 | 不同 `brandid` 对应同一 `canonical_name` 说明字典有分裂 |

### 4.3.2 验证 SQL

```sql
SELECT COUNT(*) AS total,
       SUM(CASE WHEN brand IS NULL THEN 1 ELSE 0 END) AS brand_null,
       COUNT(DISTINCT brand) AS dt,
       COUNT(DISTINCT brandid) AS di
FROM test_dwd.dwd_l2_<l1>_<l2_code>;
-- 要求：brand_null=0, dt=di
```

### 4.3.3 修复路径

如果 `brand_null > 0`：

```sql
-- 找出未覆盖的 brandshort（多源时每个源各跑一次）
-- 替换 <SRC_PARAM_TABLE> 和 <SOURCE>，参考 SKILL §二-A.D
SELECT p.brandshort, COUNT(*) AS n
FROM test_dwd.dwd_l2_<l1>_<l2_code> w
JOIN <SRC_PARAM_TABLE> p ON p.id = w.id AND w.data_source = '<SOURCE>'
LEFT JOIN dim.v_std_brand_alias a ON a.alias = p.brandshort
WHERE w.brand IS NULL AND a.alias IS NULL
GROUP BY p.brandshort ORDER BY n DESC LIMIT 50;
```

把高频未覆盖品牌补到 `dim.dim_std_brand` 或 `v_std_brand_alias` 即可（沙盒期写 `test_dim` 对应后缀表，合并时随 dim 一起入 prod）。

如果 `dt != di`：

```sql
-- 找出同一品牌名对应多个 brandid
SELECT brand, COUNT(DISTINCT brandid) AS ids, GROUP_CONCAT(DISTINCT brandid)
FROM test_dwd.dwd_l2_<l1>_<l2_code>
WHERE brand IS NOT NULL
GROUP BY brand HAVING COUNT(DISTINCT brandid) > 1;

-- 反过来：同一 brandid 对应多个品牌名
SELECT brandid, COUNT(DISTINCT brand) AS names, GROUP_CONCAT(DISTINCT brand)
FROM test_dwd.dwd_l2_<l1>_<l2_code>
WHERE brandid IS NOT NULL
GROUP BY brandid HAVING COUNT(DISTINCT brand) > 1;
```

修字典直到两条门控都过。

---

## 4.4 入仓前置：EAV 接线验证（必查）

**这是阶段 4 最容易踩的坑**：build SQL 写得没问题，跑出来宽表是空的，原因是 EAV 引擎和分类结果表对不上号。

### 4.4.1 分类结果表是哪张

```sql
-- 通用 EAV 引擎一般 JOIN 这张
SELECT l1_code, COUNT(*) FROM dwd.dwd_component_class GROUP BY l1_code;
-- 如果新品类在沙盒表，会是：
SELECT l1_code, COUNT(*) FROM test_dwd.dwd_component_class_<l1> GROUP BY l1_code;
```

**高频坑**：

- 新品类分类结果在 `test_dwd.dwd_component_class_<l1>`（沙盒）
- 通用 EAV 引擎 JOIN `dwd.dwd_component_class`（正式）
- 引擎不报错，EAV 结果静默为空

**解决**：

- 试错期：临时修改 EAV 引擎 SQL，让它 JOIN 沙盒分类表
- 或：先把分类结果合并到正式表，再跑 EAV
- **第二种更稳**，因为 EAV 引擎是通用基础设施，不应该为某品类临时改

### 4.4.2 EAV 结果行数验证

跑完 EAV 引擎后立刻查行数：

```sql
SELECT l1_code, l2_code, l3_code, COUNT(*) AS rows_in_eav, COUNT(DISTINCT id) AS distinct_mpn
FROM dwd.dwd_component_attr_std
WHERE l1_code = '<l1>'
GROUP BY l1_code, l2_code, l3_code
ORDER BY rows_in_eav DESC;
```

- 行数为 0 → JOIN 链路有问题，必须追查
- 行数远小于预期（如分类结果有 10000 物料但 EAV 只有 100 行）→ 抽取规则可能基本没命中

### 4.4.3 规则命中率抽查

随机抽 5 条 `enabled=1` 的 extract_rule，确认每条在 EAV 窄表中都有对应命中：

```sql
SELECT extract_rule_id, std_attr_code, COUNT(*) AS hits
FROM dwd.dwd_component_attr_std
WHERE l1_code = '<l1>'
  AND extract_rule_id IN (
    SELECT extract_rule_id FROM dim.dim_attr_extract_rule
    WHERE l1_code = '<l1>' AND enabled = 1
    ORDER BY rand() LIMIT 5
  )
GROUP BY extract_rule_id, std_attr_code;
```

每条 `hits` 都应该 > 0（除非该规则对应的源端字段确实非常稀疏）。

---

## 4.5 test 环境的额外注意事项

### 4.5.1 `dim.` 视图保留指向 prod

`test_dim` **没有** `v_std_brand_alias` 视图（这是品牌字典的标准化视图，统一只在 prod 维护）。

L2 build 在 test 环境跑时，sed 替换规则**只替换 dwd 表名**：

```bash
# 正确（只替换 dwd.* 而保留 dim.*）
sed -e 's|dwd\.dwd_l2_|test_dwd.dwd_l2_|g' \
    -e 's|dwd\.dwd_component_attr_std|test_dwd.dwd_component_attr_std|g' \
    build_dwd_l2_<l1>_<l2_code>.sql

# 反模式（不要做）
sed -e 's|dwd\.|test_dwd.|g' \
    -e 's|dim\.|test_dim.|g' \    # ★ 这一行会把 dim.v_std_brand_alias 替错
    build_dwd_l2_<l1>_<l2_code>.sql
```

### 4.5.2 DDL 执行要指定数据库

生成的 DDL 文件如果没有 `USE test_dwd;`，必须用 `mysql -D test_dwd` 执行：

```bash
mysql -h $MYSQL_HOST -P $MYSQL_PORT -u $MYSQL_USER -p$MYSQL_PASSWORD \
  -D test_dwd \
  < sql_scripts/2.attribute_standard/dwd_l2_<l1>_<l2_code>.sql
```

不指定的话会报 `No database selected`。

---

## 4.6 产物清单

| 产物 | 落到哪里 |
|------|---------|
| L2 宽表建表 DDL | `sql_scripts/2.attribute_standard/dwd_l2_<l1>_<l2_code>.sql` |
| L2 宽表 build SQL | `sql_scripts/2.attribute_standard/build_dwd_l2_<l1>_<l2_code>.sql` |
| EAV 行数验证报告 | `artifacts/<l1>/eav_rowcount_<date>.tsv` |
| 品牌门控验证 | `artifacts/<l1>/brand_gate_<date>.tsv` |
| 未覆盖品牌字典缺口 | `artifacts/<l1>/brand_dict_gaps_<date>.tsv`（可选） |

---

## 4.7 反模式

| 反模式 | 后果 |
|--------|------|
| build SQL 不过滤 `_unclassified` | 未分类物料污染业务宽表 |
| `brand` 列宽 VARCHAR(128) | 标准化后品牌全称可能超过 128 字符，静默截断 |
| `manufacturer` 加 COALESCE 兜底到品牌 | 同品牌多制造商被错误合并 |
| 不验证 EAV 接线就跑 build | 宽表静默为空，定位耗时 |
| sed 全替换 `dim.` 到 `test_dim.` | test_dim 没有 `v_std_brand_alias`，build 报错 |
| 品牌门控不过仍然进入阶段 5 | 后期发现要返工字典，所有 L2 宽表都要重跑 |
| 数值列用 SUM 透视 | 多源择优变成相加，数据严重错误 |

---

## 4.8 完成判定

```
☐ 每张 L2 宽表 brand_null = 0
☐ 每张 L2 宽表 dt = di
☐ EAV 窄表非空，且至少 5 条 extract_rule 抽查命中
☐ 宽表行数 ≈ 分类结果中该 L1 的非 _unclassified 物料数
☐ ext_attributes 字段非全空（L3 属性至少有部分命中）
```

完成判定通过后，进入阶段 5 的双回路迭代。
