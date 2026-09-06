/* diode 单位换算补充 → test_dim.dim_unit_factor（共享表）
 *
 * 注意：diode build SQL 统一改为 JOIN test_dim.dim_unit_factor（共享表），
 *       原 test_dim.dim_unit_factor_diode（per-L1 表）已废弃，dim_unit_factor_diode.sql
 *       DDL 不再由 run_diode_std_attr.sh 执行。
 *
 * 写前必查：SELECT * FROM test_dim.dim_unit_factor WHERE target_unit='<unit>' ORDER BY unit_raw;
 * 只写共享表中确实缺失的行，禁止重复写入已有条目。
 *
 * diode schema 用到的 target_unit 及共享表覆盖情况（2026-06-11 验证）：
 *   mW, MHz, ns, us, ps, dBm, nC, mJ, A²·s
 *   → 全部已在共享表中，seed 留空
 */
INSERT INTO test_dim.dim_unit_factor (target_unit, unit_raw, factor, note, create_at, update_at)
WITH seed(target_unit, unit_raw, factor, note) AS (
    SELECT NULL, NULL, NULL, NULL WHERE 1=0  /* 无新增条目；如需新增请先查共享表 */
)
SELECT s.target_unit, s.unit_raw, s.factor, s.note,
       COALESCE(old.create_at, CURRENT_TIMESTAMP()) AS create_at,
       CURRENT_TIMESTAMP() AS update_at
FROM seed s
LEFT JOIN test_dim.dim_unit_factor old
       ON old.target_unit = s.target_unit AND old.unit_raw = s.unit_raw;
