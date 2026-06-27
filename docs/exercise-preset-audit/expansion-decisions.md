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

## 肩部第 1 批

结论：接受 S1、S2、S3、S4、S5、S8。

接受：

- S1 `SEATED_DB_LATERAL_RAISE`：坐姿哑铃侧平举，器械「哑铃」，分类「肩 / 中束」，主动肌 `deltSide`。
- S2 `INCLINE_DB_LATERAL_RAISE`：上斜哑铃侧平举，器械「哑铃」，分类「肩 / 中束」，主动肌 `deltSide`。
- S3 `SINGLE_ARM_DB_LATERAL_RAISE`：单臂哑铃侧平举，器械「哑铃」，分类「肩 / 中束」，主动肌 `deltSide`。
- S4：不新增新 code，现有 `DB_OVERHEAD_PRESS` 展示名由「哑铃推肩」改为「坐姿哑铃推肩」，肌群保持主动肌 `deltFront`，协同肌 `triceps` + `deltSide`。
- S5 `STANDING_DB_SHOULDER_PRESS`：站姿哑铃推肩，器械「哑铃」，分类「肩 / 前束」，主动肌 `deltFront`，协同肌 `triceps` + `deltSide`。
- S8 `INCLINE_DB_REAR_DELT_FLY`：上斜哑铃后束飞鸟，器械「哑铃」，分类「肩 / 后束」，主动肌 `deltRear`，协同肌 `traps` + `rhomboids`。

暂不加入：

- S6 `SINGLE_ARM_DB_SHOULDER_PRESS`：单臂哑铃推举。
- S7 `CABLE_REAR_DELT_FLY`：绳索后束飞鸟。
- S9 `CABLE_EXTERNAL_ROTATION`：绳索外旋。
- S10 `BAND_EXTERNAL_ROTATION`：弹力带外旋。
- S11 `PRONE_Y_RAISE`：俯身 Y 提举。
- S12 `PUSH_PRESS`：杠铃推举借力推。

后续回填时新增 S1/S2/S3/S5/S8，并重命名现有 `DB_OVERHEAD_PRESS` 为「坐姿哑铃推肩」。

## 手臂第 1 批

结论：仅接受 A2。

接受：

- A2 `SINGLE_ARM_CABLE_CURL`：单臂绳索弯举，器械「绳索」，分类「手臂」，主动肌 `biceps`。

暂不加入：

- A1 `BAYESIAN_CABLE_CURL`：贝叶斯绳索弯举。
- A3 `CABLE_HAMMER_CURL`：绳索锤式弯举。
- A4 `MACHINE_PREACHER_CURL`：器械牧师凳弯举。
- A5 `INCLINE_CABLE_CURL`：坐姿上斜绳索弯举。
- A6 `REVERSE_GRIP_CABLE_PUSHDOWN`：反握绳索下压。
- A7 `SINGLE_ARM_REVERSE_GRIP_PUSHDOWN`：单臂反握绳索下压。
- A8 `SINGLE_ARM_CABLE_OVERHEAD_EXT`：单臂绳索过顶臂屈伸。
- A9 `ROPE_OVERHEAD_TRICEP_EXT`：绳柄过顶臂屈伸。
- A10 `SEATED_DB_OVERHEAD_TRICEP_EXT`：坐姿哑铃过顶臂屈伸。
- A11 `SINGLE_ARM_DB_OVERHEAD_TRICEP_EXT`：单臂哑铃过顶臂屈伸。
- A12 `MACHINE_TRICEP_PUSHDOWN`：器械三头下压。

后续回填时仅新增 A2。

## 腿部第 1 批

结论：仅接受 L3、L4。

接受：

- L3 `SMITH_LUNGE`：史密斯箭步蹲，器械「史密斯」，分类「腿」，主动肌 `quads` + `glutes`，协同肌 `adductors` + `hams`。
- L4 `SMITH_BULGARIAN_SPLIT_SQUAT`：史密斯保加利亚分腿蹲，器械「史密斯」，分类「腿」，主动肌 `quads` + `glutes`，协同肌 `adductors` + `hams`。

暂不加入：

- L1 `REVERSE_LUNGE`：反向箭步蹲。
- L2 `LATERAL_LUNGE`：侧弓步。
- L5 `NORDIC_CURL`：北欧腿弯举。
- L6 `GLUTE_HAM_RAISE`：臀腿挺。
- L7 `DB_LEG_CURL`：哑铃腿弯举。
- L8 `SMITH_FRONT_FOOT_SQUAT`：史密斯深蹲（脚前移）。
- L9 `SMITH_CALF_RAISE`：史密斯提踵。
- L10 `LEG_PRESS_CALF_RAISE`：腿举机提踵。
- L11 `SINGLE_LEG_SEATED_LEG_CURL`：坐姿单腿腿弯举。
- L12 `SINGLE_LEG_LEG_PRESS`：单腿腿举。

后续回填时仅新增 L3/L4。

## 臀部第 1 批

结论：接受 G1、G5、G8、G9。

接受：

- G1 `SMITH_HIP_THRUST`：史密斯臀推，器械「史密斯」，分类「臀」，主动肌 `glutes`，协同肌 `hams`。
- G5 `KB_DEADLIFT`：壶铃硬拉，器械「壶铃」，分类「臀」，主动肌 `glutes` + `hams`，协同肌 `lowerBack`。
- G8 `CLAMSHELL`：蚌式开合，器械「自重」，分类「臀」，主动肌 `gluteMed`，协同肌 `glutes`。
- G9 `FROG_PUMP`：青蛙泵，器械「自重」，分类「臀」，主动肌 `glutes`。

暂不加入：

- G2 `SINGLE_LEG_GLUTE_BRIDGE`：单腿臀桥。
- G3 `SINGLE_LEG_HIP_THRUST`：单腿臀推。
- G4 `CABLE_PULL_THROUGH`：绳索臀桥/拉穿。
- G6 `CABLE_HIP_ABDUCTION`：绳索髋外展。
- G7 `STANDING_MACHINE_HIP_ABDUCTION`：站姿器械髋外展。
- G10 `PRONE_HIP_EXTENSION`：俯卧髋伸展。

后续回填时新增 G1/G5/G8/G9。

## 核心第 1 批

结论：仅接受 K2、K3。

接受：

- K2 `MACHINE_CRUNCH`：器械卷腹，器械「器械」，分类「核心」，主动肌 `abs`。
- K3 `WEIGHTED_CRUNCH`：负重卷腹，器械「其他」，分类「核心」，主动肌 `abs`。

暂不加入：

- K1 `PALLOF_PRESS`：Pallof Press。
- K4 `CAPTAIN_CHAIR_LEG_RAISE`：船长椅举腿。
- K5 `HANGING_KNEE_RAISE`：悬挂屈膝举腿。
- K6 `BICYCLE_CRUNCH`：空中自行车卷腹。
- K7 `MOUNTAIN_CLIMBER`：登山跑。
- K8 `DB_SIDE_BEND`：哑铃侧屈。
- K9 `CABLE_SIDE_BEND`：绳索侧屈。
- K10 `V_UP`：V 字卷腹。
- K11 `HOLLOW_HOLD`：Hollow Hold。
- K12 `DRAGON_FLAG`：龙旗。

后续回填时仅新增 K2/K3。

## 功能性第 1 批

结论：接受 F1、F2、F3、F9。

接受：

- F1 `BARBELL_POWER_CLEAN`：杠铃高翻，器械「杠铃」，分类「功能性」，子分类「爆发奥举」，主动肌 `traps` + `glutes` + `hams`，协同肌 `lowerBack` + `quads` + `forearms`。
- F2 `BARBELL_CLEAN_AND_JERK`：杠铃挺举，器械「杠铃」，分类「功能性」，子分类「爆发奥举」，主动肌 `glutes` + `quads` + `deltFront`，协同肌 `hams` + `traps` + `triceps`。
- F3 `BARBELL_SNATCH`：杠铃抓举，器械「杠铃」，分类「功能性」，子分类「爆发奥举」，主动肌 `glutes` + `hams` + `traps` + `deltFront`，协同肌 `lowerBack` + `quads`。
- F9 `MED_BALL_SLAM`：药球砸地，器械「其他」，分类「功能性」，子分类「爆发奥举」，主动肌 `abs` + `lats` + `deltFront`，协同肌 `glutes` + `quads`。

暂不加入：

- F4 `DB_FARMER_CARRY`：哑铃农夫行走。
- F5 `KB_FARMER_CARRY`：壶铃农夫行走。
- F6 `SUITCASE_CARRY`：单手农夫行走。
- F7 `SLED_PUSH`：雪橇推。
- F8 `SLED_PULL`：雪橇拉。
- F10 `KB_CLEAN`：壶铃高翻。
- F11 `KB_SNATCH`：壶铃抓举。
- F12 `KB_CLEAN_AND_PRESS`：壶铃推举。

后续回填时新增 F1/F2/F3/F9。

## 热身拉伸第 1 批

结论：全部接受。

接受：

- M1 `BAND_CHEST_SHOULDER_STRETCH`：弹力带拉伸胸肩，器械「弹力带」，分类「热身拉伸」，子分类「动态热身」。
- M2 `SCAPULAR_PUSH_UP`：肩胛俯卧撑，器械「自重」，分类「热身拉伸」，子分类「动态热身」。
- M3 `BAND_FACE_PULL`：弹力带面拉，器械「弹力带」，分类「热身拉伸」，子分类「动态热身」。
- M4 `HIP_FLEXOR_STRETCH`：髋屈肌拉伸，器械「自重」，分类「热身拉伸」，子分类「静态拉伸」。
- M5 `HAMSTRING_STRETCH`：腘绳肌拉伸，器械「自重」，分类「热身拉伸」，子分类「静态拉伸」。
- M6 `QUAD_STRETCH`：股四头肌拉伸，器械「自重」，分类「热身拉伸」，子分类「静态拉伸」。
- M7 `CALF_STRETCH`：小腿拉伸，器械「自重」，分类「热身拉伸」，子分类「静态拉伸」。
- M8 `HIP_90_90`：90/90 髋活动，器械「自重」，分类「热身拉伸」，子分类「动态热身」。
- M9 `WORLDS_GREATEST_STRETCH`：世界最伟大拉伸，器械「自重」，分类「热身拉伸」，子分类「动态热身」。
- M10 `FOAM_ROLL_QUAD`：泡沫轴股四头肌放松，器械「其他」，分类「热身拉伸」，子分类「泡沫轴放松」。
- M11 `FOAM_ROLL_GLUTES`：泡沫轴臀部放松，器械「其他」，分类「热身拉伸」，子分类「泡沫轴放松」。
- M12 `FOAM_ROLL_LATS`：泡沫轴背阔肌放松，器械「其他」，分类「热身拉伸」，子分类「泡沫轴放松」。

后续回填时新增 M1-M12。
