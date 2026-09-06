# 反模式与工程基础设施

> 反模式按"通用 / 外部验证"两组列出。配套基础设施在最后一节。

---

## 1. 通用反模式

| 反模式 | 为什么糟 | 正确做法 |
|--------|---------|---------|
| 引擎里写 `WHERE l1_code='resistor'` | 多品类合并后静默丢数据 | 引擎与 dim 解耦，过滤全部在 dim 里 |
| 未命中规则就兜底归到大类 | 掩盖真实的数据问题 | 落 `unclassified`，靠探针迭代 |
| 单位字典只覆盖"标准写法" | 源端变体拿到 NULL | 全集核对，含全角/大小写/拼写错误 |
| 同一属性靠 IF/CASE 选源 | 不可维护，无法局部调整 | 每条候选路径独立打 priority |
| 跳过窄表直接做宽表 | 宽表口径漂移、互不一致 | 强制走"窄表 → 透视"两阶段 |
| 改规则不留探针痕迹 | 半年后没人记得为什么这么改 | 改规则前后各跑一次探针，留输出在仓库 |
| 在通用表上直接试错 | 污染其它品类 | 每个新品类先开并列沙盒，跑顺再合并 |
| **L2 宽表末尾叠 `_capacitor` 沙盒后缀** | 与正式命名不一致，用户/合并脚本查不到表；出现 `fixed_capacitor_capacitor` 重复 | L2 命名固定 `dwd_l2_{l1}_{l2_code}`；沙盒后缀只用于 classify/EAV/dim 通用表 |
| `l2_code` 列宽给小了 | 加新 L2 时静默截断 | 一开始就给宽（如 VARCHAR(96)） |
| 为某属性补规则后不重跑覆盖率探针 | 可能因 priority 竞争导致覆盖率不升反降 | 每次补规则后必须对比该属性修前/修后的覆盖率 |
| 多路径 priority 赋值随意 | 高 priority 数（低优先级）路径质量差时，反而压制低 priority 数（高优先级）的高质量路径 | 先探查各路径的实际非空率，非空率高的路径赋更小的 priority 数 |
| EAV 引擎 JOIN 的分类结果表没有确认 | 分类结果在沙盒表，引擎却 JOIN 正式表，EAV 静默为空 | 每次跑 EAV 前先确认分类结果表与引擎 JOIN 目标一致（见 phases.md 4.2 节） |
| L3 专有属性和 L2 公共属性混用同一 NULL 率报表 | 大量"正常 NULL"（非该 L3 的物料）淹没真正的清洗质量问题 | L2 和 L3 属性空值率分开统计，分母不同 |
| **分类层产出 L3，但属性 schema 没建对应 `scope_level=l3` 条目** | `ext_attributes` 恒为 `{}`，L3 专有信息整层丢失，且 `run_test` 全绿无人察觉 | 机械门控：每个非 `_unclassified` 的分类 L3 必须被 `dim_attr_schema` L3 条目覆盖（validate_dwd_data 连库 C×A 交叉）；缺一即 ERROR |
| **build SQL 用 `parse_json('{}')` 写死 ext_attributes** | 看似有 ext 列实则永远空，是"阶段 3 未完成"的伪装 | 视为未完成标记；必须改接 `scope_level=l3 → ext_attributes` 透视后方可进入发布门控 |
| **skills/ 下校验器依赖 skills 目录外文件（读 sql_scripts 下文件、sys.path 外挂）/ 强行接进某沙盒 run_test.sh** | 换项目、换目录布局即失效，方法论工具不可移植；与某沙盒脚本强耦合后牵一发动全身 | skills 校验器零外部文件依赖：只允许标准库 + 已声明 pip 包（pymysql 等），一切输入经 CLI/env 传入；是否接 run_test.sh 由沙盒自定，方法论侧默认不接（LL-20260529-13） |
| **凭沙盒目录缺同名文件就断言「某源/某品类缺脚本」，照模板新建多余脚本** | 把局部沙盒（test_dwd 单源试点）当成全局唯一通路，无视正式层（dwd/dim 多源合一）早已上线；制造双份逻辑分叉，被用户连续纠正 | 接入新源/新品类前先全项目盘点：glob `sql_scripts/**/*<品类>*` 与 `**/build_dwd_*<源>*`，区分正式层与沙盒；以正式层 `build_dwd_l2_*` 的 `src_param`/源 UNION 为「是否已接入」权威依据；用户连续≥2 次纠正同一认知即停手重盘 + AskQuestion 对齐（LL-20260529-14） |
| L2 build 未过滤 `_unclassified` 行 | 分类未定的物料写入业务宽表，污染下游分析 | WHERE 加 `AND l3_code NOT LIKE '%_unclassified'` |
| `brand` 列宽使用 VARCHAR(128) | 标准化后品牌全称可能超过 128 字符，静默截断 | `brand` 列固定使用 VARCHAR(256) |
| `manufacturer` 列加 COALESCE 兜底到品牌名 | 同品牌可能有多个制造商，兜底后丢失制造商维度 | manufacturer 只来自 EAV，没有就是 NULL |
| 合并前跳过 PK 冲突预检直接执行 UNION INSERT | 重复 PK 被 REPLACE 语义静默覆盖，旧数据丢失且无任何报错 | 合并前必须先跑 PK 冲突预检 SQL，结果为 0 行才能继续 |
| 合并新 L1 后不重跑已有 L1 的 L2 build | 已有 L2 宽表使用合并前 EAV 快照，产生跨 L1 时间层漂移 | 合并后统一重跑所有 L2 build（幂等） |
| rule_id / l3_id 开发时不带 L1 前缀 | 合并阶段出现 PK 冲突，被迫改 ID 重新测试 | 开发期就强制 `<l1>_` 前缀，l3_id 用 L1 专用数字段 |
| **合并新 L1 时绕开 test_dim→dim 替换、用别的通道直接写 prod dim** | 规则 dim 真相是 test_dim 后缀表；绕开替换式发布会与备份/回滚机制脱节，且无人维护一致性 | 按 L1 从 `test_dim.*_<l1>` 后缀表替换 prod dim：备份 `bak_*_<merge_tag>` → 删旧 L1 → insert from test_dim；`dim_unit_factor` 只追加缺失单位（LL-20260603-01） |
| **调整 skills 用打补丁 / changelog 式措辞（`自 X 起`/`已废弃`/`翻转为`/`替代旧`/`范式变更`）** | skill 正文混入迁移叙事，读者分不清「当前规则」与「历史」；越积越乱 | 正文只陈述当前态权威规则 + 禁止项；版本迁移历史只写进 `lessons_learned.md`（LL-20260603-02） |
| **P0 补缺时改通用 EAV 引擎或改从通用复制的沙盒 build SQL** | 沙盒与 prod 引擎分叉，违背「规则在 dim」；合并后回归不可信 | 只改 `test_dim` 规则（含 `data_source=icpdf`/`digikey`、正则、`literal`）；沙盒用既有 build；全源用正式层 `build_dwd_component_attr_std_*.sql`（LL-20260603-03） |
| **多源接入只补某一源规则、靠沙盒影子 EAV 有值就判定另一源已覆盖** | 某源对某属性/整层 L3 0 规则时，沙盒 build 可能漏源隔离、被他源规则越界顶替凑出假数据；阶段 1 全绿，合并用源隔离脚本后该源整层归零、基线无法复现 | 同 L1 ≥2 源时跑 `validate_attr_dim.py` **A15 [FAIL]**（按 `data_source` 列出该源缺规则的属性，未补未豁免即阻断；豁免 `--attr-source-waiver L1:SOURCE:CODE`）+ 按源跑 §8.3 gap 探针；行数基线一律以主干源隔离 `build_dwd_component_attr_std_*.sql` 为准（LL-20260603-05、LL-20260604-03） |
| **靠人读 WARN 来 triage 可机械阻断的覆盖缺口** | A15 当 WARN 时退出码 0，沙盒 `run_test.sh` 不 fail-fast，没人读就溜过去（13 条缺规则正是这样溜到合并才爆） | 可机械判定的覆盖缺口一律 FAIL + 留逃生阀（豁免清单）：A15 升 FAIL，机器不能区分「漏建/真无」的部分用 `--attr-source-waiver`/env 显式人工登记，不在清单又没覆盖即阻断（LL-20260604-03） |
| **单源 build 脚本 join 规则表漏 `AND <alias>.data_source='<src>'`** | 他源规则越界顶替，把该源缺的属性「凑」出值，成为掩盖缺规则的「掩盖器」，使阶段 1 影子产出失真 | 用 `validate_build_source_isolation.py`（B1/B2 [FAIL]）静态扫单源 build：凡 join `dim_attr_extract_rule*`/`dim_l3_classify_rule*` 必带 `<alias>.data_source='<src>'`；接进沙盒 `run_test.sh`（LL-20260603-03、LL-20260604-03） |
| **在 test 目录写 CSV/dump，不用库表做沙盒产出** | 用户看不到 test_dwd 产出；与「表为权威」冲突 | 试错期**直接改 `test_dim.dim_*_<l1>` 表**（UPDATE/INSERT/DELETE）；`run_test.sh` 刷 `test_dwd`；`validate_pipeline --dim-schema test_dim` 连库（LL-20260603-04 / LL-20260604-01） |
| **合并后用 `run_classify.sh prod` 重建分类** | 它会重建 dim，覆盖刚从 test_dim 写入 prod 的该 L1 dim | classify 重建只用主干 `dwd_component_class.sql`（不动 dim）（LL-20260603-01） |
| **L2 脚本平铺在 `2.attribute_standard/` 顶层，或 `<NN>_<l1>/` 与 `<NN>_<l1>_ready/` 双目录并存** | runner `l1_dir()` 映射与 reviewer 状态判断错乱 | L2 脚本入 `<NN>_<l1>_ready/`（NN=l3_id 前2位段）；占位目录 `git mv` 加 `_ready`；同步更新 `run_attr_std.sh` 的 `l1_dir()`/`l2_files_for_l1()`（LL-20260603-01） |
| test_dim 后缀表自身存在重复 PK | StarRocks REPLACE 语义静默吞行，DB 行数少于预期，无任何报错 | 合并前对后缀表做自身 PK 去重检查（release_gate 6.2.4） |
| 测试环境 `dim.→test_dim.` 全替换 | test_dim 没有 `v_std_brand_alias`，L2 build 找不到品牌字典 | L2 build 在 test 环境时只替换 dwd 表名；`dim.` 保留指向 prod |
| **L2 编码 `l2_code` 带 `_base` 后缀（如 mcu_base/dsp_base）** | 把实现层"基类"塞进业务 taxonomy；与权威 taxonomy 不一致，分类/属性/宽表三处 l2_code 错位，透视 JOIN 落空 | L2 用业务编码 `mcu`/`mpu_soc`/`dsp`，无 base；机械校验 `validate_classify_dim.py` C7 / `validate_attr_dim.py` A12 |
| **把属性维度拆成 L3（DSP 拆 fixed/float/multi_point_dsp）** | 定点/浮点/核心数是参数不是分类；拆成 L3 后属性 schema 对不齐 → ext_attributes 恒空、DX1 必 FAIL | DSP 的 L3 只有 `general_programmable_dsp`+`audio_dsp`（以 Excel `DSP_Base` 为准）；定点/浮点/核心数走属性字段（arithmetic_type/has_floating_point/dsp_core_count）（LL-20260529-15） |
| **把 `dim_l3_classify_all.sql` 当 L1/L2/L3 全维度权威，校验器拿它逐字段比对 L2/L3** | 该表 L2/L3 仅供参考、可能过时；逐字段比会对 capacitor/resistor 等改名品类产生大量假阳性 FAIL，淹没真正的 L1/id 段问题；且校验器若依赖 Excel，无 Excel 的协作者无法跑硬门控 | 该表只对 L1 维度权威（合法 L1 集合 + l3_id 段前2位一对一）；L2/L3 以各品类 Excel schema 为准；`validate_classify_dim.py` C1 只校 `l1_code 合法 + l3_id 段归属`，零 Excel 依赖（LL-20260529-16） |
| **删/合并 L3 节点后只删不重排，留下 l3_id 跳号（190301+190304）** | id 体系不自洽，无法从 id 判断 L2 下有几个 L3 / 是否遗漏；后续分配易撞已挖空的号 | 同一 (l1,l2) 内 l3_id 从 01 连续递增无跳号，删节点后补齐重排；机械校验 `validate_classify_dim.py` C8（LL-20260529-17） |
| **把 `schema_version` 当规则迭代号（v1.0.00/v1.1.00/v1.2.00），与 Excel schema 版本脱节** | 同一 L1 分类树/规则混多版本 → classify 引擎 `JOIN ON schema_version` 零产出；协作者无法反查对应哪份 Excel | 分类 dim+规则 dim 统一 = Excel 文件名版本（`{l1}_schema_v5.20.xlsx` → `v1.5.20`）；属性 dim = `{l1}_schema_v1.5.20`；机械校验 C10（LL-20260601-01） |
| **std_attr_code 出现大写 / 连字符 / 空格** | 跨工具大小写敏感时查询失败、与下游 JSON key 不一致 | 强制正则 `^[a-z][a-z0-9_]*$`；合并前必跑命名扫描 |
| **L2 宽表 DDL 列名 ≠ std_attr_code（PascalCase / 大小写不一致）** | EAV 透视映射错乱、BI 工具大小写敏感查询失败、与 ext_attributes JSON key 不统一 | DDL 列名必须与 std_attr_code 完全一致，含大小写 |
| **同名 std_attr_code 跨 L1 类型分裂（如 reach 一边 BOOLEAN 一边 VARCHAR）** | 跨 L1 SQL UNION 报错或隐式转换出错；消费方代码要分支处理；schema 治理失效 | 5.5.4 类型分裂扫描必须 = 0 行；统一规则见阶段 3.2.3 |
| 发现类型分裂后保留两种类型 + 消费方 CAST 兼容 | 把分裂从 schema 推给消费方，雪上加霜 | 必须升级到唯一类型，绝不允许 `CASE WHEN l1_code=... THEN CAST(...)` 这种妥协 |
| 跳过 5.5 数据质量审计直接合并 | 测试机器指标通过但漏抽规则 / schema gap / 单位换算错未被发现 | 5.5 是阶段 6 的硬前置：未产出审计报告不进入合并 |
| 仅看 brand_null / dt-di / 行数就认为测试通过 | 这三项只覆盖品牌侧，对 L2 空值率、单位换算合理性、源-schema gap 完全没保障 | 把空值率扫描、gap 探查、单位抽样都纳入"测试通过"定义 |
| 补一条规则后只看是否报错、不看覆盖率 diff | priority 抢错时空值率反而上升，机器不报错；补了等于负优化 | 每补一条规则必须复跑 EAV+L2，对比该列修前/修后空值率（5.5.4） |
| Agent / 脚本未经人工授权自动跑 prod | 测试通过不等于业务确认；agent 自行决定发布会越权且无追溯人 | prod 写操作必须由发布权限人显式触发；`ALLOW_PROD=1` 不应由 Agent 设置（6.0 节） |
| SOP 步骤排到了 prod 就连着跑 | SOP 是流程图不是授权书；test → prod 边界每次都要独立放行 | 每次跨越 test → prod 边界都需要单独的人工确认 |
| **L1 试点 / sandbox / e2e 脚本自动调用 `sync_dim_std_brand.sh`** | 该脚本"先 DROP 后 INSERT FROM ods"；权限不足或 ods 不可用时，**只完成 DROP**，把原字典清空，污染全部 L1 | 品牌字典是只读基础设施；试点流程只 SELECT，缺数据时报告用户而不是自动重建。详见 [lessons_learned.md#LL-20260528-01](lessons_learned.md) |
| **补品牌时只查 `ods.ods_jp_brand`、且按 `name` 字面相等判重** | 漏掉 manual_extra 段已有行（跨源重复）、中英混写（`慧荣科技-SiliconMotion` vs `Silicon Motion Inc`）、长短名（`Lattice` vs `Lattice Semiconductor`）→ 同一公司多 `brand_id_std`，下游 `brandid` 随 build 时机随机命中、聚合口径分裂 | 判重看**归一化键**（大写+去公司后缀+去非字母数字），范围打**整张 `dim_std_brand`**（jp_brand+manual_extra 跨源）；机械门控 `validate_brand_dim_dup.py`（BD1 FAIL，伪重复登记白名单）接进 `sync_dim_std_brand.sh` fail-fast；存量重复用 `sql_scripts/brand_merge/` 收口（LL-20260625-01） |
| **靠宽表门控 `COUNT(DISTINCT brand)=COUNT(DISTINCT brandid)` 兜品牌查重** | 该门控对「同一公司两个 id、两个 brand 文本都非空」是盲的（2=2 仍相等），抓不到字典级一公司多行 | 字典级查重另设 `validate_brand_dim_dup.py`（归一化聚合，同 key 落 >1 id 即 FAIL）；宽表门控只管「brand 与 brandid 一一对应」，两层互补（LL-20260625-01） |
| **丰富 related_words 时未核实别名归属** | 若两家公司名称含同一缩写（如 TOPPOWER），手工追加别名时容易把 A 公司的专属别名（`顶源`、`TOPPOWER(顶源)`）写入 B 公司行；`validate_brand_dim_dup.py` 检测不到（它只看归一化 key，不知道别名该属于谁）→ 视图展开后别名映射到错误品牌 | 追加 related_words 前先用 `SELECT brand_id_std, name FROM dim.dim_std_brand WHERE array_contains(related_words, '<新别名>')` 确认无人持有；若有撞车则别名只加给正确一方；发现脏别名用 `brand_merge/03_merge_dim.py` 的 `DIRTY` 字典做专项清理。见 CONTRIB_BRAND.md §5.8 |
| **jp_brand 裸缩写条目未核实是否为已有品牌的别名** | jp_brand 偶尔会收录只有缩写（如 `FC`、`WF`、`VPSC`）的条目，若同名缩写的 manual_extra 品牌已存在，则形成两行不同 id，`validate_brand_dim_dup.py` 会 FAIL 并把它们打入「占位嫌疑」白名单；但如果白名单只写了"嫌疑"而未回溯确认，将长期存在模糊条目 | 白名单中标记为「占位嫌疑」的条目必须在 **30 天内** 走两步确认：① `SELECT id,name,abbr FROM ods.ods_jp_brand WHERE abbr = '<缩写>'` + 联网查公司官网；② 若确系同一公司 → `brand_merge` 合并并移出白名单；若不同公司 → 更新白名单注释为"不同公司（确认）"固化。见 CONTRIB_BRAND.md §5.9 |
| Agent 被用户纠正后只口头答应，不更新 skills | 同类错误反复发生 | 收到纠正必须按 SKILL.md §零执行：写 lessons_learned + 升级硬门控 + 同步更新反模式表 |
| **DigiKey `category` + `prajson.类型` 含 MCU 就归 MCU L3** | 雷达/RF 收发器/蓝牙/Zigbee/ADC 集成 MCU 在商城仍属传感器、RF、数据转换器；2729+ 行批量误分 | 源端文案≠业务 L3；须商城核对后再写 classify；`TxRx+MCU`/`基于 MCU` 不能单独作 MCU 判据。见 [LL-20260528-03](lessons_learned.md) |
| **把 MCU/MPU/DSP 写成三个 L1** | 分类结果 l1_code 分裂；l3_id 与 `dim_l3_classify_all` 的 19xxxx 段冲突；合并必撞 PK | 一个 L1=`mcu_mpu_dsp`；MCU/MPU/DSP 是 L2；新试点先读 foundation/dim_l3_classify_all。见 [LL-20260528-04](lessons_learned.md) |
| **可机械判定的硬规则只写进 prompt，不配校验器** | 靠 Agent 自觉比对，上下文压力下反复犯（抄错参考源 / l3_id 撞段 / L1 分裂），只能人工 review 兜底 | 不变式类硬门控必须同时有 prompt 条款 + `tools/` 可执行校验器并接进 run_test.sh fail-fast。见 [LL-20260528-05](lessons_learned.md) |

---

## 2. 外部验证相关的反模式

| 反模式 | 为什么糟 |
|--------|---------|
| 只看内部统计就发布 | 自洽 ≠ 正确，整套字典写错也能跑出"漂亮"指标 |
| **只验参数、不验分类** | 分类错了下游所有 L2 宽表口径都歪，比单个参数错严重得多 |
| **分类草案不去商城核对就建属性 dim** | 在错的分类上盖属性字典是双倍返工 |
| **只看一边商城** | 单边偏差，海外品牌看芯查查、国产看得捷都容易判错 |
| 空值率为 0 就认为列搞定 | 可能抽错源、单位也错、凑巧填满但是值是垃圾 |
| 空值率高就立刻补规则 | 商城可能也没有、或者源端就没有，规则白补 |
| 商城有就立刻补规则 | 跳过了"源端有没有"这一步，规则可能写给"空气"永远不命中 |
| 源端没有就当上游 bug | 也有可能商城给的是计算值/派生值，上游本来就不该有 |
| 分类不符就直接扩大原规则关键词 | 容易吃到别的类目，产生反向误判；应该加约束条件而不是放宽 |
| 改 phase/priority 不跑全表 diff | 全局排序变化会大范围"按下葫芦浮起瓢"，必须配双回路验证 |
| 只抽自己觉得对的样本去商城 | 确认偏差是最大的隐性 bug |
| 商城页一闪而过、不留证据 | 改完没法回归 |
| **DigiKey 源端 `TxRx+MCU` / `基于 MCU` 文案当 MCU 分类依据** | 雷达、RF 收发器、ADC 集成片在商城不属于 MCU L3 | 必须商城核对后再写规则；禁用仅靠 prajson 文案的 MCU 路由 |

---

## 3. 配套的工程基础设施

要让方法论跑得动，最好预先准备：

1. **探针 SQL 模板**：三个通用探针以 SQL 模板形式内嵌在 [SKILL.md §八](probes.md)，替换占位符后直接粘贴到 mysql 客户端执行；无需额外脚本。

2. **基线 CSV 仓库**：每次发布把核心指标（行数、空值率、分布）落 CSV，跟代码一起进版本控制。

3. **抽样落盘工具**：把易错 case 的全字段以 TSV 落到 `artifacts/<l1>/`，方便不会写 SQL 的同事 review。

4. **外部对照 TSV 模板**：固定列结构（见 `decision_guides.md` 第 3 节），每轮迭代留一份。

5. **dim 字典的 test_dim 后缀表 + 按 L1 替换发布机制**：
   - 新 L1 / 新源的规则落在 `test_dim.*_<l1>` 后缀表（dev 期沙盒）
   - **test 验证**：后缀表跑通分类/EAV/L2 + 静态校验（喂后缀表 dump 出的 CSV）
   - **发布 prod**：用户授权后 `dim.bak_*_<l1>_<merge_tag>` 备份 → 删 prod 旧 L1 → 从 test_dim 后缀表 insert；回滚从备份表恢复（LL-20260603-01）

6. **diff 验收脚本**：跑新版 vs 旧版的分布差异、空值率差异，输出可读报表。

7. **品牌字典维护工具**：当 `brand_null > 0` 时，能快速找出未覆盖的 `brandshort` 并补录到 `dim_std_brand` 或 `v_std_brand_alias`。品牌字典按 dim 字典同等管理——沙盒期写 `test_dim`、随 L1 合并入 prod，可追溯、可回滚。

8. **PK 冲突预检脚本**：合并前一键运行，输出"可安全合并"或"冲突 N 行，需处理"，避免合并过程中手动拼 SQL。

9. **数据质量探针套件（5.5 阶段强依赖）**：三个探针 SQL 模板统一维护在 [SKILL.md §八](probes.md)：
   - §8.1 空值率扫描 — L2 物理列空值率 + 品牌门控验收
   - §8.2 分层抽样 — 阶段 1 源探查 / 阶段 5 迭代抽样
   - §8.3 schema gap — 源端高频键 vs dim_attr_extract_rule 覆盖缺口

10. **人工授权门控机制**：
    - `ALLOW_PROD=1` 环境变量"双手开车"，物理阻止 Agent 单独发布
    - 发布前必须有 5.5 审计报告 + 业务签字留痕（PR / Ticket）
    - test → prod 边界每次独立放行，不依赖 SOP 节奏
