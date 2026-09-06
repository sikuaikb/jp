/* ============================================================
 * DWS 层 schema 创建
 *
 * 路径：sql_scripts/foundation/dws_schema.sql
 *
 * 分层定位（DWS = 跨源实体解析 + 融合层）：
 *   - dws_component_entity       实体映射（强/中/弱三档匹配）
 *   - dws_l2_{l1}_{l2}_fused     按 entity_id 融合的宽表
 *
 * 环境隔离（对齐项目规范）：
 *   test_dws  开发验证库（默认目标）
 *   dws       生产库（须 ALLOW_PROD=1）
 *
 * 执行：
 *   mysql ... < sql_scripts/foundation/dws_schema.sql
 * ============================================================ */

CREATE DATABASE IF NOT EXISTS test_dws;
CREATE DATABASE IF NOT EXISTS dws;
