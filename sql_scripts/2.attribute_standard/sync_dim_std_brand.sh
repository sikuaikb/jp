#!/usr/bin/env bash
# 一键同步品牌字典：ods.ods_jp_brand + manual_extra + 产地回写 → dim.dim_std_brand → dim.v_std_brand_alias
#
# 用法：
#   bash sync_dim_std_brand.sh test                # 写 test_dim
#   ALLOW_PROD=1 bash sync_dim_std_brand.sh prod   # 写 dim
#
# 依赖：sql_scripts/local.env（MYSQL_*）或外部 shell 已 export。
#
# 流程：
#   1. dim_std_brand.sql                     — DROP+CREATE+INSERT FROM ods（产地列在 DDL 里，数据为 NULL）
#   2. dim_std_brand_manual_extra.sql        — 手工补缺品牌（含跨源阶段 2）
#   2.5 dim_std_brand_manual_extra_stage25.sql — 跨源阶段 2.5（semi triage + remaining）
#   2.6 dim_std_brand_dup_merge.sql            — 历史查重合并（A 类）
#   3. dim_brand_origin.sql                  — 确保 dim_brand_origin 表存在（独立持久，不被 DROP）
#   3.5 dim_brand_origin_extra.sql           — 手工补录产地写入 dim_brand_origin
#   3.6 _repair_brand_origin.py              — 修错表模型 + 清 origin 孤儿
#   4. brand_origin_backfill.sql             — JOIN dim_brand_origin 回写产地列
#   5. v_std_brand_alias.sql                 — 重建别名视图
#   6. validate_brand_dim_dup.py             — 查重硬门控
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=/dev/null
[[ -f "$ROOT/local.env" ]] && set -a && source "$ROOT/local.env" && set +a

ENV_NAME="${1:-test}"
case "$ENV_NAME" in
  test) DB="test_dim" ;;
  prod)
    if [[ "${ALLOW_PROD:-0}" != "1" ]]; then
      echo "需要 ALLOW_PROD=1 才能写 prod dim。" >&2
      exit 1
    fi
    DB="dim" ;;
  *)
    echo "usage: $0 test|prod" >&2
    exit 2 ;;
esac

if [[ -z "${MYSQL_PASSWORD:-}" ]]; then
  echo "请设置 MYSQL_PASSWORD 或创建 $ROOT/local.env。" >&2
  exit 1
fi

HOST="${MYSQL_HOST:-192.168.19.21}"
PORT="${MYSQL_PORT:-9030}"
USER="${MYSQL_USER:-root}"
PY_BIN="$(command -v python3 || command -v python || true)"

run_sql() {
  local sql_file="$1"
  echo "==> $sql_file -> $DB"
  # 把 dim.<table> 替换成目标 db；ods.* 保持不变
  # 注意：用纯字面替换 'dim.'（不带 \b，兼容 BSD sed/GNU sed）；
  # 仓库内不应在字符串字面量中出现 'dim.' 否则会被误改。
  sed "s/dim\\./${DB}./g" "$SCRIPT_DIR/$sql_file" \
    | mysql -h "$HOST" -P "$PORT" -u "$USER" "-p${MYSQL_PASSWORD}" --default-character-set=utf8mb4
}

run_sql "dim_std_brand.sql"
run_sql "dim_std_brand_manual_extra.sql"
run_sql "dim_std_brand_manual_extra_stage25.sql"
run_sql "dim_std_brand_dup_merge.sql"
run_sql "dim_brand_origin.sql"
run_sql "dim_brand_origin_extra.sql"
# StarRocks 无法可靠 DELETE JOIN；用 Python 修 PK 模型并清孤儿
if [[ -n "$PY_BIN" && -f "$ROOT/test/_repair_brand_origin.py" ]]; then
  echo "==> _repair_brand_origin.py $ENV_NAME"
  ALLOW_PROD="${ALLOW_PROD:-0}" "$PY_BIN" "$ROOT/test/_repair_brand_origin.py" "$ENV_NAME"
else
  echo "WARN: 跳过 origin 修复（缺 python 或 _repair_brand_origin.py）" >&2
fi
run_sql "brand_origin_backfill.sql"
run_sql "v_std_brand_alias.sql"

# 查重硬门控：sync 后按归一化品牌名查「同一公司多 id」，红则中止（见 CONTRIB_BRAND.md §0/§6）。
REPO_ROOT="$(cd "$ROOT/.." && pwd)"
VALIDATOR="$REPO_ROOT/.cursor/skills/component-etl-methodology/tools/validate_brand_dim_dup.py"
if [[ -n "$PY_BIN" && -f "$VALIDATOR" ]]; then
  echo "==> 品牌查重校验 ($DB)"
  if ! "$PY_BIN" "$VALIDATOR" --dim-schema "$DB"; then
    echo "品牌查重校验未通过：存在未登记的归一化重复（同公司多 id）。" >&2
    echo "→ 走 A 类复用既有 brand_id_std，或确为不同公司则登记白名单/用 --waiver，再重跑。" >&2
    exit 1
  fi
else
  echo "WARN: 跳过品牌查重校验（未找到 python 或校验器 $VALIDATOR）。" >&2
fi

echo "Done."
