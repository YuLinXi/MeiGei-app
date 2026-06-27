# 预置动作库扩展决策记录

生成日期：2026-06-27

## 胸部第 1 批

结论：仅接受 C7、C8。

接受：

- C7 `MACHINE_DECLINE_CHEST_PRESS`：下斜器械推胸，器械「器械」，分类「胸 / 中下胸」，主动肌 `chest`，协同肌 `deltFront` + `triceps`。
- C8 `DECLINE_HAMMER_CHEST_PRESS`：下斜悍马机推胸，器械「悍马机」，分类「胸 / 中下胸」，主动肌 `chest`，协同肌 `deltFront` + `triceps`。

暂不加入：

- C1 `BB_FLOOR_PRESS`：杠铃地板卧推。
- C2 `DB_FLOOR_PRESS`：哑铃地板卧推。
- C3 `REVERSE_GRIP_BB_BENCH_PRESS`：反握杠铃卧推。
- C4 `REVERSE_GRIP_DB_BENCH_PRESS`：反握哑铃卧推。
- C5 `CABLE_CHEST_PRESS`：绳索推胸。
- C6 `INCLINE_CABLE_CHEST_PRESS`：上斜绳索推胸。

后续回填时仅新增 C7/C8。

## 背部第 1 批

结论：全部接受。

接受：

- B1 `NEUTRAL_GRIP_PULL_UP`：对握引体向上，器械「自重」，分类「背」，主动肌 `lats`，协同肌 `biceps` + `deltRear`。
- B2 `SINGLE_ARM_CABLE_ROW`：单臂绳索划船，器械「绳索」，分类「背」，主动肌 `lats` + `rhomboids`，协同肌 `biceps` + `deltRear`。
- B3 `CHEST_SUPPORTED_T_BAR_ROW`：胸托 T 杠划船，器械「T杠」，分类「背」，主动肌 `lats` + `rhomboids`，协同肌 `biceps` + `deltRear`。
- B4 `CHEST_SUPPORTED_MACHINE_ROW`：胸托器械划船，器械「器械」，分类「背」，主动肌 `lats` + `rhomboids`，协同肌 `biceps` + `deltRear`。
- B5 `MEADOWS_ROW`：梅多斯划船，器械「杠铃」，分类「背」，主动肌 `lats` + `rhomboids`，协同肌 `biceps` + `deltRear`。
- B6 `SEAL_ROW`：海豹划船，器械「杠铃」，分类「背」，主动肌 `lats` + `rhomboids`，协同肌 `biceps` + `deltRear`。
- B7 `MACHINE_PULLOVER`：器械上拉，器械「器械」，分类「背」，主动肌 `lats`，协同肌 `chest` + `triceps`。
- B8 `LANDMINE_ROW`：地雷杆划船，器械「杠铃」，分类「背」，主动肌 `lats` + `rhomboids`，协同肌 `biceps` + `deltRear`。

后续回填时新增 B1-B8。
