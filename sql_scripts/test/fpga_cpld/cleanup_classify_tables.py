"""Step 8: 清理 fpga_cpld classify 相关 test 表（attr 表保留）"""
import pymysql, sys, io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

conn = pymysql.connect(host='192.168.19.21', port=9030, user='rock_admin',
                       password='jE4^mK9%sJ2_vP&7_2026_z!', charset='utf8mb4')
cur = conn.cursor()
L1 = 'fpga_cpld'

tables = [
    f'test_dim.dim_l3_classify_{L1}',
    f'test_dim.dim_l3_classify_rule_{L1}',
    f'test_dwd.dwd_component_class_{L1}',
    f'test_dwd.dwd_component_class_merge_{L1}',
]
for t in tables:
    try:
        cur.execute(f'DROP TABLE IF EXISTS {t}')
        conn.commit()
        print(f'  ✅ DROP {t}')
    except Exception as e:
        print(f'  ⚠️  DROP {t} 失败: {e}')

# bak 表用于安全回滚，不自动删除
print('\n保留 test_dwd.bak_* 备份表以备回滚')
print('保留 test_dim.dim_attr_* / test_dwd.dwd_component_attr_std_* / dwd_l2_* 供后续 attr merge 使用')
cur.close(); conn.close()
print('Step 8 完成')
