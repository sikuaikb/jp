#!/usr/bin/env python3
"""从 dim_attr_schema_logic_ic.csv 生成各 L2 宽表 DDL + build SQL。"""
from __future__ import annotations

import csv
import sys
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")

HERE = Path(__file__).resolve().parent
SCHEMA_CSV = HERE / "seed" / "dim_attr_schema_logic_ic.csv"

L2_CODES = [
    "combinational_logic",
    "sequential_logic",
    "signal_buffer_driver",
]

FIXED_COLS = [
    ("data_source", "VARCHAR(32)", "NOT NULL DEFAULT 'digikey'"),
    ("id", "BIGINT", "NOT NULL"),
    ("mpn", "VARCHAR(1024)", "NULL"),
    ("brand", "VARCHAR(256)", "NULL"),
    ("brandid", "BIGINT", "NULL"),
    ("l1_code", "VARCHAR(32)", "NOT NULL"),
    ("l2_code", "VARCHAR(96)", "NOT NULL"),
    ("l3_code", "VARCHAR(96)", "NULL"),
    ("brandshort", "VARCHAR(256)", "NULL"),
    ("l3_id", "INT", "NULL"),
]
FIXED_NAMES = {c[0] for c in FIXED_COLS}

TAIL_COLS = [
    ("ext_attributes", "JSON", "NULL"),
    ("semantic_tags", "JSON", "NULL"),
    ("dq_score", "DOUBLE", "NULL"),
    ("dq_flags", "JSON", "NULL"),
    ("source_id", "BIGINT", "NULL"),
    ("create_at", "DATETIME", "NULL DEFAULT CURRENT_TIMESTAMP"),
    ("update_at", "DATETIME", "NULL DEFAULT CURRENT_TIMESTAMP"),
]

SQL_TYPE = {
    "VARCHAR": "VARCHAR(1024)",
    "ENUM": "VARCHAR(128)",
    "DOUBLE": "DOUBLE",
    "INT": "INT",
}


def load_l2_attrs() -> dict[str, list[dict]]:
    rows = list(csv.DictReader(SCHEMA_CSV.open(encoding="utf-8-sig")))
    out: dict[str, list[dict]] = {}
    for r in rows:
        if r["scope_level"] == "l2" and r["is_l2_common"] == "1":
            if r["std_attr_code"] in FIXED_NAMES:
                continue
            out.setdefault(r["scope_code"], []).append(r)
    for k in out:
        out[k].sort(key=lambda x: int(x["display_ord"]))
    return out


def ddl_sql(l2: str, attrs: list[dict]) -> str:
    lines = [
        f"/* test_dwd.dwd_l2_logic_ic_{l2} */",
        f"DROP TABLE IF EXISTS test_dwd.dwd_l2_logic_ic_{l2};",
        "",
        f"CREATE TABLE test_dwd.dwd_l2_logic_ic_{l2} (",
    ]
    parts = []
    for name, typ, extra in FIXED_COLS:
        parts.append(f"    `{name}` {typ} {extra}")
    for a in attrs:
        typ = SQL_TYPE.get(a["db_type"], "VARCHAR(1024)")
        parts.append(f"    `{a['std_attr_code']}` {typ} NULL")
    for name, typ, extra in TAIL_COLS:
        parts.append(f"    `{name}` {typ} {extra}")
    lines.append(",\n".join(parts))
    lines += [
        ") ENGINE = OLAP",
        "PRIMARY KEY (`data_source`, `id`)",
        f"COMMENT 'logic_ic / {l2} L2 宽表'",
        "DISTRIBUTED BY HASH(`id`) BUCKETS 16",
        'PROPERTIES ("replication_num" = "1", "enable_persistent_index" = "true");',
        "",
    ]
    return "\n".join(lines)


def build_sql(l2: str, attrs: list[dict]) -> str:
    insert_cols = [c[0] for c in FIXED_COLS] + [a["std_attr_code"] for a in attrs] + [c[0] for c in TAIL_COLS]
    select_exprs = [
        "c.data_source",
        "c.id",
        """COALESCE(
        NULLIF(TRIM(MAX(CASE WHEN v.std_attr_code = 'mpn' THEN v.value_std_varchar END)), ''),
        p.partno
    ) AS mpn""",
        """NULLIF(TRIM(COALESCE(
        a.canonical_name,
        am.canonical_name,
        p.brandshort,
        MAX(get_json_string(p.prajson, '$."制造商"'))
    )), '') AS brand""",
        "COALESCE(a.brand_id_std, am.brand_id_std, p.brandid) AS brandid",
        "c.l1_code",
        "c.l2_code",
        "c.l3_code",
        "NULLIF(TRIM(p.brandshort), '') AS brandshort",
        "c.l3_id",
    ]
    for a in attrs:
        code = a["std_attr_code"]
        if a["db_type"] in ("DOUBLE", "INT"):
            select_exprs.append(
                f"MAX(CASE WHEN v.std_attr_code = '{code}' THEN v.value_std_double END) AS `{code}`"
            )
        else:
            select_exprs.append(
                f"MAX(CASE WHEN v.std_attr_code = '{code}' THEN v.value_std_varchar END) AS `{code}`"
            )
    select_exprs += [
        "PARSE_JSON(MAX(x.ext_attributes_str)) AS ext_attributes",
        "NULL AS semantic_tags",
        "NULL AS dq_score",
        "NULL AS dq_flags",
        "c.id AS source_id",
        "CURRENT_TIMESTAMP() AS create_at",
        "CURRENT_TIMESTAMP() AS update_at",
    ]
    return "\n".join([
        f"/* {l2}：EAV → L2 宽表（test_dwd） */",
        f"DELETE FROM test_dwd.dwd_l2_logic_ic_{l2} WHERE data_source = 'digikey';",
        "",
        f"INSERT INTO test_dwd.dwd_l2_logic_ic_{l2}",
        "(",
        "    " + ",\n    ".join(f"`{c}`" for c in insert_cols),
        ")",
        "WITH ext AS (",
        "    SELECT",
        "        e.data_source,",
        "        e.id,",
        "        CONCAT(",
        "            '{',",
        "            ARRAY_JOIN(",
        "                ARRAY_AGG(",
        "                    CONCAT(",
        '                        \'"\', e.std_attr_code, \'":\',',
        "                        CASE",
        "                            WHEN e.db_type IN ('DOUBLE', 'INT')",
        "                                THEN COALESCE(CAST(e.value_std_double AS VARCHAR), 'null')",
        "                            ELSE CONCAT('\"', REPLACE(COALESCE(e.value_std_varchar, ''), '\"', '\\\\\"'), '\"')",
        "                        END",
        "                    )",
        "                ),",
        "                ','",
        "            ),",
        "            '}'",
        "        ) AS ext_attributes_str",
        "    FROM test_dwd.dwd_component_attr_std_logic_ic e",
        "    INNER JOIN test_dwd.dwd_component_class_logic_ic c",
        "            ON c.id = e.id AND c.data_source = e.data_source",
        "    INNER JOIN test_dim.dim_attr_schema_logic_ic d",
        "            ON d.schema_version = e.attr_schema_version",
        "           AND d.l1_code = 'logic_ic'",
        "           AND d.std_attr_code = e.std_attr_code",
        "           AND d.scope_level = 'l3'",
        "           AND d.scope_code = c.l3_code",
        f"    WHERE c.l2_code = '{l2}'",
        "      AND (",
        "           e.value_std_double IS NOT NULL",
        "        OR (e.value_std_varchar IS NOT NULL AND TRIM(e.value_std_varchar) <> '')",
        "      )",
        "      AND COALESCE(TRIM(e.value_std_varchar), '') NOT IN ('-', '--', 'N/A', 'n/a', '暂无', 'None')",
        "    GROUP BY e.data_source, e.id",
        ")",
        "SELECT",
        "    " + ",\n    ".join(select_exprs),
        "FROM test_dwd.dwd_component_class_logic_ic c",
        "JOIN dwd.dwd_digikey_component_param p ON p.id = c.id AND c.data_source = 'digikey'",
        "LEFT JOIN dim.v_std_brand_alias a ON a.brand_key = UPPER(TRIM(p.brandshort))",
        "LEFT JOIN dim.v_std_brand_alias am",
        "       ON am.brand_key = UPPER(TRIM(get_json_string(p.prajson, '$.\"制造商\"')))",
        "LEFT JOIN test_dwd.dwd_component_attr_std_logic_ic v",
        "       ON v.id = c.id AND v.data_source = c.data_source",
        "LEFT JOIN ext x ON x.id = c.id AND x.data_source = c.data_source",
        f"WHERE c.l2_code = '{l2}'",
        "  AND c.data_source = 'digikey'",
        "  AND c.l3_code NOT LIKE '%_unclassified'",
        "GROUP BY",
        "    c.data_source, c.id,",
        "    c.l1_code, c.l2_code, c.l3_id, c.l3_code,",
        "    p.partno, p.brandshort, p.brandid,",
        "    a.canonical_name, a.brand_id_std,",
        "    am.canonical_name, am.brand_id_std;",
        "",
    ])


def main() -> None:
    l2_attrs = load_l2_attrs()
    for l2 in L2_CODES:
        attrs = l2_attrs.get(l2, [])
        if not attrs:
            print(f"SKIP {l2}: no l2_common attrs")
            continue
        ddl_path = HERE / f"dwd_l2_logic_ic_{l2}.sql"
        build_path = HERE / f"build_dwd_l2_logic_ic_{l2}.sql"
        ddl_path.write_text(ddl_sql(l2, attrs), encoding="utf-8")
        build_path.write_text(build_sql(l2, attrs), encoding="utf-8")
        print(f"✓ {l2}: {len(attrs)} L2 cols -> {ddl_path.name}, {build_path.name}")


if __name__ == "__main__":
    main()
