#!/usr/bin/env python3
"""switch 属性清洗：装载 dim → ICPDF EAV（test only）。"""
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

    subprocess.run([sys.executable, str(HERE / "gen_attr_extract_rule_icpdf_switch.py")], check=True)
    subprocess.run([sys.executable, str(HERE / "load_attr_seed_switch.py"), "--db", "test_dim"], check=True)

    conn = connect()
    cur = conn.cursor()
    cur.execute("SET query_timeout = 900")
    cur.execute("SET enable_local_shuffle_agg=false")

    exec_file(cur, HERE / "dwd_component_attr_std_switch.sql")
    exec_file(cur, HERE / "build_dwd_icpdf_component_attr_std_switch.sql")
    if Path(HERE / "build_dwd_digikey_component_attr_std_switch.sql").exists():
        cur.execute(
            "SELECT COUNT(*) c FROM test_dwd.dwd_component_class_switch WHERE data_source='digikey'"
        )
        if cur.fetchone()["c"]:
            exec_file(cur, HERE / "build_dwd_digikey_component_attr_std_switch.sql")

    cur.execute(
        """
        SELECT data_source, COUNT(DISTINCT id) ids, COUNT(*) rows_cnt,
               COUNT(DISTINCT CASE WHEN value_std_double IS NOT NULL
                    OR (value_std_varchar IS NOT NULL AND trim(value_std_varchar) <> '')
               THEN id END) val_ids
        FROM test_dwd.dwd_component_attr_std_switch
        GROUP BY data_source
        """
    )
    print("\n=== EAV 汇总 ===")
    for r in cur.fetchall():
        print(r)

    cur.execute(
        """
        SELECT std_attr_code, COUNT(DISTINCT id) filled
        FROM test_dwd.dwd_component_attr_std_switch
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
        FROM test_dwd.dwd_component_class_switch c
        LEFT JOIN test_dwd.dwd_component_attr_std_switch e
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
