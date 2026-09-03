#!/usr/bin/env python3
"""logic_ic schema 属性 vs DigiKey EAV 落库填充率对照。"""
from __future__ import annotations

import csv
import json
import os
import sys
from collections import Counter
from pathlib import Path

import pymysql

sys.stdout.reconfigure(encoding="utf-8")

HERE = Path(__file__).resolve().parents[1]
SQL_ROOT = HERE.parents[1]
SCHEMA_CSV = HERE / "seed" / "dim_attr_schema_logic_ic.csv"
OUT_TSV = SQL_ROOT / "artifacts" / "logic_ic" / "schema_eav_fill_audit.tsv"
OUT_TSV_CLASSIFIED = SQL_ROOT / "artifacts" / "logic_ic" / "schema_eav_fill_audit_classified.tsv"


def load_env() -> None:
    env = SQL_ROOT / "local.env"
    for line in env.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line.startswith("export "):
            k, _, v = line[7:].partition("=")
            os.environ[k] = v.strip().strip("'").strip('"')


def main() -> int:
    load_env()
    schema = list(csv.DictReader(SCHEMA_CSV.open(encoding="utf-8-sig")))
    conn = pymysql.connect(
        host=os.environ["MYSQL_HOST"],
        port=int(os.environ.get("MYSQL_PORT", "9030")),
        user=os.environ["MYSQL_USER"],
        password=os.environ["MYSQL_PASSWORD"],
        charset="utf8mb4",
        cursorclass=pymysql.cursors.DictCursor,
    )
    cur = conn.cursor()

    cur.execute(
        """
        SELECT COUNT(DISTINCT c.id) AS gate_ids
        FROM test_dwd.dwd_component_class_logic_ic c
        WHERE c.data_source = 'digikey'
        """
    )
    gate_ids = int(cur.fetchone()["gate_ids"])

    cur.execute(
        """
        SELECT e.std_attr_code, COUNT(DISTINCT e.id) AS parts
        FROM test_dwd.dwd_component_attr_std_logic_ic e
        INNER JOIN test_dwd.dwd_component_class_logic_ic c
                ON c.id = e.id AND c.data_source = e.data_source
        WHERE e.data_source = 'digikey'
        GROUP BY e.std_attr_code
        """
    )
    fill_global = {r["std_attr_code"]: int(r["parts"]) for r in cur.fetchall()}

    scope_pop: dict[tuple[str, str], int] = {}
    cur.execute(
        """
        SELECT scope_level, scope_code, COUNT(DISTINCT id) n
        FROM (
            SELECT 'l2' AS scope_level, l2_code AS scope_code, id
            FROM test_dwd.dwd_component_class_logic_ic
            WHERE data_source='digikey'
            UNION ALL
            SELECT 'l3', l3_code, id
            FROM test_dwd.dwd_component_class_logic_ic
            WHERE data_source='digikey'
        ) t
        GROUP BY 1, 2
        """
    )
    for r in cur.fetchall():
        scope_pop[(r["scope_level"], r["scope_code"])] = int(r["n"])

    cur.execute(
        """
        SELECT d.scope_level, d.scope_code, e.std_attr_code, COUNT(DISTINCT e.id) n
        FROM test_dwd.dwd_component_attr_std_logic_ic e
        INNER JOIN test_dwd.dwd_component_class_logic_ic c
                ON c.id = e.id AND c.data_source = e.data_source
        INNER JOIN test_dim.dim_attr_schema_logic_ic d
                ON d.std_attr_code = e.std_attr_code
               AND d.schema_version = e.attr_schema_version
               AND (
                    (d.scope_level = 'l2' AND d.scope_code = c.l2_code)
                 OR (d.scope_level = 'l3' AND d.scope_code = c.l3_code)
               )
        WHERE e.data_source = 'digikey'
        GROUP BY 1, 2, 3
        """
    )
    fill_scoped: dict[tuple[str, str, str], int] = {}
    for r in cur.fetchall():
        fill_scoped[(r["scope_level"], r["scope_code"], r["std_attr_code"])] = int(r["n"])

    rules = list(csv.DictReader((HERE / "seed/dim_attr_extract_rule_logic_ic.csv").open(encoding="utf-8-sig")))
    dk_keys = {r["source_expr"] for r in rules if r["source_kind"] == "prajson2_key_eq"}
    cur.execute(
        """
        SELECT p.prajson
        FROM dwd.dwd_digikey_component_param p
        JOIN test_dwd.dwd_component_class_logic_ic c ON c.id = p.id AND c.data_source = 'digikey'
        LIMIT 5000
        """
    )
    key_hits = Counter()
    for row in cur.fetchall():
        obj = json.loads(row["prajson"]) if isinstance(row["prajson"], str) else row["prajson"]
        if not isinstance(obj, dict):
            continue
        for k in dk_keys:
            if k in obj and str(obj.get(k) or "").strip():
                key_hits[k] += 1

    rows_out = []
    buckets = Counter()
    for s in schema:
        sl, sc, attr = s["scope_level"], s["scope_code"], s["std_attr_code"]
        pop = scope_pop.get((sl, sc), 0)
        filled = fill_scoped.get((sl, sc, attr), 0)
        pct = 100.0 * filled / pop if pop else 0
        if pct >= 50:
            status = "OK"
        elif pct >= 10:
            status = "LOW"
        elif pct > 0:
            status = "SPARSE"
        else:
            status = "ZERO"
        buckets[status] += 1
        rows_out.append({
            "scope_level": sl, "scope_code": sc, "std_attr_code": attr,
            "std_attr_cn": s["std_attr_cn"], "scope_pop": pop, "filled": filled,
            "fill_pct": f"{pct:.1f}", "status": status,
        })

    def write_tsv(path: Path, rows: list[dict]) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        with path.open("w", newline="", encoding="utf-8-sig") as f:
            w = csv.DictWriter(f, fieldnames=list(rows_out[0].keys()))
            w.writeheader()
            w.writerows(sorted(rows, key=lambda r: (r["status"], r["scope_code"], r["std_attr_code"])))

    write_tsv(OUT_TSV, rows_out)
    classified = [r for r in rows_out if int(r["scope_pop"]) > 0]
    classified_buckets = Counter(r["status"] for r in classified)
    write_tsv(OUT_TSV_CLASSIFIED, classified)

    zero_classified = [r for r in classified if r["status"] == "ZERO"]
    ok = [r for r in rows_out if r["status"] == "OK"]

    print(f"gate SKU: {gate_ids:,}")
    print(f"schema 属性行: {len(schema)} (全量) / {len(classified)} (分类已命中 scope)")
    print(f"EAV 有值属性种类: {len(fill_global)}")
    print(f"填充分布(全量): OK(≥50%)={len(ok)} LOW={buckets['LOW']} SPARSE={buckets['SPARSE']} ZERO={buckets['ZERO']}")
    print(
        "填充分布(仅分类命中): "
        f"OK={classified_buckets['OK']} LOW={classified_buckets['LOW']} "
        f"SPARSE={classified_buckets['SPARSE']} ZERO={classified_buckets['ZERO']}"
    )
    print(f"\n=== 仅分类命中 · ZERO 填充 ({len(zero_classified)} 项) ===")
    for r in sorted(zero_classified, key=lambda x: -int(x["scope_pop"]))[:25]:
        print(
            f"  {r['scope_level']}/{r['scope_code']}.{r['std_attr_code']} "
            f"({r['std_attr_cn']}) pop={r['scope_pop']}"
        )

    miss_keys = sorted(dk_keys - set(key_hits))
    print(f"\n=== 规则 DK key 抽样未命中 (n=5000, {len(miss_keys)}/{len(dk_keys)}) ===")
    for k in miss_keys[:15]:
        print(f"  {k}")

    conn.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
