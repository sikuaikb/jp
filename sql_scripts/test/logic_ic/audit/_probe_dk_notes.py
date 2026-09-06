#!/usr/bin/env python3
import os
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

for cat in ["触发器", "移位寄存器", "比较器", "信号开关，多路复用器，解码器"]:
    cur.execute(
        "SELECT LEFT(note_cn, 55) n, COUNT(*) c FROM dwd.dwd_digikey_component_param WHERE category=%s GROUP BY 1 ORDER BY c DESC LIMIT 5",
        (cat,),
    )
    print("---", cat)
    for r in cur.fetchall():
        print(r["c"], r["n"])

cur.execute(
    """
    SELECT category, COUNT(*) n FROM dwd.dwd_digikey_component_param
    WHERE note_cn LIKE %s
      AND category IN ('缓冲器，驱动器，接收器，收发器','驱动器，接收器，收发器','信号缓冲器、中继器、分离器')
    GROUP BY 1
    """,
    ("%电平%",),
)
print("\nlevel keyword in buffer cats:", cur.fetchall())

cur.execute(
    """
    SELECT category, COUNT(*) n FROM dwd.dwd_digikey_component_param
    WHERE (note_cn LIKE %s OR note_cn LIKE %s)
      AND category IN ('触发器','专用逻辑器件','信号开关，多路复用器，解码器','门和反相器')
    GROUP BY 1 ORDER BY n DESC
    """,
    ("%计数器%", "%分频%"),
)
print("counter/divider notes:", cur.fetchall())

conn.close()
