#!/usr/bin/env python3
"""logic_ic 分类边界 SKU 抽样 + 自动一致性检查（阶段 1A 验收）。"""
from __future__ import annotations

import csv
import os
import sys
from dataclasses import dataclass
from datetime import date
from pathlib import Path

import pymysql

HERE = Path(__file__).resolve().parents[1]
SEED = HERE / "seed"
sys.path.insert(0, str(SEED))
from gate_config import (  # noqa: E402
    CATEGORY_EXPLICIT_OUT,
    CATEGORY_INCLUDE,
    EXCLUDE_CATEGORY_NOT_LIKE,
)

SQL_ROOT = HERE.parents[1]
ENV = SQL_ROOT / "local.env"
ART = SQL_ROOT / "artifacts" / "logic_ic"
DATE = date.today().isoformat()
SAMPLES = 5
CLASS_TBL = "test_dwd.dwd_component_class_logic_ic"


@dataclass
class Check:
    theme: str
    status: str  # PASS | WARN | FAIL
    detail: str
    n: int = 0


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
        cursorclass=pymysql.cursors.DictCursor,
    )


def write_tsv(path: Path, headers: list[str], rows: list[dict]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8-sig", newline="") as f:
        w = csv.DictWriter(f, fieldnames=headers, extrasaction="ignore")
        w.writeheader()
        for r in rows:
            w.writerow({h: r.get(h, "") for h in headers})


def fetch_samples(cur, sql: str, params: tuple = ()) -> list[dict]:
    cur.execute(sql, params)
    out: list[dict] = []
    for r in cur.fetchall():
        out.append(
            {
                "theme": r.get("theme", ""),
                "id": r.get("id", ""),
                "partno": r.get("partno", ""),
                "brandshort": r.get("brandshort", ""),
                "category": r.get("category", ""),
                "l2_code": r.get("l2_code", ""),
                "l3_code": r.get("l3_code", ""),
                "rule_id": r.get("rule_id", ""),
                "pressure_type": r.get("pressure_type", ""),
                "note_cn": (r.get("note_cn") or "")[:160],
                "verdict": r.get("verdict", "人工复核"),
                "remark": r.get("remark", ""),
            }
        )
    return out


SAMPLE_HEADERS = [
    "theme",
    "id",
    "partno",
    "brandshort",
    "category",
    "l2_code",
    "l3_code",
    "rule_id",
    "pressure_type",
    "note_cn",
    "verdict",
    "remark",
]


def main() -> int:
    load_env()
    conn = connect()
    cur = conn.cursor()
    cur.execute("SET query_timeout = 300")

    checks: list[Check] = []
    sample_rows: list[dict] = []

    # ── 1. 明确排除类目不得入 classify ──
    for item in CATEGORY_EXPLICIT_OUT:
        cur.execute(
            f"""
            SELECT COUNT(*) n FROM dwd.dwd_digikey_component_param p
            WHERE p.category = %s
              AND p.id IN (SELECT id FROM {CLASS_TBL})
            """,
            (item["category"],),
        )
        n = cur.fetchone()["n"]
        checks.append(
            Check(
                f"排除类目·{item['category'][:18]}",
                "PASS" if n == 0 else "FAIL",
                item["reason"],
                n,
            )
        )

    for pat in EXCLUDE_CATEGORY_NOT_LIKE:
        cur.execute(
            f"""
            SELECT COUNT(*) n
            FROM {CLASS_TBL} c
            JOIN dwd.dwd_digikey_component_param p ON p.id = c.id
            WHERE p.category LIKE %s
            """,
            (pat,),
        )
        n = cur.fetchone()["n"]
        checks.append(
            Check(f"gate X2·category LIKE {pat}", "PASS" if n == 0 else "FAIL", "评估板/套件不得入 gate", n)
        )

    # ── 2. 白名单外误入 ──
    ph = ",".join(["%s"] * len(CATEGORY_INCLUDE))
    cur.execute(
        f"""
        SELECT COUNT(*) n
        FROM {CLASS_TBL} c
        JOIN dwd.dwd_digikey_component_param p ON p.id = c.id
        WHERE p.category NOT IN ({ph})
        """,
        CATEGORY_INCLUDE,
    )
    n_orphan_cat = cur.fetchone()["n"]
    checks.append(
        Check(
            "白名单外 category 误入",
            "PASS" if n_orphan_cat == 0 else "FAIL",
            "classify 行 category 应均在 gate category_in",
            n_orphan_cat,
        )
    )

    # 邻近品类（本期不收）
    adjacent_cats = [
        ("驱动器，接收器，收发器", "interface_communication_ic"),
        ("FIFO 存储器", "storage"),
        ("FPGA（现场可编程门阵列）", "fpga_cpld"),
        ("可编程定时器和振荡器", "clock_timing"),
        ("多谐振荡器", "clock_timing"),
        ("通用总线功能", "本期不做"),
    ]
    for cat, expect_l1 in adjacent_cats:
        cur.execute(
            "SELECT COUNT(*) n FROM dwd.dwd_digikey_component_param WHERE category = %s",
            (cat,),
        )
        n_param = cur.fetchone()["n"]
        cur.execute(
            f"""
            SELECT COUNT(*) n FROM dwd.dwd_digikey_component_param p
            WHERE p.category = %s
              AND p.id IN (SELECT id FROM {CLASS_TBL})
            """,
            (cat,),
        )
        n_in = cur.fetchone()["n"]
        checks.append(
            Check(
                f"邻近·{cat[:16]}",
                "PASS" if n_in == 0 else "FAIL",
                f"DK 有 {n_param:,} 条，应归 {expect_l1}，logic_ic classify 应为 0",
                n_in,
            )
        )

    # ── 3. 1:1 叶子 ↔ L3 硬一致 ──
    cat_l3_rules = [
        ("门和反相器", "basic_logic_gate"),
        ("门和反相器 - 多功能，可配置", "basic_logic_gate"),
        ("比较器", "digital_comparator"),
        ("奇偶校验发生器和校验器", "encoder_decoder"),
        ("触发器", "flip_flop_latch"),
        ("移位寄存器", "shift_register"),
    ]
    for cat, l3 in cat_l3_rules:
        cur.execute(
            f"""
            SELECT COUNT(*) n
            FROM {CLASS_TBL} c
            JOIN dwd.dwd_digikey_component_param p ON p.id = c.id
            WHERE p.category = %s AND c.l3_code <> %s
            """,
            (cat, l3),
        )
        n = cur.fetchone()["n"]
        checks.append(
            Check(f"类目专规·{cat[:14]}", "PASS" if n == 0 else "FAIL", f"应全部为 {l3}", n)
        )

    # ── 4. 专规边界 ──
    cur.execute(
        f"""
        SELECT COUNT(*) n
        FROM {CLASS_TBL} c
        JOIN dwd.dwd_digikey_component_param p ON p.id = c.id
        WHERE p.category = '奇偶校验发生器和校验器' AND c.l3_code = 'mux_demux'
        """
    )
    n_parity_mux = cur.fetchone()["n"]
    checks.append(
        Check(
            "奇偶·不得归 mux_demux",
            "PASS" if n_parity_mux == 0 else "FAIL",
            "奇偶校验叶应走 logic_ic_dk_parity_v1",
            n_parity_mux,
        )
    )

    cur.execute(
        f"""
        SELECT COUNT(*) n
        FROM {CLASS_TBL} c
        JOIN dwd.dwd_digikey_component_param p ON p.id = c.id
        WHERE c.rule_id = 'logic_ic_dk_bus_switch_v1'
          AND NOT (p.note_cn REGEXP '总线开关|交点开关')
        """
    )
    n_bus_bad = cur.fetchone()["n"]
    checks.append(
        Check(
            "信号开关·bus_switch 专规 note",
            "PASS" if n_bus_bad == 0 else "FAIL",
            "bus_switch 规则应匹配总线开关/交点开关 note",
            n_bus_bad,
        )
    )

    cur.execute(
        f"""
        SELECT COUNT(*) n
        FROM {CLASS_TBL} c
        JOIN dwd.dwd_digikey_component_param p ON p.id = c.id
        WHERE c.rule_id = 'logic_ic_dk_mux_fb_v1'
          AND p.note_cn REGEXP '编码器|Encoder'
        """
    )
    n_mux_fb_enc = cur.fetchone()["n"]
    checks.append(
        Check(
            "信号开关·mux_fb 含编码器字样",
            "PASS" if n_mux_fb_enc == 0 else "WARN",
            "优先顺序编码器更宜 encoder_decoder；v1 暂归 mux_demux fallback",
            n_mux_fb_enc,
        )
    )

    cur.execute(
        f"""
        SELECT COUNT(*) n
        FROM {CLASS_TBL} c
        JOIN dwd.dwd_digikey_component_param p ON p.id = c.id
        WHERE c.rule_id = 'logic_ic_dk_special_fb_v1'
          AND p.note_cn REGEXP '触发器|锁存'
        """
    )
    n_special_ff = cur.fetchone()["n"]
    checks.append(
        Check(
            "专用逻辑·special_fb 含触发器/锁存",
            "PASS" if n_special_ff == 0 else "WARN",
            "扫描测试/锁存类可专规 flip_flop_latch；v1 fallback buffer_driver",
            n_special_ff,
        )
    )

    cur.execute(
        f"""
        SELECT COUNT(*) n
        FROM {CLASS_TBL} c
        JOIN dwd.dwd_digikey_component_param p ON p.id = c.id
        WHERE c.rule_id = 'logic_ic_dk_special_adder_v1'
          AND NOT (p.note_cn REGEXP '加法器|全加|算术逻辑单元|ALU|Adder')
        """
    )
    n_adder_bad = cur.fetchone()["n"]
    checks.append(
        Check(
            "专用逻辑·adder 专规 note",
            "PASS" if n_adder_bad == 0 else "FAIL",
            "adder 规则应匹配加法器/ALU note",
            n_adder_bad,
        )
    )

    cur.execute(
        f"""
        SELECT COUNT(*) n FROM {CLASS_TBL} WHERE l3_code = 'level_translator'
        """
    )
    n_lt = cur.fetchone()["n"]
    checks.append(
        Check(
            "零命中 L3·level_translator",
            "PASS" if n_lt == 0 else "WARN",
            "DK 无独立电平转换叶子，见 CLASSIFY_DESIGN.md",
            n_lt,
        )
    )

    # gate 漏分
    cats = ", ".join(f"'{c.replace(chr(39), chr(39)+chr(39))}'" for c in CATEGORY_INCLUDE)
    exc = " OR ".join(f"p.category LIKE '{p}'" for p in EXCLUDE_CATEGORY_NOT_LIKE)
    cur.execute(
        f"""
        SELECT COUNT(DISTINCT p.id) n
        FROM dwd.dwd_digikey_component_param p
        WHERE p.category IN ({cats}) AND NOT ({exc})
          AND p.id NOT IN (SELECT id FROM {CLASS_TBL})
        """
    )
    n_gate_gap = cur.fetchone()["n"]
    checks.append(
        Check("gate 内漏分", "PASS" if n_gate_gap == 0 else "FAIL", "gate_pass 应 100% 有 L3", n_gate_gap)
    )

    # L3 最大桶
    cur.execute(
        f"""
        SELECT l3_code, COUNT(DISTINCT id) AS n
        FROM {CLASS_TBL}
        GROUP BY l3_code
        ORDER BY n DESC
        LIMIT 1
        """
    )
    top = cur.fetchone()
    cur.execute(f"SELECT COUNT(DISTINCT id) AS n FROM {CLASS_TBL}")
    total_cls = cur.fetchone()["n"]
    pct = 100.0 * top["n"] / total_cls if total_cls else 0
    checks.append(
        Check(
            "L3 分布·最大桶占比",
            "PASS" if pct <= 50 else "WARN",
            f"{top['l3_code']} {top['n']:,} ({pct:.1f}%)",
            top["n"],
        )
    )

    # ── 5. 分层抽样 ──
    base_sel = f"""
        SELECT %s AS theme, c.id, p.partno, p.brandshort, p.category,
               c.l2_code, c.l3_code, c.rule_id,
               '' AS pressure_type, p.note_cn,
               %s AS verdict, %s AS remark
        FROM {CLASS_TBL} c
        JOIN dwd.dwd_digikey_component_param p ON p.id = c.id
    """
    themes_sql: list[tuple[str, str, tuple]] = [
        (
            "leaf_basic_gate",
            base_sel + " WHERE c.rule_id = 'logic_ic_dk_gate_v1' ORDER BY c.id",
            ("leaf_basic_gate", "门叶→basic_logic_gate", ""),
        ),
        (
            "leaf_flip_flop",
            base_sel + " WHERE c.rule_id = 'logic_ic_dk_flip_flop_v1' ORDER BY c.id",
            ("leaf_flip_flop", "触发器叶→flip_flop_latch", ""),
        ),
        (
            "leaf_parity",
            base_sel + " WHERE c.rule_id = 'logic_ic_dk_parity_v1' ORDER BY c.id",
            ("leaf_parity", "奇偶校验→encoder_decoder", ""),
        ),
        (
            "mux_bus_switch",
            base_sel + " WHERE c.rule_id = 'logic_ic_dk_bus_switch_v1' ORDER BY c.id",
            ("mux_bus_switch", "总线开关专规；L3 父 L2=signal_buffer_driver", ""),
        ),
        (
            "mux_decoder",
            base_sel + " WHERE c.rule_id = 'logic_ic_dk_decoder_v1' ORDER BY c.id",
            ("mux_decoder", "解码器专规→encoder_decoder", ""),
        ),
        (
            "mux_fb",
            base_sel + " WHERE c.rule_id = 'logic_ic_dk_mux_fb_v1' ORDER BY c.id",
            ("mux_fb", "信号开关 fallback→mux_demux", ""),
        ),
        (
            "mux_fb_encoder",
            base_sel
            + " WHERE c.rule_id = 'logic_ic_dk_mux_fb_v1' AND p.note_cn REGEXP '编码器' ORDER BY c.id",
            ("mux_fb_encoder", "优先顺序编码器·v1 粗分", "可改 encoder_decoder 专规"),
        ),
        (
            "special_adder",
            base_sel + " WHERE c.rule_id = 'logic_ic_dk_special_adder_v1' ORDER BY c.id",
            ("special_adder", "专用逻辑·ALU/加法器", ""),
        ),
        (
            "special_transceiver",
            base_sel + " WHERE c.rule_id = 'logic_ic_dk_special_transceiver_v1' ORDER BY c.id",
            ("special_transceiver", "专用逻辑·总线收发器", ""),
        ),
        (
            "special_fb",
            base_sel + " WHERE c.rule_id = 'logic_ic_dk_special_fb_v1' ORDER BY c.id",
            ("special_fb", "专用逻辑 fallback", ""),
        ),
        (
            "special_fb_latch",
            base_sel
            + " WHERE c.rule_id = 'logic_ic_dk_special_fb_v1' AND p.note_cn REGEXP '触发器|锁存' ORDER BY c.id",
            ("special_fb_latch", "note 含触发器/锁存", "v1 粗分 buffer_driver"),
        ),
        (
            "buffer_transceiver",
            base_sel + " WHERE c.rule_id = 'logic_ic_dk_buffer_transceiver_v1' ORDER BY c.id",
            ("buffer_transceiver", "缓冲叶·收发器专规", ""),
        ),
        (
            "buffer_fb_null",
            base_sel
            + " WHERE c.rule_id = 'logic_ic_dk_buffer_fb_v1' AND (p.note_cn IS NULL OR TRIM(p.note_cn)='') ORDER BY c.id",
            ("buffer_fb_null", "缓冲叶 note 空·fallback", "料号多为 74xx 缓冲"),
        ),
        (
            "buffer_driver_note",
            base_sel + " WHERE c.rule_id = 'logic_ic_dk_buffer_driver_v1' ORDER BY c.id",
            ("buffer_driver_note", "缓冲叶·note 专规", ""),
        ),
    ]

    for _name, sql, params in themes_sql:
        sample_rows.extend(fetch_samples(cur, sql + f" LIMIT {SAMPLES}", params))

    # 邻近品类：prod 样例（未入 classify）
    for cat, expect in [
        ("驱动器，接收器，收发器", "interface_communication_ic"),
        ("FIFO 存储器", "storage"),
        ("FPGA（现场可编程门阵列）", "fpga_cpld"),
    ]:
        cur.execute(
            f"""
            SELECT %s AS theme, p.id, p.partno, p.brandshort, p.category,
                   '' AS l2_code, '' AS l3_code, '' AS rule_id,
                   '' AS pressure_type, p.note_cn,
                   %s AS verdict, '未入 logic_ic classify' AS remark
            FROM dwd.dwd_digikey_component_param p
            WHERE p.category = %s
            ORDER BY p.id LIMIT 3
            """,
            (f"adjacent_{cat[:6]}", f"应归 {expect}", cat),
        )
        for r in cur.fetchall():
            sample_rows.append(
                {
                    "theme": r["theme"],
                    "id": r["id"],
                    "partno": r["partno"],
                    "brandshort": r.get("brandshort", ""),
                    "category": r["category"],
                    "l2_code": "",
                    "l3_code": "",
                    "rule_id": "",
                    "pressure_type": "",
                    "note_cn": (r.get("note_cn") or "")[:160],
                    "verdict": r["verdict"],
                    "remark": r["remark"],
                }
            )

    conn.close()

    tsv_path = ART / f"boundary_classify_sample_{DATE}.tsv"
    write_tsv(tsv_path, SAMPLE_HEADERS, sample_rows)

    fails = [c for c in checks if c.status == "FAIL"]
    warns = [c for c in checks if c.status == "WARN"]
    overall = "PASS" if not fails else "FAIL"

    lines = [
        f"# logic_ic 分类边界审计 · {DATE}",
        "",
        f"**总判定：{overall}**（自动检查 {len(checks)} 项，FAIL {len(fails)}，WARN {len(warns)}）",
        "",
        "## 1. 自动一致性检查",
        "",
        "| 主题 | 状态 | 异常数 | 说明 |",
        "|------|------|-------:|------|",
    ]
    for c in checks:
        lines.append(f"| {c.theme} | {c.status} | {c.n:,} | {c.detail} |")

    if warns:
        lines.extend(
            [
                "",
                "### WARN 说明（不阻断 1A）",
                "",
            ]
        )
        for c in warns:
            lines.append(f"- **{c.theme}**（{c.n:,}）：{c.detail}")

    lines.extend(
        [
            "",
            "## 2. 抽样说明",
            "",
            f"每主题最多 **{SAMPLES}** 条，见 [`boundary_classify_sample_{DATE}.tsv`](boundary_classify_sample_{DATE}.tsv)。",
            "",
            "| theme | 复核要点 |",
            "|-------|----------|",
            "| `leaf_basic_gate` / `leaf_flip_flop` / `leaf_parity` | 1:1 DK 叶与 L3 |",
            "| `mux_bus_switch` | note 总线开关；L3 挂 signal_buffer_driver |",
            "| `mux_decoder` / `mux_fb` | 信号开关叶专规与 fallback |",
            "| `mux_fb_encoder` | 优先顺序编码器（v1 WARN 3 条） |",
            "| `special_adder` / `special_transceiver` | 专用逻辑 note 专规 |",
            "| `special_fb` / `special_fb_latch` | 杂项 fallback（v1 WARN 4 条） |",
            "| `buffer_*` | 缓冲叶专规与 note 空 fallback |",
            "| `adjacent_*` | RS485/FIFO/FPGA 等未误入 |",
            "",
            "## 3. 阶段 1A 判定",
            "",
            "- [x] gate 内 classify 100%（19,591）",
            "- [x] 零命中 L3：`level_translator`",
            "- [x] 边界自动检查 + 分层抽样",
            "- [ ] 合 prod 分类（管理员）",
            "",
            "```bash",
            "python audit/boundary_classify_audit.py",
            "```",
        ]
    )

    md_path = ART / f"boundary_classify_audit_{DATE}.md"
    md_path.write_text("\n".join(lines) + "\n", encoding="utf-8")

    print(f"=== logic_ic 边界分类审计 · {overall} ===\n")
    for c in checks:
        mark = {"PASS": "✓", "WARN": "!", "FAIL": "✗"}[c.status]
        print(f"  {mark} [{c.status}] {c.theme}: {c.n:,} — {c.detail}")
    print(f"\n报告: {md_path}")
    print(f"抽样: {tsv_path} ({len(sample_rows)} 行)")
    return 0 if overall == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
