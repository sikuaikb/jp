"""合引擎 + classify：baseline → test_dwd 验证 → prod 重跑 → 校验。"""
import os
import sys
from datetime import datetime
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")

REPO = Path(__file__).resolve().parents[2]
ENV = REPO / "sql_scripts" / "local.env"
for line in ENV.read_text(encoding="utf-8").splitlines():
    if line.strip().startswith("export "):
        k, _, v = line[7:].partition("=")
        os.environ[k] = v.strip().strip("'").strip('"')

import pymysql

ALLOW_PROD = os.environ.get("ALLOW_PROD", "") == "1"
STEP = os.environ.get("CLASSIFY_STEP", "all")
MERGE_TBL = "test_dwd.dwd_component_class_merge_dc_engine"

conn = pymysql.connect(
    host=os.environ["MYSQL_HOST"],
    port=int(os.environ.get("MYSQL_PORT", "9030")),
    user=os.environ["MYSQL_USER"],
    password=os.environ["MYSQL_PASSWORD"],
    charset="utf8mb4",
    cursorclass=pymysql.cursors.DictCursor,
    autocommit=True,
)
cur = conn.cursor()


def exec_sql_file(path):
    text = Path(path).read_text(encoding="utf-8")
    buf = []
    for line in text.splitlines():
        if line.strip().startswith("--"):
            continue
        buf.append(line)
        if line.strip().endswith(";"):
            stmt = "\n".join(buf).strip()
            buf = []
            if stmt:
                try:
                    cur.execute(stmt)
                except pymysql.err.OperationalError as e:
                    if "already exists" in str(e).lower():
                        pass
                    else:
                        raise
    if buf:
        stmt = "\n".join(buf).strip()
        if stmt:
            cur.execute(stmt)


def l1_counts(schema, table):
    cur.execute(
        f"SELECT data_source, l1_code, COUNT(DISTINCT id) n "
        f"FROM {schema}.{table} GROUP BY 1, 2 ORDER BY 1, 2"
    )
    return {(r["data_source"], r["l1_code"]): r["n"] for r in cur.fetchall()}


def section(t):
    print(f"\n=== {t} ===")


section("Step 0: prod 基线（重跑前）")
baseline = l1_counts("dwd", "dwd_component_class")
dc_before = baseline.get(("digikey", "data_converter"), 0)
print(f"  digikey.data_converter: {dc_before:,}")
print(f"  全 L1 条目: {len(baseline)}")

if STEP in ("all", "test"):
    section("Step 5: test_dwd merge 验证")
    cur.execute(f"DROP TABLE IF EXISTS {MERGE_TBL}")
    src = (REPO / "sql_scripts/1.classify/dwd_component_class.sql").read_text(encoding="utf-8")
    sql = src.replace("dwd.dwd_component_class", MERGE_TBL)
    tmp = REPO / "sql_scripts/test/_classify_merge_dc_engine.sql"
    tmp.write_text(sql, encoding="utf-8")
    print(f"  执行 {tmp.name} ...")
    exec_sql_file(tmp)
    merge = l1_counts("test_dwd", "dwd_component_class_merge_dc_engine")
    dc_merge = merge.get(("digikey", "data_converter"), 0)
    diff_pct = abs(dc_merge - dc_before) / max(dc_before, 1) * 100
    print(f"  merge digikey.data_converter: {dc_merge:,} (baseline {dc_before:,}, diff {diff_pct:.2f}%)")
    ok = True
    for key, b in baseline.items():
        m = merge.get(key, 0)
        d = abs(m - b) / max(b, 1) * 100
        flag = "OK" if d <= 0.5 else "DRIFT"
        if d > 0.5:
            ok = False
        if key[1] in ("data_converter", "pmic", "resistor", "capacitor") or d > 0.5:
            print(f"    {key[0]}.{key[1]}: merge={m:,} baseline={b:,} diff={d:.2f}% [{flag}]")
    if not ok:
        print("\n  WARN: 存在 L1 漂移 >0.5%，请人工确认后再写 prod")
        if STEP == "test":
            sys.exit(1)

if STEP in ("all", "prod"):
    if not ALLOW_PROD:
        print("\nStep 6 跳过: 需 ALLOW_PROD=1")
        sys.exit(0)
    section("Step 6: prod classify 重跑")
    print("  执行 dwd_component_class.sql ...")
    exec_sql_file(REPO / "sql_scripts/1.classify/dwd_component_class.sql")
    after = l1_counts("dwd", "dwd_component_class")
    dc_after = after.get(("digikey", "data_converter"), 0)
    print(f"  digikey.data_converter: {dc_after:,} (was {dc_before:,})")
    drift = False
    for key, b in baseline.items():
        a = after.get(key, 0)
        d = abs(a - b) / max(b, 1) * 100
        if d > 0.5:
            drift = True
            print(f"    DRIFT {key[0]}.{key[1]}: {b:,} -> {a:,} ({d:.2f}%)")
    if not drift:
        print("  全 L1 漂移 <= 0.5%")

conn.close()
print("\n完成")
