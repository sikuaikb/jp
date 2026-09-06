#!/usr/bin/env python3
"""circuit_protection Phase 5.5 QA：L2 填充率 + 品牌门控 + ext 审计。"""
from __future__ import annotations

import os
import sys
from datetime import datetime
from pathlib import Path

import pymysql

sys.stdout.reconfigure(encoding="utf-8")

HERE = Path(__file__).resolve().parent.parent
AUDIT = HERE / "audit"
ART = HERE / "artifacts" / "circuit_protection"
ENV = HERE.parents[1] / "local.env"
OUT = ART / "phase55_audit_report.txt"

L2_TABLES = {
    "overcurrent_overtemperature_protection": [
        "manufacturer", "mpn", "lifecycle_status", "rohs_compliant", "package_case",
        "mounting_type", "current_rating_a", "voltage_rating_v",
    ],
    "passive_surge_diversion": [
        "manufacturer", "mpn", "lifecycle_status", "package_case",
        "max_continuous_voltage_v", "temp_min_c", "temp_max_c",
    ],
    "semiconductor_transient_suppression": [
        "manufacturer", "mpn", "lifecycle_status", "package_case",
        "standoff_voltage_v", "breakdown_voltage_v", "peak_pulse_power_w",
        "temp_min_c", "temp_max_c",
    ],
    "surge_protection_module": [
        "manufacturer", "mpn", "lifecycle_status", "rohs_compliant", "package_case",
        "temp_min_c", "temp_max_c", "uc_v", "up_v", "imax_ka", "in_ka", "pole_count",
    ],
}


def load_env() -> None:
    for line in ENV.read_text(encoding="utf-8").splitlines():
        if line.strip().startswith("export "):
            k, _, v = line.strip()[7:].partition("=")
            os.environ[k] = v.strip().strip("'").strip('"')


def connect():
    return pymysql.connect(
        host=os.environ["MYSQL_HOST"],
        port=int(os.environ.get("MYSQL_PORT", "9030")),
        user=os.environ["MYSQL_USER"],
        password=os.environ["MYSQL_PASSWORD"],
        charset="utf8mb4",
        cursorclass=pymysql.cursors.DictCursor,
        autocommit=True,
    )


def main() -> int:
    load_env()
    ART.mkdir(parents=True, exist_ok=True)
    lines: list[str] = [
        f"circuit_protection Phase 5.5 QA · {datetime.now():%Y-%m-%d %H:%M}",
        "data_source=icpdf · test_dwd only",
    ]
    conn = connect()
    cur = conn.cursor()

    for l2, cols in L2_TABLES.items():
        tbl = f"test_dwd.dwd_l2_circuit_protection_{l2}"
        lines.append("")
        lines.append("=" * 72)
        lines.append(f"L2: {l2}")
        lines.append("=" * 72)

        cur.execute(
            f"""
            SELECT COUNT(*) total,
                   SUM(CASE WHEN brand IS NULL OR trim(brand)='' THEN 1 ELSE 0 END) brand_null,
                   COUNT(DISTINCT brand) db, COUNT(DISTINCT brandid) dbid
            FROM {tbl} WHERE data_source='icpdf'
            """
        )
        bg = cur.fetchone()
        lines.append(
            f"rows={bg['total']:,} brand_null={bg['brand_null']:,} "
            f"distinct_brand={bg['db']:,} distinct_brandid={bg['dbid']:,}"
        )
        if bg["brand_null"]:
            lines.append("[WARN] 品牌门控未通过：brand 有空值")
        elif bg["db"] != bg["dbid"]:
            lines.append("[WARN] 品牌门控未通过：distinct_brand != distinct_brandid")

        cur.execute(f"SELECT COUNT(*) n FROM {tbl} WHERE data_source='icpdf'")
        total = cur.fetchone()["n"] or 1
        lines.append("\nL2 物理列填充率:")
        for col in cols:
            cur.execute(
                f"SELECT SUM(CASE WHEN `{col}` IS NOT NULL AND trim(cast(`{col}` as string))<>'' THEN 1 ELSE 0 END) f "
                f"FROM {tbl} WHERE data_source='icpdf'"
            )
            f = cur.fetchone()["f"]
            pct = 100.0 * f / total
            flag = " [0%]" if f == 0 else (" [LOW]" if pct < 20 else "")
            lines.append(f"  {col:<28} {f:>8,} / {total:,} ({pct:5.1f}%){flag}")

        cur.execute(
            f"""
            SELECT l3_code, COUNT(*) n,
                   SUM(CASE WHEN ext_attributes IS NOT NULL THEN 1 ELSE 0 END) ext
            FROM {tbl} WHERE data_source='icpdf'
            GROUP BY l3_code ORDER BY n DESC
            """
        )
        lines.append("\nL3 ext_attributes 覆盖:")
        for r in cur.fetchall():
            pct = 100.0 * r["ext"] / r["n"] if r["n"] else 0
            lines.append(f"  {r['l3_code']:<24} {r['ext']:>6,} / {r['n']:>6,} ({pct:5.1f}%)")

    cur.execute(
        """
        SELECT scope_code, std_attr_code FROM test_dim.dim_attr_schema_circuit_protection
        WHERE scope_level='l3' ORDER BY scope_code, std_attr_code
        """
    )
    l3_fields = cur.fetchall()
    lines.append("")
    lines.append("=" * 72)
    lines.append("L3 schema 字段清单（ext 候选）")
    lines.append("=" * 72)
    for r in l3_fields:
        lines.append(f"  {r['scope_code']:<20} {r['std_attr_code']}")

    text = "\n".join(lines) + "\n"
    OUT.write_text(text, encoding="utf-8")
    print(text)
    print(f"\n报告 → {OUT}")
    conn.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
