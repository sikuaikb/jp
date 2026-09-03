#!/usr/bin/env python3
"""每 L3 抽 10 颗型号，供商城核对属性抽取完整性。"""
from __future__ import annotations

import csv
import os
import sys
from datetime import date
from pathlib import Path

import pymysql

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
ENV = REPO / "sql_scripts" / "local.env"
TAXONOMY = REPO / "sql_scripts" / "test" / "connector" / "seed" / "dim_l3_classify_connector.csv"
OUT = HERE / f"connector_l3_attr_verify_sample_{date.today().strftime('%Y%m%d')}.tsv"

FIELDS = [
    "l3_code",
    "l3_cn",
    "l2_cn",
    "sample_no",
    "partno",
    "digikey_part_number",
    "brandshort",
    "manufacturer",
    "lifecycle_status",
    "source_category",
    "digikey_url",
    "l3_attr_fields",
    "component_id",
]


def load_env() -> None:
    for line in ENV.read_text(encoding="utf-8").splitlines():
        if line.strip().startswith("export "):
            k, _, v = line.strip()[7:].partition("=")
            os.environ[k] = v.strip().strip("'").strip('"')


def main() -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    load_env()

    l3_info: dict[str, tuple[str, str]] = {}
    with TAXONOMY.open(encoding="utf-8-sig") as fh:
        for row in csv.DictReader(fh):
            l3_info[row["l3_code"]] = (row["l2_cn"], row["l3_cn"])

    conn = pymysql.connect(
        host=os.environ["MYSQL_HOST"],
        port=int(os.environ.get("MYSQL_PORT", "9030")),
        user=os.environ["MYSQL_USER"],
        password=os.environ["MYSQL_PASSWORD"],
        charset="utf8mb4",
    )
    cur = conn.cursor()

    cur.execute(
        """
        SELECT scope_code, GROUP_CONCAT(std_attr_code ORDER BY display_ord SEPARATOR ', ')
        FROM test_dim.dim_attr_schema_connector
        WHERE scope_level = 'l3' AND l1_code = 'connector'
        GROUP BY scope_code
        """
    )
    l3_attrs = {r[0]: r[1] for r in cur.fetchall()}

    cur.execute(
        """
        WITH base AS (
          SELECT c.l3_code, c.l2_code, p.partno, p.brandshort, p.category,
                 get_json_string(p.prajson, '$."制造商"') AS mfr,
                 get_json_string(p.prajson, '$."DigiKey 零件编号"') AS dk_pn,
                 get_json_string(p.prajson, '$."零件状态"') AS lifecycle,
                 p.source_product_url, p.id,
                 ROW_NUMBER() OVER (
                   PARTITION BY c.l3_code
                   ORDER BY MD5(CONCAT(CAST(p.id AS STRING), c.l3_code))
                 ) AS rn
          FROM test_dwd.dwd_component_class_connector c
          JOIN dwd.dwd_digikey_component_param p ON p.id = c.id
          WHERE c.data_source = 'digikey' AND c.l1_code = 'connector'
            AND c.l3_code IS NOT NULL AND c.l3_code NOT LIKE '%unclassified%'
        )
        SELECT l3_code, l2_code, partno, brandshort, category, mfr, dk_pn, lifecycle,
               source_product_url, id, rn
        FROM base WHERE rn <= 10
        ORDER BY l3_code, rn
        """
    )
    rows = cur.fetchall()
    conn.close()

    with OUT.open("w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=FIELDS, delimiter="\t")
        w.writeheader()
        for l3, _l2, partno, brandshort, category, mfr, dk_pn, lifecycle, url, cid, rn in rows:
            l2_cn, l3_cn = l3_info.get(l3, ("", l3))
            if not url and dk_pn:
                slug = dk_pn.replace("/", "-")
                url = f"https://www.digikey.cn/zh/products/en?keywords={slug}"
            elif not url and partno:
                url = f"https://www.digikey.cn/zh/products/en?keywords={partno}"
            w.writerow(
                {
                    "l3_code": l3,
                    "l3_cn": l3_cn,
                    "l2_cn": l2_cn,
                    "sample_no": rn,
                    "partno": partno,
                    "digikey_part_number": dk_pn or "",
                    "brandshort": brandshort or "",
                    "manufacturer": mfr or "",
                    "lifecycle_status": lifecycle or "",
                    "source_category": category or "",
                    "digikey_url": url or "",
                    "l3_attr_fields": l3_attrs.get(l3, ""),
                    "component_id": cid,
                }
            )

    from collections import Counter

    cnt = Counter(r[0] for r in rows)
    print(f"wrote {OUT} ({len(rows)} rows, {len(cnt)} L3)")
    empty = [l3 for l3 in sorted(l3_info) if cnt.get(l3, 0) == 0]
    if empty:
        print("无已分类物料（跳过）:", ", ".join(empty))
    return 0


if __name__ == "__main__":
    sys.exit(main())
