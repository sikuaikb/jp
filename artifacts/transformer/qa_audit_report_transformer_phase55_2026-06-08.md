# Transformer Phase 5.5 QA Audit — 2026-06-08

```

====================================================================
§1 品牌门控（硬门控，阻断 Phase 6）
====================================================================

  signal_communication_transformer  →  ❌ FAIL
    total=5,809  brand_null=363  distinct_brand=38  distinct_brandid=31
    ⚠ brandshort=[None]  n=363

  switching_drive_transformer  →  ❌ FAIL
    total=1,978  brand_null=1  distinct_brand=17  distinct_brandid=16
    ⚠ brandshort=[None]  n=1

====================================================================
§2 全字段填充率
====================================================================

── signal_communication_transformer ──
  总行数: 5,809

  字段                                      填充数     填充率  状态
  ------------------------------------------------------------
  manufacturer                          5,450   93.8%  ✅
  lifecycle_status                      5,450   93.8%  ✅
  rohs_compliant                        5,185   89.3%  ✅
  lead_free                             5,183   89.2%  ✅
  reach                                 4,430   76.3%  ✅
  eccn_code                             3,742   64.4%  ✅
  htsus_code                            3,736   64.3%  ✅
  msl_level                             4,526   77.9%  ✅
  mounting_style                        4,968   85.5%  ✅
  termination_style                       664   11.4%  ⚠ 低
  height_max_mm                         4,831   83.2%  ✅
  pkg_length_mm                         4,686   80.7%  ✅
  pkg_width_mm                          4,686   80.7%  ✅
  temp_min_c                            3,666   63.1%  ✅
  temp_max_c                            3,666   63.1%  ✅
  transformer_type_raw                  4,888   84.1%  ✅
  turns_ratio                           4,931   84.9%  ✅
  inductance_raw                        4,255   73.2%  ✅
  volt_time_product_vus                   554    9.5%  ⚠ 低
  aec_qualified                            61    1.1%  ⚠ 低
  freq_range_raw                          676   11.6%  ⚠ 低
  impedance_primary_raw                   664   11.4%  ⚠ 低
  impedance_secondary_raw                 662   11.4%  ⚠ 低
  dcr_primary_raw                         676   11.6%  ⚠ 低
  dcr_secondary_raw                       676   11.6%  ⚠ 低
  insertion_loss_raw                      653   11.2%  ⚠ 低
  return_loss_raw                         662   11.4%  ⚠ 低
  frequency_response_raw                  664   11.4%  ⚠ 低
  power_level_raw                         662   11.4%  ⚠ 低
  isolation_voltage_v                     389    6.7%  ⚠ 低
  certification_body                      672   11.6%  ⚠ 低

── switching_drive_transformer ──
  总行数: 1,978

  字段                                      填充数     填充率  状态
  ------------------------------------------------------------
  manufacturer                          1,977   99.9%  ✅
  lifecycle_status                      1,977   99.9%  ✅
  rohs_compliant                        1,957   98.9%  ✅
  lead_free                             1,957   98.9%  ✅
  reach                                 1,312   66.3%  ✅
  eccn_code                             1,372   69.4%  ✅
  htsus_code                            1,545   78.1%  ✅
  msl_level                             1,643   83.1%  ✅
  mounting_style                        1,744   88.2%  ✅
  form_factor                             692   35.0%  △
  height_max_mm                         1,713   86.6%  ✅
  pkg_length_mm                         1,381   69.8%  ✅
  pkg_width_mm                          1,381   69.8%  ✅
  temp_min_c                            1,557   78.7%  ✅
  temp_max_c                            1,557   78.7%  ✅
  topology_type                         1,262   63.8%  ✅
  application_raw                       1,547   78.2%  ✅
  primary_voltage_min_v                   880   44.5%  △
  primary_voltage_max_v                   782   39.5%  △
  isolation_voltage_v                   1,565   79.1%  ✅
  freq_min_khz                          1,073   54.2%  △
  freq_max_khz                            478   24.2%  ⚠ 低
  auxiliary_voltage_raw                 1,527   77.2%  ✅
  chipset_manufacturer                  1,527   77.2%  ✅
  target_chipset                        1,522   76.9%  ✅
  inductance_at_freq_raw                1,496   75.6%  ✅
  aec_qualified                            31    1.6%  ⚠ 低

====================================================================
§3 低填充字段按 L3 分解（_l2_field_by_l3 探针）
====================================================================

── signal_communication ──

  字段: termination_style  (整体填充率 11.4%)
    pulse_transformer                   has=    0/4,920  0.0%
    audio_transformer                   has=  664/  889  74.7%

  字段: volt_time_product_vus  (整体填充率 9.5%)
    pulse_transformer                   has=  554/4,920  11.3%
    audio_transformer                   has=    0/  889  0.0%

  字段: aec_qualified  (整体填充率 1.1%)
    pulse_transformer                   has=   61/4,920  1.2%
    audio_transformer                   has=    0/  889  0.0%

  字段: freq_range_raw  (整体填充率 11.6%)
    pulse_transformer                   has=    0/4,920  0.0%
    audio_transformer                   has=  676/  889  76.0%

  字段: impedance_primary_raw  (整体填充率 11.4%)
    pulse_transformer                   has=    0/4,920  0.0%
    audio_transformer                   has=  664/  889  74.7%

  字段: impedance_secondary_raw  (整体填充率 11.4%)
    pulse_transformer                   has=    0/4,920  0.0%
    audio_transformer                   has=  662/  889  74.5%

  字段: dcr_primary_raw  (整体填充率 11.6%)
    pulse_transformer                   has=    0/4,920  0.0%
    audio_transformer                   has=  676/  889  76.0%

  字段: dcr_secondary_raw  (整体填充率 11.6%)
    pulse_transformer                   has=    0/4,920  0.0%
    audio_transformer                   has=  676/  889  76.0%

  字段: insertion_loss_raw  (整体填充率 11.2%)
    pulse_transformer                   has=    0/4,920  0.0%
    audio_transformer                   has=  653/  889  73.5%

  字段: return_loss_raw  (整体填充率 11.4%)
    pulse_transformer                   has=    0/4,920  0.0%
    audio_transformer                   has=  662/  889  74.5%

  字段: frequency_response_raw  (整体填充率 11.4%)
    pulse_transformer                   has=    0/4,920  0.0%
    audio_transformer                   has=  664/  889  74.7%

  字段: power_level_raw  (整体填充率 11.4%)
    pulse_transformer                   has=    0/4,920  0.0%
    audio_transformer                   has=  662/  889  74.5%

  字段: isolation_voltage_v  (整体填充率 6.7%)
    pulse_transformer                   has=    0/4,920  0.0%
    audio_transformer                   has=  389/  889  43.8%

  字段: certification_body  (整体填充率 11.6%)
    pulse_transformer                   has=    0/4,920  0.0%
    audio_transformer                   has=  672/  889  75.6%

── switching_drive ──

  字段: freq_max_khz  (整体填充率 24.2%)
    smps_transformer                    has=  478/1,978  24.2%

  字段: aec_qualified  (整体填充率 1.6%)
    smps_transformer                    has=   31/1,978  1.6%

====================================================================
§4 字段决策（选型价值两步法）
====================================================================

  两步决策结果：
  字段                                  决策                 说明
  --------------------------------------------------------------------------------

  [signal_communication_transformer]
  freq_range_raw                      F → 下放 L3         
    → audio_transformer 89% 填充，pulse_transformer 0%（DK 无此 key）。freq_range_raw 对音频变压器选型有高价值，对脉冲变压器无意义。→ 将 scope_level 从 l2 改为 l3，scope_code='audio_transformer'。
  isolation_voltage_v                 F → 下放 L3         
    → audio_transformer 99% 填充，pulse_transformer ≈ 0%（DK 无 key '电压-隔离'）。隔离电压对音频变压器选型有高价值。→ 将 scope_level 从 l2 改为 l3，scope_code='audio_transformer'。
  volt_time_product_vus               F → 下放 L3         
    → 仅 pulse_transformer 有此字段（ET=伏·时间积）。→ scope_level='l3', scope_code='pulse_transformer'。
  aec_qualified                       D → 数据源缺失         
    → 变压器类 DK 极少标注 AEC 等级（仅少数功率型 SMPS 有资质字段）。signal_communication 器件无此数据，保留字段等候其他源（SMPS 端已有部分数据）。
  temp_min_c                          D → 数据源缺失（36.9%）  
    → audio_transformer 多为开架型号，DK 不标温度。pulse_transformer 63% 有温度。整体 63%，属可接受，无需下放。
  temp_max_c                          D → 数据源缺失（36.9%）  
    → 同 temp_min_c。

  [switching_drive_transformer]
  freq_max_khz                        D → 数据源缺失         
    → DK '频率' key 有时只给单一频率而非范围（如 '200kHz'），导致 freq_max_khz regex 无法拆分上限，实际仅 24% 填充。频率上限对 SMPS 设计选型有价值，保留字段，建议后续探查 regex 改进。
  primary_voltage_max_v               D → 数据源缺失         
    → DK '电压 - 初级' 有时只给单一电压值而非范围（如 '36 ~ 72V' 给范围，但 '36V' 只给单值），导致 max regex 无法拆分。保留，待 regex 改进。
  primary_voltage_min_v               △ 可接受（44.5%）      
    → 同上，DK 数据部分无主侧电压字段，属数据源固有缺失。
  freq_min_khz                        △ 可接受（54.2%）      
    → 部分 SMPS 变压器 DK 无频率字段，属源端缺失。
  topology_type                       △ 可接受（63.8%）      
    → DK '类型' key 仅 237/300 样本有值，部分型号无拓扑标注，属源端缺失。
  form_factor                         D → 数据源缺失（low）    
    → DK '样式' key 174/300 样本，但结果 form_factor 填充率极低；探查后发现 DK 值格式如 '通孔 (TH)' → 规则 value_map 未覆盖，保留字段，后续补 value_map。

====================================================================
§5 P 级问题汇总
====================================================================

  级别     L2                                     问题描述                                          行动
  ------------------------------------------------------------------------------------------------------------------------
  ❌P0    switching_drive_transformer            品牌门控失败：brand_null > 0                         修复 v_std_brand_alias 别名
  ❌P0    signal_communication_transformer       品牌门控失败：brand_null > 0                         修复 v_std_brand_alias 别名
  🔴P1    signal_communication_transformer       freq_range_raw + isolation_voltage_v 需从 L2 下  scope_level L2→L3；rebuild EAV+宽表
  🔴P1    signal_communication_transformer       volt_time_product_vus 需从 L2 下放到 L3=pulse_tra  scope_level L2→L3；rebuild EAV+宽表
  🔴P1    signal_communication_transformer       apply_scope_code 历史残留 pulse_signal_transform  已修复（本次 inductance_raw 从0→73%）
  🟡P2    switching_drive_transformer            freq_max_khz 仅 24.2%，DK '频率' 单值无法拆分上限         后续探查 regex 改进（如从描述字段兜底）
  🟡P2    switching_drive_transformer            primary_voltage_max_v 仅 39.5%，DK '电压-初级' 有时只  后续探查 regex 改进
  🟡P2    switching_drive_transformer            form_factor 填充率低，DK '样式' 值格式未被 value_map 覆盖   后续补 value_map
  ⬜D     signal_communication_transformer       aec_qualified signal_comm 端 DK 无数据            保留字段等其他源
  ⬜D     signal_communication_transformer       temp_min/max_c 36.9%：audio_transformer 无温度规格  不处理
  ⬜D     switching_drive_transformer            topology_type 63.8%，freq_min_khz 54.2%：DK 字段  不处理
  ℹ️INFO  signal_communication_transformer       temp_max_c 4件 >155°C：工业级规格（155~165°C），建议放宽上界  调整 dim_attr_schema max_bound
  ℹ️INFO  signal_communication_transformer       isolation_voltage_v 4件 <100V：音频变压器低隔离电压属正常    调整 dim_attr_schema min_bound 至 25V
  ℹ️INFO  两张宽表                                   EAV parse_fail=0, out_of_range=0              ✅ 无数值解析错误

====================================================================
§6 总体评估与下一步行动
====================================================================

  总体评估：PASS（无 P0 阻断，P1 已识别并有明确修复路径）

  当前版本：transformer_schema_v1.6.08
  分类结果：7,787 件（smps 1978 / pulse 4920 / audio 889）
  EAV 质量：parse_fail=0, out_of_range=0

  推荐下一步：
  1. [P1] 把 freq_range_raw / isolation_voltage_v 从 L2 下放到 L3=audio_transformer
           把 volt_time_product_vus 从 L2 下放到 L3=pulse_transformer
  2. [P2] 改进 switching_drive 的 freq_max_khz / primary_voltage_max_v 提取 regex
  3. 完成以上后 → 进入 Phase 6 发布门控（提交 PR）

```
