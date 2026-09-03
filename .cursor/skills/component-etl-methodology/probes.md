# 配套通用探针（SQL 模板，直接在 mysql 客户端执行）

> 本文件是 [SKILL.md](SKILL.md) 的横向参考之一。探针是**可复用的 SQL 片段**，不依赖外部脚本。将对应模板中的占位符替换后粘贴到 StarRocks 客户端执行即可。
> 占位符语义见 [SKILL.md §二-A.D 占位符约定](SKILL.md#二a源适配层与多源接入方法论的通用前提)。

---

## 8.1 空值率扫描（对应阶段 5.5.1 / 5 / 7）

用于每张 L2 宽表的逐列空值率统计，同时验证品牌门控。

```sql
-- 空值率扫描模板（StarRocks）
-- 替换：<DWD_SCHEMA>（test_dwd 或 dwd）、<L2_TABLE>
-- 物理列清单：先 SHOW COLUMNS FROM <DWD_SCHEMA>.<L2_TABLE>，再按列名逐行补充 CASE
SELECT
  COUNT(*)                                                                       AS total_rows,
  ROUND(SUM(CASE WHEN mpn           IS NULL THEN 1 ELSE 0 END)*100.0/COUNT(*),2) AS mpn_null_pct,
  ROUND(SUM(CASE WHEN brand         IS NULL THEN 1 ELSE 0 END)*100.0/COUNT(*),2) AS brand_null_pct,
  ROUND(SUM(CASE WHEN brandid       IS NULL THEN 1 ELSE 0 END)*100.0/COUNT(*),2) AS brandid_null_pct,
  ROUND(SUM(CASE WHEN l3_code       IS NULL THEN 1 ELSE 0 END)*100.0/COUNT(*),2) AS l3_null_pct,
  -- ↓ 按 dim_attr_schema 对应 L2 的 std_attr_code 列表续写，每列一行
  -- ROUND(SUM(CASE WHEN resistance_ohm IS NULL THEN 1 ELSE 0 END)*100.0/COUNT(*),2) AS resistance_null_pct,
  COUNT(DISTINCT brand)   AS distinct_brand,
  COUNT(DISTINCT brandid) AS distinct_brandid
FROM <DWD_SCHEMA>.<L2_TABLE>;
-- 品牌门控验收（两条都必须满足方可进入阶段 6）：
--   brand_null_pct = 0
--   distinct_brand = distinct_brandid
```

---

## 8.2 分层抽样（对应阶段 1 / 5.2 / 7）

按品牌分层，每品牌最多 N 条，用于人眼审阅源端参数杂乱度。

```sql
-- 分层抽样模板（StarRocks，源无关）
-- 替换：<SRC_PARAM_TABLE>（如 dwd.dwd_icpdf_component_param / dwd.dwd_digikey_component_param）
-- 替换：<FILTER_COND>（按本源的字段写过滤条件）、<N>（建议 5）
WITH ranked AS (
  SELECT *,
    ROW_NUMBER() OVER (PARTITION BY brandshort ORDER BY id) AS rn
  FROM <SRC_PARAM_TABLE>
  WHERE <FILTER_COND>
  -- icpdf 示例：category2 LIKE '%晶体管%' AND prajson2 IS NOT NULL
  -- digikey 示例：category LIKE '%transistor%'
)
SELECT * FROM ranked
WHERE rn <= <N>
ORDER BY brandshort, id;
```

人眼审阅重点：同一参数的写法变体（单位、大小写、全角/半角）、复合字段（值+单位混写）、乱码。

---

## 8.3 源-schema gap 探针（对应阶段 5.5.2）

找出**本源**高频出现但尚无抽取规则覆盖的键，用于发现 P0/P1 级规则缺口。

> 不同源的"键空间"不同——半结构 JSON 源用 `json_keys()` 展开，平铺 KV 源用 `SELECT DISTINCT key`。下面给出两种范式：

**范式 A：半结构 JSON 源（icpdf prajson2 / 类似形态）**

```sql
-- 替换：<SRC_PARAM_TABLE>（如 dwd.dwd_icpdf_component_param）
-- 替换：<SRC_SEMI_JSON>（如 prajson2）、<SOURCE>（如 icpdf）
-- 替换：<SRC_KIND_KEY_EQ>（如 prajson2_key_eq）、<L1>、<MIN_HITS>（建议 50）
WITH src_keys AS (
  SELECT k, COUNT(DISTINCT p.id) AS hit_cnt
  FROM <SRC_PARAM_TABLE> p,
       UNNEST(CAST(json_keys(p.<SRC_SEMI_JSON>) AS ARRAY<VARCHAR(256)>)) AS u(k)
  WHERE p.<SRC_SEMI_JSON> IS NOT NULL
  GROUP BY k
  HAVING COUNT(DISTINCT p.id) >= <MIN_HITS>
),
covered AS (
  SELECT DISTINCT source_expr AS covered_key
  FROM dim.dim_attr_extract_rule
  WHERE l1_code     = '<L1>'
    AND data_source = '<SOURCE>'
    AND source_kind = '<SRC_KIND_KEY_EQ>'
)
SELECT s.k AS uncovered_key, s.hit_cnt,
       ROUND(s.hit_cnt * 100.0 /
             (SELECT COUNT(DISTINCT id) FROM <SRC_PARAM_TABLE>), 2) AS hit_rate_pct
FROM src_keys s LEFT JOIN covered c ON s.k = c.covered_key
WHERE c.covered_key IS NULL
ORDER BY s.hit_cnt DESC;
```

**范式 B：平铺 KV 源（digikey 参数表 / 类似形态）**

```sql
-- 假设源参数表是平铺三元组 (id, param_name, param_value)
-- 替换：<SRC_PARAM_TABLE>、<SOURCE>（如 digikey）、<SRC_KIND_KEY_EQ>（如 digikey_param_kv_eq）
-- 替换：<L1>、<MIN_HITS>
WITH src_keys AS (
  SELECT param_name AS k, COUNT(DISTINCT id) AS hit_cnt
  FROM <SRC_PARAM_TABLE>
  WHERE param_name IS NOT NULL
  GROUP BY param_name
  HAVING COUNT(DISTINCT id) >= <MIN_HITS>
),
covered AS (
  SELECT DISTINCT source_expr AS covered_key
  FROM dim.dim_attr_extract_rule
  WHERE l1_code     = '<L1>'
    AND data_source = '<SOURCE>'
    AND source_kind = '<SRC_KIND_KEY_EQ>'
)
SELECT s.k AS uncovered_key, s.hit_cnt,
       ROUND(s.hit_cnt * 100.0 /
             (SELECT COUNT(DISTINCT id) FROM <SRC_PARAM_TABLE>), 2) AS hit_rate_pct
FROM src_keys s LEFT JOIN covered c ON s.k = c.covered_key
WHERE c.covered_key IS NULL
ORDER BY s.hit_cnt DESC;
```

**结果分级（两种范式相同）**：P0 = schema 已有该 std_attr_code 只缺一条路由规则；P1 = 高频但 schema 尚未登记；P2 = 低频边缘。
