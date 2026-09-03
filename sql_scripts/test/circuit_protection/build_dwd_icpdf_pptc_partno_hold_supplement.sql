/* stage F · PPTC partno 编码 → hold_current_a（Littelfuse/Bourns 等 · 无 prajson cn 时）
 * 解码：数字段长度 n → value / 10^(n-1)  （050→0.5A · 1100→1.1A · 185→1.85A）
 */
DELETE FROM test_dwd.dwd_component_attr_std_circuit_protection
WHERE data_source = 'icpdf'
  AND std_attr_code = 'hold_current_a'
  AND extract_rule_id = 'cp_ic_pptc_partno_hold';

INSERT INTO test_dwd.dwd_component_attr_std_circuit_protection
(
    data_source, id, std_attr_code, l2_code, l3_id, l3_code,
    attr_schema_version, std_attr_cn, db_type, unit_std,
    value_raw, extract_rule_id, match_priority,
    clean_str, value_std_double, value_std_varchar, dq_flag,
    create_at, update_at
)
WITH cand AS (
    SELECT
        c.id,
        c.l2_code,
        c.l3_id,
        c.l3_code,
        p.partno,
        regexp_extract(p.partno, '(?i)(?:MF-R|RHEF|RUEF|RGEF|RLD\\d+P)0*(\\d{3,4})', 2) AS digits
    FROM test_dwd.dwd_component_class_circuit_protection c
    INNER JOIN dwd.dwd_icpdf_component_param p ON p.id = c.id
    WHERE c.data_source = 'icpdf'
      AND c.l3_code = 'pptc_resettable_fuse'
      AND p.partno REGEXP '(?i)(?:MF-R|RHEF|RUEF|RGEF|RLD\\d+P)0*\\d{3,4}'
      AND NOT EXISTS (
          SELECT 1
          FROM test_dwd.dwd_component_attr_std_circuit_protection e
          WHERE e.data_source = 'icpdf'
            AND e.id = c.id
            AND e.std_attr_code = 'hold_current_a'
            AND e.value_std_double IS NOT NULL
      )
),
decoded AS (
    SELECT
        id, l2_code, l3_id, l3_code, partno, digits,
        CAST(digits AS DOUBLE) / POW(10, LENGTH(digits) - 1) AS hold_a
    FROM cand
    WHERE digits IS NOT NULL AND TRIM(digits) <> ''
)
SELECT
    'icpdf',
    d.id,
    'hold_current_a',
    d.l2_code,
    d.l3_id,
    d.l3_code,
    'v1.16.01',
    '保持电流',
    'DOUBLE',
    'A',
    CAST(d.hold_a AS VARCHAR),
    'cp_ic_pptc_partno_hold',
    6,
    CAST(d.hold_a AS VARCHAR),
    d.hold_a,
    NULL,
    NULL,
    CURRENT_TIMESTAMP(),
    CURRENT_TIMESTAMP()
FROM decoded d
WHERE d.hold_a > 0 AND d.hold_a <= 20;
