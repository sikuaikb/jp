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

cur.execute(
    """
    SELECT LEFT(note_cn, 60) n, COUNT(*) c
    FROM dwd.dwd_digikey_component_param WHERE category='信号缓冲器、中继器、分离器'
    GROUP BY 1 ORDER BY c DESC LIMIT 12
    """
)
print("信号缓冲器、中继器、分离器:")
for r in cur.fetchall():
    print(f"  {r['c']:4} {r['n']!r}")

cur.execute(
    """
    SELECT LEFT(note_cn, 60) n, COUNT(*) c
    FROM dwd.dwd_digikey_component_param WHERE category='缓冲器，驱动器，接收器，收发器'
    GROUP BY 1 ORDER BY c DESC LIMIT 8
    """
)
print("\n缓冲器，驱动器，接收器，收发器:")
for r in cur.fetchall():
    print(f"  {r['c']:4} {r['n']!r}")

cur.execute(
    """
    SELECT LEFT(note_cn, 60) n, COUNT(*) c
    FROM dwd.dwd_digikey_component_param WHERE category='驱动器，接收器，收发器'
    GROUP BY 1 ORDER BY c DESC LIMIT 8
    """
)
print("\n驱动器，接收器，收发器:")
for r in cur.fetchall():
    print(f"  {r['c']:4} {r['n']!r}")

# overlap between two buffer cats
cur.execute(
    """
    SELECT COUNT(DISTINCT a.id) n
    FROM dwd.dwd_digikey_component_param a
    JOIN dwd.dwd_digikey_component_param b ON a.id = b.id
    WHERE a.category='缓冲器，驱动器，接收器，收发器'
      AND b.category='驱动器，接收器，收发器'
    """
)
print("\noverlap ids:", cur.fetchone())

conn.close()
