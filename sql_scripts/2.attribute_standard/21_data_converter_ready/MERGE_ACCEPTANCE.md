# data_converter 属性标准化合并验收报告

合并日期：2026-06-26
分支：`yy/icpdf_data_convert_handle`
合并人：agent（用户授权 ALLOW_PROD=1）

## 合并内容

把 `data_converter` L1 的属性标准化（ICPDF 规则补录 + schema 修订 + L2 多源改造）从 test_dim/test_dwd 后缀表合入 prod 主流程。

| 维度 | 合并前 prod | 合并后 prod |
|------|------------|------------|
| `dim_attr_schema` (l1=data_converter) | 54 | **58**（+4，全在 `l3/digital_potentiometer` 1→5）|
| `dim_attr_extract_rule` (l1=data_converter) | 55（digikey only）| **105**（digikey 55 + **icpdf 50 新增**）|
| `schema_version` | `data_converter_schema_v1.0.0` | 不变 |
| EAV data_converter/icpdf | 14,425（旧规则）| **504,874**（新规则）|
| EAV data_converter/digikey | 232,081 | 232,081（不变）|
| L2 adc | digikey 1,794 | digikey 1,794 + **icpdf 16,085** |
| L2 dac | digikey 9,309 | digikey 9,309 + **icpdf 18,886** |

## 命名 / 前缀

- `extract_rule_id` 沿用历史 `dcv_` 前缀（`dcv_icpdf_*` 50 条 + `dcv_digikey_*` 55 条），与分类合并一致，**不是** `data_converter_` 前缀。
- PK 预检确认 `dcv_` 前缀只涉及 data_converter，不撞其它 L1。
- Step 5 DELETE 用 `l1_code='data_converter' OR extract_rule_id REGEXP '^dcv_'` 双保险（skill 模板的 `^<l1>_` 正则删不到 `dcv_` 前缀，需兜底）。

## 品牌字典

分支在 `dim_std_brand_manual_extra.sql` 末尾追加 data_converter ICPDF 品牌补录段（DCV 段）：
- A 类 enrich 7 个既有 `brand_id_std` 的 `related_words`（CATALYST→ON、BB→TI、SIPEX→MaxLinear、TELCOM→MICROCHIP、MAXWELL→MAXIM、AGILENT→AVAGO 等）
- B 类新增 12 个 `brand_id_std`（9000600–9000611，全新公司）

已执行 `sync_dim_std_brand.sh prod`（DCV 段 + 重建 `v_std_brand_alias`）。

### BD1 查重结论

`validate_brand_dim_dup.py` 报 46 组归一化重复 FAIL，但经核实：
- **本次 DCV sync 未引入任何新的归一化重复**：B 类新增 12 个 brand_id_std 全是新公司，0 碰撞；A 类只 enrich 既有 id 的 related_words。
- 46 组全部是 **prod 长期存在的历史问题**（jp_brand 中英重名 + 累积 manual_extra，如 MICRON、LATTICE、SKYWORKS、SUNLORD 等中英双 id），与本次 data_converter 合并无关。
- 唯一涉及 DCV id 的是 MAXLINEAR 组，但那是 prod 既有重复（`MaxLinear` vs `Maxlinear` 两个 id 早就在），DCV 只往其中一个加 SIPEX 别名。

决策：本次合并照常继续；46 组历史重复作为独立品牌字典治理任务单独处理（用户确认）。

## 入仓脚本改造（Step 4 修正）

入仓的 `21_data_converter_ready/build_dwd_l2_data_converter_{adc,dac}.sql` 原是 **DigiKey 单源硬编码**（`WHERE data_source='digikey'` + `INNER JOIN dwd_digikey_component_param`），无法跑 ICPDF。本次改为**多源模式**（参考 `11_resistor_ready/build_dwd_l2_resistor_fixed_resistor.sql` 模板）：

- 加 `WITH src_param AS (UNION ALL icpdf + digikey)` CTE
- `DELETE ... WHERE data_source IN ('icpdf','digikey')`（清两源）
- `ext` CTE 去掉 `e.data_source='digikey'` 硬编码
- 主 SELECT `JOIN src_param p ON p.data_source=c.data_source AND p.id=c.id`（替代单源 param JOIN）
- `WHERE` 去掉 `c.data_source='digikey'`，只留 `c.l1_code`/`c.l2_code`
- 保留 data_converter 原有 brand CASE 写法（brandshort 空 → NULL，保 brand_null=0）

`dwd_l2_*.sql` DDL、`run_attr_std.sh` 的 `l1_dir()`/`l2_files_for_l1()` 映射此前已在 main 完成，本次未改动。

## 验证（Step 6）

主干正式脚本输出到 test_dwd merge 临时表，对比阶段 1 后缀表：

| 表 | merge icpdf | 阶段1 icpdf | merge digikey | brand 门控 (icpdf) |
|----|------------|------------|--------------|-------------------|
| L2 adc | 16,085 ✅ | 16,085 | 1,794 | null=0, dt=di=57 ✅ |
| L2 dac | 18,886 ✅ | 18,886 | 9,309 | null=0, dt=di=54 ✅ |

icpdf 行数与阶段 1 基线完全一致，digikey 未受影响。

## prod 重跑（Step 7）

`INIT_EAV_DDL=1 SOURCES="icpdf digikey" L1_LIST=data_converter` 全量重建 EAV + 跑 2 张 L2，prod 校验：

- EAV data_converter/icpdf = 504,874 ✅
- EAV data_converter/digikey = 232,081 ✅
- L2 adc: digikey 1,794 + icpdf 16,085 ✅
- L2 dac: digikey 9,309 + icpdf 18,886 ✅
- icpdf brand 门控全绿（null=0, dt=di）
- dac digikey 有 12 个 brand_null —— prod 历史遗留（本次未引入）

## 备份表

- `dim.bak_dim_attr_schema_data_converter_202606261930`（54 行）
- `dim.bak_dim_attr_extract_rule_data_converter_202606261930`（55 行）

## cleanup（Step 8）

DROP 所有 test_dim/test_dwd `_*data_converter*` 后缀表 + merge 临时表（残留 0）。`git rm -r sql_scripts/test/data_converter/`。

## 留给 owner 的事项

1. **46 组历史品牌归一化重复**：独立任务，按 `CONTRIB_BRAND.md` 走 A 类合并 / 伪重复白名单登记，用 `sql_scripts/brand_merge/` 统一收口。
2. **dac digikey 12 个 brand_null**：prod 历史遗留，需补 `dim_std_brand_manual_extra` 后重跑。
3. `extract_rule_id` 的 `dcv_` 历史前缀：与 skill 模板 `^<l1>_` 约定不符，但已长期存在于 prod，本次保留；后续若做规则前缀治理需一并考虑。
