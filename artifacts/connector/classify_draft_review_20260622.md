# connector · 分类草案评审纪要

日期：20260622  
schema：v1.4.30（`tmp/connector_schema.xlsx`）  
数据源：digikey（仅）

## 结论

**gate v2 补全后通过，可进入阶段 3（属性 dim）。**

- `validate_classify_dim.py`：硬门控 OK（23 L3 · l3_id 段 08xxxx 连续 · schema_version 一致）
- gate 命中约 **2,435,006** SKU；已分类 **2,434,339**（覆盖率 **100.0%**）
- 与 L1 CSV 总量 2,447,784 差 **~1.3 万**，为有意排除的端子耗材/套件（见 `gate_config.EXPLICIT_OUT`）
- 双商城核对 v2（Playwright · ~48min · 105 条）：
  - 得捷 **105/105 bot 拦截**（机房 IP；需本地 `save_dk_storage.py` 导出 cookie 后 `--retry-bot`）
  - 芯查查 **105/105 搜索命中**（多为搜索列表页，非详情 breadcrumb）
  - 判定（修正 xcc 搜索页 sidebar 噪声后）：`consistent` **97** · `signal_missing` **8** · `our_rule_gap` **0（0%）**
  - 产物：`artifacts/connector/connector_class_review_20260623.tsv`

## 分类分布（Top · gate v2）

| L2 | L3 | 行数 |
|----|-----|------|
| 板级互连 | 板对板 | 811,436 |
| 通用壳体 | 圆形连接器 | 803,722 |
| 板级互连 | 排针排母 | 462,882 |
| 通用壳体 | 矩形连接器 | 65,110 |
| 背板/IC | 卡缘/背板 | 63,991 |
| 板级互连 | 线对板 | 40,802 |
| 电源端子 | 栅栏式端子 | 40,649 |

完整分布见 `run_test_connector.py` 输出或库表 `test_dwd.dwd_component_class_connector`。

## 已知 v1 局限（不阻断阶段 3）

0. **gate v2 补全**：新增板间隔柱（+19.3 万）、隔板块、线对板、底壳/Keystone/ARINC/专用背板、DIN 导轨端子等 31 个遗漏叶子；`弹簧式` 归排针排母（非弹簧端子块）。
1. **外壳/触头/配件** 与**组件**共用 DigiKey 叶子，v1 按 category 合并归类；后续属性阶段需用 note/prajson 区分“本体 vs 附件”。
2. **`USB、DVI、HDMI 连接器组件`** 依赖 `note_cn_regexp` 拆 USB/HDMI；未命中 note 的少量 SKU 可能落 USB fallback 或未分类。
3. **端子接线系统** 以 `pluggable_terminal_block` fallback；螺钉/弹簧/栅栏专规命中率低，待阶段 5 迭代。
4. **SD/SIM 卡座** 在得捷无独立高流量叶子；`card_socket_connector` 当前由 `直列式模块插座`（DIMM/SODIMM）覆盖。

## 产物索引

| 产物 | 路径 |
|------|------|
| 摸底笔记 | `artifacts/connector/digikey_explore_notes_20260622.md` |
| 词频/抽样 | `artifacts/connector/digikey_keyword_freq_20260622.tsv` 等 |
| 分类抽样 | `artifacts/connector/connector_class_sample_v1_20260622.tsv` |
| 商城核对 | `artifacts/connector/connector_class_review_20260623.tsv` |
| 沙盒入口 | `sql_scripts/test/connector/run_test_connector.py` |

## 下一步（阶段 3）

1. 从 `connector_schema.xlsx` 生成 `test_dim.dim_attr_schema_connector` + extract rules  
2. 得捷 KV/prajson gap 探针（`probes.md §8.3`）  
3. 多源若后续接 icpdf，补 A15 对称性校验
