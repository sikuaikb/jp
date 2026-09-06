/* merge 协调：ICPDF circuit_protection · rival gate 让渡
 * 在 classify-merge 后执行于 prod dim（与 CP 规则一并生效）
 * 生成：patch_icpdf_cp_gate_coordination.py --write
 */

UPDATE dim.dim_l3_classify_rule
SET match_values = ARRAY<VARCHAR(128)>['DIAC','DIAC双向触发二极管,DIAC','ESD二极管','ESD保护','PIN 二极管','RF二极管','三相整流桥','三相整流桥模块','专用微波二极管','二极管','二极管阵列','信号二极管','其他二极管','击穿二极管','功率二极管','功率超快恢复二极管','双向触发二极管','变容二极管','小信号二极管','小信号开关二极管','小信号肖特基二极管','微波混频二极管','快恢复二极管','快速恢复二极管','快速软恢复二极管','整流二极管','普通整流二极管','普通整流桥','桥式整流二极管','桥式整流器','电压倍频二极管','稳压二极管','稳定二极管','肖特基二极管','超快恢复二极管','超快软恢复二极管','超快速恢复二极管','超快速软恢复二极管','超软恢复二极管','超高速恢复二极管','超高速软恢复二极管','软恢复二极管','阶跃恢复二极管','非常快速的恢复二极管','非常快速的软恢复二极管','高压快速恢复二极管','高压快速软恢复二极管','高压超快恢复二极管','高压超快速恢复二极管','高压超快速软恢复二极管','高压软恢复二极管','高效整流二极管','齐纳二极管'],
    note = '真二极管 category 白名单（共 56 个字面）；EXCLUDED 字面不在此处，自然被 gate 拦下；TVS/瞬态抑制类已让渡 circuit_protection icpdf gate'
WHERE rule_id = 'gate_diode_icpdf_v1' AND clause_group_id = 0 AND clause_ord = 0;

UPDATE dim.dim_l3_classify_rule
SET match_values = ARRAY<VARCHAR(128)>['DIAC','DIAC双向触发二极管,DIAC','ESD二极管','ESD保护','PIN 二极管','RF二极管','三相整流桥','三相整流桥模块','专用微波二极管','二极管','二极管阵列','信号二极管','其他二极管','击穿二极管','功率二极管','功率超快恢复二极管','双向触发二极管','变容二极管','小信号二极管','小信号开关二极管','小信号肖特基二极管','微波混频二极管','快恢复二极管','快速恢复二极管','快速软恢复二极管','整流二极管','普通整流二极管','普通整流桥','桥式整流二极管','桥式整流器','电压倍频二极管','稳压二极管','稳定二极管','肖特基二极管','超快恢复二极管','超快软恢复二极管','超快速恢复二极管','超快速软恢复二极管','超软恢复二极管','超高速恢复二极管','超高速软恢复二极管','软恢复二极管','阶跃恢复二极管','非常快速的恢复二极管','非常快速的软恢复二极管','高压快速恢复二极管','高压快速软恢复二极管','高压超快恢复二极管','高压超快速恢复二极管','高压超快速软恢复二极管','高压软恢复二极管','高效整流二极管','齐纳二极管'],
    note = '真二极管 category2 白名单（与 category 共用同一份字面集）；TVS/瞬态抑制类已让渡 circuit_protection icpdf gate'
WHERE rule_id = 'gate_diode_icpdf_v1' AND clause_group_id = 1 AND clause_ord = 0;

-- rival gate exclude 行（幂等：先删后插）
DELETE FROM dim.dim_l3_classify_rule WHERE rule_id = 'gate_diode_icpdf_exclude_cp_tvs_v1';

DELETE FROM dim.dim_l3_classify_rule WHERE rule_id = 'gate_resistor_icpdf_exclude_cp_v1';

DELETE FROM dim.dim_l3_classify_rule WHERE rule_id = 'gate_transistor_icpdf_exclude_cp_v1';

INSERT INTO dim.dim_l3_classify_rule (rule_id, clause_group_id, clause_ord, schema_version, data_source, rule_kind, l3_id, l3_cn, phase, rule_priority, enabled, confidence_weight, classify_source_hint, field_code, match_value, match_values, match_map, note)
VALUES ('gate_diode_icpdf_exclude_cp_tvs_v1', '0', '0', 'v1.5.09', 'icpdf', 'gate', NULL, NULL, '1', '1', '1', '1', 'gate_exclude_category', 'gate_exclude_category_like', NULL, ARRAY<VARCHAR(128)>['瞬态抑制二极管','TVS二极管','瞬态抑制器'], NULL, 'CP 协调：category=TVS/瞬态抑制 不进 diode（即使 category2 命中整流二极管）');

INSERT INTO dim.dim_l3_classify_rule (rule_id, clause_group_id, clause_ord, schema_version, data_source, rule_kind, l3_id, l3_cn, phase, rule_priority, enabled, confidence_weight, classify_source_hint, field_code, match_value, match_values, match_map, note)
VALUES ('gate_transistor_icpdf_exclude_cp_v1', '0', '0', 'v1.5.09', 'icpdf', 'gate', NULL, NULL, '1', '1', '1', '1', 'gate_exclude_category', 'gate_exclude_category_like', NULL, ARRAY<VARCHAR(128)>['电路保护器件','硅浪涌保护器'], NULL, 'CP 协调：电路保护/硅浪涌 category 不进 transistor');

INSERT INTO dim.dim_l3_classify_rule (rule_id, clause_group_id, clause_ord, schema_version, data_source, rule_kind, l3_id, l3_cn, phase, rule_priority, enabled, confidence_weight, classify_source_hint, field_code, match_value, match_values, match_map, note)
VALUES ('gate_transistor_icpdf_exclude_cp_v1', '1', '0', 'v1.5.09', 'icpdf', 'gate', NULL, NULL, '1', '1', '1', '1', 'gate_exclude_category2', 'gate_exclude_category2_in', NULL, ARRAY<VARCHAR(128)>['电信保护电路','硅浪涌保护器'], NULL, 'CP 协调：电信保护/硅浪涌 c2 不进 transistor');

INSERT INTO dim.dim_l3_classify_rule (rule_id, clause_group_id, clause_ord, schema_version, data_source, rule_kind, l3_id, l3_cn, phase, rule_priority, enabled, confidence_weight, classify_source_hint, field_code, match_value, match_values, match_map, note)
VALUES ('gate_resistor_icpdf_exclude_cp_v1', '0', '0', 'v1.5.09', 'icpdf', 'gate', NULL, NULL, '1', '1', '1', '1', 'gate_exclude_category', 'gate_exclude_category_like', NULL, ARRAY<VARCHAR(128)>['TVS二极管','保险丝','热熔断路器/开关/保险丝','电路保护器件','硅浪涌保护器'], NULL, 'CP 协调：CP category 白名单不进 resistor');

INSERT INTO dim.dim_l3_classify_rule (rule_id, clause_group_id, clause_ord, schema_version, data_source, rule_kind, l3_id, l3_cn, phase, rule_priority, enabled, confidence_weight, classify_source_hint, field_code, match_value, match_values, match_map, note)
VALUES ('gate_resistor_icpdf_exclude_cp_v1', '1', '0', 'v1.5.09', 'icpdf', 'gate', NULL, NULL, '1', '1', '1', '1', 'gate_exclude_category2', 'gate_exclude_category2_in', NULL, ARRAY<VARCHAR(128)>['电熔丝','断路器','硅浪涌保护器','电信保护电路'], NULL, 'CP 协调：CP category2 白名单不进 resistor');
