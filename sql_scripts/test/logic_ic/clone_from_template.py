#!/usr/bin/env python3
"""从 rf_wireless 模板克隆 logic_ic 脚本。"""
from pathlib import Path
import csv
import os
import re
import pymysql

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
src = REPO / "sql_scripts/test/rf_wireless"
dst = HERE

L1 = "logic_ic"
READY = "22_logic_ic_ready"
L2_LIST = ["combinational_logic", "sequential_logic", "signal_buffer_driver"]

ENV = REPO / "sql_scripts" / "local.env"
for line in ENV.read_text(encoding="utf-8").splitlines():
    s = line.strip()
    if s.startswith("export "):
        s = s[7:]
    if "=" in s and not s.startswith("#"):
        k, v = s.split("=", 1)
        os.environ[k.strip()] = v.strip().strip("'").strip('"')

with (HERE / "seed" / f"dim_l3_classify_{L1}.csv").open(encoding="utf-8-sig") as f:
    rows = list(csv.DictReader(f))
    l1_prefix = rows[0]["l3_id"][:2] if rows else "22"

conn = pymysql.connect(
    host=os.environ["MYSQL_HOST"],
    port=int(os.environ.get("MYSQL_PORT", "9030")),
    user=os.environ["MYSQL_USER"],
    password=os.environ["MYSQL_PASSWORD"],
    charset="utf8mb4",
    init_command="SET pipeline_dop=1",
    cursorclass=pymysql.cursors.DictCursor,
)
cur = conn.cursor()
cur.execute(
    "SELECT COUNT(*) n FROM dwd.dwd_component_class WHERE l1_code=%s AND data_source='digikey'",
    (L1,),
)
cls_n = cur.fetchone()["n"]
BASELINE = {}
for l2 in L2_LIST:
    cur.execute(f"SELECT COUNT(*) n FROM dwd.dwd_l2_{L1}_{l2}")
    BASELINE[l2] = cur.fetchone()["n"]
cur.close()
conn.close()

REPL = {
    "07_rf_wireless_ready": READY,
    "26_optoelectronics_ready": READY,
    "20_storage_ready": READY,
    "07_storage_ready": READY,
    "07_rf_wireless": "22_logic_ic",
    "26_optoelectronics": "22_logic_ic",
    "20_storage": "22_logic_ic",
    "07_storage": "22_logic_ic",
    "optoelectronics": L1,
    "storage": L1,
    "rf_wireless": L1,
    'L1_PREFIX = "07"': f'L1_PREFIX = "{l1_prefix}"',
    "39,263": f"{cls_n:,}",
    "37,000-41,000": f"{max(0, cls_n-2000):,}-{cls_n+2000:,}",
    "13个in-scope类别": f"{len(rows)}个L3",
}
ORDERED = sorted(REPL.items(), key=lambda x: -len(x[0]))


def sub(text: str) -> str:
    for a, b in ORDERED:
        text = text.replace(a, b)
    l2_lines = ",\n".join(f'    "{x}"' for x in L2_LIST)
    text = re.sub(r"L2_LIST = \[.*?\]", f"L2_LIST = [\n{l2_lines},\n]", text, count=1, flags=re.S)
    bl = ",\n".join(f'    "{k}": {v}' for k, v in BASELINE.items())
    text = re.sub(r"BASELINE = \{.*?\}", f"BASELINE = {{\n{bl},\n}}", text, count=1, flags=re.S)
    text = text.replace("20_storage_ready", READY).replace("07_storage_ready", READY)
    return text


for name in ["dim_l3_classify_rf_wireless.sql", "dim_l3_classify_rule_rf_wireless.sql"]:
    (dst / name.replace("rf_wireless", L1)).write_text(
        sub((src / name).read_text(encoding="utf-8")), encoding="utf-8"
    )

for name in [
    "load_seed_rf_wireless.py",
    "run_classify_rf_wireless.py",
    "gen_l2_ready_scripts.py",
    "run_b6_prod.py",
    "cleanup_test_tables.py",
]:
    (dst / name.replace("rf_wireless", L1)).write_text(
        sub((src / name).read_text(encoding="utf-8")), encoding="utf-8"
    )

print(f"done classify={cls_n:,} prefix={l1_prefix} baselines={BASELINE}")
