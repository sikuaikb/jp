DROP TABLE IF EXISTS dwd.dwd_l2_pmic_switching_controller;
CREATE TABLE dwd.dwd_l2_pmic_switching_controller (
    `data_source`                         VARCHAR(32)            NOT NULL DEFAULT 'icpdf' COMMENT '数据来源',
    `id`                                  BIGINT                 NOT NULL COMMENT '组件唯一 ID',
    -- ── 标准头部（与全平台 L2 宽表一致）─────────────────────
    `mpn`                                 VARCHAR(1024)          NULL COMMENT '制造商料号（同源 dwd_icpdf_component_param.partno）',
    `brand`                               VARCHAR(256)           NULL COMMENT '标准品牌名（dim_std_brand；未命中回退 raw）',
    `brandid`                             BIGINT                 NULL COMMENT '标准品牌 ID（dim_std_brand；未命中回退 raw）',
    `l1_code`                             VARCHAR(32)            NOT NULL COMMENT 'L1：pmic',
    `l2_code`                             VARCHAR(32)            NOT NULL COMMENT 'L2 编码，本表内为常量',
    `l3_code`                             VARCHAR(64)            NULL COMMENT 'L3 形态编码',
    -- ── L2 专有属性（开关电源控制器基类）────────────────────────────────
    `manufacturer`                        VARCHAR(512)           NULL COMMENT '制造商；prajson2: COALESCE(IHS 制造商, Brand Name)，IHS 制造商优先，fallback Brand Name；双 key 合并后空值率从 ~45% → ~10-15%',
    `rohs_compliant`                      BOOLEAN                NULL COMMENT 'RoHS合规',
    `lifecycle_status`                    VARCHAR(64)            NULL COMMENT '生命周期状态',
    `reach`                               BOOLEAN                NULL COMMENT 'REACH合规',
    `eccn_code`                           VARCHAR(512)           NULL COMMENT '出口管制分类号',
    `aec_q_level`                         VARCHAR(64)            NULL COMMENT '车规认证等级',
    `lead_free`                           BOOLEAN                NULL COMMENT '无铅',
    `msl_level`                           VARCHAR(64)            NULL COMMENT '湿敏等级',
    `package_case`                        VARCHAR(512)           NULL COMMENT '封装形式',
    `mounting_style`                       VARCHAR(32)            NULL COMMENT '安装方式：SMD（表面贴装）/ THT（通孔插件）/ Other；从 package_case 或 prajson2.封装形式 推导',
    `temp_min_c`                          DOUBLE                 NULL COMMENT '最低工作温度（℃）',
    `temp_max_c`                          DOUBLE                 NULL COMMENT '最高工作温度（℃）',
    `pkg_length_mm`                       DOUBLE                 NULL COMMENT '封装体长度（mm）',
    `pkg_width_mm`                        DOUBLE                 NULL COMMENT '封装体宽度（mm）',
    `pkg_height_mm`                       DOUBLE                 NULL COMMENT '封装体高度（mm）',
    `vin_min_v`                           DOUBLE                 NULL COMMENT '最小输入电压（V）',
    `vin_max_v`                           DOUBLE                 NULL COMMENT '最大输入电压（V）',
    `fsw_max_khz`                         DOUBLE                 NULL COMMENT '最大开关频率（kHz）',
    `ctrl_topology_type`                  VARCHAR(64)            NULL COMMENT '拓扑路由类型',
    `control_mode`                        VARCHAR(64)            NULL COMMENT '控制模式',
    `output_channel_count`                BIGINT                 NULL COMMENT '输出通道数',
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
