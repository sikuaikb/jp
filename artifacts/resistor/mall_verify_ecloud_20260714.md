# resistor ecloud 商城核对报告（阶段 5 收尾）

- **日期**：20260714
- **对照源**：库内 `dwd_digikey_component_param` + `dwd_icpdf_component_param` + ecloud category2/MPN 系列
- **得捷 live**：Cloudflare 拦截，未用网页抓取

## 分类核对汇总

| 结论 | 数量 |
|------|------|
| Y / Y* | 30 |
| N（规则缺口） | 2 |
| pending（无对照） | 3 |

### 分类不一致（需改规则或业务裁决）

- `17FPR015E` 我方=`current_sense_resistor` 商城≈`general_fixed_resistor` · [icpdf] category2=固定电阻器; our_rule_gap
- `SR732HTTE7R68F` 我方=`current_sense_resistor` 商城≈`general_fixed_resistor` · [icpdf] category2=固定电阻器; our_rule_gap

### pending 样本（库内无 dk/icpdf，已用 ecloud/MPN 仍不足）

- `RN731JTTD3361B50` (general_fixed_resistor) · 贴片电阻
- `RN732BTTD1271C10` (general_fixed_resistor) · 贴片电阻
- `RN73H2BTTD6123D10` (general_fixed_resistor) · 贴片电阻

## 参数核对汇总

| 结论 | 数量 |
|------|------|
| Y | 21 |
| N | 0 |
| pending | 0 |

## 本轮回规则修复（核对驱动）

1. **分类**：trimmer MPN 移除 `RM06`（Samsung 排阻误落 trimmer）、`3540`（TE 贴片低阻误落 trimmer）
2. **分类**：补充 Bourns trimmer 前缀 3314/3292/3299/3266/3006 等
3. **核对**：R25 解析修正——键名 kΩ 但裸数字按 Ω 计（如 `470`→470Ω，`10k`→10kΩ）
4. **核对**：Current Sense 样本用 PE/PU/RW1/SR73/RES0/WSL + mOhm 特征补全 pending

## 阶段 5 收尾结论

- 分类样本 **35** 条：可接受 **30**，规则缺口 **2**，待人工 **3**
- 属性样本 **21** 条：通过 **21**，问题 **0**
- **可进入阶段 6 合并准备**（只读评审 dim merge），遗留 pending 为库内无第三方对照，不阻塞合并
- **业务待决**：PTC/MOV/熔断丝跨 L1 召回；`RW1*` 低阻在 icpdf=固定电阻 vs 我方 current_sense 边界
