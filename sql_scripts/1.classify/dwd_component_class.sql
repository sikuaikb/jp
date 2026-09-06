/* ============================================================
 * DWD：L3 分类（多源单脚本；正式）—— icpdf + digikey + ecloud 合并，纯维表驱动
 *
 * 一条 INSERT 同时跑所有数据源、所有 L1：
 *   - 新增数据源：在 param_all 加一段 UNION ALL（映射该源 param 表的统一列），
 *     并在 dim_l3_classify_rule 用对应 data_source 加 gate/classify 规则。
 *   - 新增 L1/L3：只加 dim 行（gate_<l1>_<source>_v1 + classify），SQL 不改。
 *
 * 性能（替代旧 `INNER JOIN rules_classify ON TRUE` 笛卡尔积，规避 OOM）：
 *   - gate 用 array_contains 的 OR 连接产出 (id, data_source, gate_l1)，避开 unnest+UNION 优化器 bug
 *   - classify 谓词按 field_code UNION ALL，按 (data_source, l1_code) 分区连接，无 ON TRUE
 *
 * 语义要点：
 *   - Gate 严格「每 L1 走自己的 gate」（gate_<l1> 的 category/category2 白名单），
 *     L1 从 gate 规则 rule_id 第 2 段推出；无 v1「无 gate→放行全表」全局回退。
 *   - 组内 AND（clause_group）、组间 OR、phase/priority/l3_code 决选，与历史一致。
 *   - JSON 列由 field_code 显式声明：parjson_match_map→prajson、parjson2_match_map→prajson2
 *     （icpdf 用 prajson2，digikey/ecloud 用 prajson；详见 RULE_ENGINE.md §5）。
 *   - note_regexp / partno_regexp 已启用。
 *   - 决选 PARTITION BY (data_source, id)：跨源 id 可能重叠。
 *
 * 执行：bash sql_scripts/1.classify/run_classify.sh prod   （或 prod_classify.yaml 调度）
 *   先 load_seed（迁移后的 seed，含 parjson2_match_map）再跑本脚本——两者必须同批上线。
 *
 * 策略：DELETE WHERE data_source IN ('icpdf','digikey','ecloud') 后全量 INSERT；只写命中行；create_at 沿用历史。
 * 升级：若存量表缺列（l3_id/rule_id/phase/confidence/matched_value≥512），先 ALTER 或 DROP 再建。
 *
 * 产出：dwd.dwd_component_class（PK data_source,id；icpdf + digikey + ecloud 同表）
 * 依赖：dim.dim_l3_classify、dim.dim_l3_classify_rule、
 *       dwd.dwd_icpdf_component_param、dwd.dwd_digikey_component_param、
 *       dwd.dwd_ecloud_component_param
 * 规则引擎说明：sql_scripts/1.classify/RULE_ENGINE.md
 * ============================================================ */

CREATE TABLE IF NOT EXISTS dwd.dwd_component_class (
    `data_source`       VARCHAR(32)   NOT NULL DEFAULT 'icpdf',
    `id`                BIGINT        NOT NULL,
    `l1_code`           VARCHAR(32)   NULL,
    `l2_code`           VARCHAR(64)   NULL,
    `l3_code`           VARCHAR(64)   NULL,
    `l3_id`             VARCHAR(6)    NULL,
    `rule_id`           VARCHAR(64)   NULL,
    `phase`             TINYINT       NULL,
    `classify_source`   VARCHAR(64)   NULL COMMENT '双字句 hint 拼接（如 digikey_category+parjson_match_map）',
    `matched_priority`  INT           NULL,
    `matched_value`     VARCHAR(512)  NULL,
    `confidence`        DECIMAL(5,4)  NULL,
    `create_at`         DATETIME      NULL DEFAULT CURRENT_TIMESTAMP,
    `update_at`         DATETIME      åNULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=OLAP
PRIMARY KEY(`data_source`, `id`)
COMMENT 'L3 分类（多源单脚本：icpdf + digikey + ecloud）'
DISTRIBUTED BY HASH(`id`) BUCKETS 16
PROPERTIES ("replication_num" = "1", "enable_persistent_index" = "true");

DELETE FROM dwd.dwd_component_class WHERE data_source IN ('icpdf', 'digikey', 'ecloud');

INSERT INTO dwd.dwd_component_class
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
    UNION ALL
    SELECT
        id, CAST('digikey' AS VARCHAR(32)) AS data_source,
        category, category2, taginfo, category_info,
        note, note_cn, partno,
        prajson, prajson2
    FROM dwd.dwd_digikey_component_param
    UNION ALL
    SELECT
        id, CAST('ecloud' AS VARCHAR(32)) AS data_source,
        category, category2, taginfo, category_info,
        note, note_cn, partno,
        prajson, prajson2
    FROM dwd.dwd_ecloud_component_param
),
rules_gate AS (
    /* gate_<l1>_<source>_vN；l1 可含下划线（如 mcu_mpu_dsp / data_converter） */
    SELECT
        data_source,
        CASE
            WHEN rule_id REGEXP '^gate_.+_digikey_' THEN regexp_extract(rule_id, '^gate_(.+)_digikey_', 1)
            WHEN rule_id REGEXP '^gate_.+_icpdf_'  THEN regexp_extract(rule_id, '^gate_(.+)_icpdf_', 1)
            WHEN rule_id REGEXP '^gate_.+_ecloud_' THEN regexp_extract(rule_id, '^gate_(.+)_ecloud_', 1)
            ELSE split_part(rule_id, '_', 2)
        END AS l1_code,
        field_code,
        match_value,
        match_values
    FROM dim.dim_l3_classify_rule
    WHERE enabled = 1
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
         OR (gr.field_code = 'gate_exclude_category2_in'
             AND gr.match_values IS NOT NULL
             AND array_contains(gr.match_values, p.category2))
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
    FROM dim.dim_l3_classify_rule r
    INNER JOIN dim.dim_l3_classify d
        ON d.l3_id = r.l3_id
       AND d.schema_version = r.schema_version
    WHERE r.enabled = 1
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
LEFT JOIN dwd.dwd_component_class o
    ON o.id = b.id AND o.data_source = b.data_source;
