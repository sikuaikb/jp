# `sql_scripts/test/` · 测试库后缀开发流程

新 L1 标准化（分类规则 + 属性抽取规则）必须先在测试库**带后缀**完整验证，验证通过后才能调用 skill / 走 CONTRIB.md 合入主流程。

> 本目录脚本受 `.gitignore` 白名单管理，新增 `.sh` 需要在白名单里加一行才能 commit。

---

## 1. 命名约定（**强隔离**）

开发 / 测试期的共享表都带 `_<l1>` 后缀，避免多人互踩；L2 宽表名本身已包含 L1，固定为 `dwd_l2_{l1}_{l2}`，不再额外追加 `_<l1>`：

| 类型 | prod 主表（无后缀） | 测试期表（带后缀，**强隔离**） |
|---|---|---|
| L3 分类树 | `dim.dim_l3_classify` | `test_dim.dim_l3_classify_<l1>` |
| L3 分类规则 | `dim.dim_l3_classify_rule` | `test_dim.dim_l3_classify_rule_<l1>` |
| 属性 schema | `dim.dim_attr_schema` | `test_dim.dim_attr_schema_<l1>` |
| 属性抽取规则 | `dim.dim_attr_extract_rule` | `test_dim.dim_attr_extract_rule_<l1>` |
| 单位换算（如需扩展） | `dim.dim_unit_factor` | `test_dim.dim_unit_factor_<l1>_supplement`（仅 delta） |
| 分类结果 | `dwd.dwd_component_class` | `test_dwd.dwd_component_class_<l1>` |
| 属性窄表 EAV | `dwd.dwd_component_attr_std` | `test_dwd.dwd_component_attr_std_<l1>` |
| L2 宽表 | `dwd.dwd_l2_{l1}_{l2}` | `test_dwd.dwd_l2_{l1}_{l2}` |
| ODS 适配（如新源） | `dwd.dwd_<source>_component_param` | `test_dwd.dwd_<source>_component_param_<l1>` |

> 为什么 strict 加后缀？多人并行试点时（电感、PMIC、驱动 IC……）共用 `test_dim` / `test_dwd` 不会互踩。

### 1.1 业务编码命名

- `l1_code` / `l2_code` / `l3_code` / `std_attr_code` / L2 宽表业务列名统一使用 lowercase snake_case：只用小写字母、数字和 `_`
- `l2_code` 不使用 `_base` 后缀；如果分类树文档里出现 `xxx_base`，落表前改成 `xxx`
- L2 宽表名跟随 `l2_code`：`dwd_l2_{l1}_{l2}`，其中 `{l2}` 也必须是 lowercase snake_case
- 属性列名和 `std_attr_code` 保持一致，避免同一个属性在 schema / EAV / L2 宽表中出现多套命名

---

## 2. 测试脚本目录约定

每个 L1 试点独立目录：

```text
sql_scripts/test/<l1>/                   # 例：sql_scripts/test/inductor/
├── README.md                            # 本 L1 的范围、参考资料、当前进度
├── seed/                                # 该 L1 的 dim 种子草稿（CSV）
│   ├── dim_attr_schema_<l1>.csv
│   ├── dim_attr_extract_rule_<l1>.csv
│   ├── dim_l3_classify_<l1>.csv
│   └── dim_l3_classify_rule_<l1>.csv
├── build_dwd_component_class_<l1>.sql           # 复制 dwd_component_class.sql + 改后缀
├── build_dwd_component_attr_std_<l1>.sql        # 复制 build_dwd_component_attr_std_icpdf.sql + 改后缀
├── dwd_l2_<l1>_<l2>.sql + build_*.sql           # 各 L2 DDL + build
└── run_test.sh                          # 一键端到端（建后缀表 + 装载 + 验证）
```

`run_test.sh` 模板可参考 `sql_scripts/test/run_test_dwd_e2e.sh`（DigiKey 多源 e2e 验证版）。

> `sql_scripts/test/<l1>/` 在合并主流程后**全部删除**（cleanup 见 §5）。开发期可正常 commit 到分支，方便回滚和 review。

---

## 3. 开发 → 合并 三阶段

> **端到端流程图**：[`../L1_STD_PIPELINE.md`](../L1_STD_PIPELINE.md)（分类 + 属性） · [`../1.classify/L1_CLASSIFY_PIPELINE.md`](../1.classify/L1_CLASSIFY_PIPELINE.md)（仅分类）

### 阶段 1：测试库开发与验证

| 步骤 | 动作 |
|---|---|
| 1.1 | 在 `sql_scripts/test/<l1>/seed/*.csv` 编辑该 L1 的分类规则 / 属性抽取规则 |
| 1.2 | 写 `build_*.sql`，源表读 `dwd.dwd_<source>_component_param`（prod，只读），写表统一带 `_<l1>` 后缀写到 `test_dwd` |
| 1.3 | 跑 `run_test.sh` 装载 |
| 1.4 | **验收**：行数 + 关键字段空值率 + brand 100% 标准化 + 抽样质检 |
| 1.5 | 与同事 review SQL + 验收结果 |

验收硬指标（参考 DigiKey 试点）：
- 分类结果：每个 L3 行数 >0 且分布合理（无单一 L3 吞噬全部行）
- EAV：`brand_null = 0` / `distinct_brand = distinct_brandid`
- L2 宽表：关键字段（如 `resistance_ohm` / `capacitance_f`）空值率 < 30%（视品类）

### 阶段 2：合并到主流程

通过 Cursor skill 或 CONTRIB.md 二选一：

- 推荐：`/dim-l3-classify-merge` + `/dim-attr-std-merge` skill
- 手动：`sql_scripts/1.classify/CONTRIB.md` + `sql_scripts/2.attribute_standard/CONTRIB.md`

合并动作（skill 会代劳）：

1. **分类合并**：只合并 `test_dim.dim_l3_classify_<l1>` / `dim_l3_classify_rule_<l1>` 到生产 `dim`，先输出到 `test_dwd.dwd_component_class_merge_<l1>` 验证，再写生产 DWD
2. **属性合并**：只合并 `test_dim.dim_attr_schema_<l1>` / `dim_attr_extract_rule_<l1>` 到生产 `dim`，`dim_unit_factor` 只追加缺失单位
3. **L1 目录入仓**：L2 DDL/build 放入 `sql_scripts/2.attribute_standard/<LL_l1_ready>/`，并更新 `run_attr_std.sh` 的 `l1_dir()` / `l2_files_for_l1()`
4. **test_dwd 正式脚本验证**：属性 EAV/L2 先输出到 `test_dwd` merge 临时表，与阶段 1 后缀表对齐
5. **prod 重跑**：验证通过后再写生产 EAV + L2
6. **校验 prod 行数 / 空值率 / brand 覆盖**与阶段 1 测试期对齐

### 阶段 3：清理

```sql
-- test_dim
DROP TABLE IF EXISTS test_dim.dim_attr_schema_<l1>;
DROP TABLE IF EXISTS test_dim.dim_attr_extract_rule_<l1>;
DROP TABLE IF EXISTS test_dim.dim_l3_classify_<l1>;
DROP TABLE IF EXISTS test_dim.dim_l3_classify_rule_<l1>;

-- test_dwd
DROP TABLE IF EXISTS test_dwd.dwd_component_class_<l1>;
DROP TABLE IF EXISTS test_dwd.dwd_component_attr_std_<l1>;
DROP TABLE IF EXISTS test_dwd.dwd_l2_<l1>_<l2>;  -- each L2
```

```bash
# 仓库目录
git rm -r sql_scripts/test/<l1>/
```

---

## 4. 已有的可复用工具

| 工具 | 用途 |
|---|---|
| `sql_scripts/test/run_test_dwd_e2e.sh` | DigiKey 多源 e2e 验证脚本范例（已 prod 化，可参考 sed 渲染 / 行数对比模板） |
| `.cursor/skills/dim-l3-classify-merge/SKILL.md` | 分类阶段从测试后缀表合并到生产 dim 的执行流程 |
| `.cursor/skills/dim-attr-std-merge/SKILL.md` | 属性阶段从测试后缀表合并到生产 dim、入仓 L1 目录脚本并回归的执行流程 |
| `sql_scripts/2.attribute_standard/run_attr_std.sh` | 属性阶段 prod EAV + L2 runner，合并新 L1 时需同步 `l1_dir()` / `l2_files_for_l1()` |

---

## 5. FAQ

**Q: 必须用 strict 后缀模式吗？我只改一个属性规则也要这么重？**
A: 仅适用于"新 L1 接入"。如果只是给已存在 L1 调整小规则，单独评审变更范围后直接维护生产规则，不走测试库后缀流程。

**Q: 当前 `sql_scripts/test/run_test_dwd_e2e.sh` 是 DigiKey 试点遗留的（无后缀，靠 data_source 隔离），跟 strict 流程不一样？**
A: 是。DigiKey 是首个多源试点，当时还没沉淀 strict 流程，跑在统一表上用 `data_source` filter 隔离。新 L1 标准化按本 README 的 strict 后缀模式做，更干净。

**Q: 阶段 1 测试期可以 commit 到 main 吗？**
A: 不建议。试点期在 feature 分支（如 `feat/<l1>-stdization`）开发；合并主流程的 PR 才合到 main。`sql_scripts/test/<l1>/` 内文件在 cleanup 阶段会 `git rm`。

---

## 6. L1 试点流程图

| L1 | 文档 | 状态 |
|---|---|---|
| 通用模板 | [`../L1_STD_PIPELINE.md`](../L1_STD_PIPELINE.md) | 已发布 |
| `data_converter` | [`data_converter/README.md`](data_converter/README.md) | 已合 prod |
| `sensor` | [`sensor/README.md`](sensor/README.md) | **进行中** |

---

## 7. 相关文档

- 分类合并 SOP：`sql_scripts/1.classify/CONTRIB.md`
- 分类规则引擎：`sql_scripts/1.classify/RULE_ENGINE.md`
- 属性标准化合并 SOP：`sql_scripts/2.attribute_standard/CONTRIB.md`
- 品牌字典 SOP：`sql_scripts/2.attribute_standard/CONTRIB_BRAND.md`
- 多源架构 cutover：`sql_scripts/PROD_CUTOVER.md`
- Cursor Skills：`.cursor/skills/dim-l3-classify-merge/SKILL.md` / `dim-attr-std-merge/SKILL.md`
