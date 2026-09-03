# `exports/` 字典草表说明

本目录下是从 `dwd_icpdf_component_param` 等表导出的**人工字典草表**。
所有 CSV 字段严格遵循《元器件数据中台白皮书》的 **7 维规范**：

| 维 | 字段名            | 规范 |
|----|-------------------|------|
| 1  | `std_attr_cn`      | 工业通用中文术语（如"标称容值"/"引脚间距"） |
| 2  | `std_attr_code`    | DB 物理列名，**必须带基准单位后缀**（如 `resistance_ohm` 严禁写 `resistance`） |
| 3  | `description_prompt` | 大白话 + 物理意义 + 选型/替代逻辑（"替代料需 >= 原料"这类） |
| 4  | `db_type`          | `DOUBLE` 连续物理量 / `INT` 离散量 / `VARCHAR` 枚举 / `JSON` 扩展池 |
| 5  | `precision`        | 小数位数，防止精度丢失（0.05% 精度、0.02mm 间距不能抹零） |
| 6  | `unit_std`         | **基准单位**：V / A / Ω / F / Hz / s / ℃ / mm / % / dB；子项解析时全部换算到此单位 |
| 7  | `value_domain`     | 常识边界或枚举（如 `> 0`, `<= 250`, `-100..300`） |

另外每行都有：
- `l2_scope`：这个属性归属哪个 L2 表（如 `voltage_regulator` / `bms_supervisor`）；留空=多 L2 通用
- `is_l2_common`：**0/1 标志**，该属性是否作为 L2 的实体列（=1）还是写进 `ext_attributes` JSON（=0）
- `note`：填表人备注

## 文件清单

### 1. 属性字典（填 L2 schema 的主战场）

| 文件 | 行数 | 适用场景 |
|---|---:|---|
| `dwd_icpdf_param_prajson_keys.csv` | 5,606 | `prajson` 数组里 `cn` 字段；**sqlname 是更稳定的机器 key，优先参考** |
| `dwd_icpdf_param_prajson2_keys.csv` | 1,510 | `prajson2` 对象顶层 key |
| `dwd_icpdf_param_all_keys.csv` | 6,946 | 两者并集 + 重合标记（`in_prajson`/`in_prajson2`），**推荐只填这一份** |

**填表优先级**：按 `covered_ids` 降序，前 300 行通常覆盖 80% 以上数据。

**关键判断**：
- 属性 4 家数据源都没 → 不要标，删除或留空即可（白皮书"求同"准则）。
- 只在一家出现的非标/冷门 → `is_l2_common=0`，扔进 `ext_attributes`。
- 多家共有且业内通用 → `is_l2_common=1`，进 L2 实体列。

### 2. 分类信号字典（填 L1 / L2 归属）

| 文件 | 行数 | 用途 |
|---|---:|---|
| `dwd_icpdf_param_category2.csv` | 372 | 覆盖 86%（主力，IHS 产业标准分类），**优先填这一份** |
| `dwd_icpdf_param_category.csv`  | 477 | 覆盖 8.7%（中文口语化），与 category2 冲突时 category 优先 |

**列含义**：
- `l1_code`：取值参考白皮书 L1 22 类（`pmic` / `mcu_mpu` / `memory` / `resistor` / ...）；L22 兜底写 `quarantine`
- `l2_code`：例如 `voltage_regulator` / `fixed_capacitor` / `mlcc` / `bjt` / ...
- **不填 L3**：L3 由清洗时按 sqlname 指纹识别，不在此层决定（白皮书："L3 不建表"）

### 3. 语义标签字典（填业务标签白名单）

| 文件 | 行数 | 用途 |
|---|---:|---|
| `dwd_icpdf_param_taginfo.csv` | 751 | `taginfo` 原始标签分布 |

`tag_type` 三选一：
- `business` → 业务语义标签，保留进 `semantic_tags`（如"车规"/"低功耗"/"AEC-Q100"/"SiC"）
- `category` → 品类词，**丢弃**（如"稳压器"/"电阻"/"晶体管" —— 已在 L1/L2/L3 里）
- `noise` → 噪声词，丢弃（如"输出元件"/"驱动"这种空洞词）

`tag_normalized`：业务标签的标准化形式（"车规" / "车规级" / "汽车级" 都归一为 `automotive_grade`）

## 填写流程建议

```
Step 1: category2 + category      (850 条) → 搞定 L1/L2 分类映射
Step 2: all_keys 前 300 条         (覆盖 80%+) → 搞定高频 L2 列定义
Step 3: all_keys 中间 300~2000 条  → 过 is_l2_common 决定进 L2 还是 JSON
Step 4: taginfo 前 200 条          → 搞定语义标签白名单
Step 5: 长尾 ~5000 条              → 默认 is_l2_common=0 丢 ext_attributes
```

单人预计 Step 1+4 合计 3~4 小时、Step 2 合计 4~6 小时即可起草完成。
