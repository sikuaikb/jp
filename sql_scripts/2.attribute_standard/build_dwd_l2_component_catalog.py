#!/usr/bin/env python3
"""全量构建 dwd_l2_component_catalog：UNION 正式 dwd_l2_* + JOIN class + dim 中文名。

用法：
  python build_dwd_l2_component_catalog.py test          # → test_dwd
  ALLOW_PROD=1 python build_dwd_l2_component_catalog.py prod   # → dwd
  INIT_DDL=1 ... prod   # 首次或改 DDL 时 DROP+CREATE
"""
from __future__ import annotations

import os
import sys
from pathlib import Path

import pymysql

sys.stdout.reconfigure(encoding="utf-8", errors="replace")

ROOT = Path(__file__).resolve().parents[2]
ENV = ROOT / "sql_scripts" / "local.env"
DDL_PROD = Path(__file__).resolve().parent / "dwd_l2_component_catalog.sql"
DDL_TEST = ROOT / "sql_scripts" / "test" / "component_catalog" / "dwd_l2_component_catalog.sql"

LEGACY_EXCLUDE = frozenset({
    "dwd_l2_voltage_regulator",
    "dwd_l2_driver_ic",
    "dwd_l2_bms_supervisor",
})

REQUIRED_COLS = frozenset({
    "data_source", "id", "mpn", "brand", "brandid",
    "l1_code", "l2_code", "l3_code",
})

INSERT_COLS = """
    data_source, id, mpn, brand, brandid,
    l1_code, l1_cn, l2_code, l2_cn, l3_code, l3_cn, l2_table,
    l3_id, confidence, rule_id, create_at, update_at
"""


def load_env():
    for line in ENV.read_text(encoding="utf-8").splitlines():
        s = line.strip()
        if "=" in s and not s.startswith("#"):
            if s.startswith("export "):
                s = s[7:]
            k, v = s.split("=", 1)
            os.environ[k.strip()] = v.strip().strip("'").strip('"')


def connect():
    return pymysql.connect(
        host=os.environ["MYSQL_HOST"],
        port=int(os.environ.get("MYSQL_PORT", "9030")),
        user=os.environ["MYSQL_USER"],
        password=os.environ["MYSQL_PASSWORD"],
        charset="utf8mb4",
        autocommit=True,
        init_command="SET pipeline_dop=1",
    )


def should_exclude(table_name: str) -> bool:
    if table_name in LEGACY_EXCLUDE:
        return True
    if "llm_completion" in table_name:
        return True
    if "sample" in table_name:
        return True
    if table_name.endswith("_result"):
        return True
    if table_name.endswith("_audit"):
        return True
    if table_name == "dwd_l2_component_catalog":
        return True
    return False


def discover_l2_tables(cur, schema: str) -> list[str]:
    cur.execute(
        """
        SELECT table_name FROM information_schema.tables
        WHERE table_schema = %s AND table_name LIKE 'dwd_l2_%%'
        ORDER BY table_name
        """,
        (schema,),
    )
    return [n for n in (r[0] for r in cur.fetchall()) if not should_exclude(n)]


def table_has_required_cols(cur, schema: str, table_name: str) -> bool:
    cur.execute(
        """
        SELECT column_name FROM information_schema.columns
        WHERE table_schema = %s AND table_name = %s
        """,
        (schema, table_name),
    )
    return REQUIRED_COLS.issubset({r[0] for r in cur.fetchall()})


def run_ddl(cur, ddl_path: Path, out_schema: str):
    sql = ddl_path.read_text(encoding="utf-8")
    while "/*" in sql:
        pre, rest = sql.split("/*", 1)
        _, post = rest.split("*/", 1)
        sql = pre + post
    sql = sql.replace("dwd.dwd_l2_component_catalog", f"{out_schema}.dwd_l2_component_catalog")
    sql = sql.replace("DROP TABLE IF EXISTS test_dwd.dwd_l2_component_catalog", f"DROP TABLE IF EXISTS {out_schema}.dwd_l2_component_catalog")
    cur.execute(sql.strip())


def insert_one_table(cur, src_schema: str, out_schema: str, table: str) -> int:
    fq = f"{src_schema}.{table}"
    sql = f"""
    INSERT INTO {out_schema}.dwd_l2_component_catalog ({INSERT_COLS})
    SELECT
        u.data_source, u.id, u.mpn, u.brand, u.brandid,
        u.l1_code, tax.l1_cn, u.l2_code, tax.l2_cn, u.l3_code, tax.l3_cn,
        '{table}' AS l2_table,
        c.l3_id, c.confidence, c.rule_id,
        CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
    FROM {fq} u
    LEFT JOIN {src_schema}.dwd_component_class c
        ON c.data_source = u.data_source AND c.id = u.id
    LEFT JOIN dim.dim_l3_classify tax
        ON tax.l1_code = u.l1_code
       AND tax.l2_code = u.l2_code
       AND tax.l3_code = u.l3_code
    WHERE u.mpn IS NOT NULL AND u.mpn <> ''
    """
    cur.execute(sql)
    return cur.rowcount


def validate(cur, out_schema: str):
    cur.execute(f"SELECT COUNT(*) FROM {out_schema}.dwd_l2_component_catalog")
    total = cur.fetchone()[0]
    cur.execute(
        f"""
        SELECT COUNT(*) FROM (
            SELECT data_source, id FROM {out_schema}.dwd_l2_component_catalog
            GROUP BY data_source, id HAVING COUNT(*) > 1
        ) d
        """
    )
    dup = cur.fetchone()[0]
    cur.execute(
        f"""
        SELECT COUNT(*) FROM {out_schema}.dwd_l2_component_catalog
        WHERE l3_cn IS NULL OR l3_cn = ''
        """
    )
    no_l3_cn = cur.fetchone()[0]
    return total, dup, no_l3_cn


def main():
    env = (sys.argv[1] if len(sys.argv) > 1 else "test").lower()
    if env == "prod" and os.environ.get("ALLOW_PROD") != "1":
        print("写 prod 需 ALLOW_PROD=1", file=sys.stderr)
        sys.exit(2)
    if env not in ("test", "prod"):
        print("usage: build_dwd_l2_component_catalog.py test|prod", file=sys.stderr)
        sys.exit(2)

    src_schema = "dwd"
    out_schema = "dwd" if env == "prod" else "test_dwd"
    init_ddl = os.environ.get("INIT_DDL", "1") == "1"

    load_env()
    conn = connect()
    cur = conn.cursor()

    print("=" * 60)
    print(f"构建 {out_schema}.dwd_l2_component_catalog  （源 L2 @ {src_schema}）")
    print("=" * 60)

    all_names = discover_l2_tables(cur, src_schema)
    skipped = [t for t in all_names if not table_has_required_cols(cur, src_schema, t)]
    tables = [t for t in all_names if table_has_required_cols(cur, src_schema, t)]
    print(f"纳入 {len(tables)} 张 L2 宽表", end="")
    if skipped:
        print(f"（跳过 {len(skipped)}：{skipped}）")
    else:
        print()

    if init_ddl:
        ddl = DDL_PROD if env == "prod" else DDL_TEST
        print(f"INIT_DDL: {ddl.name}")
        run_ddl(cur, ddl, out_schema)
    else:
        cur.execute(f"TRUNCATE TABLE {out_schema}.dwd_l2_component_catalog")

    inserted = 0
    for i, t in enumerate(tables, 1):
        n = insert_one_table(cur, src_schema, out_schema, t)
        inserted += max(n, 0)
        print(f"  [{i:>2}/{len(tables)}] {t}: rowcount={n}")

    total, dup, no_l3_cn = validate(cur, out_schema)
    print(f"\n表内总行数: {total}")
    print(f"(data_source,id) 重复组: {dup}  （必须为 0）")
    print(f"l3_cn 为空: {no_l3_cn}  ({100.0 * no_l3_cn / total if total else 0:.2f}%)")

    if dup > 0:
        print("ERROR: 存在跨 L2 表重复 (data_source,id)，请排查分类/L2 build", file=sys.stderr)
        sys.exit(1)

    cur.close()
    conn.close()
    print(f"\n完成 → {out_schema}.dwd_l2_component_catalog")


if __name__ == "__main__":
    main()
