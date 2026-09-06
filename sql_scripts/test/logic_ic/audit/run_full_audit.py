#!/usr/bin/env python3
"""logic_ic 试点整体审计：分类 + 属性 + 品牌门控 → 综合报告。"""
from __future__ import annotations

import os
import subprocess
import sys
from datetime import date
from pathlib import Path

import pymysql

sys.stdout.reconfigure(encoding="utf-8")

HERE = Path(__file__).resolve().parent
LOGIC = HERE.parent
SQL_ROOT = LOGIC.parents[1]
ART = SQL_ROOT / "artifacts" / "logic_ic"
DATE = str(date.today())
REPORT = ART / f"qa_audit_report_logic_ic_full_{DATE}.md"


def load_env() -> None:
    for line in (SQL_ROOT / "local.env").read_text(encoding="utf-8").splitlines():
        if line.strip().startswith("export "):
            k, _, v = line.strip()[7:].partition("=")
            os.environ[k] = v.strip().strip("'").strip('"')


def run_step(cmd: list[str], title: str, cwd: Path | None = None) -> int:
    print(f"\n{'='*60}\n>> {title}\n{'='*60}")
    return subprocess.run(cmd, cwd=cwd or LOGIC).returncode


def query_metrics() -> dict:
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
        SELECT COUNT(DISTINCT id) AS n,
               SUM(CASE WHEN l3_code IS NULL OR TRIM(l3_code) = '' THEN 1 ELSE 0 END) AS null_l3
        FROM test_dwd.dwd_component_class_logic_ic
        """
    )
    cls = cur.fetchone()
    cur.execute(
        """
        SELECT COUNT(DISTINCT c.id) AS total,
               SUM(CASE WHEN NULLIF(TRIM(COALESCE(p.brandshort, '')), '') IS NULL THEN 1 ELSE 0 END) AS empty_bs,
               SUM(CASE WHEN NULLIF(TRIM(COALESCE(p.brandshort, '')), '') IS NOT NULL
                         AND a.brand_id_std IS NULL THEN 1 ELSE 0 END) AS unmapped
        FROM test_dwd.dwd_component_class_logic_ic c
        JOIN dwd.dwd_digikey_component_param p ON p.id = c.id
        LEFT JOIN dim.v_std_brand_alias a ON a.brand_key = UPPER(TRIM(p.brandshort))
        """
    )
    brand = cur.fetchone()

    cur.execute(
        """
        SELECT COUNT(DISTINCT id) AS parts, COUNT(DISTINCT std_attr_code) AS codes
        FROM test_dwd.dwd_component_attr_std_logic_ic
        WHERE data_source = 'digikey'
        """
    )
    eav = cur.fetchone()
    l2_rows: dict[str, int] = {}
    for l2 in ("combinational_logic", "sequential_logic", "signal_buffer_driver"):
        try:
            cur.execute(f"SELECT COUNT(*) n FROM test_dwd.dwd_l2_logic_ic_{l2}")
            l2_rows[l2] = int(cur.fetchone()["n"])
        except Exception:
            l2_rows[l2] = 0

    conn.close()
    with_bs = int(brand["total"]) - int(brand["empty_bs"] or 0)
    mapped = with_bs - int(brand["unmapped"] or 0)
    return {
        "class_rows": int(cls["n"]),
        "null_l3": int(cls["null_l3"] or 0),
        "brand_total": int(brand["total"]),
        "brand_empty": int(brand["empty_bs"] or 0),
        "brand_unmapped": int(brand["unmapped"] or 0),
        "brand_mapped_pct": 100.0 * mapped / with_bs if with_bs else 100.0,
        "eav_parts": int(eav["parts"] or 0),
        "eav_codes": int(eav["codes"] or 0),
        "l2_rows": l2_rows,
    }


def read_report_status(path: Path, marker: str = "总判定") -> str:
    if not path.exists():
        return "N/A"
    for line in path.read_text(encoding="utf-8").splitlines():
        if marker in line and ("PASS" in line or "FAIL" in line or "WARN" in line):
            if "PASS" in line:
                return "PASS"
            if "FAIL" in line:
                return "FAIL"
            if "WARN" in line:
                return "WARN"
    return "?"


def main() -> int:
    load_env()
    ART.mkdir(parents=True, exist_ok=True)
    py = sys.executable

    rc = 0
    rc |= run_step([py, str(HERE / "brand_prod_gap_check.py")], "品牌 prod 缺口检查")
    rc |= subprocess.run(
        [py, str(HERE / "apply_brand_supplement.py"), "--both"],
        cwd=LOGIC,
        env={**os.environ, "ALLOW_PROD": os.environ.get("ALLOW_PROD", "1")},
    ).returncode
    rc |= run_step([py, str(LOGIC / "run_test_logic_ic.py")], "1A 分类验收")
    rc |= run_step([py, str(HERE / "audit_classify_coverage.py")], "分类覆盖核查")
    rc |= run_step([py, str(HERE / "boundary_classify_audit.py")], "分类边界审计")
    rc |= run_step([py, str(HERE / "run_attr_audit.py")], "1B 属性 prajson 审计")
    rc |= run_step([py, str(LOGIC / "run_test_logic_ic_attr.py")], "1B EAV + L2 宽表")
    rc |= run_step([py, str(HERE / "brand_gate_audit.py")], "品牌门控 brandshort")
    rc |= run_step([py, str(HERE / "brand_l2_gate_audit.py")], "品牌门控 L2 宽表")

    m = query_metrics()
    classify_ok = m["class_rows"] == 19_591 and m["null_l3"] == 0
    brand_ok = m["brand_unmapped"] == 0
    eav_parts = m["eav_parts"]
    eav_codes = m["eav_codes"]
    l2_rows = m["l2_rows"]

    boundary_status = read_report_status(ART / f"boundary_classify_audit_{DATE}.md")
    attr_status = read_report_status(ART / f"qa_audit_report_logic_ic_attr_{DATE}.md")
    brand_status = read_report_status(ART / f"brand_gate_audit_{DATE}.md", "判定")

    overall = "PASS"
    if not classify_ok or boundary_status == "FAIL" or attr_status == "FAIL" or brand_status == "FAIL":
        overall = "FAIL"
    elif boundary_status == "WARN" or attr_status == "WARN":
        overall = "WARN"

    lines = [
        f"# logic_ic 试点整体审计报告",
        f"**日期**: {DATE}",
        "",
        f"**总判定：{overall}**",
        "",
        "## 1. 子审计结果",
        "",
        "| 阶段 | 脚本 | 判定 |",
        "|------|------|------|",
        f"| 1A 分类验收 | `run_test_logic_ic.py` | {'PASS' if classify_ok else 'FAIL'} |",
        f"| 分类覆盖 | `audit_classify_coverage.py` | {'PASS' if classify_ok else 'FAIL'} |",
        f"| 分类边界 | `boundary_classify_audit.py` | {boundary_status} |",
        f"| 1B 属性 prajson | `run_attr_audit.py` | {attr_status} |",
        f"| 1B EAV+L2 | `run_test_logic_ic_attr.py` | {'PASS' if eav_parts >= 16_000 and sum(l2_rows.values()) == m['class_rows'] else 'WARN'} |",
        f"| 品牌门控 | `brand_gate_audit.py` | {brand_status} |",
        "",
        "## 2. 核心指标",
        "",
        "| 指标 | 值 |",
        "|------|-----:|",
        f"| 分类行数 | {m['class_rows']:,} |",
        f"| null_l3 | {m['null_l3']:,} |",
        f"| 试点 SKU | {m['brand_total']:,} |",
        f"| brandshort 空 | {m['brand_empty']:,} |",
        f"| brandshort 已映射 | {m['brand_mapped_pct']:.1f}% |",
        f"| brandshort 未映射 SKU | {m['brand_unmapped']:,} |",
        f"| EAV 覆盖器件 | {eav_parts:,} |",
        f"| EAV 属性种类 | {eav_codes} |",
        f"| L2 combinational_logic | {l2_rows.get('combinational_logic', 0):,} |",
        f"| L2 sequential_logic | {l2_rows.get('sequential_logic', 0):,} |",
        f"| L2 signal_buffer_driver | {l2_rows.get('signal_buffer_driver', 0):,} |",
        "",
        "## 3. 子报告索引",
        "",
        f"- [`boundary_classify_audit_{DATE}.md`](boundary_classify_audit_{DATE}.md)",
        f"- [`qa_audit_report_logic_ic_attr_{DATE}.md`](qa_audit_report_logic_ic_attr_{DATE}.md)",
        f"- [`l3_prajson_schema_full_audit_{DATE}.md`](l3_prajson_schema_full_audit_{DATE}.md)",
        f"- [`l3_prajson_sample_analysis_{DATE}.md`](l3_prajson_sample_analysis_{DATE}.md)",
        f"- [`brand_gate_audit_{DATE}.md`](brand_gate_audit_{DATE}.md)",
        f"- [`schema_eav_fill_audit_classified.tsv`](schema_eav_fill_audit_classified.tsv)",
        "",
        "## 4. 待办",
        "",
        "- 合 prod（管理员）",
        "- `level_translator` 零命中（DK 无独立叶，预期）",
        "",
        "```bash",
        "python audit/run_full_audit.py",
        "```",
    ]
    REPORT.write_text("\n".join(lines), encoding="utf-8")

    print(f"\n{'='*60}")
    print(f"总判定: {overall}")
    print(f"综合报告: {REPORT}")
    return 0 if overall == "PASS" else (1 if overall == "FAIL" else 2)


if __name__ == "__main__":
    sys.exit(main())
