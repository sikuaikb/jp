/* ============================================================
 * DIM: dim.dim_attr_schema —— 标准属性字典（DDL only；多 L1 合并）
 *
 * 路径：sql_scripts/2.attribute_standard/dim_attr_schema.sql
 * 种子数据：sql_scripts/2.attribute_standard/seed/dim_attr_schema.csv
 * 装载：sql_scripts/2.attribute_standard/sync_attr_std_seed.sh test|prod
 *
 * 当前覆盖 L1：
 *   - resistor   (schema_version = resistor_schema_v1.5.09)
 *   - diode      (schema_version = v1.5.09)
 * 后续 L1 仅追加 seed CSV 行，不必改本 DDL。
 *
 * 设计：
 *   - PK (schema_version, l1_code, scope_level, scope_code, std_attr_code) 全局唯一；
 *   - 同一 (l1_code, scope_code, scope_level='l2') 仅一个 schema_version；
 *   - L2 公共属性走 scope_level=l2，L3 专有属性走 scope_level=l3；
 *   - display_ord 按段位：技术 100–199 / 封装 200–299 / 合规 300–399 / 交易 400–499，段内 L2 先于 L3。
 * ============================================================ */

DROP TABLE IF EXISTS dim.dim_attr_schema;

CREATE TABLE dim.dim_attr_schema (
    `schema_version`   VARCHAR(64)   NOT NULL COMMENT '属性目录版本（resistor_schema_v1.5.09 / v1.5.09 等）',
    `l1_code`          VARCHAR(64)   NOT NULL COMMENT 'L1 分类编码：resistor / diode / capacitor / ...',
    `scope_level`      VARCHAR(16)   NOT NULL COMMENT '作用域层级：l2 | l3',
    `scope_code`       VARCHAR(96)   NOT NULL COMMENT '作用域编码：l2_code 或 l3_code',
    `std_attr_code`    VARCHAR(128)  NOT NULL COMMENT '标准属性编码（snake_case；列名 / ext_attributes JSON 键）',
    `std_attr_cn`      VARCHAR(256)  NULL     COMMENT '核心属性中文名',
    `unit_std`         VARCHAR(64)   NULL     COMMENT '基准单位；与 dim_unit_factor.target_unit 对齐',
    `db_type`          VARCHAR(24)   NOT NULL COMMENT '落库类型：DOUBLE | INT | VARCHAR | BOOLEAN',
    `precision`        INT           NULL     COMMENT '小数精度（NULL = 不限）',
    `value_domain`     VARCHAR(2048) NULL     COMMENT '值域说明（原文 / 枚举）',
    `min_bound`        DOUBLE        NULL     COMMENT '数值下界（DOUBLE/INT；超界 → dq_flag=out_of_range）',
    `max_bound`        DOUBLE        NULL     COMMENT '数值上界',
    `is_l2_common`     TINYINT       NOT NULL COMMENT '1=L2 公共 0=L3 专属（透视时 L2 落物理列、L3 落 ext_attributes）',
    `display_ord`      INT           NULL     COMMENT '展示排序段位',
    `attr_category_cn` VARCHAR(256)  NULL     COMMENT '属性分类（中文）',
    `attr_category_en` VARCHAR(256)  NULL     COMMENT '英文分类：tech_specs / regulatory_attributes / purchasing_attributes / package_attributes',
    `note`             VARCHAR(2048) NULL     COMMENT '属性描述',
    `create_at`        DATETIME      NULL DEFAULT CURRENT_TIMESTAMP,
    `update_at`        DATETIME      NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=OLAP
PRIMARY KEY(`schema_version`, `l1_code`, `scope_level`, `scope_code`, `std_attr_code`)
COMMENT '标准属性字典（多 L1 合并；DDL 仅，数据来自 seed/dim_attr_schema.csv）'
DISTRIBUTED BY HASH(`std_attr_code`) BUCKETS 4
PROPERTIES ("replication_num" = "1", "enable_persistent_index" = "true");
