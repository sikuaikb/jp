#!/usr/bin/env python3
"""classify 专规探查：混合叶子 note_cn 关键词分布。"""
from __future__ import annotations

import os
import re
from collections import Counter
from pathlib import Path

import pymysql

ENV = Path(__file__).resolve().parents[3] / "local.env"
for line in ENV.read_text(encoding="utf-8").splitlines():
    if line.strip().startswith("export "):
        k, _, v = line.strip()[7:].partition("=")
        os.environ[k] = v.strip().strip("'").strip('"')

MIXED = [
    "信号开关，多路复用器，解码器",
    "专用逻辑器件",
    "触发器",
    "缓冲器，驱动器，接收器，收发器",
]

PATTERNS = {
    "mux": re.compile(r"多路复用|复用器|Multiplex", re.I),
    "demux": re.compile(r"多路分解|解复用|Demultiplex", re.I),
    "decoder": re.compile(r"解码器|Decoder", re.I),
    "encoder": re.compile(r"编码器|Encoder", re.I),
    "bus_switch": re.compile(r"总线开关|Bus Switch|模拟开关", re.I),
    "shift_reg": re.compile(r"移位寄存器|Shift Register", re.I),
    "counter": re.compile(r"计数器|Counter|分频", re.I),
    "register": re.compile(r"寄存器|Register|寄存", re.I),
    "flip_flop": re.compile(r"触发器|锁存|Flip|Latch", re.I),
    "adder": re.compile(r"加法器|Adder|全加", re.I),
    "alu": re.compile(r"ALU|算术", re.I),
    "comparator": re.compile(r"比较器|Comparator", re.I),
    "buffer": re.compile(r"缓冲器|Buffer", re.I),
    "transceiver": re.compile(r"收发器|Transceiver", re.I),
    "driver": re.compile(r"驱动器|Driver", re.I),
    "gate": re.compile(r"与门|或门|非门|NAND|NOR|XOR|反相|门 ", re.I),
}

conn = pymysql.connect(
    host=os.environ["MYSQL_HOST"], port=9030,
    user=os.environ["MYSQL_USER"], password=os.environ["MYSQL_PASSWORD"],
    charset="utf8mb4", cursorclass=pymysql.cursors.DictCursor,
)
cur = conn.cursor()

for cat in MIXED:
    cur.execute(
        "SELECT note_cn FROM dwd.dwd_digikey_component_param WHERE category=%s",
        (cat,),
    )
    sig = Counter()
    top = Counter()
    for row in cur.fetchall():
        note = row["note_cn"] or ""
        top[note.split()[0] if note else "(null)"] += 1
        for name, pat in PATTERNS.items():
            if pat.search(note):
                sig[name] += 1
    print(f"\n=== {cat} n={sum(top.values())} ===")
    print("  keywords:", dict(sig.most_common(12)))
    print("  note lead:", top.most_common(8))

# 1:1 leaves quick count
for cat in [
    "门和反相器", "门和反相器 - 多功能，可配置", "比较器",
    "奇偶校验发生器和校验器", "移位寄存器",
]:
    cur.execute("SELECT COUNT(*) n FROM dwd.dwd_digikey_component_param WHERE category=%s", (cat,))
    print(f"\n1:1 {cat}: {cur.fetchone()['n']:,}")

conn.close()
