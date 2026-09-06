# ecloud resistor 阶段 1 摸底笔记

- **源表**：`dwd.dwd_ecloud_component_param`（`data_source='ecloud'`）
- **L1 gate**：`category = '电阻'`（ecloud 中文一级类）
- **prod L1**：`resistor`（11 个 L3：fixed/variable/protective_sensitive）
- **探查日期**：20260714

## 1. 规模与 gate 候选

| 指标 | 值 |
|------|-----|
| ecloud 全表行数 | 3,559,619 |
| 一级类 `电阻` 行数 | 1,228,372（34.51%） |
| 去重 partno | 1,227,570 |
| prajson 覆盖率 | 1,206,368 / 1,228,372（98.21%） |
| brandshort 非空 | 1,228,372（100.00%） |
| category2 非空 | 1,228,372（100.00%） |
| datasheet_url 非空 | 1,154,711（94.00%） |
| 去重 category2 | 6 |
| 与 icpdf partno 重叠（去重型号） | 205,836 |
| 与 digikey partno 重叠（去重型号） | 51,823 |

**Gate 白名单（草案）**：`category_in = ['电阻']`

**边界探针**：
- 非 `电阻` 一级类但含 `电阻阻值/电阻精度` 键的行：56（需 gate NOT 排除或接受漏入）
- `电路保护` 下含熔断/电阻 category2：13,710（可能与 `fusible_resistor` L3 交叉，阶段 2 核对）

## 2. 邻近品类边界（待阶段 2 商城核对）

- ecloud `电阻` 一级类应覆盖 prod `resistor` 三 L2（固定/可调/保护敏感），但 **category2 是商城二级导航**，与 prod L2/L3 不一一对应。
- **热敏/压敏/熔断电阻**可能在 `电阻` 或 `电路保护` 一级类下重复出现，分类规则需按 prajson `类型` + category2 联合判定。
- **排阻/电阻网络**可能在 category2=`排阻` 或固定电阻桶内，需 `端子数`/`类型` 辅助。
- 勿与 `无源器件` 下其他阻性元件（如吸收网络）混淆——以 category2 + `类型` 词频为准。

## 3. 源端坑（机器统计 + 待人工 TSV 复核）

1. **键名双轨**：`封装/外壳` vs `元器件封装`；`大小/尺寸` vs `大小 / 尺寸`（空格差异）——同语义多 key。
2. **占位符**：value 为 `-` / 空 / `null` 仍常见；EAV 阶段需过滤。
3. **复合字段**：阻值/精度/功率可能带单位后缀或容差写在同一 value（待抽样确认）。
4. **category2 大桶**：部分二级类 prajson 稀疏（见下表），分类不能单靠 category2。
5. **中文品牌前缀**：`国巨-YAGEO`、`风华高科` 等，品牌标准化走 `dim_std_brand`（只读）。

### 3.1 核心电阻键覆盖（非占位）

| prajson 键 | 命中行 | 占 has_prajson |
|------------|--------|----------------|
| `电阻精度(%)` | 1,100,126 | 91.2% |
| `电阻阻值(Ω)` | 1,088,581 | 90.2% |
| `温度系数(ppm/℃)` | 1,054,930 | 87.5% |
| `元器件封装` | 1,040,487 | 86.2% |
| `封装/外壳` | 986,237 | 81.8% |
| `成分` | 980,526 | 81.3% |
| `端子数` | 968,641 | 80.3% |
| `零件状态` | 899,073 | 74.5% |
| `特性` | 834,715 | 69.2% |
| `制造商` | 832,548 | 69.0% |
| `系列` | 830,682 | 68.9% |
| `功率(W)` | 389,532 | 32.3% |

### 3.2 prajson `成分` Top 值（L3 分类辅助信号；无 `类型` 键）

电阻子集 **不存在** 通用 `类型` 键（120 万行全为 NULL）。分类应联合 **category2 + `成分` + `特性`**：

| 成分值 | 行数 |
|--------|------|
| 金属薄膜 | 343,664 |
| 薄膜 | 265,872 |
| 厚膜 | 228,561 |
| 绕线 | 78,556 |
| 金属箔 | 21,951 |
| 金属氧化物薄膜 | 17,210 |
| 金属元素 | 8,757 |
| 炭膜 | 7,673 |

### 3.3 功率键三轨（属性抽取须合并）

| 键名 | 非占位命中行 | 占 has_prajson |
|------|-------------|----------------|
| `额定功率(W)` | 557,321 | 46.2% |
| `功率(W)` | 389,532 | 32.3% |
| `功率（W）`（全角括号） | 143,341 | 11.9% |

三键并集覆盖率需阶段 3 用多规则 + priority 合并到 `power_rating_w`。

### 3.4 prod L3 与 ecloud category2 对照（边界）

| prod L3 | ecloud 信号 | 行数/备注 |
|---------|-------------|-----------|
| general_fixed_resistor | category2=`贴片电阻`/`插件电阻` | 115.6 万（主桶） |
| resistor_array_network | category2=`排阻` | 31,155；prajson 缺 4,270 行 |
| wirewound_resistor | `成分`=绕线 | 78,556（跨 category2） |
| current_sense_resistor | `特性` 含电流检测/感应 | 27,227 |
| trimmer_potentiometer / potentiometer | category2=`可调电阻` | 14,992 |
| ntc_thermistor | category2=`NTC热敏电阻` | 7,930 |
| ptc_thermistor | **不在电阻一级类** | 电阻类仅 1 行；`电路保护` 等其它类 6,010 行 |
| varistor_mov | **不在电阻一级类** | 0；`电路保护` 压敏 13,710 行 |
| fusible_resistor | **不在电阻一级类** | 0；`电路保护` 熔断相关 13,710 行 |
| other_sensitive_resistor | 待商城核对 | — |

> **关键结论**：ecloud 把 NTC 放在 `电阻` 下，但 PTC/压敏/熔断主要在 `电路保护`——阶段 2 需决定是否在 resistor gate 外做跨 L1 召回，或与 circuit_protection 协调互斥。

### 3.5 category2 × prajson 覆盖

| category2 | 行数 | has_prajson | 覆盖率 |
|-----------|------|-------------|--------|
| 贴片电阻 | 760,288 | 746,158 | 98.1% |
| 插件电阻 | 396,126 | 395,599 | 99.9% |
| 排阻 | 31,155 | 26,885 | 86.3% |
| 底座安装电阻器 | 17,881 | 17,686 | 98.9% |
| 可调电阻 | 14,992 | 12,407 | 82.8% |
| NTC热敏电阻 | 7,930 | 7,633 | 96.2% |

## 4. 候选标准属性映射（阶段 3 输入）

| prajson 中文键 | 候选 std_attr_code | 备注 |
|----------------|-------------------|------|
| 电阻阻值(Ω) / 阻值 | resistance_ohm | 主阻值；需单位解析 |
| 电阻精度(%) / 精度 | tolerance_pct | |
| 温度系数(ppm/℃) | tcr_ppm_per_c | |
| 功率(W) / 额定功率(W) / 功率（W） | power_rating_w | 三键合并 |
| 元器件封装 / 封装/外壳 | package_case | 双 key |
| 成分 | （分类信号） | 厚膜/绕线/金属箔等 |
| 端子数 | terminal_count | 排阻网络 |
| 特性 | features | 文本 |
| 零件状态 | lifecycle_status | |
| 制造商 / 系列 | manufacturer / series | |
| 最大/最小工作温度(℃) | temp_max_c / temp_min_c | |

## 5. 数据健康度

- 全量表，无分区断档。
- 电阻子集 prajson 覆盖 **98.2%**（22,004 行缺失；排阻 4,270 + 贴片 14,130 为主）。
- datasheet **94.0%** 有值。

## 6. 与已接入源差异（resistor 已上线 icpdf + digikey）

| 维度 | icpdf / digikey | ecloud |
|------|-----------------|--------|
| 分类字段 | 英文/混合 category | **中文** category/category2 |
| 参数 KV | prajson2 / digikey KV | prajson **中文键**（别名 prajson2） |
| source_kind | prajson2_key_eq / digikey_param_kv_eq | `ecloud_dim_kv_eq` 或 prajson_cn_eq |
| 型号重叠 | 基准源 | 与 icpdf/digikey 部分重叠，靠 data_source 隔离 |

## 7. category2 词频 Top 20（gate/L3 种子）

| category2 | 行数 |
|-----------|------|
| 贴片电阻 | 760,288 |
| 插件电阻 | 396,126 |
| 排阻 | 31,155 |
| 底座安装电阻器 | 17,881 |
| 可调电阻 | 14,992 |
| NTC热敏电阻 | 7,930 |

## 8. 阶段 2 沙盒结果（2026-07-14）

分类沙盒 `test_dwd.dwd_component_class_resistor`（ecloud）：

| L3 | 行数 |
|----|------|
| general_fixed_resistor | 1,069,891 |
| wirewound_resistor | 77,177 |
| resistor_array_network | 31,155 |
| current_sense_resistor | 27,227 |
| potentiometer | 14,528 |
| ntc_thermistor | 7,930 |
| trimmer_potentiometer | 464 |
| **合计** | **1,228,372（100% gate 命中）** |

EAV P0（fixed_resistor L2）：`resistance_ohm` 90.3% · `power_rating_w` 89.0% · `package_case` 97.8%

商城核对样本：`classify_sample_ecloud_20260714.tsv`（7 L3 × 5 条）

运行：`bash sql_scripts/test/resistor/run_test.sh`

## 9. 阶段 2 前置检查清单

- [x] 沙盒分类规则写入 `test_dim.dim_l3_classify_rule_resistor`
- [x] 沙盒跑通 classify + EAV + L2
- [ ] 人工浏览 `ecloud_source_sample_<date>.tsv`（大小厂分层）
- [ ] 商城核对填 `classify_sample_ecloud_<date>.tsv`
- [ ] PTC/压敏/熔断跨 L1 召回业务决策
