/* prod SHOW CREATE TABLE dwd.dwd_l2_logic_ic_signal_buffer_driver */

CREATE TABLE `dwd_l2_logic_ic_signal_buffer_driver` (
  `data_source` varchar(32) NOT NULL DEFAULT "digikey" COMMENT "",
  `id` bigint(20) NOT NULL COMMENT "",
  `mpn` varchar(1024) NULL COMMENT "",
  `brand` varchar(256) NULL COMMENT "",
  `brandid` bigint(20) NULL COMMENT "",
  `l1_code` varchar(32) NOT NULL COMMENT "",
  `l2_code` varchar(96) NOT NULL COMMENT "",
  `l3_code` varchar(96) NULL COMMENT "",
  `brandshort` varchar(256) NULL COMMENT "",
  `l3_id` int(11) NULL COMMENT "",
  `manufacturer` varchar(1024) NULL COMMENT "",
  `rohs_compliant` varchar(1024) NULL COMMENT "",
  `lifecycle_status` varchar(128) NULL COMMENT "",
  `reach` varchar(1024) NULL COMMENT "",
  `eccn_code` varchar(1024) NULL COMMENT "",
  `lead_free` varchar(1024) NULL COMMENT "",
  `msl_level` varchar(128) NULL COMMENT "",
  `package_case` varchar(1024) NULL COMMENT "",
  `mount_type` varchar(1024) NULL COMMENT "",
  `temp_min_c` double NULL COMMENT "",
  `temp_max_c` double NULL COMMENT "",
  `supply_voltage_min_v` double NULL COMMENT "",
  `supply_voltage_max_v` double NULL COMMENT "",
  `propagation_delay_ns` double NULL COMMENT "",
  `output_current_high_low` varchar(1024) NULL COMMENT "",
  `logic_series` varchar(1024) NULL COMMENT "",
  `ext_attributes` json NULL COMMENT "",
  `semantic_tags` json NULL COMMENT "",
  `dq_score` double NULL COMMENT "",
  `dq_flags` json NULL COMMENT "",
  `source_id` bigint(20) NULL COMMENT "",
  `create_at` datetime NULL DEFAULT CURRENT_TIMESTAMP COMMENT "",
  `update_at` datetime NULL DEFAULT CURRENT_TIMESTAMP COMMENT ""
) ENGINE=OLAP 
PRIMARY KEY(`data_source`, `id`)
COMMENT "logic_ic / signal_buffer_driver L2 宽表"
DISTRIBUTED BY HASH(`id`) BUCKETS 16 
PROPERTIES (
"compression" = "LZ4",
"datacache.enable" = "true",
"enable_async_write_back" = "false",
"enable_persistent_index" = "true",
"file_bundling" = "true",
"persistent_index_type" = "CLOUD_NATIVE",
"replication_num" = "1",
"storage_volume" = "builtin_storage_volume"
);;
