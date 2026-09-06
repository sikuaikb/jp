#!/usr/bin/env python3
"""探查 dim/EAV 命名统一的现状与冲突。
别名 -> 规范名:
  ro_hs_compliant   -> rohs_compliant
  life_cycle_status -> lifecycle_status
  mounting_type     -> mounting_style
  aec_qualified     -> aec_q_level
"""
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

ALIAS = {
    "ro_hs_compliant": "rohs_compliant",
    "life_cycle_status": "lifecycle_status",
    "mounting_type": "mounting_style",
    "aec_qualified": "aec_q_level",
}

def cols(table):
    c.execute(f"SHOW COLUMNS FROM {table}")
    return [r["Field"] for r in c.fetchall()]

print("=== 表结构 ===")
for t in ["dim.dim_std_component_attr", "dim.dim_attr_schema", "dwd.dwd_component_attr_std"]:
    print(f"\n{t}:")
    print("  " + ", ".join(cols(t)))

print("\n=== dim.dim_std_component_attr: 别名 vs 规范名 行数 ===")
c.execute("SHOW COLUMNS FROM dim.dim_std_component_attr")
std_cols = [r["Field"] for r in c.fetchall()]
code_col = "std_attr_code" if "std_attr_code" in std_cols else ("attr_code" if "attr_code" in std_cols else None)
print(f"  code col = {code_col}")
if code_col:
    for old, new in ALIAS.items():
        c.execute(f"SELECT COUNT(*) n FROM dim.dim_std_component_attr WHERE {code_col}=%s", (old,))
        on = c.fetchone()["n"]
        c.execute(f"SELECT COUNT(*) n FROM dim.dim_std_component_attr WHERE {code_col}=%s", (new,))
        nn = c.fetchone()["n"]
        print(f"  {old:20s} -> {new:18s}  old={on}  new(exist)={nn}")

print("\n=== dim.dim_attr_schema: 涉及别名的列与行数 ===")
c.execute("SHOW COLUMNS FROM dim.dim_attr_schema")
sch_cols = [r["Field"] for r in c.fetchall()]
print(f"  columns: {sch_cols}")
# 找可能持有 attr code 的列
candidate_cols = [col for col in sch_cols if "attr" in col.lower() and "code" in col.lower()]
print(f"  candidate code cols: {candidate_cols}")
for col in candidate_cols:
    print(f"\n  -- 按 {col} --")
    for old, new in ALIAS.items():
        c.execute(f"SELECT COUNT(*) n FROM dim.dim_attr_schema WHERE {col}=%s", (old,))
        on = c.fetchone()["n"]
        c.execute(f"SELECT COUNT(*) n FROM dim.dim_attr_schema WHERE {col}=%s", (new,))
        nn = c.fetchone()["n"]
        if on or nn:
            print(f"    {old:20s} old={on}   {new:18s} new(exist)={nn}")

print("\n=== dwd.dwd_component_attr_std (EAV): 别名 vs 规范名 行数 ===")
c.execute("SHOW COLUMNS FROM dwd.dwd_component_attr_std")
eav_cols = [r["Field"] for r in c.fetchall()]
eav_code = "std_attr_code" if "std_attr_code" in eav_cols else ("attr_code" if "attr_code" in eav_cols else None)
print(f"  code col = {eav_code}")
if eav_code:
    for old, new in ALIAS.items():
        c.execute(f"SELECT COUNT(*) n FROM dwd.dwd_component_attr_std WHERE {eav_code}=%s", (old,))
        on = c.fetchone()["n"]
        c.execute(f"SELECT COUNT(*) n FROM dwd.dwd_component_attr_std WHERE {eav_code}=%s", (new,))
        nn = c.fetchone()["n"]
        print(f"  {old:20s} -> {new:18s}  old={on:>10,}  new(exist)={nn:>10,}")

c.close(); conn.close()
