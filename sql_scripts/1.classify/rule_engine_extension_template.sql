/* ============================================================
 * 分类规则引擎 · 扩展模板（纯注释，勿当作可执行迁移脚本）
 *
 * 详细语义见同级 RULE_ENGINE.md。
 *
 * 用法：复制下列片段到 dim_l3_classify_rule 的 INSERT 中，
 *       替换 schema_version / data_source / l3_id / 白名单与谓词；
 *       若引入新的 field_code，必须同步修改
 *       dwd_icpdf_component_class.sql → classify_clause_eval 的 CASE。
 * ============================================================

   ---------- A) Gate ----------
   同一 schema_version + data_source 下通常 1～N 行；
   field_code 多为 category_in / category2_in；match_values 为 ARRAY。

   示例结构：
   ('gate_<l1>_icpdf_v1', 0, 0, '<schema_ver>', 'icpdf', 'gate',
    NULL, NULL,
    1, 1, 1, 1.0000,
    'gate_category', 'category_in', NULL,
    ARRAY<VARCHAR(128)>['品类词1','品类词2'], NULL,
    'gate note'),

   ---------- B) Classify：两组 OR，组内 AND ----------
   单 rule_id、clause_group_id 0 与 1 为两组；
   组 0 两行：(category2_eq) AND (parjson_match_map)。

   ('<rule_id>', 0, 0, '<schema_ver>', 'icpdf', 'classify', '<l3_id>', '<l3_cn>',
    3, 10, 1, 1.0000, 'prajson2_disambig', 'category2_eq', '某category2精确值', NULL, NULL, NULL),
   ('<rule_id>', 0, 1, '<schema_ver>', 'icpdf', 'classify', '<l3_id>', '<l3_cn>',
    3, 10, 1, 1.0000, 'prajson2_disambig', 'parjson_match_map', NULL, NULL,
    map('JSON顶层键名', '%LIKE模式%'), NULL),
   ('<rule_id>', 1, 0, '<schema_ver>', 'icpdf', 'classify', '<l3_id>', '<l3_cn>',
    3, 10, 1, 1.0000, 'alt_path', 'category_eq', '某category精确值', NULL, NULL, NULL),

   ---------- C) Classify：单组单行 category_in ----------
   ('<rule_id>', 0, 0, '<schema_ver>', 'icpdf', 'classify', '<l3_id>', '<l3_cn>',
    2, 20, 1, 1.0000, 'category', 'category_in', NULL,
    ARRAY<VARCHAR(128)>['子类A','子类B'], NULL, NULL),

   ---------- D) 与 dim_l3_classify 对齐检查（运维前手工跑）----------
   SELECT r.rule_id, r.l3_id, r.schema_version, d.l3_code, d.l1_code
   FROM dim.dim_l3_classify_rule r
   LEFT JOIN dim.dim_l3_classify d
     ON d.l3_id = r.l3_id AND d.schema_version = r.schema_version
   WHERE r.rule_kind = 'classify' AND r.enabled = 1
     AND d.l3_id IS NULL;

   ============================================================ */
