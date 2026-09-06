DROP TABLE IF EXISTS dwd.dwd_l2_pmic_linear_regulator_reference;
CREATE TABLE dwd.dwd_l2_pmic_linear_regulator_reference (
    `data_source`                         VARCHAR(32)            NOT NULL DEFAULT 'icpdf' COMMENT '数据来源',
    `id`                                  BIGINT                 NOT NULL COMMENT '组件唯一 ID',
    -- ── 标准头部（与全平台 L2 宽表一致）─────────────────────
    `mpn`                                 VARCHAR(1024)          NULL COMMENT '制造商料号（同源 dwd_icpdf_component_param.partno）',
    `brand`                               VARCHAR(256)           NULL COMMENT '标准品牌名（dim_std_brand；未命中回退 raw）',
    `brandid`                             BIGINT                 NULL COMMENT '标准品牌 ID（dim_std_brand；未命中回退 raw）',
    `l1_code`                             VARCHAR(32)            NOT NULL COMMENT 'L1：pmic',
    `l2_code`                             VARCHAR(32)            NOT NULL COMMENT 'L2 编码，本表内为常量',
    `l3_code`                             VARCHAR(64)            NULL COMMENT 'L3 形态编码',
    -- ── L2 专有属性（线性稳压与基准源基类）────────────────────────────────
    `manufacturer`                        VARCHAR(512)           NULL COMMENT '制造商；prajson2: COALESCE(IHS 制造商, Brand Name)，IHS 制造商优先，fallback Brand Name；双 key 合并后空值率从 ~45% → ~10-15%',
    `rohs_compliant`                      BOOLEAN                NULL COMMENT 'RoHS合规',
    `lifecycle_status`                    VARCHAR(64)            NULL COMMENT '生命周期状态',
    `reach`                               VARCHAR(64)            NULL COMMENT 'REACH合规',
    `eccn_code`                           VARCHAR(512)           NULL COMMENT '出口管制分类编号',
    `aec_q_level`                         VARCHAR(64)            NULL COMMENT '汽车级认证等级',
    `lead_free`                           BOOLEAN                NULL COMMENT '无铅',
    `msl_level`                           VARCHAR(64)            NULL COMMENT '湿敏等级',
    `package_case`                        VARCHAR(512)           NULL COMMENT '封装形式',
    `mounting_style`                       VARCHAR(32)            NULL COMMENT '安装方式：SMD（表面贴装）/ THT（通孔插件）/ Other；从 package_case 或 prajson2.封装形式 推导',
    `temp_min_c`                          DOUBLE                 NULL COMMENT '最低工作温度（℃）；prajson2 key: 最低工作温度 OR 工作温度TJ-Min（LDO/其他稳压器类两种命名均存在）',
    `temp_max_c`                          DOUBLE                 NULL COMMENT '最高工作温度（℃）；prajson2 key: 最高工作温度 OR 工作温度TJ-Max（LDO/其他稳压器类两种命名均存在）',
    `input_voltage_max_v`                 DOUBLE                 NULL COMMENT '最大输入电压（V）；prajson2 key: 最大输入电压',
    `input_voltage_min_v`                 DOUBLE                 NULL COMMENT '最小输入电压（V）；prajson2 key: 最小输入电压',
    `output_voltage_v`                    DOUBLE                 NULL COMMENT '标称输出电压（V）；prajson2 key: 标称输出电压 1',
    `output_current_max_ma`               DOUBLE                 NULL COMMENT '最大输出电流（mA）；prajson2 key: 最大输出电流 1（注意带空格和序号后缀，与开关类的"最大输出电流"不同）',
    `quiescent_current_ua`                DOUBLE                 NULL COMMENT '静态电流（µA）；【数据源局限】prajson2 无对应字段，探针已确认 100% NULL，暂不填充',
    `is_output_adjustable`                BOOLEAN                NULL COMMENT '输出电压是否可调；prajson2 key: 可调性（ADJUSTABLE/FIXED）',
    -- ── 标准尾部（与全平台 L2 宽表一致）─────────────────────
    `ext_attributes`                      JSON                   NULL COMMENT 'L3 专有属性 KV 包（dim scope_level=l3）',
    `semantic_tags`                       JSON                   NULL COMMENT '业务场景标签数组',
    `dq_score`                            DOUBLE                 NULL COMMENT '数据质量综合分（预留）',
    `dq_flags`                            JSON                   NULL COMMENT '数据质量标记（预留）',
    `source_id`                           BIGINT                 NULL COMMENT '来源表原始 id（dwd_icpdf_component_param.id）',
    `create_at`                           DATETIME               NULL DEFAULT CURRENT_TIMESTAMP COMMENT '入库时间',
    `update_at`                           DATETIME               NULL DEFAULT CURRENT_TIMESTAMP COMMENT '最近一次更新时间'
) ENGINE=OLAP
PRIMARY KEY(`data_source`, `id`)
COMMENT '组件唯一 ID'
DISTRIBUTED BY HASH(`id`) BUCKETS 16
PROPERTIES ("replication_num" = "1", "enable_persistent_index" = "true");
