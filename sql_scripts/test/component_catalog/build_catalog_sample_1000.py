#!/usr/bin/env python3
"""PoC：从 prod dwd.dwd_l2_* 合并分类目录 → test_dwd.dwd_l2_component_catalog（1000 行样本）。

排除：llm_completion / sample / *_result 等旧表。
分类质量字段 JOIN dwd.dwd_component_class。
"""
import os
import sys
from pathlib import Path

import pymysql

sys.stdout.reconfigure(encoding="utf-8", errors="replace")

ROOT = Path(__file__).resolve().parents[3]
ENV = ROOT / "sql_scripts" / "local.env"
DDL = ROOT / "sql_scripts" / "test" / "component_catalog" / "dwd_l2_component_catalog.sql"

SAMPLE_LIMIT = 1000
SRC_SCHEMA = "dwd"
OUT_SCHEMA = "test_dwd"
OUT_TABLE = "dwd_l2_component_catalog"

LEGACY_EXCLUDE = frozenset({
    "dwd_l2_voltage_regulator",
    "dwd_l2_driver_ic",
    "dwd_l2_bms_supervisor",
})

REQUIRED_COLS = frozenset({
    "data_source", "id", "mpn", "brand", "brandid",
    "l1_code", "l2_code", "l3_code",
})


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
    return False


def discover_l2_tables(cur) -> list[str]:
    cur.execute(
        """
        SELECT table_name FROM information_schema.tables
        WHERE table_schema = %s AND table_name LIKE 'dwd_l2_%%'
        ORDER BY table_name
        """,
        (SRC_SCHEMA,),
    )
    names = [r[0] for r in cur.fetchall()]
    return [n for n in names if not should_exclude(n)]


def table_has_required_cols(cur, table_name: str) -> bool:
    cur.execute(
        """
        SELECT column_name FROM information_schema.columns
        WHERE table_schema = %s AND table_name = %s
        """,
        (SRC_SCHEMA, table_name),
    )
    cols = {r[0] for r in cur.fetchall()}
    return REQUIRED_COLS.issubset(cols)


def run_sql_file(cur, path: Path):
    sql = path.read_text(encoding="utf-8")
    while "/*" in sql:
        pre, rest = sql.split("/*", 1)
        _, post = rest.split("*/", 1)
        sql = pre + post
    cur.execute(sql.strip())


def build_insert_sql(tables: list[str]) -> str:
    unions = []
    for t in tables:
        fq = f"{SRC_SCHEMA}.{t}"
        unions.append(
            f"""
            SELECT data_source, id, mpn, brand, brandid,
                   l1_code, l2_code, l3_code,
                   '{t}' AS l2_table
            FROM {fq}
            WHERE mpn IS NOT NULL AND mpn <> ''
            """
        )
    union_sql = " UNION ALL ".join(unions)
    per_table = max(1, (SAMPLE_LIMIT + len(tables) - 1) // len(tables))
    return f"""
    INSERT INTO {OUT_SCHEMA}.{OUT_TABLE} (
        data_source, id, mpn, brand, brandid,
        l1_code, l1_cn, l2_code, l2_cn, l3_code, l3_cn, l2_table,
        l3_id, confidence, rule_id,
        create_at, update_at
    )
    SELECT
        u.data_source, u.id, u.mpn, u.brand, u.brandid,
        u.l1_code, tax.l1_cn, u.l2_code, tax.l2_cn, u.l3_code, tax.l3_cn, u.l2_table,
        c.l3_id, c.confidence, c.rule_id,
        CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
    FROM (
        SELECT * FROM (
            SELECT raw.*,
                   ROW_NUMBER() OVER (
                       PARTITION BY l2_table
                       ORDER BY data_source, id
                   ) AS rn
            FROM (
                {union_sql}
            ) raw
        ) ranked
        WHERE rn <= {per_table}
        LIMIT {SAMPLE_LIMIT}
    ) u
    LEFT JOIN {SRC_SCHEMA}.dwd_component_class c
        ON c.data_source = u.data_source AND c.id = u.id
    LEFT JOIN dim.dim_l3_classify tax
        ON tax.l1_code = u.l1_code
       AND tax.l2_code = u.l2_code
       AND tax.l3_code = u.l3_code
    """


def main():
    load_env()
    conn = connect()
    cur = conn.cursor()

    print("=" * 60)
    print(f"PoC · {OUT_SCHEMA}.{OUT_TABLE}  样本 {SAMPLE_LIMIT} 行")
    print("=" * 60)

    all_tables = discover_l2_tables(cur)
    skipped = [t for t in all_tables if not table_has_required_cols(cur, t)]
    tables = [t for t in all_tables if table_has_required_cols(cur, t)]

    print(f"\n发现 {SRC_SCHEMA}.dwd_l2_* : {len(all_tables)} 张（排除规则后 {len(all_tables)} 候选）")
    print(f"  纳入 UNION: {len(tables)} 张")
    if skipped:
        print(f"  缺列跳过: {len(skipped)} 张 → {skipped[:5]}{'...' if len(skipped) > 5 else ''}")

    run_sql_file(cur, DDL)
    cur.execute(f"TRUNCATE TABLE {OUT_SCHEMA}.{OUT_TABLE}")

    if not tables:
        print("ERROR: 无可用 L2 表", file=sys.stderr)
        sys.exit(1)

    insert_sql = build_insert_sql(tables)
    cur.execute(insert_sql)

    cur.execute(f"SELECT COUNT(*) FROM {OUT_SCHEMA}.{OUT_TABLE}")
    cnt = cur.fetchone()[0]
    cur.execute(
        f"""
        SELECT COUNT(*) FROM (
            SELECT data_source, id FROM {OUT_SCHEMA}.{OUT_TABLE}
            GROUP BY data_source, id HAVING COUNT(*) > 1
        ) d
        """
    )
    dup = cur.fetchone()[0]

    print(f"\n写入行数: {cnt}")
    print(f"(data_source,id) 重复组: {dup}  （应为 0）")

    cur.execute(
        f"""
        SELECT l2_table, COUNT(*) AS n
        FROM {OUT_SCHEMA}.{OUT_TABLE}
        GROUP BY l2_table ORDER BY n DESC LIMIT 10
        """
    )
    print("\n按 l2_table Top10:")
    for tbl, n in cur.fetchall():
        print(f"  {tbl:<55} {n:>5}")

    cur.execute(
        f"""
        SELECT data_source, l1_code, COUNT(*) AS n
        FROM {OUT_SCHEMA}.{OUT_TABLE}
        GROUP BY data_source, l1_code ORDER BY n DESC LIMIT 8
        """
    )
    print("\n按 data_source + l1_code Top8:")
    for ds, l1, n in cur.fetchall():
        print(f"  {ds:<8} {l1:<24} {n:>5}")

    cur.execute(
        f"""
        SELECT mpn, brand, l1_code, l1_cn, l2_code, l2_cn, l3_code, l3_cn,
               l2_table, confidence
        FROM {OUT_SCHEMA}.{OUT_TABLE}
        LIMIT 5
        """
    )
    print("\n样例 5 行:")
    for row in cur.fetchall():
        print(" ", row)

    cur.close()
    conn.close()
    print(f"\n完成 → {OUT_SCHEMA}.{OUT_TABLE}")


if __name__ == "__main__":
    main()
