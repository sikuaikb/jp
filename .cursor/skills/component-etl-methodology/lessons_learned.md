# 踩坑记录（Lessons Learned）

> 本文件记录在本项目实际工作中**已经发生**的错误、误操作、错误假设，以及对应的纠正与防御措施。  
> 每条都带：日期、场景、错误行为、后果、纠正、防御规则。  
> **每次用户纠正 Agent 时，必须把当次教训追加到本文件，并在 SKILL.md / anti_patterns.md 中加上对应硬约束。**

---

## 维护约定

1. 新条目追加到本文件**顶部**（最新在上），按 `LL-YYYYMMDD-NN` 编号。
2. 必须四件套：场景 / 错误 / 后果 / 纠正与防御。
3. 若产生新硬约束，**同步**写入：
   - `SKILL.md` 六、两条硬门控 → 升级为三条以上
   - `anti_patterns.md` → 通用反模式表追加一行
4. 不可删除历史条目；如有更新，开「补充」小节而不是覆盖。
5. 控制单文件体量：较早的整月条目可**只移不删**进 `lessons_learned/archive_*.md`，本文件保留最近条目；移动后必须在「全条目索引」登记位置，保证可追溯。

---

## 全条目索引

> 最近条目（2026-06-03 起）保留在本文件；更早条目已移入 [lessons_learned/archive_20260528_20260601.md](lessons_learned/archive_20260528_20260601.md)（**只移不删**，历史完整）。新增条目仍追加到本文件顶部并在此登记。

| 编号 | 标题 | 位置 |
|------|------|------|
| LL-20260706-05 | icpdf 清洗进度长期按 param 表（678 万 partno）口径算"56% 覆盖率"，漏掉源端 detail 表 2971 万 partno 里 2777 万未分类数据；真实清洗率只有 12.8%；清洗完成率必须用源端明细表 distinct partno 做分母，不能用中间层当分母 | 本文件 |
| LL-20260706-04 | "22/27 L1 完成 = 清洗 81%"是错觉；distinct partno 覆盖率只有 56.18%，297 万型号在规则盲区（259 万 categoryid 为空）；已清洗 L1 也有规则盲区（connector 的 SAMTEC 12 万没进 L2）；清洗完成率必须用 distinct partno 覆盖率口径 | 本文件 |
| LL-20260706-03 | 定 7 月目标时凭记忆写"icpdf 7 个待建 L1"，连库复核实际只有 5 个（sensor/circuit_protection 早在 7-03 已完成）；与 LL-20260703-01 同类错误 3 天内复发 | 本文件 |
| LL-20260706-02 | 多源 overlap 用纯 partno 算重叠把"同型号不同品牌"误算成重复；v2 拆真重复/替代料/真独有三层后发现 digikey∩icpdf 88.9 万同 partno 里 91.6% 是替代料、只有 7.4 万真重复，DWS 层重心从"去重"转向"建 dwd_component_alternate_map（176 万行）" | 本文件 |
| LL-20260706-01 | 凭直觉判断"元器件云大部分与得捷重复"导致 skip_if_dup 误策略；连库跑 overlap 探针才证实 ecloud 95% 型号是 digikey 没有的独有型号、且独有型号里 Vishay/KOA/SiTime 等欧美品牌排前列（不是国产替代库）；字段层重叠型号 ecloud 几无增量（digikey 参数 99.99% 已覆盖）| 本文件 |
| LL-20260703-01 | 月度规划把 `CLEAN_COVERAGE_AND_FORECAST.md` 当待办清单，没核对 prod `DWD_L2_STATS_BY_L1.md` 实际清洗状态；forecast 把 transformer 误算待建、把 12 个 icpdf「digikey 已覆盖」L1 列为增量主体，导致规划严重偏离用户「digikey 已覆盖就不在其他源重清洗」的多源去重策略 | 本文件 |
| LL-20260625-01 | 品牌字典「一家公司多个 brand_id_std」，宽表门控 dt=di 是盲区；补归一化查重校验器 + sync fail-fast + brand_merge 收口 | 本文件 |
| LL-20260604-03 | 多源覆盖门控只做成 WARN，13 条缺规则未被机械阻断；A15 升 FAIL + 补全源盲区 + build 源隔离 linter | 本文件 |
| LL-20260604-02 | Agent 不以「两个 merge skill」为流程权威源，擅自给 run_classify.sh 加 RESEED、改写 merge 门控措辞、把 seed 写回方法论 | 本文件 |
| LL-20260604-01 | 试错期改规则的载体：seed 彻底退场，直接改 test_dim 表 | 本文件 |
| LL-20260603-05 | 多源接入缺「按 data_source 的规则覆盖」门控，单源漏建整层规则无法机械发现 | 本文件 |
| LL-20260603-04 | 沙盒产出应是 test_dim/test_dwd 表，禁止在 test 目录落 CSV/dump | 本文件 |
| LL-20260603-03 | P0 补缺时改通用 EAV 引擎或从通用复制的沙盒 build SQL | 本文件 |
| LL-20260603-02 | 调整 skills 时用「打补丁 / changelog」式措辞，把迁移叙事写进 skill 正文 | 本文件 |
| LL-20260603-01 | 合并范式：按 L1 从 test_dim 后缀表替换 prod dim + L2 脚本目录化 | 本文件 |
| LL-20260601-01 | 把 `schema_version` 当成规则迭代号（v1.0.00/v1.1.00/v1.2.00），而非 Excel schema 版本 | [归档](lessons_learned/archive_20260528_20260601.md) |
| LL-20260529-17 | 删 L3 节点后留下跳号（190301+190304），L2/L3 id 体系不连续 | [归档](lessons_learned/archive_20260528_20260601.md) |
| LL-20260529-16 | 把 `dim_l3_classify_all.sql` 当成 L1/L2/L3 全维度权威，校验器拿它比对 L2/L3 | [归档](lessons_learned/archive_20260528_20260601.md) |
| LL-20260529-15 | 合并时没把 DSP 的 L3 对齐 main，机械套用旧 taxonomy 的 fixed/float/multi 四拆分 | [归档](lessons_learned/archive_20260528_20260601.md) |
| LL-20260529-14 | 动手前没全项目盘点既有通路，凭沙盒目录就断言「某源缺脚本」，连续误判 3 次 | [归档](lessons_learned/archive_20260528_20260601.md) |
| LL-20260529-13 | skills 内的校验器必须零外部依赖、可独立运行；新门控不强行接 run_test.sh | [归档](lessons_learned/archive_20260528_20260601.md) |
| LL-20260529-12 | 分类层产出了 L3，属性层却没建 L3 schema → ext_attributes 恒空且无人察觉 | [归档](lessons_learned/archive_20260528_20260601.md) |
| LL-20260529-11 | 新增校验的「权威值」必须有真权威源；不得用同一段脏文本/产出数据反推 | [归档](lessons_learned/archive_20260528_20260601.md) |
| LL-20260529-10 | 倒推工具盲区前，必须先核对 dim 现有 schema，别臆断字段不存在 | [归档](lessons_learned/archive_20260528_20260601.md) |
| LL-20260529-09 | 校验器提示必须「自解释 + 优雅降级」（给无上下文会话用） | [归档](lessons_learned/archive_20260528_20260601.md) |
| LL-20260529-08 | 校验器的「期望值/建议值」不得从脏数据反推 | [归档](lessons_learned/archive_20260528_20260601.md) |
| LL-20260529-07 | 分类 L2 的 l2_code 不要带 `_base` 后缀 | [归档](lessons_learned/archive_20260528_20260601.md) |
| LL-20260529-06 | 校验器补齐到属性/宽表层后，抓出存量 prod 债务（待人工修复） | [归档](lessons_learned/archive_20260528_20260601.md) |
| LL-20260528-05 | 硬规则只写进 prompt 不够，必须配可执行校验器（fail-fast） | [归档](lessons_learned/archive_20260528_20260601.md) |
| LL-20260528-04 | MCU/MPU/DSP 是一个 L1，不能拆成三个 L1 | [归档](lessons_learned/archive_20260528_20260601.md) |
| LL-20260528-03 | DigiKey 源端文案 ≠ 业务 L3（RF/ADC 误归 MCU） | [归档](lessons_learned/archive_20260528_20260601.md) |
| LL-20260528-02 | L2 宽表不要叠 `_capacitor` 沙盒后缀 | [归档](lessons_learned/archive_20260528_20260601.md) |
| LL-20260528-01 | 品牌字典 `dim_std_brand` 不要在试点流程里重新同步 | [归档](lessons_learned/archive_20260528_20260601.md) |

---

## LL-20260706-05 · icpdf 清洗进度长期按 param 表（678 万 partno）口径算"56% 覆盖率"，漏掉源端 detail 表 2971 万 partno 里 2777 万未分类数据；真实清洗率只有 12.8%

**日期**：2026-07-06
**场景**：定 7 月目标时长期引用"icpdf distinct partno 覆盖率 56.18% / 297 万规则盲区 / 259 万 categoryid 为空"（LL-20260706-04 的口径），并据此规划盲区补齐。用户质疑"dwd.dwd_icpdf_component_detail 已处理的 icpdf 数据只占其中一小部分" + "针对未分类只有 mpn 的 2kw 数据怎么处理"。跑探针 `probe_icpdf_source_uncategorized.py` 查源端 detail 表真实规模，发现口径完全错位：

| 层 | distinct partno | 占源端 |
|---|---:|---:|
| 源端 `dwd_icpdf_component_detail` | 2971 万 | 100% |
| 有分类（categoryid 非空非0）| 209 万 | 7% |
| 未分类（categoryid NULL/0）| **2777 万** | **93%** |
| 进 `dwd_icpdf_component_param`（有参数抽取）| 678 万 | 23% |
| 进 L2 宽表（清洗完成）| 380 万 | **12.8%** |

之前所有"56% / 297 万盲区"都是基于 param 表（678 万 partno）口径，**漏掉源端 2971 万里根本没进 param 表的 2293 万**（只有 mpn + brandshort + pdf 元数据，无参数）。未分类 brandshort Top：KYOCERA AVX 319 万 / AMPHENOL 183 万 / VISHAY 160 万 / SAMTEC 155 万 / WALSIN 147 万 / ETC 122 万 / KOA 96 万 / GLENAIR 58 万 / ECLIPTEK+ABRACON+MTRONPTI 98 万（晶振）。

**错误行为**：用中间层（param 表）当分母算清洗完成率，没回到源端明细表（detail）核对真实总量。LL-20260706-04 自称"修正了 L1 完成率的错觉"，但只修到 param 表口径，仍在源端口径上严重高估。

**后果**：7 月目标 A 把"296 万规则盲区"列为可一周补齐的任务（实际可做的 param 表内盲区）；真实未分类 2777 万量级是 10 倍，根本不在 7 月能力范围。若按错误口径承诺"覆盖率 56%→85%"会严重逾期。

**纠正与防御**：
1. 文档基线修正：`JULY_2026_GOALS.md` A 部分补充源端真实口径（12.8% / 2777 万未分类），用户裁决量太大先不处理，留长期缺口。
2. **清洗完成率必须用源端明细表 distinct partno 做分母**，不能用中间层（param/EAV/L2）当分母；任何"覆盖率"指标必须注明分母是哪一层。
3. 多源对比时，每个源都要先 `SELECT COUNT(*) FROM 源端明细表 + COUNT(DISTINCT partno)` 核对总量，再算中间层覆盖率，避免用中间层口径自我安慰。
4. 用户裁决：2777 万未分类数据先不处理，8 月起视 agent 选型需求再决定是否启动品牌→L1 兜底分类 + PDF 参数抽取。

---

## LL-20260706-02 · 多源 overlap 用纯 partno 算重叠把"同型号不同品牌"误算成重复；v2 拆三层后发现替代料关系才是大头

**日期**：2026-07-06
**场景**：做四源 overlap 综合分析（digikey+icpdf 已清洗整体 vs ecloud+element14 新源），v1 探针 `probe_four_source_overlap.py` 用纯 partno 算重叠率，得出 ecloud 重叠 41.53%、element14 重叠 51.74%、digikey∩icpdf 重叠 78 万等结论，并据此设计 DWS 去重策略。用户当场指出方法论错误：**partno 相同但 brand 不同不能视为重复，同一个器件不同厂商出品很正常**（如 LM358 TI vs NSC、2N3904 ON vs Fairchild）。v2 探针 `probe_four_source_overlap_v2.py` 按 (partno, brand) 归一化后拆三层口径，结论彻底翻转：

| 关系 | digikey∩icpdf | ecloud∩整体 | element14∩整体 | 合计 |
|---|---:|---:|---:|---:|
| 真重复（同 partno + 同 brand）| 74,266 | 787,645 | 103,470 | 965,381 |
| 替代料（同 partno + 不同 brand）| **814,679** | **804,731** | **136,705** | **1,756,115** |
| 真独有（partno 不在整体）| - | 2,179,599 | 205,525 | 2,385,124 |

**重大发现**：digikey ∩ icpdf 的 88.9 万同 partno 里 **91.6%（81.5 万）是替代料**，只有 8.4%（7.4 万）是真重复——v1 把这 88.9 万全算成"重叠去重"完全错了。全口径替代料关系对数 176 万，几乎是真重复 97 万的 2 倍。

**错误**：
1. **混淆"型号重复"与"物料重复"**：partno 是型号（model），(partno, brand) 才是物料（component）。同型号不同品牌是替代料关系，不是重复数据。overlap 分析必须用物料维度，不能用型号维度。
2. **DWS 去重策略重心错位**：v1 把"重叠"都导向去重逻辑，实际其中绝大部分要建替代料关系表 `dwd_component_alternate_map`，去重只占小头。
3. **品牌归一化未做**：v1 连 brand 都没归一化，"Texas Instruments" vs "TI" 会被当成不同品牌，扭曲替代料/真重复拆分。

**后果**：若按 v1 策略执行，digikey∩icpdf 81.5 万替代料关系会被当重复丢弃，丢失跨源替代料金矿；DWS 层会把重心放在 97 万真重复去重上，而忽略 176 万替代料关系表这个真正的大工程。

**纠正与防御**：
1. **多源 overlap 必须用三层口径**：真重复（同 partno + 同归一化 brand → DWS 去重）/ 替代料（同 partno + 不同归一化 brand → 建 alternate_map）/ 真独有（partno 不在整体 → 完整 ETL）。未拆三层前不得给出"重叠率"或"去重策略"。
2. **品牌必须归一化**：去 INC/LTD/CORP/SEMICONDUCTOR/TECHNOLOGY/ELECTRONICS/GROUP/GMBH/AG 等后缀 + UPPER + 去特殊字符，否则 "TI" vs "Texas Instruments" 会被当不同品牌扭曲拆分。
3. **partno 归一化也要做**：UPPER + 去横杠/空格（注意 StarRocks RE2 字符类不支持 `\-` 转义、`REGEXP_REPLACE(x,'.','')` 的 `.` 是元字符会清空整个字符串——用嵌套 REGEXP_REPLACE 分别替换单字符）。
4. **DWS 层设计重心**：替代料关系表（~176 万行）是重头戏，去重（~97 万行）是次要的。`dwd_component_alternate_map` schema 要尽早设计。

**防御规则**：多源 overlap 探针默认输出三层口径（真重复/替代料/真独有），单层"纯型号重叠率"不得作为策略依据；品牌对比前必须归一化；partno 归一化用嵌套单字符 REGEXP_REPLACE，禁用字符类转义和 `.` 元字符。

---

## LL-20260706-04 · "22/27 L1 完成 = 清洗完成 81%"是错觉；distinct partno 覆盖率只有 56%，297 万型号在规则盲区

**日期**：2026-07-06
**场景**：用户看 7 月目标规划质疑"icpdf 已经清洗了 22 个大类，只剩 5 个大类了，但是数据占比只有 42%，感觉有点问题"。跑 `probe_icpdf_l2_coverage.py` 连库核对：dwd_l2 宽表 icpdf 端 distinct mpn = 3,808,668，icpdf 源端 param distinct partno = 6,779,145，**覆盖率只有 56.18%**，**297 万 distinct partno 没进任何 L2 宽表**。

三个口径的差异：

| 口径 | 数值 | 含义 |
|---|---:|---|
| 大类完成率 | 22/27 = 81% | 建了 L2 宽表的 L1 数 |
| 行数清洗率 | 4.19M / 7.02M = 59.7% | L2 行数 / param 层总行数 |
| **distinct partno 覆盖率** | **3.81M / 6.78M = 56.18%** | **真正进 L2 的型号数 / 源端型号数** |

297 万盲区里 259 万 categoryid 为 NULL/0（icpdf param 表 category 字段 91% 为空，源端无分类信息，全靠规则分类，规则没命中就丢）。已清洗 L1 也有大量规则盲区：connector 已清洗但 SAMTEC 12 万/GLENAIR 6.8 万/ITT 5.3 万/TE 4.7 万连接器型号没进 L2。

**错误**：
1. **把"大类完成率"等同于"清洗完成率"**——22/27 L1 建了宽表不代表该 L1 的型号都进了宽表。每个 L1 内部规则覆盖率可能只有 50-80%，剩余是规则盲区。
2. **规划时只看了 `DWD_L2_STATS_BY_L1.md` 的大类级行数**，没看 distinct partno 覆盖率。大类级行数掩盖了规则盲区。
3. **"剩 5 个 L1 就完了"的判断完全错误**——实际还有 297 万规则盲区型号要处理，工作量翻倍。

**后果**：原 7 月主目标 A 只列 5 个待建 L1（W1-W2），完全漏掉 297 万盲区。若按此执行，icpdf 实际覆盖率仍停在 56%，ecloud 真独有量评估会高估（icpdf 盲区型号被误判为 ecloud 独有）。

**纠正与防御**：
1. **清洗完成率的唯一正确口径是 distinct partno 覆盖率**（已进 L2 的 distinct partno / 源端 distinct partno），不是大类完成率，也不是行数清洗率。`DWD_L2_STATS_BY_L1.md` 必须加这一列。
2. **每个 L1 的规则覆盖率要单独看**——某 L1 建了宽表不代表该 L1 型号 100% 覆盖。规则盲区是常态，尤其源端 category 字段稀疏的源（icpdf category 91% 空）。
3. **规划前必须跑 distinct partno 覆盖率探针**：`probe_icpdf_l2_coverage.py`（union 所有 dwd_l2 表的 mpn，对比源端 param distinct partno）。未跑此探针前不得下"清洗完成"结论。
4. **规则盲区处理优先用品牌→L1 模式规则**（按品牌直分，机械、可复用），不跑 LLM。品牌→L1 映射规则库是可复用资产，ecloud/element14 盲区也能用。
5. **dwd_l2 宽表型号字段叫 `mpn` 不是 `partno`**（dwd_component_class 表无 partno 字段、用 id 关联；icpdf param 表用 partno）——跨表 join 前先 DESC 确认字段名，别假设。

**防御规则**：任何"清洗完成/剩余 N 个 L1"的判断必须用 distinct partno 覆盖率探针验证，不能用大类完成率或行数清洗率；`DWD_L2_STATS_BY_L1.md` 补 distinct partno 覆盖率列；规则盲区默认用品牌→L1 模式规则补齐。

---

## LL-20260706-03 · 定 7 月目标时凭记忆写"icpdf 7 个待建 L1"，连库复核实际只有 5 个

**日期**：2026-07-06
**场景**：定 7 月目标时，主目标 A 写成"icpdf 7 个待建 L1 收尾"，列了 sensor / circuit_protection / clock_timing / optoelectronics / rf_wireless / interface_ic / acoustic_device 七个。用户质疑"我觉得没有 7 个 l1 了"。跑 `probe_l2_stats_by_l1.py` 复核：sensor（ic=20,904）和 circuit_protection（ic=76,559）早在 7-03 那批就已完成 icpdf 清洗，真正 ic=0 的待建 L1 只有 5 个（clock_timing / optoelectronics / rf_wireless / interface_communication_ic / acoustic_device）。

**错误**：
1. **凭记忆写待建清单，没连库核对**——`DWD_L2_STATS_BY_L1.md` 7-03 18:46 版"与上一版差异"表格明确记录了 sensor/circuit_protection 已新增 icpdf 数据，但定目标时没回看这个差异表，直接凭之前的印象写 7 个。
2. **与 LL-20260703-01 同类错误复发**——上次是规划时没核对 prod 实际状态（connector 已清洗），这次是定目标时没核对 prod 实际状态（sensor/circuit_protection 已清洗）。间隔仅 3 天，同类错误复发说明防御规则没落地。

**后果**：主目标 A 工作量被高估约 30%（7 L1 → 5 L1），排期 W1-W2 偏保守；若按 7 L1 排期，可能给团队传递错误的工作量预期。

**纠正与防御**：
1. **任何"待建/待清洗/待执行"清单在写进规划前必须连库核对**——跑 `probe_l2_stats_by_l1.py` 或等价探针，逐条验证每个 L1 的 icpdf/digikey 行数是否为 0。未核对前不得写入规划文档。
2. **回看 DWD_L2_STATS_BY_L1.md 的"与上一版差异"表**——该表记录了最近一批新增清洗的 L1，是判断"哪些已做、哪些待做"的最直接证据。定规划前必读。
3. **LL-20260703-01 的防御规则升级**：原规则是"规划前跑探针查最新状态"，本次虽跑了探针（7-03），但 3 天后定目标时凭记忆而非回看探针输出。升级为：**每次定规划/盘点时都要重跑探针**，不能依赖 N 天前的探针输出，因为期间可能有新清洗完成。

**防御规则**：定月度/周度目标前必须重跑 `probe_l2_stats_by_l1.py`，逐条核对每个"待建 L1"的 icpdf 端行数是否为 0；DWD_L2_STATS_BY_L1.md 的"与上一版差异"表是必读项；不得凭记忆写待建清单。

---

## LL-20260706-01 · 凭直觉判断多源重复率，误定 skip_if_dup 策略；连库跑 overlap 探针才证实 ecloud 95% 型号独有

**日期**：2026-07-06
**场景**：用户做 7 月规划时凭直觉说"元器件云大部分数据可能与得捷存在重复"，Agent 据此在 AskQuestion 选项里设了 `skip_if_dup` 策略（"重复率高就只取增量字段不重清洗"），用户当时也选了这个选项。3 天后真正连库跑 `probe_ecloud_digikey_overlap.py`，结果完全推翻直觉：

- 纯型号重叠 96.2 万（ecloud 25.52% / digikey 12.46%）——不是"大部分重复"
- 品牌归一化后重叠仅 17.4 万（ecloud **4.56%** / digikey 2.34%）——ecloud 95% 型号是 digikey 没有的
- ecloud 独有型号 280 万的 Top 5 品牌是 **Vishay / KOA / YAGEO / Knowles / Schurter**——欧美品牌排前列，**不是国产替代料库**
- 字段层：重叠的 96 万型号里 digikey 参数 99.99% 已覆盖、图片 98.56%、描述 98.60%，ecloud 真正能补的不到 4%——重叠型号部分 ecloud 冗余

**错误**：
1. **Agent 把用户的直觉判断直接做成策略选项**，没要求先跑探针验证。AskQuestion 的选项设计本身就把"未经验证的假设"当成了"已成立的策略"。
2. **Agent 没识别"大部分重复"是个可证伪的量化命题**——重复率是 50%+ 还是 5% 直接决定策略，必须连库算而不是凭感觉。
3. ecloud 独有型号的"国产替代料"定性也是凭印象——实际跑出来 Vishay 51 万独有型号排第一，ecloud 是"型号补全集"不是"国产替代库"。

**后果**：若按 `skip_if_dup` 执行，ecloud 280 万独有型号会被丢弃或只做字段补缺不入清洗——等于丢掉 digikey 没覆盖的型号补全集，且误把 79 万"同型号不同品牌"当重复丢弃，丢失替代料关系金矿。

**纠正与防御**：
1. **任何"重复率高/低"的判断必须先连库跑 overlap 探针**，探针输出至少包含：纯型号重叠率、品牌归一化重叠率、双向重叠率、独有型号按分类/品牌分布。未跑探针前不得把"重复"判断做成策略选项。
2. **多源策略三段分治**（替代 skip_if_dup 单一策略）：
   - 独有型号 → 完整接入清洗
   - 同型号不同品牌 → 建替代料关系表
   - 同品牌同型号 → DWS 物料主档层去重
3. **AskQuestion 选项设计禁忌**：不得把"未经验证的假设"包装成"已成立的策略"作为选项给用户选；遇到量化命题必须先要求探针验证，再决定策略。
4. **字段层增量要核对源端实际字段非空率**：本次 v1 探针误用 `d.prajson2 IS NULL` 判断"digikey 无参数"，但 digikey.prajson2 100% 为空、参数实际在 `prajson` 字段（非空 99.35%）——v1 结果全部有偏，v2 改用 prajson 才正确。设计字段对比前先 `DESC` + 单字段 COUNT 验证字段非空率。

**防御规则**：用户表达"某源与已有源重复/相似"时，Agent 不得直接做成策略，必须先输出探针计划并跑出三段数字（纯型号/品牌归一化/字段级互补）后再讨论策略；字段对比前先验证源端字段实际非空率。

---

## LL-20260703-01 · 月度规划把 forecast 文档当待办清单，没核对 prod 实际清洗状态；多源去重策略未识别

**日期**：2026-07-03
**场景**：用户在做 7 月目标规划，问"还有哪些工作"。Agent 引用 `docs/CLEAN_COVERAGE_AND_FORECAST.md` 列出"icpdf 12 个待建 L1、+220 万 + +65 万增量、2 周完成"，并据此规划主目标 A（ICPDF 清洗补尾）。用户当场纠正两点：① connector 已经清洗完了（digikey 侧 243 万行）；② LLM 分类落地"没有必要"。

**错误**：
1. **没核对 prod 实际状态**：`DWD_L2_STATS_BY_L1.md`（统计日期 2026-06-30，prod 实时查询）清楚显示 connector 在 digikey 侧 6 张表全有 2,432,752 行、icpdf 侧 0 行；forecast 文档却把 connector 列为"icpdf 待建 ≈100 万"。Agent 直接信了 forecast 当待办清单，没去 join prod stats 验证"是否真的还没做"。
2. **forecast 文档自身有 bug**：它列 12 个 icpdf 待建 L1，实际只有 11 个——transformer 在 icpdf 侧已有 19,270 行清洗数据（prod 第 416 行），forecast 把 transformer 误算进待建清单。
3. **没识别用户的多源去重策略**：用户先说"元器件云大部分数据可能与得捷存在重复"——这已透露策略；随后用户对 ecloud/element14 明确选 "skip_if_dup"（digikey 已覆盖就只取增量字段不重清洗）。Agent 没把这个策略外推到 icpdf——其实 icpdf 11 个待建 L1 全部是"digikey 已覆盖、icpdf 0"状态，按同一策略应**全部跳过**，而非当作 7 月增量主体。
4. **把仓库已有未执行的方案当待办**：`docs/STRATEGY.md`（DeepSeek LLM 分类）是 4 月就定稿的方案文档，但用户当前判断"没有必要"——Agent 没问就直接列入 7 月目标。

**后果**：7 月规划上半月的主交付（+220 万 icpdf 增量）基于错误前提；如果按规划执行，会浪费 2 周团队产能去 icpdf 侧重复清洗 digikey 已覆盖的 L1，与用户的多源去重策略完全相悖。LLM 分类目标也属于强加用户已弃用的方案。

**纠正与防御**：
1. **规划/盘点前必须以 prod 实际状态为权威**：清洗覆盖率、待建清单一律以 `DWD_L2_STATS_BY_L1.md`（或直接连库 COUNT）为准；forecast / strategy 类文档只是参考，不能当待办清单。两者矛盾时以 prod 为准、并回头修 forecast。
2. **多源去重策略识别**：用户表达"某源与已清洗源重复"时，要外推到所有同类状态——凡是「L1 在 digikey 已清洗、在其他源 0 行」的，默认按"跳过重清洗"处理，除非用户明确说该 L1 要双源互补。
3. **未执行的方案文档 ≠ 待办**：仓库里的 STRATEGY / ROADMAP / TODO 文档只能作为"可选方案池"，列入月度目标前必须先与用户确认"现在还要不要做"，不能默认"有文档就要执行"。
4. **forecast 文档需要修订**：`docs/CLEAN_COVERAGE_AND_FORECAST.md` 与 prod 矛盾的两处——transformer 误列待建、11 个 digikey 已覆盖 L1 当增量主体——要在下次文档维护时按多源去重策略重写，明确"digikey 已覆盖的 L1 在其他源不重清洗"。

**防御规则**：任何"待清洗 / 待建 / 待执行"清单在写进规划前，必须先用 prod stats 或连库 COUNT 核对每一条目；用户对某源表达"和已有源重复"时，默认外推到该源所有可去重品类。

---

### 补充（2026-07-03 当天二次纠正）

用户紧接着要求"再统计一下，这个数据几天没有更新了"。连库跑 `sql_scripts/probe_l2_stats_by_l1.py` 才发现：**3 天内团队已把 icpdf 的 connector(103万) / storage(25.8万) / filter(6.0万) / amplifier(7.2万) 4 个 L1 清洗完毕**——prod 实际 icpdf 已清洗 20/27 L1、4,096,337 行、清洗率 58.4%，而 6-30 那版 `DWD_L2_STATS_BY_L1.md` 还停在 16/27 L1、2,668,427 行、38%。

**真正根因不是"forecast 当待办清单"**，而是更上游的一条：**任何静态文档（包括 prod stats doc）都有写入滞后，规划/盘点必须连库查最新状态，不能信任何 .md 文件里的数字**。`DWD_L2_STATS_BY_L1.md` 本身就是 prod 查询的快照，但它 3 天没刷，整个规划就基于过期数据。

同时纠正对用户策略的理解：用户说"connector 已经清洗完了"= icpdf 端也清洗完了（不是"digikey 已覆盖就跳过"）。icpdf 走的是**全量清洗策略**（即使和 digikey 重复也做），ecloud/element14 的 `skip_if_dup` 是这两个源特有的策略，**不能外推到 icpdf**。把单源策略当跨源通用策略是另一层错误。

**追加防御**：
1. 规划前先跑 `sql_scripts/probe_l2_stats_by_l1.py`（或等价连库探针），任何 .md 文档的数字只能作为"上次快照"参考。
2. 用户对某源说"已清洗完"时，先用探针确认是"该源已清洗"还是"该源被另一源覆盖故跳过"——两种语义完全不同，不能凭一句"已清洗完"就抽象成跨源策略。
3. `DWD_L2_STATS_BY_L1.md` 的"统计日期"字段是必读项；本次错误就是没看日期直接信数字。

---

## LL-20260625-01 · 品牌字典「一家公司多个 brand_id_std」，宽表门控 dt=di 是盲区；补归一化查重校验器 + sync fail-fast + brand_merge 收口

**日期**：2026-06-25
**场景**：用户给出一份品牌重复清单，要求确认 `dim.dim_std_brand` 重复情况。全表归一化扫描发现大量「同一家公司多行多 id」——既有中英混写（`慧荣科技-SiliconMotion` vs `Silicon Motion Inc`）、长短名（`Lattice` / `Lattice Semiconductor` / `莱迪斯-LATTICE`），也有 jp_brand 段已有、manual_extra 段又新建一行的**跨源重复**。下游所有 `dwd_l2_*.brandid` 是 build 时经 `v_std_brand_alias` 物化的快照，同一公司多 id 会让 brandid 随 build 时机随机命中其中一个，聚合口径分裂。

**错误**：① `CONTRIB_BRAND.md` 的补缺 SOP 只在 `ods.ods_jp_brand` 内扫母公司（Step 2），又只用 `name` 字面相等预检唯一性（Step 4B），既漏 manual_extra 段、又漏中英/长短名变体——这是重复的直接成因。② 唯一的品牌相关门控是宽表 `COUNT(DISTINCT brand)=COUNT(DISTINCT brandid)`（dt=di），但它对「同一公司两个 id、两个 brand 文本都非空」是**盲的**（2=2 仍相等），抓不到字典级一公司多行。

**后果**：存量约 60+ 组真重复散落 prod，dwd_l2 已物化错 brandid；且无任何机械手段防止后续再次引入。

**纠正与防御**：
1. **存量收口** `sql_scripts/brand_merge/`：`dim_brand_merge_map`（keep_id/merge_id）→ 合并别名并入 keeper 的 `related_words` + merge 行 `state=0` 软删 → patch `v_std_brand_alias` 加 `WHERE state=1` → `dwd_l2_*` 按 map 回填 `brandid`/`brand`。方向按下游行数选 keeper（Bel Fuse 因 merge 侧 66039 行远多于 keep 侧 104 行而翻转）。
2. **新增机械门控** `tools/validate_brand_dim_dup.py`：按归一化键（大写+去 INC/LTD/CORP/SEMICONDUCTOR/TECHNOLOGY/ELECTRONICS… 后缀+去非字母数字）聚合 state=1 品牌，同 key 落 >1 个 `brand_id_std` 即 BD1 FAIL；伪重复（缩写撞车的不同公司，如 `Central` 半导体 vs 中环、`光颉 Viking` vs `Viking Technology`、`希荻微 Halo` vs `Halo Electronics`）用 `BUILTIN_WAIVER`/`--waiver`/env `BRAND_DUP_WAIVER` 登记留痕。机器无法区分「漏查重 bug」与「缩写恰好撞车」，故豁免必须人工登记。
3. **接进发布通路** `sync_dim_std_brand.sh` 末尾 fail-fast 调用校验器（`--dim-schema dim|test_dim`），红则非零退出。
4. **SOP 加固** `CONTRIB_BRAND.md`：设计原则升级为「归一化后跨源唯一」；Step 2 主查打全表（含 manual_extra）；Step 4B 归一化预检替代字面相等；常见坑加「跨源重复」。
5. 校验器**补宽表门控的盲区**，两层互补：DL1 管「brand 与 brandid 一一对应」，BD1 管「一家公司一个 id」。

**防御规则**：判重看归一化键、范围打整张 `dim_std_brand`（跨源），不用 `name` 字面相等；动过品牌字典的发布必须过 BD1=0（phase6 6.2.5）。

---

## LL-20260604-03 · 多源覆盖门控只做成 WARN，13 条缺规则未被机械阻断；A15 升 FAIL + 补全源盲区 + build 源隔离 linter

**日期**：2026-06-04
**场景**：用户追问「能出现缺 13 条规则的情况，是不是说明硬门控还不够完善？没检测出来」。复盘确认：缺规则发生当时**完全无门控**；事后虽补了 `validate_attr_dim.py` A15（多源覆盖对称性，LL-20260603-05），但 A15 只做成 **WARN（退出码 0）**，沙盒 `run_test.sh` 不会因此 fail-fast，靠人读 WARN 去 triage——等于没有真正阻断。且存在两个盲区：① A15 只查「源间不对称」，某属性**全源皆 0 规则**时无不对称、它不报；② 真正的「掩盖器」——单源 build join 规则表漏 `AND r.data_source='<src>'`、被他源规则越界顶替凑数（LL-20260603-03）——根本没有校验器。

**错误行为**：
- 把「可机械判定的覆盖缺口」做成 WARN 而非 FAIL，违背本方法论「可机械判定的硬门控必须配可执行校验器 + fail-fast」自洽要求。
- 漏了「全源皆缺」与「掩盖器（build 漏源隔离）」两类同源缺口的机械校验。

**后果**：
- 13 条缺规则一路绿灯溜到合并 main 才暴露（capacitance_f≈886K 等行数无法在生产复现）。

**根因**：
- A15 落地时回避了「机器无法区分『漏建 bug』与『该源真无此属性』」这个难点，于是退化为 WARN；没引入「豁免清单」这一逃生阀来把它升成 FAIL。
- 只校规则 dim（A 系列），没校「消费规则的 build 脚本是否源隔离」，让掩盖器游离在门控之外。

**纠正与防御**（新硬约束，已落地）：
1. **A15 升 [FAIL] + 豁免清单**：非对称属性未补规则又未豁免 → FAIL 阻断。豁免经 `--attr-source-waiver L1:SOURCE:STD_ATTR_CODE`（或 env `ATTR_SOURCE_WAIVER`，CLI/env 传入、零外部文件依赖）显式人工登记「该源确无此属性」，留痕可审。
2. **新增 A16 [WARN]**：schema→rule 反向覆盖，某属性 schema 有定义但所有源 0 规则（A15 盲区）→ 提醒。
3. **新增 `tools/validate_build_source_isolation.py`（B1/B2 [FAIL]）**：静态扫单源 build，凡 join `dim_attr_extract_rule*`/`dim_l3_classify_rule*` 必带 `<alias>.data_source='<source>'`；缺谓词/过滤错源即 FAIL。只识别真实 dim 规则表（带 `dim_` 前缀），不误伤 CTE；无别名单表 CTE 接受 unqualified `data_source=`。已接进电容 `run_test.sh` step [1b]（`--expect-source digikey`），实跑：现网两个 digikey build 通过、删掉源隔离谓词的负样本正确 FAIL。
4. 同步升级：`SKILL.md` §六（多源门控由 1 道升为 3 道：A15 FAIL / A16 WARN / B1B2 FAIL）+ §七工具表；`anti_patterns.md` 增「WARN 当门控」「build 漏源隔离」两行；`pipeline_and_validation.md` §7 总表补 A15/A16/B 行。

---

## LL-20260604-02 · Agent 不以「两个 merge skill」为流程权威源，擅自给 run_classify.sh 加 RESEED、改写 merge 门控措辞、把 seed 写回方法论

**日期**：2026-06-04
**场景**：用户问「现在合并只需要 test 沙盒表的数据就能合并、不需要 seed，skills 里有没有限制？」并连续强调「seed 应该已经完全废弃了，为什么还有这么多地方用到？？？」「现在全流程都用不上 seed，方法论里相关内容都删掉」。Agent 没有以**两个 merge skill（`dim-l3-classify-merge` / `dim-attr-std-merge`，它们全程不提 seed）**为唯一流程权威源，而是去翻 `sql_scripts/` 实现脚本与 `component-etl-methodology` 旁支，自行推演出「seed 有三个合法身份、不能删」的结论。

**错误行为**：
- 擅自给 `1.classify/run_classify.sh` 加 `RESEED` 开关，并把 `dim-l3-classify-merge` SKILL 里原本的「**禁止** `run_classify.sh prod`」翻转为「不带 RESEED 的 prod 已安全」——这都不是用户要求的，是 Agent 自行改的门控措辞。
- 在方法论 SKILL.md / phases / anti_patterns / lessons 里大段写「seed 三身份（test bootstrap / dim 只读快照 / 灾备回灌）」，把 seed 当合法机制，与两个 merge skill 全程不提 seed 的事实相悖。

**后果**：
- 产出误导性文档与门控；用户连续纠正：「run_classify.sh 这些全是你加的，谁让你加的？」「两个 merge skill 哪里提到要用 seed？」`git blame` 证实 `run_classify.sh` 的引用是历史既有，但**门控措辞翻转 + RESEED + 方法论 seed 叙事**确系本会话擅改。

**根因**：
- 没把「两个 merge skill」当唯一流程权威源，跑去看实现脚本与方法论旁支自行推演，over-engineer；并擅自翻转既有硬门控措辞，未先与用户对齐。

**纠正与防御**（新硬约束）：
1. **流程权威源 = 两个 merge skill**。它们全程不提 seed ⇒ 合并/试错/重建流程不涉及 seed。方法论中凡描述 seed 参与合并、试错期改规则、prod 重建的叙事，一律删除。
2. 回退本会话擅改：`run_classify.sh` 去掉 `RESEED`；`dim-l3-classify-merge` 恢复「**禁止** `run_classify.sh prod`（它会重建 dim、覆盖刚合并的该 L1）」。
3. **不擅自翻转既有门控措辞**；要放宽/收紧任何硬门控，先 `AskQuestion` 与用户对齐再动手。
4. 校验器原名 `validate_classify_seed.py` / `validate_attr_seed.py` 已改名为 `validate_classify_dim.py` / `validate_attr_dim.py`（连 `test_dim`、不读 CSV，引用与子进程调用同步更新）；`sql_scripts/` 下的 `load_seed*` / `sync_attr_std_seed.sh` 及 `**/seed/` 目录属 sql_scripts 代码（非方法论），本轮未触，如需清理另起。

---

## LL-20260604-01 · 试错期改规则的载体：seed 彻底退场，直接改 test_dim 表

**日期**：2026-06-04
**场景**：合并范式翻新（合并只从 `test_dim.*_<l1>` 后缀表替换 prod dim、seed CSV 不再是 dim 的 source of truth，见 LL-20260603-01）后，「阶段 1 试错期改规则的载体」在两条 LL 之间自相矛盾：LL-20260603-04 第 4 点说「`seed/`+`load_seed_*` 仅可选灌空表；改规则只写 `test_dim` 表」；LL-20260603-03 第 1 点却写「试错期只改 test_dim 后缀表来源（沙盒 `seed/*_<l1>.csv` → `load_seed_*`）」，即改 seed CSV 再重灌。用户裁决：**方向 A——seed 彻底退场，试错期也直接改 `test_dim` 表，seed 仅作首次灌空表，与 LL-04 对齐**。

**错误行为**：
- 合并范式翻新时只改了「合并侧」措辞（test_dim→dim），没清理「试错侧」的改规则载体描述，留下「直接改表」与「改 seed 再重灌」两套并存说法。

**后果**：
- 协作者不知道试错期到底改 `test_dim` 表还是改 `seed/*.csv`。
- 电容沙盒 `run_test.sh` 仍每次调 `load_seed_attr_capacitor.py` 从 seed CSV `DROP+CREATE+INSERT` 重灌——若有人直接改了 `test_dim` 表，一重跑就被 seed 覆盖清掉（与方向 A 冲突）。

**根因**：
- seed 的角色从「dim 的 SoT」降级为「首次灌空表的可选初始化」后，文档未把「改规则只走 test_dim 表」这一条贯彻到所有试错期描述与沙盒脚本。

**纠正与防御**（新硬约束）：
1. **试错期改规则 = 直接 `UPDATE`/`INSERT`/`DELETE` `test_dim.dim_*_<l1>` 表**（含 `data_source`/`source_kind`/正则/`value_map`/`priority`）；不再经「编辑 seed CSV → `load_seed_*` 重灌」改规则。
2. **改规则不经任何 CSV 重灌通道，直接写 `test_dim` 表**；合并 prod 仍只走 test_dim→dim。
3. 已校正 LL-20260603-03 第 1 点措辞（改 seed→重灌 改为 直接改 test_dim 表）；SKILL.md §六 与 anti_patterns.md 同步对齐方向 A。
4. **沙盒脚本待整改**（§零 第 4 步，待用户确认后执行）：`run_test.sh` 每次从 seed 重灌会覆盖直接改的 test_dim；应改为「首次建表灌底后不再重灌」或「重灌前先 dump 现有 test_dim」，避免冲掉试错期改动。

**补充（2026-06-04）· 同一错误复发 + 第 4 点落地**

- **复发**：补完 digikey 13 个属性规则后，Agent 又让用户「`python3 load_seed_attr_capacitor.py` 把新 CSV 重灌进 test_dim」——正是本条第 1/2 点禁止的「编辑 seed CSV → load_seed 重灌」改规则通道。用户追问「为什么还要 csv 重灌？到底是哪里的流程？」。根因：Agent 迁就电容沙盒**老脚本现状**（run_test.sh 第 0 步默认 reseed），而非按方向 A 的 test_dim-SoT 模型给出增量写入。
- **落地第 4 点**：用户裁决「迁移沙盒到方法论模型」。已执行：
  1. `sql_scripts/test/capacitor/run_test.sh`：第 0 步默认**不**重灌 test_dim；`SKIP_DIM` 改为正向开关 `BOOTSTRAP_DIM`（默认 0），仅首次建表/从快照重建时 `BOOTSTRAP_DIM=1` 才走 `load_seed_*`。常规跑用现存 test_dim，不会冲掉直接改动。
  2. 新增 `sql_scripts/test/capacitor/patch_digikey_attr_rules_capacitor.sql`：把 13 个属性的 16 行 digikey 规则**直接 `INSERT` 进现存 `test_dim.dim_attr_extract_rule_capacitor`**（增量写入，不整表重灌），替代 CSV 重灌。seed CSV 仅作首次 bootstrap 快照。
- **防御强化**：补规则/改规则**默认产出 = 对现存 `test_dim` 的增量 SQL（INSERT/UPDATE/DELETE）**，不是「改 CSV 让用户 reload」；只有空表首建才提 bootstrap。

---

## LL-20260603-05 · 多源接入缺「按 data_source 的规则覆盖」门控，单源漏建整层规则无法机械发现

**日期**：2026-06-03
**场景**：电容 `feature/digikey_capacitor` 合并 main 时发现 digikey 缺 13 个属性（`capacitance_f` 及全部 L3 专属属性）的抽取规则。排查发现：建 digikey 规则时只覆盖了 `scope_level='l2'` 通用属性（24 个），**整个 L3 层 0 规则**，且容值只做了 `电容范围`→min/max、没做主值 `电容`→`capacitance_f`。阶段 1 却一路绿灯，直到合并改用主干源隔离脚本才暴露。

**错误行为**：
- 多源架构下补规则时，默认「icpdf 有的属性 digikey 也补」没有任何机械校验兜底，纯靠人记忆 + §8.3 手工 SQL 探针（且这次没按源跑）。
- 信了沙盒 `build_dwd_digikey_component_attr_std_capacitor.sql` 的 16.7M 影子 EAV 当阶段 1 基线——该脚本 7 处 rule join 全漏 `AND r.data_source='digikey'`（见 LL-20260603-03，已知不可信、只作参考），icpdf 的 151 条规则越界顶替，把 digikey 缺的 13 个属性「凑」出了值。

**后果**：
- 「某源对某属性/整层 L3 0 规则」这类缺口现有任何校验器都不 FAIL（DX1 只校 schema 级 L3 覆盖，不校 per-source 规则覆盖）。
- 缺陷被越界 build 掩盖 → 阶段 1 影子 EAV 凑到 16.7M 看似正常 → 合并 main 用源隔离脚本后这些属性 digikey 归零，基线无法在生产复现。

**根因**：
- 方法论的多源前提（§二-A：每个源独立补规则行）只有原则、缺机械门控；第 8 原则「L2/L3 覆盖率分开统计」只分 scope、不分 data_source。可机械判定的不变式没配校验器，违背「硬门控必须配可执行校验器」自洽要求。
- 建规则缺口（因）+ 沙盒 build 越界顶替（掩盖器）叠加放大：缺任一个都不会以「合并才发现」的形式爆出。

**纠正与防御**（新硬约束）：
1. **按 data_source 的规则覆盖对称性是合并前必查门控**：同一 L1 出现 ≥2 个 `data_source` 时，某属性被部分源覆盖、另一些源 0 规则 → 每个非对称属性须「补该源规则」或「书面确认该源确无此属性」后方可进入阶段 2 合并。
2. **配可执行校验器**：`validate_attr_dim.py` 新增 **A15**（多源覆盖对称性，WARN+逐条 triage），按 `data_source` 聚合列出每个源缺规则的属性；接进沙盒 `run_test.sh`，合并前必须清零或书面豁免。
3. **阶段 1 影子 EAV 不得作生产基线**：L1 专用沙盒 build 只作参考；行数基线一律以主干源隔离 `build_dwd_component_attr_std_{icpdf,digikey}.sql` 输出为准（与 LL-20260603-03 一致）。
4. 按源跑 §8.3 源-schema gap 探针（半结构 JSON 用 `json_keys()`、平铺 KV 用 `DISTINCT key`），与 A15 互补：A15 查「schema 有属性、该源无规则」，gap 探针查「源端有键、dim 无规则」。

---

## LL-20260603-04 · 沙盒产出应是 test_dim/test_dwd 表，禁止在 test 目录落 CSV/dump

**日期**：2026-06-03
**场景**：用户要求按 test_dim 权威重跑验收；Agent 却在 `test/capacitor/dump/` 导出 CSV 并用其跑 `validate_pipeline`，且未在 test 目录提供「刷 test_dwd」的一键脚本。用户纠正：**不要 CSV**；**test 目录的产出是库表里的 test_dwd/test_dim**，换目录写 CSV 没有意义。

**错误行为**：
- 把「校验」理解成「在仓库里再写一份 CSV」，而不是「连库读 test_dim + 重跑 build 写 test_dwd」。
- 在 test 目录改/新建 CSV 或 `dump/*.csv`，让用户看不到真正的数据产出。
- 未提供 `run_test.sh` 之类端到端脚本，验收步骤散落在对话里。

**后果**：
- test 目录只有 CSV 垃圾文件，没有可执行的验收入口；用户认为「改了一大通却没有产出」。
- 与「合并只认 test_dim 表」一致的方向被 CSV 中间层再次绕开。

**根因**：
- 误读 pipeline 文档里「dump CSV」为要在 `sql_scripts/test/<l1>/` 落盘；实际产出层是 **StarRocks 表**。

**纠正与防御**（新硬约束）：
1. **沙盒产出 = `test_dim.*_<l1>` + `test_dwd.*_<l1>` / `test_dwd.dwd_l2_*`**；禁止在 `sql_scripts/test/<l1>/` 下新建 `dump/` 或任何校验用 CSV。
2. **`validate_pipeline` 连库**：`--dim-schema test_dim --dim-l1-suffix <l1>`（`validate_classify_dim` / `validate_attr_dim` 已支持）；不依赖任何 CSV 文件。
3. **每个沙盒须有 `run_test.sh`**：step0 连库静态校验 → build 刷 test_dwd → 打印行数 → `validate_dwd_data`。
4. 改规则只写 `test_dim` 表，不经 CSV 重灌；合并 prod 仍只走 test_dim→dim。

---

## LL-20260603-03 · P0 补缺时改通用 EAV 引擎或从通用复制的沙盒 build SQL

**日期**：2026-06-03
**场景**：电容沙盒落实 P0（陶瓷 literal、±% 容差、URac 键名）时，Agent 在 `build_dwd_digikey_component_attr_std_capacitor.sql` 上补 `data_source='digikey'` 过滤，并从该文件复制新建 `build_dwd_icpdf_component_attr_std_capacitor.sql` 改 ids/prajson_kv。用户纠正：**不要改通用脚本，从通用脚本复制出来的沙盒脚本也不要改**。

**错误行为**：
- 把「源隔离 / 正则抽取」当成引擎层问题，在沙盒 build SQL 里打补丁，违背「规则在 dim、引擎不动」。
- 用复制+改写的沙盒专用 EAV 脚本绕开正式层 `build_dwd_component_attr_std_{icpdf,digikey}.sql`，制造与主干分叉。

**后果**：
- 沙盒与 prod 引擎行为不一致，合并 test_dim→dim 后全表回归结论不可信。
- reviewer 误以为沙盒 SQL 是权威通路，掩盖「应只改 `dim_attr_extract_rule` + 用主干引擎重跑」。

**根因**：
- 沙盒 digikey build 历史版本未带 `data_source` 过滤时，用改 SQL 救火，而不是先把规则行 `data_source` 填齐（`icpdf` / `digikey`）并走通用引擎。

**纠正与防御**（新硬约束）：
1. **试错期只改** `test_dim.dim_attr_extract_rule_<l1>` 表本身（直接 `UPDATE`/`INSERT`/`DELETE`，不经 CSV 重灌通道，见 LL-20260604-01），P0/P1 用 `source_kind` / `source_expr` / `literal_std_value` / `source_value_regex` / `value_map` / `priority` / **`data_source`** 表达。
2. **禁止修改** `sql_scripts/2.attribute_standard/` 下通用引擎与 classify 主干；**禁止修改**从主干复制到 `sql_scripts/test/<l1>/` 的沙盒 build SQL（含 `build_dwd_*_component_attr_std_*`、L2 build 若同源复制）。
3. 沙盒重跑只用该目录**既有**脚本；新源验证在正式层用 `build_dwd_component_attr_std_<source>.sql` + 授权后的 test_dim→dim 合并，不新建「改过的沙盒 EAV 副本」。
4. 已回滚沙盒 digikey build 改动并删除新建的 icpdf 沙盒 build；151 条原空 `data_source` 规则已改为 `icpdf`。

---

## LL-20260603-02 · 调整 skills 时用「打补丁 / changelog」式措辞，把迁移叙事写进 skill 正文

**日期**：2026-06-03
**场景**：把 methodology 主文档及子文档与新合并范式对齐时，Agent 在 SKILL.md / phases / pipeline / anti_patterns 正文里大量写「自 main 起」「已废弃 seed CSV append」「翻转为」「范式变更（自 main）」「替代旧 verify hash」「provenance 从维护态 seed 文件变成…」这类描述「从前怎样、现在改成怎样」的迁移叙事。用户纠正：调整 skills 不要用这种打补丁的形式。

**错误行为**：
- 把 skill 正文当 commit message / changelog 写，记录"这次相对上一版改了什么"。
- 正文里保留对已淘汰做法的引用与对比（「不再是…」「已取代旧…」），而不是直接陈述当前态规则。

**后果**：
- skill 正文混入版本迁移叙事，无上下文的读者分不清「当前权威规则」与「历史包袱」；多次迭代后正文越积越乱、自相矛盾。

**根因**：
- 误把"文档同步升级"理解成"在文档里描述这次升级"。skill 是**当前态权威**，不是变更日志。

**纠正与防御**（新硬约束）：
1. skill 正文（SKILL.md / phases / pipeline / anti_patterns）**只陈述当前规则是什么、禁止做什么**；不出现 `自 X 起` / `已废弃` / `翻转为` / `替代旧 X` / `范式变更` / `不再是…` 等迁移叙事。
2. 版本迁移、"这次改了什么"只写进 `lessons_learned.md`（本文件就是历史日志，叙事写这里是对的）。
3. 已同步：`SKILL.md` §六 新增本条硬门控；`anti_patterns.md` 新增一行；并已清洗本次引入的全部补丁式措辞。

---

## LL-20260603-01 · 合并范式：按 L1 从 test_dim 后缀表替换 prod dim + L2 脚本目录化

**日期**：2026-06-03
**场景**：从 main 合并 `feature/digikey_capacitor` 时发现，main 已重写 `.cursor/skills/dim-l3-classify-merge` 与 `dim-attr-std-merge` 两个施工 skill：合并机制不再 append 共享 `seed/*.csv`，改为「按 L1 从 `test_dim.*_<l1>` 后缀表直接替换 prod dim」；同时 `2.attribute_standard/` 下 L2 脚本被收纳进 `<NN>_<l1>_ready/` 子目录。用户确认 seed CSV 已不再是 dim 的 source of truth。methodology 主文档与 `phases/6_release_gate.md`、`pipeline_and_validation.md` 仍停留在旧的「seed CSV 是 source of truth」范式，与子 skill 矛盾。

**错误行为（潜在）**：
- 若按旧 methodology 行事，会继续 append `seed/*.csv` + 跑 `sync_*_seed.sh` / `load_seed.sh` / `check_seed_drift.py`，而新流程已废弃这些通道。
- 误用 `run_classify.sh prod` 重建 dim，会覆盖刚从 test_dim 写入 prod 的该 L1 dim。
- L2 脚本平铺在 `2.attribute_standard/` 顶层、或 `<NN>_<l1>/` 与 `<NN>_<l1>_ready/` 双目录并存，导致 `run_attr_std.sh` 映射与 reviewer 状态判断错乱。

**后果**：
- 文档与施工 skill 范式不一致 → 无上下文会话按主文档跑会走废弃通道、或覆盖刚替换的 prod dim。

**根因**：
- 合并机制（部署侧）演进了，但承载方法论的主文档没同步翻转。
- 目录约定（`<NN>_<l1>_ready/` + `run_attr_std.sh` 映射）是 main 新增的工程约定，主文档 §六-B 未登记。

**纠正与防御**（新硬约束）：
1. **合并范式**：新 L1/新源合并 = 「PK 预检（只锁撞其他 L1）→ 质量检查 → 只读列出删除/写入范围 → 授权后 `dim.bak_*_<l1>_<merge_tag>` 备份 → 删 prod 旧 L1 → 从 test_dim 后缀表 insert」；禁止 append seed CSV / 禁止 `sync_*_seed.sh`·`load_seed.sh`·`check_seed_drift.py`·`pull_seed_drift.py` 作合并通道；`dim_unit_factor` 只追加缺失单位；回滚从 `bak_*_<merge_tag>` 恢复；classify 重建用主干 `dwd_component_class.sql`，**禁止** `run_classify.sh prod`。
2. **L2 脚本目录化**：正式层 L1 的 `dwd_l2_*.sql`+`build_dwd_l2_*.sql` 放进 `<NN>_<l1>_ready/`（`NN`=l3_id 前两位段，`_ready`=已梳理）；占位目录 `git mv` 改名加 `_ready`，禁止双目录并存；同步更新 `run_attr_std.sh` 的 `l1_dir()`/`l2_files_for_l1()`。
3. **校验器 CSV provenance**：`validate_*_seed.py` 入参 CSV 改为 `test_dim.*_<l1>` 后缀表 dump（不再是维护态 seed 文件）；校验器代码不变。
4. 已同步更新：`SKILL.md` §二-A.C / §六（两条新硬门控）/ §六-B（目录规范）/ §七；`phases/6_release_gate.md`（6.2.1/6.2.2/6.2.4/6.4.1/6.5.3/6.8）；`pipeline_and_validation.md`（provenance 说明）。

---

## 模板（新增条目复制此段）

```
## LL-YYYYMMDD-NN · 一句话标题

**日期**：YYYY-MM-DD  
**场景**：

**错误行为**：

**后果**：

**根因**：

**纠正与防御**（新硬约束）：

1. 
2. 
3. 
```
