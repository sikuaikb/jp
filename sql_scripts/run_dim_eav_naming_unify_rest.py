#!/usr/bin/env python3
"""完成剩余: dim.dim_attr_extract_rule (DELETE+INSERT) + EAV (DELETE+INSERT) + 校验。"""
import os, time
from pathlib import Path
import pymysql

ENV = Path(__file__).resolve().parent / "local.env"
for line in ENV.read_text(encoding="utf-8").splitlines():
    if line.strip().startswith("export "):
        k, _, v = line[7:].partition("=")
        os.environ[k] = v.strip().strip("'").strip('"')

conn = pymysql.connect(host=os.environ["MYSQL_HOST"], port=9030,
    user=os.environ["MYSQL_USER"], password=os.environ["MYSQL_PASSWORD"],
    charset="utf8mb4", cursorclass=pymysql.cursors.DictCursor, autocommit=True)
c = conn.cursor()

ALIAS = {
    "ro_hs_compliant": "rohs_compliant",
    "life_cycle_status": "lifecycle_status",
    "mounting_type": "mounting_style",
    "aec_qualified": "aec_q_level",
}

def cnt(table, code):
    c.execute(f"SELECT COUNT(*) n FROM {table} WHERE std_attr_code=%s", (code,))
    return c.fetchone()["n"]

def cols_of(table):
    c.execute(f"SHOW COLUMNS FROM {table}")
    return [r["Field"] for r in c.fetchall()]

# ── dim.dim_attr_extract_rule: DELETE+INSERT ──
print("=== dim.dim_attr_extract_rule (DELETE+INSERT) ===")
er_cols = cols_of("dim.dim_attr_extract_rule")
er_col_list = ",".join(f"`{x}`" for x in er_cols)
for old, new in ALIAS.items():
    before = cnt("dim.dim_attr_extract_rule", old)
    if before == 0:
        print(f"  {old}: 0 (跳过)")
        continue
    select_expr = ",".join(f"'{new}'" if x == "std_attr_code" else f"`{x}`" for x in er_cols)
    c.execute(f"INSERT INTO dim.dim_attr_extract_rule ({er_col_list}) SELECT {select_expr} FROM dim.dim_attr_extract_rule WHERE std_attr_code=%s", (old,))
    ins = c.rowcount
    c.execute("DELETE FROM dim.dim_attr_extract_rule WHERE std_attr_code=%s", (old,))
    dele = c.rowcount
    print(f"  {old}({before}) -> {new}: insert={ins} delete={dele} old残留={cnt('dim.dim_attr_extract_rule', old)} new={cnt('dim.dim_attr_extract_rule', new)}")

# ── EAV: DELETE+INSERT ──
print("\n=== dwd.dwd_component_attr_std (EAV, DELETE+INSERT) ===")
eav_cols = cols_of("dwd.dwd_component_attr_std")
eav_col_list = ",".join(f"`{x}`" for x in eav_cols)
for old, new in ALIAS.items():
    before = cnt("dwd.dwd_component_attr_std", old)
    if before == 0:
        print(f"  {old}: 0 (跳过)")
        continue
    t0 = time.time()
    select_expr = ",".join(f"'{new}'" if x == "std_attr_code" else f"`{x}`" for x in eav_cols)
    c.execute(f"INSERT INTO dwd.dwd_component_attr_std ({eav_col_list}) SELECT {select_expr} FROM dwd.dwd_component_attr_std WHERE std_attr_code=%s", (old,))
    ins = c.rowcount
    c.execute("DELETE FROM dwd.dwd_component_attr_std WHERE std_attr_code=%s", (old,))
    dele = c.rowcount
    dt = time.time() - t0
    print(f"  {old}({before:,}) -> {new}: insert={ins:,} delete={dele:,} old残留={cnt('dwd.dwd_component_attr_std', old)} new={cnt('dwd.dwd_component_attr_std', new):,} ({dt:.1f}s)")

# ── 校验 ──
print("\n=== 校验旧码残留 ===")
tables = ["dim.dim_std_component_attr", "dim.dim_attr_schema",
          "dim.dim_attr_extract_rule", "dwd.dwd_component_attr_std"]
total = 0
for t in tables:
    for old in ALIAS:
        n = cnt(t, old)
        if n:
            print(f"  {t} 残留 {old}: {n}")
            total += n
print(f"  总残留: {total}  {'OK' if total == 0 else 'FAIL'}")
c.close(); conn.close()
