#!/usr/bin/env python3
"""logic_ic 阶段 1A：装载 test_dim + 跑 classify + 验收。"""
from __future__ import annotations

import os
import re
import subprocess
import sys
from pathlib import Path

import pymysql

HERE = Path(__file__).resolve().parent
SQL_ROOT = HERE.parents[1]
ENV = SQL_ROOT / "local.env"
EXPECTED_GATE_PASS = 19_591

SPECIALIST_RULE_MIN = {
    "logic_ic_dk_gate_v1": 8_000,
    "logic_ic_dk_flip_flop_v1": 5_000,
    "logic_ic_dk_shift_register_v1": 1_900,
    "logic_ic_dk_buffer_fb_v1": 1_600,
    "logic_ic_dk_parity_v1": 150,
    "logic_ic_dk_bus_switch_v1": 45,
}

GATE_CATEGORIES = [
    "门和反相器",
    "门和反相器 - 多功能，可配置",
    "比较器",
    "奇偶校验发生器和校验器",
    "信号开关，多路复用器，解码器",
    "专用逻辑器件",
    "触发器",
    "移位寄存器",
    "缓冲器，驱动器，接收器，收发器",
]


def load_env() -> None:
    for line in ENV.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line.startswith("export "):
            k, _, v = line[7:].partition("=")
            os.environ[k] = v.strip().strip("'").strip('"')


def connect():
    return pymysql.connect(
        host=os.environ["MYSQL_HOST"],
        port=int(os.environ.get("MYSQL_PORT", "9030")),
        user=os.environ["MYSQL_USER"],
        password=os.environ["MYSQL_PASSWORD"],
        charset="utf8mb4",
        autocommit=True,
        cursorclass=pymysql.cursors.DictCursor,
    )


def split_sql(text: str) -> list[str]:
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.DOTALL)
    parts: list[str] = []
    buf: list[str] = []
    for line in text.splitlines():
        buf.append(line)
        if re.sub(r"^\s*--.*$", "", line).rstrip().endswith(";"):
            stmt = "\n".join(buf).strip().rstrip(";").strip()
            if stmt:
                parts.append(stmt)
            buf = []
    return parts


def exec_file(cur, path: Path) -> None:
    print(f"==> {path.name}")
    for stmt in split_sql(path.read_text(encoding="utf-8")):
        cur.execute(stmt)


def main() -> int:
    load_env()
    subprocess.run([sys.executable, str(HERE / "load_seed_logic_ic.py"), "--db", "test_dim"], check=True)

    conn = connect()
    cur = conn.cursor()
    cur.execute("SET query_timeout = 600")
    exec_file(cur, HERE / "dwd_component_class_logic_ic.sql")
    exec_file(cur, HERE / "build_dwd_digikey_component_class_logic_ic.sql")

    cur.execute("SELECT COUNT(DISTINCT id) AS n FROM test_dwd.dwd_component_class_logic_ic")
    n = cur.fetchone()["n"]
    print(f"\n=== 分类行数: {n:,} (gate 基线 {EXPECTED_GATE_PASS:,}) ===")

    cur.execute(
        """
        SELECT l3_code, l2_code, COUNT(DISTINCT id) AS c
        FROM test_dwd.dwd_component_class_logic_ic
        GROUP BY l3_code, l2_code
        ORDER BY c DESC
        """
    )
    print("\nL3 分布:")
    for r in cur.fetchall():
        print(f"  {r['l2_code']:<28} {r['l3_code']:<30} {r['c']:>8,}")

    ph = ",".join(["%s"] * len(GATE_CATEGORIES))
    cur.execute(
        f"""
        SELECT COUNT(*) AS n
        FROM dwd.dwd_digikey_component_param p
        WHERE p.category IN ({ph})
          AND p.category NOT LIKE '%%评估板%%'
          AND p.category NOT LIKE '%%开发套件%%'
          AND p.id NOT IN (
              SELECT id FROM test_dwd.dwd_component_class_logic_ic
              WHERE data_source = 'digikey'
          )
        """,
        GATE_CATEGORIES,
    )
    uncls = cur.fetchone()["n"]
    print(f"\ngate 白名单未分类: {uncls} (期望 0)")

    cur.execute(
        """
        SELECT COUNT(*) AS n FROM test_dwd.dwd_component_class_logic_ic
        WHERE l3_code IS NULL OR l3_id IS NULL
        """
    )
    null_l3 = cur.fetchone()["n"]
    print(f"无 L3 命中: {null_l3} (期望 0)")

    cur.execute(
        """
        SELECT rule_id, COUNT(DISTINCT id) AS c
        FROM test_dwd.dwd_component_class_logic_ic
        GROUP BY rule_id
        """
    )
    rule_counts = {r["rule_id"]: r["c"] for r in cur.fetchall()}
    print("\n专规 rule_id 命中:")
    specialist_ok = True
    for rule_id, min_c in SPECIALIST_RULE_MIN.items():
        c = rule_counts.get(rule_id, 0)
        ok_row = c >= min_c
        specialist_ok = specialist_ok and ok_row
        mark = "✓" if ok_row else "✗"
        print(f"  {mark} {rule_id}: {c:,} (>= {min_c:,})")

    ok = n == EXPECTED_GATE_PASS and uncls == 0 and null_l3 == 0 and specialist_ok
    print("\n" + ("✅ PASS" if ok else "❌ FAIL"))
    conn.close()
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
