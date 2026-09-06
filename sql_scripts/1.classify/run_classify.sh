#!/usr/bin/env bash
# 【L3 分类·多源单脚本版】写入 dwd.dwd_component_class（含 data_source 列）
#
# 流程：
#   1) load_seed.sh <env>        ← DROP+CREATE dim.dim_l3_classify(_rule) 并从 seed/ CSV 全量装载
#   2) dwd_component_class.sql   ← 一条多源 INSERT：DELETE WHERE data_source IN ('icpdf','digikey','ecloud') + INSERT
#                                  （icpdf + digikey + ecloud 在同一脚本内一次跑出；加新源改 param_all + dim）
#
# 用法：
#   bash run_classify.sh test                 # 写 test_dim + test_dwd
#   ALLOW_PROD=1 bash run_classify.sh prod    # 写生产 dim + dwd
#
# 依赖：仓库 sql_scripts/local.env（MYSQL_*）；或外层 shell 已 export MYSQL_*。
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=/dev/null
[[ -f "$ROOT/local.env" ]] && set -a && source "$ROOT/local.env" && set +a

ENV_NAME="${1:-prod}"
case "$ENV_NAME" in
  test) DIM_DB="test_dim"; DWD_DB="test_dwd" ;;
  prod)
    if [[ "${ALLOW_PROD:-0}" != "1" ]]; then
      echo "需要 ALLOW_PROD=1 才能写 prod。" >&2
      exit 1
    fi
    DIM_DB="dim"; DWD_DB="dwd" ;;
  *) echo "usage: $0 test|prod" >&2; exit 2 ;;
esac

if [[ -z "${MYSQL_PASSWORD:-}" ]]; then
  echo "请设置 MYSQL_PASSWORD 或创建 $ROOT/local.env（参考 local.env.example）。" >&2
  exit 1
fi

HOST="${MYSQL_HOST:-192.168.19.21}"
PORT="${MYSQL_PORT:-9030}"
USER="${MYSQL_USER:-root}"
MYSQL_CMD=(mysql -h "$HOST" -P "$PORT" -u "$USER" "-p${MYSQL_PASSWORD}" --default-character-set=utf8mb4)

echo "==> 1) seed dim ($ENV_NAME)"
ALLOW_PROD="${ALLOW_PROD:-0}" bash "$SCRIPT_DIR/load_seed.sh" "$ENV_NAME"

# 测试环境：SQL 内部 dwd./dim. 是硬编码，需要渲染到 test_dwd / test_dim
# 注意：多源脚本读 dwd.dwd_<source>_component_param（param 事实表）；test 模式下
#       若 param 仅在 prod，请改用 sql_scripts/test/classify_v2/run_classify_v3_multisource_test.sh
#       （仅重写结果表、保留 param 读 prod）。本脚本 test 模式按 e2e 约定整体重写。
render_to_target() {
  local f="$1"
  if [[ "$ENV_NAME" == "prod" ]]; then
    cat "$f"
  else
    python3 - "$f" "$DWD_DB" "$DIM_DB" <<'PY'
import re, sys
src = open(sys.argv[1], encoding="utf-8").read()
src = re.sub(r"\bdwd\.", sys.argv[2] + ".", src)
src = re.sub(r"\bdim\.", sys.argv[3] + ".", src)
for tbl in (
    "dwd_icpdf_component_param",
    "dwd_digikey_component_param",
    "dwd_ecloud_component_param",
):
    src = src.replace(f"{sys.argv[2]}.{tbl}", f"dwd.{tbl}")
sys.stdout.write(src)
PY
  fi
}

echo "==> 2) $DWD_DB.dwd_component_class ← icpdf + digikey + ecloud（多源单脚本）"
render_to_target "$SCRIPT_DIR/dwd_component_class.sql" | "${MYSQL_CMD[@]}"

echo "Done."
