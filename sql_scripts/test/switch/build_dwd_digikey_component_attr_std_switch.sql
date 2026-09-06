/* ============================================================
 * DigiKey → 标准属性窄表 EAV（写入 test_dwd.dwd_component_attr_std_switch，data_source='digikey'）
 *
 * 起源：sql_scripts/2.attribute_standard/build_dwd_icpdf_component_attr_std.sql
 *      表名/库名已固化替换；新增 DigiKey 中文 boolean 解析支持。
 *
 * 依赖：
 *   test_dim.dim_attr_schema_switch、test_dim.dim_attr_extract_rule_switch、test_dim.dim_unit_factor
 *   dwd.dwd_digikey_component_param、test_dwd.dwd_component_class_switch
 *
 * 约束：同一 `(l1_code, l2_code)` 在 dim_attr_schema 中应只对应 **单一** `schema_version`。
 *
 * 下游：通用 L2 build SQL（无源后缀；从 dwd_component_attr_std 拉取所有源数据）。
 *
 * 执行：mysql … < sql_scripts/2.attribute_standard/build_dwd_component_attr_std_digikey.sql
 *
 * DigiKey 与 ICPDF 关键差异：
 *   - DigiKey 没有 prajson array<{cn,value}> 结构 → prajson_cn_eq 规则不会命中（CTE 内 UNNEST 走空集）
 *   - DigiKey 的 prajson2 在 adapter 阶段保留为 NULL，所有 JSON 数据合并到 prajson 中（顶层 cn key 对象）
 *     → 注意：DigiKey 数据上 prajson2_key_eq 规则不会命中（prajson2 IS NULL）
 *     → 抽取规则 csv 中 DigiKey 专属规则需用 source_kind='prajson_key_eq' 或新增规则类型
 *
 * value 中文枚举映射（如 "在售"→Active）：见 normalize_digikey_l2_values.sql（L2 build 后跑）
 * ============================================================ */

-- DDL 见 dwd_component_attr_std.sql（首次部署或字段变更时单独执行）
DELETE FROM test_dwd.dwd_component_attr_std_switch WHERE data_source = 'digikey';
INSERT INTO test_dwd.dwd_component_attr_std_switch
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
    FROM test_dim.dim_attr_schema_switch d
    WHERE d.scope_level = 'l2'
    GROUP BY d.l1_code, d.scope_code
),
ids AS (
    SELECT
        p.id,
        /* DigiKey: prajson 是合并的顶层 cn key 对象（对应 ICPDF prajson2 语义）；
         * 把它别名为 prajson2 让下游所有 prajson2_key_eq 处理段直接复用。
         * prajson2_kv 走这个对象拆 key；prajson_kv (ICPDF array<{cn,value}>) 在 DigiKey 上返回空集。 */
        CAST(NULL AS JSON) AS prajson,
        p.prajson         AS prajson2,
        p.category,
        p.category2,
        p.taginfo,
        p.category_info,
        c.l1_code,
        c.l2_code,
        c.l3_id,
        c.l3_code,
        cat.schema_v
    FROM dwd.dwd_digikey_component_param p
    INNER JOIN test_dwd.dwd_component_class_switch c ON c.id = p.id AND c.data_source = 'digikey'
    INNER JOIN attr_l2_catalog cat
            ON cat.l1_code = c.l1_code
           AND cat.l2_code = c.l2_code
    WHERE p.prajson IS NOT NULL
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
        s.max_bound,
        r.value_map
    FROM ids i
    INNER JOIN test_dim.dim_attr_extract_rule_switch r
            ON r.schema_version = i.schema_v
           AND r.l1_code = i.l1_code
           AND r.enabled = 1
           AND r.data_source = 'digikey'
           AND r.source_kind = 'param_category2_eq'
           AND trim(coalesce(i.category2, '')) = r.source_expr
    INNER JOIN test_dim.dim_attr_schema_switch s
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
        s.max_bound,
        r.value_map
    FROM ids i
    INNER JOIN test_dim.dim_attr_extract_rule_switch r
            ON r.schema_version = i.schema_v
           AND r.l1_code = i.l1_code
           AND r.enabled = 1
           AND r.data_source = 'digikey'
           AND r.source_kind = 'param_category_eq'
           AND trim(coalesce(i.category, '')) = r.source_expr
    INNER JOIN test_dim.dim_attr_schema_switch s
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
        s.max_bound,
        r.value_map
    FROM ids_tag_tokens x
    INNER JOIN test_dim.dim_attr_extract_rule_switch r
            ON r.schema_version = x.schema_v
           AND r.l1_code = x.l1_code
           AND r.enabled = 1
           AND r.data_source = 'digikey'
           AND r.source_kind = 'param_taginfo_eq'
           AND x.tok = r.source_expr
    INNER JOIN test_dim.dim_attr_schema_switch s
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
        s.max_bound,
        r.value_map
    FROM ids_ci_tokens x
    INNER JOIN test_dim.dim_attr_extract_rule_switch r
            ON r.schema_version = x.schema_v
           AND r.l1_code = x.l1_code
           AND r.enabled = 1
           AND r.data_source = 'digikey'
           AND r.source_kind = 'param_category_info_eq'
           AND x.tok = r.source_expr
    INNER JOIN test_dim.dim_attr_schema_switch s
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
    /* DigiKey 没有 ICPDF prajson 那种 array<{cn,value,sqlname}> 结构，
     * 让这段永远返回空集；所有 prajson_cn_eq / prajson_sqln_eq 规则在 DigiKey 上不命中。 */
    SELECT
        v.id,
        v.l1_code,
        v.schema_v,
        v.l2_code,
        v.l3_id,
        v.l3_code,
        CAST(NULL AS VARCHAR(256)) AS sqln,
        CAST(NULL AS VARCHAR(256)) AS cn,
        CAST(NULL AS VARCHAR(1024)) AS raw_value
    FROM ids v
    WHERE 1 = 0
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
    INNER JOIN test_dim.dim_attr_extract_rule_switch r
            ON r.schema_version = kv.schema_v
           AND r.l1_code = kv.l1_code
           AND r.enabled = 1
           AND r.data_source = 'digikey'
           AND r.source_kind = 'prajson2_key_eq'
           AND kv.match_key = r.source_expr
    INNER JOIN test_dim.dim_attr_schema_switch s
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
    INNER JOIN test_dim.dim_attr_extract_rule_switch r
            ON r.schema_version = kv.schema_v
           AND r.l1_code = kv.l1_code
           AND r.enabled = 1
           AND r.data_source = 'digikey'
           AND r.source_kind = 'prajson_cn_eq'
           AND kv.cn = r.source_expr
    INNER JOIN test_dim.dim_attr_schema_switch s
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
    INNER JOIN test_dim.dim_attr_extract_rule_switch r
            ON r.schema_version = kv.schema_v
           AND r.l1_code = kv.l1_code
           AND r.enabled = 1
           AND r.data_source = 'digikey'
           AND r.source_kind = 'prajson_sqlname_eq'
           AND kv.sqln = r.source_expr
    INNER JOIN test_dim.dim_attr_schema_switch s
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
        tb.value_map
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
    /* 1) value_map 命中：用映射后的标准值（如 "在售"→"Active"）
     * 2) 未命中且 value_map 含 "_default"：用默认值
     * 3) value_map 为 NULL：走原 ± / ~ / ≤ / ≥ / , 符号清洗
     * 注：用 trim(value_raw) 作为 json path 的 key；
     *     先把不换行空格 U+00A0（UTF-8: C2A0）替换为普通空格再查找，
     *     避免 DK 源数据中混用两种空格导致 JSON key 匹配失败。*/
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
            ELSE TRIM(
                REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
                    COALESCE(w.value_raw, ''),
                    '±', ''),
                    '~', ' '),
                    '≤', ''),
                    '≥', ''),
                    ',', ''),
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
                    /* DigiKey 中文：RoHS / Lead_Free 类（"符合 ROHS3 规范"等）*/
                    WHEN s.std_attr_code IN ('rohs_compliant', 'lead_free', 'flameproof')
                         AND s.clean_str LIKE '符合%' THEN 1
                    WHEN s.std_attr_code IN ('rohs_compliant', 'lead_free', 'flameproof')
                         AND (s.clean_str LIKE '不符合%' OR s.clean_str = '不适用') THEN 0
                    /* DigiKey REACH 状态：「不受 REACH影响」= 合规 TRUE；「受 REACH 影响」= 不合规 FALSE */
                    WHEN s.std_attr_code = 'reach' AND s.clean_str LIKE '不受 REACH%' THEN 1
                    WHEN s.std_attr_code = 'reach' AND s.clean_str LIKE '受 REACH%' THEN 0
                    WHEN s.std_attr_code = 'reach' AND s.clean_str LIKE '符合%' THEN 1
                    ELSE NULL
                END
            WHEN s.db_type NOT IN ('DOUBLE', 'INT') THEN NULL  -- VARCHAR/BOOLEAN/ENUM 均由其专属分支处理
            WHEN s.num_std IS NULL THEN NULL
            WHEN s.min_bound IS NOT NULL AND s.num_std < s.min_bound THEN NULL
            WHEN s.max_bound IS NOT NULL AND s.num_std > s.max_bound THEN NULL
            ELSE s.num_std
        END AS value_std_double,
        CASE
            /* ENUM 与 VARCHAR 同样存入 value_std_varchar（value_map 已在 clean_str 中完成映射） */
            WHEN s.db_type NOT IN ('VARCHAR', 'ENUM') THEN NULL
            ELSE NULLIF(TRIM(s.clean_str), '')
        END AS value_std_varchar,
        CASE
            WHEN s.db_type = 'BOOLEAN'
                 AND lower(trim(s.clean_str)) NOT IN ('true', 'false', '1', '0', 't', 'f', 'yes', 'no', 'y', 'n')
                 AND NULLIF(TRIM(s.clean_str), '') IS NOT NULL
                 /* DigiKey 中文已识别路径不算 parse_fail */
                 AND NOT (s.std_attr_code IN ('rohs_compliant', 'lead_free', 'flameproof')
                          AND (s.clean_str LIKE '符合%' OR s.clean_str LIKE '不符合%' OR s.clean_str = '不适用'))
                 AND NOT (s.std_attr_code = 'reach'
                          AND (s.clean_str LIKE '不受 REACH%' OR s.clean_str LIKE '受 REACH%' OR s.clean_str LIKE '符合%'))
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
    'digikey' AS data_source,
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


/* ---------- 校验（仅 digikey 源） ---------- */
SELECT 'eav_total'      AS what, COUNT(*)               AS rows_ FROM test_dwd.dwd_component_attr_std_switch WHERE data_source='digikey'
UNION ALL SELECT 'distinct_ids',   COUNT(DISTINCT id)             FROM test_dwd.dwd_component_attr_std_switch WHERE data_source='digikey'
UNION ALL SELECT 'has_value_dbl',  COUNT(*) FROM test_dwd.dwd_component_attr_std_switch WHERE data_source='digikey' AND value_std_double IS NOT NULL
UNION ALL SELECT 'has_value_str',  COUNT(*) FROM test_dwd.dwd_component_attr_std_switch WHERE data_source='digikey' AND value_std_varchar IS NOT NULL AND value_std_varchar <> ''
UNION ALL SELECT 'parse_fail_n',   COUNT(*) FROM test_dwd.dwd_component_attr_std_switch WHERE data_source='digikey' AND dq_flag='parse_fail'
UNION ALL SELECT 'out_of_range_n', COUNT(*) FROM test_dwd.dwd_component_attr_std_switch WHERE data_source='digikey' AND dq_flag='out_of_range';
