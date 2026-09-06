#!/usr/bin/env bash
# 导出：电容 / 电阻 / 二极管 各最多 200 条（PDF 键去重）
# CSV 使用 UTF-8 **带 BOM**（utf-8-sig），便于 Excel（尤其中文 Windows）双击打开不乱码
# 依赖：sql_scripts/local.env（参考 sql_scripts/local.env.example）或仓库根目录 env 中的 MYSQL_PASSWORD / STARROCKS_PASSWORD
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
SQL_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ROOT="$(cd "$SQL_ROOT/.." && pwd)"
# shellcheck source=/dev/null
[[ -f "$SQL_ROOT/local.env" ]] && set -a && source "$SQL_ROOT/local.env" && set +a
[[ -f "$SCRIPT_DIR/local.env" ]] && set -a && source "$SCRIPT_DIR/local.env" && set +a
[[ -f "$ROOT/env" ]] && set -a && source "$ROOT/env" && set +a

HOST="${MYSQL_HOST:-192.168.19.21}"
PORT="${MYSQL_PORT:-9030}"
USER="${MYSQL_USER:-root}"
MYSQL_PASSWORD="${MYSQL_PASSWORD:-${STARROCKS_PASSWORD:-}}"
if [[ -z "${MYSQL_PASSWORD:-}" ]]; then
  echo "请设置 MYSQL_PASSWORD 或创建 $SQL_ROOT/local.env。" >&2
  exit 1
fi

OUT="${1:-$ROOT/exports/icpdf_sample_cap_res_diode_pdf_paths.csv}"
mkdir -p "$(dirname "$OUT")"

MYSQL_CMD=(mysql -h "$HOST" -P "$PORT" -u "$USER" "-p${MYSQL_PASSWORD}" \
  --default-character-set=utf8mb4 -N -B -D dwd)

# shellcheck disable=SC2068
"${MYSQL_CMD[@]}" < "$SCRIPT_DIR/export_icpdf_sample_cap_res_diode_pdf_paths.sql" |
  python3 -c '
import csv, sys
out_path = sys.argv[1]
hdr = ["大类", "id", "品牌", "型号", "封装", "foldpath", "foldpath2", "filename"]
with open(out_path, "w", newline="", encoding="utf-8-sig") as f:
    w = csv.writer(f)
    w.writerow(hdr)
    for row in csv.reader(sys.stdin, delimiter="\t"):
        w.writerow(row)
' "$OUT"

echo "Wrote $OUT ($(($(wc -l < "$OUT") - 1)) data rows + header)"
wc -l "$OUT"
