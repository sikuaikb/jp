/* ============================================================
 * dws.dws_component_entity —— 跨源实体映射表（强匹配版 v1）
 *
 * 路径：sql_scripts/foundation/dws_component_entity.sql
 *
 * 定位：DWS 层第一张表。把 icpdf + digikey 中"同一真实器件"映射到统一 entity_id。
 *       强匹配版：仅 (brand_id_std, mpn_std) 完全一致才合并，confidence=1.0。
 *       中/弱匹配后续版本扩展（match_tier / match_rule_id 已预留字段）。
 *
 * 依赖：dwd.v_param_normalized（DWD 字段级归一化视图）
 *       —— 不直接读 param 表，归一逻辑唯一入口在 v_param_normalized。
 *
 * entity_id 生成：xx_hash3_64(brand_id_std || mpn_std)
 *   —— 跨源稳定：同一 (brand, mpn) 在 icpdf/digikey 算出同一 entity_id。
 *
 * is_primary：一个 entity 内可能多行（每源一行，或同源多行），主行用于融合宽表取值锚点。
 *             v1 规则：digikey 优先（partno 更干净）；同源内取最小 id 保证确定性。
 *
 * 粒度：PK = (entity_id, data_source, source_id)
 *       一个 (brand, mpn) 实体 → 1~N 行（每源 0~多行）。
 *
 * 执行：先在 test_dws 验证，验证通过后切 dws 生产库。
 * ============================================================ */

/* ---- test_dws 开发验证库 ---- */
DROP TABLE IF EXISTS test_dws.dws_component_entity;

CREATE TABLE test_dws.dws_component_entity (
    `entity_id`         BIGINT        NOT NULL COMMENT '跨源实体ID = xx_hash3_64(brand_id_std || mpn_std)',
    `data_source`       VARCHAR(32)   NOT NULL COMMENT 'icpdf | digikey',
    `source_id`         BIGINT        NOT NULL COMMENT '源 param 表 id',
    `mpn_std`           VARCHAR(256)  NOT NULL COMMENT '归一化 MPN（来自 v_param_normalized）',
    `brand_id_std`      VARCHAR(64)   NOT NULL COMMENT '归一品牌ID',
    `brand_std`         VARCHAR(256)  NULL     COMMENT '归一品牌规范名',
    `partno_raw`        VARCHAR(256)  NULL     COMMENT '源原始 partno（溯源）',
    `match_tier`        VARCHAR(16)   NOT NULL DEFAULT 'strong' COMMENT 'strong | mid | weak',
    `match_confidence`  DECIMAL(5,4)  NOT NULL COMMENT '强匹配 1.0；中 0.85；弱 <0.7',
    `match_rule_id`     VARCHAR(64)   NULL     COMMENT '中/弱匹配命中的规则id；强匹配为 NULL',
    `is_primary`        BOOLEAN       NOT NULL COMMENT '该 entity 内主行（融合宽表取值锚点）',
    `create_at`         DATETIME      NULL DEFAULT CURRENT_TIMESTAMP,
    `update_at`         DATETIME      NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=OLAP
PRIMARY KEY(`entity_id`, `data_source`, `source_id`)
COMMENT 'DWS 跨源实体映射（强匹配版 v1：brand_id_std + mpn_std 完全一致）'
DISTRIBUTED BY HASH(`entity_id`) BUCKETS 16
PROPERTIES ("replication_num" = "1", "enable_persistent_index" = "true");

/* 装数：仅 is_mpn_like=1 且品牌命中的行参与强匹配 */
DELETE FROM test_dws.dws_component_entity WHERE match_tier = 'strong';

INSERT INTO test_dws.dws_component_entity
(
    entity_id, data_source, source_id,
    mpn_std, brand_id_std, brand_std, partno_raw,
    match_tier, match_confidence, match_rule_id, is_primary,
    create_at, update_at
)
WITH norm AS (
    SELECT
        data_source,
        id          AS source_id,
        mpn_std,
        brand_id_std,
        brand_std,
        partno_raw
    FROM dwd.v_param_normalized
    WHERE brand_id_std IS NOT NULL
      AND is_mpn_like = 1
      AND mpn_std IS NOT NULL AND TRIM(mpn_std) <> ''
),
with_eid AS (
    SELECT
        xx_hash3_64(CONCAT(brand_id_std, mpn_std)) AS entity_id,
        data_source,
        source_id,
        mpn_std,
        brand_id_std,
        brand_std,
        partno_raw
    FROM norm
),
ranked AS (
    /* entity 内主行选择：
     *   1) digikey 优先（partno 更干净，lifecycle/商务属性更全）
     *   2) 同源内取最小 source_id 保证确定性
     * 主行 = entity 内 (data_source 优先级, source_id) 最小者 */
    SELECT
        entity_id,
        data_source,
        source_id,
        mpn_std,
        brand_id_std,
        brand_std,
        partno_raw,
        ROW_NUMBER() OVER (
            PARTITION BY entity_id
            ORDER BY
                CASE data_source WHEN 'digikey' THEN 0 ELSE 1 END,
                source_id
        ) AS rn
    FROM with_eid
)
SELECT
    entity_id,
    data_source,
    source_id,
    mpn_std,
    brand_id_std,
    brand_std,
    partno_raw,
    'strong'                    AS match_tier,
    1.0000                      AS match_confidence,
    CAST(NULL AS VARCHAR(64))   AS match_rule_id,
    (rn = 1)                    AS is_primary,
    CURRENT_TIMESTAMP()         AS create_at,
    CURRENT_TIMESTAMP()         AS update_at
FROM ranked;
