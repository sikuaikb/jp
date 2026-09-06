/* ============================================================
 * DIM: dim.dim_attr_extract_rule —— ICPDF 属性抽取规则（DDL only；多 L1 合并）
 *
 * 路径：sql_scripts/2.attribute_standard/dim_attr_extract_rule.sql
 * 种子数据：sql_scripts/2.attribute_standard/seed/dim_attr_extract_rule.csv
 * 装载：sql_scripts/2.attribute_standard/sync_attr_std_seed.sh test|prod
 *
 * 当前覆盖 L1：
 *   - resistor 规则 (前缀 rs1509_ / th1509_ 等)
 *   - diode    规则 (前缀 d1509_)
 *   - capacitor 规则 (前缀 cap100_)
 *
 * 命名约定：extract_rule_id 全局唯一，**必须带 L1 前缀**避免跨 L1 撞 PK。
 *
 * data_source：标识规则只针对哪个数据源（icpdf / digikey / ...）。EAV build 时按
 *   `r.data_source = p.data_source` 过滤，避免 DigiKey 规则误匹配 ICPDF 数据。
 *   - 'icpdf'   ：从 dwd.dwd_icpdf_component_param 抽取
 *   - 'digikey' ：从 dwd.dwd_digikey_component_param 抽取（前缀 dk1520_）
 *
 * source_kind：
 *   - prajson2_key_eq         ：prajson2 顶层键名精确匹配
 *   - prajson_cn_eq           ：prajson 数组元素 $.cn 全文匹配
 *   - prajson_sqlname_eq      ：prajson 数组元素 $.sqlname 匹配
 *   - param_category_eq       ：dwd_icpdf_component_param.category 全文匹配
 *   - param_category2_eq      ：param.category2 全文匹配
 *   - param_taginfo_eq        ：taginfo 数组元素匹配
 *   - param_category_info_eq  ：category_info 数组元素匹配
 *
 * apply_scope_level/code：
 *   - NULL/NULL：不额外收窄，靠 JOIN dim_attr_schema 自然按 L2/L3 分流
 *   - l2 / 具体 l2_code：仅对该 L2 生效
 *   - l3 / 具体 l3_code：仅对该 L3 生效
 *
 * priority：胜出顺序，数值越小越优先。
 *
 * value_map：可选 JSON 对象，做 raw_value → std_value 的字面映射；
 *   一条 extract_rule 既负责抽取（source_*）也负责值标准化（value_map）。
 *   - 命中 key：用对应 value 作为标准值
 *   - 不命中：保留原 raw_value
 *   - 配合 _default 兜底；映射到空串 "" 则丢弃（输出 NULL）
 *   示例：{"在售":"Active","已过时":"Obsolete","_default":""}
 *
 * source_value_regex：可选 regex，做 raw_value 的子串/group 提取；
 *   - 在 value_map 应用之前先跑 regex
 *   - 取第 1 个 capture group 作为新 raw_value
 *   - 用于 range/复合 value 拆字段：
 *     "工作温度": "-40°C ~ 125°C" → temp_min 用 '^(-?\d+(?:\.\d+)?)°C'，temp_max 用 '~\s*(-?\d+(?:\.\d+)?)°C'
 *     "大小 / 尺寸": "0.118\" 长 x 0.118\" 宽（3.00mm x 3.00mm）" → pkg_length 用 '（(\d+(?:\.\d+)?)mm'
 *   - 不匹配则 raw_value 置 NULL（该字段不抽取）
 * ============================================================ */

DROP TABLE IF EXISTS dim.dim_attr_extract_rule;

CREATE TABLE dim.dim_attr_extract_rule (
    `extract_rule_id`     VARCHAR(128)  NOT NULL COMMENT '规则主键（全局唯一；带 L1 前缀如 rs1509_、d1509_、dk1520_）',
    `data_source`         VARCHAR(32)   NOT NULL DEFAULT 'icpdf' COMMENT '数据源：icpdf | digikey | mouser ...',
    `schema_version`      VARCHAR(64)   NOT NULL COMMENT '对齐 dim_attr_schema.schema_version',
    `l1_code`             VARCHAR(64)   NOT NULL COMMENT '对齐 taxonomy L1',
    `apply_scope_level`   VARCHAR(16)   NULL     COMMENT 'NULL | l2 | l3',
    `apply_scope_code`    VARCHAR(96)   NULL     COMMENT 'l2_code 或 l3_code',
    `std_attr_code`       VARCHAR(128)  NOT NULL COMMENT '目标标准属性编码',
    `source_kind`         VARCHAR(32)   NOT NULL COMMENT '抽取通道（见文件头注释）',
    `source_expr`         VARCHAR(512)  NOT NULL COMMENT '匹配字面量',
    `source_value_expr`   VARCHAR(1024) NULL     COMMENT 'ICDPDF 原文过滤（lower(trim) 比较）',
    `source_value_regex`  VARCHAR(512)  NULL     COMMENT '可选 regex（首个 capture group 作为新 raw_value）；常用于从 range/复合 value 中拆字段，例如 "-40°C~125°C" 拆 min/max',
    `literal_std_value`   VARCHAR(1024) NULL     COMMENT '命中后写入的标准值（非 NULL 则覆盖原文）',
    `priority`            INT           NOT NULL COMMENT '胜出优先级，数值越小越优先',
    `enabled`             TINYINT       NOT NULL COMMENT '1 启用 / 0 停用',
    `value_map`           JSON          NULL     COMMENT '可选 raw→std 字面映射（JSON object）；NULL 表示不做映射保留 raw',
    `note`                VARCHAR(512)  NULL     COMMENT '溯源 / 运维说明',
    `create_at`           DATETIME      NULL DEFAULT CURRENT_TIMESTAMP,
    `update_at`           DATETIME      NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=OLAP
PRIMARY KEY(`extract_rule_id`)
COMMENT 'ICPDF 属性抽取规则（多 L1 合并；DDL 仅，数据来自 seed/dim_attr_extract_rule.csv）'
DISTRIBUTED BY HASH(`extract_rule_id`) BUCKETS 4
PROPERTIES ("replication_num" = "1", "enable_persistent_index" = "true");
