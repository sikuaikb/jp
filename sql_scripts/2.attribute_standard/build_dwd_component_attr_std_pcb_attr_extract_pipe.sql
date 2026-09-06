/* ============================================================
 * PDF 抽取源 → 标准属性窄表 EAV（写入 dwd.dwd_component_attr_std）
 *
 * 数据源：dwd.dwd_pdf_extract_component_param
 * 分类：  dwd.dwd_component_class（data_source='pcb_attr_extract_pipe'）
 *
 * 与 icpdf/digikey EAV 的差异：
 *   - prajson 结构为 { records: [{ field, value, confidence, bucket, … }] }
 *   - records[].field 已与 dim_attr_schema.std_attr_code 对齐，无需 dim extract_rule
 *   - 按 (id, std_attr_code) 以 bucket=confident、confidence 降序决选
 *
 * 执行：mysql … < sql_scripts/2.attribute_standard/build_dwd_component_attr_std_pcb_attr_extract_pipe.sql
 * 依赖：build_dwd_component_class_pcb_attr_extract_pipe.sql 已跑
 * ============================================================ */

DELETE FROM dwd.dwd_component_attr_std WHERE data_source = 'pcb_attr_extract_pipe';

INSERT INTO dwd.dwd_component_attr_std
(
    data_source,
    id,
    std_attr_code,
    l2_code,
    l3_id,
    l3_code,
    attr_schema_version,
    std_attr_cn,
    db_type,
    unit_std,
    value_raw,
    extract_rule_id,
    match_priority,
    clean_str,
    value_std_double,
    value_std_varchar,
    dq_flag,
    create_at,
    update_at
)
WITH
attr_l2_catalog AS (
    SELECT
        d.l1_code,
        d.scope_code AS l2_code,
        MAX(d.schema_version) AS schema_v
    FROM dim.dim_attr_schema d
    WHERE d.scope_level = 'l2'
    GROUP BY d.l1_code, d.scope_code
),
ids AS (
    SELECT
        p.id,
        c.l1_code,
        c.l2_code,
        c.l3_id,
        c.l3_code,
        cat.schema_v
    FROM dwd.dwd_pdf_extract_component_param p
    INNER JOIN dwd.dwd_component_class c
            ON c.id = p.id
           AND c.data_source = 'pcb_attr_extract_pipe'
    INNER JOIN attr_l2_catalog cat
            ON cat.l1_code = c.l1_code
           AND cat.l2_code = c.l2_code
    WHERE p.prajson IS NOT NULL
),
records_kv AS (
    SELECT
        i.id,
        i.l1_code,
        i.schema_v,
        i.l2_code,
        i.l3_id,
        i.l3_code,
        NULLIF(TRIM(get_json_string(e, '$.field')), '')                    AS field,
        CAST(get_json_string(e, '$.value') AS VARCHAR(4096))                AS raw_value,
        CAST(get_json_string(e, '$.confidence') AS DOUBLE)                AS conf,
        NULLIF(TRIM(get_json_string(e, '$.bucket')), '')                    AS bucket
    FROM ids i
    INNER JOIN dwd.dwd_pdf_extract_component_param p ON p.id = i.id
    , UNNEST(CAST(parse_json(get_json_string(p.prajson, '$.records')) AS ARRAY<JSON>)) AS t(e)
    WHERE get_json_string(e, '$.value') IS NOT NULL
      AND TRIM(CAST(get_json_string(e, '$.value') AS VARCHAR)) <> ''
),
matches AS (
    SELECT
        kv.id,
        kv.l1_code,
        kv.schema_v,
        kv.l2_code,
        kv.l3_id,
        kv.l3_code,
        concat('pdf_pipe_auto_', kv.field)                                  AS extract_rule_id,
        s.std_attr_code,
        CAST(1 AS INT)                                                      AS priority,
        kv.raw_value                                                        AS value_raw,
        s.std_attr_cn,
        s.db_type,
        s.unit_std,
        s.min_bound,
        s.max_bound,
        kv.conf,
        kv.bucket
    FROM records_kv kv
    INNER JOIN dim.dim_attr_schema s
            ON s.schema_version = kv.schema_v
           AND s.l1_code = kv.l1_code
           AND s.std_attr_code = kv.field
           AND (
                (s.scope_level = 'l2' AND s.scope_code = kv.l2_code)
             OR (s.scope_level = 'l3' AND s.scope_code = kv.l3_code)
           )
    WHERE kv.field IS NOT NULL
),
ranked AS (
    SELECT
        m.*,
        ROW_NUMBER() OVER (
            PARTITION BY m.id, m.std_attr_code
            ORDER BY
                CASE WHEN m.bucket = 'confident' THEN 0 ELSE 1 END,
                m.conf DESC NULLS LAST,
                m.extract_rule_id ASC
        ) AS rn
    FROM matches m
),
won AS (
    SELECT *
    FROM ranked
    WHERE rn = 1
      AND value_raw IS NOT NULL
      AND TRIM(value_raw) <> ''
),
cleaned AS (
    SELECT
        w.*,
        CASE
            WHEN w.db_type IN ('DOUBLE', 'INT') THEN TRIM(
                REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
                    COALESCE(w.value_raw, ''),
                    '±', ''),
                    '~', ' '),
                    '≤', ''),
                    '≥', ''),
                    ',', ''),
                    '，', ''),
                    '  ', ' ')
            )
            ELSE TRIM(
                REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
                    COALESCE(w.value_raw, ''),
                    '±', ''),
                    '~', ' '),
                    '≤', ''),
                    '≥', ''),
                    '  ', ' ')
            )
        END AS clean_str
    FROM won w
),
numunit AS (
    SELECT
        c.id,
        c.l1_code,
        c.schema_v,
        c.l2_code,
        c.l3_id,
        c.l3_code,
        c.extract_rule_id,
        c.std_attr_code,
        c.priority,
        c.value_raw,
        c.std_attr_cn,
        c.db_type,
        c.unit_std,
        c.min_bound,
        c.max_bound,
        c.clean_str,
        CASE
            WHEN c.db_type NOT IN ('DOUBLE', 'INT') THEN NULL
            ELSE CAST(
                NULLIF(
                    regexp_extract(c.clean_str, '-?\\d+(\\.\\d+)?([eE][+-]?\\d+)?', 0),
                    ''
                ) AS DOUBLE
            )
        END AS num_raw,
        CASE
            WHEN c.db_type NOT IN ('DOUBLE', 'INT') THEN NULL
            ELSE NULLIF(
                TRIM(
                    regexp_extract(
                        TRIM(
                            regexp_replace(
                                c.clean_str,
                                '^[^\\d\\-]*-?\\d+(\\.\\d+)?([eE][+-]?\\d+)?\\s*',
                                ''
                            )
                        ),
                        '^[^\\s,@()]+',
                        0
                    )
                ),
                ''
            )
        END AS unit_raw
    FROM cleaned c
),
scaled AS (
    SELECT
        n.id,
        n.l1_code,
        n.schema_v,
        n.l2_code,
        n.l3_id,
        n.l3_code,
        n.extract_rule_id,
        n.std_attr_code,
        n.priority,
        n.value_raw,
        n.std_attr_cn,
        n.db_type,
        n.unit_std,
        n.min_bound,
        n.max_bound,
        n.clean_str,
        n.num_raw,
        n.unit_raw,
        f.factor,
        CASE
            WHEN n.db_type NOT IN ('DOUBLE', 'INT') THEN NULL
            WHEN n.num_raw IS NULL THEN NULL
            WHEN n.unit_std IS NULL OR trim(cast(n.unit_std AS VARCHAR)) = '' THEN n.num_raw
            WHEN f.factor IS NOT NULL THEN n.num_raw * f.factor
            ELSE n.num_raw
        END AS num_std
    FROM numunit n
    LEFT JOIN dim.dim_unit_factor f
           ON f.target_unit = n.unit_std
          AND f.unit_raw = coalesce(nullif(trim(cast(n.unit_raw AS VARCHAR)), ''), '')
),
typed AS (
    SELECT
        s.id,
        s.l2_code,
        s.l3_id,
        s.l3_code,
        s.schema_v AS attr_schema_version,
        s.std_attr_code,
        s.std_attr_cn,
        s.db_type,
        s.unit_std,
        s.value_raw,
        s.extract_rule_id,
        s.priority AS match_priority,
        s.clean_str,
        CASE
            WHEN s.db_type = 'VARCHAR' THEN NULL
            WHEN s.db_type = 'BOOLEAN' THEN
                CASE
                    WHEN lower(trim(s.clean_str)) IN ('true', '1', 't', 'yes', 'y') THEN 1
                    WHEN lower(trim(s.clean_str)) IN ('false', '0', 'f', 'no', 'n') THEN 0
                    WHEN s.std_attr_code IN ('rohs_compliant', 'lead_free', 'flameproof')
                         AND s.clean_str IN ('符合', '不含铅', '无铅') THEN 1
                    WHEN s.std_attr_code IN ('rohs_compliant', 'lead_free', 'flameproof')
                         AND s.clean_str IN ('不符合', '含铅') THEN 0
                    WHEN s.std_attr_code = 'reach'
                         AND lower(trim(s.clean_str)) = 'compliant' THEN 1
                    WHEN s.std_attr_code = 'reach'
                         AND lower(trim(s.clean_str)) = 'not_compliant' THEN 0
                    ELSE NULL
                END
            WHEN s.db_type NOT IN ('DOUBLE', 'INT') THEN NULL
            WHEN s.num_std IS NULL THEN NULL
            WHEN s.min_bound IS NOT NULL AND s.num_std < s.min_bound THEN NULL
            WHEN s.max_bound IS NOT NULL AND s.num_std > s.max_bound THEN NULL
            ELSE s.num_std
        END AS value_std_double,
        CASE
            WHEN s.db_type NOT IN ('VARCHAR', 'ENUM') THEN NULL
            ELSE NULLIF(TRIM(s.clean_str), '')
        END AS value_std_varchar,
        CASE
            WHEN s.db_type = 'BOOLEAN'
                 AND lower(trim(s.clean_str)) NOT IN ('true', 'false', '1', '0', 't', 'f', 'yes', 'no', 'y', 'n')
                 AND NULLIF(TRIM(s.clean_str), '') IS NOT NULL
                 AND NOT (s.std_attr_code IN ('rohs_compliant', 'lead_free', 'flameproof')
                          AND s.clean_str IN ('符合', '不符合', '不含铅', '含铅', '无铅'))
                 AND NOT (s.std_attr_code = 'reach'
                          AND lower(trim(s.clean_str)) IN ('compliant', 'not_compliant'))
                THEN 'parse_fail'
            WHEN s.db_type IN ('DOUBLE', 'INT')
                 AND s.num_std IS NOT NULL
                 AND s.min_bound IS NOT NULL
                 AND s.num_std < s.min_bound
                THEN 'out_of_range'
            WHEN s.db_type IN ('DOUBLE', 'INT')
                 AND s.num_std IS NOT NULL
                 AND s.max_bound IS NOT NULL
                 AND s.num_std > s.max_bound
                THEN 'out_of_range'
            WHEN s.db_type IN ('DOUBLE', 'INT')
                 AND s.num_raw IS NULL
                 AND NULLIF(TRIM(s.clean_str), '') IS NOT NULL
                THEN 'parse_fail'
            ELSE NULL
        END AS dq_flag
    FROM scaled s
)
SELECT
    'pcb_attr_extract_pipe' AS data_source,
    id,
    std_attr_code,
    l2_code,
    l3_id,
    l3_code,
    attr_schema_version,
    std_attr_cn,
    db_type,
    unit_std,
    value_raw,
    extract_rule_id,
    match_priority,
    clean_str,
    value_std_double,
    value_std_varchar,
    dq_flag,
    CURRENT_TIMESTAMP(),
    CURRENT_TIMESTAMP()
FROM typed;

/* ---------- 验收 ---------- */
SELECT 'eav_rows' AS what, COUNT(*) AS n
FROM dwd.dwd_component_attr_std
WHERE data_source = 'pcb_attr_extract_pipe';

SELECT l2_code, l3_code, COUNT(DISTINCT id) AS parts, COUNT(*) AS attr_rows
FROM dwd.dwd_component_attr_std
WHERE data_source = 'pcb_attr_extract_pipe'
GROUP BY l2_code, l3_code;

SELECT std_attr_code, COUNT(*) AS cnt
FROM dwd.dwd_component_attr_std
WHERE data_source = 'pcb_attr_extract_pipe'
GROUP BY std_attr_code
ORDER BY cnt DESC
LIMIT 25;
