#!/usr/bin/env python3
"""
B6：prod EAV + L2 重建（等价 run_attr_std.sh prod L1_LIST=logic_ic）
需要 ALLOW_PROD=1
"""
from __future__ import annotations

import os
import re
import sys
import time
from pathlib import Path

import pymysql

sys.stdout.reconfigure(encoding="utf-8", errors="replace")

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
ENV = ROOT / "sql_scripts" / "local.env"
STD_DIR = ROOT / "sql_scripts" / "2.attribute_standard"
READY_DIR = STD_DIR / "22_logic_ic_ready"
L1 = "logic_ic"

L2_LIST = [
    "combinational_logic",
    "sequential_logic",
    "signal_buffer_driver",
]

BASELINE = {
    "combinational_logic": 9789,
    "sequential_logic": 7352,
    "signal_buffer_driver": 2450,
}
TOL_PCT = 0.5


def load_env() -> None:
    for line in ENV.read_text(encoding="utf-8").splitlines():
        s = line.strip()
        if s.startswith("export "):
            s = s[7:]
        if "=" in s and not s.startswith("#"):
            k, v = s.split("=", 1)
            os.environ[k.strip()] = v.strip().strip("'").strip('"')


def split_stmts(sql: str) -> list[str]:
    sql = re.sub(r"/\*.*?\*/", "", sql, flags=re.DOTALL)
    parts: list[str] = []
    buf: list[str] = []
    for line in sql.splitlines():
        no_cmt = re.sub(r"^\s*--.*$", "", line)
        buf.append(line)
        if no_cmt.rstrip().endswith(";"):
            stmt = "\n".join(buf).strip().rstrip(";").strip()
            if stmt:
                parts.append(stmt)
            buf = []
    tail = "\n".join(buf).strip().rstrip(";").strip()
    if tail:
        parts.append(tail)
    return parts


def run_sql_file(cur, path: Path, label: str) -> tuple[int, list[str]]:
    text = path.read_text(encoding="utf-8-sig")
    stmts = split_stmts(text)
    ok = 0
    errors: list[str] = []
    for i, stmt in enumerate(stmts, 1):
        head = re.sub(r"\s+", " ", stmt[:100])
        if stmt.upper().startswith("SELECT"):
            continue
        try:
            t0 = time.time()
            cur.execute(stmt)
            elapsed = time.time() - t0
            ok += 1
            if elapsed > 5:
                print(f"    [{label}] stmt {i}/{len(stmts)} OK ({elapsed:.1f}s) {head!r}")
        except Exception as e:
            msg = f"[{label}] stmt {i}: {e} | {head}"
            errors.append(msg)
            print(f"  ❌ {msg[:200]}")
    return ok, errors


def q1(cur, sql: str, params=None):
    cur.execute(sql, params)
    row = cur.fetchone()
    if isinstance(row, dict):
        return next(iter(row.values()))
    return row[0] if row else 0


def main() -> int:
    if os.environ.get("ALLOW_PROD") != "1":
        print("需要 ALLOW_PROD=1")
        return 1

    load_env()
    conn = pymysql.connect(
        host=os.environ["MYSQL_HOST"],
        port=int(os.environ.get("MYSQL_PORT", "9030")),
        user=os.environ["MYSQL_USER"],
        password=os.environ["MYSQL_PASSWORD"],
        charset="utf8mb4",
        autocommit=True,
        init_command="SET pipeline_dop=1",
        cursorclass=pymysql.cursors.DictCursor,
    )
    cur = conn.cursor()
    cur.execute("SET query_timeout = 259200")

    print("=" * 65)
    print(f"B6 · prod EAV + L2 重建  L1={L1}")
    print("=" * 65)
    print("✅ ALLOW_PROD=1\n")

    all_errors: list[str] = []
    skip_eav = os.environ.get("SKIP_EAV", "0") == "1"

    if skip_eav:
        print("[EAV] SKIP_EAV=1，跳过 EAV 重建\n")
    else:
        for src in ("icpdf", "digikey"):
            path = STD_DIR / f"build_dwd_component_attr_std_{src}.sql"
            print(f"[EAV] {src} ← {path.name}")
            t0 = time.time()
            n, errs = run_sql_file(cur, path, f"EAV {src}")
            all_errors.extend(errs)
            print(f"  执行 {n} 条语句 ({time.time() - t0:.1f}s)")

    print()
    for src in ("icpdf", "digikey"):
        n = q1(cur, f"SELECT COUNT(*) FROM dwd.dwd_component_attr_std WHERE data_source=%s", (src,))
        print(f"  prod EAV [{src}]: {n:,} 行")
    n_l1 = q1(
        cur,
        """
        SELECT COUNT(*) FROM dwd.dwd_component_attr_std e
        INNER JOIN dwd.dwd_component_class c
          ON c.id = e.id AND c.data_source = e.data_source
        WHERE c.l1_code = %s
        """,
        (L1,),
    )
    print(f"  prod EAV [{L1} via class join]: {n_l1:,} 行")

    for l2 in L2_LIST:
        sfx = f"{L1}_{l2}"
        ddl = READY_DIR / f"dwd_l2_{sfx}.sql"
        bld = READY_DIR / f"build_dwd_l2_{sfx}.sql"
        print(f"\n[L2] {l2} DDL …")
        n1, e1 = run_sql_file(cur, ddl, f"DDL {l2}")
        all_errors.extend(e1)
        print(f"  DDL {n1} 条")
        print(f"[L2] {l2} build …")
        t0 = time.time()
        n2, e2 = run_sql_file(cur, bld, f"build {l2}")
        all_errors.extend(e2)
        print(f"  build {n2} 条 ({time.time() - t0:.1f}s)")

    print("\n" + "=" * 65)
    print("验收")
    print("=" * 65)

    ok = True
    total = 0
    for l2 in L2_LIST:
        tbl = f"dwd.dwd_l2_{L1}_{l2}"
        n = q1(cur, f"SELECT COUNT(*) FROM {tbl}")
        total += n
        base = BASELINE[l2]
        diff_pct = abs(n - base) / base * 100 if base else 0
        brand_null = q1(cur, f"SELECT COUNT(*) FROM {tbl} WHERE brand IS NULL")
        dt = q1(cur, f"SELECT COUNT(DISTINCT brand) FROM {tbl}")
        di = q1(cur, f"SELECT COUNT(DISTINCT brandid) FROM {tbl}")
        flag = "PASS" if diff_pct <= TOL_PCT and brand_null == 0 else "FAIL"
        if flag == "FAIL":
            ok = False
        print(
            f"  {tbl}: {n:,} (基线 {base:,}, 偏差 {diff_pct:.2f}%) "
            f"brand_null={brand_null} distinct_brand={dt} distinct_brandid={di} [{flag}]"
        )

    base_total = sum(BASELINE.values())
    total_pct = abs(total - base_total) / base_total * 100
    print(f"\n  合计: {total:,} (基线 {base_total:,}, 偏差 {total_pct:.2f}%)")
    print(f"  SQL 错误: {len(all_errors)}")
    print(f"\n  B6 总评: {'✅ PASS' if ok and not all_errors else '❌ FAIL'}")

    cur.close()
    conn.close()
    return 0 if ok and not all_errors else 1


if __name__ == "__main__":
    sys.exit(main())
