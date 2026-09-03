/* fpga_cpld 单位换算补充 → test_dim.dim_unit_factor（共享表）
 *
 * 写前必查：SELECT * FROM test_dim.dim_unit_factor WHERE target_unit='<unit>' ORDER BY unit_raw;
 * 只写共享表中确实缺失的行，禁止重复写入已有条目。
 *
 * fpga_cpld schema 用到的 target_unit 及共享表覆盖情况（2026-06-12 验证）：
 *   V, MHz, ns, mA, mm, ℃, ms, us  → 全部已在共享表中
 *   Gbps                             → 不在共享表，但相关 L3 属性（SoC/SRAM serdes_max_rate_gbps）
 *                                       无源数据，暂不写规则；如后续 Phase 5 补充则再加条目
 *
 * 新增条目：
 *   K  / ''     / 0.001  — logic_cells_k：icpdf/digikey 源为原始 LUT 计数（如 75264），
 *                           转为千为单位（K）需 factor=0.001；源值无单位字符串故 unit_raw=''
 *   kbit / ''   / 0.001  — block_ram_kbit：digikey 总 RAM 位数为原始 bit 数（如 1069548），
 *                           转为 kbit 需 factor=0.001；源值无单位字符串故 unit_raw=''
 */
INSERT INTO test_dim.dim_unit_factor (target_unit, unit_raw, factor, note, create_at, update_at)
WITH seed(target_unit, unit_raw, factor, note) AS (
    SELECT 'K',    '',     0.001, 'fpga_cpld logic_cells_k: raw LUT count (no unit) → K units'
    UNION ALL
    SELECT 'kbit', '',     0.001, 'fpga_cpld block_ram_kbit: raw bit count (no unit) → kbit units'
    UNION ALL
    SELECT 'K',    'K',    1.0,   'fpga_cpld logic_cells_k: source already in K'
    UNION ALL
    SELECT 'kbit', 'kbit', 1.0,   'fpga_cpld block_ram_kbit: source already in kbit'
)
SELECT s.target_unit, s.unit_raw, s.factor, s.note,
       COALESCE(old.create_at, CURRENT_TIMESTAMP()) AS create_at,
       CURRENT_TIMESTAMP() AS update_at
FROM seed s
LEFT JOIN test_dim.dim_unit_factor old
       ON old.target_unit = s.target_unit AND old.unit_raw = s.unit_raw;
