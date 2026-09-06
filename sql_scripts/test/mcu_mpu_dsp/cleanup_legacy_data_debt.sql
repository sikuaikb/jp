/* ============================================================
 * MCU/MPU/DSP legacy 数据债务清理（test_dwd only）
 *
 * 问题：icpdf 历史合并把 mcu/mpu/dsp 错拆为三个 L1，l2_code 带 _base；
 *       宽表 dwd_l2_mcu/mpu_soc/dsp 缺 data_source、表名/数据与 SKILL §六-B 不符。
 *
 * 正确形态：L1=mcu_mpu_dsp，L2∈{mcu,mpu_soc,dsp}，沙盒表 dwd_component_class_mcu_mpu_dsp。
 * 执行前请确认无下游依赖 legacy 表；本脚本仅作用于 test_dwd。
 * ============================================================ */

-- 1) 通用分类结果表：删除错拆 L1（mcu/mpu/dsp）
DELETE FROM test_dwd.dwd_component_class
WHERE l1_code IN ('mcu', 'mpu', 'dsp');

-- 2) EAV 窄表：删除 _base L2 编码行
DELETE FROM test_dwd.dwd_component_attr_std
WHERE l2_code IN ('mcu_base', 'mpu_soc_base', 'dsp_base');

-- 3) legacy 宽表（结构/命名均不合规，重建前 DROP）
DROP TABLE IF EXISTS test_dwd.dwd_l2_mcu;
DROP TABLE IF EXISTS test_dwd.dwd_l2_mpu_soc;
DROP TABLE IF EXISTS test_dwd.dwd_l2_dsp;

-- 4) icpdf 历史分 L1 沙盒并列表（已由 dwd_component_class_mcu_mpu_dsp 统一承接）
DROP TABLE IF EXISTS test_dwd.dwd_icpdf_component_class_mcu;
DROP TABLE IF EXISTS test_dwd.dwd_icpdf_component_class_mpu;
DROP TABLE IF EXISTS test_dwd.dwd_icpdf_component_class_dsp;
