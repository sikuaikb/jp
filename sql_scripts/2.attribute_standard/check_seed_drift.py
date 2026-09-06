"""检测本地 seed CSV 与 prod dim 表的漂移。

用途：
  sync_*.sh 在 DROP+CREATE+INSERT 之前应先跑此工具，避免覆盖 prod 上的手动改动。
  也可独立运行检查 CI / 日常运维。

用法：
  python3 sql_scripts/2.attribute_standard/check_seed_drift.py --db dim
  python3 sql_scripts/2.attribute_standard/check_seed_drift.py --db dim --strict   # 有差异则 exit 1
  python3 sql_scripts/2.attribute_standard/check_seed_drift.py --db dim --table dim_attr_schema  # 仅检查一张表

环境变量：MYSQL_HOST / MYSQL_PORT / MYSQL_USER / MYSQL_PASSWORD

输出：
  ✓  本地 CSV 与 DB 完全一致
  +N rows ONLY IN CSV    本地新增，sync 会插入
  -N rows ONLY IN DB     prod 有但本地无；sync 会丢失！⚠️ (需 review 是否手动改了 prod)
  ~N rows CHANGED        同 PK 但内容不同；sync 会覆盖
"""
from __future__ import annotations
import argparse
import csv
import json
import os
import sys
from pathlib import Path

import pymysql

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent  # 仓库根目录，HERE 是 sql_scripts/2.attribute_standard/

# 各表的 PK + 字段定义（与 load_seed.py 中表规范保持一致）
TABLE_SPECS = {
    "dim_attr_schema": {
        "csv": "sql_scripts/2.attribute_standard/seed/dim_attr_schema.csv",
        "pk": ["schema_version", "l1_code", "scope_level", "scope_code", "std_attr_code"],
    },
    "dim_attr_extract_rule": {
        "csv": "sql_scripts/2.attribute_standard/seed/dim_attr_extract_rule.csv",
        "pk": ["extract_rule_id"],
        "json_cols": ["value_map"],
    },
    "dim_unit_factor": {
        "csv": "sql_scripts/2.attribute_standard/seed/dim_unit_factor.csv",
        "pk": ["target_unit", "unit_raw"],
    },
    "dim_l3_classify": {
        "csv": "sql_scripts/1.classify/seed/dim_l3_classify.csv",
        "pk": ["l3_id"],
    },
    "dim_l3_classify_rule": {
        "csv": "sql_scripts/1.classify/seed/dim_l3_classify_rule.csv",
        "pk": ["rule_id", "clause_group_id", "clause_ord"],
    },
}


def norm(v):
    """规范化值用于比较：None / 空串视为相同；保持字符串原样（不做数值化避免破坏 '050101' 这类 PK）。
    数值类型保留 12 位有效数字以避免精度损失（0.0009765625 不被截成 0.000976562）。
    """
    if v is None:
        return ""
    if isinstance(v, bool):
        return "1" if v else "0"
    if isinstance(v, int):
        return str(v)
    if isinstance(v, float):
        return str(int(v)) if v == int(v) else f"{v:.12g}"
    from decimal import Decimal
    if isinstance(v, Decimal):
        f = float(v)
        return str(int(f)) if f == int(f) else f"{f:.12g}"
    return str(v).strip()


def num_eq(a: str, b: str) -> bool:
    """数值近似相等（rel_tol=1e-6 + abs_tol=1e-9，覆盖 0.000976562 vs 0.0009765625 这种精度差异）。"""
    if a == b:
        return True
    try:
        import math
        fa = float(a); fb = float(b)
        return math.isclose(fa, fb, rel_tol=1e-6, abs_tol=1e-9)
    except (ValueError, TypeError):
        return False


def load_csv(csv_path: Path) -> tuple[list[str], dict[tuple, dict]]:
    """读 CSV 返回 (fieldnames, {pk_tuple: row_dict})"""
    rows = {}
    with csv_path.open(encoding="utf-8") as fh:
        reader = csv.DictReader(fh)
        fields = list(reader.fieldnames)
        for r in reader:
            rows[None] = r  # placeholder
            del rows[None]
            yield_row = {k: norm(v) for k, v in r.items()}
            rows[id(r)] = yield_row  # 临时
            del rows[id(r)]
            rows.setdefault("_data", []).append(yield_row)
    return fields, rows.get("_data", [])


def load_db(cur, db: str, table: str) -> tuple[list[str], list[dict]]:
    """读 DB 表返回 (字段列表, [row_dict])。把 JSON 列也转字符串便于比较。"""
    cur.execute(f"DESC {db}.{table}")
    fields = [r[0] for r in cur.fetchall()]
    cur.execute(f"SELECT * FROM {db}.{table}")
    rows = []
    for r in cur.fetchall():
        row = {}
        for i, f in enumerate(fields):
            v = r[i]
            if v is None:
                row[f] = ""
            elif isinstance(v, (int, float)):
                row[f] = str(v) if not isinstance(v, float) or v != int(v) else str(int(v))
            elif hasattr(v, 'isoformat'):
                row[f] = v.isoformat()
            else:
                row[f] = str(v).strip()
        rows.append(row)
    return fields, rows


def diff_table(csv_fields, csv_rows, db_fields, db_rows, pk_cols, ignore_cols=("create_at", "update_at")):
    """返回 (only_csv, only_db, changed) — 每个是 [(pk_tuple, row_or_diff_dict)] 列表"""
    common_cols = [c for c in csv_fields if c in db_fields and c not in ignore_cols]

    def key(r):
        return tuple(r.get(c, "") for c in pk_cols)

    csv_map = {key(r): r for r in csv_rows}
    db_map = {key(r): r for r in db_rows}

    csv_keys = set(csv_map.keys())
    db_keys = set(db_map.keys())

    only_csv = [(k, csv_map[k]) for k in sorted(csv_keys - db_keys, key=str)]
    only_db = [(k, db_map[k]) for k in sorted(db_keys - csv_keys, key=str)]

    changed = []
    for k in sorted(csv_keys & db_keys, key=str):
        c_row = csv_map[k]
        d_row = db_map[k]
        diffs = {}
        for col in common_cols:
            cv = c_row.get(col, "")
            dv = d_row.get(col, "")
            if cv != dv:
                # 数值列：'0.92' == '0.9200'
                if num_eq(cv, dv):
                    continue
                # JSON 列比语义
                if col in ("value_map", "match_values", "match_map"):
                    try:
                        if cv and dv:
                            if json.loads(cv) == json.loads(dv):
                                continue
                    except Exception:
                        pass
                diffs[col] = (cv[:60], dv[:60])
        if diffs:
            changed.append((k, diffs))
    return only_csv, only_db, changed


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--db", required=True, help="dim | test_dim")
    ap.add_argument("--table", default=None, help="单张表名，默认全部")
    ap.add_argument("--strict", action="store_true", help="有差异则 exit 1")
    ap.add_argument("--limit", type=int, default=10, help="每类差异最多打印条数")
    args = ap.parse_args()

    for var in ("MYSQL_HOST", "MYSQL_USER", "MYSQL_PASSWORD"):
        if not os.environ.get(var):
            print(f"ERROR: env {var} not set", file=sys.stderr)
            sys.exit(2)

    conn = pymysql.connect(
        host=os.environ["MYSQL_HOST"], port=int(os.environ.get("MYSQL_PORT", "9030")),
        user=os.environ["MYSQL_USER"], password=os.environ["MYSQL_PASSWORD"],
        charset="utf8mb4",
    )

    tables = [args.table] if args.table else list(TABLE_SPECS.keys())
    total_drift = 0

    with conn.cursor() as cur:
        for tname in tables:
            spec = TABLE_SPECS.get(tname)
            if not spec:
                print(f"  unknown table: {tname}", file=sys.stderr)
                continue

            csv_path = ROOT / spec["csv"]
            if not csv_path.exists():
                print(f"  CSV missing: {csv_path}")
                continue

            with csv_path.open(encoding="utf-8") as fh:
                reader = csv.DictReader(fh)
                csv_fields = list(reader.fieldnames)
                csv_rows = [{k: norm(v) for k, v in r.items()} for r in reader]

            try:
                db_fields, db_rows = load_db(cur, args.db, tname)
            except Exception as e:
                print(f"\n== {tname} ==\n  ✗ DB error: {e}")
                continue

            only_csv, only_db, changed = diff_table(csv_fields, csv_rows, db_fields, db_rows, spec["pk"])

            print(f"\n== {args.db}.{tname} ==")
            print(f"  CSV: {len(csv_rows)} rows, DB: {len(db_rows)} rows")

            if not (only_csv or only_db or changed):
                print(f"  ✓ in sync")
                continue

            total_drift += len(only_csv) + len(only_db) + len(changed)

            if only_csv:
                print(f"  +{len(only_csv)} rows ONLY IN CSV  (sync 将插入)")
                for k, _ in only_csv[:args.limit]:
                    print(f"      + {k}")
                if len(only_csv) > args.limit:
                    print(f"      ... and {len(only_csv) - args.limit} more")

            if only_db:
                print(f"  -{len(only_db)} rows ONLY IN DB   ⚠️  (sync 将丢失！可能 prod 手动修改)")
                for k, _ in only_db[:args.limit]:
                    print(f"      - {k}")
                if len(only_db) > args.limit:
                    print(f"      ... and {len(only_db) - args.limit} more")

            if changed:
                print(f"  ~{len(changed)} rows CHANGED       (sync 将覆盖)")
                for k, diffs in changed[:args.limit]:
                    print(f"      ~ {k}")
                    for col, (cv, dv) in list(diffs.items())[:3]:
                        print(f"          {col}: CSV={cv!r}  DB={dv!r}")
                if len(changed) > args.limit:
                    print(f"      ... and {len(changed) - args.limit} more")

    print()
    if total_drift == 0:
        print("✅ All in sync.")
        sys.exit(0)
    else:
        print(f"⚠️  Total drift: {total_drift} rows across tables.")
        if args.strict:
            sys.exit(1)
        sys.exit(0)


if __name__ == "__main__":
    main()
