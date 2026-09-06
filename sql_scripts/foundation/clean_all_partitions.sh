#!/bin/bash
# 批量清洗 ods.ods_icpdf_component_detail 所有非空分区到 dwd.dwd_icpdf_component_detail
# 小分区先跑，大分区后跑。每个分区独立日志，遇错不中断，失败的分区打印出来由人工介入。
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SQL_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=/dev/null
[[ -f "$SQL_ROOT/local.env" ]] && . "$SQL_ROOT/local.env"

HOST="${MYSQL_HOST:-192.168.19.21}"
PORT="${MYSQL_PORT:-9030}"
USER="${MYSQL_USER:-root}"
if [[ -z "${MYSQL_PASSWORD:-}" ]]; then
    echo "Set MYSQL_PASSWORD or create $SQL_ROOT/local.env (see local.env.example)." >&2
    exit 1
fi
PASS="$MYSQL_PASSWORD"
PARTITION_LIST=${PARTITION_LIST:-/tmp/partitions.txt}
LOG_DIR=${LOG_DIR:-/tmp/icpdf_clean}
mkdir -p "$LOG_DIR"

MYSQL_BASE=(mysql -h "$HOST" -P "$PORT" -u "$USER" "-p${PASS}" --default-character-set=utf8mb4 -D dwd)

run_sql() {
    # 用法：echo "SQL" | run_sql
    "${MYSQL_BASE[@]}" "$@"
}

# 把 p20260401 转成日期 [2026-04-01 ..2026-04-02)
partition_to_dates() {
    local p=$1  # p20260401
    local y=${p:1:4}
    local m=${p:5:2}
    local d=${p:7:2}
    local start="${y}-${m}-${d}"
    local next
    next=$(date -j -f "%Y-%m-%d" -v+1d "$start" "+%Y-%m-%d" 2>/dev/null \
           || date -d "$start + 1 day" "+%Y-%m-%d")
    echo "$start $next"
}

ensure_partition() {
    local p=$1
    read -r s e <<< "$(partition_to_dates "$p")"
    "${MYSQL_BASE[@]}" -e "
        ALTER TABLE dwd_icpdf_component_detail SET ('dynamic_partition.enable' = 'false');
        ALTER TABLE dwd_icpdf_component_detail ADD PARTITION IF NOT EXISTS $p
            VALUES [('$s'), ('$e'));
        ALTER TABLE dwd_icpdf_component_detail SET ('dynamic_partition.enable' = 'true');
    " 2>&1 | grep -v '^mysql:.*Warning' || true
}

run_insert() {
    local p=$1
    local shard_filter="${2:-1=1}"  # 比如 "id % 4 = 0" 用来分片跑
    "${MYSQL_BASE[@]}" <<SQL
INSERT INTO dwd.dwd_icpdf_component_detail
(
    id, dt,
    partno, brandid, brandshort,
    pdf_file_id, foldpath, foldpath2, filename, page, filesize,
    md5file, categoryid, category, category2,
    note, note_cn, taginfo,
    prajson, prajson2,
    image2, category_info,
    createtime, updatetime, praid,
    all_info, pdf_replace_partno_arr,
    big_img, pin_diagram, schematic_diagram, package_pad_diagram,
    create_at, update_at
)
SELECT
    id, dt,
    get_json_string(dj, '\$.pdf.partno'),
    CAST(NULLIF(get_json_string(dj, '\$.pdf.brandid'), '') AS BIGINT),
    get_json_string(dj, '\$.pdf.brandshort'),
    CAST(NULLIF(get_json_string(dj, '\$.pdf.pdf_file_id'), '') AS BIGINT),
    get_json_string(dj, '\$.pdf.foldpath'),
    get_json_string(dj, '\$.pdf.foldpath2'),
    get_json_string(dj, '\$.pdf.filename'),
    CAST(NULLIF(get_json_string(dj, '\$.pdf.page'), '') AS INT),
    CAST(NULLIF(get_json_string(dj, '\$.pdf.filesize'), '') AS BIGINT),
    get_json_string(dj, '\$.pdf.md5file'),
    get_json_string(dj, '\$.pdf.categoryid'),
    get_json_string(dj, '\$.pdf.category'),
    get_json_string(dj, '\$.pdf.category2'),
    get_json_string(dj, '\$.pdf.note'),
    get_json_string(dj, '\$.pdf.note_cn'),
    CASE WHEN NULLIF(get_json_string(dj, '\$.pdf.taginfo'), '') IS NULL THEN NULL
         ELSE array_remove(split(get_json_string(dj, '\$.pdf.taginfo'), '|'), '')
    END,
    parse_json(NULLIF(get_json_string(dj, '\$.pdf.prajson'), '')),
    CASE WHEN NULLIF(get_json_string(dj, '\$.pdf.prajson2'), '') IS NULL THEN NULL
         ELSE parse_json(concat('{', regexp_replace(regexp_replace(get_json_string(dj, '\$.pdf.prajson2'),
                '<dt>\\\\s*([^<]*?)\\\\s*</dt><dd>\\\\s*([^<]*?)\\\\s*</dd>', '"\\\\1":"\\\\2",'),
                ',\$',''), '}'))
    END,
    get_json_string(dj, '\$.pdf.image2'),
    CASE WHEN NULLIF(get_json_string(dj, '\$.pdf.category__info'), '') IS NULL THEN NULL
         ELSE array_remove(split(regexp_replace(regexp_replace(get_json_string(dj, '\$.pdf.category__info'),
                '<a[^>]*>|</a>', ''), '\\\\s*&gt;\\\\s*', '|'), '|'), '')
    END,
    CAST(NULLIF(get_json_string(dj, '\$.pdf.createtime'), '') AS DATETIME),
    CAST(NULLIF(get_json_string(dj, '\$.pdf.updatetime'), '') AS DATETIME),
    CAST(NULLIF(get_json_string(dj, '\$.pdf.praid'), '') AS BIGINT),
    get_json_string(dj, '\$.allInfo'),
    parse_json(NULLIF(get_json_string(dj, '\$.pdfReplacePartNoArr'), '')),
    regexp_replace(regexp_extract(get_json_string(dj, '\$.bigImg'), 'src="([^"]+)"', 1), '^//', ''),
    regexp_replace(get_json_string(dj, '\$.pinDiagram'),        '^//', ''),
    regexp_replace(get_json_string(dj, '\$.schematicDiagram'),  '^//', ''),
    regexp_replace(get_json_string(dj, '\$.packagePadDiagram'), '^//', ''),
    CURRENT_TIMESTAMP(),
    CURRENT_TIMESTAMP()
FROM (
    SELECT id, dt,
        replace(
          replace(
            replace(
              replace(
                replace(
                  replace(
                    replace(
                      replace(
                        translate(data_json,
                          concat(char(0), char(1), char(2), char(3), char(4), char(5), char(6), char(7), char(8),
                                 char(11), char(12),
                                 char(14), char(15), char(16), char(17), char(18), char(19), char(20), char(21),
                                 char(22), char(23), char(24), char(25), char(26), char(27), char(28), char(29),
                                 char(30), char(31)),
                          ''),
                        concat(char(92), char(92)), char(1)),
                      concat(char(92), '<'), '<'),
                    concat(char(92), '>'), '>'),
                  concat(char(92), '&'), '&'),
                concat(char(92), '*'), '*'),
              concat(char(92), '1'), '1'),
            concat(char(92), ' '), ' '),
          char(1), concat(char(92), char(92))
        ) AS dj
    FROM ods.ods_icpdf_component_detail PARTITION($p)
    WHERE data_json IS NOT NULL AND data_json <> '' AND ($shard_filter)
) t;
SQL
}

verify_partition() {
    local p=$1
    "${MYSQL_BASE[@]}" -N -e "
        SELECT
          (SELECT COUNT(*) FROM ods.ods_icpdf_component_detail PARTITION($p)
                WHERE data_json IS NOT NULL AND data_json <> ''),
          (SELECT COUNT(*) FROM dwd.dwd_icpdf_component_detail PARTITION($p)),
          (SELECT COUNT(*) FROM dwd.dwd_icpdf_component_detail PARTITION($p)
                WHERE partno IS NULL OR partno = '')
        ;
    " 2>/dev/null
}

# --------- main loop ----------
SUMMARY="$LOG_DIR/summary.log"
: > "$SUMMARY"

echo "=== batch start $(date '+%F %T') ===" | tee -a "$SUMMARY"

run_insert_with_retry() {
    local pname=$1
    local shard_filter=$2
    local tag=$3   # 日志里打个分片标
    local log=$4
    local retry=0
    while (( retry < MAX_RETRIES )); do
        {
          echo "--- $(date '+%F %T') $tag insert attempt $((retry+1)) filter=[$shard_filter] ---"
          run_insert "$pname" "$shard_filter"
          echo "--- $(date '+%F %T') $tag attempt $((retry+1)) done ---"
        } >> "$log" 2>&1

        if tail -30 "$log" | grep -q 'ERROR 5609'; then
            retry=$((retry+1))
            wait_s=$(( 60 * retry ))   # 60,120,180,240,300
            echo "  [retry] $pname $tag hit OOM, wait ${wait_s}s then retry ($retry/$MAX_RETRIES)" | tee -a "$SUMMARY"
            sleep "$wait_s"
        else
            return 0
        fi
    done
    return 1
}

# 用 FD 3 读分区清单，避免 while 循环里的 mysql 把外层 stdin 吃掉
MAX_RETRIES=5
# 大分区阈值：>= 这个行数就按 id%N 分片跑，减小单 INSERT 内存压力
BIG_PARTITION_THRESHOLD=1000000
BIG_PARTITION_SHARDS=4

while IFS=$'\t' read -u 3 -r pname rowcount; do
    [[ -z "$pname" ]] && continue
    log="$LOG_DIR/${pname}.log"

    # 已完成则跳过（dwd 行数 == ods 有效行数 && null_partno 不超过容忍阈值）
    # 当前数据里 p20260214 有 2 行不可恢复的脏数据（JSON 字符串里混字面换行符），
    # 所以把 null_partno < 10 都视为已清洗完成。
    read -r ods dwd nullp _ <<< "$(verify_partition "$pname")"
    if [[ -n "${ods:-}" && -n "${dwd:-}" && "$ods" == "$dwd" && "${nullp:-99999}" -lt 10 ]]; then
        echo "[skip] $pname already clean (ods=$ods dwd=$dwd null=${nullp})" | tee -a "$SUMMARY"
        continue
    fi

    start=$(date +%s)
    echo "[run ] $pname ($rowcount rows, started $(date '+%T'))" | tee -a "$SUMMARY"

    {
      echo "--- $(date '+%F %T') add partition ---"
      ensure_partition "$pname"
    } > "$log" 2>&1

    # 小分区：一次性跑；大分区：按 id%N 分片跑
    if (( rowcount >= BIG_PARTITION_THRESHOLD )); then
        n=$BIG_PARTITION_SHARDS
        for ((i=0; i<n; i++)); do
            if ! run_insert_with_retry "$pname" "id % $n = $i" "shard-$i/$n" "$log"; then
                echo "  [abort] $pname shard $i/$n still OOM after $MAX_RETRIES retries" | tee -a "$SUMMARY"
                break
            fi
        done
    else
        run_insert_with_retry "$pname" "1=1" "full" "$log" || true
    fi

    read -r ods dwd nullp _ <<< "$(verify_partition "$pname")"
    elapsed=$(( $(date +%s) - start ))
    if [[ -n "${ods:-}" && "$ods" == "$dwd" && "${nullp:-99999}" -lt 10 ]]; then
        echo "[ok  ] $pname ods=$ods dwd=$dwd null=${nullp}  ${elapsed}s" | tee -a "$SUMMARY"
    else
        echo "[FAIL] $pname ods=${ods:-?} dwd=${dwd:-?} null=${nullp:-?}  ${elapsed}s  (see $log)" | tee -a "$SUMMARY"
    fi
done 3< "$PARTITION_LIST"

echo "=== batch end $(date '+%F %T') ===" | tee -a "$SUMMARY"
