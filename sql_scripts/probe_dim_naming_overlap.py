#!/usr/bin/env python3
"""深入比对别名行 vs 规范名行的 scope 重叠，判断是重复(删)还是独立(改名)。"""
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

# ── 1. dim.dim_std_component_attr: 按 (l1_code, l2_code, std_attr_cn) 比对 ──
print("=" * 70)
print("dim.dim_std_component_attr  (key: l1_code, l2_code, std_attr_cn)")
print("=" * 70)
for old, new in ALIAS.items():
    print(f"\n--- {old} -> {new} ---")
    # 别名行的 scope 分布
    c.execute("""
        SELECT l1_code, l2_code, std_attr_cn, COUNT(*) n
        FROM dim.dim_std_component_attr WHERE std_attr_code=%s
        GROUP BY l1_code, l2_code, std_attr_cn ORDER BY n DESC
    """, (old,))
    old_rows = c.fetchall()
    if not old_rows:
        print("  别名行: 0 (无需处理)")
        continue
    print(f"  别名行 ({len(old_rows)} 个 scope 组合):")
    for r in old_rows[:8]:
        print(f"    l1={r['l1_code']:20s} l2={str(r['l2_code']):25s} cn={r['std_attr_cn']:20s} n={r['n']}")
    # 规范名行的 scope 分布
    c.execute("""
        SELECT l1_code, l2_code, std_attr_cn, COUNT(*) n
        FROM dim.dim_std_component_attr WHERE std_attr_code=%s
        GROUP BY l1_code, l2_code, std_attr_cn ORDER BY n DESC
    """, (new,))
    new_rows = c.fetchall()
    print(f"  规范名行 ({len(new_rows)} 个 scope 组合):")
    for r in new_rows[:8]:
        print(f"    l1={r['l1_code']:20s} l2={str(r['l2_code']):25s} cn={r['std_attr_cn']:20s} n={r['n']}")
    # 重叠：同一 (l1_code, l2_code) 两者都有
    c.execute("""
        SELECT COUNT(*) overlap FROM (
          SELECT l1_code, l2_code FROM dim.dim_std_component_attr WHERE std_attr_code=%s
          INTERSECT
          SELECT l1_code, l2_code FROM dim.dim_std_component_attr WHERE std_attr_code=%s
        ) x
    """, (old, new))
    ov = c.fetchone()["overlap"]
    print(f"  同 (l1,l2) 重叠 scope 数: {ov}  {'=> 重复，应删别名行' if ov else '=> 别名行 scope 独立，需改名'}")

# ── 2. dim.dim_attr_schema: 按 (l1_code, scope_level, scope_code) 比对 ──
print("\n" + "=" * 70)
print("dim.dim_attr_schema  (key: l1_code, scope_level, scope_code)")
print("=" * 70)
for old, new in ALIAS.items():
    print(f"\n--- {old} -> {new} ---")
    c.execute("""
        SELECT l1_code, scope_level, scope_code, std_attr_cn, COUNT(*) n
        FROM dim.dim_attr_schema WHERE std_attr_code=%s
        GROUP BY l1_code, scope_level, scope_code, std_attr_cn ORDER BY n DESC
    """, (old,))
    old_rows = c.fetchall()
    if not old_rows:
        print("  别名行: 0")
        continue
    print(f"  别名行 ({len(old_rows)} 组):")
    for r in old_rows[:8]:
        print(f"    l1={r['l1_code']:18s} {r['scope_level']:6s} {str(r['scope_code']):22s} cn={r['std_attr_cn']:18s} n={r['n']}")
    c.execute("""
        SELECT l1_code, scope_level, scope_code, std_attr_cn, COUNT(*) n
        FROM dim.dim_attr_schema WHERE std_attr_code=%s
        GROUP BY l1_code, scope_level, scope_code, std_attr_cn ORDER BY n DESC
    """, (new,))
    new_rows = c.fetchall()
    print(f"  规范名行 ({len(new_rows)} 组):")
    for r in new_rows[:6]:
        print(f"    l1={r['l1_code']:18s} {r['scope_level']:6s} {str(r['scope_code']):22s} cn={r['std_attr_cn']:18s} n={r['n']}")
    c.execute("""
        SELECT COUNT(*) overlap FROM (
          SELECT l1_code, scope_level, scope_code FROM dim.dim_attr_schema WHERE std_attr_code=%s
          INTERSECT
          SELECT l1_code, scope_level, scope_code FROM dim.dim_attr_schema WHERE std_attr_code=%s
        ) x
    """, (old, new))
    ov = c.fetchone()["overlap"]
    print(f"  同 scope 重叠数: {ov}  {'=> 重复，应删别名行' if ov else '=> 别名行 scope 独立，需改名'}")

c.close(); conn.close()
