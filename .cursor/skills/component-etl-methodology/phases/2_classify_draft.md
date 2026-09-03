# 阶段 2 · 分类规则草案 + 第一次商城核对

> **本阶段一句话**：写一个能跑通的最小规则集，**第一版就拉去得捷 / 芯查查核对**，不追求精度但要确保方向对。
> 占工期：约 15%。前置：阶段 1 摸底笔记已产出。

---

## 2.1 设计层面

### 2.1.1 规则要分阶段（phase）

| phase | 名称 | 作用 |
|-------|------|------|
| 1 | gate | L1 白名单 / 黑名单，把明显不属于本品类的物料挡在外面 |
| 2 | 类目精确匹配 | 显式分类字段（icpdf：`category2`/`category`/`taginfo`；digikey：`category`/`family`；其他源等价字段）的**强信号** |
| 3 | 半结构启发式 | 源端键名/值正则（icpdf：`prajson` 值/`prajson2` key；digikey：参数 KV 表 `param_name`/`param_value`）等**弱信号** |

phase 与源无关——phase 描述"信号强度层级"，每个源都各自在两个 phase 下编写规则；不同源的规则通过 `data_source` 列隔离，互不影响。

**全局胜者公式**（任何同一物料若命中多条规则）：

```
ORDER BY phase DESC, rule_priority ASC, l3_code ASC
```

**为什么 phase DESC**：弱信号兜底优先级更低 → 强信号一旦命中就立刻定，不让弱信号搅乱。

**任何对此公式的修改都是"全表回归事件"** —— 必须配双回路验证，看每个 L3 行数变化。

### 2.1.2 priority 设计

同 phase 内业务越具体的规则，priority 数字**越小**（优先级越高）。一个典型例子：

| rule_id | phase | priority | 含义 |
|---------|-------|----------|------|
| `cap_classify_001_aluminum_polymer` | 3 | 10 | 命中"铝聚合物" → 铝聚合物电容 |
| `cap_classify_002_aluminum_general` | 3 | 50 | 命中"铝电解" → 铝电解电容 |
| `cap_classify_999_unclassified` | 3 | 9000 | 兜底落 unclassified |

**绝不能写**：`cap_classify_xxx_fallback_to_ceramic`（兜底归到陶瓷）—— 这种是反模式，会掩盖问题。

### 2.1.3 规则最小粒度

**每条规则只回答一个问题**。反模式：一条规则同时干"过滤 + 分类 + 装值 + 单位换算"四件事。

正确粒度：

- 一条规则做"L3 = 铝聚合物电容"的判定 → OK
- 一条规则做"L3 = 铝电解电容 且 容量大于 100uF" → 不 OK，应该拆成两条（一条分类、一条值域）

### 2.1.4 置信度

每条规则带 `confidence_weight`（0~1）。最终物料的置信度 = `confidence_weight × phase 基准权重`。

- gate（phase=1）基准权重高（如 1.0）
- 类目精确匹配（phase=2）基准权重次（如 0.8）
- 半结构启发式（phase=3）基准权重低（如 0.5）

低置信度的命中要在 EAV / 宽表里**额外打标**，方便后续抽查。

---

## 2.2 落地步骤

### 2.2.1 编 gate 白名单（phase=1）

依据阶段 1 关键词词频表，挑出能识别本品类的关键词集合：

```csv
rule_id,phase,priority,l3_id,l3_code,clause_group,clause_ord,source_field,operator,pattern,confidence_weight,enabled
transistor_gate_v1,1,10,000000,_unclassified,1,1,category2,contains_any,"transistor|三极管|MOSFET|IGBT|...",1.0,1
transistor_gate_neg_v1,1,20,000000,_unclassified,2,1,category2,not_contains_any,"transistor笔|...",1.0,1
```

注意：

- gate 不要写得太严，宁可"误放"到 unclassified 也不要"误挡"了真实物料
- 写 NOT 排除（如"电容笔"）防止反向误判

### 2.2.2 写 L3 classify 规则草案（phase=2/3）

每个 L3 子类至少给一条规则。先用强信号（phase=2）：

```csv
cap_classify_001_aluminum_polymer,2,10,100101,aluminum_polymer_capacitor,1,1,category2,equals_any,"铝聚合物电容|aluminum polymer capacitor",0.9,1
```

强信号覆盖不了的再写半结构启发式（phase=3）：

```csv
cap_classify_001b_aluminum_polymer_kv,3,30,100101,aluminum_polymer_capacitor,1,1,prajson2_key_value,key_contains,"电容器类型=铝聚合物",0.6,1
```

### 2.2.3 跑分类引擎，看结果分布

```sql
SELECT l1_code, l2_code, l3_code, COUNT(*) AS n
FROM test_dwd.dwd_component_class
WHERE l1_code = '<l1>'
GROUP BY l1_code, l2_code, l3_code
ORDER BY n DESC;
```

判断点（**先看分布，再去商城核对**）：

- 是不是大头都集中在 `_unclassified`？→ gate 太严或者规则太少
- 某个 L3 占比是不是不合常理（如 95% 都是同一子类）？→ 规则太宽吃了别的类
- 是不是有几个 L3 是 0 行？→ 规则没命中过，要检查关键词

---

## 2.3 强制动作：第一次去商城核对（不是后期才做）

**这是本阶段最容易跳过、但绝对不能跳过的一步**。

### 2.3.1 抽样原则

| 维度 | 怎么抽 | 抽多少 |
|------|--------|--------|
| 每个 L3 | 随机 + 边缘料号 | 5-10 个 |
| 数量异常少的 L3 | 全抽 | 全部 |
| 数量异常多的 L3 | 边缘料号 + 大厂家料号 | 10+ |
| 大厂家 | 必抽 | 每个厂家 ≥ 3 个 |

抽样 SQL：

使用 [probes.md §8.2 分层抽样模板](../probes.md)，按 l3_code 分层抽 5 条分类结果：

```sql
-- 替换 <L1>
WITH ranked AS (
  SELECT *,
    ROW_NUMBER() OVER (PARTITION BY l3_code ORDER BY id) AS rn
  FROM test_dwd.dwd_component_class_<l1>    -- 或 dwd.dwd_component_class（多源合并后）
  WHERE l1_code = '<L1>'
)
SELECT * FROM ranked WHERE rn <= 5 ORDER BY l3_code, id;
```

导出（mysql `-B`）→ `artifacts/<l1>/class_sample_v1_<date>.tsv`

### 2.3.2 去得捷 + 芯查查双查

- **海外品牌（Vishay / Panasonic / Murata / TDK / KEMET / AVX / Yageo / 三星）以得捷为准**
- **国内品牌、亚洲冷门、中文歧义大的以芯查查为准**
- **两边都查得到时两边都看**；不一致时回头看源数据里厂家自己的描述

### 2.3.3 落分类核对 TSV

模板见 [`decision_guides.md`](../decision_guides.md#31-分类核对-tsv) 第 3.1 节。

每一条样本必须打一个**判定结论**（四选一）：

- `consistent`（一致，正常）
- `mall_inconsistent`（两个商城互相不一致，待业务裁决，**暂不动规则**）
- `signal_missing`（源里没有任何区分信号，**不写规则强猜**）
- `our_rule_gap`（源里有信号但我方判错，**进改 dim 流程**）

### 2.3.4 草案过不了商城核对，就停手

**这是硬门控**：

- 如果 `our_rule_gap` 比例 > 30%，说明草案方向有问题 → 回到 2.2 重写，不要往后做属性 dim
- 如果某个 L3 全部样本都是 `signal_missing`，说明这个 L3 不可能用规则判定 → 移除该 L3 或合并到上级

**绝不要在草案错的分类基础上去建属性 dim**。属性都建在错的分类上是双倍返工。

---

## 2.4 产物清单

| 产物 | 落到哪里 |
|------|---------|
| 第一版 classify 规则 | `test_dim.dim_l3_classify_rule_<l1>` 后缀表（INSERT） |
| 第一版 L3 类目 | `test_dim.dim_l3_classify_<l1>` 后缀表（INSERT） |
| 分类抽样 TSV | `artifacts/<l1>/class_sample_v1_<date>.tsv` |
| 分类核对 TSV | `artifacts/<l1>/<l1>_class_review_<date>.tsv` |
| 草案评审纪要 | `artifacts/<l1>/classify_draft_review_<date>.md`（含 `our_rule_gap` 比例、是否通过 30% 门控） |

---

## 2.5 反模式

| 反模式 | 后果 |
|--------|------|
| 草案写完不去商城核对就做属性 dim | 在错的分类上盖属性字典，双倍返工 |
| 未命中规则就兜底归到大类 | 掩盖真实数据问题，永远发现不了 |
| 只看一边商城（只看得捷或只看芯查查） | 海外/国内偏差大的品类会判错 |
| 抽样只抽"我觉得对的"样本 | 确认偏差，是最大的隐性 bug |
| 边缘 L3 没人抽样 | 全部样本来自高频 L3，掩盖低频 L3 的错误 |
| `our_rule_gap` 比例高仍然进入阶段 3 | 后期发现要返工阶段 2 时，阶段 3 的所有工作要重做 |

---

## 2.6 完成判定

```
☐ classify 规则 CSV 已 git diff 入仓
☐ 分类抽样 TSV 已产出
☐ 分类核对 TSV 已产出且每条都打了判定结论
☐ our_rule_gap 比例 ≤ 30%
☐ 草案评审纪要明确写"通过，可进入阶段 3"
```

只有全部满足才能进入阶段 3。
