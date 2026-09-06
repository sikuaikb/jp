# 阶段 7 · 五维验收

> **本阶段一句话**：用 5 个独立维度做发布后验收，每项都必须能复跑、能签字。
> 占工期：含在阶段 6 的 7% 内。
>
> **本阶段的目标不是"再做一遍"，而是给业务方一个可以信任的发布留痕**。

---

## 7.1 五个维度概览

| 维度 | 怎么验 | 通过标准 |
|------|--------|---------|
| **1. 数量一致性** | 每张宽表行数 = 「分类结果 ∩ 源表」期望行数 | 完全一致 |
| **2. 分布合理性** | L1/L2/L3 占比与业务直觉对比 | 异常类目去商城抽样核对、业务方点头 |
| **3. L2 空值率基线** | 与上一版基线 CSV 对比 | 关注 / 高危列空值率不悄悄变化 |
| **4. L3 ext_attributes 命中率** | 每个 L3 子类的 ext_attributes 非空率 | 存在提取规则的属性命中率 ≥ 源端覆盖率的 90% |
| **5. 品牌标准化质量** | 每张 L2 宽表的 brand_null + dt vs di | brand_null=0 且 dt=di |
| **6. 外部样本对照** | 易错 case TSV，业务方逐条点头 | 100% 一致 / 已标注 |

> 注：维度 6 是"质性验收"，与前 5 个量化维度并列；6 项里业务方签字是最终拦截门。

---

## 7.2 维度 1：数量一致性

### 7.2.1 计算"期望行数"

```sql
SELECT l2_code, COUNT(*) AS expected_rows
FROM dwd.dwd_component_class
WHERE l1_code = '<l1>'
  AND l3_code NOT LIKE '%_unclassified'
GROUP BY l2_code;
```

### 7.2.2 对比 L2 宽表实际行数

```sql
-- 对每张 L2 宽表
SELECT 'dwd_l2_<l1>_<l2_code>' AS l2_table, COUNT(*) AS actual_rows
FROM dwd.dwd_l2_<l1>_<l2_code>;
```

### 7.2.3 判定

```
☐ 每个 l2_code 的 expected_rows = actual_rows
```

不一致的常见原因：

- 宽表 build 没过滤 `_unclassified` → actual > expected
- EAV JOIN 链路丢数据 → actual < expected
- 重跑 build 时分区残留 → actual > expected

---

## 7.3 维度 2：分布合理性

### 7.3.1 跨 L1 占比对比

```sql
SELECT l1_code, COUNT(*) AS n, ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER(), 2) AS pct
FROM dwd.dwd_component_class
GROUP BY l1_code
ORDER BY n DESC;
```

### 7.3.2 本 L1 内 L3 占比

```sql
SELECT l3_code, COUNT(*) AS n, ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER(), 2) AS pct
FROM dwd.dwd_component_class
WHERE l1_code = '<l1>'
GROUP BY l3_code
ORDER BY n DESC;
```

### 7.3.3 与业务直觉对比

需要业务方点头：

- "电容主要是陶瓷 + 铝电解，其它都是小众" → 实际分布是否符合？
- "电阻主要是贴片电阻，巨幅多数是 0402/0603" → 实际是否如此？
- "MCU 32 位应该比 8 位多" → 实际是否如此？

异常分布去得捷 / 芯查查抽样核对，TSV 入仓 `artifacts/<l1>/distribution_review_<date>.tsv`。

### 7.3.4 判定

```
☐ 每个 L3 占比与业务预期一致或有合理解释
☐ 异常分布已抽样、TSV 已入仓、业务方点头
```

---

## 7.4 维度 3：L2 空值率基线

### 7.4.1 用 5.5 的 null_rates TSV 作为本次基线

使用 [probes.md §8.1 空值率扫描模板](../probes.md)，替换 `<DWD_SCHEMA>=dwd`、`<L2_TABLE>=dwd_l2_<l1>_<l2_code>`，将结果以 TSV 格式（mysql 客户端 `-B`）保存到 `artifacts/<l1>/baseline_<l2_code>_<date>.tsv`。

### 7.4.2 与上一版基线对比（如有）

```bash
diff artifacts/<l1>/baseline_<l2_code>_<previous_date>.tsv \
     artifacts/<l1>/baseline_<l2_code>_<date>.tsv
```

### 7.4.3 每条变化必须打标

| 标签 | 含义 |
|------|------|
| `improved` | 本次发布带来覆盖率提升 |
| `regressed` | 本次发布带来覆盖率下降（需追查） |
| `noise` | 差异在 ±1pp（百分点）内，正常波动 |

### 7.4.4 判定

```
☐ 关注列 / 高危列没有 regressed（除非已记入"已知问题"）
☐ improved 列已在审计报告"本轮修复收益"中体现
☐ 本次基线 TSV 已入仓，成为下一次发布的对照基线
```

---

## 7.5 维度 4：L3 ext_attributes 命中率

### 7.5.1 计算每个 L3 子类的命中率

```sql
-- 对每个 L3 子类、每个该 L3 应有的 std_attr_code
SELECT l3_code,
       COUNT(*) AS total,
       SUM(CASE WHEN json_extract_string(ext_attributes, '$.<attr>') IS NOT NULL
                THEN 1 ELSE 0 END) AS hit,
       ROUND(100.0 * SUM(CASE WHEN json_extract_string(ext_attributes, '$.<attr>') IS NOT NULL
                              THEN 1 ELSE 0 END) / COUNT(*), 2) AS hit_pct
FROM dwd.dwd_l2_<l1>_<l2_code>
WHERE l3_code = '<target_l3>'
GROUP BY l3_code;
```

### 7.5.2 标杆：源端覆盖率 × 90%

```sql
-- 源端覆盖率（该 L3 物料中源端有 <key> 的比例）
-- 多源时按 w.data_source 各跑一次；<SRC_PARAM_TABLE> 与 <SRC_KEY_EXPR> 按 SKILL §二-A.D 替换
-- icpdf 示例：<SRC_KEY_EXPR> = json_extract_string(p.prajson2, '$.<key>')
-- digikey 示例：<SRC_KEY_EXPR> = (SELECT value FROM dwd.dwd_digikey_component_param d
--                                  WHERE d.id = p.id AND d.param_name = '<key>' LIMIT 1)
SELECT
  w.data_source,
  COUNT(*) AS total,
  SUM(CASE WHEN <SRC_KEY_EXPR> IS NOT NULL THEN 1 ELSE 0 END) AS src_hit
FROM dwd.dwd_l2_<l1>_<l2_code> w
JOIN <SRC_PARAM_TABLE> p ON p.id = w.id AND w.data_source = '<SOURCE>'
WHERE w.l3_code = '<target_l3>'
GROUP BY w.data_source;
```

**判定**：宽表 ext_attributes 命中率 ≥ 源端覆盖率 × 90%。

低于这个标杆意味着：源端有数据但我们没接住（extract_rule 漏了 / 单位换算失败 / regex 截断）。

### 7.5.3 判定

```
☐ 每个 L3 子类的 ext_attributes 命中率 ≥ 源端覆盖率 × 90%
☐ 低于标杆的属性已记录原因（schema 合约登记但当前源没有 / 已知 P1 项）
```

---

## 7.6 维度 5：品牌标准化质量

```sql
SELECT 'dwd_l2_<l1>_<l2_code>' AS l2_table,
       COUNT(*) AS total,
       SUM(CASE WHEN brand IS NULL THEN 1 ELSE 0 END) AS brand_null,
       COUNT(DISTINCT brand) AS dt,
       COUNT(DISTINCT brandid) AS di
FROM dwd.dwd_l2_<l1>_<l2_code>;
```

### 判定

```
☐ 每张 L2 宽表：brand_null = 0
☐ 每张 L2 宽表：COUNT(DISTINCT brand) = COUNT(DISTINCT brandid)
```

任何一条不过 → 不能算验收通过，需要回到品牌字典修复。

---

## 7.7 维度 6：外部样本对照

### 7.7.1 抽样

把阶段 5.5 单位抽样 + 阶段 5 双回路最后一轮的外部 TSV 合并成发布版 TSV：

```
artifacts/<l1>/release_review_<date>.tsv
```

包含至少：

- 每个 L3 5 个料号（覆盖大厂家 + 小众品牌）
- 每个高空值率列 NULL 行 5 个
- 单位抽样异常列 5 个

### 7.7.2 业务方逐条点头

每条要标 `Y / N`：

- 分类是否与商城一致？Y / N
- 关键参数（容量 / 电压 / 频率等）是否合理？Y / N

**N 的条目必须有处理结论**（已记入下次迭代 / 业务可接受 / 已修复）。

### 7.7.3 判定

```
☐ release_review TSV 已产出
☐ 业务方在 TSV 上逐条签字（Y 或 N + 处理结论）
☐ N 的条目都有明确处理结论
```

---

## 7.8 验收报告

发布后产出**验收报告**：`artifacts/<l1>/acceptance_report_<date>.md`。

### 模板

```markdown
# <L1> 数据清洗发布验收报告 (<date>)

## 1. 发布信息
- L1: <l1>
- 发布人: <name>
- 业务方授权人: <name>
- 发布时间: <YYYY-MM-DD HH:MM>
- 涉及表: <list>

## 2. 五维验收结果
| 维度 | 通过 | 备注 |
| 1. 数量一致性 | ✅/❌ | |
| 2. 分布合理性 | ✅/❌ | |
| 3. L2 空值率基线 | ✅/❌ | |
| 4. L3 ext_attributes 命中率 | ✅/❌ | |
| 5. 品牌标准化质量 | ✅/❌ | |
| 6. 外部样本对照 | ✅/❌ | |

## 3. 本次发布带来的指标变化
- <metric>: <before> → <after>

## 4. 已知问题 + 下次迭代计划
| 问题 | 是否阻塞 | 计划修复时间 |

## 5. 回滚信息（备用）
- 回滚命令: <command>
- 回滚预估耗时: <minutes>
- 联系人: <name>
```

---

## 7.9 产物清单

| 产物 | 落到哪里 |
|------|---------|
| 五维验收明细 TSV | `artifacts/<l1>/acceptance_<dim>_<date>.tsv`（每个维度一份） |
| release_review TSV | `artifacts/<l1>/release_review_<date>.tsv` |
| 验收报告 | `artifacts/<l1>/acceptance_report_<date>.md` |
| 本次基线 CSV | `artifacts/<l1>/baseline_<l2_code>_<date>.tsv`（成为下次基线对照） |

---

## 7.10 反模式

| 反模式 | 后果 |
|--------|------|
| 五维验收只跑机器项，跳过 6 维度业务签字 | 验收形式化，没有真正的业务背书 |
| 业务方"看着差不多就过了"不逐条标 Y/N | 失去样本级的留痕 |
| 验收报告只列指标，不列下次迭代计划 | 已知问题被忘记、下次发布重复犯错 |
| 不留本次基线给下次对比 | 永远看不到长期趋势 |
| 维度 3 出现 regressed 但接受发布 | 已知劣化还上线 |

---

## 7.11 完成判定

```
☐ 六个维度全部通过（或不通过项有明确处理结论）
☐ 验收报告已入仓
☐ 业务方在验收报告上签字
☐ 本次基线 TSV 已入仓
☐ 已知问题已转化为下次迭代的输入
```

满足后，本次 L1 发布周期结束。下一个 L1 从阶段 1 重新开始。
