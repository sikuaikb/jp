/* dim_unit_factor_acoustic_device_supplement.sql
 * 补充 acoustic_device schema 所需但 dim_unit_factor 共享表缺失的 (target_unit, unit_raw) 条目。
 * 写入共享表 test_dim.dim_unit_factor（UPSERT，勿 DROP）。
 *
 * 与生产库 dim.dim_unit_factor 对比（2026-07-09）：
 *   - 生产已有 target_unit=℃（含 ''/C/°C/℃），无 target_unit=°C
 *   - 生产已有 uA/µA/mV（含 mV←V factor=1000），无 target_unit=μA / nF
 *   - 生产无 dB SPL / dBV/Pa / T·m / V←VAC
 *
 * 本 L1 icpdf 已启用数值规则实际用到的 unit_std：Hz/V/W/mm/nF/°C/μA
 * （Hz/V/W/mm 生产与共享表已覆盖，不补）
 *
 * 仅补当前换算路径必需且生产缺失的条目：
 *   - °C：schema unit_std=°C；prajson 值用 ℃ → ''/℃/°C
 *   - nF：schema unit_std=nF；值有 nF/pF → ''/nF/pF(0.001)
 *   - μA：schema unit_std=μA（希腊 mu）；值用 µA → ''/μA/µA
 *
 * 已删（多补 / 生产已有 / 当前规则未用）：
 *   degC/C、µF/uF、uA/mA/A、dB SPL、dBV/Pa、T·m、mV、V←VAC
 *   （其中 mV←V=0.001 曾写反，正确应为 1000，且生产已有）
 */

INSERT INTO test_dim.dim_unit_factor (target_unit, unit_raw, factor, create_at, update_at)
SELECT * FROM (
    /* °C — 温度（schema=°C；生产仅有 target=℃） */
    SELECT '°C' AS target_unit, '' AS unit_raw, 1.0 AS factor, CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
    UNION ALL SELECT '°C', '℃', 1.0, CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
    UNION ALL SELECT '°C', '°C', 1.0, CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
    /* nF — 电容（生产无 target=nF；有 pF→nF 换算） */
    UNION ALL SELECT 'nF', '', 1.0, CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
    UNION ALL SELECT 'nF', 'nF', 1.0, CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
    UNION ALL SELECT 'nF', 'pF', 0.001, CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
    /* μA — 工作电流（schema=μA 希腊 mu；生产仅有 uA/µA） */
    UNION ALL SELECT 'μA', '', 1.0, CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
    UNION ALL SELECT 'μA', 'μA', 1.0, CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
    UNION ALL SELECT 'μA', 'µA', 1.0, CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
) t
WHERE NOT EXISTS (
    SELECT 1 FROM test_dim.dim_unit_factor f
    WHERE f.target_unit = t.target_unit AND f.unit_raw = t.unit_raw
);
