/* system_module 单位换算补充 → test_dim.dim_unit_factor（共享表，UPSERT，勿 DROP）
 *
 * 写前已查共享表（2026-06-18 验证）：
 *   V(kV→1000, mV→0.001, V→1, ''→1)、A(mA→0.001, µA→1e-6, A→1)、W(mW→0.001)、
 *   MHz(GHz→1000, kHz→0.001)、kHz、dBm、%、℃(°C/C→1)、Hz、Vrms、mV、KB、mm 等 → 全部已在共享表
 *   仅 target_unit='MB' 缺失（compute sys_ram_mb：源 RAM 容量为 '1GB'/'512MB'）
 *
 * 新增条目：
 *   MB / GB / 1024  — sys_ram_mb：源 '1GB' → 1024 MB
 *   MB / MB / 1     — sys_ram_mb：源 '512MB' 已是 MB
 *   MB / ''  / 1    — 无单位回退按 MB 处理（identity，不放大）
 */
INSERT INTO test_dim.dim_unit_factor (target_unit, unit_raw, factor, note, create_at, update_at)
WITH seed(target_unit, unit_raw, factor, note) AS (
    SELECT 'MB', 'GB', 1024.0, 'system_module sys_ram_mb: GB → MB'
    UNION ALL SELECT 'MB', 'MB', 1.0, 'system_module sys_ram_mb: source already MB'
    UNION ALL SELECT 'MB', '',  1.0, 'system_module sys_ram_mb: no-unit fallback → MB'
)
SELECT s.target_unit, s.unit_raw, s.factor, s.note,
       COALESCE(old.create_at, CURRENT_TIMESTAMP()) AS create_at,
       CURRENT_TIMESTAMP() AS update_at
FROM seed s
LEFT JOIN test_dim.dim_unit_factor old
       ON old.target_unit = s.target_unit AND old.unit_raw = s.unit_raw;
