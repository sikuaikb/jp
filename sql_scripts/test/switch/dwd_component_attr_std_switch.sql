/* ============================================================
 * DWD：多源元器件标准化属性窄表（EAV）
 *
 * 数据源：dim_attr_schema 定义全部 (l1_code, l2_code) scope + std_attr_code，
 *        各源（icpdf / digikey / mouser ...）由独立 build SQL 装载，写入同一张表，
 *        通过 data_source 列区分。
 *
 * 主键：(data_source, id, std_attr_code) —— 多源同一 id 不冲突；同一源同一 id 同一属性唯一一行。
 *
 * 装载策略：各源 build SQL 用 DELETE FROM ... WHERE data_source='<src>' 后全量 INSERT。
 *
 * 历史：从 dwd_icpdf_component_attr_std 演进而来，原 DDL/PK 不含 data_source；
 *       cutover 时由发布脚本统一执行本文件 DDL 后再各源 build。
 * ============================================================ */

DROP TABLE IF EXISTS test_dwd.dwd_component_attr_std_switch;

CREATE TABLE test_dwd.dwd_component_attr_std_switch (
    `data_source`            VARCHAR(32)   NOT NULL COMMENT '数据源：icpdf | digikey | mouser ...',
    `id`                     BIGINT        NOT NULL COMMENT '组件 ID（对齐对应源 param 表 id）',
    `std_attr_code`          VARCHAR(128)  NOT NULL COMMENT '标准属性编码（与 dim_attr_schema 对齐）',
    `l2_code`                VARCHAR(32)   NULL     COMMENT '分类 L2 编码',
    `l3_id`                  VARCHAR(6)    NULL     COMMENT '分类 L3 短 ID',
    `l3_code`                VARCHAR(64)   NULL     COMMENT '分类 L3 编码',
    `attr_schema_version`    VARCHAR(32)   NOT NULL COMMENT '所用属性目录版本',
    `std_attr_cn`            VARCHAR(256)  NULL     COMMENT '标准属性中文名（快照）',
    `db_type`                VARCHAR(24)   NULL     COMMENT '属性类型（快照）：DOUBLE | INT | VARCHAR | BOOLEAN',
    `unit_std`               VARCHAR(32)   NULL     COMMENT '基准单位（快照）',
    `value_raw`              VARCHAR(1024) NULL     COMMENT '原始取值字符串',
    `extract_rule_id`        VARCHAR(128)  NULL     COMMENT '胜出规则 ID',
    `match_priority`         INT           NULL     COMMENT '胜出规则优先级（数值越小越优先）',
    `clean_str`              VARCHAR(1024) NULL     COMMENT '清洗后待解析字符串',
    `value_std_double`       DOUBLE        NULL     COMMENT '标准化数值（DOUBLE/INT；BOOLEAN 运行态以 1/0 存于该列）',
    `value_std_varchar`      VARCHAR(1024) NULL     COMMENT '标准化文本（VARCHAR/ENUM 等）',
    `dq_flag`                VARCHAR(32)   NULL     COMMENT '质量标记：out_of_range | parse_fail 等',
    `create_at`              DATETIME      NULL DEFAULT CURRENT_TIMESTAMP COMMENT '写入时间',
    `update_at`              DATETIME      NULL DEFAULT CURRENT_TIMESTAMP COMMENT '更新时间'
) ENGINE=OLAP
PRIMARY KEY(`data_source`, `id`, `std_attr_code`)
COMMENT '多源元器件标准化属性窄表（EAV；dim_attr_schema 中全部 L2 scope 驱动）'
DISTRIBUTED BY HASH(`id`) BUCKETS 16
PROPERTIES ("replication_num" = "1", "enable_persistent_index" = "true");
