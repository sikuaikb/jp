#!/usr/bin/env python3
"""从 prod_export SHOW CREATE + dim_attr_schema seed 生成 22_logic_ic_ready 脚本。"""
import csv
import re
import sys
from collections import defaultdict
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8", errors="replace")

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
PROD_EXPORT = HERE / "prod_export"
SEED = HERE / "seed"
OUT = REPO / "sql_scripts" / "2.attribute_standard" / "22_logic_ic_ready"
L1 = "logic_ic"

L2_LIST = [
    "combinational_logic",
    "sequential_logic",
    "signal_buffer_driver",
]

STD_HEAD = {"data_source", "id", "mpn", "brand", "brandid", "l1_code", "l2_code", "l3_code"}
STD_TAIL = {"ext_attributes", "semantic_tags", "dq_score", "dq_flags", "source_id", "create_at", "update_at"}
EXTRA = {"brandshort", "l3_id"}


def load_schema():
    l2_attrs = defaultdict(list)
    l3_attrs = defaultdict(list)
    l2_to_l3 = defaultdict(set)
    with (SEED / f"dim_attr_schema_{L1}.csv").open(encoding="utf-8-sig") as f:
        for row in csv.DictReader(f):
            sl, sc, attr, dt = row["scope_level"], row["scope_code"], row["std_attr_code"], row["db_type"]
            if sl == "l2":
                l2_attrs[sc].append((attr, dt))
            elif sl == "l3":
                l3_attrs[sc].append((attr, dt))
    with (SEED / f"dim_l3_classify_{L1}.csv").open(encoding="utf-8-sig") as f:
        for row in csv.DictReader(f):
            l2_to_l3[row["l2_code"]].add(row["l3_code"])
    return l2_attrs, l3_attrs, l2_to_l3


def parse_prod_columns(ddl_text: str) -> list[tuple[str, str]]:
    cols = []
    for m in re.finditer(r"`(\w+)`\s+(\w+(?:\([^)]*\))?)", ddl_text):
        cols.append((m.group(1), m.group(2)))
    return cols


def pivot_expr(attr: str, db_type: str) -> str:
    if db_type == "BOOLEAN":
        return f"MAX(CASE WHEN v.std_attr_code = '{attr}' THEN CAST(v.value_std_double AS BOOLEAN) END) AS {attr}"
    if db_type in ("VARCHAR", "ENUM"):
        return f"MAX(CASE WHEN v.std_attr_code = '{attr}' THEN v.value_std_varchar END) AS {attr}"
    return f"MAX(CASE WHEN v.std_attr_code = '{attr}' THEN v.value_std_double END) AS {attr}"


def gen_ddl(l2: str, prod_ddl: str) -> str:
    tbl = f"dwd_l2_{L1}_{l2}"
    cols = parse_prod_columns(prod_ddl)
    body_lines = []
    for name, typ in cols:
        if name in STD_HEAD:
            continue
        if name in STD_TAIL:
            continue
        sql_type = typ.upper()
        if "varchar" in sql_type.lower():
            sql_type = "VARCHAR(1024)" if name in ("manufacturer", "package_case", "rohs_compliant", "reach", "lead_free", "eccn_code") else "VARCHAR(128)"
        elif "double" in sql_type.lower():
            sql_type = "DOUBLE"
        elif "bigint" in sql_type.lower():
            sql_type = "BIGINT"
        elif "int" in sql_type.lower():
            sql_type = "INT"
        elif "json" in sql_type.lower():
            sql_type = "JSON"
        elif "datetime" in sql_type.lower():
            sql_type = "DATETIME"
        body_lines.append(f"    `{name}` {sql_type} NULL,")

    head = f"""/* ============================================================
 * DWD L2 / {l2}
 * l1_code={L1} · 逆向合仓自 prod SHOW CREATE TABLE
 * ============================================================ */

DROP TABLE IF EXISTS dwd.{tbl};

CREATE TABLE IF NOT EXISTS dwd.{tbl} (
    `data_source`   VARCHAR(32)    NOT NULL COMMENT '数据来源：icpdf | digikey',
    `id`            BIGINT         NOT NULL COMMENT '组件唯一ID',
    `mpn`           VARCHAR(1024)  NULL     COMMENT '制造商料号',
    `brand`         VARCHAR(256)   NULL     COMMENT '标准品牌名',
    `brandid`       BIGINT         NULL     COMMENT '标准品牌ID',
    `l1_code`       VARCHAR(32)    NOT NULL COMMENT 'L1：{L1}',
    `l2_code`       VARCHAR(96)    NOT NULL COMMENT 'L2：{l2}',
    `l3_code`       VARCHAR(96)    NULL     COMMENT 'L3 形态编码',
"""
    mid = "\n".join(body_lines)
    tail = """
    `ext_attributes` JSON           NULL COMMENT 'L3 专有属性 KV 包',
    `semantic_tags`  JSON           NULL COMMENT '业务标签',
    `dq_score`       DOUBLE         NULL COMMENT '数据质量综合分（预留）',
    `dq_flags`       JSON           NULL COMMENT '数据质量标记（预留）',
    `source_id`      BIGINT         NULL COMMENT '来源表原始 id',
    `create_at`      DATETIME       NULL DEFAULT CURRENT_TIMESTAMP,
    `update_at`      DATETIME       NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=OLAP
PRIMARY KEY(`data_source`, `id`)
COMMENT 'DWD L2 {l2} 宽表（{l1}）'
DISTRIBUTED BY HASH(`id`) BUCKETS 16
PROPERTIES (
    "compression"             = "ZSTD",
    "datacache.enable"        = "true",
    "replication_num"         = "1",
    "enable_persistent_index" = "true"
);
"""
    return head + mid + tail.format(l2=l2, l1=L1)


def gen_build(l2: str, l2_attrs: list, l3_codes: set, l3_attrs: dict, prod_cols: list[str]) -> str:
    tbl = f"dwd_l2_{L1}_{l2}"
    attr_cols = [c for c in prod_cols if c not in STD_HEAD | STD_TAIL]

    insert_cols = (
        ["id", "mpn", "brand", "brandid", "l1_code", "l2_code", "l3_code"]
        + [c for c in attr_cols if c != "mpn"]
        + ["ext_attributes", "semantic_tags", "dq_score", "dq_flags", "data_source", "source_id", "create_at", "update_at"]
    )

    schema_map = {a: dt for a, dt in l2_attrs}
    pivots = []
    for col in attr_cols:
        if col in ("brandshort", "l3_id"):
            continue
        if col == "mpn":
            continue
        dt = schema_map.get(col, "VARCHAR")
        pivots.append("    " + pivot_expr(col, dt))

    l3_attr_list = []
    seen = set()
    for l3 in sorted(l3_codes):
        for attr, dt in l3_attrs.get(l3, []):
            if attr not in seen:
                seen.add(attr)
                l3_attr_list.append((attr, dt))

    ext_block = """    parse_json(MAX(x.ext_attributes_str)) AS ext_attributes,"""
    if l3_attr_list:
        ext_block = """    parse_json(MAX(x.ext_attributes_str)) AS ext_attributes,"""

    select_tail = []
    for col in attr_cols:
        if col == "brandshort":
            select_tail.append("    p.brandshort AS brandshort,")
        elif col == "l3_id":
            select_tail.append("    c.l3_id AS l3_id,")
        elif col == "mpn":
            continue
        else:
            dt = schema_map.get(col, "VARCHAR")
            if dt == "BOOLEAN":
                select_tail.append(f"    MAX(CASE WHEN v.std_attr_code = '{col}' THEN CAST(v.value_std_double AS BOOLEAN) END) AS {col},")
            elif dt in ("VARCHAR", "ENUM"):
                select_tail.append(f"    MAX(CASE WHEN v.std_attr_code = '{col}' THEN v.value_std_varchar END) AS {col},")
            else:
                select_tail.append(f"    MAX(CASE WHEN v.std_attr_code = '{col}' THEN v.value_std_double END) AS {col},")

    return f"""/* ============================================================
 * 装配 SQL：dwd_component_attr_std（EAV）→ dwd.{tbl}
 * 逆向合仓 · 列结构对齐 prod
 * ============================================================ */

INSERT INTO dwd.{tbl}
(
    {', '.join(insert_cols)}
)
WITH src_param AS (
    SELECT 'icpdf'   AS data_source, id, partno, brandshort, brandid
    FROM dwd.dwd_icpdf_component_param
    UNION ALL
    SELECT 'digikey' AS data_source, id, partno, brandshort, brandid
    FROM dwd.dwd_digikey_component_param
),
ext AS (
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
    FROM dwd.dwd_component_attr_std e
    INNER JOIN dwd.dwd_component_class c ON c.id = e.id AND c.data_source = e.data_source
    INNER JOIN dim.dim_attr_schema d
            ON d.schema_version = e.attr_schema_version
           AND d.l1_code = '{L1}'
           AND d.std_attr_code = e.std_attr_code
           AND d.scope_level = 'l3'
           AND d.scope_code = c.l3_code
    WHERE c.l2_code = '{l2}'
      AND (
          e.value_std_double IS NOT NULL
          OR (e.value_std_varchar IS NOT NULL AND trim(e.value_std_varchar) <> '')
      )
    GROUP BY e.data_source, e.id
)
SELECT
    c.id,
    COALESCE(
        NULLIF(TRIM(MAX(CASE WHEN v.std_attr_code = 'mpn' THEN v.value_std_varchar END)), ''),
        p.partno
    ) AS mpn,
    COALESCE(a.canonical_name, p.brandshort) AS brand,
    COALESCE(a.brand_id_std, p.brandid) AS brandid,
    c.l1_code,
    c.l2_code,
    c.l3_code,
{chr(10).join(select_tail)}
{ext_block}
    NULL AS semantic_tags,
    NULL AS dq_score,
    NULL AS dq_flags,
    c.data_source AS data_source,
    c.id AS source_id,
    COALESCE(MAX(old.create_at), CURRENT_TIMESTAMP()) AS create_at,
    CURRENT_TIMESTAMP() AS update_at
FROM dwd.dwd_component_class c
JOIN src_param p ON p.data_source = c.data_source AND p.id = c.id
LEFT JOIN dim.v_std_brand_alias a ON a.brand_key = UPPER(TRIM(p.brandshort))
LEFT JOIN dwd.dwd_component_attr_std v ON v.id = c.id AND v.data_source = c.data_source AND v.l2_code = c.l2_code
LEFT JOIN ext x ON x.id = c.id AND x.data_source = c.data_source
LEFT JOIN dwd.{tbl} old ON old.id = c.id AND old.data_source = c.data_source
WHERE c.l2_code = '{l2}'
GROUP BY
    c.id, c.data_source, p.partno, p.brandshort, p.brandid,
    a.brand_id_std, a.canonical_name, c.l1_code, c.l2_code, c.l3_code, c.l3_id;
"""


def main():
    l2_attrs, l3_attrs, l2_to_l3 = load_schema()
    OUT.mkdir(parents=True, exist_ok=True)
    for l2 in L2_LIST:
        prod_path = PROD_EXPORT / f"dwd_l2_{L1}_{l2}.sql"
        prod_ddl = prod_path.read_text(encoding="utf-8")
        ddl = gen_ddl(l2, prod_ddl)
        prod_cols = [c for c, _ in parse_prod_columns(prod_ddl)]
        build = gen_build(l2, l2_attrs.get(l2, []), l2_to_l3.get(l2, set()), l3_attrs, prod_cols)
        (OUT / f"dwd_l2_{L1}_{l2}.sql").write_text(ddl, encoding="utf-8")
        (OUT / f"build_dwd_l2_{L1}_{l2}.sql").write_text(build, encoding="utf-8")
        print(f"  ✅ {l2}")
    readme = OUT / "README.md"
    readme.write_text(
        f"""# 22_logic_ic_ready

逆向合仓自 prod（`MERGE_BACKLOG_6L1.md` P0）。

## prod 基线（2026-06-24）

| 指标 | 值 |
|---|---:|
| 分类行数 (digikey) | 19,591 |
| dim_l3_classify | 21 |
| dim_l3_classify_rule | 20 |
| dim_attr_schema | 215 |
| dim_attr_extract_rule | 64 |

| L2 表 | 行数 |
|---|---:|
| rf_antenna | 17,350 |
| rf_passive_network | 2,308 |
| rf_signal_control_detection | 11,444 |
| rf_transceiver_ic | 6,668 |
| rfid_nfc_frontend | 1,493 |

## 验收

- 分类 A4-A6：`test/logic_ic/run_classify_logic_ic.py` → 19,591 行 PASS
- 属性 B6：`ALLOW_PROD=1 run_attr_std.sh prod L1_LIST=logic_ic`
""",
        encoding="utf-8",
    )
    print(f"输出目录: {OUT}")


if __name__ == "__main__":
    main()
