# logic_ic · 逻辑芯片 L1 分类清洗（阶段 1A 完成）

分类树真源：[`foundation/dim_l3_classify_all.sql`](../../foundation/dim_l3_classify_all.sql)（`22xxxx`，`schema_version = v1.4.30`）

属性 schema（后续 1B）：桌面 `Logic_IC_schema.xlsx` → 3 L2 Base · 13 L3

## 分类树

| L2 | L3 数 | l3_id 段 |
|----|------:|----------|
| `combinational_logic` | 5 | 220101–220105 |
| `sequential_logic` | 4 | 220201–220204 |
| `signal_buffer_driver` | 4 | 220301–220304 |

## 当前进度

- [x] DigiKey 类目探查（`audit/_probe_dk_*.py`）
- [x] gate v1.1：**19,591** SKU（含奇偶校验）
- [x] classify v1：**35 条 classify 规则**（37 clause 行 + 4 gate）→ 详见 [`CLASSIFY_DESIGN.md`](CLASSIFY_DESIGN.md)
- [x] `build_dwd_digikey_component_class_logic_ic.sql` + `run_test_logic_ic.py` 验收 **PASS**
- [x] 边界抽样审计（`audit/boundary_classify_audit.py`）**PASS**（WARN 0）
- [x] 属性阶段（1B）**PASS**
- [x] 属性 schema + 抽取规则（93/93 覆盖）
- [x] EAV：`test_dwd.dwd_component_attr_std_logic_ic`（17,928 器件 / 39 属性）
- [x] L2 宽表 ×3（合计 19,591 行）
- [x] 品牌门控（有 brandshort 100% 映射）
- [x] 整体审计 `audit/run_full_audit.py` **PASS**
- [ ] 合 prod（管理员）

## 验收结果（v1）

| 指标 | 值 |
|------|---:|
| gate_pass | 19,591 |
| 未分类 | 0 |
| null_l3 | 0 |
| 零命中 L3 | `level_translator`（DK 无独立叶子） |

## 快速命令

```bash
python seed/gen_rule_csv.py              # gate + classify → CSV
python seed/gen_classify_insert_sql.py   # 仅 classify → INSERT SQL
python load_seed_logic_ic.py --db test_dim
python audit/probe_gate.py          # gate 基线 19,591
python run_test_logic_ic.py         # 全链路验收
python audit/audit_classify_row_integrity.py  # 改名后行数/重复/L3 基线
python audit/validate_rule_id_naming.py  # CONTRIB Step 2
python audit/audit_classify_coverage.py   # 覆盖核查
python gen_attr_seed_logic_ic.py          # 属性 schema CSV
python gen_attr_extract_rule_logic_ic.py  # 抽取规则 CSV
python audit/probe_digikey_keys.py        # L3×prajson key 频次
python audit/l3_prajson_sample_analysis.py  # 每 L3 1 条样本映射
python load_attr_seed_logic_ic.py --db test_dim
python run_test_logic_ic_attr.py            # EAV + L2 宽表
python audit/run_full_audit.py              # 一键整体审计
```
