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

queries = [
    (
        "mux_fb 含「编码器」",
        """
        SELECT COUNT(*) AS n FROM dwd.dwd_digikey_component_param p
        JOIN test_dwd.dwd_component_class_logic_ic c ON c.id=p.id
        WHERE p.category='信号开关，多路复用器，解码器' AND c.rule_id='logic_ic_dk_mux_fb_v1'
          AND p.note_cn LIKE '%编码器%'
        """,
    ),
    (
        "special_fb 含触发器/锁存",
        """
        SELECT COUNT(*) AS n FROM dwd.dwd_digikey_component_param p
        JOIN test_dwd.dwd_component_class_logic_ic c ON c.id=p.id
        WHERE p.category='专用逻辑器件' AND c.rule_id='logic_ic_dk_special_fb_v1'
          AND (p.note_cn LIKE '%触发器%' OR p.note_cn LIKE '%锁存%')
        """,
    ),
]
for title, sql in queries:
    cur.execute(sql)
    print(f"{title}: {cur.fetchone()['n']}")

cur.execute(
    """
    SELECT c.l3_code, c.rule_id, COUNT(DISTINCT p.id) AS n
    FROM dwd.dwd_digikey_component_param p
    JOIN test_dwd.dwd_component_class_logic_ic c ON c.id=p.id
    WHERE p.category='专用逻辑器件'
    GROUP BY c.l3_code, c.rule_id ORDER BY n DESC
    """
)
print("\n专用逻辑器件 rule×L3:")
for r in cur.fetchall():
    print(f"  {r['n']:>4}  {r['l3_code']:<22} {r['rule_id']}")

conn.close()
