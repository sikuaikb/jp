#!/usr/bin/env python3
"""验证 build 脚本抽取逻辑: 对 amplifier/audio_power_amplifier 的 class 结果,
按 build 脚本同款逻辑从 EAV 抽 lead_free/rohs_compliant/lifecycle_status/aec_q_level,
看值分布是否正常 (lead_free 应为 1/0/null, 规范名应有值)。"""
import os
from pathlib import Path
import pymysql
ENV = Path(__file__).resolve().parent / "local.env"
for line in ENV.read_text(encoding="utf-8").splitlines():
    if line.strip().startswith("export "):
        k, _, v = line[7:].partition("=")
        os.environ[k] = v.strip().strip("'").strip('"')
conn = pymysql.connect(host=os.environ["MYSQL_HOST"], port=9030,
    user=os.environ["MYSQL_USER"], password=os.environ["MYSQL_PASSWORD"],
    charset="utf8mb4", cursorclass=pymysql.cursors.DictCursor)
c = conn.cursor()

# 模拟 build: 对 audio_power_amplifier 的 SKU, 抽 lead_free 等
sql = """
SELECT
  MAX(CASE WHEN v.std_attr_code='lead_free' THEN v.value_std_varchar END) AS lead_free,
  MAX(CASE WHEN v.std_attr_code='rohs_compliant' THEN v.value_std_varchar END) AS rohs_compliant,
  MAX(CASE WHEN v.std_attr_code='lifecycle_status' THEN v.value_std_varchar END) AS lifecycle_status,
  MAX(CASE WHEN v.std_attr_code='aec_q_level' THEN v.value_std_varchar END) AS aec_q_level,
  COUNT(*) AS sku_n
FROM (
  SELECT data_source, id FROM dwd.dwd_component_class
  WHERE l2_code='audio_power_amplifier'
) c
LEFT JOIN dwd.dwd_component_attr_std v
  ON v.data_source=c.data_source AND v.id=c.id
  AND v.std_attr_code IN ('lead_free','rohs_compliant','lifecycle_status','aec_q_level')
GROUP BY c.data_source, c.id
"""
c.execute(sql)
rows = c.fetchall()
print(f"audio_power_amplifier SKU 数: {len(rows)}")
from collections import Counter
lf = Counter(str(r["lead_free"]) for r in rows)
rh = Counter(str(r["rohs_compliant"]) for r in rows)
lc = Counter(str(r["lifecycle_status"]) for r in rows)
aq = Counter(str(r["aec_q_level"]) for r in rows)
print(f"\nlead_free 分布: {dict(lf)}")
print(f"rohs_compliant 分布(前5): {dict(list(rh.most_common(5)))}")
print(f"lifecycle_status 分布(前5): {dict(list(lc.most_common(5)))}")
print(f"aec_q_level 分布(前5): {dict(list(aq.most_common(5)))}")

# 关键校验: lead_free 是否仅 1/0/None
bad_lf = [k for k in lf if k not in ("1","0","None")]
print(f"\nlead_free 异常值(非1/0/None): {bad_lf if bad_lf else '无 -> OK'}")

c.close(); conn.close()
