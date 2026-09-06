#!/usr/bin/env python3
"""inductor 未映射 brandshort 全量 + jp_brand 母公司扫描"""
from __future__ import annotations

import json
import os
import re
from pathlib import Path

import pymysql

L1 = "inductor"
L2S = ["power_inductor", "hf_chip_inductor", "emi_filter_inductor"]
OUT = Path(__file__).resolve().parent / "brand_unmapped_scan.json"

for line in Path("sql_scripts/local.env").read_text(encoding="utf-8").splitlines():
    if line.strip().startswith("export "):
        k, _, v = line[7:].partition("=")
        os.environ[k] = v.strip().strip("'\"")

conn = pymysql.connect(
    host=os.environ["MYSQL_HOST"], port=int(os.environ["MYSQL_PORT"]),
    user=os.environ["MYSQL_USER"], password=os.environ["MYSQL_PASSWORD"],
    charset="utf8mb4", cursorclass=pymysql.cursors.DictCursor,
)
cur = conn.cursor()

cur.execute(
    f"""
WITH src_param AS (
    SELECT 'icpdf' AS data_source, id, brandshort FROM dwd.dwd_icpdf_component_param
    UNION ALL
    SELECT 'digikey', id, brandshort FROM dwd.dwd_digikey_component_param
)
SELECT p.brandshort,
       COUNT(DISTINCT c.id) AS rows_,
       GROUP_CONCAT(DISTINCT c.data_source ORDER BY c.data_source) AS sources
FROM dwd.dwd_component_class c
JOIN src_param p ON p.data_source = c.data_source AND p.id = c.id
LEFT JOIN dim.v_std_brand_alias a ON a.brand_key = UPPER(TRIM(p.brandshort))
WHERE c.l1_code = '{L1}'
  AND c.l2_code IN ({",".join(repr(x) for x in L2S)})
  AND c.l3_code NOT LIKE 'excluded%'
  AND NULLIF(TRIM(COALESCE(p.brandshort, '')), '') IS NOT NULL
  AND a.brand_id_std IS NULL
GROUP BY p.brandshort
ORDER BY rows_ DESC
"""
)
unmapped = cur.fetchall()
print(f"unmapped brandshort count: {len(unmapped)}")
print(f"unmapped rows total: {sum(r['rows_'] for r in unmapped)}")

# jp_brand scan: tokenize brandshort for LIKE search
cur.execute("SELECT id, name, abbr FROM ods.ods_jp_brand WHERE state = 1")
jp_rows = cur.fetchall()

def norm(s: str) -> str:
    return re.sub(r"[^A-Z0-9]", "", (s or "").upper())

def tokens(brandshort: str) -> list[str]:
    raw = brandshort.upper()
    parts = re.split(r"[,/&\-\.]+|\s+", raw)
    out = []
    for p in parts:
        p = p.strip()
        if len(p) >= 3 and p not in {"INC", "LLC", "LTD", "CORP", "CO", "THE", "AND"}:
            out.append(p)
    if len(norm(raw)) >= 4:
        out.append(norm(raw)[:12])
    return list(dict.fromkeys(out))[:6]

results = []
for row in unmapped:
    bs = row["brandshort"]
    hits = []
    for t in tokens(bs):
        if len(t) < 3:
            continue
        for jp in jp_rows:
            blob = f"{jp['name'] or ''} {jp['abbr'] or ''}".upper()
            if t in blob or t in norm(jp["name"] or ""):
                hits.append({"id": jp["id"], "name": jp["name"], "abbr": jp["abbr"], "token": t})
                break
    # dedupe by id
    seen = set()
    uniq_hits = []
    for h in hits:
        if h["id"] in seen:
            continue
        seen.add(h["id"])
        uniq_hits.append(h)
    action = "A_enrich" if uniq_hits else "B_new"
    results.append({
        "brandshort": bs,
        "rows": row["rows_"],
        "sources": row["sources"],
        "action": action,
        "jp_hits": uniq_hits[:3],
    })
    if len(results) <= 20 or row["rows_"] >= 50:
        print(f"  [{action}] {bs!r} rows={row['rows_']} hits={len(uniq_hits)}")

OUT.write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding="utf-8")
print(f"wrote {OUT}")

a_count = sum(1 for r in results if r["action"] == "A_enrich")
b_count = sum(1 for r in results if r["action"] == "B_new")
print(f"A_enrich={a_count} B_new={b_count}")

conn.close()
