# resistor ecloud 阶段 5 外部商城核对收尾（20260714）

## 产物

| 文件 | 说明 |
|------|------|
| `classify_sample_ecloud_20260714.tsv` | 35 条分类样本，`mall_ok` / `mall_l3` / `notes` 已填 |
| `attr_review_ecloud_20260714.tsv` | 21 条 P0 属性样本 |
| `mall_verify_ecloud_20260714.md` | 核对汇总与规则修复记录 |

**脚本**：`sql_scripts/test/resistor/audit/gen_mall_verify_ecloud.py`  
**对照源**：库内 `dwd_digikey` + `dwd_icpdf` + ecloud `category2` / mOhm 特征 / MPN 系列（得捷 live 受 Cloudflare 拦截）

## 分类核对结果

| 结论 | 数量 |
|------|------|
| Y / Y* | 29 |
| N（规则缺口） | 2 |
| pending（无第三方对照） | 4 |

**本轮回修复**：
- trimmer MPN 规则移除 `RM06`（Samsung 排阻误落 trimmer，+224 行回排阻）、`3540`（TE 贴片低阻误落 trimmer，+254 行回贴片）
- 补充 Bourns trimmer 前缀 3314/3292/3299/3266/3006 等
- 排阻样本 `RM062PJ241CS` 已正确为 `resistor_array_network`

**规则缺口（业务裁决）**：
- `PF1262-30KF1`：30kΩ 插件功率电阻，我方 current_sense vs 商城 general_fixed
- `SR731JTTDR255F`：255mΩ 贴片，icpdf=固定电阻器 vs 我方 current_sense（低阻边界）

**pending（不阻塞合并）**：`CRT0402-FZ-2151GLF`、`ERJ-1GEF2053C`、`RTT038R2JTP`、`SMW568RJT` — 库内无 dk/icpdf

## 属性核对结果

| 结论 | 数量 |
|------|------|
| Y | 21 |
| N | 0 |

NTC R25 解析已修正：`470`（键名 kΩ 但裸数字）→ 470Ω；`10k`/`100k` 正常换算。  
阻值比对容忍 ecloud 宽表保留 mOhm/kOhm 数字未除/乘 1000 的已知引擎行为（如 `6 mOhms`→宽表 6.0）。

## 分类分布（修规则后 e2e）

| L3 | 行数 |
|----|------|
| general_fixed_resistor | 1,069,891 |
| wirewound_resistor | 77,177 |
| resistor_array_network | **31,155** (+224) |
| current_sense_resistor | 27,227 |
| potentiometer | **9,000** |
| ntc_thermistor | 7,923 |
| trimmer_potentiometer | **5,999** |

gate 1,228,372 · 分类覆盖 **100%**

## 阶段 5 收尾结论

- 外部商城核对 **可收尾**；遗留 2 条 N + 4 条 pending 不阻塞阶段 6
- **可进入阶段 6 合并准备**（只读评审 `dim-l3-classify-merge` / `dim-attr-std-merge`）
- **业务待决**：PTC/MOV/熔断丝跨 L1 召回；低阻 current_sense 与 general_fixed 边界

## 重跑

```bash
.probe_venv/bin/python sql_scripts/test/resistor/run_test_resistor_ecloud.py
.probe_venv/bin/python sql_scripts/test/resistor/audit/gen_attr_review_ecloud.py
.probe_venv/bin/python sql_scripts/test/resistor/audit/gen_mall_verify_ecloud.py
```
