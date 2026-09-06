#!/usr/bin/env python3
"""circuit_protection 属性清洗：装载 dim → ICPDF EAV（test only）。"""
from __future__ import annotations

import os
import re
import subprocess
import sys
from pathlib import Path

import pymysql

HERE = Path(__file__).resolve().parent
ENV = HERE.parents[1] / "local.env"


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


def main() -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    load_env()

    subprocess.run([sys.executable, str(HERE / "gen_attr_extract_rule_icpdf_circuit_protection.py")], check=True)
    subprocess.run([sys.executable, str(HERE / "append_stage_a_extract_rules.py")], check=True)
    subprocess.run([sys.executable, str(HERE / "append_stage_b_extract_rules.py")], check=True)
    subprocess.run([sys.executable, str(HERE / "append_stage_c_gdt_esd_rules.py")], check=True)
    subprocess.run([sys.executable, str(HERE / "append_stage_d_pptc_spd_rules.py")], check=True)
    subprocess.run([sys.executable, str(HERE / "append_stage_e_tco_rules.py")], check=True)
    subprocess.run([sys.executable, str(HERE / "append_stage_f_pptc_rules.py")], check=True)
    subprocess.run([sys.executable, str(HERE / "gen_build_attr_std_icpdf.py")], check=True)
    subprocess.run([sys.executable, str(HERE / "load_attr_seed_circuit_protection.py"), "--db", "test_dim"], check=True)

    conn = connect()
    cur = conn.cursor()
    cur.execute("SET query_timeout = 900")
    cur.execute("SET enable_local_shuffle_agg=false")

    unit_sup = HERE / "dim_unit_factor_circuit_protection_supplement.sql"
    if unit_sup.exists():
        exec_file(cur, unit_sup)

    exec_file(cur, HERE / "dwd_component_attr_std_circuit_protection.sql")
    exec_file(cur, HERE / "build_dwd_icpdf_component_attr_std_circuit_protection.sql")
    tco_sup = HERE / "build_dwd_icpdf_tco_partno_rated_temp_supplement.sql"
    if tco_sup.exists():
        exec_file(cur, tco_sup)
    pptc_sup = HERE / "build_dwd_icpdf_pptc_partno_hold_supplement.sql"
    if pptc_sup.exists():
        exec_file(cur, pptc_sup)

    cur.execute(
        """
        SELECT data_source, COUNT(DISTINCT id) ids, COUNT(*) rows_cnt,
               COUNT(DISTINCT CASE WHEN value_std_double IS NOT NULL
                    OR (value_std_varchar IS NOT NULL AND trim(value_std_varchar) <> '')
               THEN id END) val_ids
        FROM test_dwd.dwd_component_attr_std_circuit_protection
        GROUP BY data_source
        """
    )
    print("\n=== EAV 汇总 ===")
    for r in cur.fetchall():
        print(r)

    cur.execute(
        """
        SELECT std_attr_code, COUNT(DISTINCT id) filled
        FROM test_dwd.dwd_component_attr_std_circuit_protection
        WHERE data_source='icpdf'
          AND (value_std_double IS NOT NULL
               OR (value_std_varchar IS NOT NULL AND trim(value_std_varchar) <> ''))
        GROUP BY std_attr_code ORDER BY filled DESC LIMIT 20
        """
    )
    print("\n=== ICPDF Top 属性命中 ===")
    for r in cur.fetchall():
        print(f"  {r['std_attr_code']:<28} {r['filled']:>7,}")

    cur.execute(
        """
        SELECT COUNT(DISTINCT c.id) class_n,
               COUNT(DISTINCT e.id) eav_n
        FROM test_dwd.dwd_component_class_circuit_protection c
        LEFT JOIN test_dwd.dwd_component_attr_std_circuit_protection e
          ON e.id=c.id AND e.data_source=c.data_source
        WHERE c.data_source='icpdf'
        """
    )
    print("\n=== ICPDF 分类 vs EAV 覆盖 ===")
    print(cur.fetchone())
    conn.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
