"""Mirror sync_dim_std_brand.sh for Windows (no bash/mysql client).

Usage:
  python sql_scripts/test/_sync_dim_std_brand_py.py test
  ALLOW_PROD=1 python sql_scripts/test/_sync_dim_std_brand_py.py prod
"""
import os
import re
import subprocess
import sys
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")
ROOT = Path(__file__).resolve().parents[1]  # sql_scripts
SCRIPT_DIR = ROOT / "2.attribute_standard"
REPO = ROOT.parent
sys.path.insert(0, str(Path(__file__).resolve().parent))

for line in (ROOT / "local.env").read_text(encoding="utf-8").splitlines():
    if line.strip().startswith("export "):
        k, _, v = line[7:].partition("=")
        os.environ.setdefault(k, v.strip().strip("'").strip('"'))

from _sql_split import split_statements  # noqa: E402

env_name = (sys.argv[1] if len(sys.argv) > 1 else "test").lower()
if env_name == "test":
    db = "test_dim"
elif env_name == "prod":
    if os.environ.get("ALLOW_PROD") != "1":
        print("需要 ALLOW_PROD=1 才能写 prod dim。", file=sys.stderr)
        sys.exit(1)
    db = "dim"
else:
    print("usage: _sync_dim_std_brand_py.py test|prod", file=sys.stderr)
    sys.exit(2)

import pymysql

host = os.environ.get("MYSQL_HOST", "192.168.19.21")
port = int(os.environ.get("MYSQL_PORT", "9030"))
user = os.environ.get("MYSQL_USER", "root")
password = os.environ["MYSQL_PASSWORD"]

FILES = [
    "dim_std_brand.sql",
    "dim_std_brand_manual_extra.sql",
    "dim_std_brand_manual_extra_stage25.sql",
    "dim_std_brand_dup_merge.sql",
    "dim_brand_origin.sql",
    "dim_brand_origin_extra.sql",
    # orphan cleanup: _repair_brand_origin.py (StarRocks DELETE JOIN 不可用；顺带修错表模型)
    "brand_origin_backfill.sql",
    "v_std_brand_alias.sql",
]


def rewrite_dim(sql: str) -> str:
    return sql.replace("dim.", f"{db}.")


def main():
    conn = pymysql.connect(
        host=host, port=port, user=user, password=password,
        charset="utf8mb4", autocommit=True,
        cursorclass=pymysql.cursors.DictCursor,
    )
    cur = conn.cursor()

    for fname in FILES:
        path = SCRIPT_DIR / fname
        print(f"==> {fname} -> {db}")
        raw = path.read_text(encoding="utf-8")
        sql = rewrite_dim(raw)
        stmts = split_statements(sql)
        n_exec = 0
        for idx, stmt in enumerate(stmts, 1):
            body = re.sub(r"/\*.*?\*/", "", stmt, flags=re.S)
            body = re.sub(r"--.*?$", "", body, flags=re.M).strip()
            if not body:
                continue
            n_exec += 1
            try:
                cur.execute(stmt)
            except Exception as e:
                preview = body[:240].replace("\n", " ")
                print(f"FAIL {fname} stmt#{idx} exec#{n_exec}: {e}\n  SQL: {preview}...", file=sys.stderr)
                m = re.search(r"job_id=(\d+)", str(e))
                if m:
                    try:
                        cur.execute(
                            "select tracking_log from information_schema.load_tracking_logs "
                            f"where job_id={m.group(1)}"
                        )
                        for r in cur.fetchall():
                            log = r.get("tracking_log") or ""
                            print(f"TRACK: {log[:3000]}", file=sys.stderr)
                    except Exception as e2:
                        print(f"TRACK fetch failed: {e2}", file=sys.stderr)
                conn.close()
                sys.exit(1)
        print(f"    ok ({n_exec} statements)")

        # after origin_extra: repair PK model + purge orphans before backfill
        if fname == "dim_brand_origin_extra.sql":
            repair = Path(__file__).resolve().parent / "_repair_brand_origin.py"
            print(f"==> _repair_brand_origin.py {env_name}")
            rc = subprocess.call([sys.executable, str(repair), env_name], env=os.environ.copy())
            if rc != 0:
                print("产地表修复/清孤儿失败", file=sys.stderr)
                conn.close()
                sys.exit(rc)

    validator = REPO / ".cursor/skills/component-etl-methodology/tools/validate_brand_dim_dup.py"
    print(f"==> 品牌查重校验 ({db})")
    rc = subprocess.call([sys.executable, str(validator), "--dim-schema", db])
    if rc != 0:
        print("品牌查重校验未通过", file=sys.stderr)
        sys.exit(rc)

    print("Done.")
    conn.close()


if __name__ == "__main__":
    main()
