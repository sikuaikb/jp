#!/usr/bin/env python3
"""得捷连接器 L1 数据质量报告（阶段 5.5 验收快照）。"""
from __future__ import annotations

import os
import sys
from datetime import date
from pathlib import Path

import pymysql

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from gen_attr_fill_rate_tables import (  # noqa: E402
    L2_CN,
    L2_WIDE,
    brand_gate,
    conn_kwargs,
    fill_rates,
    load_taxonomy,
    to_human_md,
    wide_l2_fill_rates,
)

REPORT = HERE / f"connector_digikey_null_rate_report_{date.today().strftime('%Y%m%d')}.md"

L2_ORDER = tuple(L2_CN.keys())


def q1(cur, sql, args=()):
    cur.execute(sql, args)
    return cur.fetchone()[0]


def bucket_by_l2(rows: list[tuple], l3_map: dict[str, tuple[str, str]]) -> dict[str, list[tuple]]:
    out = {k: [] for k in L2_ORDER}
    for row in rows:
        sl, sc = row[0], row[1]
        l2 = sc if sl == "l2" else l3_map.get(sc, ("", ""))[0]
        if l2 in out:
            out[l2].append(row)
    return out


def aggregate(rows: list[tuple]) -> tuple[int, int, float, float, int]:
    denom = sum(r[4] for r in rows)
    filled = sum(r[5] for r in rows)
    nz = sum(1 for r in rows if r[6] > 0)
    if denom == 0:
        return 0, 0, 0.0, 100.0, nz
    fill_pct = round(100.0 * filled / denom, 2)
    return denom, filled, fill_pct, round(100.0 - fill_pct, 2), nz


def scope_rows(rows: list[tuple], mode: str) -> list[tuple]:
    if mode == "l2_common":
        return [r for r in rows if r[0] == "l2"]
    if mode == "l3_only":
        return [r for r in rows if r[0] == "l3" and r[4] > 0]
    return rows


def l3_table(rows: list[tuple], l2_cn: dict[str, str], l3_map: dict[str, tuple[str, str]]) -> str:
    lines = ["| 大类 | 细分类 | 物料数 |", "|------|--------|--------|"]
    for l2, l3, n in rows:
        lines.append(f"| {l2_cn.get(l2, l2)} | {l3_map.get(l3, (l2, l3))[1]} | {n:,} |")
    return "\n".join(lines)


def fmt_attr_row(r: tuple, l2_cn: dict[str, str], l3_map: dict[str, tuple[str, str]]) -> str:
    sl, sc, _attr, cn, d, f, pct = r
    if sl == "l2":
        cat, sub = l2_cn.get(sc, sc), "（大类公共）"
    else:
        l2, l3_cn = l3_map.get(sc, ("", sc))
        cat, sub = l2_cn.get(l2, l2), l3_cn
    null_pct = round(100.0 - pct, 2)
    return f"| {cat} | {sub} | {cn} | {d:,} | {f:,} | {pct}% | {null_pct}% |"


def section_table(rows: list[tuple], l2_cn: dict[str, str], l3_map: dict[str, tuple[str, str]]) -> str:
    active = [r for r in rows if r[4] > 0]
    if not active:
        return "（该宽表下暂无已分类物料）\n"
    hdr = "| 大类 | 细分类 | 参数 | 适用物料数 | 已填写 | 填充率 | 空值率 |"
    sep = "|------|--------|------|------------|--------|--------|--------|"
    body = [fmt_attr_row(r, l2_cn, l3_map) for r in active]
    return "\n".join([hdr, sep, *body])


def wide_phys_table(rows: list[tuple]) -> str:
    if not rows:
        return "（无数据）\n"
    lines = [
        "| 参数 | 物料数 | 已填 | 填充率 | 空值率 |",
        "|------|--------|------|--------|--------|",
    ]
    for attr, cn, total, filled, pct in rows:
        null_pct = round(100.0 - pct, 2)
        lines.append(f"| {cn} (`{attr}`) | {total:,} | {filled:,} | {pct}% | {null_pct}% |")
    return "\n".join(lines)


WAIVER_ENV = HERE / "connector_digikey_source_waiver.env"


def load_brand_null_waiver() -> int | None:
    if not WAIVER_ENV.exists():
        return None
    for line in WAIVER_ENV.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line.startswith("BRAND_NULL_WAIVER="):
            part = line.split("=", 1)[1].strip()
            bits = part.split(":")
            if len(bits) == 3 and bits[2].isdigit():
                return int(bits[2])
    return None


def brand_status(bg: dict, brand_null_waiver: int | None, brand_null_total: int) -> str:
    if bg["total"] == 0:
        return "—"
    alias_ok = bg["distinct_brand"] == bg["distinct_brandid"]
    if bg["brand_null"] == 0 and alias_ok:
        return "通过"
    if alias_ok and brand_null_waiver is not None and brand_null_total <= brand_null_waiver:
        return "源端豁免"
    return "未过"


def main() -> None:
    conn = pymysql.connect(**conn_kwargs())
    try:
        with conn.cursor() as cur:
            l2_cn, l3_map = load_taxonomy(cur)
            dk_rows = fill_rates(cur, "digikey")
            dk_cls = q1(
                cur,
                "SELECT COUNT(DISTINCT id) FROM test_dwd.dwd_component_class_connector "
                "WHERE data_source='digikey' AND l3_code NOT LIKE '%%unclassified%%'",
            )
            dk_eav_parts = q1(
                cur,
                "SELECT COUNT(DISTINCT id) FROM test_dwd.dwd_component_attr_std_connector "
                "WHERE data_source='digikey'",
            )
            pf = q1(
                cur,
                "SELECT COUNT(*) FROM test_dwd.dwd_component_attr_std_connector "
                "WHERE data_source='digikey' AND dq_flag='parse_fail'",
            )
            oor = q1(
                cur,
                "SELECT COUNT(*) FROM test_dwd.dwd_component_attr_std_connector "
                "WHERE data_source='digikey' AND dq_flag='out_of_range'",
            )
            schema_rows = q1(cur, "SELECT COUNT(*) FROM test_dim.dim_attr_schema_connector")
            cur.execute(
                """SELECT l2_code, l3_code, COUNT(DISTINCT id)
                FROM test_dwd.dwd_component_class_connector
                WHERE data_source='digikey' AND l3_code NOT LIKE '%%unclassified%%'
                GROUP BY l2_code, l3_code ORDER BY l2_code, l3_code"""
            )
            dk_l3 = cur.fetchall()
            cur.execute(
                """SELECT l2_code, COUNT(DISTINCT id)
                FROM test_dwd.dwd_component_class_connector
                WHERE data_source='digikey' AND l3_code NOT LIKE '%%unclassified%%'
                GROUP BY l2_code ORDER BY l2_code"""
            )
            dk_l2 = dict(cur.fetchall())
            brand_gates = {l2: brand_gate(cur, tbl) for l2, tbl in L2_WIDE.items()}
            wide_phys = {l2: wide_l2_fill_rates(cur, l2, tbl) for l2, tbl in L2_WIDE.items()}
            l2_parts = {
                l2: q1(cur, f"SELECT COUNT(*) FROM test_dwd.{tbl} WHERE data_source='digikey'")
                for l2, tbl in L2_WIDE.items()
            }
    finally:
        conn.close()

    buckets = bucket_by_l2(dk_rows, l3_map)
    summary_rows = []
    scope_rows_md = []
    detail_sections = []
    wide_sections = []
    all_active = []

    for l2 in L2_ORDER:
        rows = buckets[l2]
        active = [r for r in rows if r[4] > 0]
        all_active.extend(active)
        n_attr = len(rows)
        denom, filled, fill_pct, null_pct, nz = aggregate(rows)
        l2c = scope_rows(rows, "l2_common")
        l3c = scope_rows(rows, "l3_only")
        _, _, _, null_l2, nz_l2 = aggregate(l2c)
        _, _, _, null_l3, nz_l3 = aggregate(l3c)
        parts = dk_l2.get(l2, 0)
        wide_parts = l2_parts.get(l2, 0)
        bg = brand_gates[l2]

        summary_rows.append(
            f"| {l2_cn[l2]} | {parts:,} | {wide_parts:,} | {n_attr} | {nz}/{len(active) or n_attr} "
            f"| {null_pct}% | {fill_pct}% |"
        )
        scope_rows_md.append(f"| {l2_cn[l2]} | L2 公共参数 | {len(l2c)} | {nz_l2}/{len(l2c)} | {null_l2}% |")
        scope_rows_md.append(f"| {l2_cn[l2]} | L3 专有参数 | {len(l3c)} | {nz_l3}/{len(l3c) or 0} | {null_l3}% |")
        scope_rows_md.append(f"| {l2_cn[l2]} | **全表合计** | {len(active)} | {nz}/{len(active)} | {null_pct}% |")

        top = sorted(active, key=lambda r: r[6], reverse=True)[:10]
        bottom = sorted(active, key=lambda r: r[6])[:10]
        top_md = "\n".join(fmt_attr_row(r, l2_cn, l3_map) for r in top)
        bot_md = "\n".join(fmt_attr_row(r, l2_cn, l3_map) for r in bottom)

        detail_sections.append(f"""### 3.{L2_ORDER.index(l2) + 1} {l2_cn[l2]}（EAV 口径）

**已分类物料** {parts:,} 颗 · **宽表行数** {wide_parts:,} · **适用参数项** {len(active)} 项 · **全表空值率** {null_pct}%

#### 填充率最高 10 项

| 大类 | 细分类 | 参数 | 适用物料数 | 已填写 | 填充率 | 空值率 |
|------|--------|------|------------|--------|--------|--------|
{top_md}

#### 填充率最低 10 项（分母>0）

| 大类 | 细分类 | 参数 | 适用物料数 | 已填写 | 填充率 | 空值率 |
|------|--------|------|------------|--------|--------|--------|
{bot_md}
""")

        wide_sections.append(f"""### 4.{L2_ORDER.index(l2) + 1} {l2_cn[l2]}（宽表物理列）

{wide_phys_table(wide_phys[l2])}
""")

    total_denom, total_filled, total_fill, total_null, total_nz = aggregate(all_active)

    brand_null_waiver = load_brand_null_waiver()
    brand_null_total = sum(brand_gates[l2]["brand_null"] for l2 in L2_ORDER)

    brand_rows = []
    for l2 in L2_ORDER:
        bg = brand_gates[l2]
        brand_rows.append(
            f"| {l2_cn[l2]} | {bg['total']:,} | {bg['brand_null']:,} | {bg['brandid_null']:,} "
            f"| {bg['distinct_brand']} | {bg['distinct_brandid']} | "
            f"{brand_status(bg, brand_null_waiver, brand_null_total)} |"
        )

    md = f"""# 得捷数据质量报告 · 连接器

**报告日期**：{date.today().isoformat()}  
**数据来源**：得捷（`data_source = digikey`）  
**Schema**：`connector_schema_v1.4.30`  
**环境**：`test_dwd` / `test_dim`

---

## 这份报告回答什么？

只看得捷一侧：**243 万颗连接器已分到哪几个大类/细分类**、**六项核心参数（针位数、间距、安装方式等）填了多少**、**六张宽表品牌是否齐全**。

> 空值率 = 100% − 填充率。EAV 口径按 schema {schema_rows} 行逐项统计；宽表物理列口径反映透视后的实际列填充。

---

## 1. 结论摘要

| 指标 | 数值 |
|------|------|
| Gate 内已分类物料 | **{dk_cls:,}** 颗 |
| 有参数值的物料 | **{dk_eav_parts:,}** 颗 |
| 适用参数槽位合计 | {total_denom:,} |
| **整体空值率（EAV）** | **{total_null}%**（填充率 {total_fill}%） |
| 有数据参数项 | {total_nz} / {len(all_active)} |
| 参数解析失败 | {pf:,} 条 |
| 参数数值超范围 | {oor:,} 条 |

### 分宽表空值率（EAV 口径）

| 大类 | 已分类物料 | 宽表行数 | 参数项 | 有数据项 | **空值率** | 填充率 |
|------|------------|----------|--------|----------|------------|--------|
{chr(10).join(summary_rows)}

### 品牌门控（宽表 · 发布前须通过）

| 大类 | 行数 | brand 空 | brandid 空 | distinct brand | distinct brandid | 状态 |
|------|------|----------|------------|----------------|------------------|------|
{chr(10).join(brand_rows)}

> 品牌门控：`distinct brand` = `distinct brandid` 须通过；`brand` 空须为 0，或合计 ≤ 登记源端豁免（当前 **{brand_null_total:,}** 行，豁免上限 **{brand_null_waiver or '未登记'}**）。缺口审计见 `gen_brand_gap_audit.py`；豁免登记见 `connector_digikey_source_waiver.env`。

---

## 2. 分类完整结果

### 2.1 按大类

| 大类 | 物料数 |
|------|--------|
{chr(10).join(f"| {l2_cn[l2]} | {dk_l2.get(l2, 0):,} |" for l2 in L2_ORDER)}
| **合计** | **{dk_cls:,}** |

### 2.2 按细分类（23 类）

{l3_table(dk_l3, l2_cn, l3_map)}

---

## 3. 属性填充率 · EAV 口径（按大类）

### 3.0 口径拆开

| 大类 | 统计口径 | 参数项数 | 有数据项 | 空值率 |
|------|----------|----------|----------|--------|
{chr(10).join(scope_rows_md)}

{chr(10).join(detail_sections)}

---

## 4. L2 宽表物理列空值率

{chr(10).join(wide_sections)}

---

## 附录 · 技术说明

| 项 | 说明 |
|----|------|
| 分类结果表 | `test_dwd.dwd_component_class_connector` |
| 属性窄表 | `test_dwd.dwd_component_attr_std_connector` |
| 属性定义 | `test_dim.dim_attr_schema_connector` |
| L2 宽表 | `test_dwd.dwd_l2_connector_*`（6 张） |
| Gate 估算 | ~243.5 万（connector gate v2，排除评估板/开发套件/耗材） |

### 生成命令

```bash
source sql_scripts/local.env
python3 artifacts/connector/gen_digikey_null_rate_report.py
python3 artifacts/connector/gen_brand_gap_audit.py
```
"""
    REPORT.write_text(md, encoding="utf-8")
    human_path = HERE / f"attr_fill_rate_digikey_connector_human_{date.today().strftime('%Y%m%d')}.md"
    human_path.write_text(to_human_md(dk_rows, l2_cn, l3_map), encoding="utf-8")
    print(f"wrote {REPORT}")
    print(f"wrote {human_path}")


if __name__ == "__main__":
    main()
