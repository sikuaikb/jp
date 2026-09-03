/* circuit_protection 试点：ICPDF → test_dwd.dwd_component_class_circuit_protection
 *
 * 读：dwd.dwd_icpdf_component_param（prod 只读）
 * 维表：test_dim.dim_l3_classify_rule_circuit_protection + dim_l3_classify_circuit_protection
 * 写：test_dwd.dwd_component_class_circuit_protection（data_source='icpdf'）
 *
 * 重新生成：python gen_build_classify_sql.py
 */

DELETE FROM test_dwd.dwd_component_class_circuit_protection WHERE data_source = 'icpdf';

INSERT INTO test_dwd.dwd_component_class_circuit_protection
(
    id, data_source,
    l1_code, l2_code, l3_code, l3_id,
    rule_id, phase, classify_source, matched_priority, matched_value, confidence,
    create_at, update_at
)
WITH
/* 多源统一事实表：同时暴露 prajson / prajson2，由 field_code 选列 */
param_all AS (
    SELECT
        id, CAST('icpdf' AS VARCHAR(32)) AS data_source,
        category, category2, taginfo, category_info,
        note, note_cn, partno,
        prajson, prajson2
    FROM dwd.dwd_icpdf_component_param
),
rules_gate AS (
    /* gate_<l1>_<source>_vN；l1 可含下划线（如 mcu_mpu_dsp / data_converter） */
    SELECT
        data_source,
        CASE
            WHEN rule_id REGEXP '^gate_.+_digikey_' THEN regexp_extract(rule_id, '^gate_(.+)_digikey_', 1)
            WHEN rule_id REGEXP '^gate_.+_icpdf_'  THEN regexp_extract(rule_id, '^gate_(.+)_icpdf_', 1)
            ELSE split_part(rule_id, '_', 2)
        END AS l1_code,
        field_code,
        match_value,
        match_values
    FROM test_dim.dim_l3_classify_rule_circuit_protection
    WHERE enabled = 1
      AND data_source = 'icpdf'
      AND rule_kind = 'gate'
),
/* gate：include（任一命中）减去 exclude（任一命中）；见 RULE_ENGINE.md §4 */
gate_include AS (
    SELECT p.id, p.data_source, gr.l1_code
    FROM param_all p
    INNER JOIN rules_gate gr
        ON gr.data_source = p.data_source
       AND ((gr.field_code = 'category_in'
             AND gr.match_values IS NOT NULL
             AND array_contains(gr.match_values, p.category))
         OR (gr.field_code = 'category2_in'
             AND gr.match_values IS NOT NULL
             AND array_contains(gr.match_values, p.category2))
         OR (gr.field_code = 'category_with_null_category2_in'
             AND gr.match_values IS NOT NULL
             AND p.category2 IS NULL
             AND array_contains(gr.match_values, p.category)))
    GROUP BY p.id, p.data_source, gr.l1_code
),
gate_exclude AS (
    SELECT p.id, p.data_source, gr.l1_code
    FROM param_all p
    INNER JOIN rules_gate gr
        ON gr.data_source = p.data_source
       AND (
            (gr.field_code = 'gate_exclude_note_cn'
             AND gr.match_value IS NOT NULL
             AND TRIM(gr.match_value) <> ''
             AND p.category = gr.match_value
             AND gr.match_values IS NOT NULL
             AND array_length(gr.match_values) > 0
             AND array_sum(
                 transform(
                     gr.match_values,
                     pat -> IF(p.note_cn IS NOT NULL AND p.note_cn LIKE pat, 1, 0)
                 )
             ) > 0)
         OR (gr.field_code = 'gate_exclude_null_note_cn'
             AND gr.match_value IS NOT NULL
             AND TRIM(gr.match_value) <> ''
             AND p.category = gr.match_value
             AND p.note_cn IS NULL)
         OR (gr.field_code = 'gate_exclude_category_like'
             AND gr.match_values IS NOT NULL
             AND array_length(gr.match_values) > 0
             AND array_sum(
                 transform(
                     gr.match_values,
                     pat -> IF(p.category IS NOT NULL AND p.category LIKE pat, 1, 0)
                 )
             ) > 0)
         OR (gr.field_code = 'gate_exclude_category2_note_cn'
             AND gr.match_value IS NOT NULL
             AND TRIM(gr.match_value) <> ''
             AND p.category2 = gr.match_value
             AND gr.match_values IS NOT NULL
             AND array_length(gr.match_values) > 0
             AND array_sum(
                 transform(
                     gr.match_values,
                     pat -> IF(p.note_cn IS NOT NULL AND p.note_cn LIKE pat, 1, 0)
                 )
             ) > 0)
       )
    GROUP BY p.id, p.data_source, gr.l1_code
),
gate_pass AS (
    SELECT i.id, i.data_source, i.l1_code
    FROM gate_include i
    LEFT JOIN gate_exclude e
        ON e.id = i.id
       AND e.data_source = i.data_source
       AND e.l1_code = i.l1_code
    WHERE e.id IS NULL
    GROUP BY i.id, i.data_source, i.l1_code
),
gate_param AS (
    SELECT
        gp.l1_code AS gate_l1,
        p.*
    FROM gate_pass gp
    INNER JOIN param_all p
        ON p.id = gp.id AND p.data_source = gp.data_source
),
rules_classify AS (
    SELECT
        r.*,
        d.l1_code,
        d.l2_code,
        d.l3_code
    FROM test_dim.dim_l3_classify_rule_circuit_protection r
    INNER JOIN test_dim.dim_l3_classify_circuit_protection d
        ON d.l3_id = r.l3_id
       AND d.schema_version = r.schema_version
    WHERE r.enabled = 1
      AND r.data_source = 'icpdf'
      AND r.rule_kind = 'classify'
),
rule_group_clause_cnt AS (
    SELECT
        rule_id,
        clause_group_id,
        COUNT(*) AS clause_cnt
    FROM rules_classify
    GROUP BY rule_id, clause_group_id
),
/* 各分支：(data_source, l1_code) 分区连接；谓词写入 JOIN，clause_ok 恒 TRUE */
classify_clause_eval AS (
    SELECT
        p.id, p.data_source, r.rule_id, r.clause_group_id, r.clause_ord,
        r.l3_id, r.phase, r.rule_priority, r.confidence_weight,
        r.classify_source_hint, r.l1_code, r.l2_code, r.l3_code,
        TRUE AS clause_ok
    FROM gate_param p
    INNER JOIN rules_classify r
        ON r.data_source = p.data_source
       AND r.l1_code = p.gate_l1
       AND r.field_code = 'category_eq'
       AND p.category IS NOT NULL
       AND r.match_value IS NOT NULL
       AND p.category = r.match_value

    UNION ALL

    SELECT
        p.id, p.data_source, r.rule_id, r.clause_group_id, r.clause_ord,
        r.l3_id, r.phase, r.rule_priority, r.confidence_weight,
        r.classify_source_hint, r.l1_code, r.l2_code, r.l3_code,
        TRUE AS clause_ok
    FROM gate_param p
    INNER JOIN rules_classify r
        ON r.data_source = p.data_source
       AND r.l1_code = p.gate_l1
       AND r.field_code = 'category2_eq'
       AND p.category2 IS NOT NULL
       AND r.match_value IS NOT NULL
       AND p.category2 = r.match_value

    UNION ALL

    SELECT
        p.id, p.data_source, r.rule_id, r.clause_group_id, r.clause_ord,
        r.l3_id, r.phase, r.rule_priority, r.confidence_weight,
        r.classify_source_hint, r.l1_code, r.l2_code, r.l3_code,
        TRUE AS clause_ok
    FROM gate_param p
    INNER JOIN rules_classify r
        ON r.data_source = p.data_source
       AND r.l1_code = p.gate_l1
       AND r.field_code = 'category_in'
       AND p.category IS NOT NULL
       AND r.match_values IS NOT NULL
       AND array_contains(r.match_values, p.category)

    UNION ALL

    SELECT
        p.id, p.data_source, r.rule_id, r.clause_group_id, r.clause_ord,
        r.l3_id, r.phase, r.rule_priority, r.confidence_weight,
        r.classify_source_hint, r.l1_code, r.l2_code, r.l3_code,
        TRUE AS clause_ok
    FROM gate_param p
    INNER JOIN rules_classify r
        ON r.data_source = p.data_source
       AND r.l1_code = p.gate_l1
       AND r.field_code = 'category2_in'
       AND p.category2 IS NOT NULL
       AND r.match_values IS NOT NULL
       AND array_contains(r.match_values, p.category2)

    UNION ALL

    SELECT
        p.id, p.data_source, r.rule_id, r.clause_group_id, r.clause_ord,
        r.l3_id, r.phase, r.rule_priority, r.confidence_weight,
        r.classify_source_hint, r.l1_code, r.l2_code, r.l3_code,
        TRUE AS clause_ok
    FROM gate_param p
    INNER JOIN rules_classify r
        ON r.data_source = p.data_source
       AND r.l1_code = p.gate_l1
       AND r.field_code = 'category_like'
       AND p.category IS NOT NULL
       AND r.match_value IS NOT NULL
       AND p.category LIKE r.match_value

    UNION ALL

    SELECT
        p.id, p.data_source, r.rule_id, r.clause_group_id, r.clause_ord,
        r.l3_id, r.phase, r.rule_priority, r.confidence_weight,
        r.classify_source_hint, r.l1_code, r.l2_code, r.l3_code,
        TRUE AS clause_ok
    FROM gate_param p
    INNER JOIN rules_classify r
        ON r.data_source = p.data_source
       AND r.l1_code = p.gate_l1
       AND r.field_code = 'category2_like'
       AND p.category2 IS NOT NULL
       AND r.match_value IS NOT NULL
       AND p.category2 LIKE r.match_value

    UNION ALL

    SELECT
        p.id, p.data_source, r.rule_id, r.clause_group_id, r.clause_ord,
        r.l3_id, r.phase, r.rule_priority, r.confidence_weight,
        r.classify_source_hint, r.l1_code, r.l2_code, r.l3_code,
        TRUE AS clause_ok
    FROM gate_param p
    INNER JOIN rules_classify r
        ON r.data_source = p.data_source
       AND r.l1_code = p.gate_l1
       AND r.field_code = 'taginfo_overlap'
       AND p.taginfo IS NOT NULL
       AND array_length(p.taginfo) > 0
       AND r.match_values IS NOT NULL
       AND array_length(r.match_values) > 0
       AND arrays_overlap(p.taginfo, r.match_values)

    UNION ALL

    SELECT
        p.id, p.data_source, r.rule_id, r.clause_group_id, r.clause_ord,
        r.l3_id, r.phase, r.rule_priority, r.confidence_weight,
        r.classify_source_hint, r.l1_code, r.l2_code, r.l3_code,
        TRUE AS clause_ok
    FROM gate_param p
    INNER JOIN rules_classify r
        ON r.data_source = p.data_source
       AND r.l1_code = p.gate_l1
       AND r.field_code = 'category_info_overlap'
       AND p.category_info IS NOT NULL
       AND array_length(p.category_info) > 0
       AND r.match_values IS NOT NULL
       AND array_length(r.match_values) > 0
       AND arrays_overlap(p.category_info, r.match_values)

    UNION ALL

    SELECT
        p.id, p.data_source, r.rule_id, r.clause_group_id, r.clause_ord,
        r.l3_id, r.phase, r.rule_priority, r.confidence_weight,
        r.classify_source_hint, r.l1_code, r.l2_code, r.l3_code,
        TRUE AS clause_ok
    FROM gate_param p
    INNER JOIN rules_classify r
        ON r.data_source = p.data_source
       AND r.l1_code = p.gate_l1
       AND r.field_code = 'note_cn_regexp'
       AND p.note_cn IS NOT NULL
       AND r.match_value IS NOT NULL
       AND TRIM(r.match_value) <> ''
       AND p.note_cn REGEXP r.match_value

    UNION ALL

    SELECT
        p.id, p.data_source, r.rule_id, r.clause_group_id, r.clause_ord,
        r.l3_id, r.phase, r.rule_priority, r.confidence_weight,
        r.classify_source_hint, r.l1_code, r.l2_code, r.l3_code,
        TRUE AS clause_ok
    FROM gate_param p
    INNER JOIN rules_classify r
        ON r.data_source = p.data_source
       AND r.l1_code = p.gate_l1
       AND r.field_code = 'note_regexp'
       AND p.note IS NOT NULL
       AND r.match_value IS NOT NULL
       AND TRIM(r.match_value) <> ''
       AND p.note REGEXP r.match_value

    UNION ALL

    SELECT
        p.id, p.data_source, r.rule_id, r.clause_group_id, r.clause_ord,
        r.l3_id, r.phase, r.rule_priority, r.confidence_weight,
        r.classify_source_hint, r.l1_code, r.l2_code, r.l3_code,
        TRUE AS clause_ok
    FROM gate_param p
    INNER JOIN rules_classify r
        ON r.data_source = p.data_source
       AND r.l1_code = p.gate_l1
       AND r.field_code = 'partno_regexp'
       AND p.partno IS NOT NULL
       AND r.match_value IS NOT NULL
       AND TRIM(r.match_value) <> ''
       AND p.partno REGEXP r.match_value

    UNION ALL

    SELECT
        p.id, p.data_source, r.rule_id, r.clause_group_id, r.clause_ord,
        r.l3_id, r.phase, r.rule_priority, r.confidence_weight,
        r.classify_source_hint, r.l1_code, r.l2_code, r.l3_code,
        TRUE AS clause_ok
    FROM gate_param p
    INNER JOIN rules_classify r
        ON r.data_source = p.data_source
       AND r.l1_code = p.gate_l1
       AND r.field_code = 'parjson_match_map'
       AND p.prajson IS NOT NULL
       AND r.match_map IS NOT NULL
       AND cardinality(map_keys(r.match_map)) > 0
       AND array_sum(
            transform(
                map_keys(r.match_map),
                k -> IF(
                    LOWER(IFNULL(get_json_string(p.prajson, concat('$."', k, '"')), ''))
                        LIKE LOWER(TRIM(element_at(r.match_map, k))),
                    1,
                    0
                )
            )
        ) = cardinality(map_keys(r.match_map))

    UNION ALL

    SELECT
        p.id, p.data_source, r.rule_id, r.clause_group_id, r.clause_ord,
        r.l3_id, r.phase, r.rule_priority, r.confidence_weight,
        r.classify_source_hint, r.l1_code, r.l2_code, r.l3_code,
        TRUE AS clause_ok
    FROM gate_param p
    INNER JOIN rules_classify r
        ON r.data_source = p.data_source
       AND r.l1_code = p.gate_l1
       AND r.field_code = 'parjson2_match_map'
       AND p.prajson2 IS NOT NULL
       AND r.match_map IS NOT NULL
       AND cardinality(map_keys(r.match_map)) > 0
       AND array_sum(
            transform(
                map_keys(r.match_map),
                k -> IF(
                    LOWER(IFNULL(get_json_string(p.prajson2, concat('$."', k, '"')), ''))
                        LIKE LOWER(TRIM(element_at(r.match_map, k))),
                    1,
                    0
                )
            )
        ) = cardinality(map_keys(r.match_map))
),
/* 组内 AND：classify hint 按 clause_ord 聚合拼接（v1 双字句），不参与 GROUP BY 键；gate 无此步 */
classify_group_pass AS (
    SELECT
        e.id,
        e.data_source,
        e.rule_id,
        e.clause_group_id,
        e.l3_id,
        e.phase,
        e.rule_priority,
        e.confidence_weight,
        array_join(
            array_distinct(array_agg(e.classify_source_hint ORDER BY e.clause_ord)),
            '+'
        ) AS classify_source_hint,
        e.l1_code,
        e.l2_code,
        e.l3_code
    FROM classify_clause_eval e
    INNER JOIN rule_group_clause_cnt need
        ON need.rule_id = e.rule_id
       AND need.clause_group_id = e.clause_group_id
    GROUP BY
        e.id,
        e.data_source,
        e.rule_id,
        e.clause_group_id,
        e.l3_id,
        e.phase,
        e.rule_priority,
        e.confidence_weight,
        e.l1_code,
        e.l2_code,
        e.l3_code,
        need.clause_cnt
    HAVING COUNT(DISTINCT e.clause_ord) = need.clause_cnt
       AND SUM(CASE WHEN e.clause_ok THEN 1 ELSE 0 END) = need.clause_cnt
),
classify_rule_hit AS (
    SELECT DISTINCT
        id,
        data_source,
        rule_id,
        l3_id,
        phase,
        rule_priority,
        confidence_weight,
        classify_source_hint,
        l1_code,
        l2_code,
        l3_code
    FROM classify_group_pass
),
hits AS (
    SELECT
        h.id,
        h.data_source,
        h.l1_code,
        h.l2_code,
        h.l3_code,
        h.l3_id,
        h.rule_id,
        h.phase,
        h.rule_priority,
        SUBSTRING(COALESCE(h.classify_source_hint, 'rule_l3_sql_v1'), 1, 64) AS classify_source,
        concat(
            h.rule_id,
            '|category=', COALESCE(p.category, ''),
            '|category2=', COALESCE(p.category2, ''),
            '|pj_sample=', CASE
                WHEN p.prajson2 IS NOT NULL
                THEN substring(CAST(p.prajson2 AS VARCHAR), 1, 120)
                WHEN p.prajson IS NOT NULL
                THEN substring(CAST(p.prajson AS VARCHAR), 1, 120)
                ELSE ''
            END
        ) AS matched_value,
        LEAST(
            CAST(1.0000 AS DECIMAL(6,4)),
            CAST(
                (
                    CASE
                        WHEN h.phase >= 3 THEN 0.9200
                        WHEN h.phase >= 2 THEN 0.7800
                        ELSE 0.5500
                    END
                ) * h.confidence_weight AS DECIMAL(7,4)
            )
        ) AS confidence
    FROM classify_rule_hit h
    INNER JOIN param_all p
        ON p.id = h.id AND p.data_source = h.data_source
),
ranked AS (
    SELECT
        id,
        data_source,
        l1_code,
        l2_code,
        l3_code,
        l3_id,
        rule_id,
        phase,
        classify_source,
        rule_priority AS matched_priority,
        matched_value,
        confidence,
        ROW_NUMBER() OVER (
            PARTITION BY data_source, id
            ORDER BY phase DESC, rule_priority ASC, l3_code ASC
        ) AS rn
    FROM hits
),
best AS (
    SELECT *
    FROM ranked
    WHERE rn = 1
)
SELECT
    b.id,
    b.data_source,
    b.l1_code,
    b.l2_code,
    b.l3_code,
    b.l3_id,
    b.rule_id,
    b.phase,
    b.classify_source,
    b.matched_priority,
    b.matched_value,
    b.confidence,
    COALESCE(o.create_at, CURRENT_TIMESTAMP()) AS create_at,
    CURRENT_TIMESTAMP() AS update_at
FROM best b
LEFT JOIN test_dwd.dwd_component_class_circuit_protection o
    ON o.id = b.id AND o.data_source = b.data_source;
