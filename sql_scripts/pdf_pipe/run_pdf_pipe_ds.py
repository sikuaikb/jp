#!/usr/bin/env python3
"""PDF 抽取直通链路 · 纯 Python 一键编排（海豚调度 / DolphinScheduler 友好）。

特点（相对 run_pdf_pipe.sh）：
  - 只依赖 pymysql，**不依赖 worker 上的 mysql CLI**
  - 凭据全部走环境变量（DS 环境变量管理 / 工作流参数注入），不强制 local.env
  - 分步日志 + 计时 + 行数核对；任一步失败 fail-fast 并返回非 0 退出码（DS 可识别）
  - 幂等：每步按 data_source='pcb_attr_extract_pipe' 删后插，可被 DS 重试 / 补数安全重跑

步骤：
  1) upsert  ods.ods_pdf_extract_component_param → dwd.dwd_pdf_extract_component_param
  2) classify  → dwd.dwd_component_class (data_source=pcb_attr_extract_pipe)
  3) EAV       → dwd.dwd_component_attr_std (同上 data_source)
  4) L2 宽表   → 既有 dwd_l2_*（schema 驱动，复用 build_dwd_l2_pcb_attr_extract_pipe.py）

环境变量：
  必填：MYSQL_HOST  MYSQL_PORT  MYSQL_USER  MYSQL_PASSWORD
  可选：DWD_SCHEMA(默认 dwd)  DIM_SCHEMA(默认 dim)
        SKIP_UPSERT=1 跳过步骤 1
        ONLY_STEPS="2,3,4" 只跑指定步骤（逗号分隔，子集）
        REPO_ROOT 覆盖仓库根（默认按脚本路径推断）

用法：
  python3 sql_scripts/pdf_pipe/run_pdf_pipe_ds.py
  SKIP_UPSERT=1 python3 sql_scripts/pdf_pipe/run_pdf_pipe_ds.py
  ONLY_STEPS=4 python3 sql_scripts/pdf_pipe/run_pdf_pipe_ds.py
"""
from __future__ import annotations

import os
import re
import sys
import time
from pathlib import Path

try:
    import pymysql
except ImportError:
    print("需要 pymysql: pip install pymysql", file=sys.stderr)
    sys.exit(2)

HERE = Path(__file__).resolve().parent
REPO = Path(os.environ.get("REPO_ROOT", HERE.parents[1]))
SQL_ROOT = REPO / "sql_scripts"
LOCAL_ENV = SQL_ROOT / "local.env"
DEV_SECRETS = SQL_ROOT / "local.env.secrets"
DEFAULT_SECRET_ENV = Path("/opt/data_etl_secret/db.env")

DATA_SOURCE = "pcb_attr_extract_pipe"
DWD_SCHEMA = os.environ.get("DWD_SCHEMA", "dwd")
DIM_SCHEMA = os.environ.get("DIM_SCHEMA", "dim")

UPSERT_SQL = SQL_ROOT / "foundation" / "upsert_pdf_extract_component_param_from_ods.sql"
CLASSIFY_SQL = SQL_ROOT / "1.classify" / "build_dwd_component_class_pcb_attr_extract_pipe.sql"
EAV_SQL = SQL_ROOT / "2.attribute_standard" / "build_dwd_component_attr_std_pcb_attr_extract_pipe.sql"

# 复用 schema 驱动的 L2 装配逻辑（与本脚本同目录）
sys.path.insert(0, str(HERE))
import build_dwd_l2_pcb_attr_extract_pipe as l2build  # noqa: E402


def _parse_export_file(path: Path) -> None:
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, _, v = line.partition("=")
        k = k.replace("export ", "").strip()
        v = v.strip().strip("'").strip('"')
        if k and k not in os.environ:
            os.environ[k] = v


def load_env_file() -> None:
    """优先已 export 的 MYSQL_*；Worker 读 Secret；本地读 sql_scripts/local.env。"""
    if os.environ.get("MYSQL_PASSWORD"):
        return

    secret = Path(os.environ.get("ETL_SECRET_ENV_FILE", str(DEFAULT_SECRET_ENV)))
    if secret.is_file():
        _parse_export_file(secret)
        return

    if LOCAL_ENV.is_file():
        _parse_export_file(LOCAL_ENV)
        return

    if DEV_SECRETS.is_file():
        _parse_export_file(DEV_SECRETS)


def require_env() -> None:
    missing = [k for k in ("MYSQL_HOST", "MYSQL_USER", "MYSQL_PASSWORD") if not os.environ.get(k)]
    if missing:
        print(f"缺少必填环境变量: {', '.join(missing)}", file=sys.stderr)
        sys.exit(2)


def connect():
    return pymysql.connect(
        host=os.environ["MYSQL_HOST"],
        port=int(os.environ.get("MYSQL_PORT", "9030")),
        user=os.environ["MYSQL_USER"],
        password=os.environ["MYSQL_PASSWORD"],
        charset="utf8mb4",
        autocommit=True,
    )


def render_schema(sql: str) -> str:
    """SQL 内硬编码 dwd./dim.；若指定非默认 schema，做整词替换（test 场景）。"""
    if DWD_SCHEMA != "dwd":
        sql = re.sub(r"\bdwd\.", f"{DWD_SCHEMA}.", sql)
    if DIM_SCHEMA != "dim":
        sql = re.sub(r"\bdim\.", f"{DIM_SCHEMA}.", sql)
    return sql


def split_statements(text: str) -> list[str]:
    """剥离 /* */ 块注释与 -- 行注释，按行尾 ; 切分（本链路 SQL 无内联分号）。"""
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.DOTALL)
    stmts: list[str] = []
    buf: list[str] = []
    for line in text.splitlines():
        if re.sub(r"^\s*--.*$", "", line).strip() == "" and not buf:
            continue
        buf.append(line)
        if re.sub(r"--.*$", "", line).rstrip().endswith(";"):
            stmt = "\n".join(buf).strip().rstrip(";").strip()
            if stmt:
                stmts.append(stmt)
            buf = []
    tail = "\n".join(buf).strip().rstrip(";").strip()
    if tail:
        stmts.append(tail)
    return stmts


def run_sql_file(cur, path: Path, label: str) -> None:
    if not path.is_file():
        print(f"  [{label}] SQL 文件不存在: {path}", file=sys.stderr)
        raise FileNotFoundError(path)
    sql = render_schema(path.read_text(encoding="utf-8"))
    for stmt in split_statements(sql):
        cur.execute(stmt)
        # DML 打印影响行数；校验 SELECT 打印首行，便于 DS 日志观测
        low = stmt.lstrip().lower()
        if low.startswith(("insert", "delete", "update")):
            print(f"  [{label}] affected={cur.rowcount}")
        elif low.startswith("select"):
            rows = cur.fetchall()
            for r in rows[:20]:
                print(f"  [{label}] {r}")


def step_upsert(cur) -> None:
    print("==> STEP 1 upsert ods → dwd_pdf_extract_component_param")
    run_sql_file(cur, UPSERT_SQL, "upsert")


def step_classify(cur) -> None:
    print("==> STEP 2 classify (pcb_attr_extract_pipe)")
    run_sql_file(cur, CLASSIFY_SQL, "classify")
    n = cur.execute(
        f"SELECT 1 FROM {DWD_SCHEMA}.dwd_component_class WHERE data_source=%s LIMIT 1",
        (DATA_SOURCE,),
    )
    if not n:
        raise RuntimeError("classify 后无 pcb_attr_extract_pipe 行，链路异常")


def step_eav(cur) -> None:
    print("==> STEP 3 EAV (pcb_attr_extract_pipe)")
    run_sql_file(cur, EAV_SQL, "eav")


def step_l2(cur) -> None:
    print("==> STEP 4 L2 wide (schema-driven, all)")
    pairs = l2build.discover_l2_pairs(cur, DWD_SCHEMA)
    if not pairs:
        raise RuntimeError("无 pcb_attr_extract_pipe 分类数据，无法装配 L2")
    ok = 0
    for l1, l2 in pairs:
        if l2build.run_build(cur, DWD_SCHEMA, DIM_SCHEMA, l1, l2):
            ok += 1
    print(f"  [l2] {ok}/{len(pairs)} 张宽表完成")
    if ok == 0:
        raise RuntimeError("所有 L2 宽表装配失败")


STEPS = {
    1: ("upsert", step_upsert),
    2: ("classify", step_classify),
    3: ("eav", step_eav),
    4: ("l2", step_l2),
}


def selected_steps() -> list[int]:
    only = os.environ.get("ONLY_STEPS", "").strip()
    if only:
        want = {int(x) for x in re.split(r"[,\s]+", only) if x}
        steps = sorted(s for s in STEPS if s in want)
    else:
        steps = sorted(STEPS)
    if os.environ.get("SKIP_UPSERT") == "1" and 1 in steps:
        steps.remove(1)
    return steps


def main() -> int:
    load_env_file()
    require_env()
    steps = selected_steps()
    print(
        f"PDF pipe DS runner | dwd={DWD_SCHEMA} dim={DIM_SCHEMA} "
        f"steps={steps} host={os.environ['MYSQL_HOST']}"
    )

    conn = connect()
    cur = conn.cursor()
    try:
        cur.execute("SET query_timeout = 1800")
    except Exception:  # noqa: BLE001  某些版本无该会话变量
        pass

    for s in steps:
        name, fn = STEPS[s]
        t0 = time.time()
        try:
            fn(cur)
        except Exception as exc:  # noqa: BLE001
            print(f"!! STEP {s} ({name}) 失败: {exc}", file=sys.stderr)
            return 1
        print(f"<= STEP {s} ({name}) 完成，用时 {time.time() - t0:.1f}s")

    print("ALL DONE")
    return 0


if __name__ == "__main__":
    sys.exit(main())
