/* resistor ecloud 阻值单位字面量补充 → dim.dim_unit_factor（合并阶段 6 装载）
 * 根因：ecloud prajson 常用复数/简写（mOhms/kOhms/2.2k），prod dim 仅有单数形。
 * 验证：SELECT unit_raw, factor FROM dim.dim_unit_factor WHERE target_unit='Ω' AND unit_raw IN ('mOhms','kOhms');
 */
INSERT INTO dim.dim_unit_factor (target_unit, unit_raw, factor, note, create_at, update_at)
SELECT v.target_unit, v.unit_raw, v.factor, v.note, NOW(), NOW()
FROM (
    SELECT 'Ω' AS target_unit, 'mOhms' AS unit_raw, 0.001 AS factor, 'ecloud mOhms→Ω' AS note
    UNION ALL SELECT 'Ω', 'mohm', 0.001, 'ecloud mohm→Ω'
    UNION ALL SELECT 'Ω', 'mohms', 0.001, 'ecloud mohms→Ω'
    UNION ALL SELECT 'Ω', 'kOhm', 1000, 'ecloud kOhm→Ω'
    UNION ALL SELECT 'Ω', 'kOhms', 1000, 'ecloud kOhms→Ω'
    UNION ALL SELECT 'Ω', 'KOhm', 1000, 'ecloud KOhm→Ω'
    UNION ALL SELECT 'Ω', 'KOhms', 1000, 'ecloud KOhms→Ω'
    UNION ALL SELECT 'Ω', 'Ohms', 1, 'ecloud Ohms→Ω'
    UNION ALL SELECT 'Ω', 'MOhm', 1000000, 'ecloud MOhm→Ω'
    UNION ALL SELECT 'Ω', 'MOhms', 1000000, 'ecloud MOhms→Ω'
    UNION ALL SELECT 'Ω', 'Mohm', 1000000, 'ecloud Mohm→Ω'
    UNION ALL SELECT 'Ω', 'GOhm', 1000000000, 'ecloud GOhm→Ω'
    UNION ALL SELECT 'Ω', 'GOhms', 1000000000, 'ecloud GOhms→Ω'
    UNION ALL SELECT 'Ω', 'µOhms', 0.000001, 'ecloud µOhms→Ω'
    UNION ALL SELECT 'Ω', 'uOhms', 0.000001, 'ecloud uOhms→Ω'
    UNION ALL SELECT 'Ω', 'µOhm', 0.000001, 'ecloud µOhm→Ω'
    UNION ALL SELECT 'Ω', 'K', 1000, 'ecloud 简写 K→kΩ'
    UNION ALL SELECT 'Ω', 'k', 1000, 'ecloud 简写 k→kΩ'
) v
LEFT JOIN dim.dim_unit_factor old
       ON old.target_unit = v.target_unit AND old.unit_raw = v.unit_raw
WHERE old.unit_raw IS NULL;
