#!/usr/bin/env python3
import os, re
from collections import Counter
from pathlib import Path
import pymysql

ENV = Path(__file__).resolve().parents[3] / "local.env"
for line in ENV.read_text(encoding="utf-8").splitlines():
    if line.strip().startswith("export "):
        k, _, v = line.strip()[7:].partition("=")
        os.environ[k] = v.strip().strip("'").strip('"')

conn = pymysql.connect(
    host=os.environ["MYSQL_HOST"], port=9030,
    user=os.environ["MYSQL_USER"], password=os.environ["MYSQL_PASSWORD"],
    charset="utf8mb4", cursorclass=pymysql.cursors.DictCursor,
)
cur = conn.cursor()

for kw in ["计数", "分频", "寄存器", "寄存缓冲", "加法", "全加"]:
    cur.execute(
        """
        SELECT category, COUNT(*) n FROM dwd.dwd_digikey_component_param
        WHERE category IN ('触发器','专用逻辑器件','信号开关，多路复用器，解码器')
          AND note_cn LIKE %s
        GROUP BY 1 ORDER BY n DESC
        """,
        (f"%{kw}%",),
    )
    rows = cur.fetchall()
    if rows:
        print(kw, rows)

# null note in buffer cat
cur.execute(
    """
    SELECT COUNT(*) n FROM dwd.dwd_digikey_component_param
    WHERE category='缓冲器，驱动器，接收器，收发器' AND (note_cn IS NULL OR TRIM(note_cn)='')
    """
)
print("buffer null note:", cur.fetchone()["n"])

conn.close()
