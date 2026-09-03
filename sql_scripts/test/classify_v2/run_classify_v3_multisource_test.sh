#!/usr/bin/env bash
# v3 多源单脚本 test：icpdf + digikey 一条 INSERT → test_dwd.dwd_component_class_v3ms
#   param 读 prod dwd（只读）；dim 读 test_dim；结果写独立表 v3ms（不覆盖 V1 基线）。
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
SQL="$SCRIPT_DIR/dwd_component_class_v3_multisource.sql"

[[ -f "$ROOT/env" ]] && set -a && source "$ROOT/env" && set +a
[[ -f "$ROOT/sql_scripts/local.env" ]] && set -a && source "$ROOT/sql_scripts/local.env" && set +a
export MYSQL_PASSWORD="${MYSQL_PASSWORD:-${STARROCKS_PASSWORD:-}}"
HOST="${MYSQL_HOST:-192.168.19.21}"; PORT="${MYSQL_PORT:-9030}"; USER="${MYSQL_USER:-root}"
MYSQL_CMD=(mysql -h "$HOST" -P "$PORT" -u "$USER" "-p${MYSQL_PASSWORD}" --default-character-set=utf8mb4)

render() {
  python3 - "$SQL" <<'PY'
import re, sys
src = open(sys.argv[1], encoding="utf-8").read()
src = re.sub(r"\bdim\.", "test_dim.", src)
# 结果表 → test_dwd.dwd_component_class_v3ms（param 表保持 prod 只读）
src = re.sub(r"\bdwd\.dwd_component_class\b", "test_dwd.dwd_component_class_v3ms", src)
sys.stdout.write(src)
PY
}

if [[ "${SKIP_LOAD_SEED:-0}" != "1" ]]; then
  echo "==> load_seed test_dim"
  ALLOW_PROD=0 bash "$ROOT/sql_scripts/1.classify/load_seed.sh" test
fi

echo "==> v3 multisource classify (single INSERT)"
T0=$(date +%s)
render | "${MYSQL_CMD[@]}"
echo "    sec=$(( $(date +%s) - T0 ))"

echo "==> [counts] by source/l1"
"${MYSQL_CMD[@]}" -N -e "
SELECT data_source, COUNT(*) FROM test_dwd.dwd_component_class_v3ms GROUP BY data_source ORDER BY 1;
SELECT data_source, l1_code, COUNT(*) FROM test_dwd.dwd_component_class_v3ms GROUP BY data_source, l1_code ORDER BY data_source, 3 DESC;
" 2>&1 | grep -vi "using a password" || true

echo "==> [icpdf] v3ms vs test V1 分批基线 test_dwd.dwd_component_class（note/partno 已启用 → v3ms 预期略多）"
"${MYSQL_CMD[@]}" -N -e "
SELECT 'v3ms_icpdf', COUNT(*) FROM test_dwd.dwd_component_class_v3ms WHERE data_source='icpdf';
SELECT 'v1_icpdf', COUNT(*) FROM test_dwd.dwd_component_class WHERE data_source='icpdf';
SELECT 'only_v1', COUNT(*) FROM test_dwd.dwd_component_class v1
  LEFT JOIN test_dwd.dwd_component_class_v3ms a ON a.id=v1.id AND a.data_source=v1.data_source
  WHERE v1.data_source='icpdf' AND a.id IS NULL;
SELECT 'only_v3ms', COUNT(*) FROM test_dwd.dwd_component_class_v3ms a
  LEFT JOIN test_dwd.dwd_component_class v1 ON v1.id=a.id AND v1.data_source=a.data_source
  WHERE a.data_source='icpdf' AND v1.id IS NULL;
" 2>&1 | grep -vi "using a password" || true

echo "==> [digikey] v3ms vs prod dwd（768028 基线）"
"${MYSQL_CMD[@]}" -N -e "
SELECT 'v3ms_digikey', COUNT(*) FROM test_dwd.dwd_component_class_v3ms WHERE data_source='digikey';
SELECT 'prod_digikey', COUNT(*) FROM dwd.dwd_component_class WHERE data_source='digikey';
SELECT 'only_v3ms_dk', COUNT(*) FROM (SELECT id FROM test_dwd.dwd_component_class_v3ms WHERE data_source='digikey') a
  LEFT JOIN (SELECT id FROM dwd.dwd_component_class WHERE data_source='digikey') b ON a.id=b.id WHERE b.id IS NULL;
SELECT 'only_prod_dk', COUNT(*) FROM (SELECT id FROM dwd.dwd_component_class WHERE data_source='digikey') b
  LEFT JOIN (SELECT id FROM test_dwd.dwd_component_class_v3ms WHERE data_source='digikey') a ON a.id=b.id WHERE a.id IS NULL;
" 2>&1 | grep -vi "using a password" || true
