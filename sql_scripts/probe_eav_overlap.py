#!/usr/bin/env python3
"""EAV SKU 级重叠探查 + dim_attr_schema 重叠 scope 详情。"""
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

print("=" * 70)
print("EAV SKU 级重叠 (同一 data_source+id 同时有 old 与 new 两行)")
print("=" * 70)
for old, new in ALIAS.items():
    # 既有 old 又有 new 的 SKU 数
    c.execute("""
        SELECT COUNT(*) both_n FROM (
          SELECT data_source, id FROM dwd.dwd_component_attr_std WHERE std_attr_code=%s
          INTERSECT
          SELECT data_source, id FROM dwd.dwd_component_attr_std WHERE std_attr_code=%s
        ) x
    """, (old, new))
    both = c.fetchone()["both_n"]
    c.execute("SELECT COUNT(*) n FROM dwd.dwd_component_attr_std WHERE std_attr_code=%s", (old,))
    oldn = c.fetchone()["n"]
    only_old = oldn - both
    print(f"\n  {old} -> {new}")
    print(f"    old 总行={oldn:>10,}  其中 SKU 同时有 new={both:>10,}  仅 old={only_old:>10,}")
    print(f"    => {both:,} 行应删除(重复)  {only_old:,} 行应改名 old->new")

print("\n" + "=" * 70)
print("dim_attr_schema 重叠 scope 详情 (ro_hs_compliant / life_cycle_status)")
print("=" * 70)
for old in ["ro_hs_compliant", "life_cycle_status"]:
    new = ALIAS[old]
    print(f"\n--- {old} vs {new} 重叠 scope ---")
    c.execute("""
        SELECT a.l1_code, a.scope_level, a.scope_code,
               a.std_attr_cn AS old_cn, b.std_attr_cn AS new_cn,
               a.unit_std AS old_unit, b.unit_std AS new_unit,
               a.db_type AS old_dbt, b.db_type AS new_dbt
        FROM dim.dim_attr_schema a
        JOIN dim.dim_attr_schema b
          ON a.l1_code=b.l1_code AND a.scope_level=b.scope_level AND a.scope_code=b.scope_code
        WHERE a.std_attr_code=%s AND b.std_attr_code=%s
    """, (old, new))
    for r in c.fetchall():
        same = (r["old_cn"] == r["new_cn"]) and (r["old_unit"] == r["new_unit"]) and (r["old_dbt"] == r["new_dbt"])
        print(f"    l1={r['l1_code']:20s} {r['scope_level']:6s} {str(r['scope_code']):24s}")
        print(f"      old_cn={r['old_cn']}  new_cn={r['new_cn']}  unit={r['old_unit']}/{r['new_unit']}  dbt={r['old_dbt']}/{r['new_dbt']}  {'同=>删old' if same else '异=>需人工'}")

c.close(); conn.close()
