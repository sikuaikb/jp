/* ============================================================
 * 回填 dwd.dwd_digikey_component_param.brandshort
 * 场景：brandshort 为空但 prajson 含 制造商 / Manufacturer（英文页仅 Manufacturer）
 * 幂等：只更新 brandshort 为空的行
 * prod：ALLOW_PROD=1 python sql_scripts/test/inductor/run_backfill_dk_brandshort.py
 * ============================================================ */

UPDATE dwd.dwd_digikey_component_param
SET brandshort = substr(TRIM(split_part(
        COALESCE(
            NULLIF(TRIM(get_json_string(prajson, '$.制造商')), ''),
            NULLIF(TRIM(get_json_string(prajson, '$.Manufacturer')), '')
        ),
        ' (', 1
    )), 1, 128),
    update_at = CURRENT_TIMESTAMP()
WHERE (brandshort IS NULL OR TRIM(brandshort) = '')
  AND (
        NULLIF(TRIM(get_json_string(prajson, '$.制造商')), '') IS NOT NULL
     OR NULLIF(TRIM(get_json_string(prajson, '$.Manufacturer')), '') IS NOT NULL
  );
