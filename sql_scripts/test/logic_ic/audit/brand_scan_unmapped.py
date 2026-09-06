#!/usr/bin/env python3
"""logic_ic 试点人群未映射 brandshort 扫描 + jp_brand 母公司匹配建议。"""
from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path

import pymysql

sys.stdout.reconfigure(encoding="utf-8")

HERE = Path(__file__).resolve().parents[1]
SQL_ROOT = HERE.parents[1]
OUT = SQL_ROOT / "artifacts" / "logic_ic" / "brand_unmapped_scan.json"


def load_env() -> None:
    for line in (SQL_ROOT / "local.env").read_text(encoding="utf-8").splitlines():
        if line.strip().startswith("export "):
            k, _, v = line.strip()[7:].partition("=")
            os.environ[k] = v.strip().strip("'").strip('"')


def norm(s: str) -> str:
    return re.sub(r"[^A-Z0-9]", "", (s or "").upper())


def tokens(brandshort: str) -> list[str]:
    raw = brandshort.upper()
    parts = re.split(r"[,/&\-\.]+|\s+", raw)
    out: list[str] = []
    for p in parts:
        p = p.strip()
        if len(p) >= 3 and p not in {"INC", "LLC", "LTD", "CORP", "CO", "THE", "AND", "USA"}:
            out.append(p)
    if len(norm(raw)) >= 4:
        out.append(norm(raw)[:16])
    return list(dict.fromkeys(out))[:8]


def main() -> int:
    load_env()
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
        SELECT p.brandshort, COUNT(DISTINCT c.id) AS rows_,
               GROUP_CONCAT(DISTINCT c.l3_code ORDER BY c.l3_code) AS l3s
        FROM test_dwd.dwd_component_class_logic_ic c
        JOIN dwd.dwd_digikey_component_param p ON p.id = c.id
        LEFT JOIN dim.v_std_brand_alias a ON a.brand_key = UPPER(TRIM(p.brandshort))
        WHERE NULLIF(TRIM(COALESCE(p.brandshort, '')), '') IS NOT NULL
          AND a.brand_id_std IS NULL
        GROUP BY p.brandshort
        ORDER BY rows_ DESC
        """
    )
    unmapped = cur.fetchall()

    cur.execute(
        """
        SELECT COUNT(DISTINCT c.id) AS n
        FROM test_dwd.dwd_component_class_logic_ic c
        JOIN dwd.dwd_digikey_component_param p ON p.id = c.id
        WHERE NULLIF(TRIM(COALESCE(p.brandshort, '')), '') IS NOT NULL
        """
    )
    total = int(cur.fetchone()["n"])

    cur.execute("SELECT id, name, abbr FROM ods.ods_jp_brand WHERE state = 1")
    jp_rows = cur.fetchall()

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
        seen: set[int] = set()
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
            "l3s": row["l3s"],
            "action": action,
            "jp_hits": uniq_hits[:3],
        })

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding="utf-8")

    mapped_rows = total - sum(r["rows"] for r in results)
    print(f"total SKU w/ brandshort: {total:,}")
    print(f"unmapped brandshort: {len(results)}  rows: {sum(r['rows'] for r in results):,}")
    print(f"mapped rows: {mapped_rows:,} ({100*mapped_rows/total:.1f}%)")
    a_n = sum(1 for r in results if r["action"] == "A_enrich")
    b_n = sum(1 for r in results if r["action"] == "B_new")
    print(f"A_enrich={a_n}  B_new={b_n}")
    for r in results:
        hits = ", ".join(f"{h['name']}(id={h['id']})" for h in r["jp_hits"][:2]) or "-"
        print(f"  [{r['action']}] {r['rows']:5d}  {r['brandshort']!r}  -> {hits}")
    print(f"wrote {OUT}")
    conn.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
