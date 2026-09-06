# 阶段 5.5 · 测试宽表数据质量审计

> **本阶段一句话**：测试机器指标（brand_null、行数）通过 ≠ 测试通过；必须独立做一遍空值率扫描 / schema gap / 单位抽样 / 复验，产出**业务可读**的审计报告。
> **位置**：阶段 5 双回路收敛后、阶段 6 合并发布之前的**强制独立阶段**。
> 占工期：约 10%。
>
> ⚠️ **本阶段是阶段 6 的硬前置：没有审计报告 → 不进入合并发布**。

---

## 5.5.0 为什么这一阶段必须存在

没有这一阶段的典型事故：

> 测试 `brand_null = 0`、`dt = di`、行数对得上 → 看上去测试通过 → 发到 prod →
> 下游消费时才发现某关键属性大面积 NULL，或者源里明明有的字段被 schema 完全忽略，
> 或者单位识别错把字节当 KB → 已经发布的数据要回滚 → 业务方失去信任。

机器侧"看起来通过"和**真正数据可用**之间的 gap，靠这一阶段填上。

---

## 5.5.1 L2 物理列空值率扫描

### 执行方式

对**每张测试 L2 宽表**，逐列统计空值率（使用 [probes.md §8.1 空值率扫描模板](../probes.md)）：

```sql
-- 替换 <DWD_SCHEMA>（test_dwd）、<L2_TABLE>（dwd_l2_<l1>_<l2_code>）
-- 按 SHOW COLUMNS FROM <DWD_SCHEMA>.<L2_TABLE> 的结果补全 CASE 列表
SELECT
  COUNT(*) AS total_rows,
  ROUND(SUM(CASE WHEN mpn     IS NULL THEN 1 ELSE 0 END)*100.0/COUNT(*),2) AS mpn_null_pct,
  ROUND(SUM(CASE WHEN brand   IS NULL THEN 1 ELSE 0 END)*100.0/COUNT(*),2) AS brand_null_pct,
  ROUND(SUM(CASE WHEN brandid IS NULL THEN 1 ELSE 0 END)*100.0/COUNT(*),2) AS brandid_null_pct,
  -- ↓ 续写 dim_attr_schema 对应 L2 的所有 std_attr_code 列
  COUNT(DISTINCT brand)   AS distinct_brand,
  COUNT(DISTINCT brandid) AS distinct_brandid
FROM <DWD_SCHEMA>.<L2_TABLE>;
```

结果导出为 TSV（mysql 客户端 `-B` 参数），保存到 `artifacts/<l1>/null_rates_<l2_code>_<date>.tsv`。

### 分级标准

| 空值率 | 判定 | 处理 |
|--------|------|------|
| 0 ~ 30% | 正常 | 不动 |
| 30 ~ 70% | 关注 | 走 [`decision_guides.md` 空值四段式](../decision_guides.md#2-空值核对的四段式判断) |
| 70%+ | **高危** | 必须排查；很可能漏规则 |
| 修后显著下降 | 良性 | 留痕记入"本轮修复收益" |

### L3 ext_attributes 必须单独统计

**绝不能与 L2 物理列空值率混在一张报表里**。L3 专有属性的分母是该 L3 子类行数：

```sql
-- 单独跑一份 L3 命中率
SELECT
  l3_code, COUNT(*) AS total,
  SUM(CASE WHEN json_extract_string(ext_attributes, '$.<attr>') IS NULL
           THEN 1 ELSE 0 END) AS null_cnt,
  ROUND(100.0 * SUM(CASE WHEN json_extract_string(ext_attributes, '$.<attr>') IS NULL
           THEN 1 ELSE 0 END) / COUNT(*), 2) AS null_pct
FROM dwd.dwd_l2_<l1>_<l2_code>
WHERE l3_code = '<target_l3>'
GROUP BY l3_code;
```

混在一起报表的后果：「非该 L3 的物料的正常 NULL」会淹没真正的数据质量问题，看起来空值率 90% 但其实业务正常。

---

## 5.5.2 源数据-schema gap 探查

### 执行方式

使用 [probes.md §8.3 schema gap 探针模板](../probes.md)，替换 `<L1>` 和 `<MIN_HITS>`（建议 50）后直接在 StarRocks 客户端执行：

```sql
-- 完整模板见 probes.md §8.3；此处列出输出列说明
-- 输出列：uncovered_key, hit_cnt, hit_rate_pct
-- covered_in_dim 逻辑：LEFT JOIN dim.dim_attr_extract_rule WHERE source_kind='prajson2_key_eq'
-- hit_rate_pct = hit_cnt / 全表 DISTINCT id
```

结果导出为 TSV，保存到 `artifacts/<l1>/schema_gap_<date>.tsv`。

### 分级处理

| 级别 | 含义 | 行动 | 处理时机 |
|------|------|------|---------|
| **P0** | schema 已有该 std_attr_code，**仅缺一条新 extract_rule 路径** | **本轮内修复并复验** | 立即 |
| **P1** | 高频源端字段、schema 中尚未登记新 std_attr_code，但应在本品类范围内 | 评估是否新增 std_attr_code | 本轮记录、下一品类周期处理 |
| **P2** | 低频或边缘字段 | 仅记录 | 不处理 |

### P0/P1/P2 分级的判断流程

```
新发现 source_key (covered_in_dim=0)
        │
        ├─ 该 key 表达的语义在 dim_attr_schema 里已经有对应的 std_attr_code 吗？
        │     ├─ 有 → P0（写一条 extract_rule 把这个 key 接到已有 std_attr_code）
        │     └─ 无 → 继续
        │
        ├─ 该 key 的命中率 hit_rate 是不是 ≥ 5%？
        │     ├─ 是 → P1（值得新增 std_attr_code 但不在本轮发布范围）
        │     └─ 否 → P2（边缘字段，记录即止）
```

---

## 5.5.3 单位换算合理性抽样

### 为什么需要

单位字典识别不出某个变体 → fall-through → 数据**非 NULL、不超 schema 上下界**，但**数值偏差 1000 倍**。机器检查 100% 通不出来，必须**人眼抽样**。

### 抽样 SQL

```sql
-- 对每个数值型 std_attr_code 都跑一遍
SELECT id, std_attr_code, value_std_double, unit_raw, num_raw, raw_value
FROM dwd.dwd_component_attr_std
WHERE std_attr_code = '<attr>' AND l1_code = '<l1>'
ORDER BY rand() LIMIT 20;
```

### 典型隐性错误清单（必查）

| 错误模式 | 现象 | 如何识别 |
|---------|------|---------|
| **字节 vs KB 混淆** | 源端 `RAM: 1024字节`，单位字典没识别 `字节` → fall-through 当成 KB | 抽样看 num_raw=1024 但 value_std_double=1024*1024 |
| **全角符号** | `μＦ`（全角 F）没被字典覆盖 → 当成 unitless | 出现 value_std_double 比量级高 10^6 |
| **大小写漏覆盖** | `MOHM` 没覆盖、`Mohm` 没覆盖 → 当成欧姆 | value_std_double 比量级低 10^6 |
| **平方根符号** | `√Hz`（噪声密度的单位）字典常漏 → 当成 Hz | 抽样看 raw_value 含 √ 字符 |
| **小数千分位** | 源端写 `1,000pF` （欧美用逗号当千分位）→ regexp 把数字截成 1 | num_raw=1 value=1pF |
| **科学计数法** | 源端 `1.5E-6` 没被 regexp 匹配 → NULL | extract_rule 应支持科学计数法 |
| **范围值** | 源端 `100~200V` → regexp 提取第一个数值 → 全部按 100V 入库 | 抽样看 raw_value 含 ~ 或 - 范围符 |
| **复合单位** | `mA/V`（跨导）拆成 mA 当电流 | value_std_double 量级与该属性预期严重不符 |
| **温度 °C vs K** | 源端 `25°C` vs `298K` 混入同一字段 | 抽样看 raw_value 是否有 K 字样 |
| **时间 ns vs us** | `100ns` 被识别成 us → value_std 偏差 1000 倍 | 该 std_attr_code 期望量级与实际不符 |

### 人眼抽样的判定流程

每条抽样判一个标签：

| 标签 | 含义 |
|------|------|
| `ok` | num_raw / unit_raw / value_std_double 三者关系合理 |
| `unit_unrecognized` | unit_raw 显示源端单位但 value_std_double 等于 num_raw → 单位字典漏覆盖 |
| `magnitude_off` | value_std_double 量级与 std_attr_code 预期差异巨大 |
| `regex_clip` | num_raw 看起来明显被正则截断 |
| `not_a_number` | raw_value 是范围值 / 文本，本来就不该抽出 |

每个标签都有对应修复路径（补单位字典 / 补正则 / 改 extract_rule）。

### 抽查覆盖范围

| L1 类型 | 必抽的 std_attr_code |
|---------|--------------------|
| 电容 | `capacitance_f`, `voltage_rated_v`, `esr_ohm`, `temp_min_c`, `temp_max_c` |
| 电阻 | `resistance_ohm`, `power_rating_w`, `tolerance_pct`, `tcr_ppm_per_c` |
| 电感 | `inductance_h`, `current_rated_a`, `dcr_ohm`, `srf_hz` |
| 晶体管 | `vds_max_v`, `id_max_a`, `rds_on_ohm`, `gate_charge_c`, `power_dissipation_w` |
| MCU/MPU/DSP | `flash_size_b`, `ram_size_b`, `frequency_max_hz`, `voltage_supply_v` |
| 二极管 | `vf_max_v`, `if_avg_a`, `vrm_max_v`, `trr_s` |

**经验**：内存 / 存储类（`*_size_b`）和频率类（`*_hz`）最容易出单位换算错误，优先抽。

---

## 5.5.4 schema 一致性扫描（合并前必跑）

**目的**：在数据已经跑稳之后、合并前，最后扫描一次 schema 本身的一致性问题（命名规范 / 类型分裂）。

> **不变式权威源**：snake_case 规范见 [phases/3_attr_dim.md §3.2.2](3_attr_dim.md)，跨 scope `db_type` 一致性见 [§3.2.3](3_attr_dim.md)；二者已被 `validate_attr_dim.py`（A1 / 跨 scope 类型）静态机械化。本节是**合并前的最后一次人工复扫**，SQL 与 §3.2.2/§3.2.3 等价，仅在不同生命周期节点执行。

### 5.5.4.1 std_attr_code 命名扫描

```sql
-- 违反 snake_case 的 std_attr_code
SELECT l1_code, scope_level, scope_code, std_attr_code, db_type
FROM <test_dim or dim>.dim_attr_schema
WHERE std_attr_code REGEXP '[A-Z]'
   OR std_attr_code REGEXP '[^a-z0-9_]'
   OR std_attr_code NOT REGEXP '^[a-z]';
-- 期望 0 行
```

### 5.5.4.2 L2 宽表列名扫描

```sql
SELECT table_schema, table_name, column_name, column_type
FROM information_schema.columns
WHERE table_schema IN ('test_dwd', 'dwd')
  AND table_name LIKE 'dwd_l2_%'
  AND (column_name REGEXP '[A-Z]' OR column_name REGEXP '[^a-z0-9_]');
-- 期望 0 行
```

### 5.5.4.3 跨 L1/scope 类型分裂扫描

```sql
SELECT std_attr_code,
       COUNT(DISTINCT db_type) AS dt_kinds,
       GROUP_CONCAT(DISTINCT db_type) AS db_types,
       GROUP_CONCAT(DISTINCT CONCAT(l1_code,'/',scope_code,'->',db_type)) AS detail
FROM <test_dim or dim>.dim_attr_schema
GROUP BY std_attr_code
HAVING COUNT(DISTINCT db_type) > 1;
-- 期望 0 行
```

### 5.5.4.4 std_attr_code ↔ 物理列类型一致性

```sql
-- schema 说 BOOLEAN，DDL 实际是 VARCHAR：这种偏差最隐蔽，必须扫
SELECT s.l1_code, s.scope_code AS l2_code, s.std_attr_code,
       s.db_type AS schema_type, c.column_type AS ddl_type
FROM <test_dim or dim>.dim_attr_schema s
JOIN information_schema.columns c
  ON c.table_schema = '<test_dwd or dwd>'
 AND c.table_name = CONCAT('dwd_l2_', s.scope_code)
 AND c.column_name = s.std_attr_code
WHERE s.scope_level = 'l2'
  AND s.enabled = 1
  AND (
    (s.db_type = 'BOOLEAN' AND c.column_type NOT IN ('tinyint(1)', 'boolean'))
    OR (s.db_type = 'DOUBLE' AND c.column_type NOT IN ('double', 'double(0)'))
    OR (s.db_type = 'BIGINT' AND c.column_type NOT LIKE 'bigint%')
    OR (s.db_type = 'INT' AND c.column_type NOT LIKE 'int%')
    OR (s.db_type = 'VARCHAR' AND c.column_type NOT LIKE 'varchar%')
    OR (s.db_type = 'JSON' AND c.column_type NOT IN ('json', 'varchar(65533)'))
  );
-- 期望 0 行
```

### 5.5.4.5 三个扫描的判定

```
☐ 命名扫描 = 0 行
☐ L2 列名扫描 = 0 行
☐ 类型分裂扫描 = 0 行
☐ schema ↔ DDL 类型扫描 = 0 行
```

任一不为 0 行 → 不进入阶段 6 合并。修复路径见阶段 3 的[类型升级路径](../phases/3_attr_dim.md#类型升级路径)。

---

## 5.5.5 规则补缺后的强制复验

每补一条 extract_rule，必须按顺序复跑并对比：

```
重跑 prod EAV 引擎 → 重跑该 L2 build → 重新统计该列空值率
                                          │
                          修前 vs 修后 diff（人可读）
```

### 复验三种结局

| 结局 | 含义 | 行动 |
|------|------|------|
| 空值率显著下降 | 规则补对了 | 落入"本轮修复收益"表 |
| 空值率不动 | 规则没命中 / source_kind 写错 | 回到 [`decision_guides.md` 空值第 3 段](../decision_guides.md#2-空值核对的四段式判断) |
| **空值率反而上升** | priority 抢错了高质量路径 | **立即回滚该规则** |

### 复验的最小命令链

```bash
# 1. 直接在 test_dim 改/补一条 extract_rule（沙盒期不经 CSV）
#    UPDATE/INSERT test_dim.dim_attr_extract_rule_<l1>（source_kind / 正则 / value_map / priority ...）

# 2. 重跑 EAV
mysql -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" \
  --default-character-set=utf8mb4 \
  < sql_scripts/2.attribute_standard/build_dwd_component_attr_std_icpdf.sql

# 4. 重跑 L2 build
mysql -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" \
  --default-character-set=utf8mb4 \
  < sql_scripts/2.attribute_standard/build_dwd_l2_<l1>_<l2_code>.sql
```

然后用 [probes.md §8.1 空值率扫描模板](../probes.md) 重跑空值率，将结果保存到 `artifacts/<l1>/null_rates_<l2_code>_after.tsv`，再手工 diff 前后两份 TSV。

---

## 5.5.6 审计报告产出（强制）

每次发布前必须产出**人可读**的审计报告（Markdown / Canvas / TSV），交给业务方阅读。

### 报告必须包含

```markdown
# <L1> 数据质量审计报告 (<date>)

## 1. 总览
- L1: <l1>
- 涉及 L2 宽表：<l2_list>
- 涉及 L3 子类：<l3_list>
- 总物料数：N
- 本轮迭代轮次：<n>

## 2. 每张测试 L2 宽表的指标
| L2 | rows | brand_null | dt | di | 高危列(>70%) | 关注列(30~70%) |
| ... |

## 3. L2 物理列空值率表
（按 null_pct 降序，每张 L2 一节）

## 4. L3 ext_attributes 命中率表
（按 L3 子类分组，分母 = 该 L3 行数）

## 5. 本轮补缺的规则清单
| rule_id | 补的字段 | 涉及 L2/L3 | 修前空值率 | 修后空值率 | 收益 |

## 6. 已发现但未处理的 P1/P2 gap
| source_key | hit_rate | 级别 | 推迟原因 |

## 7. 已发现但无法修复的源端问题
| 现象 | 涉及行数 | 推断原因 | 处理结论 |

## 8. 单位换算抽样结果
| std_attr_code | 抽样数 | ok | 异常种类与数量 |

## 9. 审计结论
- [ ] 通过 / 不通过
- 不通过的原因（如有）
- 建议进入阶段 6 的窗口期
```

### 这份报告就是阶段 6 的"发布门控"输入

业务方 / 数据负责人**阅读 → 签字 → 才能进入合并发布流程**。
不出审计报告 = 不能发布。
出了但没人签字 = 不能发布。

---

## 5.6 产物清单

| 产物 | 落到哪里 |
|------|---------|
| L2 物理列空值率 TSV | `artifacts/<l1>/null_rates_<l2>_<date>.tsv`（每张 L2 一份） |
| L3 命中率 TSV | `artifacts/<l1>/l3_coverage_<l2>_<date>.tsv`（每张 L2 一份） |
| schema gap TSV | `artifacts/<l1>/schema_gap_<date>.tsv` |
| P0/P1/P2 分级表 | `artifacts/<l1>/gap_triage_<date>.tsv` |
| 单位抽样 TSV + 标签 | `artifacts/<l1>/unit_sanity_<date>.tsv` |
| 规则补缺前后 diff | `artifacts/<l1>/patch_diff_<date>.md`（每条 patch 一节） |
| **审计报告** | `artifacts/<l1>/qa_audit_report_<date>.md`（业务侧读这一份） |

---

## 5.7 反模式

| 反模式 | 后果 |
|--------|------|
| 跳过 5.5 直接合并 | 漏抽规则 / schema gap / 单位换算错未被发现 |
| 只看 brand_null + 行数就认为测试通过 | 完全没覆盖 L2 空值率 / 单位 / gap 三类问题 |
| L3 ext_attributes 命中率混进 L2 空值率报表 | "非该 L3 的正常 NULL"淹没真问题 |
| 单位换算只看 ”值非 NULL“ 不做人眼抽样 | 字节当 KB、全角符号等隐性错误识别不出 |
| 补一条规则后只看是否报错、不看 diff | priority 抢错时空值率反而上升，机器不报错 |
| 审计报告只有数字、没有结论建议 | 业务方无法基于此报告做发布决策 |
| 出了审计报告但没人签字就开始合并 | 等于没出报告 |
| P0 项还没修复就出审计报告 | 报告失去意义（"明知有 bug 还发布"） |

---

## 5.8 完成判定

```
☐ 每张 L2 的 null_rates TSV 已产出
☐ 每个 L3 子类的 ext_attributes 命中率 TSV 已产出
☐ schema gap 探查已跑、P0/P1/P2 已分级
☐ schema 一致性扫描（5.5.4）四项全部 = 0 行
☐ 本轮所有 P0 项已修复并通过 5.5.5 复验
☐ 单位抽样已抽（必抽列见 5.5.3）、异常已处理
☐ 审计报告已产出，业务方签字
☐ 报告结论明确"通过，可进入阶段 6"
```

满足后进入 [`6_release_gate.md`](6_release_gate.md)。
