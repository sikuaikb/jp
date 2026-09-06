#!/usr/bin/env python3
"""连接器属性填充率查询（对齐 test_dim.dim_attr_schema_connector）。"""
from __future__ import annotations

import os
from pathlib import Path

import pymysql

HERE = Path(__file__).resolve().parent
ENV = HERE.parents[1] / "sql_scripts" / "local.env"

L2_CN = {
    "board_wire_interconnect_connector": "板级与线缆互连连接器",
    "general_shell_connector": "通用壳体连接器",
    "standard_interface_socket_connector": "标准接口与卡座连接器",
    "backplane_ic_socket_connector": "背板与插座连接器",
    "power_terminal_connector": "电源与端子连接器",
    "rf_coaxial_connector": "RF同轴连接器",
}

L2_WIDE = {l2: f"dwd_l2_connector_{l2}" for l2 in L2_CN}


def load_env() -> None:
    if not ENV.exists():
        return
    for line in ENV.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line.startswith("export "):
            k, _, v = line[7:].partition("=")
            os.environ[k] = v.strip().strip("'").strip('"')


def conn_kwargs() -> dict:
    load_env()
    return dict(
        host=os.environ.get("MYSQL_HOST", "192.168.19.21"),
        port=int(os.environ.get("MYSQL_PORT", "9030")),
        user=os.environ.get("MYSQL_USER", "dev"),
        password=os.environ["MYSQL_PASSWORD"],
        charset="utf8mb4",
    )


def load_taxonomy(cur) -> tuple[dict[str, str], dict[str, tuple[str, str]]]:
    cur.execute("""
        SELECT l2_code, l2_cn, l3_code, l3_cn
        FROM test_dim.dim_l3_classify_connector
        WHERE l3_code NOT LIKE '%%unclassified%%'
    """)
    l2_cn = dict(L2_CN)
    l3_map: dict[str, tuple[str, str]] = {}
    for l2, l2c, l3, l3_cn in cur.fetchall():
        l2_cn.setdefault(l2, l2c or l2)
        l3_map[l3] = (l2, l3_cn or l3)
    return l2_cn, l3_map


def fill_rates(cur, data_source: str) -> list[tuple]:
    cur.execute("""
        SELECT scope_level, scope_code, std_attr_code, std_attr_cn
        FROM test_dim.dim_attr_schema_connector
        WHERE l1_code='connector'
        ORDER BY scope_level, scope_code, display_ord, std_attr_code
    """)
    schema = cur.fetchall()
    rows = []
    unclass = "c.l3_code NOT LIKE '%%unclassified%%'"
    for sl, sc, attr, cn in schema:
        scope_col = "c.l2_code" if sl == "l2" else "c.l3_code"
        sql = f"""
        SELECT
          COUNT(DISTINCT c.id) AS denom,
          COUNT(DISTINCT CASE
            WHEN e.value_std_double IS NOT NULL
              OR NULLIF(TRIM(e.value_std_varchar), '') IS NOT NULL
            THEN c.id END) AS filled
        FROM test_dwd.dwd_component_class_connector c
        LEFT JOIN test_dwd.dwd_component_attr_std_connector e
          ON e.id = c.id AND e.data_source = c.data_source AND e.std_attr_code = %s
        WHERE c.data_source = %s AND {unclass} AND {scope_col} = %s
        """
        cur.execute(sql, (attr, data_source, sc))
        d, f = cur.fetchone()
        pct = round(100.0 * f / d, 2) if d else 0.0
        rows.append((sl, sc, attr, cn or "", d, f, pct))
    return rows


def wide_l2_fill_rates(cur, l2: str, table: str) -> list[tuple]:
    cur.execute("""
        SELECT std_attr_code, std_attr_cn, db_type
        FROM test_dim.dim_attr_schema_connector
        WHERE l1_code='connector' AND scope_level='l2' AND scope_code=%s AND is_l2_common=1
        ORDER BY display_ord
    """, (l2,))
    schema = cur.fetchall()
    cur.execute(f"SELECT COUNT(*) FROM test_dwd.{table} WHERE data_source='digikey'")
    total = cur.fetchone()[0]
    rows = []
    skip = {"mpn", "brand", "brandid", "l1_code", "l2_code", "l3_code", "data_source", "id"}
    for attr, cn, db_type in schema:
        if attr in skip:
            continue
        if db_type in ("DOUBLE", "INT"):
            cond = f"`{attr}` IS NOT NULL"
        else:
            cond = f"NULLIF(TRIM(`{attr}`), '') IS NOT NULL"
        cur.execute(f"SELECT COUNT(*) FROM test_dwd.{table} WHERE data_source='digikey' AND {cond}")
        filled = cur.fetchone()[0]
        pct = round(100.0 * filled / total, 2) if total else 0.0
        rows.append((attr, cn or "", total, filled, pct))
    return rows


def brand_gate(cur, table: str) -> dict:
    cur.execute(f"""
        SELECT COUNT(*) AS total,
               SUM(CASE WHEN brand IS NULL OR TRIM(brand)='' THEN 1 ELSE 0 END) AS brand_null,
               SUM(CASE WHEN brandid IS NULL THEN 1 ELSE 0 END) AS brandid_null,
               COUNT(DISTINCT brand) AS distinct_brand,
               COUNT(DISTINCT brandid) AS distinct_brandid
        FROM test_dwd.{table}
        WHERE data_source='digikey'
    """)
    r = cur.fetchone()
    return {
        "total": int(r[0]),
        "brand_null": int(r[1] or 0),
        "brandid_null": int(r[2] or 0),
        "distinct_brand": int(r[3] or 0),
        "distinct_brandid": int(r[4] or 0),
    }


def to_human_md(rows: list[tuple], l2_cn: dict[str, str], l3_map: dict[str, tuple[str, str]]) -> str:
    lines = [
        "| 大类 | 细分类 | 参数 | 适用物料数 | 已填写物料数 | 填充率 |",
        "|------|--------|------|------------|--------------|--------|",
    ]
    for sl, sc, _attr, cn, d, f, pct in rows:
        if sl == "l2":
            cat = l2_cn.get(sc, sc)
            sub = "（该大类全部物料）"
        else:
            l2, l3_cn = l3_map.get(sc, ("", sc))
            cat = l2_cn.get(l2, l2) if l2 else "—"
            sub = l3_cn
        lines.append(f"| {cat} | {sub} | {cn} | {d:,} | {f:,} | {pct}% |")
    return "\n".join(lines) + "\n"
