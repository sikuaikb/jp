#!/usr/bin/env python3
"""switch 属性校验：按 L2/L3 分类统计 EAV 字段覆盖率与质量。

默认 data_source=icpdf，对齐 test_dwd.dwd_component_class_switch + EAV。

用法:
  python audit/audit_attr_by_l3.py
  python audit/audit_attr_by_l3.py --data-source icpdf --out artifacts/switch/attr_by_l3_icpdf.txt
"""
from __future__ import annotations

import argparse
import csv
import os
import sys
from collections import defaultdict
from dataclasses import dataclass, field
from pathlib import Path

import pymysql

sys.stdout.reconfigure(encoding="utf-8")

HERE = Path(__file__).resolve().parents[1]
REPO = HERE.parents[2]
SCHEMA_CSV = HERE / "seed" / "dim_attr_schema_switch.csv"
ENV = HERE.parents[1] / "local.env"

# L2 公共关键字段（替代选型底线）
KEY_L2_ATTRS = [
    "manufacturer",
    "mpn",
    "lifecycle_status",
    "rohs_compliant",
    "package_case",
    "temp_min_c",
    "temp_max_c",
    "rated_voltage_v",
    "rated_current_a",
    "circuit_type",
    "mounting_type",
    "electrical_life_cycles",
]

# 覆盖率阈值
COV_OK = 30.0
COV_WARN = 5.0


@dataclass
class FieldStat:
    std_attr_code: str
    db_type: str
    sku: int
    value_n: int
    cov: float
    distinct_n: int
    bad_n: int
    top_value: str
    top_pct: float
    health: str
    notes: str = ""


@dataclass
class L3Report:
    l2_code: str
    l3_code: str
    l3_cn: str
    sku: int
    eav_ids: int
    l2_stats: list[FieldStat] = field(default_factory=list)
    l3_stats: list[FieldStat] = field(default_factory=list)

    @property
    def l2_key_cov(self) -> float:
        if not self.l2_stats:
            return 0.0
        keys = [s for s in self.l2_stats if s.std_attr_code in KEY_L2_ATTRS]
        if not keys:
            return 0.0
        return sum(s.cov for s in keys) / len(keys)

    @property
    def l3_attr_cov(self) -> float:
        if not self.l3_stats:
            return 0.0
        return sum(s.cov for s in self.l3_stats) / len(self.l3_stats)

    @property
    def zero_hit_l3(self) -> list[str]:
        return [s.std_attr_code for s in self.l3_stats if s.value_n == 0]

    @property
    def verdict(self) -> str:
        if self.sku == 0:
            return "SKIP"
        if self.eav_ids < self.sku * 0.95:
            return "FAIL(no_eav)"
        bad_l2 = [s for s in self.l2_stats if s.std_attr_code in KEY_L2_ATTRS and s.cov < COV_WARN]
        if len(bad_l2) >= 4:
            return "FAIL(l2)"
        if self.l3_stats and self.l3_attr_cov < COV_WARN and self.sku >= 100:
            return "WARN(l3)"
        if self.zero_hit_l3 and self.sku >= 50:
            return "WARN(l3_zero)"
        return "PASS"


def load_env() -> None:
    if not ENV.exists():
        return
    for line in ENV.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line.startswith("export "):
            k, _, v = line[7:].partition("=")
            os.environ[k] = v.strip().strip("'").strip('"')


def load_schema() -> tuple[dict[str, list[tuple[str, str]]], dict[str, list[tuple[str, str]]], dict[str, str]]:
    l2: dict[str, list[tuple[str, str]]] = defaultdict(list)
    l3: dict[str, list[tuple[str, str]]] = defaultdict(list)
    for row in csv.DictReader(SCHEMA_CSV.open(encoding="utf-8-sig")):
        pair = (row["std_attr_code"], row["db_type"])
        if row["scope_level"] == "l2":
            l2[row["scope_code"]].append(pair)
        elif row["scope_level"] == "l3":
            l3[row["scope_code"]].append(pair)
    l3_cn: dict[str, str] = {}
    classify_csv = HERE / "seed" / "dim_l3_classify_switch.csv"
    if classify_csv.exists():
        for row in csv.DictReader(classify_csv.open(encoding="utf-8-sig")):
            l3_cn[row["l3_code"]] = row.get("l3_cn") or row["l3_code"]
    return l2, l3, l3_cn


def health_tag(cov: float, value_n: int, top_pct: float, bad_n: int) -> tuple[str, str]:
    notes: list[str] = []
    if value_n == 0:
        return "✗", "0 命中"
    h = "✓"
    if cov < COV_WARN:
        h = "✗"
        notes.append(f"覆盖<{COV_WARN:.0f}%")
    elif cov < COV_OK:
        h = "△"
        notes.append(f"覆盖<{COV_OK:.0f}%")
    if top_pct > 95 and value_n > 50:
        h = "⚠" if h == "✓" else h
        notes.append(f"取值集中({top_pct:.0f}%)")
    if bad_n and value_n and bad_n / value_n > 0.05:
        notes.append(f"bad={bad_n}")
        if h == "✓":
            h = "⚠"
    return h, ", ".join(notes)


def field_stat(
    cur,
    data_source: str,
    scope_level: str,
    scope_code: str,
    attr: str,
    db_type: str,
    sku: int,
    *,
    l3_code: str | None = None,
) -> FieldStat:
    if scope_level == "l2":
        if l3_code:
            scope_filter = f"AND l3_code = '{l3_code}'"
        else:
            scope_filter = f"AND l2_code = '{scope_code}'"
    else:
        scope_filter = f"AND l3_code = '{scope_code}'"

    cur.execute(
        f"""
        SELECT
          COUNT(DISTINCT id) AS row_n,
          COUNT(DISTINCT CASE
            WHEN value_std_double IS NOT NULL
              OR (value_std_varchar IS NOT NULL AND trim(value_std_varchar) <> '')
            THEN id END) AS value_n,
          COUNT(DISTINCT CASE WHEN dq_flag IN ('parse_fail','out_of_range') THEN id END) AS bad_n
        FROM test_dwd.dwd_component_attr_std_switch
        WHERE data_source = %s AND std_attr_code = %s {scope_filter}
        """,
        (data_source, attr),
    )
    row = cur.fetchone()
    row_n = row["row_n"] or 0
    value_n = row["value_n"] or 0
    bad_n = row["bad_n"] or 0
    cov = 100.0 * value_n / sku if sku else 0.0

    distinct_n = 0
    top_value = ""
    top_pct = 0.0

    if value_n:
        if db_type in ("DOUBLE", "INT"):
            cur.execute(
                f"""
                SELECT COUNT(DISTINCT value_std_double) AS dn
                FROM test_dwd.dwd_component_attr_std_switch
                WHERE data_source = %s AND std_attr_code = %s {scope_filter}
                  AND value_std_double IS NOT NULL
                """,
                (data_source, attr),
            )
            distinct_n = cur.fetchone()["dn"] or 0
        else:
            cur.execute(
                f"""
                SELECT COUNT(DISTINCT value_std_varchar) AS dn
                FROM test_dwd.dwd_component_attr_std_switch
                WHERE data_source = %s AND std_attr_code = %s {scope_filter}
                  AND value_std_varchar IS NOT NULL AND trim(value_std_varchar) <> ''
                """,
                (data_source, attr),
            )
            distinct_n = cur.fetchone()["dn"] or 0
            cur.execute(
                f"""
                SELECT value_std_varchar, COUNT(*) AS n
                FROM test_dwd.dwd_component_attr_std_switch
                WHERE data_source = %s AND std_attr_code = %s {scope_filter}
                  AND value_std_varchar IS NOT NULL AND trim(value_std_varchar) <> ''
                GROUP BY value_std_varchar ORDER BY n DESC LIMIT 1
                """,
                (data_source, attr),
            )
            top = cur.fetchone()
            if top:
                top_value = (top["value_std_varchar"] or "")[:24]
                top_pct = 100.0 * top["n"] / value_n

    h, notes = health_tag(cov, value_n, top_pct, bad_n)
    return FieldStat(attr, db_type, sku, value_n, cov, distinct_n, bad_n, top_value, top_pct, h, notes)


def render_field_table(stats: list[FieldStat], lines: list[str]) -> None:
    lines.append(f"  {'std_attr_code':<28} {'type':<7} {'value_n':>8} {'cov%':>7} {'distinct':>8} {'health':<4} notes")
    lines.append("  " + "-" * 90)
    for s in stats:
        note = s.notes or (s.top_value if s.top_value else "")
        lines.append(
            f"  {s.std_attr_code:<28} {s.db_type:<7} {s.value_n:>8,} {s.cov:>6.1f}% {s.distinct_n:>8,} "
            f"[{s.health}]  {note[:40]}"
        )


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--data-source", default="icpdf")
    ap.add_argument("--out", default="")
    ap.add_argument("--min-sku", type=int, default=1, help="跳过 SKU 少于此值的 L3")
    args = ap.parse_args()
    ds = args.data_source

    load_env()
    l2_schema, l3_schema, l3_cn_map = load_schema()

    conn = pymysql.connect(
        host=os.environ["MYSQL_HOST"],
        port=int(os.environ.get("MYSQL_PORT", "9030")),
        user=os.environ["MYSQL_USER"],
        password=os.environ["MYSQL_PASSWORD"],
        charset="utf8mb4",
        cursorclass=pymysql.cursors.DictCursor,
    )
    cur = conn.cursor()
    cur.execute("SET enable_local_shuffle_agg=false")

    cur.execute(
        """
        SELECT l2_code, l3_code, COUNT(*) AS sku
        FROM test_dwd.dwd_component_class_switch
        WHERE data_source = %s AND l1_code = 'switch'
        GROUP BY l2_code, l3_code
        ORDER BY l2_code, l3_code
        """,
        (ds,),
    )
    class_rows = cur.fetchall()

    cur.execute(
        """
        SELECT l2_code, l3_code, COUNT(DISTINCT id) AS n
        FROM test_dwd.dwd_component_attr_std_switch
        WHERE data_source = %s
        GROUP BY l2_code, l3_code
        """,
        (ds,),
    )
    eav_by_l3 = {(r["l2_code"], r["l3_code"]): r["n"] for r in cur.fetchall()}

    lines: list[str] = []
    lines.append(f"# switch 属性校验 · data_source={ds}")
    lines.append(f"# schema={SCHEMA_CSV.name}")
    lines.append("")

    reports: list[L3Report] = []

    # ── L2 汇总 ──
    l2_sku: dict[str, int] = defaultdict(int)
    for r in class_rows:
        l2_sku[r["l2_code"]] += r["sku"]

    lines.append("=" * 100)
    lines.append("一、L2 公共属性（各 L2 内全部 SKU）")
    lines.append("=" * 100)
    for l2_code in sorted(l2_schema.keys()):
        sku = l2_sku.get(l2_code, 0)
        if sku == 0:
            continue
        lines.append("")
        lines.append(f"## L2 {l2_code}  (SKU={sku:,})")
        stats = [
            field_stat(cur, ds, "l2", l2_code, attr, dbt, sku)
            for attr, dbt in l2_schema[l2_code]
        ]
        render_field_table(stats, lines)

    # ── 每个 L3 ──
    lines.append("")
    lines.append("=" * 100)
    lines.append("二、按 L3 分类校验（L2 关键字段 + L3 专属字段）")
    lines.append("=" * 100)

    for row in class_rows:
        l2, l3 = row["l2_code"], row["l3_code"]
        sku = row["sku"]
        if sku < args.min_sku:
            continue
        eav_ids = eav_by_l3.get((l2, l3), 0)
        cn = l3_cn_map.get(l3, l3)

        rep = L3Report(l2, l3, cn, sku, eav_ids)
        l2_fields = [(a, t) for a, t in l2_schema.get(l2, []) if a in KEY_L2_ATTRS]
        rep.l2_stats = [field_stat(cur, ds, "l2", l2, a, t, sku, l3_code=l3) for a, t in l2_fields]
        rep.l3_stats = [
            field_stat(cur, ds, "l3", l3, a, t, sku) for a, t in l3_schema.get(l3, [])
        ]
        reports.append(rep)

        lines.append("")
        lines.append("-" * 100)
        lines.append(f"L3 {l3} ({cn})  ∈ {l2}  |  SKU={sku:,}  EAV={eav_ids:,}  |  判定: {rep.verdict}")
        lines.append("-" * 100)
        lines.append("  [L2 关键字段]")
        render_field_table(rep.l2_stats, lines)
        if rep.l3_stats:
            lines.append("  [L3 专属字段]")
            render_field_table(rep.l3_stats, lines)
        if rep.zero_hit_l3:
            lines.append(f"  L3 零命中: {', '.join(rep.zero_hit_l3)}")

    # ── 汇总表 ──
    lines.append("")
    lines.append("=" * 100)
    lines.append("三、L3 汇总表")
    lines.append("=" * 100)
    lines.append(
        f"  {'L3':<28} {'中文':<12} {'SKU':>8} {'EAV%':>7} {'L2关键均cov':>12} {'L3均cov':>10} {'判定':<12}"
    )
    lines.append("  " + "-" * 96)
    for rep in reports:
        eav_pct = 100.0 * rep.eav_ids / rep.sku if rep.sku else 0
        lines.append(
            f"  {rep.l3_code:<28} {rep.l3_cn:<12} {rep.sku:>8,} {eav_pct:>6.1f}% "
            f"{rep.l2_key_cov:>11.1f}% {rep.l3_attr_cov:>9.1f}% {rep.verdict:<12}"
        )

    verdicts = defaultdict(int)
    for rep in reports:
        verdicts[rep.verdict.split("(")[0]] += 1
    lines.append("")
    lines.append(
        f"  合计 L3={len(reports)}  PASS={verdicts['PASS']}  WARN={verdicts['WARN']}  FAIL={verdicts['FAIL']}"
    )

    conn.close()
    text = "\n".join(lines) + "\n"
    print(text)

    if args.out:
        out_path = Path(args.out)
        out_path.parent.mkdir(parents=True, exist_ok=True)
        out_path.write_text(text, encoding="utf-8")
        print(f"已写入 {out_path}", file=sys.stderr)

    fail_n = sum(1 for r in reports if r.verdict.startswith("FAIL"))
    return 1 if fail_n else 0


if __name__ == "__main__":
    raise SystemExit(main())
