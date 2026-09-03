# MCU/MPU/DSP · 阶段 2 分类沙盒（icpdf + DigiKey）

## Taxonomy（对齐 `dim_l3_classify_all`）

**一个 L1**，MCU/MPU/DSP 是 **L2**，不是三个 L1：

| 层 | 编码 | 说明 |
|----|------|------|
| L1 | `mcu_mpu_dsp` | 微控制器和处理器 |
| L2 | `mcu` / `mpu_soc` / `dsp` | 微控制器 / 微处理器与异构SoC / 数字信号处理器 |
| L3 | `19xxxx` | 如 `190101` general_mcu、`190201` application_mpu、`190305` general_programmable_dsp |

> 勿用 prod seed 里临时的 `l1_code=mcu|mpu|dsp` 或 `20xxxx/21xxxx/22xxxx` 段——那是 icpdf 合并前的历史形态；沙盒以 `foundation/dim_l3_classify_all.sql` 为准。

## 范围与前提

- **数据源**：`dwd.dwd_icpdf_component_param`、`dwd.dwd_digikey_component_param`（只读）
- **沙盒 dim（权威态）**：`test_dim.dim_l3_classify_mcu_mpu_dsp`、`test_dim.dim_l3_classify_rule_mcu_mpu_dsp`、`test_dim.dim_attr_schema_mcu_mpu_dsp`、`test_dim.dim_attr_extract_rule_mcu_mpu_dsp` — 试错期直接 `UPDATE`/`INSERT`/`DELETE`，不经 CSV 重灌
- **沙盒产出**：`test_dwd.dwd_component_class_mcu_mpu_dsp`、`test_dwd.dwd_component_attr_std_mcu_mpu_dsp`（`data_source` 区分 icpdf/得捷）
- **阶段 1 结论**：见 `artifacts/mcu_mpu_dsp/digikey_explore_notes_20260528.md`

### v1 接受的现状（不改引擎 / 不改 adapter）

| 项 | 决策 |
|---|---|
| Gate 字段 | 仅用 `category` 白名单（引擎不支持 gate 读 `prajson`） |
| 未分类叶子 | **不含** `未分类` → ~44 行 PIC 单片机裸片不入 gate |
| SBC / 评估板 | 不在 gate 白名单内 |
| 主流 STM32/TMS320 | 上游 ODS 缺口，本规则无法补 |

## 规则摘要

### Gate `gate_mcu_mpu_dsp_digikey_v1`

`category_in`：

- 片上系统（SoC）
- 射频收发器 IC
- ADC/DAC - 特殊用途
- 专用 IC
- 带单片机的 FPGA（现场可编程门阵列）

### Classify（DigiKey 首批 rule_id，见 `test_dim.dim_l3_classify_rule_mcu_mpu_dsp`）

| rule_id | L3 | 信号 |
|---------|-----|------|
| ~~`mcu_digikey_wireless_v1`~~ | 200101 wireless_mcu_soc | **v1.1 已禁用**（商城核对：RF/雷达/蓝牙/Zigbee ≠ MCU） |
| ~~`mcu_digikey_metering_v1`~~ | 200106 metering_mcu | **v1.1 已禁用**（商城核对：MSC12xx 仍属数据转换器） |
| `mcu_digikey_specialty_ic_v1` | 200107 general_mcu | 专用 IC + note 微控制器 |
| `mcu_digikey_soc_mcu_arch_v1` | 200107 general_mcu | SoC + 架构 %MCU% |
| `mpu_digikey_ai_soc_v1` | 210102 ai_edge_computing_soc | SoC + note AI/NPU |
| `mpu_digikey_prog_soc_cat_v1` | 210103 programmable_heterogeneous_soc | FPGA+MCU 叶子 |
| `mpu_digikey_prog_soc_arch_v1` | 210103 | SoC + 架构 %FPGA% |
| `mpu_digikey_app_cortex_a_v1` | 210101 application_mpu | SoC + Cortex-A |
| `mpu_digikey_app_arch_v1` | 210101 | SoC + 架构 %MPU% |
| `mpu_digikey_soc_fallback_v1` | 210101 | SoC 弱兜底 phase=1 |
| `dsp_digikey_type_v1` | 220105 general_programmable_dsp | 类型 %DSP% |
| `dsp_digikey_specialty_ic_v1` | 220105 | 专用 IC + note DSP |

**暂无 L3 场景规则**（200102–200105 等 icpdf 专有形态在 DigiKey 样本中未出现）。

### v1.4 变更（2026-05-29，icpdf 对齐）

- **icpdf 规则迁入沙盒**：55 条 gate/classify 规则在 `test_dim.dim_l3_classify_rule_mcu_mpu_dsp`（`l3_id` 全量 `19xxxx`，`rule_id` 前缀 `mcu_mpu_dsp_icpdf_{mcu|mpu|dsp}_*`）
- **DSP L3 收敛**：以 Excel `DSP_Base` 为准，DSP 只有单一 `general_programmable_dsp`(190301) + `audio_dsp`(190302) 两个连续节点；不再拆 fixed/float/multi（定点/浮点/核心数走属性字段）
- **build SQL**：`build_dwd_icpdf_component_class_mcu_mpu_dsp.sql` → 写入沙盒表 `data_source='icpdf'`（~105k 行，DC1–DC4 PASS）
- **run_test.sh**：icpdf + digikey 双源 classify + 双源 `validate_dwd_data.py`
- **清理**：`cleanup_legacy_data_debt.sql` 增加 DROP `dwd_icpdf_component_class_{mcu|mpu|dsp}` 历史并列表

### v1.3 变更（2026-05-29，taxonomy + 数据债务清理）

- **prod seed 对齐**：`dim_l3_classify.csv` 76–89 行改为 `19xxxx` / `l1_code=mcu_mpu_dsp` / L2 无 `_base`（与 `dim_l3_classify_all.sql` 一致）
- **属性 dim**：`test_dim.dim_attr_schema_mcu_mpu_dsp`（124 行，`l1_code=mcu_mpu_dsp`，`scope_code` 为 `mcu`/`mpu_soc`/`dsp` 及 L3 节点）
- **test_dwd 清理**：执行 `cleanup_legacy_data_debt.sql` — 删除通用表错拆 L1（mcu/mpu/dsp 共 105007 行）、EAV `_base` 行、DROP legacy 宽表 `dwd_l2_mcu/mpu_soc/dsp`

```bash
# 一次性清理 legacy 数据（已执行时可跳过）
mysql -h $MYSQL_HOST -P $MYSQL_PORT -u $MYSQL_USER -p$MYSQL_PASSWORD \
  < sql_scripts/test/mcu_mpu_dsp/cleanup_legacy_data_debt.sql
```

### v1.2 变更（2026-05-28，taxonomy 纠正）

- L1 统一为 `mcu_mpu_dsp`；L2 为 `mcu` / `mpu_soc` / `dsp`；`l3_id` 改用 `19xxxx` 段
- `rule_id` 统一前缀 `mcu_mpu_dsp_digikey_*`
- 详见 `lessons_learned.md#LL-20260528-04`

### v1.1 变更（2026-05-28，商城核对纠正）

- 禁用 `wireless_mcu_soc` / `metering_mcu` 两条 DigiKey 规则；分类总量 4140 → **1352**
- 你指出的 6 个料号已不再入 MCU L3（gate 内保持未分类）
- 详见 `lessons_learned.md#LL-20260528-03`

## 运行

```bash
set -a && source sql_scripts/local.env && set +a

# 分类（icpdf + 得捷）
mysql … < sql_scripts/test/mcu_mpu_dsp/build_dwd_icpdf_component_class_mcu_mpu_dsp.sql
mysql … < sql_scripts/test/mcu_mpu_dsp/build_dwd_digikey_component_class_mcu_mpu_dsp.sql

# EAV + L2 宽表 + 数据质量报告
bash artifacts/mcu_mpu_dsp/run_eav_mcu_mpu_dsp.sh
bash artifacts/mcu_mpu_dsp/run_l2_mcu_mpu_dsp_sandbox.sh
python3 artifacts/mcu_mpu_dsp/gen_data_quality_report.py

# 属性 dim 门控（含 A15 豁免 env）
source artifacts/mcu_mpu_dsp/attr_source_waivers_mcu_mpu_dsp.env
python3 .cursor/skills/component-etl-methodology/tools/validate_attr_dim.py \
  --dim-schema test_dim --schema-table dim_attr_schema_mcu_mpu_dsp \
  --rule-table dim_attr_extract_rule_mcu_mpu_dsp --unit-table dim_unit_factor --l1 mcu_mpu_dsp
```

改规则：直接改 `test_dim` 后缀表，或执行 `artifacts/mcu_mpu_dsp/apply_*.sql` / `apply_*_rules.py`，再重跑上述脚本。

## 下一步

1. 按 SKILL §六-B 新建宽表 DDL：`dwd_l2_mcu_mpu_dsp_{mcu|mpu_soc|dsp}.sql`
2. 宽表透视 + `validate_dwd_data.py` 门控
3. 分层抽样 + 得捷/芯查查商城三段式核对（`decision_guides.md`）
4. 阶段 6 合并：`test_dim` → `dim`（见 `dim-l3-classify-merge` / `dim-attr-std-merge` skill）
