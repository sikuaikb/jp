#!/usr/bin/env bash
# Load L3 classify dim seed CSV into a StarRocks dim database.
#
# Usage:
#   bash sql_scripts/1.classify/load_seed.sh test       # -> test_dim
#   bash sql_scripts/1.classify/load_seed.sh prod       # -> dim (requires ALLOW_PROD=1)
#   bash sql_scripts/1.classify/load_seed.sh --db <name>
#
# 依赖：MYSQL_HOST / MYSQL_PORT / MYSQL_USER / MYSQL_PASSWORD（来自 sql_scripts/local.env 或外部 shell）
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=/dev/null
[[ -f "$ROOT/local.env" ]] && set -a && source "$ROOT/local.env" && set +a

if [[ $# -lt 1 ]]; then
  echo "usage: $0 test|prod | --db <name>" >&2
  exit 2
fi

case "$1" in
  test)
    DB="test_dim"
    ;;
  prod)
    if [[ "${ALLOW_PROD:-0}" != "1" ]]; then
      echo "需要 ALLOW_PROD=1 才能写 prod dim 库" >&2
      exit 1
    fi
    DB="dim"
    ;;
  --db)
    [[ $# -ge 2 ]] || { echo "missing db name after --db" >&2; exit 2; }
    DB="$2"
    ;;
  *)
    echo "unknown arg: $1" >&2
    exit 2
    ;;
esac

if [[ -z "${MYSQL_PASSWORD:-}" ]]; then
  echo "请设置 MYSQL_PASSWORD 或创建 $ROOT/local.env" >&2
  exit 1
fi

# Drift check (仅 prod 严格；test 总是覆盖；SKIP_DRIFT_CHECK=1 强制跳过)
if [[ "$DB" == "dim" && "${SKIP_DRIFT_CHECK:-0}" != "1" ]]; then
  DRIFT_CHECKER="$ROOT/sql_scripts/2.attribute_standard/check_seed_drift.py"
  if [[ -f "$DRIFT_CHECKER" ]]; then
    echo "==> 检查 prod($DB) 与本地 CSV 漂移..."
    if ! python3 "$DRIFT_CHECKER" --db "$DB" --strict; then
      echo "" >&2
      echo "⚠️  DB 有 CSV 缺失的行 —— 会覆盖丢失！" >&2
      echo "  1. 先 reconcile: python3 sql_scripts/2.attribute_standard/pull_seed_drift.py --db $DB --reconcile" >&2
      echo "  2. 或 SKIP_DRIFT_CHECK=1 bash $0 $@" >&2
      exit 1
    fi
  fi
fi

echo "==> load_seed -> $DB"
python3 "$SCRIPT_DIR/load_seed.py" --db "$DB"
echo "Done."
