#!/usr/bin/env python3
"""PDF 抽取直通链路 · schema 驱动 L2 宽表装配（写入既有 prod 宽表，脚本与 icpdf/digikey build 分离）。

运行时从 information_schema 读取目标宽表列清单，列名与 dim_attr_schema.std_attr_code / EAV 对齐，
宽表 DDL 增删列后重跑本脚本即可，无需改 SQL 源码。

用法：
  python build_dwd_l2_pcb_attr_extract_pipe.py --all
  python build_dwd_l2_pcb_attr_extract_pipe.py --l1 mcu_mpu_dsp --l2 mpu_soc
  python build_dwd_l2_pcb_attr_extract_pipe.py --table dwd.dwd_l2_resistor_fixed_resistor --l2 fixed_resistor

依赖：local.env（MYSQL_*）；已跑 classify + EAV（pcb_attr_extract_pipe）。
"""
from __future__ import annotations

import argparse
import os
import re
import sys
from pathlib import Path

try:
    import pymysql
except ImportError:
    print("需要 pymysql: pip install pymysql", file=sys.stderr)
    sys.exit(1)

REPO = Path(__file__).resolve().parents[2]
LOCAL_ENV = REPO / "sql_scripts" / "local.env"

DATA_SOURCE = "pcb_attr_extract_pipe"

STD_HEAD = (
    "data_source",
    "id",
    "mpn",
    "brand",
    "brandid",
    "l1_code",
    "l2_code",
    "l3_code",
)
STD_TAIL = (
    "ext_attributes",
    "semantic_tags",
    "dq_score",
    "dq_flags",
    "source_id",
    "create_at",
    "update_at",
)
HEAD_EXTRA = frozenset({"brandshort", "l3_id"})


def load_env() -> None:
    if LOCAL_ENV.is_file():
        for line in LOCAL_ENV.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            k, _, v = line.partition("=")
            k = k.replace("export ", "").strip()
            v = v.strip().strip("'").strip('"')
            if k and k not in os.environ:
                os.environ[k] = v


def connect():
    return pymysql.connect(
        host=os.environ["MYSQL_HOST"],
        port=int(os.environ.get("MYSQL_PORT", "9030")),
        user=os.environ["MYSQL_USER"],
        password=os.environ["MYSQL_PASSWORD"],
        charset="utf8mb4",
        autocommit=True,
    )


def q(cur, sql: str, args=None):
    cur.execute(sql, args or ())
    return cur.fetchall()


def resolve_table(cur, dwd_schema: str, l1_code: str, l2_code: str) -> str | None:
    exact = f"dwd_l2_{l1_code}_{l2_code}"
    rows = q(
        cur,
        """
        SELECT table_name FROM information_schema.tables
        WHERE table_schema = %s AND table_name = %s
        """,
        (dwd_schema, exact),
    )
    if rows:
        return exact
    rows = q(
        cur,
        """
        SELECT table_name FROM information_schema.tables
        WHERE table_schema = %s AND table_name LIKE %s
        ORDER BY CHAR_LENGTH(table_name), table_name
        """,
        (dwd_schema, f"%_{l2_code}"),
    )
    for (name,) in rows:
        if name.endswith(f"_{l2_code}") or name == f"dwd_l2_{l2_code}":
            return name
    return None


def fetch_columns(cur, dwd_schema: str, table: str) -> list[str]:
    rows = q(
        cur,
        """
        SELECT column_name FROM information_schema.columns
        WHERE table_schema = %s AND table_name = %s
        ORDER BY ordinal_position
        """,
        (dwd_schema, table),
    )
    return [r[0] for r in rows]


def fetch_db_types(cur, dim_schema: str, l1_code: str, l2_code: str) -> dict[str, str]:
    rows = q(
        cur,
        f"""
        SELECT std_attr_code, db_type
        FROM {dim_schema}.dim_attr_schema
        WHERE l1_code = %s AND scope_level = 'l2' AND scope_code = %s
        """,
        (l1_code, l2_code),
    )
    return {r[0]: r[1] for r in rows}


def fetch_column_types(cur, dwd_schema: str, table: str) -> dict[str, dict]:
    rows = q(
        cur,
        """
        SELECT column_name, data_type, character_maximum_length
        FROM information_schema.columns
        WHERE table_schema = %s AND table_name = %s
        ORDER BY ordinal_position
        """,
        (dwd_schema, table),
    )
    return {
        r[0]: {"type": r[1].lower(), "max_len": r[2]}
        for r in rows
    }
def pivot_expr(col: str, db_type: str, col_meta: dict) -> str:
    phys = col_meta["type"]
    max_len = col_meta.get("max_len")
    if phys in ("tinyint", "boolean") or db_type == "BOOLEAN":
        return (
            f"MAX(CASE WHEN v.std_attr_code = '{col}' "
            f"THEN CAST(v.value_std_double AS TINYINT) END)"
        )
    if phys == "int" or db_type == "INT":
        return (
            f"MAX(CASE WHEN v.std_attr_code = '{col}' "
            f"THEN CAST(v.value_std_double AS INT) END)"
        )
    if phys in ("double", "float", "decimal") or db_type == "DOUBLE":
        return f"MAX(CASE WHEN v.std_attr_code = '{col}' THEN v.value_std_double END)"
    inner = f"MAX(CASE WHEN v.std_attr_code = '{col}' THEN v.value_std_varchar END)"
    if max_len and int(max_len) > 0:
        return f"substr({inner}, 1, {int(max_len)})"
    return inner


def select_expr(col: str, db_types: dict[str, str], col_types: dict[str, dict]) -> str:
    if col == "data_source":
        return f"'{DATA_SOURCE}' AS data_source"
    if col == "id":
        return "c.id AS id"
    if col == "mpn":
        mpn_expr = (
            "COALESCE("
            "NULLIF(TRIM(MAX(CASE WHEN v.std_attr_code = 'mpn' "
            "THEN v.value_std_varchar END)), ''), "
            "p.partno)"
        )
        max_len = col_types.get("mpn", {}).get("max_len")
        if max_len and int(max_len) > 0:
            mpn_expr = f"substr({mpn_expr}, 1, {int(max_len)})"
        return f"{mpn_expr} AS mpn"
    if col == "brand":
        return "COALESCE(a.canonical_name, p.brandshort) AS brand"
    if col == "brandid":
        return "COALESCE(a.brand_id_std, p.brandid) AS brandid"
    if col == "l1_code":
        return "c.l1_code AS l1_code"
    if col == "l2_code":
        return "c.l2_code AS l2_code"
    if col == "l3_code":
        return "c.l3_code AS l3_code"
    if col == "brandshort":
        return "p.brandshort AS brandshort"
    if col == "l3_id":
        return "c.l3_id AS l3_id"
    if col == "ext_attributes":
        return "parse_json(MAX(x.ext_attributes_str)) AS ext_attributes"
    if col == "semantic_tags":
        return "NULL AS semantic_tags"
    if col == "dq_score":
        return "NULL AS dq_score"
    if col == "dq_flags":
        return "NULL AS dq_flags"
    if col == "source_id":
        return "c.id AS source_id"
    if col == "create_at":
        return "COALESCE(MAX(old.create_at), CURRENT_TIMESTAMP()) AS create_at"
    if col == "update_at":
        return "CURRENT_TIMESTAMP() AS update_at"
    dt = db_types.get(col, "VARCHAR")
    cm = col_types.get(col, {"type": "varchar", "max_len": None})
    return f"{pivot_expr(col, dt, cm)} AS `{col}`"


def build_sql(
    dwd_schema: str,
    dim_schema: str,
    table: str,
    l1_code: str,
    l2_code: str,
    columns: list[str],
    db_types: dict[str, str],
    col_types: dict[str, dict],
) -> str:
    fq = f"{dwd_schema}.{table}"
    col_list = ",\n    ".join(f"`{c}`" for c in columns)
    select_list = ",\n    ".join(select_expr(c, db_types, col_types) for c in columns)

    return f"""/* auto-generated by build_dwd_l2_pcb_attr_extract_pipe.py — schema-driven */
DELETE FROM {fq} WHERE data_source = '{DATA_SOURCE}';

INSERT INTO {fq}
(
    {col_list}
)
WITH ext AS (
    SELECT
        e.data_source,
        e.id,
        concat(
            '{{',
            array_join(
                array_agg(
                    concat(
                        '"', e.std_attr_code, '":',
                        CASE
                            WHEN e.db_type IN ('VARCHAR', 'ENUM')
                                THEN concat('"', replace(COALESCE(e.value_std_varchar, ''), '"', '\\\\"'), '"')
                            WHEN e.db_type = 'BOOLEAN'
                                THEN CASE
                                        WHEN CAST(e.value_std_double AS INT) = 1 THEN 'true'
                                        WHEN CAST(e.value_std_double AS INT) = 0 THEN 'false'
                                        ELSE 'null'
                                     END
                            ELSE COALESCE(CAST(e.value_std_double AS VARCHAR), 'null')
                        END
                    )
                ),
                ','
            ),
            '}}'
        ) AS ext_attributes_str
    FROM {dwd_schema}.dwd_component_attr_std e
    INNER JOIN {dwd_schema}.dwd_component_class c
            ON c.id = e.id AND c.data_source = e.data_source
    INNER JOIN {dim_schema}.dim_attr_schema d
            ON d.schema_version = e.attr_schema_version
           AND d.l1_code = '{l1_code}'
           AND d.std_attr_code = e.std_attr_code
           AND d.scope_level = 'l3'
           AND d.scope_code = c.l3_code
    WHERE c.data_source = '{DATA_SOURCE}'
      AND c.l2_code = '{l2_code}'
      AND (
          e.value_std_double IS NOT NULL
          OR (e.value_std_varchar IS NOT NULL AND trim(e.value_std_varchar) <> '')
      )
    GROUP BY e.data_source, e.id
)
SELECT
    {select_list}
FROM {dwd_schema}.dwd_component_class c
INNER JOIN {dwd_schema}.dwd_pdf_extract_component_param p
        ON p.id = c.id
LEFT JOIN {dim_schema}.v_std_brand_alias a
       ON a.brand_key = UPPER(TRIM(p.brandshort))
LEFT JOIN {dwd_schema}.dwd_component_attr_std v
       ON v.id = c.id
      AND v.data_source = c.data_source
      AND v.l2_code = c.l2_code
LEFT JOIN ext x ON x.id = c.id AND x.data_source = c.data_source
LEFT JOIN {fq} old
       ON old.id = c.id AND old.data_source = '{DATA_SOURCE}'
WHERE c.data_source = '{DATA_SOURCE}'
  AND c.l2_code = '{l2_code}'
GROUP BY
    c.id,
    c.data_source,
    p.partno,
    p.brandshort,
    p.brandid,
    a.brand_id_std,
    a.canonical_name,
    c.l1_code,
    c.l2_code,
    c.l3_code,
    c.l3_id;
"""


def discover_l2_pairs(cur, dwd_schema: str) -> list[tuple[str, str]]:
    rows = q(
        cur,
        f"""
        SELECT DISTINCT l1_code, l2_code
        FROM {dwd_schema}.dwd_component_class
        WHERE data_source = %s
        ORDER BY l1_code, l2_code
        """,
        (DATA_SOURCE,),
    )
    return [(r[0], r[1]) for r in rows]


def run_build(
    cur,
    dwd_schema: str,
    dim_schema: str,
    l1_code: str,
    l2_code: str,
    table_override: str | None = None,
) -> bool:
    table = table_override or resolve_table(cur, dwd_schema, l1_code, l2_code)
    if not table:
        print(f"  SKIP: 未找到宽表 l1={l1_code} l2={l2_code}", file=sys.stderr)
        return False
    if table_override and "." in table_override:
        table = table_override.split(".", 1)[1]

    columns = fetch_columns(cur, dwd_schema, table)
    if not columns:
        print(f"  SKIP: {table} 无列", file=sys.stderr)
        return False

    db_types = fetch_db_types(cur, dim_schema, l1_code, l2_code)
    col_types = fetch_column_types(cur, dwd_schema, table)
    sql = build_sql(dwd_schema, dim_schema, table, l1_code, l2_code, columns, db_types, col_types)

    print(f"==> {dwd_schema}.{table}  ← {DATA_SOURCE} ({len(columns)} 列, l1={l1_code}, l2={l2_code})")
    for stmt in re.split(r";\s*\n", sql.strip()):
        stmt = stmt.strip()
        if stmt:
            cur.execute(stmt)

    n = q(
        cur,
        f"SELECT COUNT(*) FROM {dwd_schema}.{table} WHERE data_source = %s",
        (DATA_SOURCE,),
    )[0][0]
    print(f"    写入 {n} 行")
    return True


def main() -> int:
    load_env()
    ap = argparse.ArgumentParser(description="PDF pipe schema-driven L2 wide build")
    ap.add_argument("--dwd-schema", default="dwd")
    ap.add_argument("--dim-schema", default="dim")
    ap.add_argument("--all", action="store_true", help="装配所有已分类 L2")
    ap.add_argument("--l1", help="L1 code")
    ap.add_argument("--l2", help="L2 code")
    ap.add_argument("--table", help="显式宽表名（可带 schema，如 dwd.dwd_l2_...）")
    args = ap.parse_args()

    conn = connect()
    cur = conn.cursor()

    if args.all:
        pairs = discover_l2_pairs(cur, args.dwd_schema)
        if not pairs:
            print("无 pcb_attr_extract_pipe 分类数据", file=sys.stderr)
            return 1
        ok = 0
        for l1, l2 in pairs:
            if run_build(cur, args.dwd_schema, args.dim_schema, l1, l2):
                ok += 1
        print(f"Done: {ok}/{len(pairs)} 张宽表")
        return 0 if ok else 1

    if not args.l2:
        ap.error("请指定 --all，或同时指定 --l1 与 --l2")

    l1 = args.l1
    if not l1:
        rows = q(
            cur,
            f"""
            SELECT DISTINCT l1_code FROM {args.dwd_schema}.dwd_component_class
            WHERE data_source = %s AND l2_code = %s LIMIT 2
            """,
            (DATA_SOURCE, args.l2),
        )
        if len(rows) != 1:
            ap.error(f"无法唯一推断 l1（l2={args.l2}），请显式传 --l1")
        l1 = rows[0][0]

    table_override = args.table
    if table_override and "." in table_override:
        pass
    elif table_override:
        table_override = f"{args.dwd_schema}.{table_override}"

    if not run_build(cur, args.dwd_schema, args.dim_schema, l1, args.l2, table_override):
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
