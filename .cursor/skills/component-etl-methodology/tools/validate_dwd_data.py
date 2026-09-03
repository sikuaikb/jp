#!/usr/bin/env python3
"""DWD 结果表「数据 + 线上结构」机械校验器（连库 fail-fast）。

前三个校验器校的是 dim 表/DDL（静态定义）；本工具校的是**真正产出到库里的数据**
和**线上表结构**，覆盖三张结果表：
    1) 分类结果   dwd_component_class
    2) EAV 窄表   dwd_component_attr_std
    3) L2 宽表    dwd_l2_*（可自动发现，逐表校验数据 + 公共列结构）

连接所需 env：MYSQL_HOST / MYSQL_PORT / MYSQL_USER / MYSQL_PASSWORD。

用法（prod 全量）：
    python3 validate_dwd_data.py --dwd-schema dwd --dim-schema dim

用法（沙盒，表名带后缀、库为 test_*）：
    python3 validate_dwd_data.py \
        --dwd-schema test_dwd --dim-schema test_dim \
        --class-table dwd_component_class_mcu_mpu_dsp \
        --classify-dim dim_l3_classify_mcu_mpu_dsp \
        --data-source digikey --l1 mcu_mpu_dsp \
        --skip-attr --l2-glob ''   # 没有 EAV/宽表时跳过

退出码：0 = 全部硬门控通过；1 = 有 FAIL；2 = 连接/参数错误。

校验项（FAIL = 硬门控，WARN = 建议项）：
  分类结果 dwd_component_class：
    DC1 [FAIL] PK (data_source,id) 无重复
    DC2 [FAIL] 每行 (l1,l2,l3_code,l3_id) 必须在分类树 dim 中存在且一致（taxonomy 对齐）
    DC3 [FAIL] l2_code 不得以 _base 结尾
    DC4 [WARN] l3_code / l3_id 为 NULL 的行数（未分类不应入表）
    DC5 [WARN] confidence<0.6 的低置信度分类占比（建议人工复核）
  EAV 窄表 dwd_component_attr_std：
    DA1 [FAIL] PK (data_source,id,std_attr_code) 无重复
    DA2 [FAIL] (attr_schema_version, std_attr_code) 必须在 dim_attr_schema 中存在（无 orphan）
    DA3 [FAIL] l2_code 不得以 _base 结尾
    DA4 [WARN] dq_flag 取值越界（非 out_of_range/parse_fail/空）
  L2 宽表 dwd_l2_*（逐表）：
    DL1 [FAIL] 品牌门控：brand_null=0 且 distinct_brand=distinct_brandid
    DL2 [FAIL] l3_code 无 *_unclassified 泄漏
    DL3 [FAIL] l1_code/l2_code 为常量且与表名 dwd_l2_{l1}_{l2} 一致
               （期望表名按「去 _base」后的业务编码推导，不把脏后缀带进建议值）
    DL4 [FAIL] 线上表结构含全部标准头部(8)+尾部(7)公共列
    DL5 [WARN] l3_code 非空但 ext_attributes 为空的比例（L3 参数缺失率）
    DL6 [FAIL] 数据里的 l1_code/l2_code 不得以 _base 结尾（L2 名不要带 base）
    DL7 [FAIL] 线上头部前 8 列顺序 = 标准头部，且 data_source NOT NULL（不得错位/可空）
    DL8 [FAIL] 头部 8 列类型对齐基准（data_source/mpn/brand/l*_code=VARCHAR · id/brandid=BIGINT）
    DL9 [FAIL] 安装方式列必须命名 mounting_style，不得用 mounting_type（SKILL §六-A2）
    DL10[WARN] L2 物理列 100% 空（死列：schema 定义却从未填充，建议补抽取规则或删列）
    DL11[WARN] dq_flags/dq_score/semantic_tags 100% 空（EAV dq 标记未透传 / 语义标签未实现）
    DL12[WARN] L2 数值物理列越界残留：按 dim_attr_schema 的 min_bound/max_bound 复扫，
               宽表里仍存在 <min_bound 或 >max_bound 的值（本应在 EAV 标 out_of_range
               或置 NULL，不应进宽表）；缺 dim 表/缺界列则降级跳过

  分类×属性 跨层交叉（连库 C×A，独立于上面三组，可单独跑）：
    DX1 [FAIL] 分类层产出的每个 L3（dwd_component_class.l3_code，剔除 *_unclassified、非 NULL）
               必须出现在 dim_attr_schema 的 scope_level='l3' scope_code 集合里；
               未覆盖的 L3 注定 ext_attributes 恒空（缺 schema → EAV 无法抽 → 透视无键），
               且 run_test 全绿无人察觉。对应 SKILL §六硬门控 / lessons LL-20260529-12。
               缺表/缺列/无 L3 行一律降级 WARN 跳过。

  注：DL7-DL9 是「线上结构」硬门控（只读 information_schema），与 DDL 静态校验
     validate_l2_widetable.py 的 W1/W3 互补——后者校 DDL 文件，前者校真正建出来的表。
     本工具零外部文件依赖（仅标准库 + pymysql，全部输入经 CLI/env 传入），可脱离
     任何沙盒目录独立运行；是否接进某沙盒 run_test.sh 由该沙盒自行决定。
"""
from __future__ import annotations

import argparse
import os
import sys

import pymysql

HEADER = ["data_source", "id", "mpn", "brand", "brandid", "l1_code", "l2_code", "l3_code"]
TAIL = ["ext_attributes", "semantic_tags", "dq_score", "dq_flags", "source_id", "create_at", "update_at"]


def connect():
    for var in ("MYSQL_HOST", "MYSQL_USER", "MYSQL_PASSWORD"):
        if not os.environ.get(var):
            print(f"ERROR: env {var} not set", file=sys.stderr)
            sys.exit(2)
    return pymysql.connect(
        host=os.environ["MYSQL_HOST"],
        port=int(os.environ.get("MYSQL_PORT", "9030")),
        user=os.environ["MYSQL_USER"],
        password=os.environ["MYSQL_PASSWORD"],
        charset="utf8mb4",
        autocommit=True,
        # StarRocks 4.0.2 集群缺陷：pipeline_dop>1（默认自动）时并行聚合不做最终合并，
        # GROUP BY / 嵌套 GROUP BY 子查询 / SELECT DISTINCT 会返回未合并的 partial（约 ×BUCKETS）。
        # 强制 dop=1 规避，保证 DC1/DA1（PK 唯一）、DX1 等依赖分组的规则结果可信。
        # 详见 sql_scripts/NOTE_starrocks_groupby_bug.md
        init_command="SET pipeline_dop=1",
    )


def scalar(cur, sql: str):
    cur.execute(sql)
    row = cur.fetchone()
    return row[0] if row else None


def table_exists(cur, schema: str, table: str) -> bool:
    cur.execute(
        "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema=%s AND table_name=%s",
        (schema, table),
    )
    return (cur.fetchone()[0] or 0) > 0


def columns(cur, schema: str, table: str) -> set[str]:
    cur.execute(
        "SELECT column_name FROM information_schema.columns WHERE table_schema=%s AND table_name=%s",
        (schema, table),
    )
    return {r[0].lower() for r in cur.fetchall()}


def columns_meta(cur, schema: str, table: str):
    """返回有序列元数据 [(name_lower, data_type_lower, nullable_bool)]（按 ordinal_position）。"""
    cur.execute(
        "SELECT column_name, data_type, is_nullable FROM information_schema.columns "
        "WHERE table_schema=%s AND table_name=%s ORDER BY ordinal_position",
        (schema, table),
    )
    out = []
    for name, dtype, nullable in cur.fetchall():
        out.append((name.lower(), (dtype or "").lower(), str(nullable).upper() == "YES"))
    return out


# 标准头部 8 列的类型契约（对齐 dwd_l2_resistor_fixed_resistor / SKILL §六-B）
HEADER_DBTYPE = {
    "data_source": "varchar",
    "id": "bigint",
    "mpn": "varchar",
    "brand": "varchar",
    "brandid": "bigint",
    "l1_code": "varchar",
    "l2_code": "varchar",
    "l3_code": "varchar",
}


def check_class(cur, fails, warns, dwd, dim, tbl, classify_dim, ds_filter, l1_filter):
    if not table_exists(cur, dwd, tbl):
        warns.append(f"DC 分类结果表 {dwd}.{tbl} 不存在，跳过")
        return
    cols = columns(cur, dwd, tbl)
    full = f"{dwd}.{tbl}"

    # 过滤条件仅在对应列存在时启用，避免引用不存在的列导致 SQL 报错
    filt = []
    if ds_filter and "data_source" in cols:
        filt.append(("data_source", ds_filter))
    if l1_filter and "l1_code" in cols:
        filt.append(("l1_code", l1_filter))

    def wc(alias=""):
        p = (alias + ".") if alias else ""
        return (" AND ".join(f"{p}{c}='{v}'" for c, v in filt)) if filt else ""

    def wclause(alias=""):
        body = wc(alias)
        return (" WHERE " + body) if body else ""

    def andclause(alias=""):
        body = wc(alias)
        return (" AND " + body) if body else ""

    # DC1: PK 唯一
    if {"data_source", "id"} <= cols:
        dup = scalar(cur, f"SELECT COUNT(*) FROM (SELECT data_source,id FROM {full}{wclause()} GROUP BY data_source,id HAVING COUNT(*)>1) x")
        if dup:
            fails.append(f"DC1 {tbl} PK(data_source,id) 重复组数={dup}")
    else:
        warns.append(f"DC1 {tbl} 缺列 data_source/id，跳过 PK 唯一性校验")

    # DC2: taxonomy 对齐（需分类树 dim + 本表四列俱全）
    need_join = {"l3_id", "l1_code", "l2_code", "l3_code"}
    if not (need_join <= cols):
        warns.append(f"DC2 {tbl} 缺列 {sorted(need_join - cols)}，跳过 taxonomy 对齐校验")
    elif table_exists(cur, dim, classify_dim):
        orphan = scalar(cur, f"""
            SELECT COUNT(*) FROM {full} c
            LEFT JOIN {dim}.{classify_dim} d
              ON c.l3_id=d.l3_id AND c.l1_code=d.l1_code AND c.l2_code=d.l2_code AND c.l3_code=d.l3_code
            WHERE d.l3_id IS NULL{andclause('c')}""")
        if orphan:
            fails.append(f"DC2 {tbl} 有 {orphan} 行 (l1_code,l2_code,l3_code,l3_id) 不在分类树 {dim}.{classify_dim} 中")
    else:
        warns.append(f"DC2 分类树 {dim}.{classify_dim} 不存在，跳过 taxonomy 对齐校验")

    # DC3: l2_code 不得带 _base
    if "l2_code" in cols:
        base = scalar(cur, f"SELECT COUNT(*) FROM {full} WHERE l2_code REGEXP '_base$'{andclause()}")
        if base:
            fails.append(f"DC3 {tbl} 有 {base} 行 l2_code 以 _base 结尾（L2 名不要带 base）")
    else:
        warns.append(f"DC3 {tbl} 缺列 l2_code，跳过 _base 校验")

    # DC4: 未分类入表
    null_cols = [c for c in ("l3_code", "l3_id") if c in cols]
    if null_cols:
        cond = " OR ".join(f"{c} IS NULL" for c in null_cols)
        nullc = scalar(cur, f"SELECT COUNT(*) FROM {full} WHERE ({cond}){andclause()}")
        if nullc:
            warns.append(f"DC4 {tbl} 有 {nullc} 行 {'/'.join(null_cols)} 为 NULL（未分类不应入表）")

    # DC5: 低置信度分类占比（建议复核）
    if "confidence" in cols:
        tot = scalar(cur, f"SELECT COUNT(*) FROM {full}{wclause()}") or 0
        lowc = scalar(cur, f"SELECT COUNT(*) FROM {full} WHERE confidence < 0.6{andclause()}") or 0
        if tot and lowc:
            warns.append(f"DC5 {tbl} 有 {lowc} 行 confidence<0.6（占 {round(lowc*100.0/tot,1)}%，建议人工复核低置信度分类）")


def check_attr(cur, fails, warns, dwd, dim, tbl, attr_schema_dim, ds_filter):
    if not table_exists(cur, dwd, tbl):
        warns.append(f"DA EAV 窄表 {dwd}.{tbl} 不存在，跳过")
        return
    cols = columns(cur, dwd, tbl)
    use_ds = bool(ds_filter) and "data_source" in cols
    wc = f" WHERE data_source='{ds_filter}'" if use_ds else ""
    and_ds = f" AND e.data_source='{ds_filter}'" if use_ds else ""
    and_tail = (" AND " + wc[7:]) if wc else ""
    full = f"{dwd}.{tbl}"

    # DA1: PK 唯一
    if {"data_source", "id", "std_attr_code"} <= cols:
        dup = scalar(cur, f"SELECT COUNT(*) FROM (SELECT data_source,id,std_attr_code FROM {full}{wc} GROUP BY data_source,id,std_attr_code HAVING COUNT(*)>1) x")
        if dup:
            fails.append(f"DA1 {tbl} PK(data_source,id,std_attr_code) 重复组数={dup}")
    else:
        warns.append(f"DA1 {tbl} 缺列 data_source/id/std_attr_code，跳过 PK 唯一性校验")

    # DA2: orphan 属性
    need = {"attr_schema_version", "std_attr_code"}
    if not (need <= cols):
        warns.append(f"DA2 {tbl} 缺列 {sorted(need - cols)}，跳过 orphan 校验")
    elif table_exists(cur, dim, attr_schema_dim):
        orphan = scalar(cur, f"""
            SELECT COUNT(*) FROM {full} e
            LEFT JOIN {dim}.{attr_schema_dim} s
              ON s.schema_version=e.attr_schema_version AND s.std_attr_code=e.std_attr_code
            WHERE s.std_attr_code IS NULL{and_ds}""")
        if orphan:
            fails.append(f"DA2 {tbl} 有 {orphan} 行 (attr_schema_version,std_attr_code) 不在 {dim}.{attr_schema_dim} 中（orphan 属性 / std_attr_code 拼写漂移）")
    else:
        warns.append(f"DA2 属性字典 {dim}.{attr_schema_dim} 不存在，跳过 orphan 校验")

    # DA3: l2_code 不得带 _base
    if "l2_code" in cols:
        base = scalar(cur, f"SELECT COUNT(*) FROM {full} WHERE l2_code REGEXP '_base$'{and_tail}")
        if base:
            fails.append(f"DA3 {tbl} 有 {base} 行 l2_code 以 _base 结尾（L2 名不要带 base）")
    else:
        warns.append(f"DA3 {tbl} 缺列 l2_code，跳过 _base 校验")

    # DA4: dq_flag 取值
    if "dq_flag" in cols:
        badflag = scalar(cur, f"SELECT COUNT(*) FROM {full} WHERE dq_flag IS NOT NULL AND dq_flag<>'' AND dq_flag NOT IN ('out_of_range','parse_fail'){and_tail}")
        if badflag:
            warns.append(f"DA4 {tbl} 有 {badflag} 行 dq_flag 取值越界（仅允许 out_of_range/parse_fail/空）")
    else:
        warns.append(f"DA4 {tbl} 缺列 dq_flag，跳过 dq_flag 取值校验")


def check_l3_coverage(cur, fails, warns, dwd, dim, class_tbl, attr_schema_dim, l1_filter, ds_filter):
    """DX1：分类层 L3 ↔ 属性 schema L3 覆盖交叉（连库 C×A）。

    分类层产出的 L3（剔除 *_unclassified、非 NULL）必须全部能在 dim_attr_schema
    scope_level='l3' 找到同名 scope_code；缺一即 FAIL。
    """
    if not table_exists(cur, dwd, class_tbl):
        warns.append(f"DX1 分类结果表 {dwd}.{class_tbl} 不存在，跳过 L3 覆盖交叉校验")
        return
    if not table_exists(cur, dim, attr_schema_dim):
        warns.append(f"DX1 属性字典 {dim}.{attr_schema_dim} 不存在，跳过 L3 覆盖交叉校验")
        return
    ccols = columns(cur, dwd, class_tbl)
    if not ({"l1_code", "l3_code"} <= ccols):
        warns.append(f"DX1 {class_tbl} 缺列 l1_code/l3_code，跳过 L3 覆盖交叉校验")
        return
    acols = columns(cur, dim, attr_schema_dim)
    if not ({"l1_code", "scope_level", "scope_code"} <= acols):
        warns.append(f"DX1 {attr_schema_dim} 缺列 l1_code/scope_level/scope_code，跳过 L3 覆盖交叉校验")
        return

    filt = []
    if l1_filter:
        filt.append(f"c.l1_code='{l1_filter}'")
    if ds_filter and "data_source" in ccols:
        filt.append(f"c.data_source='{ds_filter}'")
    wc = (" AND " + " AND ".join(filt)) if filt else ""
    cur.execute(
        f"SELECT DISTINCT c.l1_code, c.l3_code FROM {dwd}.{class_tbl} c "
        f"WHERE c.l3_code IS NOT NULL AND c.l3_code NOT REGEXP '_unclassified$'{wc}"
    )
    class_l3 = [(r[0], r[1]) for r in cur.fetchall()]
    if not class_l3:
        warns.append(f"DX1 {class_tbl} 无「已分类 L3」行（按当前过滤），跳过 L3 覆盖交叉校验")
        return

    afilt = f" AND l1_code='{l1_filter}'" if l1_filter else ""
    cur.execute(
        f"SELECT DISTINCT l1_code, scope_code FROM {dim}.{attr_schema_dim} "
        f"WHERE scope_level='l3'{afilt}"
    )
    schema_l3 = {(r[0], r[1]) for r in cur.fetchall()}

    missing = sorted((l1, l3) for (l1, l3) in class_l3 if (l1, l3) not in schema_l3)
    if missing:
        detail = ", ".join(f"{l1}/{l3}" for l1, l3 in missing)
        fails.append(
            f"DX1 分类层产出 {len(missing)} 个 L3 未被属性字典 {dim}.{attr_schema_dim} 的 "
            f"scope_level='l3' 覆盖：[{detail}]；这些 L3 的 ext_attributes 注定恒空"
            f"（缺 schema 定义 → EAV 抽不出 → 宽表透视无键）。"
            f"修复：在 dim_attr_schema 为每个缺失 L3 补 scope_level='l3', scope_code=该 l3_code 的属性行"
        )


def discover_l2(cur, dwd: str) -> list[str]:
    cur.execute(
        "SELECT table_name FROM information_schema.tables WHERE table_schema=%s AND table_name LIKE 'dwd\\_l2\\_%%' ORDER BY table_name",
        (dwd,),
    )
    return [r[0] for r in cur.fetchall()]


def check_l2(cur, fails, warns, dwd, tbl, ds_filter, dim=None, attr_schema_dim=None):
    full = f"{dwd}.{tbl}"
    meta = columns_meta(cur, dwd, tbl)
    cols = {m[0] for m in meta}
    order = [m[0] for m in meta]
    type_by = {m[0]: m[1] for m in meta}
    null_by = {m[0]: m[2] for m in meta}
    wc = f" WHERE data_source='{ds_filter}'" if ds_filter else ""

    # DL4 结构：公共列齐全
    miss_h = [c for c in HEADER if c not in cols]
    miss_t = [c for c in TAIL if c not in cols]
    if miss_h or miss_t:
        fails.append(f"DL4 {tbl} 线上结构缺公共列 头部缺{miss_h} 尾部缺{miss_t}")

    # DL7 线上头部前 8 列顺序 + data_source 位置/NOT NULL（仅头部齐全时判定）
    if set(HEADER) <= cols:
        first8 = order[:8]
        if first8 != HEADER:
            fails.append(f"DL7 {tbl} 线上头部前 8 列顺序应为 {HEADER}，实测 {first8}")
        if null_by.get("data_source", True):
            fails.append(f"DL7 {tbl} data_source 必须 NOT NULL 且位于头部首列（线上为可空 / 错位）")

    # DL8 头部列类型对齐基准（dwd_l2_resistor_fixed_resistor）
    for c, want in HEADER_DBTYPE.items():
        if c in type_by and type_by[c] != want:
            fails.append(f"DL8 {tbl} 头部列 {c} 类型应为 {want.upper()}，实测 {type_by[c].upper()}")

    # DL9 封装/安装方式标准列名：必须用 mounting_style，不得用 mounting_type（SKILL §六-A2）
    if "mounting_type" in cols:
        fails.append(f"DL9 {tbl} 含非标列 mounting_type，安装方式标准列名应为 mounting_style（小写受控词表 smd/through_hole/...）")

    if {"brand", "brandid"} <= cols:
        row = None
        cur.execute(f"""
            SELECT
              SUM(CASE WHEN brand IS NULL THEN 1 ELSE 0 END) AS brand_null,
              COUNT(DISTINCT brand) AS db, COUNT(DISTINCT brandid) AS dbi, COUNT(*) AS tot
            FROM {full}{wc}""")
        row = cur.fetchone()
        if row and row[3]:
            brand_null, db, dbi, tot = row
            if brand_null and brand_null > 0:
                fails.append(f"DL1 {tbl} 品牌门控失败：brand_null={brand_null}（必须=0）")
            if db != dbi:
                fails.append(f"DL1 {tbl} 品牌门控失败：distinct_brand={db} ≠ distinct_brandid={dbi}")

    if "l3_code" in cols:
        leak = scalar(cur, f"SELECT COUNT(*) FROM {full} WHERE l3_code REGEXP '_unclassified$'{(' AND ' + wc[7:]) if wc else ''}")
        if leak:
            fails.append(f"DL2 {tbl} 有 {leak} 行 l3_code 为 *_unclassified（不应进宽表）")

    if {"l1_code", "l2_code"} <= cols:
        d_l1 = scalar(cur, f"SELECT COUNT(DISTINCT l1_code) FROM {full}{wc}")
        d_l2 = scalar(cur, f"SELECT COUNT(DISTINCT l2_code) FROM {full}{wc}")
        if (d_l1 or 0) > 1 or (d_l2 or 0) > 1:
            fails.append(f"DL3 {tbl} l1_code/l2_code 非常量 (distinct l1={d_l1}, l2={d_l2})")
        elif d_l1 == 1 and d_l2 == 1:
            v_l1 = scalar(cur, f"SELECT MAX(l1_code) FROM {full}{wc}") or ""
            v_l2 = scalar(cur, f"SELECT MAX(l2_code) FROM {full}{wc}") or ""
            # DL6: 数据里的 l1_code/l2_code 不得带 _base
            if v_l1.endswith("_base") or v_l2.endswith("_base"):
                fails.append(f"DL6 {tbl} 数据 l1_code/l2_code 带 _base（l1={v_l1} l2={v_l2}）；L2 名不要带 base")
            # 期望表名按「去掉 _base」后的业务编码推导，避免把脏后缀带进建议值
            base_l1 = v_l1[:-5] if v_l1.endswith("_base") else v_l1
            base_l2 = v_l2[:-5] if v_l2.endswith("_base") else v_l2
            want = f"dwd_l2_{base_l1}_{base_l2}"
            if tbl != want and not tbl.startswith(want):
                suffix = "（已去除 _base）" if (v_l1 != base_l1 or v_l2 != base_l2) else ""
                fails.append(f"DL3 {tbl} 表名与数据不一致：数据 l1={v_l1} l2={v_l2} → 期望表名 {want}{suffix}")

    if {"l3_code", "ext_attributes"} <= cols:
        tot = scalar(cur, f"SELECT COUNT(*) FROM {full} WHERE l3_code IS NOT NULL{(' AND ' + wc[7:]) if wc else ''}")
        miss = scalar(cur, f"SELECT COUNT(*) FROM {full} WHERE l3_code IS NOT NULL AND ext_attributes IS NULL{(' AND ' + wc[7:]) if wc else ''}")
        if tot and miss and miss > 0:
            warns.append(f"DL5 {tbl} L3 参数缺失率 {round(miss*100.0/tot,1)}%（{miss}/{tot} 行 l3_code 非空但 ext_attributes 空）")

    # DL10 死列（L2 物理列 100% 空）+ DL11 质量/语义列 100% 空（合并一次扫描）
    phys = [m[0] for m in meta if m[0] not in HEADER and m[0] not in TAIL]
    reserved = [c for c in ("dq_flags", "dq_score", "semantic_tags") if c in cols]
    scan_cols = phys + reserved
    if scan_cols:
        sel = ",".join(f"SUM(CASE WHEN `{c}` IS NOT NULL THEN 1 ELSE 0 END)" for c in scan_cols)
        cur.execute(f"SELECT COUNT(*),{sel} FROM {full}{wc}")
        r = cur.fetchone()
        tot = (r[0] or 0) if r else 0
        if tot:
            nonnull = {scan_cols[i]: (r[1 + i] or 0) for i in range(len(scan_cols))}
            dead = [c for c in phys if nonnull[c] == 0]
            if dead:
                warns.append(f"DL10 {tbl} 死列（100% 空，schema 定义却从未填充，建议补抽取规则或删列）: {dead}")
            empty_res = [c for c in reserved if nonnull[c] == 0]
            if empty_res:
                warns.append(f"DL11 {tbl} 质量/语义列 100% 空（EAV 的 dq 标记未透传 / semantic_tags 未实现）: {empty_res}")

    # DL12 数值物理列越界残留：按 dim_attr_schema 的 min_bound/max_bound 复扫宽表
    if dim and attr_schema_dim and "l1_code" in cols:
        v_l1 = scalar(cur, f"SELECT MAX(l1_code) FROM {full}{wc}") or ""
        v_l1 = v_l1[:-5] if v_l1.endswith("_base") else v_l1  # 去 _base，对齐 dim 业务编码
        if v_l1 and table_exists(cur, dim, attr_schema_dim):
            acols = columns(cur, dim, attr_schema_dim)
            need = {"l1_code", "std_attr_code", "db_type", "min_bound", "max_bound"}
            if need <= acols:
                # 同一 std_attr_code 跨 scope 可能有多条界，按列聚合取「最宽区间」
                # （min 取最小、max 取最大），只标真正越出所有定义区间的值，避免重复扫描误报
                cur.execute(
                    f"SELECT LOWER(std_attr_code),MIN(min_bound),MAX(max_bound) FROM {dim}.{attr_schema_dim} "
                    f"WHERE l1_code=%s AND UPPER(db_type) IN ('DOUBLE','INT','BIGINT') "
                    f"AND (min_bound IS NOT NULL OR max_bound IS NOT NULL) "
                    f"GROUP BY LOWER(std_attr_code)",
                    (v_l1,),
                )
                bounds = [(c, mn, mx) for c, mn, mx in cur.fetchall()]
                for code, mn, mx in bounds:
                    if code not in cols:  # 只扫 L2 物理列；L3 在 ext_attributes 里不在此查
                        continue
                    conds = []
                    if mn is not None:
                        conds.append(f"`{code}` < {mn}")
                    if mx is not None:
                        conds.append(f"`{code}` > {mx}")
                    if not conds:
                        continue
                    cond = " OR ".join(conds)
                    bad = scalar(cur, f"SELECT COUNT(*) FROM {full} WHERE ({cond}){(' AND ' + wc[7:]) if wc else ''}")
                    if bad:
                        warns.append(
                            f"DL12 {tbl} 列 {code} 有 {bad} 行越界 "
                            f"[min_bound={mn if mn is not None else 'NULL'},max_bound={mx if mx is not None else 'NULL'}]"
                            f"（区间来自 {dim}.{attr_schema_dim}；越界值本应在 EAV 标 out_of_range 或置 NULL，不应进宽表）"
                        )
            else:
                warns.append(f"DL12 属性字典 {dim}.{attr_schema_dim} 缺列 {sorted(need - acols)}，跳过越界复扫")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dwd-schema", default="dwd")
    ap.add_argument("--dim-schema", default="dim")
    ap.add_argument("--class-table", default="dwd_component_class")
    ap.add_argument("--attr-table", default="dwd_component_attr_std")
    ap.add_argument("--classify-dim", default="dim_l3_classify")
    ap.add_argument("--attr-schema-dim", default="dim_attr_schema")
    ap.add_argument("--data-source")
    ap.add_argument("--l1")
    ap.add_argument("--l2-table", action="append", default=[], help="显式指定 L2 宽表（可重复）；不传则自动发现 dwd_l2_*")
    ap.add_argument("--l2-glob", default="auto", help="auto=自动发现；''=不校验任何 L2 宽表")
    ap.add_argument("--skip-class", action="store_true")
    ap.add_argument("--skip-attr", action="store_true")
    ap.add_argument("--skip-l2", action="store_true")
    ap.add_argument("--skip-l3cov", action="store_true", help="跳过 DX1 分类×属性 L3 覆盖交叉校验")
    args = ap.parse_args()

    conn = connect()
    fails: list[str] = []
    warns: list[str] = []
    with conn.cursor() as cur:
        if not args.skip_class:
            check_class(cur, fails, warns, args.dwd_schema, args.dim_schema, args.class_table,
                        args.classify_dim, args.data_source, args.l1)
        if not args.skip_attr:
            check_attr(cur, fails, warns, args.dwd_schema, args.dim_schema, args.attr_table,
                       args.attr_schema_dim, args.data_source)
        if not args.skip_l3cov:
            check_l3_coverage(cur, fails, warns, args.dwd_schema, args.dim_schema, args.class_table,
                              args.attr_schema_dim, args.l1, args.data_source)
        if not args.skip_l2:
            l2_tables = args.l2_table
            if not l2_tables and args.l2_glob == "auto":
                l2_tables = discover_l2(cur, args.dwd_schema)
            elif args.l2_glob == "":
                l2_tables = []
            if not l2_tables:
                warns.append("L2 未发现/未指定任何 dwd_l2_* 宽表，跳过")
            for t in l2_tables:
                check_l2(cur, fails, warns, args.dwd_schema, t, args.data_source,
                         args.dim_schema, args.attr_schema_dim)
    conn.close()

    for w in warns:
        print(f"WARN  {w}")
    for f in fails:
        print(f"FAIL  {f}")
    if fails:
        print(f"\nDWD 数据校验未通过：{len(fails)} 个硬门控失败，{len(warns)} 个警告")
        sys.exit(1)
    print(f"DWD 数据校验通过：硬门控 OK（{len(warns)} 个警告）")
    sys.exit(0)


if __name__ == "__main__":
    main()
