#!/usr/bin/env python3
"""验证 amplifier/audio_power_amplifier 的 rohs_compliant 抽取 (归一后应为 1/0/None)。"""
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
c.execute("""
SELECT
  MAX(CASE WHEN v.std_attr_code='rohs_compliant' THEN v.value_std_varchar END) AS rohs_compliant,
  MAX(CASE WHEN v.std_attr_code='lead_free' THEN v.value_std_varchar END) AS lead_free
FROM (SELECT data_source, id FROM dwd.dwd_component_class WHERE l2_code='audio_power_amplifier') cls
LEFT JOIN dwd.dwd_component_attr_std v
  ON v.data_source=cls.data_source AND v.id=cls.id
  AND v.std_attr_code IN ('rohs_compliant','lead_free')
GROUP BY cls.data_source, cls.id
""")
from collections import Counter
rows = c.fetchall()
rh = Counter(str(r["rohs_compliant"]) for r in rows)
lf = Counter(str(r["lead_free"]) for r in rows)
print(f"SKU 数: {len(rows)}")
print(f"rohs_compliant 分布: {dict(rh)}")
print(f"lead_free 分布: {dict(lf)}")
bad = [k for k in rh if k not in ("1","0","None")]
print(f"rohs_compliant 异常值: {bad if bad else '无 -> OK'}")
c.close(); conn.close()
