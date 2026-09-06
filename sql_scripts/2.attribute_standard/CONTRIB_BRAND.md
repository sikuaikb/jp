# 2.attribute_standard · 品牌字典维护 SOP

适用场景：
- 新 L1 / L2 上线后发现 `dwd.dwd_l2_*.brand` 命中率 < 100%；
- 例行品牌字典审计；
- 业务方反馈某个 `brandshort` 没有归到正确的标准品牌。

`ods.ods_jp_brand` 由数据源方维护，本仓库**不修改 ods**——所有补缺通过 `sql_scripts/2.attribute_standard/dim_std_brand_manual_extra.sql` 承载。

---

## 0. 设计原则（必读）

1. **归一化后跨源唯一（最重要）**：同一家公司在 `dim.dim_std_brand` 内**只能有一行**，判重不是看 `name` 字面相等，而是看**归一化键**（大写、去 INC/LTD/CORP/CO/GMBH 等公司后缀、去非字母数字）。判重范围是**整张表**（jp_brand 段 + manual_extra 段 + 任何其它 source），**不是只查 jp_brand**。常见漏网形态：
   - 中英混写 `慧荣科技-SiliconMotion` vs 纯英文 `Silicon Motion Inc`
   - 长短名 `Lattice` vs `Lattice Semiconductor` vs `莱迪斯-LATTICE`
   - jp_brand 段已有 + 别人在 manual_extra 段又建了一行（**跨源重复**是历史第一大坑，见 §5.7）
2. jp_brand 已有母公司/同公司另一写法的品牌**禁止新建独立行**，必须复用其 `brand_id_std`。
3. **related_words 是统一规则入口**：所有匹配都通过 `related_words` 数组展开；若现有品牌覆盖度不足，**重写丰富**它（array_concat + array_distinct + UPSERT），不另起一行。
4. **真重复 ≠ 伪重复**：归一化键相同但**确系不同公司**（如 `Central Semiconductor` 纽约分立半导体 vs `中环` 半导体；`光颉 Viking Tech` vs `Viking Technology`）属于伪重复，**不合并**，登记到 `validate_brand_dim_dup.py` 的白名单（见 §6 校验器）。

两类操作：

| 操作 | 触发条件 | 写法 |
|------|---------|------|
| **A. 重写丰富** | jp_brand 中已存在母公司 / 收购方 / 同一公司另一写法 | 复用 jp_brand 的 `brand_id_std`，StarRocks PK 模型 UPSERT 替换原行，`related_words` 用 `array_distinct(array_concat(...))` 合并 |
| **B. 新增** | jp_brand 完全无收录 | `brand_id_std` 取 **9_000_001+** 段，`name` 唯一 |

---

## 1. 前置条件

- 仓库已 clone，`sql_scripts/local.env` 或 shell `MYSQL_*` 配好 StarRocks 凭据。
- 工作树干净（`git status`），从 `main` 切分支。
- 知道要补的 `brandshort` 字面（从下游 L2 表或 audit 报表得到）。

---

## 2. 流程总览

```
1. 查未匹配的 brandshort 列表
2. 在 jp_brand 内做"母公司"扫描
3. 决定每条走 A 还是 B
4. 编辑 dim_std_brand_manual_extra.sql
5. bash sync_dim_std_brand.sh test  →  验证 test_dim
6. drop test_dim 的 dim_std_brand + v_std_brand_alias
7. ALLOW_PROD=1 bash sync_dim_std_brand.sh prod   ← sync 末尾自动跑查重校验器，红则中止
8. 重跑下游 L2 build（若需立即更新 brand 列）
9. git commit + push
```

> `sync_dim_std_brand.sh prod` 在 sync 成功后会自动调用 `validate_brand_dim_dup.py` 做硬门控：归一化后出现「同公司多 id」且不在白名单，直接非零退出、提示你走 A 复用或登记白名单。**这一步把住了重复不再流入。**

---

## 3. 详细步骤

### Step 1 · 找当前未匹配 brandshort（按 L1 维度）

```sql
SELECT p.brandshort, p.brandid, COUNT(*) AS rows_
FROM dwd.dwd_icpdf_component_param p
INNER JOIN dwd.dwd_component_class c ON c.id = p.id
LEFT JOIN dim.v_std_brand_alias a ON a.brand_key = UPPER(TRIM(p.brandshort))
WHERE c.l1_code = '<your_l1>' AND a.brand_id_std IS NULL
GROUP BY p.brandshort, p.brandid
ORDER BY rows_ DESC;
```

### Step 2 · 跨源「母公司 / 同公司」扫描（**查整张 dim，不止 jp_brand**）

对每个未匹配 `brandshort`，**先查现行 `dim.dim_std_brand` 全表**（jp_brand 段 + manual_extra 段都在内），避免别人已经建过、你又建一行造成跨源重复：

```sql
-- 主查：整张 dim（含 manual_extra），归一化 + related_words 一起命中
SELECT brand_id_std, name, source,
       array_contains(related_words, UPPER('<brandshort>')) AS in_rw
FROM dim.dim_std_brand
WHERE state = 1
  AND ( UPPER(name) LIKE '%<英文>%'
     OR name        LIKE '%<中文>%'
     OR UPPER(name) LIKE '%<母公司/收购方>%'
     OR array_contains(related_words, UPPER('<brandshort>')) );
```

```sql
-- 补查：ods.ods_jp_brand（确认母公司/收购关系的原始出处）
SELECT id, name, abbr FROM ods.ods_jp_brand
WHERE UPPER(name) LIKE '%<英文>%'
   OR name LIKE '%<中文>%'
   OR UPPER(name) LIKE '%<母公司/收购方>%';
```

> ⚠️ 只查 jp_brand、或只做 `name` 字面相等比较，是历史上品牌重复的**头号成因**——别人在 manual_extra 段建的行、或中英混写/长短名的行都会漏掉。**主查一定打在 `dim.dim_std_brand` 全表上。**

历史并购关系可参考已落地的示例（commit `ea91ad4` 内）：

| brandshort | 归到 | 关系 |
|-----------|------|------|
| DALLAS | 美信-MAXIM | Dallas Semi → Maxim → ADI |
| ZETEX | 美台-diodes | Zetex → Diodes Inc |
| COOPER | BUSSMANN | Cooper → Eaton, Bussmann 是 Cooper 子品牌 |
| TAOS | 艾迈斯-AMS | TAOS → AMS |
| HOKURIKU | Hokuriku Electric Industry | 同一公司不同写法 |

### Step 3 · 决策

```
查到 jp_brand 内有母公司 / 收购方 / 同一公司另一名 → 走 A
完全没有 → 走 B
```

### Step 4A · 编辑 manual_extra · **重写丰富**

在 `sql_scripts/2.attribute_standard/dim_std_brand_manual_extra.sql` 的 Part A 段追加：

```sql
/* A.<N> <brandshort> → jp_brand <母公司 name> (id <jp_brand_id>) */
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
SELECT brand_id_std, name, brand_zh, brand_en, abbr,
       array_distinct(array_concat(
           COALESCE(related_words, CAST([] AS ARRAY<VARCHAR(256)>)),
           ARRAY<VARCHAR(256)>['<NEW_ALIAS_1>','<NEW_ALIAS_2>','<中文写法>']
       )),
       logo, state, official_website, level, type,
       'jp_brand+manual_extra', create_at, CURRENT_TIMESTAMP()
FROM dim.dim_std_brand WHERE brand_id_std = <jp_brand_id>;
```

- 注意 `related_words` 写法：**必须**用 `array_concat(原数组, 新别名)`，**不能**直接覆盖（否则丢失 jp_brand 已有的 related_words）。
- `array_distinct` 让 INSERT 幂等。
- `source = 'jp_brand+manual_extra'` 作审计标记。

### Step 4B · 编辑 manual_extra · **新增**

在 Part B 段追加 INSERT VALUES：

```sql
(<下一个 9_000_xxx>, '<标准 name，全局唯一>', '<中文部分或NULL>', '<英文部分>', '<abbr>',
 ARRAY<VARCHAR(256)>['<别名1>','<别名2>','<brandshort 大写>','<中文写法>'],
 NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
```

- `brand_id_std` 从当前最大 `9_000_xxx` 顺延（`SELECT MAX(brand_id_std) FROM dim.dim_std_brand WHERE source='manual_extra'`）。
- **归一化跨源预检（强制）**：走 B 前必须确认整张表没有同一家公司的归一化重复行。仅查 `name = '<候选>'` 字面相等**不够**——下面这条按归一化键扫，命中即说明该走 A（复用既有 id），不能走 B：

```sql
-- 归一化键 = 大写 + 去公司后缀 + 去非字母数字；命中 >0 行说明已存在，改走 A
SELECT brand_id_std, name, source
FROM dim.dim_std_brand
WHERE state = 1
  AND REGEXP_REPLACE(
        REGEXP_REPLACE(UPPER(name),
          '(INC|INCORPORATED|CORP|CORPORATION|CO|COMPANY|LTD|LIMITED|LLC|GMBH|TECHNOLOGY|TECHNOLOGIES|SEMICONDUCTOR|ELECTRONICS|GROUP)',''),
        '[^A-Z0-9]','')
    = REGEXP_REPLACE(
        REGEXP_REPLACE(UPPER('<候选 name>'),
          '(INC|INCORPORATED|CORP|CORPORATION|CO|COMPANY|LTD|LIMITED|LLC|GMBH|TECHNOLOGY|TECHNOLOGIES|SEMICONDUCTOR|ELECTRONICS|GROUP)',''),
        '[^A-Z0-9]','');
```

> 命中但确属**不同公司**（伪重复）才可继续走 B，且必须把归一化键登记进 `validate_brand_dim_dup.py` 白名单（§6），否则 sync 时校验器会 fail-fast 挡下。

### Step 5 · test_dim 验证

```bash
bash sql_scripts/2.attribute_standard/sync_dim_std_brand.sh test
```

```sql
-- 验证 1：主表新增/重写生效
SELECT brand_id_std, name, source, array_length(related_words) AS rw_size,
       array_contains(related_words, 'YOUR_NEW_ALIAS_UPPER') AS hit
FROM test_dim.dim_std_brand
WHERE brand_id_std IN (<列出涉及的 brand_id_std>);

-- 验证 2：视图能展开新别名
SELECT brand_key, canonical_name, brand_id_std, alias_kind
FROM test_dim.v_std_brand_alias
WHERE brand_key IN ('<NEW_ALIAS_1>', '<NEW_ALIAS_2>');

-- 验证 3：原未匹配 brandshort 现在能命中
SELECT p.brandshort, a.canonical_name, a.brand_id_std, COUNT(*) AS rows_
FROM dwd.dwd_icpdf_component_param p
INNER JOIN dwd.dwd_component_class c ON c.id = p.id
LEFT JOIN test_dim.v_std_brand_alias a ON a.brand_key = UPPER(TRIM(p.brandshort))
WHERE p.brandshort IN ('<待补品牌1>', '<待补品牌2>')
GROUP BY p.brandshort, a.canonical_name, a.brand_id_std;
```

三条都通过才走下一步。

### Step 6 · 清 test_dim

```sql
DROP VIEW  IF EXISTS test_dim.v_std_brand_alias;
DROP TABLE IF EXISTS test_dim.dim_std_brand;
```

### Step 7 · 发 prod

```bash
ALLOW_PROD=1 bash sql_scripts/2.attribute_standard/sync_dim_std_brand.sh prod
```

复跑 Step 5 的"验证 1/2/3"切换到 prod 库（`dim.*` / `dwd.*`），全绿。

**查重硬门控**（`sync_dim_std_brand.sh prod` 末尾已自动跑；也可手动单跑）：

```bash
python .cursor/skills/component-etl-methodology/tools/validate_brand_dim_dup.py
# exit 0 = 无新增「同公司多 id」；非零 = 有未登记重复，按提示走 A 复用 / 登记白名单 / 走 brand_merge 收口
```

### Step 8 · 重跑下游 L2 build（可选）

只有当**立即希望** `dwd.dwd_l2_*` 表的 `brand` / `brandid` 列更新时才需要：

```bash
ALLOW_PROD=1 bash sql_scripts/2.attribute_standard/run_attr_std.sh
# 或单独跑：mysql ... -D dwd < build_dwd_l2_<l1>_<l2>.sql
```

如果只是字典本身的扩充，不重跑也行；下次 L2 全量重建时自动生效。

### Step 9 · 提交

```bash
git add sql_scripts/2.attribute_standard/dim_std_brand_manual_extra.sql
git commit -m "feat(attr-std): brand dict 补 <品牌列表>"
```

---

## 4. 失败回滚

| 现象 | 处理 |
|------|------|
| Step 5 验证 1 未生效（rw_size 没变） | 检查 SELECT FROM dim.dim_std_brand WHERE brand_id_std = X 是否查到原行；常见错误：jp_brand_id 写错 |
| Step 5 验证 2 视图未命中 | 检查别名拼写大小写、空格；视图用 `UPPER(TRIM(...))` 严格匹配 |
| Step 5 验证 3 brandshort 仍 null | 视图里 brand_key 可能被其他更高优先级条目占了，查 `SELECT * FROM test_dim.v_std_brand_alias WHERE brand_key = 'XXX'` 看谁赢了 |
| prod sync 跑错 | `sync_dim_std_brand.sh prod` 是幂等的（dim_std_brand.sql 先 DROP 再 INSERT），改完 manual_extra 直接重跑即可 |
| 误改了已合入的 Part A 条目 | git revert / 重写正确版本 → sync prod |

---

## 5. 常见坑

1. **Part A 不能用 VALUES**，必须 `INSERT ... SELECT FROM dim.dim_std_brand WHERE brand_id_std = <id>`——否则会把 jp_brand 原 related_words 抹掉，破坏匹配。
2. **`brand_id_std` 分段**：jp_brand 用 ods.id（19 位）；manual_extra 用 `9_000_001+` 段。**禁止跨界**。
3. **name 全局唯一**：用 `SELECT COUNT(*) FROM dim.dim_std_brand WHERE name = '<候选>'` 预检；若 jp_brand 本身有重名（已知 `Cosel` / `Micro Crystal` / `Central Semiconductor`），不在我们职责内，不要修。
4. **不要修改 `manufacturer` 的 EAV 语义**：同一品牌可能对应多个制造商（OEM/ODM/合资）；`manufacturer` 仅从 `dwd_icpdf_component_attr_std` 的 EAV 抽取，**禁止 COALESCE 兜底到 dim_std_brand canonical**。
5. **`brand` 列已升宽到 VARCHAR(256)**，存放标准品牌名（如 "威世-VISHAY"），不再是 raw brandshort 短名。
6. **重跑 Part A 是幂等的**：`array_distinct` 保证多次执行结果一致；但要小心**别名顺序**会变化（StarRocks 数组无序）。
7. **跨源重复（历史头号坑）**：同一家公司既在 jp_brand 段、又被 manual_extra 段新建一行（或中英混写 / 长短名各一行）。下游 `dwd_l2_*.brandid` 会随 build 时机随机命中其中一行，造成**同一公司多 id**、聚合口径分裂。根因是 Step 2 只查 jp_brand + Step 4B 只比 `name` 字面。**对策**：Step 2 主查打全表、Step 4B 归一化预检、sync 后跑 §6 校验器。已发现的重复用 `sql_scripts/brand_merge/`（merge_map + soft-delete + dwd 回填）统一收口，不要手工散改。

8. **related_words 别名交叉污染**：两家公司名称含同一缩写时（如 `顶源` 和 `南京拓微` 都用 TOPPOWER），手工追加别名容易把 A 公司专属别名写进 B 公司行，`validate_brand_dim_dup.py` **检测不到**（它只看归一化 key，不知道别名应属于谁），但视图展开后别名会映射到错误品牌。

   **对策**：追加任何 related_words 前先做持有人检查：
   ```sql
   SELECT brand_id_std, name
   FROM dim.dim_std_brand
   WHERE array_contains(related_words, '<新别名>')
      OR array_contains(related_words, UPPER('<新别名>'));
   ```
   若已有人持有，别名**只加给正确的一方**；若发现脏别名已入库，用 `brand_merge/03_merge_dim.py` 的 `DIRTY` 字典做专项清理（`DIRTY = {brand_id: [要移除的别名列表]}`）。

9. **白名单「占位嫌疑」条目的后续追踪**：`validate_brand_dim_dup.py` 发现归一化撞车但标注"占位嫌疑，非确认"的条目，是**未决状态**，不是最终结论。若不回溯确认，脏数据长期潜伏。

   **处置流程**（30 天内完成）：
   1. `SELECT id, name, abbr FROM ods.ods_jp_brand WHERE abbr = '<缩写>'`，结合官网确认是否同一公司。
   2. **是同一公司** → `brand_merge/01_create_merge_map.sql` 补合并对、重跑 `03_merge_dim.py --apply`、从白名单移除该 key。
   3. **不同公司** → 将白名单注释更新为 `# <A公司> / <B公司>（已确认不同公司，20260625）`，从"嫌疑"改为"确认"固化。

---

## 6. 常用 audit 查询

```sql
-- 查全部 manual_extra 与 重写丰富 行
SELECT brand_id_std, name, abbr, array_length(related_words) AS rw_size, source
FROM dim.dim_std_brand
WHERE source LIKE '%manual_extra%'
ORDER BY source DESC, brand_id_std;

-- 各 L1 品牌覆盖率
SELECT c.l1_code,
       COUNT(*) AS total,
       SUM(CASE WHEN a.brand_id_std IS NOT NULL THEN 1 ELSE 0 END) AS matched,
       ROUND(100.0 * SUM(CASE WHEN a.brand_id_std IS NOT NULL THEN 1 ELSE 0 END) / COUNT(*), 2) AS pct
FROM dwd.dwd_icpdf_component_param p
INNER JOIN dwd.dwd_component_class c ON c.id = p.id
LEFT JOIN dim.v_std_brand_alias a ON a.brand_key = UPPER(TRIM(p.brandshort))
GROUP BY c.l1_code ORDER BY total DESC;

-- 某品牌当前所有别名
SELECT brand_key, alias_kind
FROM dim.v_std_brand_alias
WHERE canonical_name = '<某 canonical>'
ORDER BY alias_kind, brand_key;

-- 检查 name 字面唯一（只能查出字面完全相同的，漏中英混写/长短名/跨源）
SELECT name, COUNT(*) AS dup
FROM dim.dim_std_brand
GROUP BY name HAVING COUNT(*) > 1;
```

> ⚠️ 上面这条**只查字面相等**，查不出 `慧荣科技-SiliconMotion` vs `Silicon Motion Inc` 这类。**归一化查重以 `validate_brand_dim_dup.py` 为准**（大写 + 去公司后缀 + 去符号 + 白名单），不要再用字面 GROUP BY 当查重依据。

---

## 6.5 品牌产地维度维护

### 背景

`dim.dim_std_brand` 扩展了 3 个产地列：

| 列 | 类型 | 说明 |
|----|------|------|
| `country_region` | VARCHAR(8) | 品牌起源地 ISO-2 码（CN/TW/US/JP/DE…），NULL=未定 |
| `is_domestic` | TINYINT | 1=中国资本/品牌（含台港澳+中资收购），0=海外，NULL=未定 |
| `domestic_type` | VARCHAR(20) | `mainland_native`/`mainland_acquired`/`taiwan`/`hk_mo`/`overseas` |

### 为什么用独立表

`dim.dim_std_brand` 每次 sync 会 `DROP + CREATE + INSERT FROM ods`，产地列和数据会被冲掉。因此产地数据存放在**独立持久表** `dim.dim_brand_origin`（PK=`brand_id_std`），sync 后由 `brand_origin_backfill.sql` JOIN 回写。

### sync 流程中的自动回写

`sync_dim_std_brand.sh` 已集成产地回写（步骤 3-4）：

```
1. dim_std_brand.sql              → DROP+CREATE+INSERT（产地列在 DDL 里，值为 NULL）
2. dim_std_brand_manual_extra.sql → 手工补缺品牌
3. dim_brand_origin.sql           → 确保 dim_brand_origin 表存在（CREATE IF NOT EXISTS）
3.5 dim_brand_origin_extra.sql    → 手工补录产地写入 dim_brand_origin
4. brand_origin_backfill.sql      → JOIN dim_brand_origin 回写产地列（UPSERT）
5. v_std_brand_alias.sql          → 重建别名视图
6. validate_brand_dim_dup.py      → 查重硬门控
```

### 新增/修正产地（手工补录）

产地数据的「源」是 `dim.dim_brand_origin`，不直接 UPDATE `dim_std_brand`（会被下次 sync 冲掉）。**手工补录产地写进仓库脚本 `dim_brand_origin_extra.sql`**（与 `dim_std_brand_manual_extra.sql` 对称，有 git 历史，可追溯），跑 sync 后自动生效。

**补品牌 + 补产地的完整操作（编辑两个文件）：**

```sql
-- 1. dim_std_brand_manual_extra.sql 加品牌（跟以前一样）
INSERT INTO dim.dim_std_brand
(brand_id_std, name, brand_zh, brand_en, abbr, related_words,
 logo, state, official_website, level, type, source, create_at, update_at)
VALUES (9001300, '某品牌-XXX', '某品牌', 'XXX', 'XXX', ARRAY<VARCHAR(256)>['XXX','某品牌'],
 NULL, 1, NULL, NULL, NULL, 'manual_extra', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP());

-- 2. dim_brand_origin_extra.sql 加产地（同一个 brand_id_std，产地三件套配套填）
INSERT INTO dim.dim_brand_origin
(brand_id_std, country_region, is_domestic, domestic_type, update_at)
VALUES (9001300, 'CN', 1, 'mainland_native', CURRENT_TIMESTAMP());

-- 3. 跑 sync，品牌和产地一起生效
-- bash sync_dim_std_brand.sh prod
```

**只补产地（品牌已存在）：** 只编辑 `dim_brand_origin_extra.sql` 加 INSERT，然后跑 sync。

**不知道产地：** 不补 `dim_brand_origin_extra.sql`，品牌照样有，只是产地 3 列为 NULL——产地是可选维度，不影响任何下游流程。

> ⚠️ **禁止**直接 `UPDATE dim.dim_std_brand` 改产地列（下次 sync 会被冲掉）。也**禁止**直接 `INSERT INTO dim.dim_brand_origin` 连数据库写（不在仓库里，不可追溯）。**统一走 `dim_brand_origin_extra.sql` 脚本**。

### 品牌合并时的产地迁移

`brand_merge/03_merge_dim.py` 已集成产地迁移（步骤 5）：

- `merge_id` 有产地但 `keep_id` 没产地 → 产地迁到 `keep_id`
- `merge_id` 有产地且 `keep_id` 也有产地 → 保留 `keep_id` 的产地，删除 `merge_id` 的产地行

### 产地数据来源

当前产地数据由 `brand_origin_agent` 产出（规则引擎 + 联网核查 + 人工 override），详见交接包文档。首次导入由 `sql_scripts/import_brand_origin.py` 从 Agent 产出的 `brand_origin_apply.sql` 解析写入 `dim.dim_brand_origin`。

---

## 7. 相关路径

- `sql_scripts/2.attribute_standard/dim_std_brand.sql` —— DDL + INSERT FROM ods.ods_jp_brand（含产地列）
- `sql_scripts/2.attribute_standard/dim_std_brand_manual_extra.sql` —— Part A 重写 + Part B 新增
- `sql_scripts/2.attribute_standard/dim_brand_origin.sql` —— 产地维度独立表 DDL
- `sql_scripts/2.attribute_standard/dim_brand_origin_extra.sql` —— 手工补录产地（INSERT VALUES，跑 sync 生效）
- `sql_scripts/2.attribute_standard/brand_origin_backfill.sql` —— sync 后 JOIN 回写产地列
- `sql_scripts/2.attribute_standard/v_std_brand_alias.sql` —— 查询视图
- `sql_scripts/2.attribute_standard/sync_dim_std_brand.sh` —— 一键同步 test|prod（含产地回写 + 查重校验器）
- `sql_scripts/2.attribute_standard/build_dwd_l2_*_resistor.sql` —— 下游 L2 装配（参考品牌 JOIN 写法）
- `.cursor/skills/component-etl-methodology/tools/validate_brand_dim_dup.py` —— 归一化查重硬门控 + 伪重复白名单
- `sql_scripts/brand_merge/` —— 已发现重复的统一收口（merge_map + soft-delete dim + dwd_l2 brandid 回填 + 产地迁移）
- `sql_scripts/import_brand_origin.py` —— 从 brand_origin_agent 产出导入产地数据（一次性）
