/* isolator 单位换算补充 → test_dim.dim_unit_factor（共享表）
 *
 * 验证：SELECT target_unit, unit_raw, factor FROM test_dim.dim_unit_factor WHERE target_unit IN ('V','℃','µs') ORDER BY target_unit, unit_raw;
 *
 * 初版新增（2026-06-11）：
 *   (V, Vrms/vrms, 1)  digikey 隔离电压
 *   (℃, °C, 1)        icpdf 温度
 *   (℃, ℃, 1)         全角摄氏度自身
 *
 * 迭代新增（2026-06-12）：
 *   (µs, µs, 1)        共享表仅有 target=us(ASCII)，µs(U+00B5)作 target 缺失
 *   (µs, us, 1)        ASCII us 小写
 *   (µs, ns, 0.001)    ns → µs 换算
 *   (µs, ms, 1000)     ms → µs 换算
 *   (µs, s, 1000000)   s → µs 换算
 *   — 用于 rise_time_max_us / fall_time_max_us，源数据单位 µs/ns
 */
INSERT INTO test_dim.dim_unit_factor (target_unit, unit_raw, factor, note, create_at, update_at)
WITH seed(target_unit, unit_raw, factor, note) AS (
    SELECT 'V',  'Vrms', CAST(1 AS DOUBLE), 'isolator: digikey 隔离电压 Vrms→V 等价'
    UNION ALL
    SELECT 'V',  'vrms', CAST(1 AS DOUBLE), 'isolator: vrms 小写变体'
    UNION ALL
    SELECT '℃', '°C',   CAST(1 AS DOUBLE), 'isolator: icpdf 温度 °C → ℃ 等价'
    UNION ALL
    SELECT '℃', '℃',   CAST(1 AS DOUBLE), 'isolator: ℃ 自身'
    UNION ALL
    SELECT 'µs', 'µs',  CAST(1 AS DOUBLE),       'isolator iter: µs(U+B5) target 自身'
    UNION ALL
    SELECT 'µs', 'us',  CAST(1 AS DOUBLE),       'isolator iter: ASCII us → µs'
    UNION ALL
    SELECT 'µs', 'ns',  CAST(0.001 AS DOUBLE),   'isolator iter: ns → µs'
    UNION ALL
    SELECT 'µs', 'ms',  CAST(1000 AS DOUBLE),    'isolator iter: ms → µs'
    UNION ALL
    SELECT 'µs', 's',   CAST(1000000 AS DOUBLE), 'isolator iter: s → µs'
)
SELECT s.target_unit, s.unit_raw, s.factor, s.note,
       COALESCE(old.create_at, CURRENT_TIMESTAMP()) AS create_at,
       CURRENT_TIMESTAMP() AS update_at
FROM seed s
LEFT JOIN test_dim.dim_unit_factor old
       ON old.target_unit = s.target_unit AND old.unit_raw = s.unit_raw
WHERE old.factor IS NULL;
