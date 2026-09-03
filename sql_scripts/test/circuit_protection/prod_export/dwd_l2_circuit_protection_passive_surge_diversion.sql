/* prod SHOW CREATE TABLE dwd.dwd_l2_circuit_protection_passive_surge_diversion */

CREATE TABLE `dwd_l2_circuit_protection_passive_surge_diversion` (
  `data_source` varchar(32) NOT NULL DEFAULT "digikey" COMMENT "数据源",
  `id` bigint(20) NOT NULL COMMENT "物料唯一 ID",
  `mpn` varchar(1024) NULL COMMENT "MPN",
  `brand` varchar(256) NULL COMMENT "标准化品牌全称",
  `brandid` bigint(20) NULL COMMENT "标准化品牌 ID",
  `l1_code` varchar(32) NOT NULL COMMENT "L1: circuit_protection",
  `l2_code` varchar(96) NOT NULL COMMENT "L2: passive_surge_diversion",
  `l3_code` varchar(96) NULL COMMENT "L3: mov / gdt / ...",
  `brandshort` varchar(256) NULL COMMENT "原始品牌简称",
  `l3_id` varchar(6) NULL COMMENT "L3 短 ID",
  `manufacturer` varchar(1024) NULL COMMENT "制造商",
  `lifecycle_status` varchar(64) NULL COMMENT "生命周期状态",
  `rohs_compliant` varchar(256) NULL COMMENT "RoHS 合规",
  `lead_free` varchar(256) NULL COMMENT "无铅工艺",
  `msl_level` varchar(64) NULL COMMENT "湿气敏感等级",
  `package_case` varchar(256) NULL COMMENT "封装形式",
  `temp_min_c` double NULL COMMENT "最低工作温度 ℃",
  `temp_max_c` double NULL COMMENT "最高工作温度 ℃",
  `max_continuous_voltage_v` double NULL COMMENT "最大持续工作电压 V（AC）",
  `ext_attributes` json NULL COMMENT "L3专有：mov→varistor_voltage_v, junction_capacitance_pf",
  `semantic_tags` json NULL COMMENT "业务标签（预留）",
  `dq_score` double NULL COMMENT "数据质量分（预留）",
  `dq_flags` json NULL COMMENT "数据质量标记（预留）",
  `source_id` bigint(20) NULL COMMENT "源端原始 id",
  `create_at` datetime NULL DEFAULT CURRENT_TIMESTAMP COMMENT "",
  `update_at` datetime NULL DEFAULT CURRENT_TIMESTAMP COMMENT ""
) ENGINE=OLAP 
PRIMARY KEY(`data_source`, `id`)
COMMENT "DWD L2 无源浪涌能量泄放宽表（circuit_protection_schema_v1.16.01）"
DISTRIBUTED BY HASH(`id`) BUCKETS 4 
PROPERTIES (
"compression" = "ZSTD",
"datacache.enable" = "true",
"enable_async_write_back" = "false",
"enable_persistent_index" = "true",
"file_bundling" = "true",
"persistent_index_type" = "CLOUD_NATIVE",
"replication_num" = "1",
"storage_volume" = "builtin_storage_volume"
);;
