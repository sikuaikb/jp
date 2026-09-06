"""
Step 8: 重建 prod EAV + L2 宽表（等价 run_attr_std.sh prod  L1=fpga_cpld）
需要 ALLOW_PROD=1
"""
import os, sys, io, re, pymysql
from pathlib import Path

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

ALLOW_PROD = os.environ.get('ALLOW_PROD', '0')
L1 = 'fpga_cpld'
L2S = ['cpld', 'fpga']
ROOT = Path(__file__).resolve().parents[3]
STD_DIR = ROOT / 'sql_scripts' / '2.attribute_standard'
READY_DIR = STD_DIR / '25_fpga_cpld_ready'

conn = pymysql.connect(host='192.168.19.21', port=9030, user='rock_admin',
                       password='jE4^mK9%sJ2_vP&7_2026_z!', charset='utf8mb4',
                       connect_timeout=60)
cur = conn.cursor()

def q1(sql):
    try: cur.execute(sql); r = cur.fetchone(); return r[0] if r else 0
    except: return 0

def run_sql_file(path, label, replacements=None):
    sql = Path(path).read_text(encoding='utf-8-sig')
    if replacements:
        for old, new in replacements.items():
            sql = sql.replace(old, new)
    stmts = re.split(r';\s*\n', sql)
    ok = 0
    for i, s in enumerate(stmts):
        s = s.strip()
        if not s or len(s) < 5:
            continue
        try:
            cur.execute(s); conn.commit(); ok += 1
        except Exception as e:
            msg = str(e)
            if 'already exist' not in msg.lower():
                print(f'  ⚠️  {label} stmt{i+1}: {msg[:120]}')
    return ok

print('=' * 65)
print(f'prod EAV + L2 重建  L1={L1}（等价 run_attr_std.sh prod）')
print('=' * 65)

if ALLOW_PROD != '1':
    print('\n⚠️  请先设置 $env:ALLOW_PROD="1"')
    cur.close(); conn.close(); sys.exit(0)
print('✅ ALLOW_PROD=1\n')

# ── EAV rebuild ──────────────────────────────────────────────
for src in ['icpdf', 'digikey']:
    eav_path = STD_DIR / f'build_dwd_component_attr_std_{src}.sql'
    print(f'[EAV] {src} ...')
    n = run_sql_file(eav_path, f'EAV {src}')
    print(f'  执行 {n} 条语句')

print()
for src in ['icpdf', 'digikey']:
    n = q1(f"SELECT COUNT(*) FROM dwd.dwd_component_attr_std WHERE data_source='{src}'")
    print(f'  prod EAV [{src}]: {n:,} 行')
n_fpga = q1(f"SELECT COUNT(*) FROM dwd.dwd_component_attr_std WHERE l1_code='{L1}'")
print(f'  prod EAV [fpga_cpld 合计]: {n_fpga:,} 行（baseline: ~125,549）')

# ── L2 rebuild ────────────────────────────────────────────────
for l2 in L2S:
    ddl_path = READY_DIR / f'dwd_l2_{L1}_{l2}.sql'
    bld_path = READY_DIR / f'build_dwd_l2_{L1}_{l2}.sql'
    print(f'\n[L2] {l2} DDL ...')
    n1 = run_sql_file(ddl_path, f'DDL {l2}')
    print(f'  DDL {n1} 条语句')
    print(f'[L2] {l2} build ...')
    n2 = run_sql_file(bld_path, f'build {l2}')
    print(f'  build {n2} 条语句')

# ── 校验 ─────────────────────────────────────────────────────
print('\n[校验] prod L2 宽表:')
for l2 in L2S:
    try:
        cur.execute(f"SELECT data_source, COUNT(*) n FROM dwd.dwd_l2_{L1}_{l2} GROUP BY 1 ORDER BY 1")
        rows = cur.fetchall()
    except Exception as e:
        rows = [('ERR', str(e))]
    total = sum(r[1] for r in rows if isinstance(r[1], int))
    print(f'  dwd_l2_{L1}_{l2}: {dict(rows)} (total={total:,})')

print(f'\n{"="*65}')
print('prod EAV + L2 重建完成！')
cur.close(); conn.close()
