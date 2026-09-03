"""Step 9: 清理 fpga_cpld attr 相关 test 表（classify 已在前一步清理）"""
import pymysql, sys, io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

conn = pymysql.connect(host='192.168.19.21', port=9030, user='rock_admin',
                       password='jE4^mK9%sJ2_vP&7_2026_z!', charset='utf8mb4')
cur = conn.cursor()
L1 = 'fpga_cpld'

tables = [
    f'test_dim.dim_attr_schema_{L1}',
    f'test_dim.dim_attr_extract_rule_{L1}',
    f'test_dwd.dwd_component_attr_std_{L1}',
    f'test_dwd.dwd_component_attr_std_merge_{L1}',
    f'test_dwd.dwd_l2_{L1}_cpld_{L1}',
    f'test_dwd.dwd_l2_{L1}_fpga_{L1}',
    f'test_dwd.dwd_l2_{L1}_cpld_merge',
    f'test_dwd.dwd_l2_{L1}_fpga_merge',
]
for t in tables:
    try:
        cur.execute(f'DROP TABLE IF EXISTS {t}')
        conn.commit()
        print(f'  ✅ DROP {t}')
    except Exception as e:
        print(f'  ⚠️  DROP {t} 失败: {e}')

cur.close(); conn.close()
print('Step 9 cleanup 完成')
