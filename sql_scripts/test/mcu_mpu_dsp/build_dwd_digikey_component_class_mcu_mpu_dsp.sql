/* ============================================================
 * 沙盒：DigiKey MCU/MPU/DSP 分类（阶段 2 初版）
 *
 * 读：dwd.dwd_digikey_component_param（prod 只读）
 * 规则：test_dim.dim_l3_classify_rule_mcu_mpu_dsp + dim_l3_classify_mcu_mpu_dsp
 * 写：test_dwd.dwd_component_class_mcu_mpu_dsp
 *
 * v1 接受现状：gate 仅 category 白名单，不含「未分类」叶子（~44 行 PIC 裸片不入 gate）
 * ============================================================ */

CREATE TABLE IF NOT EXISTS test_dwd.dwd_component_class_mcu_mpu_dsp (
    `data_source`       VARCHAR(32)   NOT NULL DEFAULT 'digikey',
    `id`                BIGINT        NOT NULL,
    `l1_code`           VARCHAR(32)   NULL,
    `l2_code`           VARCHAR(32)   NULL,
    `l3_code`           VARCHAR(64)   NULL,
    `l3_id`             VARCHAR(6)    NULL,
    `rule_id`           VARCHAR(64)   NULL,
    `phase`             TINYINT       NULL,
    `classify_source`   VARCHAR(64)   NULL,
    `matched_priority`  INT           NULL,
    `matched_value`     VARCHAR(512)  NULL,
    `confidence`        DECIMAL(5,4)  NULL,
    `create_at`         DATETIME      NULL DEFAULT CURRENT_TIMESTAMP,
    `update_at`         DATETIME      NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=OLAP
PRIMARY KEY(`data_source`, `id`)
COMMENT '沙盒：DigiKey MCU/MPU/DSP L3 分类'
DISTRIBUTED BY HASH(`id`) BUCKETS 16
PROPERTIES ("replication_num" = "1", "enable_persistent_index" = "true");

DELETE FROM test_dwd.dwd_component_class_mcu_mpu_dsp WHERE data_source = 'digikey';

INSERT INTO test_dwd.dwd_component_class_mcu_mpu_dsp
(
    id, data_source,
    l1_code, l2_code, l3_code, l3_id,
    rule_id, phase, classify_source, matched_priority, matched_value, confidence,
    create_at, update_at
)
WITH
rules_gate AS (
    SELECT *
    FROM test_dim.dim_l3_classify_rule_mcu_mpu_dsp
    WHERE enabled = 1
      AND data_source = 'digikey'
      AND rule_kind = 'gate'
),
gate_rule_components AS (
    SELECT p.*
    FROM dwd.dwd_digikey_component_param p
    WHERE NOT EXISTS (SELECT 1 FROM rules_gate)
       OR p.category IN (
              SELECT mv
              FROM rules_gate r,
                   unnest(r.match_values) AS u(mv)
              WHERE r.field_code = 'category_in'
          )
       OR p.category2 IN (
              SELECT mv
              FROM rules_gate r,
                   unnest(r.match_values) AS u(mv)
              WHERE r.field_code = 'category2_in'
          )
       /* 专用 IC 是得捷杂项大类：仅 note/prajson 明示 MCU/DSP 时入 gate，避免验证芯片等拉高未分类分母 */
       OR (
           p.category = '专用 IC'
           AND (
               (
                   p.note_cn IS NOT NULL
                   AND p.note_cn REGEXP '(微控制器|Microcontroller|视频处理器，微控制器|^DSP |数字信号处理器|Audio DSP)'
               )
               OR get_json_string(p.prajson, '$.类型') IN (
                   '微控制器', 'DSP', '视频处理器，微控制器'
               )
           )
       )
),
rules_classify AS (
    SELECT
        r.*,
        d.l1_code,
        d.l2_code,
        d.l3_code
    FROM test_dim.dim_l3_classify_rule_mcu_mpu_dsp r
    INNER JOIN test_dim.dim_l3_classify_mcu_mpu_dsp d
        ON d.l3_id = r.l3_id
       AND d.schema_version = r.schema_version
    WHERE r.enabled = 1
      AND r.data_source = 'digikey'
      AND r.rule_kind = 'classify'
),
classify_clause_eval AS (
    SELECT
        p.id,
        r.rule_id,
        r.clause_group_id,
        r.clause_ord,
        r.l3_id,
        r.phase,
        r.rule_priority,
        r.confidence_weight,
        r.classify_source_hint,
        r.l1_code,
        r.l2_code,
        r.l3_code,
        CASE r.field_code
            WHEN 'category_eq'
            THEN (p.category IS NOT NULL AND r.match_value IS NOT NULL AND p.category = r.match_value)
            WHEN 'category2_eq'
            THEN (p.category2 IS NOT NULL AND r.match_value IS NOT NULL AND p.category2 = r.match_value)
            WHEN 'category_in'
            THEN (
                p.category IS NOT NULL
                AND r.match_values IS NOT NULL
                AND array_contains(r.match_values, p.category)
            )
            WHEN 'category2_in'
            THEN (
                p.category2 IS NOT NULL
                AND r.match_values IS NOT NULL
                AND array_contains(r.match_values, p.category2)
            )
            WHEN 'category_like'
            THEN (p.category IS NOT NULL AND r.match_value IS NOT NULL AND p.category LIKE r.match_value)
            WHEN 'category2_like'
            THEN (p.category2 IS NOT NULL AND r.match_value IS NOT NULL AND p.category2 LIKE r.match_value)
            WHEN 'taginfo_overlap'
            THEN (
                p.taginfo IS NOT NULL
                AND array_length(p.taginfo) > 0
                AND r.match_values IS NOT NULL
                AND array_length(r.match_values) > 0
                AND arrays_overlap(p.taginfo, r.match_values)
            )
            WHEN 'category_info_overlap'
            THEN (
                p.category_info IS NOT NULL
                AND array_length(p.category_info) > 0
                AND r.match_values IS NOT NULL
                AND array_length(r.match_values) > 0
                AND arrays_overlap(p.category_info, r.match_values)
            )
            WHEN 'note_cn_regexp'
            THEN (
                p.note_cn IS NOT NULL
                AND r.match_value IS NOT NULL
                AND TRIM(r.match_value) <> ''
                AND p.note_cn REGEXP r.match_value
            )
            WHEN 'parjson_match_map'
            THEN (
                p.prajson IS NOT NULL
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
            )
            ELSE FALSE
        END AS clause_ok
    FROM gate_rule_components p
    INNER JOIN rules_classify r ON TRUE
),
classify_group_pass AS (
    SELECT
        id,
        rule_id,
        clause_group_id,
        l3_id,
        phase,
        rule_priority,
        confidence_weight,
        array_join(
            array_distinct(array_agg(classify_source_hint ORDER BY clause_ord)),
            '+'
        ) AS classify_source_hint,
        l1_code,
        l2_code,
        l3_code
    FROM classify_clause_eval
    GROUP BY
        id,
        rule_id,
        clause_group_id,
        l3_id,
        phase,
        rule_priority,
        confidence_weight,
        l1_code,
        l2_code,
        l3_code
    HAVING SUM(CASE WHEN clause_ok THEN 1 ELSE 0 END) = COUNT(*)
),
classify_rule_hit AS (
    SELECT DISTINCT
        id,
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
        h.l1_code,
        h.l2_code,
        h.l3_code,
        h.l3_id,
        h.rule_id,
        h.phase,
        h.rule_priority,
        COALESCE(h.classify_source_hint, 'rule_l3_sql_v1') AS classify_source,
        concat(
            h.rule_id,
            '|category=', COALESCE(p.category, ''),
            '|category2=', COALESCE(p.category2, ''),
            '|p_sample=', CASE
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
    INNER JOIN gate_rule_components p ON p.id = h.id
),
ranked AS (
    SELECT
        id,
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
            PARTITION BY id
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
    p.id,
    'digikey'                                     AS data_source,
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
FROM gate_rule_components p
INNER JOIN best b ON b.id = p.id
LEFT JOIN test_dwd.dwd_component_class_mcu_mpu_dsp o
    ON o.id = p.id AND o.data_source = 'digikey';
