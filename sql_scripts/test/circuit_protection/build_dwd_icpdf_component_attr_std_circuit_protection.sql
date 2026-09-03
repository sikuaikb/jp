/* test/circuit_protection build -> test_dwd.dwd_component_attr_std_circuit_protection
 * 由 switch 引擎模板派生；dim 指向 test_dim.dim_attr_*_circuit_protection
 */
-- DDL 见 dwd_component_attr_std.sql（首次部署或字段变更时单独执行）
DELETE FROM test_dwd.dwd_component_attr_std_circuit_protection WHERE data_source = 'icpdf';
INSERT INTO test_dwd.dwd_component_attr_std_circuit_protection
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
    FROM test_dim.dim_attr_schema_circuit_protection d
    WHERE d.scope_level = 'l2'
    GROUP BY d.l1_code, d.scope_code
),
ids AS (
    SELECT
        p.id,
        p.prajson,
        p.prajson2,
        p.category,
        p.category2,
        p.taginfo,
        p.category_info,
        c.l1_code,
        c.l2_code,
        c.l3_id,
        c.l3_code,
        cat.schema_v
    FROM dwd.dwd_icpdf_component_param p
    INNER JOIN test_dwd.dwd_component_class_circuit_protection c ON c.id = p.id AND c.data_source = 'icpdf'
    INNER JOIN attr_l2_catalog cat
            ON cat.l1_code = c.l1_code
           AND cat.l2_code = c.l2_code
    WHERE (p.prajson IS NOT NULL OR p.prajson2 IS NOT NULL)
),
ids_tag_tokens AS (
    SELECT
        i.id,
        i.l1_code,
        i.schema_v,
        i.l2_code,
        i.l3_id,
        i.l3_code,
        trim(tag) AS tok
    FROM ids i,
         UNNEST(coalesce(i.taginfo, CAST([] AS ARRAY<VARCHAR(256)>))) AS tags(tag)
    WHERE trim(tag) <> ''
),
ids_ci_tokens AS (
    SELECT
        i.id,
        i.l1_code,
        i.schema_v,
        i.l2_code,
        i.l3_id,
        i.l3_code,
        trim(crumb) AS tok
    FROM ids i,
         UNNEST(coalesce(i.category_info, CAST([] AS ARRAY<VARCHAR(256)>))) AS crumbs(crumb)
    WHERE trim(crumb) <> ''
),
taxonomy_from_dim AS (
    SELECT
        i.id,
        i.l1_code,
        i.schema_v,
        i.l2_code,
        i.l3_id,
        i.l3_code,
        r.extract_rule_id,
        r.std_attr_code,
        r.priority,
        r.literal_std_value AS value_raw,
        s.std_attr_cn,
        s.db_type,
        s.unit_std,
        s.min_bound,
        s.max_bound
    FROM ids i
    INNER JOIN test_dim.dim_attr_extract_rule_circuit_protection r
            ON r.schema_version = i.schema_v
           AND r.l1_code = i.l1_code
           AND r.enabled = 1
           AND r.data_source = 'icpdf'
           AND r.source_kind = 'param_category2_eq'
           AND trim(coalesce(i.category2, '')) = r.source_expr
    INNER JOIN test_dim.dim_attr_schema_circuit_protection s
            ON s.schema_version = r.schema_version
           AND s.l1_code = r.l1_code
           AND s.std_attr_code = r.std_attr_code
           AND (
                (s.scope_level = 'l2' AND s.scope_code = i.l2_code)
             OR (s.scope_level = 'l3' AND s.scope_code = i.l3_code)
           )
    WHERE r.literal_std_value IS NOT NULL
      AND trim(coalesce(i.category2, '')) <> ''
      AND (
          (r.apply_scope_level IS NULL AND r.apply_scope_code IS NULL)
          OR (r.apply_scope_level = 'l2' AND r.apply_scope_code = i.l2_code)
          OR (r.apply_scope_level = 'l3' AND r.apply_scope_code = i.l3_code)
      )

    UNION ALL

    SELECT
        i.id,
        i.l1_code,
        i.schema_v,
        i.l2_code,
        i.l3_id,
        i.l3_code,
        r.extract_rule_id,
        r.std_attr_code,
        r.priority,
        r.literal_std_value AS value_raw,
        s.std_attr_cn,
        s.db_type,
        s.unit_std,
        s.min_bound,
        s.max_bound
    FROM ids i
    INNER JOIN test_dim.dim_attr_extract_rule_circuit_protection r
            ON r.schema_version = i.schema_v
           AND r.l1_code = i.l1_code
           AND r.enabled = 1
           AND r.data_source = 'icpdf'
           AND r.source_kind = 'param_category_eq'
           AND trim(coalesce(i.category, '')) = r.source_expr
    INNER JOIN test_dim.dim_attr_schema_circuit_protection s
            ON s.schema_version = r.schema_version
           AND s.l1_code = r.l1_code
           AND s.std_attr_code = r.std_attr_code
           AND (
                (s.scope_level = 'l2' AND s.scope_code = i.l2_code)
             OR (s.scope_level = 'l3' AND s.scope_code = i.l3_code)
           )
    WHERE r.literal_std_value IS NOT NULL
      AND trim(coalesce(i.category, '')) <> ''
      AND (
          (r.apply_scope_level IS NULL AND r.apply_scope_code IS NULL)
          OR (r.apply_scope_level = 'l2' AND r.apply_scope_code = i.l2_code)
          OR (r.apply_scope_level = 'l3' AND r.apply_scope_code = i.l3_code)
      )

    UNION ALL

    SELECT
        x.id,
        x.l1_code,
        x.schema_v,
        x.l2_code,
        x.l3_id,
        x.l3_code,
        r.extract_rule_id,
        r.std_attr_code,
        r.priority,
        r.literal_std_value AS value_raw,
        s.std_attr_cn,
        s.db_type,
        s.unit_std,
        s.min_bound,
        s.max_bound
    FROM ids_tag_tokens x
    INNER JOIN test_dim.dim_attr_extract_rule_circuit_protection r
            ON r.schema_version = x.schema_v
           AND r.l1_code = x.l1_code
           AND r.enabled = 1
           AND r.data_source = 'icpdf'
           AND r.source_kind = 'param_taginfo_eq'
           AND x.tok = r.source_expr
    INNER JOIN test_dim.dim_attr_schema_circuit_protection s
            ON s.schema_version = r.schema_version
           AND s.l1_code = r.l1_code
           AND s.std_attr_code = r.std_attr_code
           AND (
                (s.scope_level = 'l2' AND s.scope_code = x.l2_code)
             OR (s.scope_level = 'l3' AND s.scope_code = x.l3_code)
           )
    WHERE r.literal_std_value IS NOT NULL
      AND (
          (r.apply_scope_level IS NULL AND r.apply_scope_code IS NULL)
          OR (r.apply_scope_level = 'l2' AND r.apply_scope_code = x.l2_code)
          OR (r.apply_scope_level = 'l3' AND r.apply_scope_code = x.l3_code)
      )

    UNION ALL

    SELECT
        x.id,
        x.l1_code,
        x.schema_v,
        x.l2_code,
        x.l3_id,
        x.l3_code,
        r.extract_rule_id,
        r.std_attr_code,
        r.priority,
        r.literal_std_value AS value_raw,
        s.std_attr_cn,
        s.db_type,
        s.unit_std,
        s.min_bound,
        s.max_bound
    FROM ids_ci_tokens x
    INNER JOIN test_dim.dim_attr_extract_rule_circuit_protection r
            ON r.schema_version = x.schema_v
           AND r.l1_code = x.l1_code
           AND r.enabled = 1
           AND r.data_source = 'icpdf'
           AND r.source_kind = 'param_category_info_eq'
           AND x.tok = r.source_expr
    INNER JOIN test_dim.dim_attr_schema_circuit_protection s
            ON s.schema_version = r.schema_version
           AND s.l1_code = r.l1_code
           AND s.std_attr_code = r.std_attr_code
           AND (
                (s.scope_level = 'l2' AND s.scope_code = x.l2_code)
             OR (s.scope_level = 'l3' AND s.scope_code = x.l3_code)
           )
    WHERE r.literal_std_value IS NOT NULL
      AND (
          (r.apply_scope_level IS NULL AND r.apply_scope_code IS NULL)
          OR (r.apply_scope_level = 'l2' AND r.apply_scope_code = x.l2_code)
          OR (r.apply_scope_level = 'l3' AND r.apply_scope_code = x.l3_code)
      )
),
prajson2_kv AS (
    SELECT
        v.id,
        v.l1_code,
        v.schema_v,
        v.l2_code,
        v.l3_id,
        v.l3_code,
        k AS match_key,
        NULLIF(TRIM(get_json_string(v.prajson2, concat('$."', k, '"'))), '') AS raw_value
    FROM ids v,
         UNNEST(CAST(json_keys(v.prajson2) AS ARRAY<VARCHAR(256)>)) AS u(k)
    WHERE v.prajson2 IS NOT NULL
),
prajson_kv AS (
    SELECT
        v.id,
        v.l1_code,
        v.schema_v,
        v.l2_code,
        v.l3_id,
        v.l3_code,
        NULLIF(TRIM(get_json_string(e, '$.sqlname')), '') AS sqln,
        NULLIF(TRIM(get_json_string(e, '$.cn')), '') AS cn,
        NULLIF(TRIM(get_json_string(e, '$.value')), '') AS raw_value
    FROM ids v
    INNER JOIN dwd.dwd_icpdf_component_param p ON p.id = v.id,
         UNNEST(CAST(p.prajson AS ARRAY<JSON>)) AS t(e)
    WHERE p.prajson IS NOT NULL
),
matches AS (
    SELECT
        kv.id,
        kv.l1_code,
        kv.schema_v,
        kv.l2_code,
        kv.l3_id,
        kv.l3_code,
        r.extract_rule_id,
        r.std_attr_code,
        r.priority,
        COALESCE(
            r.literal_std_value,
            CASE
                WHEN r.source_value_regex IS NOT NULL AND r.source_value_regex <> ''
                    THEN NULLIF(regexp_extract(kv.raw_value, r.source_value_regex, 1), '')
                ELSE kv.raw_value
            END
        ) AS value_raw,
        s.std_attr_cn,
        s.db_type,
        s.unit_std,
        s.min_bound,
        s.max_bound,
        r.value_map
    FROM prajson2_kv kv
    INNER JOIN test_dim.dim_attr_extract_rule_circuit_protection r
            ON r.schema_version = kv.schema_v
           AND r.l1_code = kv.l1_code
           AND r.enabled = 1
           AND r.data_source = 'icpdf'
           AND r.source_kind = 'prajson2_key_eq'
           AND kv.match_key = r.source_expr
    INNER JOIN test_dim.dim_attr_schema_circuit_protection s
            ON s.schema_version = r.schema_version
           AND s.l1_code = r.l1_code
           AND s.std_attr_code = r.std_attr_code
           AND (
                (s.scope_level = 'l2' AND s.scope_code = kv.l2_code)
             OR (s.scope_level = 'l3' AND s.scope_code = kv.l3_code)
           )
    WHERE kv.raw_value IS NOT NULL
      AND (
            r.source_value_expr IS NULL
         OR lower(trim(kv.raw_value)) = lower(trim(r.source_value_expr))
          )
      AND (
          (r.apply_scope_level IS NULL AND r.apply_scope_code IS NULL)
          OR (r.apply_scope_level = 'l2' AND r.apply_scope_code = kv.l2_code)
          OR (r.apply_scope_level = 'l3' AND r.apply_scope_code = kv.l3_code)
      )

    UNION ALL

    SELECT
        kv.id,
        kv.l1_code,
        kv.schema_v,
        kv.l2_code,
        kv.l3_id,
        kv.l3_code,
        r.extract_rule_id,
        r.std_attr_code,
        r.priority,
        COALESCE(
            r.literal_std_value,
            CASE
                WHEN r.source_value_regex IS NOT NULL AND r.source_value_regex <> ''
                    THEN NULLIF(regexp_extract(kv.raw_value, r.source_value_regex, 1), '')
                ELSE kv.raw_value
            END
        ) AS value_raw,
        s.std_attr_cn,
        s.db_type,
        s.unit_std,
        s.min_bound,
        s.max_bound,
        r.value_map
    FROM prajson_kv kv
    INNER JOIN test_dim.dim_attr_extract_rule_circuit_protection r
            ON r.schema_version = kv.schema_v
           AND r.l1_code = kv.l1_code
           AND r.enabled = 1
           AND r.data_source = 'icpdf'
           AND r.source_kind = 'prajson_cn_eq'
           AND kv.cn = r.source_expr
    INNER JOIN test_dim.dim_attr_schema_circuit_protection s
            ON s.schema_version = r.schema_version
           AND s.l1_code = r.l1_code
           AND s.std_attr_code = r.std_attr_code
           AND (
                (s.scope_level = 'l2' AND s.scope_code = kv.l2_code)
             OR (s.scope_level = 'l3' AND s.scope_code = kv.l3_code)
           )
    WHERE kv.raw_value IS NOT NULL
      AND (
            r.source_value_expr IS NULL
         OR lower(trim(kv.raw_value)) = lower(trim(r.source_value_expr))
          )
      AND (
          (r.apply_scope_level IS NULL AND r.apply_scope_code IS NULL)
          OR (r.apply_scope_level = 'l2' AND r.apply_scope_code = kv.l2_code)
          OR (r.apply_scope_level = 'l3' AND r.apply_scope_code = kv.l3_code)
      )

    UNION ALL

    SELECT
        kv.id,
        kv.l1_code,
        kv.schema_v,
        kv.l2_code,
        kv.l3_id,
        kv.l3_code,
        r.extract_rule_id,
        r.std_attr_code,
        r.priority,
        COALESCE(
            r.literal_std_value,
            CASE
                WHEN r.source_value_regex IS NOT NULL AND r.source_value_regex <> ''
                    THEN NULLIF(regexp_extract(kv.raw_value, r.source_value_regex, 1), '')
                ELSE kv.raw_value
            END
        ) AS value_raw,
        s.std_attr_cn,
        s.db_type,
        s.unit_std,
        s.min_bound,
        s.max_bound,
        r.value_map
    FROM prajson_kv kv
    INNER JOIN test_dim.dim_attr_extract_rule_circuit_protection r
            ON r.schema_version = kv.schema_v
           AND r.l1_code = kv.l1_code
           AND r.enabled = 1
           AND r.data_source = 'icpdf'
           AND r.source_kind = 'prajson_sqlname_eq'
           AND kv.sqln = r.source_expr
    INNER JOIN test_dim.dim_attr_schema_circuit_protection s
            ON s.schema_version = r.schema_version
           AND s.l1_code = r.l1_code
           AND s.std_attr_code = r.std_attr_code
           AND (
                (s.scope_level = 'l2' AND s.scope_code = kv.l2_code)
             OR (s.scope_level = 'l3' AND s.scope_code = kv.l3_code)
           )
    WHERE kv.raw_value IS NOT NULL
      AND kv.sqln IS NOT NULL
      AND (
            r.source_value_expr IS NULL
         OR lower(trim(kv.raw_value)) = lower(trim(r.source_value_expr))
          )
      AND (
          (r.apply_scope_level IS NULL AND r.apply_scope_code IS NULL)
          OR (r.apply_scope_level = 'l2' AND r.apply_scope_code = kv.l2_code)
          OR (r.apply_scope_level = 'l3' AND r.apply_scope_code = kv.l3_code)
      )

    UNION ALL

    SELECT
        tb.id,
        tb.l1_code,
        tb.schema_v,
        tb.l2_code,
        tb.l3_id,
        tb.l3_code,
        tb.extract_rule_id,
        tb.std_attr_code,
        tb.priority,
        tb.value_raw,
        tb.std_attr_cn,
        tb.db_type,
        tb.unit_std,
        tb.min_bound,
        tb.max_bound,
        CAST(NULL AS JSON) AS value_map
    FROM taxonomy_from_dim tb
),
ranked AS (
    SELECT
        id,
        l1_code,
        schema_v,
        l2_code,
        l3_id,
        l3_code,
        extract_rule_id,
        std_attr_code,
        priority,
        value_raw,
        std_attr_cn,
        db_type,
        unit_std,
        min_bound,
        max_bound,
        value_map,
        ROW_NUMBER() OVER (
            PARTITION BY id, std_attr_code
            ORDER BY priority ASC, extract_rule_id ASC
        ) AS rn
    FROM matches
),
won AS (
    SELECT *
    FROM ranked
    WHERE rn = 1
      AND value_raw IS NOT NULL
      AND TRIM(value_raw) <> ''
),
cleaned AS (
    /* 1) value_map 命中：用映射后的标准值（如 "符合"→"TRUE"）
     * 2) 未命中且 value_map 含 "_default"：用默认值
     * 3) value_map 为 NULL：按 db_type 走符号清洗
     *    数值(DOUBLE/INT)：剥 ± / ~ / ≤ / ≥ 及半角/全角逗号
     *    文本/布尔：仅剥 ± / ~ / ≤ / ≥，不剥逗号 */
    SELECT
        w.*,
        CASE
            WHEN w.value_map IS NOT NULL
                 AND get_json_string(w.value_map,
                        concat('$."', replace(
                            replace(TRIM(COALESCE(w.value_raw, '')), UNHEX('C2A0'), ' '),
                            '"', '\\"'), '"')
                     ) IS NOT NULL
                THEN get_json_string(w.value_map,
                        concat('$."', replace(
                            replace(TRIM(COALESCE(w.value_raw, '')), UNHEX('C2A0'), ' '),
                            '"', '\\"'), '"'))
            WHEN w.value_map IS NOT NULL
                 AND get_json_string(w.value_map, '$._default') IS NOT NULL
                THEN get_json_string(w.value_map, '$._default')
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
    LEFT JOIN test_dim.dim_unit_factor f
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
                    /* ICPDF prajson2 中文/英文原文（value_map 未覆盖时的兜底） */
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
    'icpdf' AS data_source,
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
