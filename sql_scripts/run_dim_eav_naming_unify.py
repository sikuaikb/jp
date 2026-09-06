#!/usr/bin/env python3
"""dim/EAV 命名统一 - DB 部分 (PK 安全版)。
std_attr_code 是 PK 列，StarRocks 禁止 UPDATE PK，改用 DELETE+INSERT。
策略: 先 INSERT 规范名行(从 old 行复制改 code) -> 再 DELETE old 行。
dim_attr_schema: 先删 6 重叠行(避免 INSERT 规范名时 PK 冲突) -> INSERT -> DELETE old。
EAV: 同法，但需注意 INSERT 规范名时若同 SKU 已有规范名会 PK 冲突
      (探查确认 SKU 级重叠=0，故安全)。"""
import os, time
from pathlib import Path
import pymysql

ENV = Path(__file__).resolve().parent / "local.env"
for line in ENV.read_text(encoding="utf-8").splitlines():
    if line.strip().startswith("export "):
        k, _, v = line[7:].partition("=")
        os.environ[k] = v.strip().strip("'").strip('"')

conn = pymysql.connect(host=os.environ["MYSQL_HOST"], port=9030,
    user=os.environ["MYSQL_USER"], password=os.environ["MYSQL_PASSWORD"],
    charset="utf8mb4", cursorclass=pymysql.cursors.DictCursor, autocommit=True)
c = conn.cursor()

ALIAS = {
    "ro_hs_compliant": "rohs_compliant",
    "life_cycle_status": "lifecycle_status",
    "mounting_type": "mounting_style",
    "aec_qualified": "aec_q_level",
}

def cnt(table, code):
    c.execute(f"SELECT COUNT(*) n FROM {table} WHERE std_attr_code=%s", (code,))
    return c.fetchone()["n"]

def cols_of(table):
    c.execute(f"SHOW COLUMNS FROM {table}")
    return [r["Field"] for r in c.fetchall()]

# ── 1. dim.dim_std_component_attr: DELETE+INSERT (3 个改名) ──
print("=== 1. dim.dim_std_component_attr (PK: schema_version,l1_code,l2_code,std_attr_code) ===")
std_cols = cols_of("dim.dim_std_component_attr")
std_col_list = ",".join(f"`{x}`" for x in std_cols)
# std_attr_code 在列中位置
for old, new in ALIAS.items():
    if old == "aec_qualified":
        continue
    before = cnt("dim.dim_std_component_attr", old)
    # INSERT 规范名行：复制 old 行，std_attr_code 替换为 new
    select_expr = ",".join(f"'{new}'" if x == "std_attr_code" else f"`{x}`" for x in std_cols)
    c.execute(f"INSERT INTO dim.dim_std_component_attr ({std_col_list}) SELECT {select_expr} FROM dim.dim_std_component_attr WHERE std_attr_code=%s", (old,))
    ins = c.rowcount
    c.execute("DELETE FROM dim.dim_std_component_attr WHERE std_attr_code=%s", (old,))
    dele = c.rowcount
    print(f"  {old}({before}) -> {new}: insert={ins} delete={dele} old残留={cnt('dim.dim_std_component_attr', old)} new={cnt('dim.dim_std_component_attr', new)}")

# ── 2. dim.dim_attr_schema: 删 6 重叠 + DELETE+INSERT ──
print("\n=== 2. dim.dim_attr_schema (PK: schema_version,l1_code,scope_level,scope_code,std_attr_code) ===")
# 先删重叠行：old 行其 (schema_version,l1,scope_level,scope_code) 已有 new 行
for old, new in ALIAS.items():
    c.execute("""
        DELETE FROM dim.dim_attr_schema
        WHERE std_attr_code=%s
          AND (schema_version, l1_code, scope_level, scope_code) IN (
            SELECT schema_version, l1_code, scope_level, scope_code FROM dim.dim_attr_schema WHERE std_attr_code=%s
          )
    """, (old, new))
    print(f"  删 {old} 与 {new} 重叠行: affected={c.rowcount}")

sch_cols = cols_of("dim.dim_attr_schema")
sch_col_list = ",".join(f"`{x}`" for x in sch_cols)
for old, new in ALIAS.items():
    before = cnt("dim.dim_attr_schema", old)
    if before == 0:
        continue
    select_expr = ",".join(f"'{new}'" if x == "std_attr_code" else f"`{x}`" for x in sch_cols)
    c.execute(f"INSERT INTO dim.dim_attr_schema ({sch_col_list}) SELECT {select_expr} FROM dim.dim_attr_schema WHERE std_attr_code=%s", (old,))
    ins = c.rowcount
    c.execute("DELETE FROM dim.dim_attr_schema WHERE std_attr_code=%s", (old,))
    dele = c.rowcount
    print(f"  {old}({before}) -> {new}: insert={ins} delete={dele} old残留={cnt('dim.dim_attr_schema', old)} new={cnt('dim.dim_attr_schema', new)}")

# ── 3. dim.dim_attr_extract_rule: PK=extract_rule_id，std_attr_code 非 PK，可直接 UPDATE ──
print("\n=== 3. dim.dim_attr_extract_rule (PK: extract_rule_id) ===")
for old, new in ALIAS.items():
    before = cnt("dim.dim_attr_extract_rule", old)
    if before == 0:
        continue
    c.execute("UPDATE dim.dim_attr_extract_rule SET std_attr_code=%s WHERE std_attr_code=%s", (new, old))
    print(f"  {old}({before}) -> {new}: affected={c.rowcount} old残留={cnt('dim.dim_attr_extract_rule', old)}")

# ── 4. EAV: PK=(data_source,id,std_attr_code)，需 DELETE+INSERT ──
print("\n=== 4. dwd.dwd_component_attr_std (EAV, PK: data_source,id,std_attr_code) ===")
eav_cols = cols_of("dwd.dwd_component_attr_std")
eav_col_list = ",".join(f"`{x}`" for x in eav_cols)
for old, new in ALIAS.items():
    before = cnt("dwd.dwd_component_attr_std", old)
    if before == 0:
        continue
    t0 = time.time()
    select_expr = ",".join(f"'{new}'" if x == "std_attr_code" else f"`{x}`" for x in eav_cols)
    c.execute(f"INSERT INTO dwd.dwd_component_attr_std ({eav_col_list}) SELECT {select_expr} FROM dwd.dwd_component_attr_std WHERE std_attr_code=%s", (old,))
    ins = c.rowcount
    c.execute("DELETE FROM dwd.dwd_component_attr_std WHERE std_attr_code=%s", (old,))
    dele = c.rowcount
    dt = time.time() - t0
    print(f"  {old}({before:,}) -> {new}: insert={ins:,} delete={dele:,} old残留={cnt('dwd.dwd_component_attr_std', old)} new={cnt('dwd.dwd_component_attr_std', new):,} ({dt:.1f}s)")

# ── 5. 校验 ──
print("\n=== 5. 校验旧码残留 ===")
tables = ["dim.dim_std_component_attr", "dim.dim_attr_schema",
          "dim.dim_attr_extract_rule", "dwd.dwd_component_attr_std"]
total = 0
for t in tables:
    for old in ALIAS:
        n = cnt(t, old)
        if n:
            print(f"  {t} 残留 {old}: {n}")
            total += n
print(f"  总残留: {total}  {'OK' if total == 0 else 'FAIL'}")
c.close(); conn.close()
