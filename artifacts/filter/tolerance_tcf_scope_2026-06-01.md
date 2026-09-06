# 容差 / 温度系数 — 得捷 scope 分析

> 生成：`analyze_tolerance_tcf_scope.py`

## 容差（有值 3,802 件）

| L2 | L3 | 件数 | 占比 |
|----|-----|------|------|
| emi_suppression_filter | feedthrough_capacitor | 3,802 | 100.0% |

### 取值形态（Top L3 各抽最多 800 行）

#### `feedthrough_capacitor`（n=800）

| 形态 | 条数 | 占比 | 样例 |
|------|------|------|------|
| has_percent | 798 | 99.8% | ±20%；±20%；±20% |
| percent_like | 2 | 0.2% | ±0.5pF；±0.5pF |

## 温度系数（有值 3,376 件）

| L2 | L3 | 件数 | 占比 |
|----|-----|------|------|
| emi_suppression_filter | feedthrough_capacitor | 3,376 | 100.0% |

### 取值形态（Top L3 各抽最多 800 行）

#### `feedthrough_capacitor`（n=800）

| 形态 | 条数 | 占比 | 样例 |
|------|------|------|------|
| dielectric_code | 642 | 80.2% | X7R；X7R；X7R |
| alnum_mixed | 157 | 19.6% | C0G，NP0；X7W；C0G，NP0 |
| has_ppm | 1 | 0.1% | ±2.5ppm/°C |

## 当前规则 matches 模拟

### `cutoff_freq_tolerance_pct`

（无匹配 — scope/schema 未联结）

### `tcf_ppm_per_c`

（无匹配 — scope/schema 未联结）

## EAV 现状

（上述属性尚无 EAV 行）

## 建议动作

### 容差 → `cutoff_freq_tolerance_pct`

- **主量落在 `feedthrough_capacitor`（馈通电容）**：得捷「容差」多为电容 **±%**（如 `±20%`），语义接近电容容值容差，**不是** LC 滤波器「截止频率容差」。
- **不建议**把全量 `容差` 绑到 `lc_passive_filter.cutoff_freq_tolerance_pct`（当前仅 ~19 件 LC）。
- **试点可选**：
  - A) `feedthrough_capacitor` 新增 `capacitance_tolerance_pct`（需白皮书字段）；或
  - B) 暂不入 EAV，保留 gap 表 `manual_review`。

### 温度系数 → `tcf_ppm_per_c` / `ceramic_tcf_ppm_per_c`

- **`feedthrough_capacitor` / `emi_common_mode_filter` 等**：多为 `X7R`/`C0G` 等 **介质代号**，应映射 `ceramic_tcf_ppm_per_c`（VARCHAR/枚举）或单独 `dielectric_material`，**不要**写入 ppm 数值型 `tcf_ppm_per_c`。
- **`saw_filter` / `baw_filter` 等**：得捷该 key **常为空**；频率 TCF 可能在其他 key（需 Phase 1 再扫 key 别名）。
- **`dielectric_resonator_filter`**：schema 已有 `ceramic_tcf_ppm_per_c`，可补规则 `温度系数` → 介质代号（VARCHAR 或 value_map），与 `tcf_ppm_per_c` 分流。

### 不建议的捷径

- 勿把馈通上的 `容差`/`温度系数` 绑到 `lc_passive_filter.cutoff_freq_tolerance_pct` 或声学 `tcf_ppm_per_c`。
- 勿对介质代号用 `([\d.]+)` 数值 regex（会得到 parse_fail 或错误数值）。

---

## 2026-06-01 已落地（test 试点）

在 `gen_attr_seed_filter.py` → `PILOT_DK_SCHEMA_EXTRAS` + 馈通规则：

| 得捷 key | std_attr | 规则 | EAV 填充 |
|----------|----------|------|----------|
| 容差 | `capacitance_tolerance_pct` | `fil_ft_tol` + `([\d.]+)\s*%` | **4,164** 件 (15.3%) |
| 温度系数 | `dielectric_material` | `fil_ft_dielectric`（VARCHAR 原值） | **4,163** 件 (15.3%) |

重跑：`python gen_attr_seed_filter.py` → `python run_test_filter_attr.py`
