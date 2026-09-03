#!/usr/bin/env python3
"""logic_ic 属性清洗一键验收：test_dim → EAV → L2 → 审计。"""
from __future__ import annotations

import os
import re
import subprocess
import sys
from pathlib import Path

import pymysql

HERE = Path(__file__).resolve().parent
SQL_ROOT = HERE.parents[1]
ENV = SQL_ROOT / "local.env"
CLASSIFIED = 19_591


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

    subprocess.run([sys.executable, str(HERE / "load_attr_seed_logic_ic.py"), "--db", "test_dim"], check=True)

    conn = connect()
    cur = conn.cursor()
    cur.execute("SET query_timeout = 900")

    print("\n=== EAV ===")
    exec_file(cur, HERE / "dwd_component_attr_std_logic_ic.sql")
    exec_file(cur, HERE / "build_dwd_digikey_component_attr_std_logic_ic.sql")
    cur.execute(
        """
        SELECT COUNT(DISTINCT id) parts, COUNT(*) rows_cnt, COUNT(DISTINCT std_attr_code) codes
        FROM test_dwd.dwd_component_attr_std_logic_ic WHERE data_source='digikey'
        """
    )
    eav = cur.fetchone()
    print(f"  器件 {eav['parts']:,}/{CLASSIFIED:,}  行 {eav['rows_cnt']:,}  属性种类 {eav['codes']}")
    conn.close()

    print("\n=== L2 全部宽表 ===")
    rc = subprocess.run([sys.executable, str(HERE / "run_all_l2_logic_ic.py")]).returncode

    conn = connect()
    cur = conn.cursor()
    cur.execute("SELECT COUNT(*) n FROM test_dwd.dwd_l2_logic_ic_combinational_logic")
    l2n = cur.fetchone()["n"]
    conn.close()

    rc |= subprocess.run([sys.executable, str(HERE / "audit" / "schema_eav_fill_audit.py")]).returncode
    rc |= subprocess.run([sys.executable, str(HERE / "audit" / "brand_gate_audit.py")]).returncode

    if eav["parts"] >= int(CLASSIFIED * 0.85) and l2n > 0 and rc == 0:
        print("\n=== logic_ic 属性清洗验收 PASS ===")
        return 0
    print("\n=== logic_ic 属性清洗验收 FAIL / WARN ===")
    return 1


if __name__ == "__main__":
    sys.exit(main())
