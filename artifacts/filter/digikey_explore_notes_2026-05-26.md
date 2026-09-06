# filter · DigiKey 阶段 1 摸底笔记

> 生成日期：2026-05-26  
> 数据源：`digikey` · 源表：`dwd.dwd_digikey_component_param`  
> 过滤条件：`element_at(category_info, 1) = '滤波器'`

---

## 1. 量级

| 指标 | 行数 |
|------|------|
| 源表全量 | 7,707,539 |
| L1=滤波器 | 27,213 |
| 占全表比例 | 0.35% |

**不要用** `category LIKE '%滤波%'` 作为 gate（仅约 15,645 行，会漏磁珠/馈通电容等）。

---

## 2. 字段覆盖率（滤波器子集）

见 [`digikey_field_coverage_2026-05-26.tsv`](digikey_field_coverage_2026-05-26.tsv)。

| 字段 | 非空占比（约） |
|------|----------------|
| `brandshort` | 96.43% |
| `category` | 100.0% |
| `category_info` | 100.0% |
| `prajson` | 100.0% |
| `note_cn` | 96.52% |
| `datasheet_url` | 84.7% |
| `image` | 96.53% |

**解读**：分类主信号是 `category` + `category_info[1]`；属性抽取主信号是 `prajson`（合并 specs，非平铺 KV）。

---

## 3. 叶子类词频（= gate 白名单候选）

见 [`digikey_keyword_freq_2026-05-26.tsv`](digikey_keyword_freq_2026-05-26.tsv)。

共 **10** 个叶子 `category`，合计 **27,213** 行。

**建议 gate `category_in` 白名单（10 个主叶子）**：

- `电力线滤波模块` — 11,506 行
- `铁氧体磁珠和芯片` — 7,612 行
- `馈通式电容器` — 4,236 行
- `EMI/RFI 滤波器（LC，RC 网络）` — 1,925 行
- `SAW 滤波器` — 1,841 行
- `滤波器配件` — 67 行
- `DSL 滤波器` — 19 行
- `螺旋滤波器` — 5 行
- `陶瓷滤波器` — 1 行
- `射频滤波器` — 1 行

**不纳入 filter gate**：

- `套件 > EMI，滤波器套件`（L1 是套件，约 221 行，不在上表 L1=滤波器 内）

---

## 4. prajson 顶层键 Top

见 [`digikey_prajson_keys_2026-05-26.tsv`](digikey_prajson_keys_2026-05-26.tsv)（Top 120）。

---

## 5. 分层抽样

见 [`digikey_source_sample_2026-05-26.tsv`](digikey_source_sample_2026-05-26.tsv)（每品牌最多 5 条，上限 500 行）。

人眼检查项：描述语言、单位写法、是否电源/连接器误归滤波器。

---

## 6. 邻近品类混淆边界（待阶段 2 规则加固）

| 风险 | 说明 |
|------|------|
| 电感 vs 磁珠 | 得捷将「铁氧体磁珠和芯片」放在 **滤波器** L1；我们 taxonomy 映射为 `ferrite_bead`（130303） |
| 电容 vs 馈通 | 「馈通式电容器」在滤波器 L1，映射 `feedthrough_capacitor`（130304） |
| 套件 | 「EMI，滤波器套件」在 **套件** L1，勿收入 filter gate |
| 官网类目漂移 | 报告中有「共模扼流圈」等 Web 独有路径，库内抓取约 27k vs 官网 ~47k |

---

## 7. 对阶段 2 的输入清单

1. **gate**：`data_source=digikey`，`category_in` = 上表 10 个主叶子（见 `seed/digikey_leaf_to_l3.csv`）
2. **classify**：每叶子 `category_eq` → `l3_id`（`schema_version=v1.5.30`）
3. **验收**：`test_dwd.dwd_component_class_filter` 行数 ≈ 27,213
4. **商城核对**：每 L3 抽 5～10 条 → `artifacts/filter/filter_class_review_*.tsv`

---

## 8. 阶段 1 完成判定

- [x] 字段覆盖率表
- [x] 叶子词频 Top
- [x] prajson 键 Top（或注明替代来源）
- [x] 分层抽样 TSV
- [x] 摸底笔记

**可进入阶段 2**（编写 `dim_l3_classify_rule_filter.csv` + test 跑数 + 商城核对）。
