# logic_ic · 本期不做 / 零命中 L3 说明

| L3 | l3_id | 原因 |
|----|-------|------|
| `level_translator` | 220304 | DigiKey 无独立「电平转换器」叶子；缓冲/收发类目下无专用 note 可稳定专规 |

边界审计中 `零命中 L3·level_translator` 检查项 **PASS（期望 0 误入）**。

若后续 DK 开放独立类目或 note 模式稳定，可新增 `logic_ic_dk_level_translator_v1` 专规。
