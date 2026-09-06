#!/usr/bin/env python3
"""摸底 rohs_compliant: EAV 值分布 + DWD L2 列类型 + dim_attr_schema db_type。"""
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

# 1. EAV rohs_compliant value_std_varchar 分布
print("=== EAV rohs_compliant value_std_varchar 分布 ===")
c.execute("""
    SELECT value_std_varchar v, COUNT(*) n
    FROM dwd.dwd_component_attr_std
    WHERE std_attr_code='rohs_compliant'
    GROUP BY value_std_varchar ORDER BY n DESC
""")
rows = c.fetchall()
out = Path(__file__).resolve().parent / "artifacts" / "eav_rohs_compliant_values.tsv"
out.parent.mkdir(parents=True, exist_ok=True)
lines = ["value_std_varchar\trows"]
total = 0
for r in rows:
    v = "" if r["v"] is None else str(r["v"])
    lines.append(f"{v}\t{r['n']}")
    total += r["n"]
out.write_text("\n".join(lines), encoding="utf-8")
print(f"  共 {len(rows)} 种值, 总 {total:,} 行 -> {out}")

# value_std_double
c.execute("""
    SELECT value_std_double v, COUNT(*) n FROM dwd.dwd_component_attr_std
    WHERE std_attr_code='rohs_compliant' AND value_std_double IS NOT NULL
    GROUP BY value_std_double
""")
print("  value_std_double 非空:", [(str(r["v"]), r["n"]) for r in c.fetchall()])

# 2. DWD L2 rohs_compliant 列类型分布
print("\n=== DWD L2 rohs_compliant 列类型 ===")
c.execute("""
    SELECT data_type, COUNT(*) n FROM information_schema.columns
    WHERE table_schema='dwd' AND table_name LIKE 'dwd_l2_%' AND column_name='rohs_compliant'
    GROUP BY data_type
""")
for r in c.fetchall():
    print(f"  {r['data_type']}: {r['n']} 张")

# 3. dim_attr_schema rohs_compliant db_type
print("\n=== dim_attr_schema rohs_compliant db_type ===")
c.execute("""
    SELECT db_type, COUNT(*) n FROM dim.dim_attr_schema
    WHERE std_attr_code='rohs_compliant' GROUP BY db_type
""")
for r in c.fetchall():
    print(f"  {r['db_type']}: {r['n']}")

c.close(); conn.close()
