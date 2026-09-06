#!/usr/bin/env python3
"""扫描所有 dim/dwd 表中 std_attr_code 列引用 4 个旧码的行数，确保覆盖全。"""
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

OLD = ("ro_hs_compliant", "life_cycle_status", "mounting_type", "aec_qualified")

# 找所有 dim/dwd 表里名为 std_attr_code 的列
c.execute("""
    SELECT table_schema, table_name, column_name
    FROM information_schema.columns
    WHERE table_schema IN ('dim','dwd')
      AND column_name IN ('std_attr_code','attr_code','std_attr')
""")
candidates = c.fetchall()
print("=== 含 std_attr_code 类列的表 ===")
for r in candidates:
    print(f"  {r['table_schema']}.{r['table_name']}.{r['column_name']}")

print("\n=== 各表引用旧码的行数 ===")
for r in candidates:
    ts, tn, col = r["table_schema"], r["table_name"], r["column_name"]
    for old in OLD:
        try:
            c.execute(f"SELECT COUNT(*) n FROM {ts}.{tn} WHERE {col}=%s", (old,))
            n = c.fetchone()["n"]
            if n:
                print(f"  {ts}.{tn}.{col} = '{old}': {n:,}")
        except Exception as e:
            print(f"  {ts}.{tn}.{col} ERR {e}")

# 额外：dim_attr_extract_rule 可能用 std_attr_code 或别的列
print("\n=== dim.dim_attr_extract_rule 结构 ===")
try:
    c.execute("SHOW COLUMNS FROM dim.dim_attr_extract_rule")
    cols = [r["Field"] for r in c.fetchall()]
    print("  " + ", ".join(cols))
    for col in cols:
        if "attr" in col.lower() or "code" in col.lower() or "target" in col.lower():
            for old in OLD:
                c.execute(f"SELECT COUNT(*) n FROM dim.dim_attr_extract_rule WHERE {col}=%s", (old,))
                n = c.fetchone()["n"]
                if n:
                    print(f"  dim.dim_attr_extract_rule.{col} = '{old}': {n:,}")
except Exception as e:
    print(f"  ERR {e}")

c.close(); conn.close()
