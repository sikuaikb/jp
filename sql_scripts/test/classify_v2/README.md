# classify · 多源单脚本（参考 / 回归验证）

正式引擎已落到 **`sql_scripts/1.classify/dwd_component_class.sql`**（icpdf + digikey 多源单脚本）。
本目录仅保留一份**参考副本**与**回归验证脚本**，便于在 test 环境复跑对比。

## 文件

| 文件 | 说明 |
|------|------|
| `dwd_component_class_v3_multisource.sql` | 多源单脚本参考副本（与 prod `1.classify/dwd_component_class.sql` 同逻辑） |
| `run_classify_v3_multisource_test.sh` | test 回归：param 读 prod、dim 读 test_dim、结果写 `test_dwd.dwd_component_class_v3ms` |

> 注意：参考副本可能与 prod 版本漂移；以 `sql_scripts/1.classify/dwd_component_class.sql` 为准。

## 引擎要点（详见 `1.classify/RULE_ENGINE.md`）

- **一条 INSERT 跑全量、全源**：`param_all` UNION ALL 各源 param 表；加新源加一段 + dim 规则。
- **性能**：gate 用 `array_contains` OR 连接产出 `(id, data_source, gate_l1)`；classify 按
  `(data_source, l1_code)` 分区连接、`field_code` UNION ALL 展开，**无 `ON TRUE` 笛卡尔积**。
- **Gate**：每 L1 走自己的 `gate_<l1>_<source>_v1`（L1 取 `rule_id` 第 2 段）。
- **JSON 列由 field_code 显式声明**：`parjson_match_map`→`prajson`、`parjson2_match_map`→`prajson2`。
- `note_regexp` / `partno_regexp` 已启用；决选 `PARTITION BY (data_source, id)`。

## 用法

```bash
source env
SKIP_LOAD_SEED=1 bash sql_scripts/test/classify_v2/run_classify_v3_multisource_test.sh
```

## 验收基线（test，含 note/partno）

| 源 | 行数 |
|----|------|
| icpdf | 2,462,150 |
| digikey | 768,028 |
