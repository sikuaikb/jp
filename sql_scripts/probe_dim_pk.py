#!/usr/bin/env python3
"""查 dim 三张表与 EAV 的主键定义，确认哪些表 std_attr_code 是 PK。"""
import os
from pathlib import Path
import pymysql

ENV = Path(__file__).resolve().parent / "local.env"
for line in ENV.read_text(encoding="utf-8").splitlines():
    if line.strip().startswith("export "):
        k, _, v = line[7:].partition("=")
        os.environ[k] = v.strip().strip("'").strip('"')

conn = pymysql.connect(host=os.environ["MYSQL_HOST"], port=9030,
    user=os.environ["MYSQL_USER"], password=os.environ["MYSQL_PASSWORD"],
    charset="utf8mb4", cursorclass=pymysql.cursors.DictCursor)
c = conn.cursor()

for t in ["dim.dim_std_component_attr", "dim.dim_attr_schema",
          "dim.dim_attr_extract_rule", "dwd.dwd_component_attr_std"]:
    print(f"\n=== {t} ===")
    c.execute(f"SHOW CREATE TABLE {t}")
    ddl = c.fetchone()["Create Table"]
    # 找 PRIMARY KEY 行
    for line in ddl.split("\n"):
        if "PRIMARY KEY" in line.upper() or "UNIQUE" in line.upper() or "KEY " in line.upper():
            print("  " + line.strip())
    # 也列 DUPLICATE 风险：std_attr_code 是否在 PK
c.close(); conn.close()
