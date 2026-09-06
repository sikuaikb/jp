#!/usr/bin/env python3
"""探查 EAV lead_free 值分布, 写到 TSV 文件 (避免控制台编码问题)。"""
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

c.execute("""
    SELECT value_std_varchar v, COUNT(*) n
    FROM dwd.dwd_component_attr_std
    WHERE std_attr_code='lead_free'
    GROUP BY value_std_varchar ORDER BY n DESC
""")
rows = c.fetchall()
out = Path(__file__).resolve().parent / "artifacts" / "eav_lead_free_values.tsv"
out.parent.mkdir(parents=True, exist_ok=True)
lines = ["value_std_varchar\trows"]
total = 0
for r in rows:
    v = "" if r["v"] is None else str(r["v"])
    lines.append(f"{v}\t{r['n']}")
    total += r["n"]
out.write_text("\n".join(lines), encoding="utf-8")
print(f"共 {len(rows)} 种值, 总 {total:,} 行 -> {out}")

# value_std_double
c.execute("""
    SELECT value_std_double v, COUNT(*) n FROM dwd.dwd_component_attr_std
    WHERE std_attr_code='lead_free' AND value_std_double IS NOT NULL
    GROUP BY value_std_double
""")
drows = c.fetchall()
print("value_std_double 非空:", [(str(r["v"]), r["n"]) for r in drows])

c.close(); conn.close()
