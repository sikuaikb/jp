#!/usr/bin/env python3
"""模拟专用逻辑器件专规后剩余。"""
import os, re
from pathlib import Path
import pymysql

ENV = Path(__file__).resolve().parents[3] / "local.env"
for line in ENV.read_text(encoding="utf-8").splitlines():
    if line.strip().startswith("export "):
        k, _, v = line.strip()[7:].partition("=")
        os.environ[k] = v.strip().strip("'").strip('"')

RULES = [
    ("adder", r"加法器|全加|Adder", "alu_adder"),
    ("regbuf", r"寄存缓冲", "buffer_driver"),
    ("register", r"寄存器", "register"),
    ("comparator", r"比较器", "digital_comparator"),
    ("transceiver", r"收发器", "bus_transceiver"),
    ("buffer", r"缓冲器", "buffer_driver"),
]

conn = pymysql.connect(
    host=os.environ["MYSQL_HOST"], port=9030,
    user=os.environ["MYSQL_USER"], password=os.environ["MYSQL_PASSWORD"],
    charset="utf8mb4", cursorclass=pymysql.cursors.DictCursor,
)
cur = conn.cursor()
cur.execute("SELECT note_cn FROM dwd.dwd_digikey_component_param WHERE category='专用逻辑器件'")
fb = 0
from collections import Counter
c = Counter()
for row in cur.fetchall():
    note = row["note_cn"] or ""
    hit = False
    for _, pat, lbl in RULES:
        if re.search(pat, note, re.I):
            c[lbl] += 1
            hit = True
            break
    if not hit:
        fb += 1
        c["fb"] += 1
print("specialty sim:", dict(c))
print("fb samples need:")
cur.execute("SELECT LEFT(note_cn,70) n, COUNT(*) c FROM dwd.dwd_digikey_component_param WHERE category='专用逻辑器件' GROUP BY 1 ORDER BY c DESC LIMIT 15")
for r in cur.fetchall():
    print(r["c"], r["n"])
conn.close()
