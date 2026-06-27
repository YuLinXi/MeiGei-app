# 预置动作审核决策记录

生成日期：2026-06-27

## 已确认决策

### 第 1 组：胸部飞鸟 / 夹胸类协同肌

结论：接受。

涉及动作：

- `DB_FLY`：哑铃飞鸟
- `INCLINE_DB_FLY`：上斜哑铃飞鸟
- `CABLE_CROSSOVER`：绳索夹胸
- `HIGH_CABLE_FLY`：高位绳索夹胸
- `LOW_CABLE_FLY`：低位绳索夹胸
- `PEC_DECK_FLY`：蝴蝶机夹胸

回填规则：统一移除 `triceps` 协同肌，保留 `chest` 主动肌和 `deltFront` 协同肌。

### 第 2 组：背部划船类主动肌

结论：接受。

涉及动作：

- `BB_ROW`：杠铃划船
- `PENDLAY_ROW`：潘德利划船
- `T_BAR_ROW`：T杠划船
- `DB_BENT_OVER_ROW`：哑铃划船
- `SINGLE_ARM_DB_ROW`：单臂哑铃划船
- `DB_PRONE_ROW`：俯卧哑铃划船
- `SEATED_CABLE_ROW`：坐姿绳索划船
- `V_BAR_ROW`：V-bar 划船
- `WIDE_SEATED_ROW`：宽握坐姿划船
- `MACHINE_ROW`：坐姿器械划船
- `MACHINE_SINGLE_ARM_ROW`：单臂器械划船
- `HAMMER_ROW`：悍马机划船
- `SINGLE_ARM_HAMMER_ROW`：单臂悍马机划船
- `SMITH_OVERHAND_ROW`：史密斯正手划船
- `SMITH_REVERSE_ROW`：史密斯反手划船
- `SPLIT_HIGH_ROW`：分动式高位划船
- `INVERTED_ROW`：反式划船

回填规则：划船类统一使用 `lats` + `rhomboids` 作为主动肌，保留 `biceps` + `deltRear` 作为协同肌。`SMITH_REVERSE_ROW` 当前已是双主动肌，保持一致即可。

### 第 3 组：背部硬拉 / 髋铰链 / 背伸类肌群

结论：接受。

涉及动作：

- `DEADLIFT`：硬拉
- `PARTIAL_DEADLIFT`：半程硬拉
- `RACK_PULL`：架上拉
- `BACK_EXTENSION`：山羊挺身
- `REVERSE_HYPEREXTENSION`：反向山羊挺身
- `GOOD_MORNING`：早安式

回填规则：

- `DEADLIFT`：主动肌 `lowerBack` + `glutes`，协同肌 `hams` + `quads` + `traps` + `forearms`。
- `PARTIAL_DEADLIFT` / `RACK_PULL`：主动肌 `lowerBack` + `glutes` + `traps`，协同肌 `hams` + `forearms`。
- `BACK_EXTENSION`：主动肌 `lowerBack`，协同肌 `glutes` + `hams`。
- `REVERSE_HYPEREXTENSION`：主动肌 `glutes` + `lowerBack`，协同肌 `hams`。
- `GOOD_MORNING`：主动肌 `hams` + `lowerBack`，协同肌 `glutes`。

### 第 4 组：背部剩余单点肌群

结论：部分接受，按用户修订口径执行。

涉及动作与回填规则：

- `STRAIGHT_ARM_PULLDOWN`：直臂下压。主动肌保留 `lats`，协同肌改为仅 `deltRear`；不加入 `triceps`。
- `DB_PULLOVER`：哑铃仰卧上拉。接受建议，主动肌 `lats`，协同肌 `chest` + `triceps`。
- `SHRUG_BB`：杠铃耸肩。主动肌 `traps`，协同肌留空。
- `SHRUG_DB`：哑铃耸肩。主动肌 `traps`，协同肌留空。

说明：耸肩动作中前臂更多是握持/负重保持因素，不一定作为训练部位展示；当前产品口径采用无协同肌，避免误导用户认为前臂是该动作主要训练目标。

### 第 5 组：肩推类协同肌

结论：接受。

涉及动作：

- `OHP`：站姿杠铃推举
- `SEATED_BB_PRESS`：坐姿杠铃推举
- `DB_OVERHEAD_PRESS`：哑铃推肩
- `ARNOLD_PRESS`：阿诺德推举
- `MACHINE_SHOULDER_PRESS`：器械肩推
- `SMITH_SHOULDER_PRESS`：史密斯肩推
- `HAMMER_SEATED_PRESS`：悍马机坐姿推举

回填规则：主动肌保留 `deltFront`，协同肌由 `triceps` 调整为 `triceps` + `deltSide`。

### 第 6 组：肩后束动作协同肌

结论：接受。

涉及动作：

- `REAR_DELT_FLY`：俯身飞鸟
- `MACHINE_REVERSE_FLY`：蝴蝶机反向飞鸟
- `FACE_PULL`：绳索面拉
- `CABLE_CROSS_REAR_FLY`：绳索交叉后束飞鸟
- `PREACHER_BENCH_REAR_DELT_FLY`：牧师凳俯身飞鸟

回填规则：

- 普通后束飞鸟类：主动肌 `deltRear`，协同肌 `traps` + `rhomboids`。
- `FACE_PULL`：主动肌 `deltRear`，协同肌 `traps` + `rhomboids` + `deltSide`。

### 第 7 组：杠铃/哑铃提拉与直立划船合并口径

结论：按用户修订口径执行。

涉及动作：

- `UPRIGHT_ROW`：杠铃直立划船
- `DB_UPRIGHT_ROW`：哑铃直立划船
- `BB_HIGH_PULL`：杠铃提拉

回填规则：

- 只保留 `BB_HIGH_PULL` 作为杠铃侧标准动作，展示名保留「杠铃提拉」。
- `UPRIGHT_ROW`「杠铃直立划船」不再作为独立新选动作展示；历史数据并入 `BB_HIGH_PULL`「杠铃提拉」，需要在 alias 层映射。
- `DB_UPRIGHT_ROW` 展示名由「哑铃直立划船」改为「哑铃提拉」。
- `BB_HIGH_PULL` 与 `DB_UPRIGHT_ROW` 统一肌群：主动肌 `deltFront` + `deltSide`，协同肌 `traps`。
- 两者分类均保留为「肩」，不改入「功能性」。

### 第 8 组：手臂动作

结论：按用户修订口径执行。

涉及动作：

- `HAMMER_CURL`：锤式弯举
- `DB_CROSS_HAMMER_CURL`：交叉锤式弯举
- `REVERSE_CURL`：反握弯举
- `PREACHER_CURL`：牧师凳弯举
- `CLOSE_GRIP_BENCH`：窄距卧推
- `TRICEP_DIP`：双杠臂屈伸（三头）
- `BENCH_DIP`：凳上臂屈伸

回填规则：

- `HAMMER_CURL` / `DB_CROSS_HAMMER_CURL`：保留现状，主动肌 `biceps`，不补 `forearms` 协同肌。
- `REVERSE_CURL`：去掉 `forearms`，主动肌仅保留 `biceps`。
- `PREACHER_CURL`：删除原泛称「牧师凳弯举」动作；历史记录并入「牧师凳杠铃弯举」。
- 牧师凳弯举应区分为「牧师凳 EZ 杠弯举」「牧师凳杠铃弯举」「牧师凳哑铃弯举」。
- 器械归类仅使用「杠铃」和「哑铃」：EZ 杠也归入「杠铃」，不单独增加器械类型。
- `CLOSE_GRIP_BENCH` / `TRICEP_DIP` / `BENCH_DIP`：接受建议，主动肌 `triceps`，协同肌 `chest` + `deltFront`。

### 第 9 组：腿部蹲类 / 腿举 / 单腿蹲类协同肌

结论：按用户修订口径执行。

涉及动作：

- `BB_SQUAT`：杠铃深蹲
- `FRONT_SQUAT`：颈前深蹲
- `SMITH_SQUAT`：史密斯深蹲
- `HACK_SQUAT`：哈克深蹲
- `GOBLET_SQUAT`：高脚杯深蹲
- `PISTOL_SQUAT`：单腿深蹲
- `LEG_PRESS`：腿举
- `MACHINE_LEG_PRESS`：器械倒蹬机
- `BULGARIAN_SPLIT_SQUAT`：保加利亚分腿蹲
- `LUNGE`：箭步蹲
- `WALKING_LUNGE`：行走箭步蹲
- `STEP_UP`：箱式登踏

回填规则：

- 蹲类：接受建议，主动肌 `quads`，协同肌 `glutes` + `adductors` + `hams`。
- 腿举类：`LEG_PRESS`「腿举」与 `MACHINE_LEG_PRESS`「器械倒蹬机」视为同一动作；删除「腿举」，只保留 `MACHINE_LEG_PRESS`「器械倒蹬机」，历史记录并入保留项。
- `MACHINE_LEG_PRESS` 肌群接受建议：主动肌 `quads`，协同肌 `glutes` + `adductors` + `hams`。
- 箭步 / 登踏 / 保加利亚类：接受建议，主动肌 `quads` + `glutes`，协同肌 `adductors` + `hams`。

### 第 10 组：腿部髋铰链 / 相扑硬拉

结论：按用户修订口径执行。

涉及动作：

- `ROMANIAN_DL`：罗马尼亚硬拉
- `DB_RDL`：哑铃罗马尼亚硬拉
- `SUMO_DEADLIFT`：相扑硬拉

回填规则：

- `ROMANIAN_DL` / `DB_RDL`：接受建议，主动肌 `hams`，协同肌 `glutes` + `lowerBack`。
- `SUMO_DEADLIFT`：主动肌 `glutes` + `adductors`，协同肌 `quads` + `hams` + `lowerBack`；不加入 `traps` 和 `forearms`。

### 第 11 组：臀部动作

结论：接受克制版。

涉及动作：

- `HIP_THRUST`：杠铃臀冲
- `MACHINE_HIP_THRUST`：器械臀推
- `GLUTE_BRIDGE`：臀桥
- `DB_GLUTE_BRIDGE`：哑铃臀桥
- `CABLE_KICKBACK`：绳索后踢腿
- `GLUTE_KICKBACK_MACHINE`：器械后踢腿
- `DB_SINGLE_LEG_DEADLIFT`：单腿哑铃硬拉
- `HIP_ABDUCTION`：髋外展
- `BAND_LATERAL_WALK`：弹力带侧走

回填规则：

- 臀推 / 臀桥：主动肌 `glutes`，协同肌 `hams`。
- 绳索后踢腿 / 器械后踢腿：主动肌 `glutes`，协同肌留空。
- `DB_SINGLE_LEG_DEADLIFT`：主动肌 `glutes` + `hams`，协同肌 `lowerBack`。
- 髋外展 / 弹力带侧走：主动肌 `gluteMed`，协同肌 `glutes`。

### 第 12 组：核心动作

结论：按用户确认口径执行。

涉及动作：

- `BIRD_DOG`：鸟狗
- `RUSSIAN_TWIST`：俄罗斯转体
- `WOODCHOPPER`：绳索伐木
- `INCLINE_TWIST_CRUNCH`：上斜卷腹转体
- `AB_WHEEL`：健腹轮

回填规则：

- `BIRD_DOG`：主动肌 `abs` + `obliques`，协同肌 `lowerBack` + `glutes`。
- `RUSSIAN_TWIST` / `WOODCHOPPER` / `INCLINE_TWIST_CRUNCH`：主动肌 `obliques`，协同肌 `abs`。
- `AB_WHEEL`：采用克制版，主动肌 `abs`，协同肌 `obliques`；不加入肩背稳定肌。

### 第 13 组：功能性动作

结论：接受，按澄清后的子分类口径执行。

涉及动作：

- `BATTLE_ROPE`：战绳
- `BURPEE`：波比跳
- `KETTLEBELL_SWING`：壶铃摆荡
- `TURKISH_GET_UP`：土耳其起立
- `FARMER_CARRY`：农夫行走

回填规则：

- `BATTLE_ROPE`：器械改为「其他」，分类「功能性」，子分类「动态控制」；主动肌 `deltFront` + `forearms`，协同肌 `abs` + `obliques`。
- `BURPEE`：分类「功能性」，子分类「动态控制」；主动肌 `quads` + `chest`，协同肌 `triceps` + `deltFront` + `abs`。
- `KETTLEBELL_SWING`：分类「功能性」，子分类「动态控制」；主动肌 `glutes` + `hams`，协同肌 `lowerBack`。
- `TURKISH_GET_UP`：器械改为「壶铃」，分类「功能性」，子分类「动态控制」；主动肌 `abs` + `deltFront`，协同肌 `obliques` + `glutes`。
- `FARMER_CARRY`：器械改为「其他」，分类「功能性」，子分类「负重搬运」；主动肌 `forearms` + `traps`，协同肌 `abs` + `obliques`。

### 第 14 组：钻石俯卧撑

结论：选择方案 B，改入手臂。

涉及动作：

- `DIAMOND_PUSH_UP`：钻石俯卧撑

回填规则：分类改为「手臂」，子分类置空；主动肌 `triceps`，协同肌 `chest` + `deltFront`。

### 第 15 组：热身拉伸

结论：接受。

涉及动作：

- `SHOULDER_WARMUP`：肩部热身
- `BAND_SHOULDER_PASS_THROUGH`：弹力带绕肩

回填规则：

- `SHOULDER_WARMUP`：展示名改为「肩部动态热身」，分类「热身拉伸」，子分类「动态热身」，器械「自重」。
- `BAND_SHOULDER_PASS_THROUGH`：展示名保留「弹力带绕肩」，分类「热身拉伸」，子分类「动态热身」，器械改为「弹力带」。

### 第 16 组：单臂绳索下拉合并

结论：按用户修订口径执行。

涉及动作：

- `SINGLE_ARM_LAT_PULLDOWN`：单臂高位下拉
- `CABLE_SINGLE_ARM_PULLDOWN`：单臂绳索下拉

回填规则：

- 保留 `CABLE_SINGLE_ARM_PULLDOWN`「单臂绳索下拉」。
- 删除 `SINGLE_ARM_LAT_PULLDOWN`「单臂高位下拉」。
- 历史记录与 alias 归并：`SINGLE_ARM_LAT_PULLDOWN` /「单臂高位下拉」并入 `CABLE_SINGLE_ARM_PULLDOWN` /「单臂绳索下拉」。

## 待确认决策

已完成当前 93 条候选项的分组审核，下一步按本文件回填 JSON 与 alias。
