#!/usr/bin/env python3
"""执行一个 .sql 文件（按分号切分语句）。用法：python run_sql.py <file.sql>"""
from __future__ import annotations
import os, sys, re
from pathlib import Path
import pymysql

sys.stdout.reconfigure(encoding="utf-8")
ENV = Path(__file__).resolve().parents[1] / "local.env"
for line in ENV.read_text(encoding="utf-8").splitlines():
    if line.strip().startswith("export "):
        k, _, v = line[7:].partition("=")
        os.environ[k] = v.strip().strip("'").strip('"')

sql_text = Path(sys.argv[1]).read_text(encoding="utf-8")
# 去掉 /* */ 注释块，避免切分干扰
sql_text = re.sub(r"/\*.*?\*/", "", sql_text, flags=re.DOTALL)
stmts = [s.strip() for s in sql_text.split(";") if s.strip()]

conn = pymysql.connect(
    host=os.environ["MYSQL_HOST"], port=int(os.environ.get("MYSQL_PORT", "9030")),
    user=os.environ["MYSQL_USER"], password=os.environ["MYSQL_PASSWORD"],
    charset="utf8mb4",
)
cur = conn.cursor()
for s in stmts:
    cur.execute(s)
    print(f"OK: {s[:70].replace(chr(10),' ')} …")
conn.commit()
conn.close()
print(f"\n执行完毕：{len(stmts)} 条语句。")
