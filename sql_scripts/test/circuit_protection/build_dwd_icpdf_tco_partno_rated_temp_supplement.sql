/* stage E · EYP partno 编码 → rated_function_temp_c（ICPDF extract 引擎不支持 partno） */
DELETE FROM test_dwd.dwd_component_attr_std_circuit_protection
WHERE data_source = 'icpdf'
  AND std_attr_code = 'rated_function_temp_c'
  AND extract_rule_id = 'cp_ic_tco_partno_eyp';

INSERT INTO test_dwd.dwd_component_attr_std_circuit_protection
(
    data_source, id, std_attr_code, l2_code, l3_id, l3_code,
    attr_schema_version, std_attr_cn, db_type, unit_std,
    value_raw, extract_rule_id, match_priority,
    clean_str, value_std_double, value_std_varchar, dq_flag,
    create_at, update_at
)
WITH eyp_temp AS (
    SELECT
        c.id,
        c.l2_code,
        c.l3_id,
        c.l3_code,
        CAST(regexp_extract(p.partno, '(?i)^EYP[A-Z0-9]*[A-Z]{2}(\\d{3})', 1) AS DOUBLE) AS temp_c
    FROM test_dwd.dwd_component_class_circuit_protection c
    INNER JOIN dwd.dwd_icpdf_component_param p ON p.id = c.id
    WHERE c.data_source = 'icpdf'
      AND c.l3_code = 'thermal_cutoff'
      AND p.partno REGEXP '(?i)^EYP'
)
SELECT
    'icpdf' AS data_source,
    e.id,
    'rated_function_temp_c' AS std_attr_code,
    e.l2_code,
    e.l3_id,
    e.l3_code,
    'v1.16.01' AS attr_schema_version,
    '额定动作温度' AS std_attr_cn,
    'DOUBLE' AS db_type,
    '℃' AS unit_std,
    CAST(e.temp_c AS VARCHAR) AS value_raw,
    'cp_ic_tco_partno_eyp' AS extract_rule_id,
    5 AS match_priority,
    CAST(e.temp_c AS VARCHAR) AS clean_str,
    e.temp_c AS value_std_double,
    NULL AS value_std_varchar,
    NULL AS dq_flag,
    CURRENT_TIMESTAMP() AS create_at,
    CURRENT_TIMESTAMP() AS update_at
FROM eyp_temp e
WHERE e.temp_c BETWEEN 60 AND 300
  AND NOT EXISTS (
      SELECT 1
      FROM test_dwd.dwd_component_attr_std_circuit_protection x
      WHERE x.data_source = 'icpdf'
        AND x.id = e.id
        AND x.std_attr_code = 'rated_function_temp_c'
  );
