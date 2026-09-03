#!/usr/bin/env python3
import os
from pathlib import Path
import pymysql

SQL_ROOT = Path(__file__).resolve().parents[3]
for line in (SQL_ROOT / "local.env").read_text(encoding="utf-8").splitlines():
    if line.strip().startswith("export "):
        k, _, v = line.strip()[7:].partition("=")
        os.environ[k] = v.strip().strip("'").strip('"')

conn = pymysql.connect(
    host=os.environ["MYSQL_HOST"],
    port=int(os.environ.get("MYSQL_PORT", "9030")),
    user=os.environ["MYSQL_USER"],
    password=os.environ["MYSQL_PASSWORD"],
    charset="utf8mb4",
    cursorclass=pymysql.cursors.DictCursor,
)
cur = conn.cursor()
terms = [
    "Rochester", "Quality Semiconductor", "IDT", "AMD", "Advanced Micro",
    "ADSANTEC", "TAEJIN", "Flip Electronics", "Runic", "润石", "Lattice",
    "Renasas", "Renesas",
]
for t in terms:
    print(f"=== {t} ===")
    cur.execute(
        """
        SELECT brand_id_std, name, abbr
        FROM dim.dim_std_brand
        WHERE UPPER(name) LIKE %s OR UPPER(COALESCE(abbr,'')) LIKE %s
        LIMIT 8
        """,
        (f"%{t.upper()}%", f"%{t.upper()}%"),
    )
    for r in cur.fetchall():
        print(f"  std {r['brand_id_std']} | {r['name']} | {r['abbr']}")
    cur.execute(
        """
        SELECT brand_key, brand_id_std, canonical_name
        FROM dim.v_std_brand_alias
        WHERE brand_key LIKE %s
        LIMIT 5
        """,
        (f"%{t.upper().replace(' ', '%')}%",),
    )
    for r in cur.fetchall():
        print(f"  alias {r['brand_key']} -> {r['canonical_name']} ({r['brand_id_std']})")
conn.close()
