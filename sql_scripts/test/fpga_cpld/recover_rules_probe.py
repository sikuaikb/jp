"""从 dwd baseline + param 反推 classify rule 模式"""
import pymysql, sys, io, json
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
conn = pymysql.connect(host='192.168.19.21', port=9030, user='rock_admin',
                       password='jE4^mK9%sJ2_vP&7_2026_z!', charset='utf8mb4')
cur = conn.cursor()

rules = [
 'fpgacpld_p2_cpld_v1','fpgacpld_p2_dk_cpld_v1','fpgacpld_p2_dk_soc_v1',
 'fpgacpld_p2_sram_icpdf_v1','fpgacpld_p3_antifuse_v1','fpgacpld_p3_dk_flash_igloo_v1',
 'fpgacpld_p3_dk_flash_machxo_v1','fpgacpld_p3_dk_flash_max10_v1','fpgacpld_p3_dk_flash_proasic_v1',
 'fpgacpld_p3_dk_sram_crosslink_v1','fpgacpld_p3_dk_sram_cyclone_v1','fpgacpld_p3_dk_sram_ice40_v1',
 'fpgacpld_p3_dk_sram_spartan_v1','fpgacpld_p3_dk_sram_trion_v1','fpgacpld_p3_flash_v1','fpgacpld_p3_sram_loadable_v1',
]

for rid in rules:
    cur.execute("""
    SELECT c.data_source, c.l3_id, c.l3_code, c.matched_value, c.classify_source,
           p.category, p.category2, LEFT(CAST(p.partno AS CHAR),40) partno,
           LEFT(CAST(p.note_cn AS CHAR),80) note_cn
    FROM test_dwd.dwd_component_class_fpga_cpld c
    LEFT JOIN dwd.dwd_icpdf_component_param pi ON c.data_source='icpdf' AND pi.id=c.id
    LEFT JOIN dwd.dwd_digikey_component_param pd ON c.data_source='digikey' AND pd.id=c.id
    LEFT JOIN (
      SELECT 'icpdf' AS data_source, id, category, category2, partno, note_cn FROM dwd.dwd_icpdf_component_param
      UNION ALL
      SELECT 'digikey', id, category, category2, partno, note_cn FROM dwd.dwd_digikey_component_param
    ) p ON p.id=c.id AND p.data_source=c.data_source
    WHERE c.rule_id=%s LIMIT 3
    """, (rid,))
    rows = cur.fetchall()
    if not rows:
        continue
    print(f'\n=== {rid} ===')
    for r in rows:
        print(r)

# gate 类目探查
print('\n=== icpdf gate categories (CPLD/FPGA) ===')
cur.execute("""
SELECT category, category2, COUNT(*) n FROM dwd.dwd_icpdf_component_param
WHERE category REGEXP 'CPLD|FPGA|可编程' OR category2 REGEXP 'CPLD|FPGA|可编程'
GROUP BY 1,2 ORDER BY n DESC LIMIT 15""")
for r in cur.fetchall(): print(r)

print('\n=== digikey gate categories ===')
cur.execute("""
SELECT category, COUNT(*) n FROM dwd.dwd_digikey_component_param
WHERE category REGEXP 'FPGA|CPLD|可编程|单片机'
GROUP BY 1 ORDER BY n DESC LIMIT 15""")
for r in cur.fetchall(): print(r)

cur.close(); conn.close()
