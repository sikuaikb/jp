# 字段决策详细指南

## A. L2 公共字段决策流程

> **核心原则**：选型价值是去留的第一判据，不是数据有没有。

```
L2 字段填充率低或 0%
  │
  Step 1【技术核查】prajson / prajson2 里有没有这个 key？
  │
  ├─ 有 key 但 0% → 抽取规则有问题
  │     └─ source_expr 写错 / 有 \xa0 / regex 不匹配 → R（规则错误）→ 修复
  │
  └─ 确认无 key → Step 2
  │
  Step 2【业务核查】这个字段对选型有没有价值？
  │   问：买家会用这个字段过滤/比较产品吗？
  │   问：规格书/选型指南会标注这个参数吗？
  │   问：不同产品间这个参数差异大、影响选型吗？
  │
  ├─ 无价值 → X（删除）
  │     无论 DK / 其他源有无数据，都删
  │     例：LC 滤波器的 aec_q_level（工业品类无此需求）
  │
  └─ 有价值 → Step 3
  │
  Step 3【数据分布 + 三问法】（运行 _l2_field_by_l3 探针）
  │
  ├─ 只有特定 L3 子类有值（其他 L3 ≈ 0%）
  │    │
  │    │  ⚠️ 不能直接下放！先问（三问法）：
  │    │  Q1. 该字段对 L2 下所有 L3 子类的选型决策是否都有意义？
  │    │  Q2. 行业惯例/器件手册里，其他 L3 子类应具备这个参数吗？
  │    │  Q3. 其他 L3 的空值是「DK 未填」还是「该类器件本来就没有」？
  │    │
  │    ├─ 三问中 ≥2 个支持"L2 通用" → D（数据源缺口）→ 保留 L2 字段
  │    │    例：isolation_voltage_v 对所有变压器物理上都有意义，
  │    │        DK 只对 audio 填写 = 数据源缺口，不代表 pulse 没有
  │    │
  │    └─ 三问中 ≥2 个支持"L3 特有" → F（下放 L3）→ 移到 L3 ext_attributes
  │         例：freq_range_raw 是 audio 专属的频率范围，
  │             pulse 用其他参数（带宽、伏秒积）表达，概念不同
  │
  └─ L2 下所有子类都没数据 → D（数据源缺失）→ 保留字段，标注"DK 无此数据"
```

---

## B. L3 专属字段（ext_attributes）决策流程

**触发时机**：§2.4 中某个 L3 专属字段，在其目标 L3 内填充率 = 0% 或极低（< 5%）。

```
L3 ext 字段，在目标 L3 内填充率 ≈ 0%
  │
  Step 1【技术核查】
  │   - prajson 里有没有该字段的 key？
  │   - apply_scope_code 是否等于该 L3 的 code？
  │   - source_expr / regex 有没有写错？
  │
  ├─ 有 key 但 0%，或 apply_scope_code 写错
  │     → R（规则错误）→ 修复 extract rule，重跑 EAV，重新评估
  │
  └─ key 确实不存在，规则本身没问题 → Step 2
  │
  Step 2【业务核查】这个字段对该 L3 子类的选型有意义吗？
  │   问：该 L3 子类的规格书/选型表里会标注这个参数吗？
  │   问：买家在选择该 L3 产品时会用这个参数做决策吗？
  │   问：DK 对该 L3 的竞品也没有这个参数（系统性未填），
  │        还是只是这批数据碰巧没有？
  │
  ├─ 无意义（该 L3 根本没有这个概念，或选型时不使用）
  │     → X（删除）→ 从 dim_attr_schema + dim_attr_extract_rule 删除
  │     例：给 pulse_transformer 设计了 frequency_response_raw，
  │         但 pulse 产品根本不用频响曲线来选型
  │
  └─ 有意义但 DK 对该 L3 未填
        → D（数据源缺口）→ 保留字段，在审计报告标注
        例：certification_body 对 audio L3 有意义（有 UL/CE 等认证区别），
            但 DK 对这批 audio 产品未标注，期待 icpdf 补充
```

### L3 字段决策速查

| 目标 L3 填充率 | 规则是否正确 | 选型意义 | 决策 |
|---|---|---|---|
| 0% | 规则有误（scope/expr 错） | — | **R** 修规则，重跑 |
| 0% | 规则正确，DK 无 key | 无意义 | **X** 删除字段 |
| 0% | 规则正确，DK 无 key | 有意义 | **D** 保留，标数据源缺口 |
| 正常（> 10%） | — | — | 抽样验收确认值正确 |

## 选型价值判断参考

**高选型价值（保留）**：
- 频率类：截止频率、中心频率、带宽——买家首要筛选条件
- 损耗类：插入损耗、带外抑制——直接影响滤波性能
- 电气极限：额定电流、额定电压、功率容量
- 封装/尺寸：PCB 布局必须参数

**低或无选型价值（考虑删除）**：
- 该品类几乎固定不变的参数（如腔体滤波器阻抗 = 固定 50Ω，标不标都知道）
- 认证等级（如 `aec_q_level`）在消费/工业类滤波器中无意义
- DK 和其他主流源均不提供、且行业规格书也不标注的参数

## 分 L3 的 L2 字段填充率脚本（_l2_field_by_l3）

```python
# 按 L3 分组统计某 L2 字段的 EAV 填充率
cur.execute(f"""
    SELECT c.l3_code, COUNT(*) AS total,
           SUM(CASE WHEN e.value_std_double IS NOT NULL
                      OR e.value_std_varchar IS NOT NULL THEN 1 ELSE 0 END) AS has_val
    FROM test_dwd.dwd_component_class_filter c
    LEFT JOIN test_dwd.dwd_component_attr_std_filter e
           ON e.id = c.id AND e.data_source = c.data_source
          AND e.std_attr_code = '{attr_code}'
    WHERE c.l2_code = '{l2_code}'
    GROUP BY c.l3_code
    ORDER BY has_val DESC
""")
```

结果：若某 L3 填充率 > 80%，其他 L3 ≈ 0% → 下放 L3。

## L2 vs L3 字段归属判定原则

- **L2 字段**：对该 L2 下所有 L3 子类均普遍存在（DK 覆盖率 > 30%）
- **L3 字段**：只在特定 L3 子类有意义或有数据
- **删除**：DK 完全无数据，且其他主流源（lcsc、mouser）也无此参数，对选型帮助极低

## value_map 处理占位符

DK 某些字段有无信息占位符（如 `可根据要求提供 REACH 信息`），应映射到 NULL：

```csv
extract_rule_id: fil_p_reach
value_map: {"可根据要求提供 REACH 信息":""}
```

空字符串 `""` 在引擎中转为 NULL。

## 复杂 value 提取 regex 模式

| 场景 | value 样例 | regex |
|---|---|---|
| 带单位数值 | `4dB` | `([\d.]+)\s*dB` |
| 带频率注释 | `25dB（+50MHz）33dB（-50MHz）` | `([\d.]+)dB`（取首值） |
| 带单位换算 | `1.2 kOhms @ 100 MHz` | `([\d.]+)\s*kOhms?\s*@\s*100\s*MHz`（×1000） |
| 纯数值 | `0.5dB` | `([\d.]+)` |
| 多频点取 100MHz | `500 Ohms @ 100 MHz` | `([\d.]+)\s*Ohms?\s*@\s*100\s*MHz` |

> **单位换算**：若 DK 返回 kΩ 但 schema 存 Ω，须在 build SQL 或 EAV 引擎里做 ×1000，或在 `source_value_unit_std` 标注 kΩ 触发引擎换算。

<a name="brand-alias"></a>
## 品牌别名修复

### 诊断

```python
# 找 brandid=NULL 的品牌
cur.execute("""
    SELECT DISTINCT p.brandshort, UPPER(TRIM(p.brandshort)) AS lookup_key
    FROM test_dwd.dwd_component_class_filter c
    JOIN dwd.dwd_digikey_component_param p ON p.id = c.id
    WHERE c.l2_code = '<L2>'
      AND NOT EXISTS (
          SELECT 1 FROM test_dim.v_std_brand_alias a
          WHERE a.brand_key = UPPER(TRIM(p.brandshort))
      )
""")
```

### v_std_brand_alias 生成机制

VIEW 从 `test_dim.dim_std_brand` 三路生成 brand_key：
1. `name` → `UPPER(TRIM(name))`
2. `abbr` → `UPPER(TRIM(abbr))`
3. `related_words[]` → 每个元素 `UPPER(TRIM(rw))`

### 修复方式

**情况 A：品牌已在 dim_std_brand，但 brand_key 不匹配**（如 `Toko America Inc.` 需要映射到已有 `东光-TOKO`）

在现有行的 `related_words` 中追加新 key（INSERT 覆盖整行）：

```python
cur.execute("""
    INSERT INTO test_dim.dim_std_brand
    (brand_id_std, name, brand_zh, brand_en, abbr, related_words,
     logo, state, official_website, level, type, source)
    VALUES (%s, %s, %s, %s, %s, %s, '', 1, '', 1, 1, 'filter_<l2>_fix')
""", (existing_brand_id_std, canonical_name, brand_zh, brand_en, abbr,
      ['ALIAS1', 'ALIAS2', 'NEW BRAND NAME']))
```

> ⚠️ `dim_std_brand` 以 `brand_id_std` 为 PRIMARY KEY，INSERT 同 id 会覆盖整行。必须保留原有 `name`/`abbr` 的值，仅在 `related_words` 追加新 key。

**情况 B：品牌完全不在字典（全新品牌）**

分配新 ID（取 `MAX(brand_id_std) + 1`），INSERT 新行：

```python
cur.execute("SELECT MAX(brand_id_std) AS max_id FROM test_dim.dim_std_brand")
next_id = cur.fetchone()['max_id'] + 1
cur.execute("""
    INSERT INTO test_dim.dim_std_brand
    (brand_id_std, name, brand_zh, brand_en, abbr, related_words,
     logo, state, official_website, level, type, source)
    VALUES (%s, %s, '', %s, %s, %s, '', 1, '', 1, 1, 'filter_<l2>_fix')
""", (next_id, canonical_name, brand_en, abbr_short, ['ALIAS1', 'ALIAS2']))
```

### 重建验证

```python
# 验证 v_std_brand_alias 更新
cur.execute("""
    SELECT brand_key, canonical_name, brand_id_std, alias_kind
    FROM test_dim.v_std_brand_alias
    WHERE brand_key LIKE '%<BRAND>%'
""")
# 然后重建宽表，再次运行品牌门控查询
```

## 审计脚本模板

完整审计脚本参考 `sql_scripts/test/filter/phase55_audit_analog_dc.py`，主要模块：

```python
# 1. 品牌门控
# 2. L2 物理列空值率（DESCRIBE 获取列名，逐列 COUNT）
# 3. ext_attributes 覆盖率
# 4. prajson key 频率 vs. dim_attr_extract_rule gap
# 5. prajson2 key 频率（补充探查）
```

可将 L2 名称参数化，对多个 L2 批量执行。
