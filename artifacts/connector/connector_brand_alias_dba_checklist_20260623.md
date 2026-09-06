# 得捷连接器品牌 alias 补全清单（DBA）

**日期**：2026-06-23  
**Gate 影响**：六表 `distinct brand = distinct brandid`；brand 空合计 **101,358**（= 已登记豁免上限）

---

## 1. 执行顺序（prod）

```bash
# 1) 在 dim 库执行补缺 SQL（test 环境可先 bash sync_dim_std_brand.sh test）
mysql ... < sql_scripts/2.attribute_standard/dim_std_brand_manual_extra.sql   # 含 connector_digikey_brand_gaps 段
mysql ... < artifacts/connector/connector_brand_manual_extra_r3_20260623.sql

# 2) 重建 v_std_brand_alias 视图
mysql ... < sql_scripts/2.attribute_standard/v_std_brand_alias.sql

# 3) 沙盒验证通过后，prod 重刷 L2 宽表 build
```

沙盒已验证：`apply_connector_brand_test_dim.py --skip-clone` + `validate_dwd_data` **硬门控 OK**。

---

## 2. A 类：扩写既有品牌 `related_words`（7 组）

| 目标 brand_id_std | 标准名 | 得捷别名（节选） | 影响行数 |
|-------------------|--------|------------------|----------|
| 9000568 | Amphenol CONEC | Amphenol CONEC | ~1k |
| 9000571 | TE Connectivity | Corcom Filters / Schaffner / Erni / ENTRELEC | ~4.3k |
| 1443490691630862341 | Eaton | Eaton Wiring Devices / Bussmann | ~3.4k |
| 1443490692209676298 | Amphenol FCI | Amphenol NEXUS / FCI Deutschland | ~170 |
| 1443490699323215877 | Molex | AirBorn, a Molex company | ~5.6k |
| 1494518929597435906 | Amphenol | Positronic / Limited / PCD Shenzhen / Times Microwave … | ~73k |
| 1443490697037320202 | 台达 DELTA | Delta Electronics/Industrial Automation | ~7 |

SQL 见 `connector_brand_manual_extra_draft_20260623.sql` 段 A + `connector_brand_manual_extra_r3_20260623.sql`。

---

## 3. B 类：新建 9_000_xxx 品牌（40 个，Top 15）

| brand_id_std | name | 影响行数 |
|--------------|------|----------|
| 9001140 | Fischer Elektronik | 33,561 |
| 9001141 | Curtis Industries | 23,792 |
| 9001142 | On Shore Technology Inc. | 11,214 |
| 9001143 | Aries Electronics | 4,743 |
| 9001144 | METZ CONNECT USA Inc. | 1,799 |
| 9001145 | Lumberg Automation | 685 |
| 9001146 | Phyton Inc. | 539 |
| 9001147 | HALO Electronics, Inc. | 526 |
| 9001148 | Cvilux USA | 518 |
| 9001149 | Ease Electronics | 508 |
| 9001150 | Oupiin | 499 |
| 9001151 | Winchester Interconnect | 385 |
| 9001152 | CLIFF Electronic Components Ltd | 385 |
| 9001153 | Cinch Connectivity Solutions Trompeter | 361 |
| 9001154 | Qualtek | 351 |

完整 40 行见 `connector_brand_manual_extra_draft_20260623.sql` 段 B（9001140–9001179）。

---

## 4. 待 DBA 人工确认（draft WARN 段）

| 得捷 brand_raw | 建议锚点 | 行数 | 说明 |
|----------------|----------|------|------|
| Assmann WSW Components | Assmann | 10,892 | dim 无 Assmann 主品牌行，需指定 brand_id 或新建 |
| LAPP | LAPP | 1,784 | dim 无 LAPP 主品牌行 |
| Anderson Power Products, Inc. | Anderson Power | 903 | dim 无 Anderson Power 主品牌行 |

---

## 5. 源端真无 brand（不处理）

101,358 行 `brandshort` 与 prajson「制造商」均为空——**原始数据无品牌，不用管**；宽表保持 brand/brandid 为空即可。已登记 `BRAND_NULL_WAIVER=connector:digikey:101358`，门控按合计豁免通过。

后续 alias 补缺**只针对** gap 审计 TSV 里有 `brand_raw` 文案、但未映射的行（A/B 类）；不再追求 brand_null 归零。

---

## 6. 产物索引

| 文件 | 用途 |
|------|------|
| `connector_brand_manual_extra_draft_20260623.sql` | A+B 主补缺 SQL |
| `connector_brand_manual_extra_r3_20260623.sql` | 长尾 enrich 第 3 轮 |
| `connector_brand_gap_audit_20260623.tsv` | 缺口审计原始表 |
| `connector_brand_alias_dba_checklist_20260623.tsv` | 110 品牌 machine 清单 |
| `sql_scripts/test/connector/apply_connector_brand_test_dim.py` | 沙盒应用 + 重刷 L2 |
