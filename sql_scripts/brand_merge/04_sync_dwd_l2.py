#!/usr/bin/env python3
"""下游同步：把所有 dwd.dwd_l2_* 宽表（含 component_catalog）里残留的
merge_id remap 成 keep_id，并把 brand 文本统一成 keeper 的 name。

以 dim.dim_brand_merge_map 为准；keeper name 实时从 dim.dim_std_brand 读取
（因此需在 03_merge_dim.py 执行之后再跑，确保 Bel Fuse 已重命名）。

用法：
    python 04_sync_dwd_l2.py            # dry-run：只统计每表受影响行数
    python 04_sync_dwd_l2.py --apply    # 执行 UPDATE
"""
from __future__ import annotations
import os, sys
from pathlib import Path
import pymysql

sys.stdout.reconfigure(encoding="utf-8")
APPLY = "--apply" in sys.argv

ENV = Path(__file__).resolve().parents[1] / "local.env"
for line in ENV.read_text(encoding="utf-8").splitlines():
    if line.strip().startswith("export "):
        k, _, v = line[7:].partition("=")
        os.environ[k] = v.strip().strip("'").strip('"')

conn = pymysql.connect(
    host=os.environ["MYSQL_HOST"], port=int(os.environ.get("MYSQL_PORT", "9030")),
    user=os.environ["MYSQL_USER"], password=os.environ["MYSQL_PASSWORD"],
    charset="utf8mb4", cursorclass=pymysql.cursors.DictCursor,
)
cur = conn.cursor()

cur.execute("SELECT keep_id, merge_id FROM dim.dim_brand_merge_map")
pairs = [(r["keep_id"], r["merge_id"]) for r in cur.fetchall()]
merge_ids = [m for _, m in pairs]
keep_ids = list({k for k, _ in pairs})

# keeper 可读名（写入宽表 brand 列）
cur.execute(
    f"SELECT brand_id_std, name FROM dim.dim_std_brand "
    f"WHERE brand_id_std IN ({','.join(str(x) for x in keep_ids)})"
)
keep_name = {r["brand_id_std"]: r["name"] for r in cur.fetchall()}

# 找所有含 brandid 的 dwd_l2_* 表
cur.execute(
    """
    SELECT DISTINCT t.table_name FROM information_schema.tables t
    JOIN information_schema.columns c
      ON c.table_schema=t.table_schema AND c.table_name=t.table_name
    WHERE t.table_schema='dwd' AND t.table_name LIKE 'dwd_l2_%' AND c.column_name='brandid'
    ORDER BY t.table_name
    """
)
tables = [r["table_name"] for r in cur.fetchall()]
merge_list = ",".join(str(x) for x in merge_ids)

print(f"=== 扫描 {len(tables)} 张 dwd_l2_* 表（含 brandid）===")
total = 0
affected = []
for tn in tables:
    cur.execute(f"SELECT COUNT(*) c FROM dwd.{tn} WHERE brandid IN ({merge_list})")
    c = cur.fetchone()["c"]
    if c:
        affected.append((tn, c))
        total += c
for tn, c in sorted(affected, key=lambda x: -x[1]):
    print(f"  {c:>7,}  {tn}")
print(f"\n受影响表 {len(affected)} 张，受影响行合计 {total:,}（含 catalog 镜像）")

if not APPLY:
    print("\n[DRY-RUN] 未写库。加 --apply 执行 UPDATE。")
    conn.close()
    sys.exit(0)

print("\n[APPLY] 开始执行 UPDATE …")
changed = 0
for tn, _ in affected:
    for keep_id, merge_id in pairs:
        nm = (keep_name.get(keep_id) or "").replace("'", "''")
        cur.execute(
            f"UPDATE dwd.{tn} SET brandid = {keep_id}, brand = '{nm}' "
            f"WHERE brandid = {merge_id}"
        )
        changed += cur.rowcount if cur.rowcount and cur.rowcount > 0 else 0
    conn.commit()
    print(f"  done {tn}")
print(f"\n[APPLY] 完成。累计影响约 {changed:,} 行（按 rowcount 估计）。")

# 终检：残留
cur.execute("SELECT 1")
residual = 0
for tn, _ in affected:
    cur.execute(f"SELECT COUNT(*) c FROM dwd.{tn} WHERE brandid IN ({merge_list})")
    residual += cur.fetchone()["c"]
print(f"终检：受影响表里仍残留 merge_id 的行数 = {residual}（应为 0）")

conn.close()
