/* circuit_protection 单位换算补充 → test_dim.dim_unit_factor（共享表）
 * rated_short_circuit_capacity_ka：ICPDF 额定分断能力 源端为 A，schema 目标 kA
 */
INSERT INTO test_dim.dim_unit_factor (target_unit, unit_raw, factor, note, create_at, update_at)
WITH seed(target_unit, unit_raw, factor, note) AS (
    SELECT 'kA', '', 1, 'kA 默认同单位'
    UNION ALL SELECT 'kA', 'A', 0.001, 'A → kA（÷1000）'
    UNION ALL SELECT 'kA', 'a', 0.001, 'a → kA'
    UNION ALL SELECT 'kA', 'kA', 1, 'kA 直通'
    UNION ALL SELECT 'kA', 'KA', 1, 'KA 直通'
    UNION ALL SELECT 'A', '', 1, 'A 默认同单位'
    UNION ALL SELECT 'A', 'A', 1, 'A 直通'
    UNION ALL SELECT 'A', 'a', 1, 'a 直通'
    UNION ALL SELECT 'A', 'mA', 0.001, 'mA → A（÷1000）'
    UNION ALL SELECT 'A', 'ma', 0.001, 'ma → A'
    UNION ALL SELECT 'Ω', 'Ω', 1, 'Ω 直通'
    UNION ALL SELECT 'Ω', 'Ohm', 1, 'Ohm 直通'
    UNION ALL SELECT 'Ω', 'ohm', 1, 'ohm 直通'
    UNION ALL SELECT 'Ω', 'mΩ', 0.001, 'mΩ → Ω'
    UNION ALL SELECT 'Ω', 'mOhm', 0.001, 'mOhm → Ω'
)
SELECT s.target_unit, s.unit_raw, s.factor, s.note,
       COALESCE(old.create_at, CURRENT_TIMESTAMP()) AS create_at,
       CURRENT_TIMESTAMP() AS update_at
FROM seed s
LEFT JOIN test_dim.dim_unit_factor old
       ON old.target_unit = s.target_unit AND old.unit_raw = s.unit_raw;
