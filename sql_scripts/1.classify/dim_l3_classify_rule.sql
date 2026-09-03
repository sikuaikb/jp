/* ============================================================
 * dim.dim_l3_classify_rule —— icpdf L3 分类规则（DDL 仅；多 L1 合并）
 *
 * 路径：`sql_scripts/1.classify/dim_l3_classify_rule.sql`
 * 数据来源：历史 seed CSV 或新 L1 合并时的 `test_dim.dim_l3_classify_rule_<l1>` 后缀表
 *   - match_values 列以 JSON 数组字面量存储（如 ["A","B"]）
 *   - match_map    列以 JSON 对象字面量存储（如 {"k":"v"}）
 *   - 空单元格 = SQL NULL
 * 合并：分类阶段只合并 taxonomy + rule 数据；`dwd_component_class.sql` 以主干最新引擎为准
 *
 * **规则引擎总览**（谓词语义、gate/classify、扩展 checklist）：`sql_scripts/1.classify/RULE_ENGINE.md`
 *
 * PK：(rule_id, clause_group_id, clause_ord)，全局唯一；`rule_id` **必须带 L1 前缀**
 * （resistor_*, diode_*, cap_*, gate_<l1>_icpdf_v1）以保证扩 L1 时不撞 PK。
 * ============================================================ */

DROP TABLE IF EXISTS dim.dim_l3_classify_rule;

CREATE TABLE dim.dim_l3_classify_rule (
    `rule_id`               VARCHAR(64)    NOT NULL COMMENT '逻辑规则 ID（可多行）',
    `clause_group_id`       INT            NOT NULL COMMENT '条件组；组间 OR',
    `clause_ord`            INT            NOT NULL COMMENT '组内顺序；组内 AND',

    `schema_version`        VARCHAR(64)    NOT NULL,
    `data_source`           VARCHAR(32)    NOT NULL COMMENT 'icpdf 等',

    `rule_kind`             VARCHAR(16)    NOT NULL COMMENT 'gate | classify',

    `l3_id`                 VARCHAR(6)     NULL COMMENT 'classify 必填；gate 为 NULL',
    `l3_cn`                 VARCHAR(128)   NULL COMMENT '展示用，与 dim.dim_l3_classify.l3_cn 一致',

    `phase`                 TINYINT        NOT NULL COMMENT '1=入口 2=keyword 3=json 消解',
    `rule_priority`         INT            NOT NULL COMMENT '同 phase 内越小越优先',
    `enabled`               TINYINT        NOT NULL COMMENT '1 启用',

    `confidence_weight`     DECIMAL(5,4)    NOT NULL,

    `classify_source_hint`  VARCHAR(32)    NULL,

    `field_code`            VARCHAR(32)    NOT NULL COMMENT '谓词类型',

    `match_value`           VARCHAR(512)   NULL COMMENT 'eq / like / regexp 单值',
    `match_values`          ARRAY<VARCHAR(128)> NULL COMMENT 'in / overlap 列表',

    `match_map`             MAP<VARCHAR(512), VARCHAR(512)> NULL COMMENT 'parjson_match_map：顶层键→LIKE 模式',

    `note`                  VARCHAR(512)   NULL,

    `create_at`             DATETIME       NULL DEFAULT CURRENT_TIMESTAMP,
    `update_at`             DATETIME       NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=OLAP
PRIMARY KEY(`rule_id`, `clause_group_id`, `clause_ord`)
COMMENT 'icpdf L3 分类规则（多 L1 合并；DDL 仅）'
DISTRIBUTED BY HASH(`rule_id`) BUCKETS 1
PROPERTIES ("replication_num" = "1", "enable_persistent_index" = "true");
