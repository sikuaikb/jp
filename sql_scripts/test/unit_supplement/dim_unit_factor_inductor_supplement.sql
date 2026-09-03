/* inductor 单位换算补充 → test_dim.dim_unit_factor（共享表）
 *
 * 写前必查：SELECT * FROM test_dim.dim_unit_factor WHERE target_unit='<unit>' ORDER BY unit_raw;
 * 只写共享表中确实缺失的行，禁止重复写入已有条目。
 *
 * inductor schema 用到的 target_unit 及共享表覆盖情况（2026-06-11 验证）：
 *   uH, nH, mohm, mA, A, kHz, MHz, GHz, ohm, ppm/C → 全部已在共享表中
 *
 * 新增条目：
 *   ohm / kOhms / 1000  — DigiKey 阻抗值 kOhms 单位（如 ferrite_bead、common_mode_choke
 *                          impedance_at_100mhz_ohm / cm_impedance_ohm）；共享表原无此行，
 *                          2026-06-11 随 regex 修复一并补入
 */
INSERT INTO test_dim.dim_unit_factor (target_unit, unit_raw, factor, note, create_at, update_at)
WITH seed(target_unit, unit_raw, factor, note) AS (
    SELECT 'ohm', 'kOhms', 1000.0, 'inductor digikey: ferrite_bead/common_mode_choke impedance'
)
SELECT s.target_unit, s.unit_raw, s.factor, s.note,
       COALESCE(old.create_at, CURRENT_TIMESTAMP()) AS create_at,
       CURRENT_TIMESTAMP() AS update_at
FROM seed s
LEFT JOIN test_dim.dim_unit_factor old
       ON old.target_unit = s.target_unit AND old.unit_raw = s.unit_raw;
