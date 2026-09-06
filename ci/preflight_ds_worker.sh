#!/usr/bin/env bash
# DS Worker 预检（可在海豚 Shell 节点或 CI 部署后手动跑）
set -u

ETL_BASE="${ETL_BASE:-/opt/data_etl}"
DB_SECRET_MOUNT_PATH="${DB_SECRET_MOUNT_PATH:-/opt/data_etl_secret}"
REPO="${ETL_BASE}/current"

echo "=== worker ==="
hostname; whoami; pwd

echo "=== 代码发布 ==="
if [ -d "${REPO}" ] && [ -L "${ETL_BASE}/current" ]; then
  echo "OK current -> $(readlink "${ETL_BASE}/current")"
  cat "${REPO}/VERSION" 2>/dev/null && echo "OK VERSION"
  test -f "${REPO}/sql_scripts/pdf_pipe/run_pdf_pipe_ds.py" && echo "OK pdf_pipe runner"
else
  echo "MISSING ${ETL_BASE}/current —— 需先跑 ci/deploy_to_ds_worker.sh"
fi

echo "=== Secret ==="
if [ -r "${DB_SECRET_MOUNT_PATH}/db.env" ]; then
  echo "OK ${DB_SECRET_MOUNT_PATH}/db.env"
  export ETL_SECRET_ENV_FILE="${DB_SECRET_MOUNT_PATH}/db.env"
  # shellcheck disable=SC1090
  source "${REPO}/sql_scripts/load_env.sh" 2>/dev/null && echo "OK MYSQL_HOST=${MYSQL_HOST:-?}"
else
  echo "MISSING ${DB_SECRET_MOUNT_PATH}/db.env"
fi

echo "=== python ==="
python3 --version 2>/dev/null || echo "MISSING python3"
python3 -c "import pymysql; print('OK pymysql', pymysql.__version__)" 2>/dev/null || echo "MISSING pymysql"

echo "=== done ==="
