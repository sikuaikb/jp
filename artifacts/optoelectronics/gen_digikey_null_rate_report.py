#!/usr/bin/env python3
"""得捷专用空值率报告 — 光电器件沙盒（L2 宽表物理列 + L3 ext_attributes / EAV）。"""
from __future__ import annotations

import os
from datetime import date
from pathlib import Path
import sys

import pymysql

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from gen_attr_fill_rate_tables import (  # noqa: E402
    L2_CN,
    fill_rates,
    l3_ext_fill_rates,
    load_taxonomy,
    wide_l2_fill_rates,
)

CONN = dict(
    host=os.environ.get("MYSQL_HOST", "192.168.19.21"),
    port=int(os.environ.get("MYSQL_PORT", "9030")),
    user=os.environ.get("MYSQL_USER", "dev"),
    password=os.environ["MYSQL_PASSWORD"],
)

L2_ORDER = ("light_emitter", "photodetector")
L2_WIDE = {
    "light_emitter": "dwd_l2_optoelectronics_light_emitter",
    "photodetector": "dwd_l2_optoelectronics_photodetector",
}
REPORT = HERE / f"optoelectronics_digikey_null_rate_report_{date.today().strftime('%Y%m%d')}.md"


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


def fmt_wide_row(attr, cn, d, f, pct) -> str:
    null_pct = round(100.0 - pct, 2)
    return f"| {cn} (`{attr}`) | {d:,} | {f:,} | {pct}% | {null_pct}% |"


def fmt_l3_row(l3, attr, cn, d, f, pct, l3_map) -> str:
    l3_cn = l3_map.get(l3, ("", l3))[1]
    null_pct = round(100.0 - pct, 2)
    return f"| {l3_cn} | {cn} (`{attr}`) | {d:,} | {f:,} | {pct}% | {null_pct}% |"


def l3_wide_attr_fill(cur, l2: str, table: str, attr: str) -> list[tuple]:
    cur.execute(
        f"""
        SELECT c.l3_code,
               COUNT(*) AS denom,
               SUM(CASE WHEN w.`{attr}` IS NOT NULL THEN 1 ELSE 0 END) AS filled
        FROM test_dwd.{table} w
        JOIN test_dwd.dwd_component_class_optoelectronics c
          ON c.id = w.id AND c.data_source = w.data_source
        WHERE w.data_source = 'digikey' AND c.l2_code = %s
        GROUP BY c.l3_code ORDER BY denom DESC
        """,
        (l2,),
    )
    out = []
    for l3, d, f in cur.fetchall():
        pct = round(100.0 * f / d, 2) if d else 0.0
        out.append((l3, d, f, pct))
    return out


def brand_gate(cur, table: str) -> tuple[int, int, int, int]:
    cur.execute(f"""
        SELECT
          SUM(CASE WHEN brandid IS NULL THEN 1 ELSE 0 END),
          COUNT(DISTINCT brand),
          COUNT(DISTINCT brandid)
        FROM test_dwd.{table} WHERE data_source='digikey'
    """)
    brand_null, distinct_brand, distinct_brandid = cur.fetchone()
    cur.execute(f"SELECT COUNT(*) FROM test_dwd.{table} WHERE data_source='digikey'")
    total = cur.fetchone()[0]
    return total, brand_null or 0, distinct_brand or 0, distinct_brandid or 0


def main():
    env = Path(__file__).resolve().parents[2] / "sql_scripts" / "local.env"
    if env.exists():
        for line in env.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if line.startswith("export "):
                k, _, v = line[7:].partition("=")
                os.environ[k] = v.strip().strip("'").strip('"')

    conn = pymysql.connect(**CONN)
    try:
        with conn.cursor() as cur:
            l2_cn, l3_map = load_taxonomy(cur)
            eav_rows = fill_rates(cur, "digikey")
            dk_cls = q1(
                cur,
                "SELECT COUNT(DISTINCT id) FROM test_dwd.dwd_component_class_optoelectronics "
                "WHERE data_source='digikey' AND l3_code NOT LIKE '%%unclassified%%'",
            )
            dk_eav_parts = q1(
                cur,
                "SELECT COUNT(DISTINCT id) FROM test_dwd.dwd_component_attr_std_optoelectronics "
                "WHERE data_source='digikey'",
            )
            pf = q1(
                cur,
                "SELECT COUNT(*) FROM test_dwd.dwd_component_attr_std_optoelectronics "
                "WHERE data_source='digikey' AND dq_flag='parse_fail'",
            )
            oor = q1(
                cur,
                "SELECT COUNT(*) FROM test_dwd.dwd_component_attr_std_optoelectronics "
                "WHERE data_source='digikey' AND dq_flag='out_of_range'",
            )
            cur.execute(
                """SELECT l2_code, l3_code, COUNT(DISTINCT id)
                FROM test_dwd.dwd_component_class_optoelectronics
                WHERE data_source='digikey' AND l3_code NOT LIKE '%%unclassified%%'
                GROUP BY l2_code, l3_code ORDER BY l2_code, l3_code"""
            )
            dk_l3 = cur.fetchall()
            cur.execute(
                """SELECT l2_code, COUNT(DISTINCT id)
                FROM test_dwd.dwd_component_class_optoelectronics
                WHERE data_source='digikey' AND l3_code NOT LIKE '%%unclassified%%'
                GROUP BY l2_code ORDER BY l2_code"""
            )
            dk_l2 = dict(cur.fetchall())

            optical_power_l3 = l3_wide_attr_fill(
                cur, "light_emitter", L2_WIDE["light_emitter"], "optical_power_mw"
            )
            cur.execute(
                """
                SELECT c.l3_code,
                       COUNT(DISTINCT c.id) AS denom,
                       COUNT(DISTINCT CASE WHEN e.value_std_double IS NOT NULL THEN c.id END) AS filled
                FROM test_dwd.dwd_component_class_optoelectronics c
                LEFT JOIN test_dwd.dwd_component_attr_std_optoelectronics e
                  ON e.id = c.id AND e.data_source = c.data_source
                 AND e.std_attr_code = 'luminous_intensity_mcd'
                WHERE c.data_source = 'digikey' AND c.l2_code = 'light_emitter'
                GROUP BY c.l3_code ORDER BY denom DESC
                """
            )
            luminous_l3 = [
                (l3, d, f, round(100.0 * f / d, 2) if d else 0.0)
                for l3, d, f in cur.fetchall()
            ]

            wide_sections = []
            brand_sections = []
            l3_sections = []
            for l2 in L2_ORDER:
                tbl = L2_WIDE[l2]
                wide = wide_l2_fill_rates(cur, l2, tbl)
                l3_ext = l3_ext_fill_rates(cur, l2)
                total, bnull, db, dbid = brand_gate(cur, tbl)
                brand_sections.append(
                    f"| {l2_cn[l2]} | {total:,} | {bnull} | {db} | {dbid} | "
                    f"{'⚠ 未过' if bnull > 0 or db > dbid * 1.5 else '✓'} |"
                )
                wide_body = "\n".join(fmt_wide_row(*r) for r in wide)
                wide_sections.append(f"""### L2 宽表 · {l2_cn[l2]}（`test_dwd.{tbl}`）

| 参数 | 物料数 | 已填 | 填充率 | 空值率 |
|------|--------|------|--------|--------|
{wide_body}
""")
                l3_body = "\n".join(fmt_l3_row(*r, l3_map=l3_map) for r in l3_ext)
                l3_sections.append(f"""### L3 ext_attributes 源（EAV l3 行）· {l2_cn[l2]}

| 细分类 | 参数 | 适用物料 | 已填 | 填充率 | 空值率 |
|--------|------|----------|------|--------|--------|
{l3_body}
""")
    finally:
        conn.close()

    buckets = bucket_by_l2(eav_rows, l3_map)
    eav_summary = []
    for l2 in L2_ORDER:
        rows = buckets[l2]
        active = [r for r in rows if r[4] > 0]
        _, _, fill_pct, null_pct, nz = aggregate(active)
        eav_summary.append(f"| {l2_cn[l2]} | {len(active)} | {nz}/{len(active)} | {null_pct}% | {fill_pct}% |")

    op_l3_lines = [
        f"| {l3_map.get(l3, ('', l3))[1]} | {d:,} | {f:,} | {pct}% |"
        for l3, d, f, pct in optical_power_l3
    ]
    lum_l3_lines = [
        f"| {l3_map.get(l3, ('', l3))[1]} | {d:,} | {f:,} | {pct}% |"
        for l3, d, f, pct in luminous_l3
    ]

    md = f"""# 得捷数据空值率报告 · 光电器件

**报告日期**：{date.today().isoformat()}  
**数据来源**：得捷（`data_source = digikey`）  
**Schema**：`optoelectronics_schema_v1.5.09`  
**环境**：`test_dwd` / `test_dim`

---

## 1. 结论摘要

| 指标 | 数值 |
|------|------|
| 已分类物料 | **{dk_cls:,}** 颗 |
| 有 EAV 属性值的物料 | **{dk_eav_parts:,}** 颗 |
| 解析失败 `parse_fail` | {pf:,} 条 |
| 超范围 `out_of_range` | {oor:,} 条 |

> **色温 `color_temperature_k`**：共享 `dim_unit_factor` 中 `K,,0.001`（FPGA 逻辑门）曾误乘开尔文色温，已在 schema 侧将 `unit_std` 置空走裸数值；`out_of_range` 从 ~6.7 万降至 ~2k。

### EAV 填充率（按大类）

| L2 | 适用参数项 | 有数据项 | 空值率 | 填充率 |
|----|------------|----------|--------|--------|
{chr(10).join(eav_summary)}

### 品牌门控（宽表）

| L2 宽表 | 行数 | brandid 空 | distinct brand | distinct brandid | 状态 |
|---------|------|------------|----------------|------------------|------|
{chr(10).join(brand_sections)}

> 品牌门控：`brandid` 空行应趋近 0，且 `distinct brand` 不应显著大于 `distinct brandid`（未命中 `v_std_brand_alias`）。**勿自动 sync 品牌字典**；缺口审计见 `python3 artifacts/optoelectronics/gen_brand_gap_audit.py` → `optoelectronics_brand_gap_audit_*.tsv` + `manual_extra` 草案。

### 光输出功率按细分类（L2 列 `optical_power_mw`）

得捷 LED 桶无 mW 功率键，亮度见 L3 `luminous_intensity_mcd`；激光见 `功率 (W)`（mW 标称）。

| 细分类 | 物料数 | 已填 mW | 填充率 |
|--------|--------|---------|--------|
{chr(10).join(op_l3_lines) if op_l3_lines else '| — | 0 | 0 | — |'}

| 细分类（L3 发光强度 mcd） | 物料数 | 已填 | 填充率 |
|---------------------------|--------|------|--------|
{chr(10).join(lum_l3_lines) if lum_l3_lines else '| — | 0 | 0 | — |'}

---

## 2. 分类分布

| 大类 | 细分类 | 物料数 |
|------|--------|--------|
"""
    for l2, l3, n in dk_l3:
        md += f"| {l2_cn.get(l2, l2)} | {l3_map.get(l3, ('', l3))[1]} | {n:,} |\n"

    md += f"""
| **合计** | | **{dk_cls:,}** |

---

## 3. L2 宽表物理列空值率

{chr(10).join(wide_sections)}

---

## 4. L3 专有参数（ext_attributes / EAV）

{chr(10).join(l3_sections)}

### 得捷源豁免（`digikey_attr_source_waiver.list`）

下列属性在得捷 prajson **无键或仅 SPCM 模组键**，已登记 `validate_attr_dim` 豁免，不建抽取规则：

| 细分类 | 字段 |
|--------|------|
| photodiode | junction_capacitance_pf, dark_current_na, breakdown_voltage_v, response_time_ns, shunt_resistance_kohm |
| phototransistor | dc_current_gain_hfe, rise_time_us, fall_time_us |
| led | 光功率请用 `luminous_intensity_mcd`（得捷无 LED mW 键） |
| laser_diode | `optical_power_mw` 由 `功率 (W)` 抽取 |

---

## 附录

```bash
source sql_scripts/local.env
python3 artifacts/optoelectronics/gen_digikey_null_rate_report.py
```

重跑属性链路：

```bash
bash sql_scripts/test/optoelectronics/run_test.sh
```
"""
    REPORT.write_text(md, encoding="utf-8")
    print(f"wrote {REPORT}")


if __name__ == "__main__":
    main()
