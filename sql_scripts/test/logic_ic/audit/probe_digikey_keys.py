#!/usr/bin/env python3
"""按 L3 统计 DigiKey prajson 顶层 key 频次（logic_ic gate 内 SKU）。"""
from __future__ import annotations

import csv
import json
import os
from collections import Counter
from datetime import date
from pathlib import Path

import pymysql

SQL_ROOT = Path(__file__).resolve().parents[3]
ART = SQL_ROOT / "artifacts" / "logic_ic"
OUT = ART / f"digikey_prajson_keys_by_l3_{date.today()}.tsv"

ADMIN = {
    "DigiKey 零件编号", "ECCN", "HTSUS", "category", "category_path",
    "制造商", "制造商产品编号", "制造商标准包装", "描述", "类别", "系列",
    "详细描述", "零件状态", "Part Number Alias", "包装", "安装类型",
    "湿气敏感性等级 (MSL)", "REACH 状态", "环保信息", "特色产品",
    "RoHS 状态", "PCN 产品变更/停产", "报价表", "计价货币", "库存数量",
    "原厂标准交货期", "基本产品编号", "产品培训模块", "PCN 组装/来源",
    "测试条件", "EDA 模型", "EDA/CAD 模型", "Forum Discussions",
    "其他名称", "PCN 封装", "PCN 设计/规格", "PCN 其他", "PCN 零件状态变更",
}


def load_env() -> None:
    env = SQL_ROOT / "local.env"
    for line in env.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line.startswith("export "):
            k, _, v = line[7:].partition("=")
            os.environ[k] = v.strip().strip("'").strip('"')


def main() -> None:
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
        SELECT c.l2_code, c.l3_code, p.prajson
        FROM test_dwd.dwd_component_class_logic_ic c
        JOIN dwd.dwd_digikey_component_param p ON p.id = c.id
        WHERE c.data_source = 'digikey' AND p.prajson IS NOT NULL
        """
    )
    per_l3: dict[str, Counter] = {}
    for row in cur.fetchall():
        l3 = row["l3_code"]
        pj = json.loads(row["prajson"]) if isinstance(row["prajson"], str) else row["prajson"]
        if not isinstance(pj, dict):
            continue
        c = per_l3.setdefault(l3, Counter())
        for k, v in pj.items():
            if k in ADMIN or not str(v or "").strip():
                continue
            c[k] += 1
    conn.close()

    ART.mkdir(parents=True, exist_ok=True)
    rows_out = []
    for l3 in sorted(per_l3):
        total = sum(per_l3[l3].values())
        for key, n in per_l3[l3].most_common(40):
            rows_out.append({
                "l3_code": l3,
                "prajson_key": key,
                "sku_with_key": n,
                "pct": f"{100.0 * n / max(total, 1):.1f}",
            })

    with OUT.open("w", encoding="utf-8-sig", newline="") as f:
        w = csv.DictWriter(f, fieldnames=["l3_code", "prajson_key", "sku_with_key", "pct"])
        w.writeheader()
        w.writerows(rows_out)

    print(f"wrote {len(rows_out)} rows -> {OUT}")
    for l3 in sorted(per_l3):
        top = ", ".join(k for k, _ in per_l3[l3].most_common(8))
        print(f"  {l3}: {top}")


if __name__ == "__main__":
    main()
