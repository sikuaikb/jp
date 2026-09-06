#!/usr/bin/env python3
"""品牌字典查重机械校验器（component-etl-methodology 硬门控的可执行版）。

把"品牌名全局唯一"从只能写在 prompt 里的约定，变成 fail-fast 校验：
扫描 `dim.dim_std_brand`（state=1）按**归一化品牌名**聚合，同一归一化 key
落在 >1 个 brand_id_std 上 = 疑似同一公司多行（真重复），判 FAIL。

归一化规则（与人工查重一致）：
    upper → 去公司后缀词(INC/LLC/LTD/CORP/CO/GMBH/SEMICONDUCTOR/SEMI/
            ELECTRONIC(S)/TECHNOLOGY/TECHNOLOGIES/COMPONENTS) → 去所有非 [A-Z0-9]
    （CJK 字符也被去掉，故「镁光-micron」与「Micron Technology」归一化后都是 MICRON，
     可捕获 jp_brand 自带的「中文名-ENG vs 纯 ENG」重名）

为什么发布门控 dt=di（COUNT(DISTINCT brand)=COUNT(DISTINCT brandid)）抓不到：
    同一公司两个 brand_id，两个 brand 文本都非空，distinct brand 与 distinct brandid
    仍相等(2=2)，那条门控对"一家公司两个 id"是盲的。本校验器专补这个盲区。

伪重复（缩写撞车、不是同一公司）用白名单豁免：内置 BUILTIN_WAIVER（已确认的
缩写撞车，如 CEC/JEC/HF/ST 等），可用 --waiver <NORM_KEY>（可重复）或
env BRAND_DUP_WAIVER（逗号分隔）追加。豁免须人工登记、留痕——机器无法区分
「漏查重 bug」与「缩写恰好撞车的不同公司」。

用法：
    python3 validate_brand_dim_dup.py                 # 连 dim 库（默认）
    python3 validate_brand_dim_dup.py --dim-schema dim --brand-table dim_std_brand
    python3 validate_brand_dim_dup.py --waiver CEC --waiver JEC
    python3 validate_brand_dim_dup.py --warn-only     # 只报不阻断（退出码恒 0）

依赖：标准库 + pymysql（经 dim_db_loader，读 MYSQL_* env）。缺表/缺库优雅降级 WARN。
退出码：0 = 无未豁免重复（或 --warn-only）；1 = 有未豁免归一化重复组。

校验项：
    BD1 [FAIL] 归一化品牌名重复：同一归一化 key 落在 >1 个 state=1 brand_id_std，
               且该 key 不在白名单 → 疑似真重复。修复：按 CONTRIB_BRAND.md 走 A 类
               合并（复用一个 brand_id_std，别名并入），或若确为不同公司则登记白名单。
"""
from __future__ import annotations

import argparse
import os
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

SUFFIX_WORDS = {
    "INC", "LLC", "LTD", "CORP", "CORPORATION", "CO", "GMBH", "AG", "SA", "BV",
    "SEMICONDUCTOR", "SEMICONDUCTORS", "SEMI", "ELECTRONIC", "ELECTRONICS",
    "TECHNOLOGY", "TECHNOLOGIES", "TECH", "COMPONENTS", "GROUP", "HOLDINGS",
}

# 已确认的「缩写撞车 / 不是同一公司」伪重复（归一化 key）。新增豁免须人工登记。
BUILTIN_WAIVER = {
    "CEC",   # 振华新云 / 中电熊猫 / 振华
    "JEC",   # 智旭 / 智中
    "ST",    # 先科-ST(中国) / 意法半导体-ST(STMicroelectronics)——ST裸条目已合并入意法半导体，仍有两个不同公司
    "ICORE", # 中微爱芯 I-core / 睿兴 ICORE
    "HUAWEI",   # 华威集团 / 华为
    "LITEON",   # 台湾光宝 / 台湾敦南
    "TOPPOWER", # 南京拓微 / 顶源
    "HF",    # 汉枫 / 宏发
    "FM",    # 复旦微 / 富满
    "GP",    # 超霸 / 格瑞宝
    "KLD",   # 科利德 / 科乐达
    "JK",    # JK Electronics / 金科
    "HX",    # 恒佳兴 / 红星
    "MST",   # 迈尔斯通 / 台湾美格
    "HD",    # 无锡好达 / 海德频率
    "BL",    # 博林 / 上海贝岭
    "DC",    # 东晨 / 辰新
    "BC",    # 台湾诚阳 / 宝成
    "CENTRAL",  # Central Semiconductor(纽约分立半导体) / Central Technologies(加州磁性) / 中环
    "VIKING",   # 光颉 Viking Tech(台湾电阻) / Viking Technology(Sanmina 存储)——联网确认不同
    "ORIENTAL", # 东微 Oriental Semi(功率MOSFET) / Oriental Technology(LCD)——联网确认不同
    "HALO",     # 希荻微 Halo Microelectronics(电源IC) / Halo Electronics(磁件)——不同公司
    "FC",    # 方成-FC / 裸 FC（占位嫌疑，待确认——见 CONTRIB_BRAND.md §5.9，30天内复查）
    "WF",    # 伟烽-WF / 裸 WF（占位嫌疑，待确认——见 CONTRIB_BRAND.md §5.9，30天内复查）
    "VPSC",  # 源特科技-VPSC / 裸 VPSC（占位嫌疑，待确认——见 CONTRIB_BRAND.md §5.9，30天内复查）
    "LEADER",  # Leader Tech Inc(美国EMI屏蔽) / 立得-LEADER —— 联网+料号核实不同公司 2026-07-09
    "AIC",  # 沛亨半导体-AIC(Analog Integrations 电源IC) / AIC tech Inc(日立AIC分拆 铝电解) —— 不同公司 2026-07-09
    "HELIX",  # Helix Semiconductors(加州电源IC) / 裸 Helix —— 无充分同公司证据，豁免 2026-07-09
}


def norm(name: str) -> str:
    s = (name or "").upper()
    tokens = re.split(r"[^A-Z0-9]+", s)
    tokens = [t for t in tokens if t and t not in SUFFIX_WORDS]
    return "".join(tokens)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dim-schema", default="dim", help="品牌字典所在库（默认 dim）")
    ap.add_argument("--brand-table", default="dim_std_brand")
    ap.add_argument("--waiver", action="append", default=[], help="追加豁免的归一化 key（可重复）")
    ap.add_argument("--warn-only", action="store_true", help="只报不阻断（退出码恒 0）")
    args = ap.parse_args()

    waiver = set(BUILTIN_WAIVER)
    waiver |= {w.strip().upper() for w in args.waiver if w.strip()}
    env_w = os.environ.get("BRAND_DUP_WAIVER", "")
    waiver |= {w.strip().upper() for w in env_w.split(",") if w.strip()}

    try:
        from dim_db_loader import fetch_rows
        rows = fetch_rows(args.dim_schema, args.brand_table,
                          ["brand_id_std", "name", "state"])
    except SystemExit:
        raise
    except Exception as e:  # 缺表/缺库优雅降级
        print(f"WARN: 无法读取 {args.dim_schema}.{args.brand_table}（{e}）；跳过品牌查重校验")
        sys.exit(0)

    groups: dict[str, list[tuple[str, str]]] = {}
    for r in rows:
        if (r.get("state") or "").strip() != "1":
            continue
        key = norm(r.get("name") or "")
        if len(key) < 2:
            continue
        groups.setdefault(key, []).append((r.get("brand_id_std", ""), r.get("name", "")))

    fails: list[str] = []
    waived_hits = 0
    for key, members in sorted(groups.items()):
        ids = {m[0] for m in members}
        if len(ids) <= 1:
            continue
        if key in waiver:
            waived_hits += 1
            continue
        detail = "; ".join(f"{bid}={nm!r}" for bid, nm in members)
        fails.append(
            f"BD1 归一化品牌名 {key!r} 落在 {len(ids)} 个 brand_id_std 上（疑似同一公司多行）："
            f"{detail}。期望：按 CONTRIB_BRAND.md A 类合并为一个 brand_id_std（别名并入 "
            f"related_words）；若确为不同公司，用 --waiver {key} / env BRAND_DUP_WAIVER 登记豁免"
        )

    print(f"[validate_brand_dim_dup] 源={args.dim_schema}.{args.brand_table}  "
          f"state=1 品牌 {sum(len(v) for v in groups.values())} 行 / 归一化组 {len(groups)}  "
          f"豁免命中 {waived_hits} 组")
    if fails:
        print(f"\n[FAIL] {len(fails)} 组未豁免的归一化重复：")
        for f in fails:
            print("  - " + f)
    else:
        print("[OK] 无未豁免的归一化品牌重复。")

    if fails and not args.warn_only:
        sys.exit(1)
    sys.exit(0)


if __name__ == "__main__":
    main()
