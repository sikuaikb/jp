"""反向同步：把 DB 数据 pull 回本地 CSV，与本地保持一致。

两个模式：
  默认（append）：仅把 only_in_db 的行追加到 CSV 末尾。本机已有的行不动。
  --reconcile  ：完整 reconcile —— 以 DB 为基础全量同步，本地独有的新增保留。
                 即：新 CSV = (DB 全量按 PK dedup keep-last) ∪ (本机 only_in_csv)
                 用于"先同步 prod 再合并本机新增"场景。

用法：
  python3 pull_seed_drift.py --db dim --dry-run                # 看变更
  python3 pull_seed_drift.py --db dim                          # append 模式
  python3 pull_seed_drift.py --db dim --reconcile              # 全量同步（推荐）
  python3 pull_seed_drift.py --db dim --reconcile --table dim_l3_classify_rule

场景：
  - 同事在 prod 直接加了行（dsp/transistor 等），CSV 还没同步
  - 本机也有未提交的新增（如 DigiKey 规则）
  - 用 --reconcile：拉 prod 全量 + 保留本机独有 → CSV 与 prod 对齐 + 不丢本机新增
"""
from __future__ import annotations
import argparse
import csv
import os
import sys
from pathlib import Path

import pymysql

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent

# 复用 check_seed_drift 的表规范
sys.path.insert(0, str(HERE))
from check_seed_drift import TABLE_SPECS, norm  # type: ignore


def db_row_to_dict(r, db_field_names, csv_fields):
    """把 DB 一行转换为 CSV 友好的 dict（只保留 CSV 字段，类型规范化）。"""
    from decimal import Decimal
    out = {}
    for i, fname in enumerate(db_field_names):
        v = r[i]
        if v is None:
            s = ""
        elif isinstance(v, bool):
            s = "1" if v else "0"
        elif isinstance(v, int):
            s = str(v)
        elif isinstance(v, float):
            s = str(int(v)) if v == int(v) else f"{v:.12g}"
        elif isinstance(v, Decimal):
            f = float(v)
            s = str(int(f)) if f == int(f) else f"{f:.12g}"
        elif hasattr(v, "isoformat"):
            s = ""  # 时间字段不入 CSV
        else:
            s = str(v).strip()
        out[fname] = s
    # 只保留 CSV 中存在的字段；CSV 多出的字段（如 data_source / value_map / source_value_regex）填空
    return {f: out.get(f, "") for f in csv_fields}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--db", required=True)
    ap.add_argument("--table", default=None)
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--reconcile", action="store_true",
                    help="完整 reconcile：以 DB 为基础全量同步，保留本机独有 only_in_csv")
    args = ap.parse_args()

    for var in ("MYSQL_HOST", "MYSQL_USER", "MYSQL_PASSWORD"):
        if not os.environ.get(var):
            print(f"ERROR: env {var} not set", file=sys.stderr); sys.exit(2)

    conn = pymysql.connect(
        host=os.environ["MYSQL_HOST"], port=int(os.environ.get("MYSQL_PORT", "9030")),
        user=os.environ["MYSQL_USER"], password=os.environ["MYSQL_PASSWORD"],
        charset="utf8mb4",
    )

    tables = [args.table] if args.table else list(TABLE_SPECS.keys())
    total_pulled = 0

    with conn.cursor() as cur:
        for tname in tables:
            spec = TABLE_SPECS[tname]
            csv_path = ROOT / spec["csv"]

            # 读 CSV
            with csv_path.open(encoding="utf-8") as fh:
                reader = csv.DictReader(fh)
                csv_fields = list(reader.fieldnames)
                csv_rows = list(reader)
            csv_keys = set(tuple(norm(r.get(c, "")) for c in spec["pk"]) for r in csv_rows)

            # 读 DB
            cur.execute(f"DESC {args.db}.{tname}")
            db_field_names = [r[0] for r in cur.fetchall()]
            cur.execute(f"SELECT {', '.join(db_field_names)} FROM {args.db}.{tname}")
            db_raw = cur.fetchall()
            db_rows_all = [db_row_to_dict(r, db_field_names, csv_fields) for r in db_raw]

            # === Reconcile 模式：以 DB 为基础全量同步 + 保留本机 only_in_csv ===
            if args.reconcile:
                # DB 行按 PK dedup keep-last
                db_by_pk = {}
                for r in db_rows_all:
                    k = tuple(r.get(c, "") for c in spec["pk"])
                    db_by_pk[k] = r
                db_keys = set(db_by_pk.keys())

                only_in_csv = [r for r in csv_rows if tuple(norm(r.get(c, "")) for c in spec["pk"]) not in db_keys]
                only_in_csv_clean = [{f: r.get(f, "") for f in csv_fields} for r in only_in_csv]

                final_rows = list(db_by_pk.values()) + only_in_csv_clean

                print(f"== {tname} ==  reconcile:")
                print(f"   DB rows (dedup):        {len(db_by_pk):>5}")
                print(f"   + only_in_csv kept:     {len(only_in_csv_clean):>5}  (本机独有保留)")
                print(f"   = final CSV size:       {len(final_rows):>5}")
                if only_in_csv_clean[:5]:
                    print(f"   样本 only_in_csv:")
                    for r in only_in_csv_clean[:5]:
                        pk_vals = " | ".join(str(r.get(c, "")) for c in spec["pk"])
                        print(f"      kept: {pk_vals}")

                if not args.dry_run:
                    with csv_path.open("w", newline="", encoding="utf-8") as fh:
                        w = csv.DictWriter(fh, fieldnames=csv_fields, quoting=csv.QUOTE_MINIMAL)
                        w.writeheader()
                        for r in final_rows: w.writerow(r)
                    print(f"   ✓ rewrote {csv_path}")
                    total_pulled += len(db_by_pk)
                continue

            # === 默认 append 模式：仅追加 only_in_db ===
            new_rows = [r for r in db_rows_all
                        if tuple(r.get(c, "") for c in spec["pk"]) not in csv_keys]

            if not new_rows:
                print(f"== {tname} ==  ✓ no rows to pull")
                continue

            print(f"== {tname} ==  will append {len(new_rows)} rows from {args.db}")
            for nr in new_rows[:5]:
                pk_vals = " | ".join(str(nr.get(c, "")) for c in spec["pk"])
                print(f"   + {pk_vals}")
            if len(new_rows) > 5:
                print(f"   ... and {len(new_rows)-5} more")

            if not args.dry_run:
                with csv_path.open("a", newline="", encoding="utf-8") as fh:
                    w = csv.DictWriter(fh, fieldnames=csv_fields, quoting=csv.QUOTE_MINIMAL)
                    for nr in new_rows:
                        w.writerow(nr)
                print(f"   ✓ appended to {csv_path}")
                total_pulled += len(new_rows)

    if args.dry_run:
        print(f"\n--dry-run: 未实际写入。去掉 --dry-run 后会写。")
    else:
        print(f"\n✓ Total pulled: {total_pulled} rows")
        print(f"  Next steps: git diff / git add / git commit / git push")


if __name__ == "__main__":
    main()
