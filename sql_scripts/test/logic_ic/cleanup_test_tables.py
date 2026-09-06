#!/usr/bin/env python3
"""C1：清理 logic_ic test 后缀表。"""
import os
import sys
from pathlib import Path

import pymysql

sys.stdout.reconfigure(encoding="utf-8", errors="replace")

HERE = Path(__file__).resolve().parent
ENV = HERE.parents[2] / "sql_scripts" / "local.env"

TABLES = [
    "test_dim.dim_l3_classify_logic_ic",
    "test_dim.dim_l3_classify_rule_logic_ic",
    "test_dwd.dwd_component_class_logic_ic",
]


def load_env():
    for line in ENV.read_text(encoding="utf-8").splitlines():
        s = line.strip()
        if s.startswith("export "):
            s = s[7:]
        if "=" in s and not s.startswith("#"):
            k, v = s.split("=", 1)
            os.environ[k.strip()] = v.strip().strip("'").strip('"')


def main():
    load_env()
    conn = pymysql.connect(
        host=os.environ["MYSQL_HOST"],
        port=int(os.environ.get("MYSQL_PORT", "9030")),
        user=os.environ["MYSQL_USER"],
        password=os.environ["MYSQL_PASSWORD"],
        charset="utf8mb4",
        autocommit=True,
        cursorclass=pymysql.cursors.DictCursor,
    )
    cur = conn.cursor()
    for t in TABLES:
        cur.execute(f"DROP TABLE IF EXISTS {t}")
        print(f"  DROP {t}")
    cur.close()
    conn.close()
    print("C1 清理完成")


if __name__ == "__main__":
    main()
