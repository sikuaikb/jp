/* ============================================================
 * DIM: dim.dim_unit_factor —— 单位换算字典（DDL only）
 *
 * 路径：sql_scripts/2.attribute_standard/dim_unit_factor.sql
 * 种子数据：sql_scripts/2.attribute_standard/seed/dim_unit_factor.csv
 * 装载：sql_scripts/2.attribute_standard/sync_attr_std_seed.sh test|prod
 *
 * 单一共享表（不按 L1 分），任一 L1 新增 unit_raw 都通过追加 seed CSV 行实现。
 * factor 含义：raw_value × factor = target_unit 下的数值；
 *   e.g. ('V','mV',0.001)：1000 mV = 1 V；('Ω','kΩ',1000)：1 kΩ = 1000 Ω
 *
 * target_unit 与 dim_attr_schema.unit_std 对齐：保留符号单位（Ω、℃、V…），不维护 ohm/deg_c 等 snake 写法。
 * ============================================================ */

DROP TABLE IF EXISTS dim.dim_unit_factor;

CREATE TABLE dim.dim_unit_factor (
    `target_unit`  VARCHAR(16)  NOT NULL COMMENT '目标单位（与 dim_attr_schema.unit_std 一致）',
    `unit_raw`     VARCHAR(32)  NOT NULL COMMENT 'raw 字符串里的单位字面',
    `factor`       DOUBLE       NOT NULL COMMENT 'raw_value × factor = 目标单位下数值',
    `note`         VARCHAR(64)  NULL,
    `create_at`    DATETIME     NULL DEFAULT CURRENT_TIMESTAMP,
    `update_at`    DATETIME     NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=OLAP
PRIMARY KEY(`target_unit`, `unit_raw`)
COMMENT '单位换算字典（DDL 仅，数据来自 seed/dim_unit_factor.csv）'
DISTRIBUTED BY HASH(`target_unit`) BUCKETS 4
PROPERTIES ("replication_num" = "1");
