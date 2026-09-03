# ecloud 电阻器商城核对记录（阶段 5 外部回路）

- **日期**：20260714
- **核对源**：DigiKey（主，经 OEMsec/JLC/PNEDA 等分销镜像页核对参数与分类）；芯查查需登录，本次未取到详情页
- **样本**：`classify_sample_ecloud_20260714.tsv` + `attr_review_ecloud_20260714.tsv` 子集

## 分类核对结论

| 判定 | 数量 | 说明 |
|------|------|------|
| consistent | 7 | CS/绕线/排阻/NTC/已命中 trimmer 样本与商城一致 |
| our_rule_gap | 3 | **3386P / 3269X / 3250W** 商城均为 Trimmer Potentiometers，我方落在 `potentiometer` |
| mall_inconsistent | 0 | — |

**根因（pot vs trimmer）**：

1. `resistor_ecloud_pot_v1` 对 `category2=可调电阻` 整桶兜底 → 14,528 行
2. `resistor_ecloud_trimmer_v1` 要求 **category2=可调电阻 AND note_cn 含微调**（组内 AND），仅 464 行
3. 约 **3,202** 行 pot 的 MPN 符合常见 Trimpot 系列前缀（3386/3269/3250/…），商城分类应为 trimmer

**处理（阶段 B）**：新增 phase=3 规则（优先于 pot 兜底）：

- `resistor_ecloud_trimmer_json_v1`：`prajson.类别 ` 含 `微调电位计`
- `resistor_ecloud_trimmer_mpn_v1`：`partno_regexp` 常见 Trimpot 系列

## 属性核对结论

| 判定 | 说明 |
|------|------|
| consistent | CS 阻值/精度/功率、NTC R25/B 值、电位器阻值与商城一致 |
| our_rule_gap | **`匝数` 误映射 `gang_count`**（实为 Number of Turns）；NTC 部分仅有 `B25/75` 未抽中 |
| signal_missing | `T6YA504KT20` 等 trimmer 源 prajson 极稀疏，宽表空属源端缺失 |

**处理（阶段 B）**：

1. 删除 `ec1520_pot_gang`（匝数→gang_count）
2. 保留/强化 trimmer `匝数`→`adjustment_turns`
3. 补 NTC `B25/75`、`B0/50` → `b_value_k`
4. 补 trimmer `调节类型`→`adjustment_type`
5. A15 豁免 `gang_count`（ecloud 无「组数」键）

## 人工续核

请在 `classify_sample_ecloud_20260714.tsv` / `attr_review_ecloud_20260714.tsv` 补 `mall_ok=Y/N` 列；登录芯查查后可对 disputed 样本二次确认。
