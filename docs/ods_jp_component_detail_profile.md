# `ods.ods_jp_component_detail` 数据质量探查报告

- **数据源**：JP 业务爬取的器件主数据（ODS 层）
- **探查时间**：2026-04-20（写报告时仍在持续写入，最新行数随时可能上浮）
- **主键**：`id`（VARCHAR(64)）
- **存储**：Primary Key（LZ4），8 个 bucket，云原生 persistent index

---

## 0. 表结构（摘）

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | VARCHAR(64) | 主键 / 组件 ID |
| `cat_id` | VARCHAR(64) | 分类 ID（关联 `ods_jp_category.id`） |
| `name` | VARCHAR(256) | 名称/型号 |
| `picture` | VARCHAR(512) | 图片 URL |
| `brand_name` | VARCHAR(256) | 品牌名称 |
| `brand_id` | VARCHAR(64) | 品牌 ID |
| `supplier` | VARCHAR(256) | 供应商 |
| `extended_attributes` | VARCHAR(65533) | 扩展属性（JSON 字符串） |
| `description` | VARCHAR(65533) | 描述文本 |
| `encapsulation` | VARCHAR(128) | 封装 |
| `data_sheet` | VARCHAR(65533) | 数据手册（JSON 数组） |
| `eccn` | VARCHAR(64) | ECCN 出口管制编码 |
| `create_at` / `update_at` | DATETIME | 入库 / 更新时间 |

---

## 1. 规模总览

| 指标 | 值 |
|------|------|
| 总行数 | **2,507,039** |
| 去重 `id` | 2,506,751（与行数一致，主键唯一） |
| 去重 `name` | 2,489,006（≈ 99.3% 唯一） |
| 去重 `brand_name` | 1,330 |
| 去重 `brand_id` | **0**（字段完全未填） |
| 去重 `cat_id` | 198 |
| 去重 `supplier` | 8（且仅 19 行有值） |
| 去重 `encapsulation` | 6,020 |
| 去重 `picture` URL | 60,652 |
| 去重 `data_sheet`（整串 JSON） | 1,555,755 |
| `create_at` 范围 | 2026-02-06 15:08:51 ~ 2026-04-21 13:43:39 |
| `update_at` 范围 | 同上 |

**关键异常**

- `brand_id`、`eccn` **字段常量 NULL/空**，占表空间不贡献任何信息。  
- `supplier` 仅 19 行有非空值（其中 `Kingbright` 5 条、`STMicroelectronics` 4 条等），在业务上基本不可用。  
- `picture` 仅 60,652 个去重 URL，对应 3 张高度复用的缩略图（一张 `media.d…` 模板被 100 万+ 行复用），应作“图片是否缺省”语义看待，不能当作真正唯一图。

---

## 2. 批次分布（按 `create_at` 当天）

| create_at 日期 | 行数 |
|----------------|------|
| 2026-02-06 | 11,739 |
| 2026-03-23 | 114,465 |
| 2026-03-24 | 152,268 |
| 2026-03-25 | 165,832 |
| 2026-03-26 | 307,633 |
| 2026-03-27 | 434,278 |
| 2026-03-28 | 518,605 |
| 2026-04-21 | 801,931+（今日仍在写入） |

**解读**

- 只有少数几天有大量写入；中间 20 多天完全无记录，符合“每次全量抓取后间隔几周”的业务节奏。  
- `create_at = update_at` **100% 成立**（全表 2,506,751 行），说明这张表**从未做过 upsert 更新**，只有 INSERT；下游不能依赖 `update_at` 判断“被改动过”。

---

## 3. 字段空值率

| 字段 | NULL 或 '' | 占比 | 备注 |
|------|-----------|------|------|
| `cat_id` | 0 | 0% | ✅ 全部有值 |
| `brand_name` | 0 | 0% | ✅ 全部有值 |
| `encapsulation` | 0 | 0% | ⚠️ 但 20.83%（522,342 行）取值 `'-'`，等同空值 |
| `name` | 81 | 0.003% | 可接受 |
| `ext_attr`（extended_attributes） | 112,536 | 4.49% | 非空均为合法 JSON 起始符（详见 §6） |
| `data_sheet` | 262,074 | 10.45% | 非空均为 JSON 数组 |
| `description` | 372,540 | 14.86% |  |
| `picture` | 1,031,087 | **41.13%** | 缺失率最高的业务字段 |
| `supplier` | 2,506,732 | **99.9992%** | 几乎全空 |
| `brand_id` | 2,506,751 | **100%** | 字段**全部为空** |
| `eccn` | 2,506,751 | **100%** | 字段**全部为空** |

---

## 4. 字符串长度分布

| 字段 | min | max | avg | p50 | p90 | p99 |
|------|-----|-----|-----|-----|-----|-----|
| `name` | 1 | 59 | 16.20 | 15 | 24 | 39 |
| `description` | 1 | 388 | 67.19 | 68 | 119 | 185 |
| `extended_attributes` | 2 | **1,889** | 326.32 | 362 | 434 | 527 |
| `data_sheet` | 2 | 285 | 96.07 | 107 | 107 | 125 |
| `picture` | 27 | 156 | 84.82 | 83 | 107 | 107 |
| `encapsulation` | 1 | 49 | 4.21 | 4 | 8 | 15 |

**解读**

- `extended_attributes` 即便 p99 也只有 527 字符，当前 `VARCHAR(65533)` 严重过宽。若下游要建清洗表，可以缩到 `VARCHAR(2048)` 并建 BITMAP/Inverted 索引。  
- `data_sheet` 始终是 JSON 数组字符串，长度集中在 107–125，通常就是一条 URL 被 JSON 包裹（见 §6）。  
- `description` 短文本（p99≤185），适合全文索引。  
- `encapsulation` 有 49 字符的“长串封装”，需要在 DWD 层做规范化截断。

---

## 5. 维度 Top-K

### Top-15 品牌（按行数）

| 品牌 | 行数 |
|------|------|
| 威世-VISHAY | 309,421 |
| 兴亚-KOA | 176,047 |
| 楼氏-Knowles | 155,773 |
| 国巨-YAGEO | 116,517 |
| SCHURTER | 110,307 |
| SITIME | 109,950 |
| VICOR | 108,198 |
| 基美-KEMET | 104,765 |
| 松下-PANASONIC | 68,020 |
| 京瓷-kyocera | 65,561 |
| 德州仪器-TI | 54,718 |
| 美国微芯-MICROCHIP | 53,235 |
| ABRACON | 46,780 |
| 安森美-ON | 43,993 |
| 亚德诺-ADI | 36,716 |

- 品牌命名混合"**中文名-英文名**"（如"威世-VISHAY"）与"**纯英文名**"（如 SCHURTER），大小写也不统一（如"京瓷-kyocera"）。下游若做跨源聚合，先按 `ods_jp_brand.abbr` 重映射。

### Top-15 分类（`cat_id`）

| cat_id | 行数 |
|--------|------|
| 1435793826139865088 | 524,925 |
| 1435521118185455616 | 354,678 |
| 1435532540223160320 | 219,281 |
| 1435531995185938432 | 141,030 |
| 1435793348790321152 | 123,805 |
| 1435793881647284224 | 109,770 |
| 1435521672739553280 | 65,514 |
| 1435532083102744576 | 63,412 |
| 1435521318106955776 | 53,429 |
| 1435531725831929856 | 49,123 |
| 1435516606548803584 | 47,782 |
| 1435521918311858176 | 43,729 |
| 1435521030511919104 | 39,962 |
| 1435532430101708800 | 38,379 |
| 1435522305878130688 | 33,161 |

### Top-15 封装

| encapsulation | 行数 |
|--------------|------|
| - | 522,342 |
| 0805 | 179,205 |
| 1206 | 164,075 |
| 0603 | 149,846 |
| 4-SMD | 134,648 |
| 轴向 | 111,710 |
| 0402 | 93,246 |
| 6-SMD | 81,066 |
| 1210 | 72,192 |
| 径向 | 67,012 |
| 全砖 | 54,212 |
| 1812 | 38,790 |
| 8-SOIC | 30,434 |
| 1808 | 24,579 |
| 半砖 | 22,870 |

> **`encapsulation = '-'` 占 20.83%**，等同“无封装信息”，DWD 清洗应将其转为 NULL。

### supplier 全量值域（非空 19 行）

| supplier | 行数 |
|----------|------|
| Kingbright | 5 |
| STMicroelectronics | 4 |
| ams | 2 |
| TDK Corporation | 2 |
| Diodes Incorporated | 2 |
| Dialight | 2 |
| Molex | 1 |
| pSemi | 1 |

---

## 6. `data_sheet` / `extended_attributes` 内容校验

### `data_sheet`

- 始终是 JSON 数组字符串：`["http…"]`。
- Top 前缀：
  | 前缀 | 行数 |
  |------|------|
  | `["http://jpfile` | 1,393,790 |
  | `["https://atta.` | 218,360 |
  | `["https://www.v` | 83,362 |
  | `["https://www.s` | 64,484 |
  | `["http:https://` | 47,381（**脏数据**：协议重复拼接） |
- 文件扩展 Top：`.pdf`（2,075,697）、`.aspx`、`en`、`08` 等。
- **建议**：下游 DWD 清洗按 `json_array_elements` 展开为多行 URL，并匹配正则 `^(https?://)+` 去重前缀。

### `extended_attributes`

| 形态 | 行数 |
|------|------|
| 合法 JSON 开头（`{` 或 `[`） | 2,394,215 |
| 非 JSON 但非空 | 0 |
| 空 | 112,536 |
| 带 `"dimensions"` 键 | 2,394,212（≈ 100% 合法 JSON 均含此键） |

**结构示例（截断）**

```json
{"dimensions":{"元器件封装":"0603","工作温度最大值(℃)":"--","电阻精度(%)":"±5%","电阻阻值(Ω)":"33KΩ", ...}}
```

- 一级键固定为 `dimensions`，下挂业务参数对象。键名是中英文混排、末尾常带 `:`，属性值大量以 `"--"` 表示“缺省”，实际参数填充率远低于键数。
- **建议**：DWD 清洗把 `"--"` / 空串统一映射 NULL，再把 `dimensions` 对象拍平成 `(id, attr_key, attr_value)` EAV，单独落一张参数明细表便于检索。

---

## 7. `picture` / URL 协议

| 协议 | 行数 |
|------|------|
| `https://` | 1,036,536 |
| `http://`  | 438,859 |
| 空 | 1,031,087 |
| `https:…`（脏，缺少 `//`） | 269 |

**脏示例**：`https:https://…`、`https:1,3k Ohm …`、`https:/ptm/s/st…` 等 269 行（占比 0.01%）为历史爬虫拼接错误，建议在 DWD 清洗时丢弃/修正。

**图片资源集中**

| tier | 行数 |
|------|------|
| `http://jpfile…` | 438,859（自有 CDN） |
| `https://media.d…`（DigiKey media） | 1,036,536 |
| 其他 https | 0 |
| 其他 http | 0 |
| 脏 | 269 |
| 空 | 1,031,087 |

> 几乎所有图片要么来自 `jpfile` 自有 CDN，要么来自 DigiKey `media.d…` 模板——**这两个 URL 集合是“分类级缩略图”而非“每个 SKU 一张图”**，在检索展示里要预期大量重复图。

---

## 8. 名称 (`name`) 重复情况

| 组别 | 去重 name | 行数 |
|------|----------|------|
| 仅出现 1 次 | 2,476,043 | 2,476,043 |
| 出现 ≥ 2 次 | 12,963 | 30,627 |

**Top 10 重复 name**（每条的品牌数 ≈ 条数，说明是同型号在不同品牌 SPU 之间出现）

| name | 条数 | 品牌数 |
|------|-----|--------|
| BAV99 | 30 | 30 |
| SS14 | 28 | 28 |
| 1N4148WS | 27 | 27 |
| BAT54C | 26 | 26 |
| S8550 | 24 | 24 |
| BAV70 | 24 | 24 |
| 1N4148W | 24 | 24 |
| ES1D | 22 | 22 |
| ABS10 | 22 | 22 |
| SS34 | 22 | 22 |

- 都是行业**通用分立器件**（肖特基、开关二极管、三极管），跨品牌命名一致，不是脏数据。  
- 下游跨表关联务必用 `(name, brand_name)` 复合键，不要拿 `name` 当单独维度。

---

## 9. 时间字段健康度

| 指标 | 值 |
|------|------|
| `create_at IS NULL` | 0 |
| `update_at IS NULL` | 0 |
| `create_at > update_at` | 0 |
| `create_at = update_at` | **2,506,751（全表）** |
| `create_at < update_at` | 0 |

**结论**：`update_at` 字段形同虚设，所有行的入库时间等于更新时间——业务上不存在“二次修订”的语义，这在下游做 CDC/增量同步时要特别注意。

---

## 10. 与外部维表 / 其他事实表的交叉覆盖

### 维表外键完整性

| 来源字段 | distinct | 在目标表能匹配到 | 覆盖率 |
|----------|----------|-----------------|--------|
| `cat_id` → `ods_jp_category.id` | 198 | **198** | **100.00%** |
| `brand_name` → `ods_jp_brand.name` | 1,330 | 1,330 | 100.00% |
| `brand_name` → `ods_jp_brand.abbr`（辅） | 1,330 | 36 | 2.71% |
| `encapsulation`（排除 `-`/空） → `ods_jp_encapsulation.name` | 6,019 | 6,018 | 99.98% |
| `encapsulation` → `ods_jp_encapsulation.code` | 6,019 | 0 | 0% |

- **分类 / 品牌 / 封装**三条外键链完整可用（用 `name/id` 维度即可），**但 `brand_id` 字段本身全空**，必须走 `brand_name` 反查。  
- `ods_jp_encapsulation.code` 与 ODS 的 `encapsulation` 文本不对齐，统一用 `name`。

### 与 ICPDF PDF 库的交叉

| 指标 | 值 |
|------|------|
| `ods_jp_component_detail` 去重 `name`（非空） | 2,489,294 |
| 与 `dwd_icpdf_component_detail.partno` 精确匹配的 name | **1,784,697** |
| 匹配率 | **71.70%** |

> 每 10 个 JP 器件里有 ~7 个能在 ICPDF 找到至少一份对应 PDF，是做“器件-规格书"融合的可观入口。剩余 ~28% 未匹配，多为带后缀的 SKU 型号（如 `BAV99-7-F`）、或 ICPDF 未收录的本土品牌，后续可做 `LIKE partno%` 前缀补救。

---

## 11. 数据质量问题汇总与建议

| 编号 | 问题 | 影响 | 建议处理 |
|------|------|------|----------|
| DQ-1 | `brand_id`、`eccn` **全部为空** | 字段冗余 | 在 DWD 层丢弃；或从 `brand_name` 反查 `ods_jp_brand.id` 填充 `brand_id` |
| DQ-2 | `supplier` 99.9992% 为空（仅 19 行） | 基本无用 | DWD 层不保留 |
| DQ-3 | `update_at` 恒等 `create_at` | 无增量语义 | CDC 以 `id` + 源端版本字段（如 `extended_attributes` hash）为准 |
| DQ-4 | `encapsulation` 有 20.83% 取值 `-` | 聚合污染 | 统一转为 NULL |
| DQ-5 | `picture` 269 行协议拼接错误（`https:https://…` 等） | 前端图片加载失败 | 正则 `^(https?:)+//` 清洗 |
| DQ-6 | `data_sheet` 47,381 行以 `["http:https://` 开头 | 同上 | 同上 |
| DQ-7 | `extended_attributes` 中 `"--"` 代表“缺省”却作为字符串存在 | BI 聚合把 "--" 当真实枚举 | DWD 清洗时转 NULL |
| DQ-8 | `brand_name` 命名不一致（中英混排/大小写） | 跨源聚合困难 | 按 `ods_jp_brand.name` 做字典映射统一 |
| DQ-9 | `picture` 41% 为空 | 图文展示残缺 | 用 ICPDF 的 `big_img` 或 DigiKey/官网做二次补图 |
| DQ-10 | 表层不做分区，主键表已有 250 万行 | 大范围查询会扫全表 | 若日后超过 ~2000 万行，考虑按 `DATE(create_at)` 建 RANGE 分区 |

---

## 12. 对下游 DWD / DM 的建模建议

1. **瘦身 DWD**：裁掉 `brand_id`、`eccn`、`supplier` 三列空字段；`extended_attributes`、`data_sheet` 缩宽到 `VARCHAR(2048)` 和 `VARCHAR(1024)`。
2. **维表关联**：
   - `cat_id` → `dim_category`
   - `brand_name` → `dim_brand`（顺便把 `ods_jp_brand.id` 回填为 `brand_id`）
   - `encapsulation` → `dim_encapsulation`（过滤 `-`）
3. **参数明细展平表**：对 2,394,212 行合法 JSON，按 `extended_attributes.dimensions` 展开为 `(id, attr_key, attr_value_clean)`，`"--"`/`""` 映射 NULL，落入 `dwd_jp_component_attribute`，便于参数检索。
4. **PDF 融合**：在 DM 层直接 `LEFT JOIN dwd_icpdf_component_detail ON name = partno`，71.70% 行可命中；未命中的走前缀匹配兜底。
5. **图片规范化**：新建 `image_url_clean` 字段（补 `https:` 前缀、去重协议、白名单域），空串直接落 NULL。
6. **增量同步**：既然 `update_at` 不可信，**增量捕获建议按 `create_at >= ${last_watermark}` 单侧窗口拉取**，下游按 `id` upsert。

---

> 本报告所有统计为直连 StarRocks（`192.168.19.21:9030/ods`）实时查询，数据在报告期间仍在增长（~±数千行），对百分比结论影响可忽略。
