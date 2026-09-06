"""把 test_dim 后缀表写入 seed CSV：替换旧 mcu/mpu/dsp，追加/覆盖 mcu_mpu_dsp。"""
from __future__ import annotations
import csv, json, os, sys
from pathlib import Path
sys.stdout.reconfigure(encoding="utf-8")

L1 = "mcu_mpu_dsp"
OLD_L1 = {"mcu", "mpu", "dsp"}
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
SEED = ROOT / "2.attribute_standard" / "seed"
ENV = ROOT / "local.env"

SCHEMA_COLS = [
    "schema_version", "l1_code", "scope_level", "scope_code", "std_attr_code",
    "std_attr_cn", "unit_std", "db_type", "precision", "value_domain",
    "min_bound", "max_bound", "is_l2_common", "display_ord",
    "attr_category_cn", "attr_category_en", "note",
]
RULE_COLS = [
    "extract_rule_id", "data_source", "schema_version", "l1_code",
    "apply_scope_level", "apply_scope_code",
    "std_attr_code", "source_kind", "source_expr",
    "source_value_expr", "source_value_regex", "literal_std_value",
    "priority", "enabled", "value_map", "note",
]
SCHEMA_PK = SCHEMA_COLS[:5]
RULE_PK = ["extract_rule_id"]

for line in ENV.read_text(encoding="utf-8").splitlines():
    if line.strip().startswith("export "):
        k, _, v = line[7:].partition("=")
        os.environ[k] = v.strip().strip("'").strip('"')

import pymysql
conn = pymysql.connect(
    host=os.environ["MYSQL_HOST"], port=int(os.environ.get("MYSQL_PORT", "9030")),
    user=os.environ["MYSQL_USER"], password=os.environ["MYSQL_PASSWORD"],
    charset="utf8mb4", cursorclass=pymysql.cursors.DictCursor,
)
cur = conn.cursor()

def cell(v):
    if v is None:
        return ""
    if isinstance(v, (dict, list)):
        return json.dumps(v, ensure_ascii=False)
    return str(v)

def fetch(table, cols):
    cur.execute(f"SELECT {', '.join(cols)} FROM {table}")
    return [dict(zip(cols, [cell(r[c]) for c in cols])) for r in cur.fetchall()]

def merge_csv(path: Path, cols, pk_cols, new_rows, drop_l1: set[str]):
    kept = []
    if path.exists():
        with path.open(encoding="utf-8", newline="") as fh:
            for row in csv.DictReader(fh):
                if row.get("l1_code") in drop_l1:
                    continue
                kept.append({c: row.get(c, "") for c in cols})
    new_map = {tuple(r[c] for c in pk_cols): r for r in new_rows}
    out, seen = [], set()
    for row in kept:
        k = tuple(row[c] for c in pk_cols)
        if k in new_map:
            out.append(new_map[k])
            seen.add(k)
        else:
            out.append(row)
    for k, row in new_map.items():
        if k not in seen:
            out.append(row)
    with path.open("w", encoding="utf-8", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=cols, quoting=csv.QUOTE_MINIMAL)
        w.writeheader()
        w.writerows(out)
    print(f"  {path.name}: kept-after-drop={len(kept)} new={len(new_rows)} total={len(out)}")

schema_rows = fetch(f"test_dim.dim_attr_schema_{L1}", SCHEMA_COLS)
rule_rows = fetch(f"test_dim.dim_attr_extract_rule_{L1}", RULE_COLS)
print(f"source schema={len(schema_rows)} rule={len(rule_rows)}")
merge_csv(SEED / "dim_attr_schema.csv", SCHEMA_COLS, SCHEMA_PK, schema_rows, OLD_L1)
merge_csv(SEED / "dim_attr_extract_rule.csv", RULE_COLS, RULE_PK, rule_rows, OLD_L1)
conn.close()
print("✅ seed CSV 已更新（移除 mcu/mpu/dsp，写入 mcu_mpu_dsp）")
