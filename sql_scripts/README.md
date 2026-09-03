# sql_scripts 说明

本目录存放 **StarRocks / MySQL 协议** 可执行的 DDL、增量 SQL 与运维脚本，覆盖 ICDPDF/eCloud 底座、L3 分类（多 L1 合并）、属性标准化。

> **新 L1 分类 + 属性清洗端到端总图**：[`L1_STD_PIPELINE.md`](L1_STD_PIPELINE.md)
>
> **DWS / ADS 分层设计（评审稿）**：[`DWS_ADS_PIPELINE.md`](DWS_ADS_PIPELINE.md)

测试 / 生产分离：
- **生产**：`dim` / `dwd`（受 `ALLOW_PROD=1` 保护）。
- **测试**：`test_dim` / `test_dwd`（默认目标）。`ods` test/prod 共享只读。

连接参数见 **`local.env.example`**；实际 **`local.env`** 放在 **`sql_scripts/`** 下且不入库（见仓库 `.gitignore`）。

---

## 1. 目录一览

| 路径 | 作用 |
|------|------|
| **`foundation/`** | **通用底座**：ODS→DWD 明细与参数、`dim_icpdf_pdf`、`dwd_ecloud_component_detail`，以及全量 taxonomy **`dim_l3_classify_all.sql`**；含批量回填 **`clean_all_partitions.sh`**（按分区清洗进 `dwd_icpdf_component_detail`，需与 **`dwd_icpdf_component_detail.sql`** 语义对齐）。 |
| **`1.classify/`** | **ICDPDF L3 分类（多 L1 合并：resistor + diode + capacitor）**：dim 维表 DDL（`dim_l3_classify.sql` / `dim_l3_classify_rule.sql`）+ **CSV 种子数据** `seed/*.csv` + **loader** `load_seed.py/.sh`；构建 `dwd_component_class`（INNER JOIN best，未分类不入表）；规则语义见 **`RULE_ENGINE.md`**；新 L1 端到端总图见 **`L1_CLASSIFY_PIPELINE.md`**。一键入口 **`run_classify.sh test\|prod`**。 |
| **`2.attribute_standard/`** | **属性标准化（多 L1 合并）**：dim 三表 DDL（`dim_attr_schema.sql` / `dim_attr_extract_rule.sql` / `dim_unit_factor.sql`）+ **CSV 种子数据** `seed/*.csv` + **loader** `load_seed.py` / `sync_attr_std_seed.sh`；统一 EAV `build_dwd_icpdf_component_attr_std.sql` → 各 L2 宽表（都带品牌标准化 `dim.v_std_brand_alias`）。品牌字典：`dim_std_brand.sql` + `dim_std_brand_manual_extra.sql` + `v_std_brand_alias.sql`，详见 **`CONTRIB_BRAND.md`**。|
| **`exports/`** | 抽样、导出类 SQL（及配套 `.sh`）。 |

个别脚本头部的历史路径仍可能写作 `pipelines/`、`分类/`；执行时改用上表 **`foundation/`**、`1.classify/` 等现行目录。

---

## 2. 推荐依赖顺序（从底向上）

以各文件头部注释为准；这里是整体串联关系。

| 次序 | 内容 |
|------|------|
| 1 | **全量 taxonomy**：`foundation/dim_l3_classify_all.sql` |
| 2 | **明细与参数**：`foundation/dwd_icpdf_component_detail.sql` → `foundation/dwd_icpdf_component_param.sql`；可选用 `foundation/dim_icpdf_pdf.sql`、`foundation/dwd_ecloud_component_detail.sql` |
| 3 | **L3 分类（多 L1）**：`1.classify/load_seed.sh prod`（DDL + CSV 装载） → `1.classify/dwd_component_class.sql`；或一键 `1.classify/run_classify.sh test\|prod` |
| 4 | **属性标准化**：`2.attribute_standard/` dim → 窄表 → DDL → 宽表（或 **`run_attr_std.sh`**） |

**历史分区大批量回填 ICDPDF DWD**：`foundation/clean_all_partitions.sh`。

---

## 3. 执行方式示例

```bash
mysql -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" \
  --default-character-set=utf8mb4 -D dim < sql_scripts/foundation/dim_l3_classify_all.sql
```

环境与一键脚本由各 **`run_*.sh`、`clean_all_partitions.sh`** 自行加载 **`local.env`** 或 **`MYSQL_*`**（以脚本为准）。

---

## 4. 关于 `.gitignore` 与 `*.sh`

仓库可能对 **`*.sh`** 大范围忽略并对少数路径放行。当前 **`sql_scripts` 内需提交的一键脚本**（以仓库实际为准）：如 `foundation/clean_all_partitions.sh`、`1.classify/run_classify.sh`、`1.classify/load_seed.sh`、`2.attribute_standard/run_attr_std.sh`、`exports/*.sh`。若无脚本则用各 SQL 头部的 `mysql … < …` 手动跑。

## 5. 1.classify seed 数据流（多 L1 合并）

- **种子**：`1.classify/seed/dim_l3_classify.csv`（taxonomy 35 行）、`1.classify/seed/dim_l3_classify_rule.csv`（规则 148 行）。
  - 空单元格 = SQL NULL。
  - `match_values` 列为 ARRAY，存 JSON 数组字面量（如 `["A","B"]`）。
  - `match_map` 列为 MAP，存 JSON 对象字面量（如 `{"k":"v"}`）。
- **DDL**：`1.classify/dim_l3_classify.sql` / `dim_l3_classify_rule.sql` 仅含 `DROP+CREATE`。
- **装载**：`bash 1.classify/load_seed.sh test` 写 `test_dim`；`ALLOW_PROD=1 bash 1.classify/load_seed.sh prod` 写 `dim`。
- **新增 L1**：仅在两份 CSV 追加行（rule_id 用 `<l1>_*` 前缀）；不改 DDL，不改 build SQL。

发布流程建议（test → prod）：
1. PR 内修改 CSV/DDL；本机 `bash 1.classify/load_seed.sh test` 装载 → 用 hash 对比 prod。
2. 跑 `dwd_component_class.sql`（目前仍直写生产 dwd；占位符化在 PR1）。
3. 合 main → `ALLOW_PROD=1 bash 1.classify/run_classify.sh prod` 重建 prod。

---

## 6. 不要随意执行（除非已评审）

- **一次性迁移 / DROP / `ALTER`** 类 SQL；
- 由生成器/临时脚本写出的 `.sql`（若其他目录中带 `generated/` 等）：先改生成链或评审再执行。

设计及评测类长文通常在仓库 **`exports/`** 或顶层 **`docs/`**，与 DDL 主链路区分开即可。
