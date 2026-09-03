#!/usr/bin/env python3
"""Step 9: DROP test_dim/test_dwd inductor 后缀表 + merge 表（需 ALLOW_PROD=1）"""
from __future__ import annotations

import os
import sys
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")

L1 = "inductor"
L2S = ["power_inductor", "hf_chip_inductor", "emi_filter_inductor"]

ENV = Path(__file__).resolve().parents[2] / "local.env"
for line in ENV.read_text(encoding="utf-8").splitlines():
    if line.strip().startswith("export "):
        k, _, v = line[7:].partition("=")
        os.environ[k] = v.strip().strip("'\"")

if os.environ.get("ALLOW_PROD") != "1":
    print("需要 ALLOW_PROD=1"); sys.exit(1)

import pymysql

conn = pymysql.connect(
    host=os.environ["MYSQL_HOST"], port=int(os.environ["MYSQL_PORT"]),
    user=os.environ["MYSQL_USER"], password=os.environ["MYSQL_PASSWORD"],
    charset="utf8mb4", autocommit=True,
)
cur = conn.cursor()

TABLES = [
    f"test_dim.dim_attr_schema_{L1}",
    f"test_dim.dim_attr_extract_rule_{L1}",
    f"test_dim.dim_l3_classify_{L1}",
    f"test_dim.dim_l3_classify_rule_{L1}",
    f"test_dwd.dwd_component_class_{L1}",
    f"test_dwd.dwd_component_class_merge_{L1}",
    f"test_dwd.dwd_component_attr_std_{L1}",
    f"test_dwd.dwd_component_attr_std_merge_{L1}",
]
for l2 in L2S:
    TABLES.append(f"test_dwd.dwd_l2_{L1}_{l2}_{L1}")  # 阶段1 双重后缀
    TABLES.append(f"test_dwd.dwd_l2_{L1}_{l2}_merge")

print("=== 清理前探测 ===")
existing = []
for t in TABLES:
    db, name = t.split(".", 1)
    cur.execute(f"SHOW TABLES FROM {db} LIKE %s", (name,))
    if cur.fetchone():
        existing.append(t)
        print(f"  存在: {t}")

if not existing:
    print("  (无待删表)")
    sys.exit(0)

print(f"\n=== DROP {len(existing)} 张表 ===")
for t in existing:
    cur.execute(f"DROP TABLE IF EXISTS {t}")
    print(f"  ✅ DROP {t}")

print("\n=== 清理后验证 ===")
left = 0
for t in TABLES:
    db, name = t.split(".", 1)
    cur.execute(f"SHOW TABLES FROM {db} LIKE %s", (name,))
    if cur.fetchone():
        print(f"  ❌ 仍在: {t}")
        left += 1
if left == 0:
    print("  ✅ 全部已删除")
else:
    sys.exit(1)

conn.close()
