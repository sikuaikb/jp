/* ============================================================
 * dim_unit_factor_filter_supplement.sql
 * UPSERT 进共享表 test_dim.dim_unit_factor（无后缀，全 L1 共用，勿 DROP）。
 * 文件名带 _filter 仅表示「本 L1 新增的种子行」，写入的仍是共享表。
 *
 * filter 涉及的 target_unit（schema unit_std）：
 *   已有（无需补，写规则前逐一核对过 test_dim.dim_unit_factor）：
 *     ℃ / mm / dB / MHz / Ω / mA / mH / pF / V / A / % / dBm / ppm/℃ / mΩ / W
 *   本 L1 唯一新增：Ω 的大写变体 'OHM'（icpdf prajson2「输入/输出阻抗」字面为
 *     "330 OHM"/"350 OHM//2.7 pF" 等全大写拼写，StarRocks 字符串比较区分大小写，
 *     已有 'Ohm'/'Ohms' 条目不覆盖 'OHM'；数值上 OHM=Ω factor 应为 1，
 *     但仍需显式条目以通过 EXTRACT_RULE_QA.md §J2 覆盖缺口检查，避免每次审计误报）。
 *   电容量 µF（U+00B5 micro sign）已与共享表 hex 校验完全一致（C2B546），无需补充。
 *
 * 幂等：NOT EXISTS 守卫，重跑不冲突。
 * ============================================================ */

INSERT INTO test_dim.dim_unit_factor (target_unit, unit_raw, factor, note, create_at, update_at)
WITH seed(target_unit, unit_raw, factor, note) AS (
    SELECT 'Ω', 'OHM', 1.0, 'icpdf 输入/输出阻抗字面全大写拼写'
)
SELECT s.target_unit, s.unit_raw, s.factor, s.note,
       CURRENT_TIMESTAMP() AS create_at,
       CURRENT_TIMESTAMP() AS update_at
FROM seed s
WHERE NOT EXISTS (
    SELECT 1 FROM test_dim.dim_unit_factor o
    WHERE o.target_unit = s.target_unit AND o.unit_raw = s.unit_raw
);
