#!/usr/bin/env python3
import os
from pathlib import Path
import pymysql

env = Path(__file__).resolve().parents[3] / "local.env"
for line in env.read_text(encoding="utf-8").splitlines():
    line = line.strip()
    if line.startswith("export "):
        line = line[7:]
    if "=" in line and not line.startswith("#"):
        k, _, v = line.partition("=")
        os.environ[k.strip()] = v.strip().strip("'").strip('"')

conn = pymysql.connect(
    host=os.environ["MYSQL_HOST"],
    port=int(os.environ.get("MYSQL_PORT", "9030")),
    user=os.environ["MYSQL_USER"],
    password=os.environ["MYSQL_PASSWORD"],
    charset="utf8mb4",
    cursorclass=pymysql.cursors.DictCursor,
)
cur = conn.cursor()
for tbl in ["dim_l3_classify_logic_ic", "dim_l3_classify_rule_logic_ic"]:
    cur.execute(f"SELECT COUNT(*) n FROM test_dim.{tbl}")
    print(f"{tbl}: {cur.fetchone()['n']} rows")
cur.execute(
    "SELECT rule_kind, COUNT(*) n FROM test_dim.dim_l3_classify_rule_logic_ic GROUP BY rule_kind"
)
print("rule_kind:", cur.fetchall())
conn.close()
