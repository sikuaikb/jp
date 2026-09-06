#!/usr/bin/env python3
"""重新统计 dwd.dwd_l2_* 业务宽表行数（按 data_source 拆分），输出与
docs/DWD_L2_STATS_BY_L1.md 一致的口径。

读取 sql_scripts/local.env 拿连接串（与 brand_merge/_verify_dim.py 同模式）。
支持 digikey / icpdf / ecloud 三源。
"""
from __future__ import annotations
import os, sys
from pathlib import Path
from collections import defaultdict
import pymysql

sys.stdout.reconfigure(encoding="utf-8")

ENV = Path(__file__).resolve().parent / "local.env"
for line in ENV.read_text(encoding="utf-8").splitlines():
    if line.strip().startswith("export "):
        k, _, v = line[7:].partition("=")
        os.environ[k] = v.strip().strip("'").strip('"')

conn = pymysql.connect(
    host=os.environ["MYSQL_HOST"],
    port=int(os.environ.get("MYSQL_PORT", "9030")),
    user=os.environ["MYSQL_USER"],
    password=os.environ["MYSQL_PASSWORD"],
    charset="utf8mb4",
    cursorclass=pymysql.cursors.DictCursor,
)
cur = conn.cursor()

# 1. 拉所有 dwd_l2_* 业务宽表清单
# 排除规则：component_catalog 目录表 + 任何含 _llm_ / _audit / _sample / _result 的辅助表
EXCLUDE_SUBSTRINGS = ("_llm_", "_audit", "_sample", "_result", "component_catalog")

cur.execute("""
    SELECT table_name
    FROM information_schema.tables
    WHERE table_schema = 'dwd'
      AND table_name LIKE 'dwd\\_l2\\_%'
    ORDER BY table_name
""")
all_tables = [r["table_name"] for r in cur.fetchall()]
tables = [t for t in all_tables if not any(s in t for s in EXCLUDE_SUBSTRINGS)]
print(f"# 候选业务宽表 {len(tables)} 张（已排除 {len(all_tables)-len(tables)} 张辅助表）", file=sys.stderr)

# 2. L1 -> L2 表清单（按表名第 3 段抽 L1）
def l1_of(table: str) -> str:
    parts = table.split("_")
    # dwd_l2_<l1>_<l2...>
    if len(parts) < 4:
        return "_unknown"
    # L1 可能多段（如 mcu_mpu_dsp, interface_communication_ic, circuit_protection）
    # 用 doc 已知 27 L1 集合反查
    return "_".join(parts[2:-1])  # 暂用倒数第二段起，下面用 KNOWN_L1 修正

KNOWN_L1 = {
    "connector", "capacitor", "resistor", "diode", "pmic", "transistor", "switch",
    "sensor", "circuit_protection", "logic_ic", "inductor", "clock_timing",
    "optoelectronics", "mcu_mpu_dsp", "relay", "system_module", "data_converter",
    "isolator", "rf_wireless", "filter", "storage", "driver_ic",
    "interface_communication_ic", "fpga_cpld", "acoustic_device", "transformer",
    "amplifier",
}

def extract_l1(table: str) -> str:
    parts = table.split("_")[2:]  # 去掉 dwd_l2_
    # 从最短前缀开始试，匹配 KNOWN_L1
    for n in range(1, len(parts) + 1):
        cand = "_".join(parts[:n])
        if cand in KNOWN_L1:
            return cand
    return "_unknown"

l1_to_tables = defaultdict(list)
for t in tables:
    l1_to_tables[extract_l1(t)].append(t)

# 3. 逐表 COUNT (data_source) —— 用 WHERE data_source=... 分别 COUNT，规避
# StarRocks query cache 导致 GROUP BY 返回多行分片的问题（doc 末尾备注所述）
def count_by_source(table: str) -> dict:
    out = {
        "digikey": 0, "icpdf": 0, "ecloud": 0, "other": 0, "total": 0,
        "dk_distinct": 0, "ic_distinct": 0, "ec_distinct": 0,
    }
    src_prefix = {"digikey": "dk", "icpdf": "ic", "ecloud": "ec"}
    for src in ("digikey", "icpdf", "ecloud"):
        try:
            cur.execute(
                f"SELECT COUNT(*) c, COUNT(DISTINCT mpn) d FROM dwd.{table} "
                f"WHERE data_source='{src}' AND mpn IS NOT NULL AND mpn<>''"
            )
            r = cur.fetchone()
            out[src] = int(r["c"])
            out[f"{src_prefix[src]}_distinct"] = int(r["d"])
        except Exception as e:
            print(f"  [WARN] {table}.{src}: {e}", file=sys.stderr)
    try:
        cur.execute(f"SELECT COUNT(*) c FROM dwd.{table}")
        out["total"] = int(cur.fetchone()["c"])
    except Exception as e:
        print(f"  [WARN] {table} total: {e}", file=sys.stderr)
    out["other"] = out["total"] - out["digikey"] - out["icpdf"] - out["ecloud"]
    return out


# 4. 聚合输出
results = {}  # table -> counts
for l1, tbls in sorted(l1_to_tables.items()):
    for t in tbls:
        results[t] = count_by_source(t)

# 5. 打印汇总（L1 -> 合计）
print("\n=== L1 汇总（按 digikey+icpdf+ecloud 合计倒序） ===")
l1_summary = []
for l1, tbls in l1_to_tables.items():
    dk = sum(results[t]["digikey"] for t in tbls)
    ic = sum(results[t]["icpdf"] for t in tbls)
    ec = sum(results[t]["ecloud"] for t in tbls)
    ot = sum(results[t]["other"] for t in tbls)
    dk_d = sum(results[t]["dk_distinct"] for t in tbls)
    ic_d = sum(results[t]["ic_distinct"] for t in tbls)
    ec_d = sum(results[t]["ec_distinct"] for t in tbls)
    l1_summary.append((l1, len(tbls), dk, ic, ec, ot, dk + ic + ec + ot, dk_d, ic_d, ec_d))
l1_summary.sort(key=lambda r: -r[6])

print(
    f"{'L1':<32} {'表数':>4} {'digikey':>12} {'icpdf':>12} {'ecloud':>12} "
    f"{'other':>10} {'合计':>12} {'dk distinct':>12} {'ic distinct':>12} {'ec distinct':>12}"
)
tot_dk = tot_ic = tot_ec = tot_ot = 0
tot_dk_d = tot_ic_d = tot_ec_d = 0
tot_tables = 0
for l1, n, dk, ic, ec, ot, tot, dk_d, ic_d, ec_d in l1_summary:
    print(
        f"{l1:<32} {n:>4} {dk:>12,} {ic:>12,} {ec:>12,} {ot:>10,} {tot:>12,} "
        f"{dk_d:>12,} {ic_d:>12,} {ec_d:>12,}"
    )
    tot_dk += dk; tot_ic += ic; tot_ec += ec; tot_ot += ot
    tot_dk_d += dk_d; tot_ic_d += ic_d; tot_ec_d += ec_d
    tot_tables += n
print(
    f"{'**合计**':<32} {tot_tables:>4} {tot_dk:>12,} {tot_ic:>12,} {tot_ec:>12,} "
    f"{tot_ot:>10,} {tot_dk+tot_ic+tot_ec+tot_ot:>12,} "
    f"{tot_dk_d:>12,} {tot_ic_d:>12,} {tot_ec_d:>12,}"
)

# 6. 打印每张表明细
print("\n=== 每张表明细 ===")
for l1, tbls in sorted(l1_to_tables.items()):
    print(f"\n### {l1}")
    for t in tbls:
        r = results[t]
        print(
            f"  {t:<70} dk={r['digikey']:>10,}  ic={r['icpdf']:>10,}  "
            f"ec={r['ecloud']:>10,}  other={r['other']:>8,}  total={r['total']:>10,}  "
            f"dk_dist={r['dk_distinct']:>10,}  ic_dist={r['ic_distinct']:>10,}  "
            f"ec_dist={r['ec_distinct']:>10,}"
        )

# 7. 源端总计（用于清洗率）—— 两个口径：行数清洗率 + distinct partno 覆盖率
print("\n=== 源端 param 总量 vs 已清洗 ===")
for src, param_table, cleaned_rows, cleaned_distinct in [
    ("digikey", "dwd.dwd_digikey_component_param", tot_dk, tot_dk_d),
    ("icpdf", "dwd.dwd_icpdf_component_param", tot_ic, tot_ic_d),
    ("ecloud", "dwd.dwd_ecloud_component_param", tot_ec, tot_ec_d),
]:
    try:
        cur.execute(
            f"SELECT COUNT(*) c, COUNT(DISTINCT partno) d FROM {param_table} "
            f"WHERE partno IS NOT NULL AND partno<>''"
        )
        r = cur.fetchone()
        total_rows = int(r["c"])
        src_distinct = int(r["d"])
        row_rate = cleaned_rows / total_rows * 100 if total_rows else 0
        distinct_rate = cleaned_distinct / src_distinct * 100 if src_distinct else 0
        print(f"  {src:<10} 源端行数 {total_rows:>10,}  已清洗行 {cleaned_rows:>10,}  行数清洗率 {row_rate:>5.1f}%")
        print(
            f"  {'':<10} 源端distinct partno {src_distinct:>10,}  已覆盖distinct {cleaned_distinct:>10,}  "
            f"**distinct覆盖率 {distinct_rate:>5.2f}%**  ← 真实清洗完成度"
        )
        print(f"  {'':<10} 未覆盖 distinct partno {src_distinct - cleaned_distinct:>10,}（规则盲区）")
    except Exception as e:
        print(f"  [WARN] {src}: {e}", file=sys.stderr)

conn.close()
