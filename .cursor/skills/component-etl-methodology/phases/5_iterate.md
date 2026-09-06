# 阶段 5 · 双回路试错迭代

> **本阶段一句话**：跑完第一版后用「内部探针 + 外部商城」双回路逼近正确，直到指标稳定。
> 占工期：约 35%（**整个工程中最长**的一段）。

---

## 5.1 双回路是什么

```
内部回路（自洽证明）：
  跑探针 → 量化问题 → 改 dim → 重跑引擎 → 与基线 diff → 量化收益

外部回路（正确性证明）：
  挑可疑样本 → 得捷 + 芯查查双查 → 反推规则错在哪 → 改 dim → 再核对
```

**两个回路缺一不可**：

- 只有内部回路 → 自洽 ≠ 正确，整套字典写错也能跑出"漂亮"指标
- 只有外部回路 → 没有量化基线，改了一处不知道是否引发回归

---

## 5.2 内部回路：跑探针

每轮迭代要跑的三组探针：

### 5.2.1 行数与分布

```sql
SELECT l2_code, l3_code, COUNT(*) AS n
FROM dwd.dwd_component_class
WHERE l1_code = '<l1>'
GROUP BY l2_code, l3_code
ORDER BY n DESC;
```

判断点：

- L1/L2/L3 占比与业务直觉对比
- 数量异常少（个位数）的 L3 是不是规则没命中过
- 数量异常多的 L3 是不是吃了别的类

### 5.2.2 核心属性 NULL 占比

**L2 物理列空值率**：用 `null_rates.sql` 探针扫描。

**L3 ext_attributes 命中率**：单独跑，分母是该 L3 子类行数：

```sql
SELECT l3_code, COUNT(*) AS total,
       SUM(CASE WHEN json_extract_string(ext_attributes, '$.<attr>') IS NULL THEN 1 ELSE 0 END) AS null_cnt
FROM dwd.dwd_l2_<l1>_<l2_code>
WHERE l3_code = '<target_l3>'
GROUP BY l3_code;
```

**关键**：L2 公共列空值率与 L3 专有属性命中率**必须分开报表**。混在一起会被"非该 L3 的正常 NULL"淹没真问题。

### 5.2.3 易错关键词探测

针对阶段 1 摸底笔记里记录的"易混淆边界词"做命中量统计：

```sql
-- 例（icpdf 源 + capacitor）：容易把"双电层电容"识别成普通电解电容
-- 多源时按 c.data_source 拆开各跑一次；<SRC_PARAM_TABLE> 与本源关键字段按 SKILL §二-A.D 替换
SELECT c.data_source, c.l3_code, COUNT(*) AS n
FROM dwd.dwd_l2_capacitor_non_polar_fixed_capacitor c
JOIN <SRC_PARAM_TABLE> p ON p.id = c.id AND c.data_source = '<SOURCE>'
WHERE LOWER(p.taginfo) LIKE '%双电层%'        -- icpdf：用 taginfo；digikey：换成对应文本列
   OR LOWER(p.taginfo) LIKE '%double layer%'
GROUP BY c.data_source, c.l3_code;
-- 期望：全部在 supercapacitor 段，如果出现在其它 L3 → 规则太宽
```

---

## 5.3 内部回路：基线 diff（强制留痕）

**这是最容易跳过、但绝对不能跳过的步骤**。

每改一次 dim 都要做**修前 vs 修后 diff**：

使用 [probes.md §8.1 空值率扫描模板](../probes.md)，在改 dim 前后各执行一次，分别保存 TSV：

```bash
# 修前快照：执行 probes.md §8.1 模板（<DWD_SCHEMA>=dwd / test_dwd，<L2_TABLE>=dwd_l2_<l1>_<l2_code>），-B 导出
# 保存 → artifacts/<l1>/baseline_<date>_v1.tsv

# 改 dim、重跑引擎、重跑 build...

# 修后快照：同上
# 保存 → artifacts/<l1>/baseline_<date>_v2.tsv

diff artifacts/<l1>/baseline_<date>_v1.tsv artifacts/<l1>/baseline_<date>_v2.tsv
```

**diff 必须人眼审阅**。每一条变化要打三选一标签：

| 标签 | 含义 |
|------|------|
| `improved` | 空值率下降 / 分布更合理 → 本次修复有效 |
| `regressed` | 空值率上升 / 分布变差 → 必须回滚或追加修复 |
| `noise` | 无显著变化 → 修复未生效（探针没探到、规则未命中等） |

---

## 5.4 外部回路：挑可疑样本

按三个维度抽：

| 维度 | 怎么抽 | 干嘛用 |
|------|--------|--------|
| **每个 L3** | 随机 5-10 个 | 验分类口径 |
| **每个高空值率列** | NULL 行随机 5-10 个 | 验"是真没有还是漏抽" |
| **每个分布异常的类目** | 边缘 / 大厂家料号 | 验规则太宽 or 太严 |

抽样 SQL（使用 [probes.md §8.2 分层抽样模板](../probes.md)）：

```sql
-- 例：按 l3_code 分层，每个 L3 抽 5 条
-- 替换 <SRC_TABLE>=dwd_l2_<l1>_<l2_code>，<FILTER_COND>=1=1（或加额外过滤条件）
WITH ranked AS (
  SELECT *,
    ROW_NUMBER() OVER (PARTITION BY l3_code ORDER BY id) AS rn
  FROM dwd.<SRC_TABLE>
  WHERE <FILTER_COND>
)
SELECT * FROM ranked WHERE rn <= 5 ORDER BY l3_code, id;
```

结果导出（mysql `-B`）→ `artifacts/<l1>/review_sample_iter_<n>_<date>.tsv`

---

## 5.5 外部回路：去商城核对

### 5.5.1 商城选择

| 来源 | 适用 |
|------|------|
| **得捷（DigiKey）** | 海外大厂参数最标准化；分类边界、单位口径、关键参数对照 |
| **芯查查** | 国内料号覆盖广，中文分类贴近厂家原始数据；国产/亚洲品牌 |

**铁律**：

- 海外品牌（Vishay / Panasonic / Murata / TDK / KEMET / AVX）**以得捷为准**
- 国内品牌、亚洲冷门、中文歧义大的**以芯查查为准**
- 两边都查得到时**两边都看**；不一致时回头看源数据里厂家自己的描述

### 5.5.2 落两份 TSV

按 [`decision_guides.md`](../decision_guides.md) 第 3 节模板：

- **分类核对 TSV**：`artifacts/<l1>/<l1>_class_review_iter_<n>.tsv`
- **参数核对 TSV**：`artifacts/<l1>/<l1>_attr_review_iter_<n>.tsv`

每条样本必须打**判定结论**（分类四选一、参数三选一）。

### 5.5.3 判定流程不要跳步

**遇到分类不符** → 走 [`decision_guides.md` 第 1 节](../decision_guides.md#1-分类核对的三段式判断) 三段式：

1. 商城两边一致且与我方不同 → 我方错
2. 源里有信号 → 进改 dim
3. 源里没信号 → 不要硬写规则强猜

**遇到参数为空** → 走 [`decision_guides.md` 第 2 节](../decision_guides.md#2-空值核对的四段式判断) 四段式：

1. 商城没有 → 业务不公开，**不动**
2. L3 专有 + 不在数据源范围 → schema 保留合约，**不补规则**
3. 源端没有 → 上游问题，**不补规则**
4. 源端有 + 我们 NULL → 自己的问题，**补 dim**

---

## 5.6 量化问题 + 改 dim

外部发现的错误**必须回到内部用探针 SQL 量化**：

```sql
-- 例（icpdf 源）：发现 1 条 X7R 电容被错分到 X5R，量化这种错误全表有多少
-- 多源时每个源各跑一次，<SRC_PARAM_TABLE> 与"介质"键访问表达式按 SKILL §二-A.D 替换
SELECT c.data_source, p.brandshort, COUNT(*) AS n
FROM dwd.dwd_l2_capacitor_non_polar_fixed_capacitor c
JOIN <SRC_PARAM_TABLE> p ON p.id = c.id AND c.data_source = '<SOURCE>'
WHERE c.l3_code = 'ceramic_x5r_capacitor'
  AND (LOWER(p.taginfo) LIKE '%x7r%'                       -- icpdf：taginfo 文本
       OR get_json_string(p.prajson2, '$.介质') = 'X7R')   -- icpdf：prajson2 半结构
GROUP BY c.data_source, p.brandshort ORDER BY n DESC;
```

**量化的意义**：

- 1 条问题：补一条规则成本 vs 收益是否值得
- 100 条问题：必修
- 跨多家厂商：可能是规则结构性缺陷，要重新审视 phase/priority

把修复**落成 dim 字典里的一条新增/修改规则**，**不要直接改引擎 SQL**。

---

## 5.7 双回路验证

每一轮"改完 dim → 重跑"之后：

| 验证项 | 怎么做 |
|--------|--------|
| 内部 diff | 跑同一段探针对比修前修后差异（行数、空值率、分布），按 5.3 节打标 |
| 外部复查 | 把同一批可疑样本**再去商城核对一次**，确认修对且无新反向误判 |

**复查发现新问题** → 回到 5.4 重新挑样本，进入下一轮迭代。

---

## 5.8 迭代收敛判定

每一轮的 ”外部 TSV“ 都计算这三个指标：

| 指标 | 计算 | 收敛目标 |
|------|------|---------|
| 分类一致率 | `consistent / total` | ≥ 95% |
| `our_rule_gap` 比例 | `our_rule_gap / total` | ≤ 2% |
| 参数核对一致率 | `(business_not_public + upstream_missing + our_rule_gap=已修) / total` | ≥ 90% |

**连续两轮都达到目标** → 迭代收敛，可以进入阶段 5.5 数据质量审计。

**否则**：继续下一轮，直到指标稳定。注意每轮间隔 ≥ 1 天（让记忆冷却，避免确认偏差）。

---

## 5.9 产物清单

| 产物 | 落到哪里 |
|------|---------|
| 每轮内部 diff 报告 | `artifacts/<l1>/baseline_diff_iter_<n>.md` |
| 每轮分类核对 TSV | `artifacts/<l1>/<l1>_class_review_iter_<n>.tsv` |
| 每轮参数核对 TSV | `artifacts/<l1>/<l1>_attr_review_iter_<n>.tsv` |
| dim 字典变更 | `test_dim.*_<l1>` 后缀表 +（合并后）`dim.bak_*_<merge_tag>` 备份 |
| 收敛判定纪要 | `artifacts/<l1>/iter_convergence_<date>.md` |

---

## 5.10 反模式

| 反模式 | 后果 |
|--------|------|
| 看到内部空值率高就立刻补规则 | 跳过"商城是否有 / 源端是否有"判断，规则白补 |
| 改了 dim 不跑 diff 探针 | 半年后没人记得为什么这么改、修了什么 |
| 只跑内部探针不去商城 | 自洽 ≠ 正确，可能整套字典都写错 |
| 只挑"自己觉得对"的样本去商城 | 确认偏差，最大的隐性 bug |
| 同一轮内反复改 dim 不留中间快照 | 出现回归无法定位是哪一步引入 |
| 改 phase/priority 不跑全表 diff | 全局排序变化大范围"按下葫芦浮起瓢" |
| `our_rule_gap` 高仍然推进到阶段 5.5 | 5.5 数据质量审计基础就不稳，会反复返工 |
| 没有 ”收敛判定纪要“ 就开始 5.5 | 5.5 数据基础不可信，浪费审计精力 |

---

## 5.11 完成判定

```
☐ 连续两轮迭代分类一致率 ≥ 95%
☐ 连续两轮迭代 our_rule_gap ≤ 2%
☐ 参数核对一致率 ≥ 90%
☐ 所有内部 diff 报告与外部 TSV 已入仓
☐ 收敛判定纪要明确写"通过，可进入 5.5"
```

满足后进入 [`5_5_qa_audit.md`](5_5_qa_audit.md)。
