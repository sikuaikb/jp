#!/usr/bin/env python3
"""诊断 test_dim 中 logic_ic 规则可见性。"""
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

print("=== test_dim 中含 logic_ic 的表 ===")
cur.execute("SHOW TABLES FROM test_dim")
tables = [list(r.values())[0] for r in cur.fetchall() if "logic" in list(r.values())[0].lower()]
for t in sorted(tables):
    print(f"  {t}")

print("\n=== test_dim.dim_l3_classify_rule_logic_ic ===")
cur.execute(
    """
    SELECT rule_kind, COUNT(*) AS rows_, COUNT(DISTINCT rule_id) AS rule_ids
    FROM test_dim.dim_l3_classify_rule_logic_ic
    GROUP BY rule_kind
    """
)
for r in cur.fetchall():
    print(f"  {r['rule_kind']}: {r['rows_']} rows, {r['rule_ids']} distinct rule_id")

print("\n  gate rule_id:")
cur.execute(
    """
    SELECT DISTINCT rule_id FROM test_dim.dim_l3_classify_rule_logic_ic
    WHERE rule_kind='gate' ORDER BY 1
    """
)
for r in cur.fetchall():
    print(f"    {r['rule_id']}")

print("\n  classify rule_id (前10):")
cur.execute(
    """
    SELECT DISTINCT rule_id FROM test_dim.dim_l3_classify_rule_logic_ic
    WHERE rule_kind='classify' ORDER BY 1 LIMIT 10
    """
)
for r in cur.fetchall():
    print(f"    {r['rule_id']}")
cur.execute(
    "SELECT COUNT(DISTINCT rule_id) n FROM test_dim.dim_l3_classify_rule_logic_ic WHERE rule_kind='classify'"
)
print(f"    ... 共 {cur.fetchone()['n']} 条 classify rule_id")

print("\n=== 共享表 test_dim.dim_l3_classify_rule（若只查这张会看不到 logic_ic 试点规则）===")
try:
    cur.execute(
        """
        SELECT COUNT(*) n FROM test_dim.dim_l3_classify_rule
        WHERE rule_id LIKE 'gate_logic_ic%' OR rule_id LIKE 'logic_dk%'
        """
    )
    n_shared = cur.fetchone()["n"]
    print(f"  logic_ic 相关规则行数: {n_shared}")
    cur.execute(
        """
        SELECT rule_kind, COUNT(*) n FROM test_dim.dim_l3_classify_rule
        WHERE rule_id LIKE 'gate_logic_ic%' OR rule_id LIKE 'logic_dk%'
        GROUP BY rule_kind
        """
    )
    print(f"  按 rule_kind: {cur.fetchall()}")
except Exception as e:
    print(f"  表不存在或不可查: {e}")

conn.close()
