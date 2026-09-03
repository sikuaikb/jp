/* ============================================================
 * dim_unit_factor_amplifier_supplement.sql
 * UPSERT 进共享表 test_dim.dim_unit_factor（无后缀，全 L1 共用，勿 DROP）。
 * 文件名带 _amplifier 仅表示「本 L1 新增的种子行」，写入的仍是共享表。
 *
 * ⚠️ 2026-07-01 修订：首版曾一次性列出全部理论上可能的希腊字母 μ/大小写/kV·mV·nV
 *   组合（53 条），事后核对 EAV 实际 unit_raw 命中发现仅 22 条被真实数据用到，
 *   其余 31 条（含 5 个 '' 默认行——验证对 scaled CTE 结果无影响，非必需）从未命中，
 *   属未经验证的推测性冗余，违反 PITFALLS.md「禁止 speculative 变体」原则。
 *   已 DELETE 共享表内这些未命中行，本文件同步只保留下方 22 条经 EAV 数据验证的条目。
 *   核查方法：对 amplifier icpdf EAV 全量数值行反推 unit_raw，与 dim_unit_factor 比对命中数。
 *
 * amplifier 涉及的 target_unit（schema unit_std）：
 *   已有（无需补）：MHz/℃/V/W/dB/dBm/mm/Ω/µA/mA/ns/ps/us/ppm/kHz/Hz
 *   本 L1 新增（共享表原无）：pA、nA、µV、V/µs、V/us（仅保留下方经验证有实际命中的 unit_raw）
 *
 * 源单位（已抽样验证 + EAV 命中数复核）：
 *   - 偏置电流：prajson2「最大平均偏置电流 (IIB)」为 µA/μA；prajson cn「输入偏置电流」为 pA/nA/μA
 *   - 失调电压：prajson2「最大输入失调电压」为 µV/μV；prajson cn「输入补偿电压」为 mV
 *   - 压摆率：prajson2「标称压摆率」为 V/us；prajson cn「转换速率」为 V/μs/mV/μs/kV/μs/nV/μs/µV/μs
 *   注：源数据 μ(U+03BC 希腊 mu) 与 schema µ(U+00B5 micro sign) 不同字符，两种字符实际都出现在源数据中。
 *
 * 幂等：NOT EXISTS 守卫，重跑不冲突（共享表已有同 (target_unit,unit_raw) 则跳过）。
 * ============================================================ */

INSERT INTO test_dim.dim_unit_factor (target_unit, unit_raw, factor, note, create_at, update_at)
WITH seed(target_unit, unit_raw, factor, note) AS (
    /* ---- pA（input_bias_current_max_pa）---- */
    SELECT 'pA', 'pA', 1.0,       NULL UNION ALL
    SELECT 'pA', 'nA', 1000.0,    NULL UNION ALL
    SELECT 'pA', 'µA', 1000000.0, NULL UNION ALL
    SELECT 'pA', 'μA', 1000000.0, NULL
    UNION ALL
    /* ---- nA（input_bias_current_na）---- */
    SELECT 'nA', 'nA', 1.0,       NULL UNION ALL
    SELECT 'nA', 'pA', 0.001,     NULL UNION ALL
    SELECT 'nA', 'µA', 1000.0,    NULL UNION ALL
    SELECT 'nA', 'μA', 1000.0,    NULL
    UNION ALL
    /* ---- µV（input_offset_voltage_uv）---- */
    SELECT 'µV', 'µV', 1.0,    NULL UNION ALL
    SELECT 'µV', 'mV', 1000.0, NULL UNION ALL
    SELECT 'µV', 'μV', 1.0,    NULL
    UNION ALL
    /* ---- V/µs（op_amp/buffer slew_rate_v_us；prajson2「标称压摆率」主用 ASCII V/us 拼写）---- */
    SELECT 'V/µs', 'V/us',  1.0,       NULL UNION ALL
    SELECT 'V/µs', 'V/μs',  1.0,       NULL UNION ALL
    SELECT 'V/µs', 'mV/μs', 0.001,     NULL UNION ALL
    SELECT 'V/µs', 'kV/μs', 1000.0,    NULL UNION ALL
    SELECT 'V/µs', 'nV/μs', 0.000000001, NULL UNION ALL
    SELECT 'V/µs', 'µV/μs', 0.000001,  NULL
    UNION ALL
    /* ---- V/us（class_ab_audio_amp slew_rate_v_us；此 L3 范围内源数据均用希腊 μs 拼写）---- */
    SELECT 'V/us', 'V/μs',  1.0,    NULL UNION ALL
    SELECT 'V/us', 'mV/μs', 0.001,  NULL UNION ALL
    SELECT 'V/us', 'kV/μs', 1000.0, NULL
    UNION ALL
    /* ---- mm 补 in（英寸；icpdf pkg 尺寸部分行为 in）---- */
    SELECT 'mm', 'in', 25.4, NULL
    UNION ALL
    /* ---- V 补 VDC（大小写变体）---- */
    SELECT 'V', 'VDC', 1.0, NULL
)
SELECT s.target_unit, s.unit_raw, s.factor, s.note,
       CURRENT_TIMESTAMP() AS create_at,
       CURRENT_TIMESTAMP() AS update_at
FROM seed s
WHERE NOT EXISTS (
    SELECT 1 FROM test_dim.dim_unit_factor o
    WHERE o.target_unit = s.target_unit AND o.unit_raw = s.unit_raw
);
