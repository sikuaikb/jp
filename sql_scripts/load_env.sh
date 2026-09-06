#!/usr/bin/env bash
# Worker / CI 凭据加载（可提交 Git，不含密码）
#
# DS Worker：K8s Secret 挂载 db.env，默认 /opt/data_etl_secret/db.env
# 本地开发：请继续用 gitignore 的 sql_scripts/local.env（见 local.env.example）
#
# 用法（海豚 Shell / Worker）：
#   export ETL_SECRET_ENV_FILE=/opt/data_etl_secret/db.env
#   source sql_scripts/load_env.sh
set -euo pipefail

SECRET_ENV_FILE="${ETL_SECRET_ENV_FILE:-/opt/data_etl_secret/db.env}"

if [ ! -r "${SECRET_ENV_FILE}" ]; then
  echo "[ERROR] 未找到 Worker 凭据文件: ${SECRET_ENV_FILE}" >&2
  echo "  本地开发请: source sql_scripts/local.env" >&2
  exit 20
fi

# shellcheck disable=SC1090
source "${SECRET_ENV_FILE}"

export MYSQL_HOST
export MYSQL_PORT
export MYSQL_USER
export MYSQL_PASSWORD

export STARROCKS_HOST="${STARROCKS_HOST:-${MYSQL_HOST}}"
export STARROCKS_PORT="${STARROCKS_PORT:-${MYSQL_PORT}}"
export STARROCKS_USER="${STARROCKS_USER:-${MYSQL_USER}}"
export STARROCKS_PASSWORD="${STARROCKS_PASSWORD:-${MYSQL_PASSWORD}}"
