# ICPDF Phase 5.5 逐项优化纪要

日期：2026-07-07 | 范围：**仅 icpdf** | DigiKey 规则未改

## gap 探针结论（Step 1 技术核查）

| 属性 | L3 | 源端键 | 命中 SKU | 判定 |
|------|-----|--------|----------|------|
| viewing_angle_half_deg | led | prajson2.视角 | 71,053 | **R**：regex 只认 `°` 不认 `deg` |
| photodetector_type | photodiode | 子类别/光电设备类型 | 部分 | **R**：补 category2 兜底 |
| pkg_height_mm | photodetector | 总高度 | 76 | **R**：补 photodetector L2 规则 |
| dark_current_na | photodiode | 最大暗电源 | 1,370 | 规则已对齐（D：覆盖=源端上限） |
| breakdown_voltage_v | photodiode | 最大/最小反向电压 | 738+781 | 规则已对齐，放宽 regex |
| color_temperature_k | led | 颜色@波长 | 19,607 | **D**：值为 Green/Red 非 K |
| thermal_resistance | led | — | 0 | **D** |
| slope_efficiency | laser | — | 0 | **D**（删除错误 DK 映射） |
| divergence_* | laser | 视角 | 0 | **D** |
| junction_cap / response_time / shunt | photodiode | — | 0 | **D** |
| responsivity / spectral_range / nep | photodiode | 响应度等 | ≈0 | **D** |

## dim 变更（`gen_attr_extract_rule_icpdf_optoelectronics.py`）

1. **ICPDF_REGEX_OVERRIDE**：视角 `deg`、pkg `mm`、dark `nA`、breakdown 可选 `V`
2. **SKIP_ICPDF_STD_ATTRS**：slope_efficiency、thermal_R、junction_cap、response_time、shunt
3. **EXTRA**：photodetector `pkg_height_mm`；`param_category2_eq` → photodetector_type 兜底
4. **value_map**：子类别 `Other Optoelectronics` → Photodiode

## 重跑（仅 ICPDF）

```bash
cd sql_scripts/test/optoelectronics
python gen_attr_extract_rule_icpdf_optoelectronics.py
python run_test_optoelectronics_attr.py
python run_test_optoelectronics_l2.py
```

## 效果对比

| 指标 | 优化前 | 优化后 |
|------|--------|--------|
| EAV viewing_angle_half_deg | 0 | **70,774** |
| EAV photodetector_type | 6,824 | **7,270** |
| L2 photodetector_type 填充率 | 77.2% | **99.6%** |
| L3 led viewing_angle | 0% | **61.8%** |
| L3 led ext 覆盖 | 82.0% | **83.1%** |
| icpdf extract 规则行数 | 58 | **60**（删 3 错规则 + 增 5） |

## 仍待（ICPDF 无法单靠规则解决）

- photodiode ext 19.6%：dark/breakdown 源端键仅 ~10–19% 覆盖
- 阶段 5 外部核对 consistent 79.7% 未变（本次未动分类 dim）
