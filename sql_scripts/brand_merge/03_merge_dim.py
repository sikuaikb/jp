#!/usr/bin/env python3
"""dim 层合并：以 dim.dim_brand_merge_map 为准。

1) 把每个 merge 记录的 name/abbr/related_words 并入对应 keep 记录的 related_words；
2) merge 记录 state 置 0（软删，保留可追溯，配合视图 state=1 过滤后不再参与映射）；
3) Bel Fuse keeper 重命名为 'Bel Fuse'（原 name 是小写 belfuse）；
4) 清理 4.3 脏别名：中环-Central / 光颖-Viking 的污染 related_words。
5) 产地表迁移：dim.dim_brand_origin 里 merge_id 的产地迁到 keep_id（keep 优先）。

幂等：可重复执行（union 去重、state=0 重复设置、移除别名重复执行均无副作用）。
用法：
    python 03_merge_dim.py            # 预览（不写库）
    python 03_merge_dim.py --apply    # 真正执行
"""
from __future__ import annotations
import os, sys, json
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

# 4.3 脏别名清理（brand_id -> 需移除的 related_words，大写比较）
DIRTY = {
    1443490693442801674: ["CENTRAL SEMICONDUCTOR CORP", "CENTRAL SEMICONDUCTOR"],  # 中环-Central
    1443490691173683207: ["VIKINGTECHNOLOGY"],                                     # 光颖-Viking
    1443490693316972553: ["TOPPOWER(顶源)", "顶源"],                                # 南京拓微-TOPPOWER 脏别名(顶源是不同公司)
    # clock_timing 核实 20260710：stage25 误挂，LSI≠华新科 / PULSECORE≠PULSE Electronics
    1443490691173683201: ["LSI"],                                                  # 华新科-Walsin 脏别名
    1443490692796878855: ["PULSECORE"],                                            # PULSE 脏别名
}
BELFUSE_KEEP = 1443490694885642242  # 重命名为 'Bel Fuse'


def arr_literal(vals: list[str]) -> str:
    parts = ["'" + v.replace("'", "''") + "'" for v in vals]
    return "[" + ",".join(parts) + "]"


def as_list(v) -> list[str]:
    """StarRocks array<varchar> 经 MySQL 协议返回为 JSON 字符串，需解析为 list。"""
    if v is None:
        return []
    if isinstance(v, list):
        return v
    if isinstance(v, str):
        try:
            r = json.loads(v)
            return r if isinstance(r, list) else [v]
        except Exception:
            return [v]
    return []


def dedup_ci(items: list[str]) -> list[str]:
    seen, out = set(), []
    for x in items:
        x = (x or "").strip()
        if not x:
            continue
        k = x.upper()
        if k not in seen:
            seen.add(k)
            out.append(x)
    return out


cur.execute("SELECT keep_id, merge_id FROM dim.dim_brand_merge_map")
pairs = cur.fetchall()
keep_to_merges: dict[int, list[int]] = {}
for r in pairs:
    keep_to_merges.setdefault(r["keep_id"], []).append(r["merge_id"])
all_ids = list({r["keep_id"] for r in pairs} | {r["merge_id"] for r in pairs})

idlist = ",".join(str(x) for x in all_ids)
cur.execute(
    f"SELECT brand_id_std, name, abbr, related_words FROM dim.dim_std_brand "
    f"WHERE brand_id_std IN ({idlist})"
)
rec = {r["brand_id_std"]: r for r in cur.fetchall()}

stmts: list[str] = []

# 1+2) 别名归并 + merge 软删
for keep_id, merges in sorted(keep_to_merges.items()):
    k = rec.get(keep_id)
    if not k:
        print(f"[WARN] keeper 缺失 {keep_id}，跳过")
        continue
    combined = as_list(k["related_words"])
    combined += [k["name"], k["abbr"]]
    for m in merges:
        mr = rec.get(m)
        if not mr:
            print(f"[WARN] merge 缺失 {m}，跳过")
            continue
        combined += as_list(mr["related_words"])
        combined += [mr["name"], mr["abbr"]]
    new_rw = dedup_ci(combined)
    stmts.append(
        f"UPDATE dim.dim_std_brand SET related_words = {arr_literal(new_rw)} "
        f"WHERE brand_id_std = {keep_id};"
    )
    valid_merges = [m for m in merges if m in rec]
    if valid_merges:
        stmts.append(
            f"UPDATE dim.dim_std_brand SET state = 0 "
            f"WHERE brand_id_std IN ({','.join(str(m) for m in valid_merges)});"
        )

# 3) Bel Fuse keeper 重命名
if BELFUSE_KEEP in rec:
    stmts.append(
        f"UPDATE dim.dim_std_brand SET name = 'Bel Fuse', brand_en = 'Bel Fuse' "
        f"WHERE brand_id_std = {BELFUSE_KEEP};"
    )

# 4) 4.3 脏别名清理
cur.execute(
    f"SELECT brand_id_std, related_words FROM dim.dim_std_brand "
    f"WHERE brand_id_std IN ({','.join(str(x) for x in DIRTY)})"
)
for r in cur.fetchall():
    bid = r["brand_id_std"]
    rm = {x.upper() for x in DIRTY[bid]}
    kept = [w for w in as_list(r["related_words"]) if (w or "").strip().upper() not in rm]
    stmts.append(
        f"UPDATE dim.dim_std_brand SET related_words = {arr_literal(kept)} "
        f"WHERE brand_id_std = {bid};"
    )

# 5) 产地表迁移：dim.dim_brand_origin 里 merge_id → keep_id（PK UPSERT 覆盖）
#    merge_id 有产地但 keep_id 没产地时，把产地迁到 keep_id；
#    merge_id 有产地且 keep_id 也有产地时，keep 优先（不覆盖）。
origin_migrated = 0
for keep_id, merges in sorted(keep_to_merges.items()):
    for m in merges:
        # 查 merge_id 是否在产地表有记录
        cur.execute(
            "SELECT country_region, is_domestic, domestic_type FROM dim.dim_brand_origin WHERE brand_id_std = %s",
            (m,)
        )
        m_row = cur.fetchone()
        if not m_row or m_row["country_region"] is None:
            continue
        # 查 keep_id 是否已有产地
        cur.execute(
            "SELECT country_region FROM dim.dim_brand_origin WHERE brand_id_std = %s",
            (keep_id,)
        )
        k_row = cur.fetchone()
        if k_row and k_row["country_region"] is not None:
            # keep 已有产地，保留 keep 的，删掉 merge 的产地行
            stmts.append(
                f"DELETE FROM dim.dim_brand_origin WHERE brand_id_std = {m};"
            )
        else:
            # keep 没产地，把 merge 的产地迁到 keep_id（UPSERT）
            cr = m_row["country_region"]
            isd = m_row["is_domestic"]
            dt = m_row["domestic_type"]
            stmts.append(
                f"INSERT INTO dim.dim_brand_origin (brand_id_std, country_region, is_domestic, domestic_type, update_at) "
                f"VALUES ({keep_id}, '{cr}', {isd}, '{dt}', CURRENT_TIMESTAMP());"
            )
            stmts.append(
                f"DELETE FROM dim.dim_brand_origin WHERE brand_id_std = {m};"
            )
        origin_migrated += 1
if origin_migrated:
    print(f"=== 产地迁移: {origin_migrated} 条 merge_id → keep_id ===")

print(f"=== 生成 {len(stmts)} 条 UPDATE ===")
for s in stmts:
    print("  " + (s[:160] + ("…" if len(s) > 160 else "")))

if APPLY:
    for s in stmts:
        cur.execute(s)
    conn.commit()
    print("\n[APPLY] 已执行并提交。")
else:
    print("\n[DRY-RUN] 未写库。加 --apply 执行。")

conn.close()
