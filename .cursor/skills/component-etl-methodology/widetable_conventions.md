# 宽表工程约定（封装参数 + 建表规范）

> 本文件是 [SKILL.md](SKILL.md) 的横向参考之一，承载 L2 宽表的**建表权威规范**：封装/安装列约定（§六-A2）+ schema/命名/公共列/ext_attributes（§六-B）。所有 L2 宽表 DDL 以本文件为准；机械校验见 `tools/validate_l2_widetable.py`。

---

## 六-A2、封装参数标准化约定

> **基准表**：`dwd.dwd_l2_resistor_fixed_resistor`（电阻宽表），所有新 L2 宽表在本节描述的封装属性上须与之保持一致。

### 封装方式 vs 安装方式 的概念区分

这是两个**独立属性**，必须分列存储，不得合并：

| 属性 | 列名 | 类型 | 说明 |
|------|------|------|------|
| **封装方式** | `package_case` | VARCHAR(512) | 物理封装形态，如 SOT-23-5、DFN-6、QFN-16、SOIC-8、DIP-8 等；来自器件规格书或参数数据库 |
| **安装方式** | `mounting_style` | VARCHAR(128) | PCB 安装工艺，取值：`smd` / `through_hole` / `chassis` / `panel` / `other` |

**为什么要区分？**
- 同一封装形态可对应不同安装方式（如 TO-220 有 `through_hole` 和 `smd` 两种变体）
- 下游 PCB 工艺筛选需要 `mounting_style`，而布局设计需要 `package_case`
- 混用会导致工艺筛选错误：把 TO-92 当 smd 会导致贴片工艺排废

### schema 中没有 mounting_style 时的处理规则

若 schema 原始定义中只有 `package_case` 而没有 `mounting_style`，**只要源数据中存在可推导的封装信息，就应补充 `mounting_style` 列**。

**推导优先级（高 → 低）：**

1. **优先**：源数据中有明确的安装方式字段（icpdf：`prajson2.安装方式` / `安装类型`；digikey：参数 KV 表 `key='安装类型'` 对应 value；其他源等价字段）→ 直接映射到下表标准值
2. **次选**：从源端"封装形式"等价字段（icpdf：`prajson2.封装形式`；digikey：`key='封装类型'`；其他源对应字段）推导：

| 封装形式取值 | mounting_style |
|------------|----------------|
| `IN-LINE` | `through_hole` |
| `CYLINDRICAL` | `through_hole` |
| `SMALL OUTLINE*`（含各变体）| `smd` |
| `CHIP CARRIER*` | `smd` |
| `GRID ARRAY*` | `smd` |
| `FLATPACK` | `smd` |
| `MICROELECTRONIC ASSEMBLY` | `smd` |
| `FLANGE MOUNT` | 需结合 `包装说明` 二次判断（见下） |
| `UNCASED CHIP` | `other`（裸芯片/模组内嵌，无标准安装方式） |

3. **兜底**：从 `包装说明` 或 `package_case` 列的文本关键词推导：

```sql
CASE
    WHEN UPPER(pkg_desc) REGEXP 'DIP|TO-92|TO-220|TO-3[^A-Z0-9]|SIP|ZIP|THRU.?HOLE|THROUGH.?HOLE'
         THEN 'through_hole'
    WHEN UPPER(pkg_desc) REGEXP 'D2PAK|DPAK|SOT|SOP|DFN|QFN|QFP|BGA|LGA|TSSOP|TSOP|CSP|WLCSP|LLP|LFCSP'
         THEN 'smd'
    ELSE NULL   -- 无法推导，保持 NULL，不要拍脑袋填默认值
END AS mounting_style
```

### 列声明规范

```sql
-- 在所有 L2 宽表中，封装参数区块按以下顺序声明：
`package_case`    VARCHAR(512) NULL COMMENT '封装形式，如 SOT-23-5 / DFN-6 / QFN-16',
`mounting_style`  VARCHAR(128) NULL COMMENT '安装工艺：smd / through_hole / chassis / panel / other',
`pkg_length_mm`   DOUBLE       NULL COMMENT '封装体长度 mm',
`pkg_width_mm`    DOUBLE       NULL COMMENT '封装体宽度 mm',
`pkg_height_mm`   DOUBLE       NULL COMMENT '封装体高度 mm',
```

**强制约束：**
- `mounting_style` 标准取值只能是 `smd` / `through_hole` / `chassis` / `panel` / `other` / NULL，全部**小写英文**，不允许写中文、大写缩写（`SMD`、`THT` 均为非法值）
- `package_case` 保持原始规格书描述，不做标准化截断（保留引脚数，如 SOT-23-**5** 不能变成 SOT-23）
- 两列均允许 NULL；**推导不出来就是 NULL**，不要填写推测值

---

## 六-B、宽表工程约定（建表规范）

### Schema 命名规则

| 环境 | DWD 宽表 | DIM 字典 |
|------|---------|---------|
| **测试环境** | `test_dwd` | `test_dim` |
| **生产环境** | `dwd` | `dim` |

- 所有建表、建索引默认在 **测试环境**（`test_dwd` / `test_dim`）执行。
- 切换到生产时，仅修改生成脚本顶部的 `DWD_SCHEMA` / `DIM_SCHEMA` 常量，DDL 结构不变。
- **Agent 不得自行将常量改为生产值**，须人工确认后执行。

### L2 脚本目录规范（硬约束）

正式层 `sql_scripts/2.attribute_standard/` 下，每个 L1 的 L2 宽表脚本（`dwd_l2_*.sql` DDL + `build_dwd_l2_*.sql`）**收纳进按 L1 分段的子目录**，而不是平铺：

```
sql_scripts/2.attribute_standard/<NN>_<l1>_ready/
├── dwd_l2_<l1>_<l2>.sql
└── build_dwd_l2_<l1>_<l2>.sql
```

- **`NN`** = 该 L1 的 `l3_id` 前两位段（与 `foundation/dim_l3_classify_all.sql` 一致），如 `01_pmic`、`05_diode`、`10_capacitor`、`11_resistor`、`19_mcu_mpu_dsp`。
- **`_ready` 后缀 = 状态标识**：该 L1 属性规则已梳理完、脚本可用。未梳理品类用占位目录（`02_amplifier/` 仅含 README）。
- **目录改名用 `git mv`**：占位目录 `<NN>_<l1>/` 跑通后 `git mv` 成 `<NN>_<l1>_ready/`，**禁止** `<NN>_<l1>/` 与 `<NN>_<l1>_ready/` 双目录并存（会让 runner 映射和 reviewer 误判状态）。
- 入仓后必须同步更新 `run_attr_std.sh`：
  - `l1_dir()` 加 `<l1>) echo "<NN>_<l1>_ready" ;;`
  - `l2_files_for_l1()` 加该 L1 的全部 `<l1>_<l2>` 后缀
- 引擎/字典脚本（`build_dwd_component_attr_std_*.sql`、`dwd_component_class.sql` 及 dim DDL）仍留在 `2.attribute_standard/` 顶层，不进 L1 子目录。

### L2 宽表命名（硬约束）

- **表名**：`dwd_l2_{l1_code}_{l2_code}`（示例：`dwd_l2_capacitor_non_polar_fixed_capacitor`）
- **test/prod 仅 schema 不同**（`test_dwd` / `dwd`），表名本身不变
- **禁止**在 L2 表名末尾加 `_capacitor` 等沙盒后缀；`_capacitor` 后缀只用于通用引擎并列表（`dwd_component_class_capacitor`、`dwd_component_attr_std_capacitor`、`dim_*_capacitor`）
- 踩坑详情：[lessons_learned.md#LL-20260528-02](lessons_learned.md)

### 公共列规范（所有 L2 宽表必须与 dwd_l2_resistor_fixed_resistor 保持一致）

```
标准头部（顺序固定）：
  data_source VARCHAR(32)   NOT NULL    — 数据来源：icpdf | digikey | mouser ...（复合 PK 第一列）
  id          BIGINT        NOT NULL    — 组件唯一 ID（复合 PK 第二列）
  mpn         VARCHAR(1024) NULL        — 制造商料号
  brand       VARCHAR(256)  NULL        — 标准品牌名（dim_std_brand；未命中回退 raw）
  brandid     BIGINT        NULL        — 标准品牌 ID
  l1_code     VARCHAR(32)   NOT NULL    — L1 大类编码（如 pmic / resistor / capacitor）
  l2_code     VARCHAR(32)   NOT NULL    — L2 编码，本表内为常量
  l3_code     VARCHAR(64)   NULL        — L3 形态编码

L2 专有属性（来自 dim_attr_schema，列名全部小写 snake_case）

标准尾部（顺序固定）：
  ext_attributes  JSON NULL             — L3 专有属性 KV 包
  semantic_tags   JSON NULL             — 业务标签数组
  dq_score        DOUBLE NULL           — 数据质量综合分（预留）
  dq_flags        JSON NULL             — 数据质量标记（预留）
  source_id       BIGINT NULL           — 来源表原始 id
  create_at       DATETIME NULL DEFAULT CURRENT_TIMESTAMP
  update_at       DATETIME NULL DEFAULT CURRENT_TIMESTAMP
```

**强制约束：**
- 列名必须小写 snake_case，与 `dim_attr_schema.std_attr_code` 一致。
- `data_source` 是多源架构的区分键，**必须在头部且 NOT NULL**；不得移至尾部或设 NULL。
- 头部已有 `mpn` / `brand` / `brandid`，L2 属性中不得再定义同名列。
- DDL 语法使用 StarRocks（`ENGINE=OLAP PRIMARY KEY(\`data_source\`, \`id\`) DISTRIBUTED BY HASH(\`id\`) BUCKETS 16`）。
- 数据类型：`DOUBLE`（不是 DOUBLE PRECISION）、`JSON`（不是 JSONB）、`DATETIME`（不是 TIMESTAMP）。
- **不得**自行定义平台级公共列（如 `component_id`、`l2_type`、`created_at`）。

### L3 属性的 `ext_attributes` 存储约定

宽表列布局遵循以下分层规则：

```
L2 专有属性  →  独立列（支持直接 WHERE / GROUP BY）
L3 专有属性  →  ext_attributes JSON 列（键名 = attr_en lowercase，按 l3_code 路由解析）
```

**为什么不将 L3 属性展开为独立列？**

1. **防列爆炸**：多个 L3 子类各有十余个专有参数，展开后宽表列数急剧膨胀，且大量行为 NULL。
2. **L3 子类可扩展**：新增 L3 子类只需往 `ext_attributes` 写新键，无需 `ALTER TABLE ADD COLUMN`。
3. **L2 层查询不受影响**：跨 L2 的通用分析只用独立列，`ext_attributes` 对 L2 层透明。

**使用规范：**

```sql
-- 写入示例（插入一条 Buck_Converter 物料）
INSERT INTO test_dwd.dwd_l2_pmic_switching_dcdc_converter
    (data_source, id, mpn, brand, brandid, l1_code, l2_code, l3_code,
     manufacturer, vin_min_v, vin_max_v, ext_attributes,
     source_id, create_at, update_at)
VALUES
    ('icpdf', 123456, 'TPS62840', 'TI', 9001, 'pmic', 'switching_dcdc_converter', 'buck_converter',
     'Texas Instruments', 1.8, 6.5,
     '{"vout_min_v": 0.6, "vout_max_v": 5.5, "max_duty_cycle_pct": 100, "light_load_mode": "AUTO"}',
     789, NOW(), NOW());

-- 查询示例：取 Buck_Converter 中 vout_min_v <= 0.8V 的物料（StarRocks JSON 函数）
SELECT manufacturer, mpn,
       CAST(get_json_string(ext_attributes, 'vout_min_v') AS DOUBLE) AS vout_min_v
FROM test_dwd.dwd_l2_pmic_switching_dcdc_converter
WHERE l3_code = 'buck_converter'
  AND CAST(get_json_string(ext_attributes, 'vout_min_v') AS DOUBLE) <= 0.8;
```

**索引配置（StarRocks）：**
- StarRocks PRIMARY KEY 表已按 `id` 排序存储，无需额外建 B-Tree 索引。
- 高频过滤列（`l2_code`、`l3_code`、`manufacturer`）可通过 `ORDER BY` 副排序键或 Bitmap Index 加速：
  ```sql
  CREATE INDEX idx_l3 ON test_dwd.dwd_l2_pmic_switching_dcdc_converter (l3_code) USING BITMAP;
  ```
- `ext_attributes` 为 JSON 列，StarRocks 通过 `get_json_string()` 提取；高频键可用生成列（Generated Column）物化后建索引。

**数据质量审计补充（§5.5 扩展）：**

针对 `ext_attributes`，除常规空值率外还需审计：
- `l3_code IS NOT NULL` 但 `ext_attributes IS NULL` 的行比例（L3 参数缺失率）
- `ext_attributes` 中各键的实际存在率（StarRocks `json_keys()` 展开后按键名聚合统计）
- 类型一致性：`CAST(get_json_string(ext_attributes, 'key') AS DOUBLE)` 能否无报错转换
