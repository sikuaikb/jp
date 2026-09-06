"""Repair dim_brand_origin schema + purge orphans (StarRocks-safe).

Why not pure SQL DELETE JOIN / NOT IN (SELECT):
  - StarRocks rejects those DELETE forms
  - test_dim.dim_brand_origin was wrongly created as DUPLICATE KEY
    (CREATE IF NOT EXISTS never fixed it), so DELETE is unreliable there

Actions per schema:
  1. If table is not PRIMARY KEY(brand_id_std) → rebuild from live rows
  2. Else DELETE orphans via WHERE brand_id_std IN (literal ids)

Usage:
  python sql_scripts/test/_repair_brand_origin.py test
  ALLOW_PROD=1 python sql_scripts/test/_repair_brand_origin.py prod
  python sql_scripts/test/_repair_brand_origin.py both
"""
from __future__ import annotations

import os
import sys
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")
ROOT = Path(__file__).resolve().parents[1]
for line in (ROOT / "local.env").read_text(encoding="utf-8").splitlines():
    if line.strip().startswith("export "):
        k, _, v = line[7:].partition("=")
        os.environ.setdefault(k, v.strip().strip("'").strip('"'))

import pymysql

PK_DDL = """
CREATE TABLE {db}.dim_brand_origin (
    `brand_id_std`     BIGINT       NOT NULL COMMENT '品牌主键，关联 dim_std_brand',
    `country_region`   VARCHAR(8)   NULL COMMENT '品牌起源地ISO码',
    `is_domestic`      TINYINT      NULL COMMENT '1=中国资本/品牌 0=海外 NULL未定',
    `domestic_type`    VARCHAR(20)  NULL COMMENT 'mainland_native/mainland_acquired/taiwan/hk_mo/overseas',
    `update_at`        DATETIME     NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=OLAP
PRIMARY KEY(`brand_id_std`)
COMMENT '品牌产地维度（独立持久，sync 后 JOIN 回写 dim_std_brand）'
DISTRIBUTED BY HASH(`brand_id_std`) BUCKETS 4
PROPERTIES ("replication_num"="1", "enable_persistent_index"="true")
"""


def connect():
    return pymysql.connect(
        host=os.environ.get("MYSQL_HOST", "192.168.19.21"),
        port=int(os.environ.get("MYSQL_PORT", "9030")),
        user=os.environ.get("MYSQL_USER", "root"),
        password=os.environ["MYSQL_PASSWORD"],
        charset="utf8mb4",
        cursorclass=pymysql.cursors.DictCursor,
        autocommit=True,
    )


def is_primary_key(cur, db: str) -> bool:
    cur.execute(f"SHOW CREATE TABLE {db}.dim_brand_origin")
    ddl = cur.fetchone()["Create Table"]
    return "PRIMARY KEY(`brand_id_std`)" in ddl or "PRIMARY KEY(`brand_id_std`)" in ddl.replace(" ", "")


def fetch_live_origins(cur, db: str) -> list[dict]:
    """Deduped live origin rows (brand still exists)."""
    cur.execute(
        f"""
        SELECT o.brand_id_std, o.country_region, o.is_domestic, o.domestic_type, o.update_at
        FROM {db}.dim_brand_origin o
        INNER JOIN {db}.dim_std_brand b ON b.brand_id_std = o.brand_id_std
        """
    )
    rows = cur.fetchall()
    best: dict[int, dict] = {}
    for r in rows:
        bid = r["brand_id_std"]
        prev = best.get(bid)
        if prev is None:
            best[bid] = r
            continue
        # prefer row with non-null country; then later update_at
        def score(x):
            return (
                1 if x.get("country_region") else 0,
                str(x.get("update_at") or ""),
            )
        if score(r) >= score(prev):
            best[bid] = r
    return list(best.values())


def fetch_orphan_ids(cur, db: str) -> list[int]:
    cur.execute(
        f"""
        SELECT o.brand_id_std
        FROM {db}.dim_brand_origin o
        LEFT JOIN {db}.dim_std_brand b ON b.brand_id_std = o.brand_id_std
        WHERE b.brand_id_std IS NULL
        """
    )
    return [r["brand_id_std"] for r in cur.fetchall()]


def insert_rows(cur, db: str, rows: list[dict]) -> None:
    if not rows:
        return
    # batch insert
    batch = 200
    for i in range(0, len(rows), batch):
        chunk = rows[i : i + batch]
        vals = []
        for r in chunk:
            cr = r.get("country_region")
            cr_sql = "NULL" if cr is None else f"'{str(cr).replace(chr(39), chr(39)+chr(39))}'"
            dt = r.get("domestic_type")
            dt_sql = "NULL" if dt is None else f"'{str(dt).replace(chr(39), chr(39)+chr(39))}'"
            dom = r.get("is_domestic")
            dom_sql = "NULL" if dom is None else str(int(dom))
            ua = r.get("update_at")
            ua_sql = "CURRENT_TIMESTAMP()" if ua is None else f"'{ua}'"
            vals.append(f"({r['brand_id_std']}, {cr_sql}, {dom_sql}, {dt_sql}, {ua_sql})")
        cur.execute(
            f"INSERT INTO {db}.dim_brand_origin "
            f"(brand_id_std, country_region, is_domestic, domestic_type, update_at) VALUES "
            + ", ".join(vals)
        )


def rebuild_pk(cur, db: str) -> None:
    live = fetch_live_origins(cur, db)
    print(f"  [{db}] rebuild PRIMARY KEY; keep live rows={len(live)}")
    cur.execute(f"DROP TABLE IF EXISTS {db}.dim_brand_origin")
    cur.execute(PK_DDL.format(db=db))
    insert_rows(cur, db, live)


def delete_orphans_pk(cur, db: str) -> int:
    ids = fetch_orphan_ids(cur, db)
    if not ids:
        print(f"  [{db}] orphans=0")
        return 0
    # chunk IN lists
    n = 0
    for i in range(0, len(ids), 200):
        chunk = ids[i : i + 200]
        cur.execute(
            f"DELETE FROM {db}.dim_brand_origin WHERE brand_id_std IN "
            f"({','.join(str(x) for x in chunk)})"
        )
        n += len(chunk)
    print(f"  [{db}] deleted orphans={n}")
    return n


def repair(db: str) -> None:
    conn = connect()
    cur = conn.cursor()
    cur.execute(
        f"SELECT COUNT(*) c FROM information_schema.tables "
        f"WHERE table_schema=%s AND table_name='dim_brand_origin'",
        (db,),
    )
    if cur.fetchone()["c"] == 0:
        print(f"  [{db}] table missing → create PK")
        cur.execute(PK_DDL.format(db=db))
        conn.close()
        return

    pk = is_primary_key(cur, db)
    cur.execute(f"SELECT COUNT(*) c FROM {db}.dim_brand_origin")
    before = cur.fetchone()["c"]
    orphans_before = len(fetch_orphan_ids(cur, db))
    print(f"  [{db}] rows={before} orphans={orphans_before} primary_key={pk}")

    if not pk:
        rebuild_pk(cur, db)
    else:
        delete_orphans_pk(cur, db)

    cur.execute(f"SELECT COUNT(*) c FROM {db}.dim_brand_origin")
    after = cur.fetchone()["c"]
    orphans_after = len(fetch_orphan_ids(cur, db))
    print(f"  [{db}] after rows={after} orphans={orphans_after}")
    conn.close()


def main() -> None:
    target = (sys.argv[1] if len(sys.argv) > 1 else "test").lower()
    dbs = []
    if target == "test":
        dbs = ["test_dim"]
    elif target == "prod":
        if os.environ.get("ALLOW_PROD") != "1":
            print("需要 ALLOW_PROD=1", file=sys.stderr)
            sys.exit(1)
        dbs = ["dim"]
    elif target == "both":
        dbs = ["test_dim"]
        if os.environ.get("ALLOW_PROD") == "1":
            dbs.append("dim")
        else:
            print("WARN: both 未带 ALLOW_PROD=1，只修 test_dim")
    else:
        print("usage: _repair_brand_origin.py test|prod|both", file=sys.stderr)
        sys.exit(2)

    for db in dbs:
        print(f"==> repair {db}")
        repair(db)
    print("Done.")


if __name__ == "__main__":
    main()
