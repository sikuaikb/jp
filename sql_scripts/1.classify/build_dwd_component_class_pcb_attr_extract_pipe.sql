/* ============================================================
 * PDF 抽取源 → dwd.dwd_component_class（taxonomy 路径短路）
 *
 * 数据源：dwd.dwd_pdf_extract_component_param（data_source='pcb_attr_extract_pipe'）
 *
 * 与 icpdf/digikey 规则引擎的差异：
 *   - 抽取管线已输出 [L1,L2,L3] 路径（category_info），字段名对齐宽表 schema
 *   - 仅做 pipe → prod taxonomy 映射后 JOIN dim.dim_l3_classify，不走 gate/classify 规则
 *
 * 映射（pipe 编码 → prod l1_code / l2_code）：
 *   - L1: mcu / mpu / dsp → mcu_mpu_dsp（prod 维表把三者合并为一个 L1）；其余与 pipe L1 相同（如 resistor）
 *   - L2: 去掉 _base 后缀（mpu_soc_base → mpu_soc）
 *   - L3: category_info[3] 与 dim.l3_code 精确匹配
 *
 * 执行：mysql … < sql_scripts/1.classify/build_dwd_component_class_pcb_attr_extract_pipe.sql
 * 依赖：dim.dim_l3_classify；须先于 build_dwd_component_attr_std_pcb_attr_extract_pipe.sql
 * ============================================================ */

DELETE FROM dwd.dwd_component_class WHERE data_source = 'pcb_attr_extract_pipe';

INSERT INTO dwd.dwd_component_class
(
    id, data_source,
    l1_code, l2_code, l3_code, l3_id,
    rule_id, phase, classify_source, matched_priority, matched_value, confidence,
    create_at, update_at
)
SELECT
    p.id,
    'pcb_attr_extract_pipe'                                               AS data_source,
    d.l1_code,
    d.l2_code,
    d.l3_code,
    d.l3_id,
    'pdf_pipe_category_path_v1'                                           AS rule_id,
    CAST(1 AS TINYINT)                                                    AS phase,
    'category_info_path'                                                  AS classify_source,
    CAST(1 AS INT)                                                        AS matched_priority,
    concat(
        coalesce(p.category_info[1], ''), '/',
        coalesce(p.category_info[2], ''), '/',
        coalesce(p.category_info[3], '')
    )                                                                     AS matched_value,
    CAST(0.95 AS DECIMAL(5,4))                                            AS confidence,
    CURRENT_TIMESTAMP()                                                 AS create_at,
    CURRENT_TIMESTAMP()                                                 AS update_at
FROM dwd.dwd_pdf_extract_component_param p
INNER JOIN dim.dim_l3_classify d
        ON d.l3_code = p.category_info[3]
       AND d.l2_code = REPLACE(p.category_info[2], '_base', '')
       AND d.l1_code = CASE p.category_info[1]
             WHEN 'mpu' THEN 'mcu_mpu_dsp'
             WHEN 'mcu' THEN 'mcu_mpu_dsp'
             WHEN 'dsp' THEN 'mcu_mpu_dsp'
             ELSE p.category_info[1]
           END
WHERE p.category_info IS NOT NULL
  AND array_length(p.category_info) >= 3
  AND p.category_info[3] IS NOT NULL
  AND TRIM(p.category_info[3]) <> '';

/* ---------- 验收 ---------- */
SELECT 'classified' AS what, COUNT(*) AS n
FROM dwd.dwd_component_class
WHERE data_source = 'pcb_attr_extract_pipe';

SELECT 'unmapped' AS what, COUNT(*) AS n
FROM dwd.dwd_pdf_extract_component_param p
LEFT JOIN dwd.dwd_component_class c
       ON c.id = p.id AND c.data_source = 'pcb_attr_extract_pipe'
WHERE c.id IS NULL;

SELECT l1_code, l2_code, l3_code, COUNT(*) AS cnt
FROM dwd.dwd_component_class
WHERE data_source = 'pcb_attr_extract_pipe'
GROUP BY l1_code, l2_code, l3_code
ORDER BY cnt DESC;
