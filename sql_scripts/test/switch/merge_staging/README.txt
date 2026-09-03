switch merge 预备快照（由 export_merge_staging.py 生成）
合 prod 时按 CONTRIB.md Step 5/7 从 test_dim 或本目录 CSV 装载。
勿直接 mysql 导入 prod，需 ALLOW_PROD=1 + 人工确认。
