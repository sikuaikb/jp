#!/usr/bin/env python3
"""dim.dim_attr_extract_rule 改名冲突探查：同 (l1,scope,source_kind,source_expr)
是否同时有 old 与 new 两条规则 -> 重复(删old)；否则独立(改名)。"""
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

for old, new in ALIAS.items():
    print(f"\n=== {old} -> {new} (dim_attr_extract_rule) ===")
    c.execute("SELECT COUNT(*) n FROM dim.dim_attr_extract_rule WHERE std_attr_code=%s", (old,))
    oldn = c.fetchone()["n"]
    c.execute("SELECT COUNT(*) n FROM dim.dim_attr_extract_rule WHERE std_attr_code=%s", (new,))
    newn = c.fetchone()["n"]
    print(f"  old 规则={oldn}  new 规则={newn}")
    if oldn == 0:
        print("  无 old 规则，跳过")
        continue
    # 同 (l1,scope_level,scope_code,source_kind,source_expr) 重叠
    c.execute("""
        SELECT COUNT(*) overlap FROM (
          SELECT l1_code, apply_scope_level, apply_scope_code, source_kind, source_expr
          FROM dim.dim_attr_extract_rule WHERE std_attr_code=%s
          INTERSECT
          SELECT l1_code, apply_scope_level, apply_scope_code, source_kind, source_expr
          FROM dim.dim_attr_extract_rule WHERE std_attr_code=%s
        ) x
    """, (old, new))
    ov = c.fetchone()["overlap"]
    print(f"  同 source 重叠规则数: {ov}  {'=> 删 old 重复规则' if ov else '=> 全部改名 old->new'}")
    # 展示 old 规则样例
    c.execute("""
        SELECT extract_rule_id, l1_code, apply_scope_level, apply_scope_code,
               source_kind, substr(source_expr,1,40) se, enabled
        FROM dim.dim_attr_extract_rule WHERE std_attr_code=%s LIMIT 5
    """, (old,))
    for r in c.fetchall():
        print(f"    {str(r['extract_rule_id']):30s} {str(r['l1_code']):16s} {str(r['apply_scope_level']):5s} {str(r['apply_scope_code']):20s} {str(r['source_kind']):8s} {str(r['se']):40s} en={r['enabled']}")

c.close(); conn.close()
