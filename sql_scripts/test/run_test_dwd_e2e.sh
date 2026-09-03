#!/usr/bin/env bash
# 【test_dwd 端到端验证·多源版】
#
# 范围：电阻试点，跑 ICPDF + DigiKey 两源端到端：
#   0) [可选] CREATE DATABASE test_dim/test_dwd（首次）
#   1) test_dim：dim_attr_schema / dim_attr_extract_rule / dim_l3_classify(_rule) / dim_unit_factor
#                + dim_std_brand + dim_std_brand_manual_extra（含 DigiKey 段）
#   2) test_dwd：建 DigiKey param 表 + 装载（小范围或全量由 SQL 控）
#   3) test_dwd：建 dwd_component_class（多源） + 跑 ICPDF/DigiKey 两 classify SQL
#   4) test_dwd：建 dwd_component_attr_std（多源） + 跑 ICPDF/DigiKey 两 EAV SQL
#   5) test_dwd：3 张电阻 L2 DDL + 多源 build SQL
#   6) 行数对比：与 prod dwd 当前 L1=resistor 数据
#
# 用法：
#   bash run_test_dwd_e2e.sh                                  # 默认全跑
#   SKIP_CREATE_DB=1 bash run_test_dwd_e2e.sh                 # 跳过库创建
#   SKIP_DIM=1 bash run_test_dwd_e2e.sh                       # 跳过 dim 装载
#   SKIP_DIGIKEY_PARAM=1 bash run_test_dwd_e2e.sh             # 跳过 DigiKey param 重建（已有则跳）
#
# 依赖：sql_scripts/local.env（MYSQL_*）；
#       与 prod 同库（dim/dwd）；test_dim/test_dwd 在同实例 prefix 区分。
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SQL_ROOT="$ROOT/sql_scripts"

# shellcheck source=/dev/null
[[ -f "$SQL_ROOT/local.env" ]] && set -a && source "$SQL_ROOT/local.env" && set +a

if [[ -z "${MYSQL_PASSWORD:-}" ]]; then
  echo "请设置 MYSQL_PASSWORD 或创建 $SQL_ROOT/local.env" >&2
  exit 1
fi
HOST="${MYSQL_HOST:-192.168.19.21}"
PORT="${MYSQL_PORT:-9030}"
USER="${MYSQL_USER:-root}"
MYSQL_CMD=(mysql -h "$HOST" -P "$PORT" -u "$USER" "-p${MYSQL_PASSWORD}" --default-character-set=utf8mb4)

SKIP_CREATE_DB="${SKIP_CREATE_DB:-0}"
SKIP_DIM="${SKIP_DIM:-0}"
SKIP_DIGIKEY_PARAM="${SKIP_DIGIKEY_PARAM:-0}"

# 渲染 SQL（用 python 走 \b 正则；BSD sed 不支持 \b）：
#   dim.*           → test_dim.*
#   写入的多源新表 → test_dwd.*  (component_class / component_attr_std / l2_*)
#   DigiKey param  → test_dwd.dwd_digikey_component_param
#   ICPDF param / 老 icpdf 表 / ods.* 保留 prod（只读）。
exec_rendered() {
  local f="$1"
  echo "  ↳ $(basename "$f")"
  python3 - "$f" <<'PY' | "${MYSQL_CMD[@]}"
import sys, re
src = open(sys.argv[1], encoding='utf-8').read()
src = re.sub(r'\bdim\.', 'test_dim.', src)
src = re.sub(r'\bdwd\.dwd_component_class\b', 'test_dwd.dwd_component_class', src)
src = re.sub(r'\bdwd\.dwd_component_attr_std\b', 'test_dwd.dwd_component_attr_std', src)
src = re.sub(r'\bdwd\.dwd_l2_', 'test_dwd.dwd_l2_', src)
src = re.sub(r'\bdwd\.dwd_digikey_component_param\b', 'test_dwd.dwd_digikey_component_param', src)
sys.stdout.write(src)
PY
}

# ------------------------------------------------------------
# Step 0: 库存在性
# ------------------------------------------------------------
if [[ "$SKIP_CREATE_DB" != "1" ]]; then
  echo "==> [0] CREATE DATABASE test_dim / test_dwd（IF NOT EXISTS）"
  "${MYSQL_CMD[@]}" -e "CREATE DATABASE IF NOT EXISTS test_dim;
                       CREATE DATABASE IF NOT EXISTS test_dwd;"
fi

# ------------------------------------------------------------
# Step 1: test_dim 装载（schema / extract_rule / classify(_rule) / unit_factor + brand）
# ------------------------------------------------------------
if [[ "$SKIP_DIM" != "1" ]]; then
  echo "==> [1] test_dim 装载（dim_*.sql + seed CSV）"
  ALLOW_PROD=0 bash "$SQL_ROOT/2.attribute_standard/sync_attr_std_seed.sh" test
  ALLOW_PROD=0 bash "$SQL_ROOT/1.classify/load_seed.sh" test
  # dim_std_brand：从 ods 拉一份到 test_dim
  bash "$SQL_ROOT/2.attribute_standard/sync_dim_std_brand.sh" test || \
    echo "  WARN: sync_dim_std_brand.sh 失败（如不存在 test 入口，请手动拉 ods.ods_jp_brand → test_dim.dim_std_brand）"
fi

# ------------------------------------------------------------
# Step 2: test_dwd 建 DigiKey param 表 + 装载
# ------------------------------------------------------------
if [[ "$SKIP_DIGIKEY_PARAM" != "1" ]]; then
  echo "==> [2] test_dwd.dwd_digikey_component_param 建表 + 装载"
  exec_rendered "$SQL_ROOT/foundation/dwd_digikey_component_param.sql"
fi

# ------------------------------------------------------------
# Step 3: dwd_component_class 多源
# ------------------------------------------------------------
echo "==> [3] test_dwd.dwd_component_class 建表 + ICPDF classify"
exec_rendered "$SQL_ROOT/1.classify/dwd_component_class.sql"
echo "==> [3] test_dwd.dwd_component_class ← DigiKey classify"
exec_rendered "$SQL_ROOT/1.classify/dwd_digikey_component_class.sql"

# ------------------------------------------------------------
# Step 4: dwd_component_attr_std 多源
# ------------------------------------------------------------
echo "==> [4] test_dwd.dwd_component_attr_std DDL（DROP+CREATE）"
exec_rendered "$SQL_ROOT/2.attribute_standard/dwd_component_attr_std.sql"
echo "==> [4] EAV ← ICPDF"
exec_rendered "$SQL_ROOT/2.attribute_standard/build_dwd_component_attr_std_icpdf.sql"
echo "==> [4] EAV ← DigiKey"
exec_rendered "$SQL_ROOT/2.attribute_standard/build_dwd_component_attr_std_digikey.sql"

# ------------------------------------------------------------
# Step 5: 3 张电阻 L2
# ------------------------------------------------------------
for sfx in resistor_fixed_resistor resistor_variable_resistor resistor_protective_sensitive_resistor; do
  echo "==> [5] test_dwd.dwd_l2_${sfx} DDL"
  exec_rendered "$SQL_ROOT/2.attribute_standard/dwd_l2_${sfx}.sql"
  echo "==> [5] build dwd_l2_${sfx}"
  exec_rendered "$SQL_ROOT/2.attribute_standard/build_dwd_l2_${sfx}.sql"
done

# ------------------------------------------------------------
# Step 6: 行数对比 test_dwd vs prod dwd（仅 ICPDF L1=resistor）
# ------------------------------------------------------------
echo "==> [6] 行数对比 test_dwd ↔ prod dwd（仅 ICPDF resistor）"
"${MYSQL_CMD[@]}" <<'SQL'
SELECT '==> class.resistor.icpdf' AS what;
SELECT 'prod.dwd_icpdf_component_class' AS src,
       COUNT(*) AS rows_ FROM dwd.dwd_icpdf_component_class WHERE l1_code='resistor'
UNION ALL
SELECT 'test_dwd.dwd_component_class (icpdf)',
       COUNT(*) FROM test_dwd.dwd_component_class
       WHERE l1_code='resistor' AND data_source='icpdf';

SELECT '==> class.resistor.digikey (test only)' AS what;
SELECT 'test_dwd.dwd_component_class (digikey)',
       COUNT(*) FROM test_dwd.dwd_component_class
       WHERE l1_code='resistor' AND data_source='digikey';

SELECT '==> eav.resistor.icpdf' AS what;
SELECT 'prod.dwd_icpdf_component_attr_std (L2 in 3 res)' AS src,
       COUNT(*) AS rows_ FROM dwd.dwd_icpdf_component_attr_std
       WHERE l2_code IN ('fixed_resistor','variable_resistor','protective_sensitive_resistor')
UNION ALL
SELECT 'test_dwd.dwd_component_attr_std (icpdf)',
       COUNT(*) FROM test_dwd.dwd_component_attr_std
       WHERE data_source='icpdf'
       AND l2_code IN ('fixed_resistor','variable_resistor','protective_sensitive_resistor');

SELECT '==> eav.resistor.digikey (test only)' AS what;
SELECT 'test_dwd.dwd_component_attr_std (digikey)',
       COUNT(*) FROM test_dwd.dwd_component_attr_std
       WHERE data_source='digikey'
       AND l2_code IN ('fixed_resistor','variable_resistor','protective_sensitive_resistor');

SELECT '==> L2 行数对比' AS what;
SELECT 'prod.dwd_l2_fixed_resistor'         AS src, COUNT(*) AS rows_ FROM dwd.dwd_l2_fixed_resistor
UNION ALL SELECT 'test_dwd.dwd_l2_resistor_fixed_resistor (icpdf)',
       COUNT(*) FROM test_dwd.dwd_l2_resistor_fixed_resistor WHERE data_source='icpdf'
UNION ALL SELECT 'test_dwd.dwd_l2_resistor_fixed_resistor (digikey)',
       COUNT(*) FROM test_dwd.dwd_l2_resistor_fixed_resistor WHERE data_source='digikey'
UNION ALL SELECT 'prod.dwd_l2_variable_resistor',
       COUNT(*) FROM dwd.dwd_l2_variable_resistor
UNION ALL SELECT 'test_dwd.dwd_l2_resistor_variable_resistor (icpdf)',
       COUNT(*) FROM test_dwd.dwd_l2_resistor_variable_resistor WHERE data_source='icpdf'
UNION ALL SELECT 'test_dwd.dwd_l2_resistor_variable_resistor (digikey)',
       COUNT(*) FROM test_dwd.dwd_l2_resistor_variable_resistor WHERE data_source='digikey'
UNION ALL SELECT 'prod.dwd_l2_protective_sensitive_resistor',
       COUNT(*) FROM dwd.dwd_l2_protective_sensitive_resistor
UNION ALL SELECT 'test_dwd.dwd_l2_resistor_protective_sensitive_resistor (icpdf)',
       COUNT(*) FROM test_dwd.dwd_l2_resistor_protective_sensitive_resistor WHERE data_source='icpdf'
UNION ALL SELECT 'test_dwd.dwd_l2_resistor_protective_sensitive_resistor (digikey)',
       COUNT(*) FROM test_dwd.dwd_l2_resistor_protective_sensitive_resistor WHERE data_source='digikey';

SELECT '==> 关键空值率（test_dwd icpdf vs prod）' AS what;
SELECT 'fixed_resistor.resistance_ohm.null_pct.icpdf.test' AS metric,
       ROUND(100.0 * SUM(CASE WHEN resistance_ohm IS NULL THEN 1 ELSE 0 END) / COUNT(*), 2) AS pct
FROM test_dwd.dwd_l2_resistor_fixed_resistor WHERE data_source='icpdf'
UNION ALL
SELECT 'fixed_resistor.resistance_ohm.null_pct.prod',
       ROUND(100.0 * SUM(CASE WHEN resistance_ohm IS NULL THEN 1 ELSE 0 END) / COUNT(*), 2)
FROM dwd.dwd_l2_fixed_resistor;
SQL

echo
echo "Done. 若 ICPDF 列两端行数 / 关键空值率几乎一致 → 可发 prod cutover。"
