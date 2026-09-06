#!/usr/bin/env python3
"""switch test：品牌字典 → L2 宽表（icpdf + digikey，不写 prod）。"""
from __future__ import annotations

import os
import re
import subprocess
import sys
from pathlib import Path

import pymysql

HERE = Path(__file__).resolve().parent
ENV = HERE.parents[1] / "local.env"

L2_BUILDS = (
    "mechanical_actuated_switch",
    "mechanical_sensing_switch",
    "magnetic_sensing_switch",
)


def load_env() -> None:
    for line in ENV.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line.startswith("export "):
            k, _, v = line[7:].partition("=")
            os.environ[k] = v.strip().strip("'").strip('"')


def connect():
    return pymysql.connect(
        host=os.environ["MYSQL_HOST"],
        port=int(os.environ.get("MYSQL_PORT", "9030")),
        user=os.environ["MYSQL_USER"],
        password=os.environ["MYSQL_PASSWORD"],
        charset="utf8mb4",
        autocommit=True,
        cursorclass=pymysql.cursors.DictCursor,
    )


def split_sql(text: str) -> list[str]:
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.DOTALL)
    parts: list[str] = []
    buf: list[str] = []
    for line in text.splitlines():
        buf.append(line)
        if re.sub(r"^\s*--.*$", "", line).rstrip().endswith(";"):
            stmt = "\n".join(buf).strip().rstrip(";").strip()
            if stmt:
                parts.append(stmt)
            buf = []
    return parts


def exec_file(cur, path: Path) -> None:
    print(f"==> {path.name}")
    for stmt in split_sql(path.read_text(encoding="utf-8-sig")):
        cur.execute(stmt)


def brand_gate(cur, table: str) -> None:
    cur.execute(
        f"""
        SELECT
            COUNT(*) AS total_rows,
            SUM(CASE WHEN brand IS NULL OR TRIM(brand) = '' THEN 1 ELSE 0 END) AS brand_null,
            SUM(CASE WHEN brand IS NOT NULL AND TRIM(brand) <> '' AND brandid IS NULL THEN 1 ELSE 0 END) AS dict_gap,
            COUNT(DISTINCT brand) AS distinct_brand,
            COUNT(DISTINCT brandid) AS distinct_brandid,
            SUM(CASE WHEN manufacturer IS NOT NULL AND TRIM(manufacturer) <> '' THEN 1 ELSE 0 END) AS has_mfr
        FROM {table}
        WHERE data_source = 'icpdf'
        """
    )
    r = cur.fetchone()
    print(f"  [icpdf] rows={r['total_rows']:,} brand_null={r['brand_null']:,} "
          f"dict_gap={r['dict_gap']:,} mfr={r['has_mfr']:,}")


def main() -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    load_env()

    subprocess.run([sys.executable, str(HERE / "gen_l2_wide_switch.py")], check=True)
    subprocess.run([sys.executable, str(HERE / "run_brand_sync.py")], check=True)
    supplement = HERE.parent / "brand_supplement" / "apply_brand_supplement_switch.py"
    if supplement.exists():
        subprocess.run([sys.executable, str(supplement)], check=True)
    subprocess.run([sys.executable, str(HERE / "audit" / "brand_scan_switch.py")], check=True)

    conn = connect()
    cur = conn.cursor()
    cur.execute("SET query_timeout = 900")
    cur.execute("SET enable_local_shuffle_agg=false")

    for l2 in L2_BUILDS:
        exec_file(cur, HERE / f"dwd_l2_switch_{l2}.sql")
        exec_file(cur, HERE / f"build_dwd_l2_switch_{l2}.sql")
        brand_gate(cur, f"test_dwd.dwd_l2_switch_{l2}")

    print("\n=== L2 汇总 (icpdf) ===")
    summaries = {
        "mechanical_actuated_switch": "circuit_type",
        "mechanical_sensing_switch": "rated_voltage_v",
        "magnetic_sensing_switch": "switching_voltage_max_v",
    }
    for l2, key_col in summaries.items():
        cur.execute(
            f"""
            SELECT COUNT(*) n,
                   SUM(CASE WHEN temp_min_c IS NOT NULL THEN 1 ELSE 0 END) tmin,
                   SUM(CASE WHEN `{key_col}` IS NOT NULL THEN 1 ELSE 0 END) key_attr
            FROM test_dwd.dwd_l2_switch_{l2}
            WHERE data_source='icpdf'
            """
        )
        r = cur.fetchone()
        print(f"  {l2}: rows={r['n']:,} tmin={r['tmin']:,} {key_col}={r['key_attr']:,}")

    conn.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
