#!/usr/bin/env python3
"""改名后分类结果完整性：无重复行、无丢数、L3/rule 分布与基线一致。"""
from __future__ import annotations

import os
import sys
from pathlib import Path

import pymysql

HERE = Path(__file__).resolve().parents[1]
SQL_ROOT = HERE.parents[1]
EXPECTED_DISTINCT = 19_591

# 改名前 v1 基线（logic_dk_* 时期 run_test 输出，仅 rule_id 字符串不同）
BASELINE_L3 = {
    "basic_logic_gate": 9_045,
    "flip_flop_latch": 5_344,
    "buffer_driver": 2_182,
    "shift_register": 1_999,
    "digital_comparator": 364,
    "encoder_decoder": 282,
    "bus_transceiver": 206,
    "mux_demux": 67,
    "bus_switch": 62,
    "alu_adder": 31,
    "register": 8,
    "counter_divider": 1,
}

BASELINE_RULE = {
    "logic_ic_dk_gate_v1": 8_198,
    "logic_ic_dk_flip_flop_v1": 5_337,
    "logic_ic_dk_shift_register_v1": 1_999,
    "logic_ic_dk_buffer_fb_v1": 1_651,
    "logic_ic_dk_config_gate_v1": 847,
    "logic_ic_dk_comparator_v1": 353,
    "logic_ic_dk_buffer_driver_v1": 347,
    "logic_ic_dk_buffer_transceiver_v1": 182,
    "logic_ic_dk_parity_v1": 163,
    "logic_ic_dk_decoder_v1": 116,
    "logic_ic_dk_bus_switch_v1": 62,
    "logic_ic_dk_mux_v1": 60,
    "logic_ic_dk_special_regbuf_v1": 89,
    "logic_ic_dk_special_buffer_v1": 59,
    "logic_ic_dk_special_fb_v1": 36,
    "logic_ic_dk_special_adder_v1": 31,
    "logic_ic_dk_special_transceiver_v1": 24,
    "logic_ic_dk_mux_fb_v1": 7,
    "logic_ic_dk_mux_encoder_v1": 3,
    "logic_ic_dk_special_comparator_v1": 11,
    "logic_ic_dk_special_register_v1": 8,
    "logic_ic_dk_special_flipflop_v1": 7,
    "logic_ic_dk_special_counter_v1": 1,
}

TBL = "test_dwd.dwd_component_class_logic_ic"


def load_env() -> None:
    for line in (SQL_ROOT / "local.env").read_text(encoding="utf-8").splitlines():
        if line.strip().startswith("export "):
            k, _, v = line.strip()[7:].partition("=")
            os.environ[k] = v.strip().strip("'").strip('"')


def main() -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
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
    ok = True

    print("=== logic_ic 分类行完整性（改名后）===\n")

    cur.execute(f"SELECT COUNT(*) AS n, COUNT(DISTINCT id) AS d FROM {TBL}")
    r = cur.fetchone()
    total, distinct = int(r["n"]), int(r["d"])
    print(f"COUNT(*)           = {total:,}")
    print(f"COUNT(DISTINCT id) = {distinct:,}  (期望 {EXPECTED_DISTINCT:,})")
    if total != distinct:
        ok = False
        print("  FAIL  存在重复 id（同一 SKU 多行分类）")
        cur.execute(
            f"""
            SELECT id, COUNT(*) AS c FROM {TBL}
            GROUP BY id HAVING COUNT(*) > 1
            ORDER BY c DESC LIMIT 10
            """
        )
        for row in cur.fetchall():
            print(f"    id={row['id']}  rows={row['c']}")
    else:
        print("  PASS  无重复行")

    if distinct != EXPECTED_DISTINCT:
        ok = False
        print(f"  FAIL  器件数偏差 {distinct - EXPECTED_DISTINCT:+,}")
    else:
        print("  PASS  器件数与 gate 基线一致")

    # 旧 rule_id 残留（test_dim / DWD）
    for label, sql in [
        ("test_dim 旧 logic_dk_*", "SELECT COUNT(*) AS n FROM test_dim.dim_l3_classify_rule_logic_ic WHERE rule_id LIKE 'logic_dk_%'"),
        ("DWD 旧 logic_dk_* rule_id", f"SELECT COUNT(*) AS n FROM {TBL} WHERE rule_id LIKE 'logic_dk_%'"),
    ]:
        cur.execute(sql)
        n = int(cur.fetchone()["n"])
        mark = "PASS" if n == 0 else "FAIL"
        if n != 0:
            ok = False
        print(f"  {mark}  {label}: {n}")

    print("\n--- L3 分布 vs 基线 ---")
    cur.execute(
        f"""
        SELECT l3_code, COUNT(DISTINCT id) AS n
        FROM {TBL} GROUP BY 1 ORDER BY n DESC
        """
    )
    actual_l3 = {r["l3_code"]: int(r["n"]) for r in cur.fetchall()}
    all_l3 = sorted(set(BASELINE_L3) | set(actual_l3))
    for code in all_l3:
        exp = BASELINE_L3.get(code)
        act = actual_l3.get(code, 0)
        if exp is None:
            ok = False
            print(f"  FAIL  新增 L3 {code}: {act:,}（基线无）")
        elif act != exp:
            ok = False
            print(f"  FAIL  {code}: {act:,} vs 基线 {exp:,} ({act - exp:+,})")
        else:
            print(f"  PASS  {code}: {act:,}")

    print("\n--- rule_id 命中 vs 基线 ---")
    cur.execute(
        f"""
        SELECT rule_id, COUNT(DISTINCT id) AS n
        FROM {TBL} GROUP BY 1 ORDER BY n DESC
        """
    )
    actual_rule = {r["rule_id"]: int(r["n"]) for r in cur.fetchall()}
    for rid, exp in sorted(BASELINE_RULE.items(), key=lambda x: -x[1]):
        act = actual_rule.get(rid, 0)
        if act != exp:
            ok = False
            print(f"  FAIL  {rid}: {act:,} vs {exp:,} ({act - exp:+,})")
        else:
            print(f"  PASS  {rid}: {act:,}")

    extra_rules = set(actual_rule) - set(BASELINE_RULE)
    if extra_rules:
        ok = False
        for rid in sorted(extra_rules):
            print(f"  FAIL  基线外 rule_id {rid}: {actual_rule[rid]:,}")

    conn.close()
    print("\n" + ("✅ PASS" if ok else "❌ FAIL"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
