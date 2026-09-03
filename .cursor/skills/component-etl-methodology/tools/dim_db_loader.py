"""Read dim rows from StarRocks/MySQL for validate_* (no CSV). Uses MYSQL_* env."""
from __future__ import annotations

import os
import sys
from typing import Sequence


def connect():
    import pymysql

    for var in ("MYSQL_HOST", "MYSQL_USER", "MYSQL_PASSWORD"):
        if not os.environ.get(var):
            print(f"ERROR: env {var} not set", file=sys.stderr)
            sys.exit(2)
    return pymysql.connect(
        host=os.environ["MYSQL_HOST"],
        port=int(os.environ.get("MYSQL_PORT", "9030")),
        user=os.environ["MYSQL_USER"],
        password=os.environ["MYSQL_PASSWORD"],
        charset="utf8mb4",
    )


def fetch_rows(schema: str, table: str, columns: Sequence[str]) -> list[dict]:
    col_sql = ", ".join(f"`{c}`" for c in columns)
    sql = f"SELECT {col_sql} FROM `{schema}`.`{table}`"
    conn = connect()
    try:
        with conn.cursor() as cur:
            cur.execute(sql)
            raw = cur.fetchall()
    finally:
        conn.close()
    out: list[dict] = []
    for row in raw:
        d: dict = {}
        for i, c in enumerate(columns):
            v = row[i]
            if v is None:
                d[c] = ""
            elif isinstance(v, float) and v == int(v):
                d[c] = str(int(v))
            else:
                d[c] = str(v)
        out.append(d)
    return out
