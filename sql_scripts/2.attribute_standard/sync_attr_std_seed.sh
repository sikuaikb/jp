#!/usr/bin/env bash
# Load attribute_standard dim seed (dim_attr_schema / dim_attr_extract_rule / dim_unit_factor)
# 同款流程：DROP+CREATE+INSERT，类似 1.classify/load_seed.sh。
#
# 用法：
#   bash sync_attr_std_seed.sh test                # -> test_dim
#   ALLOW_PROD=1 bash sync_attr_std_seed.sh prod   # -> dim
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
  test) DB="test_dim" ;;
  prod)
    if [[ "${ALLOW_PROD:-0}" != "1" ]]; then
      echo "需要 ALLOW_PROD=1 才能写 prod dim 库" >&2
      exit 1
    fi
    DB="dim" ;;
  --db)
    [[ $# -ge 2 ]] || { echo "missing db name after --db" >&2; exit 2; }
    DB="$2" ;;
  *)
    echo "unknown arg: $1" >&2
    exit 2 ;;
esac

if [[ -z "${MYSQL_PASSWORD:-}" ]]; then
  echo "请设置 MYSQL_PASSWORD 或创建 $ROOT/local.env" >&2
  exit 1
fi

# ============================================================
# Drift Check：sync prod 之前先检查 DB 是否有 CSV 缺失的行（防止覆盖同事手动改动）。
# test 环境总是覆盖（测试库不要数据保留）；prod 跑严格检查。
# 设置 SKIP_DRIFT_CHECK=1 强制跳过（不推荐用于 prod）。
# ============================================================
if [[ "$DB" == "dim" && "${SKIP_DRIFT_CHECK:-0}" != "1" ]]; then
  echo "==> 检查 prod($DB) 与本地 CSV 漂移..."
  if ! python3 "$SCRIPT_DIR/check_seed_drift.py" --db "$DB" --strict; then
    echo "" >&2
    echo "⚠️  DB 有 CSV 缺失的行（only_in_db）——直接 sync 会覆盖丢失！" >&2
    echo "处理方式：" >&2
    echo "  1. 先 reconcile (推荐): python3 $SCRIPT_DIR/pull_seed_drift.py --db $DB --reconcile" >&2
    echo "  2. 确认可丢弃: SKIP_DRIFT_CHECK=1 bash $0 $@" >&2
    exit 1
  fi
fi

echo "==> load_seed -> $DB"
python3 "$SCRIPT_DIR/load_seed.py" --db "$DB"
echo "Done."
