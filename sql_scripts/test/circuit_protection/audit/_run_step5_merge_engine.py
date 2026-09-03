#!/usr/bin/env python3
"""重跑 Step 5 merge 引擎（test_dwd.dwd_component_class_merge_circuit_protection）。"""
from __future__ import annotations

import os
import sys
from pathlib import Path

import pymysql

ROOT = Path(__file__).resolve().parents[1]
ENGINE = Path(__file__).resolve().parents[3] / "1.classify" / "dwd_component_class.sql"
OUT = ROOT / "_step5_merge_engine.sql"
MERGE = "test_dwd.dwd_component_class_merge_circuit_protection"


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    src = ENGINE.read_text(encoding="utf-8")
    OUT.write_text(src.replace("dwd.dwd_component_class", MERGE), encoding="utf-8")

    conn = pymysql.connect(
        host=os.environ.get("MYSQL_HOST", "192.168.19.21"),
        port=int(os.environ.get("MYSQL_PORT", "9030")),
        user=os.environ.get("MYSQL_USER", "root"),
        password=os.environ.get("MYSQL_PASSWORD", ""),
        charset="utf8mb4",
    )
    cur = conn.cursor()
    for stmt in OUT.read_text(encoding="utf-8").split(";"):
        s = stmt.strip()
        if not s or s.startswith("/*"):
            continue
        cur.execute(s)
    conn.commit()
    cur.execute(
        f"""
        SELECT COUNT(*) FROM {MERGE}
        WHERE l1_code='circuit_protection' AND data_source='icpdf'
        """
    )
    print(f"merge icpdf cp rows: {cur.fetchone()[0]:,}")
    conn.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
