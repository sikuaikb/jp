/* ============================================================
 * 校验：dwd_component_attr_std（fixed_resistor）覆盖率与 dq_flag
 *
 * 默认 data_source='icpdf'；如需校验 digikey，把 SET @DS='digikey' 改一下再跑。
 * 依赖：build_dwd_component_attr_std_icpdf.sql / _digikey.sql 已执行。
 *
 * 执行：mysql … -D dwd < sql_scripts/属性标准化/validate_resistor_attr_std.sql
 * ============================================================ */

SET @DS = 'icpdf';

WITH universe AS (
    SELECT COUNT(DISTINCT p.id) AS cnt
    FROM dwd.dwd_icpdf_component_param p
    INNER JOIN dwd.dwd_component_class c
            ON c.id = p.id AND c.data_source = @DS
    WHERE c.l1_code = 'resistor'
      AND c.l2_code = 'fixed_resistor'
      AND (p.prajson IS NOT NULL OR p.prajson2 IS NOT NULL)
),
filled AS (
    SELECT
        std_attr_code,
        COUNT(DISTINCT id) AS ids_with_value
    FROM dwd.dwd_component_attr_std
    WHERE data_source = @DS
      AND l2_code = 'fixed_resistor'
      AND value_raw IS NOT NULL
      AND value_raw <> ''
    GROUP BY std_attr_code
)
SELECT
    u.cnt                                   AS universe_fixed_resistor_param_ids,
    f.std_attr_code,
    f.ids_with_value,
    ROUND(f.ids_with_value * 100.0 / NULLIF(u.cnt, 0), 4) AS fill_pct
FROM filled f
CROSS JOIN universe u
ORDER BY f.ids_with_value DESC;


SELECT dq_flag, COUNT(*) AS row_cnt
FROM dwd.dwd_component_attr_std
WHERE data_source = @DS
  AND l2_code = 'fixed_resistor'
GROUP BY dq_flag
ORDER BY row_cnt DESC;


/* ---------- L3 专有属性填充（按 l3_code） ---------- */
SELECT
    c.l3_code,
    e.std_attr_code,
    COUNT(DISTINCT e.id) AS ids_with_value
FROM dwd.dwd_component_attr_std e
INNER JOIN dim.dim_attr_schema d
        ON d.schema_version = e.attr_schema_version
       AND d.l1_code = 'resistor'
       AND d.std_attr_code = e.std_attr_code
       AND d.scope_level = 'l3'
       AND d.scope_code = e.l3_code
INNER JOIN dwd.dwd_component_class c
        ON c.id = e.id AND c.data_source = e.data_source AND c.l3_code = e.l3_code
WHERE e.data_source = @DS
  AND e.l2_code = 'fixed_resistor'
  AND (
       e.value_std_double IS NOT NULL
    OR (e.value_std_varchar IS NOT NULL AND trim(e.value_std_varchar) <> '')
      )
GROUP BY c.l3_code, e.std_attr_code
ORDER BY c.l3_code, COUNT(DISTINCT e.id) DESC;
